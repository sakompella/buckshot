import * as hegel from "@hegeldev/hegel";
import * as gs from "@hegeldev/hegel/generators";
import { Database } from "bun:sqlite";
import { expect, test } from "bun:test";
import { mkdtempSync } from "node:fs";
import { tmpdir } from "node:os";
import { join } from "node:path";

import { consistencyOf } from "../scripts/arena-regret-consistency.ts";
import { MISMATCHES, mismatchesOf, type MoveRow, openRegret } from "../src/arena-viewer/regret.ts";

const SCHEMA = `create table regret (
  match_id text, ordinal integer, player text, label text, evaluator text, max_depth integer, budget integer, reload text, samples integer,
  status text, reason text, values_json text, best text, best_score integer, chosen_score integer, regret integer, exact integer,
  depth integer, limited integer, nodes integer, ms real,
  primary key (match_id, ordinal, evaluator, max_depth, budget, reload, samples))`;

interface Row {
  readonly match: string;
  readonly ordinal: number;
  readonly player: string;
  readonly status?: "searched" | "fallback";
  readonly best: number;
  readonly chosen: number;
  readonly exact?: boolean;
  readonly values?: string;
  readonly run?: Partial<Run>;
}

interface Run {
  readonly evaluator: string;
  readonly depth: number;
  readonly budget: number;
  readonly reload: string;
  readonly samples: number;
}

const RUN: Run = { evaluator: "v1", depth: 6, budget: 20000, reload: "static", samples: 0 };

const regretFile = (rows: ReadonlyArray<Row>): string => {
  const path = join(mkdtempSync(join(tmpdir(), "regret-")), "regret.sqlite");
  const db = new Database(path);

  db.run(SCHEMA);

  const insert = db.query(`insert into regret values (?, ?, ?, 'chosen move', ?, ?, ?, ?, ?, ?, null, ?, 'best move', ?, ?, ?, ?, 4, 1, 0, 0)`);

  for (const row of rows) {
    const { evaluator, depth, budget, reload, samples } = { ...RUN, ...row.run };
    const searched = (row.status ?? "searched") === "searched";

    const values = row.values ?? JSON.stringify([{ label: "best move", score: row.best }, { label: "other move", score: 0 }, { label: "chosen move", score: row.chosen }]);

    insert.run(row.match, row.ordinal, row.player, evaluator, depth, budget, reload, samples, row.status ?? "searched", values, searched ? row.best : null, searched ? row.chosen : null, searched ? row.best - row.chosen : null, searched ? Number(row.exact ?? false) : null);
  }

  db.close();

  return path;
};

test("a seat's regret sums its searched moves in percentage points and judges each by lichess's cut-offs", () => {
  const regret = openRegret(
    regretFile([
      { match: "m1", ordinal: 1, player: "A", best: 600_000, chosen: 500_000 },
      { match: "m1", ordinal: 2, player: "A", best: 1_000_000, chosen: 0, exact: true },
      { match: "m1", ordinal: 3, player: "B", best: 400_000, chosen: 400_000 },
      { match: "m1", ordinal: 4, player: "B", best: 600_000, chosen: 540_000 },
    ]),
  );

  expect(regret.seats.get("m1|A")).toMatchObject({ moves: 2, total: 110, best: 0, inaccuracies: 0, mistakes: 1, blunders: 1, losses: [10, 100] });
  expect(regret.seats.get("m1|B")).toMatchObject({ moves: 2, total: 6, best: 1, inaccuracies: 1, mistakes: 0, blunders: 0, losses: [6] });
  expect(regret.seats.get("m1|B")?.accuracy).toBeGreaterThan(regret.seats.get("m1|A")?.accuracy ?? 100);
});

test("a decision whose moves all score within a point is left out of a seat's statistics", () => {
  const flat = JSON.stringify([{ label: "best move", score: 500_000 }, { label: "chosen move", score: 495_000 }]);

  const regret = openRegret(
    regretFile([
      { match: "m1", ordinal: 1, player: "A", best: 500_000, chosen: 495_000, values: flat },
      { match: "m1", ordinal: 2, player: "A", best: 600_000, chosen: 600_000 },
      { match: "m1", ordinal: 3, player: "B", best: 500_000, chosen: 495_000, values: flat },
    ]),
  );

  expect(regret.seats.get("m1|A")).toMatchObject({ moves: 1, total: 0, best: 1, losses: [] });
  expect(regret.seats.has("m1|B")).toBe(false);
});

test("a move that fell back has no regret, not a zero", () => {
  const regret = openRegret(
    regretFile([
      { match: "m1", ordinal: 1, player: "A", best: 600_000, chosen: 500_000 },
      { match: "m1", ordinal: 2, player: "A", status: "fallback", best: 0, chosen: 0 },
    ]),
  );

  expect(regret.seats.get("m1|A")?.moves).toBe(1);
  expect(regret.moves("m1").has(2)).toBe(false);
});

test("a move shows its regret, whether it is exact and the scores in percentage points", () => {
  const regret = openRegret(
    regretFile([
      { match: "m1", ordinal: 1, player: "A", best: 600_000, chosen: 500_000 },
      { match: "m1", ordinal: 2, player: "A", best: 1_000_000, chosen: 1_000_000, exact: true },
    ]),
  );

  expect(regret.moves("m1").get(1)).toEqual({
    points: 10,
    exact: false,
    best: "best move",
    bestScore: 60,
    chosen: "chosen move",
    chosenScore: 50,
    depth: 4,
    limited: true,
    values: [
      { label: "best move", score: 60 },
      { label: "other move", score: 0 },
      { label: "chosen move", score: 50 },
    ],
  });
  expect(regret.moves("m1").get(2)?.exact).toBe(true);
  expect(regret.moves("other").size).toBe(0);
});

test("a file holding more than one run is refused, so evaluators, reload rules and sample counts never mix", () => {
  const run = (other: Partial<Run>) => () => openRegret(regretFile([{ match: "m1", ordinal: 1, player: "A", best: 600_000, chosen: 500_000 }, { match: "m1", ordinal: 1, player: "A", best: 900_000, chosen: 100_000, run: other }]));

  for (const other of [{ evaluator: "v2" }, { depth: 3 }, { reload: "sampled", samples: 256 }]) expect(run(other)).toThrow("regret runs, not one");
});

test("a stored row whose values do not decode or do not agree with its scores fails the match", () => {
  const broken = (row: Partial<Row>) => openRegret(regretFile([{ match: "m1", ordinal: 1, player: "A", best: 600_000, chosen: 500_000, ...row }]));

  expect(() => broken({ values: "not json" }).moves("m1")).toThrow();
  expect(() => broken({ values: JSON.stringify([{ label: "best move", score: 700_000 }, { label: "chosen move", score: 500_000 }]) }).moves("m1")).toThrow("best score is not the top value");
});

const randomOf = (seed: number) => {
  let state = seed;

  return (below: number) => {
    state = (state * 1_103_515_245 + 12_345) % 2_147_483_648;

    return state % below;
  };
};

const consistentRow = (random: (below: number) => number, ordinal: number): MoveRow => {
  const values = Array.from({ length: 1 + random(13) }, (_value, index) => ({ label: `move ${index}`, score: random(3) === 0 ? random(2) * 1_000_000 : random(1_000_001) }));
  const chosen = values[random(values.length)] ?? { label: "move 0", score: 0 };
  const bestScore = Math.max(...values.map(({ score }) => score));

  return { matchId: "m", ordinal, label: chosen.label, values, regret: bestScore - chosen.score, exact: 0, best: "move 0", bestScore, chosenScore: chosen.score, depth: 6, limited: 0 };
};

const drawnRow = (tc: hegel.TestCase): MoveRow => consistentRow((below) => tc.draw(gs.integers({ minValue: 0, maxValue: below - 1 })), 0);

test("a consistent row has no mismatch", () =>
  hegel.test((tc) => {
    expect(mismatchesOf(drawnRow(tc))).toEqual([]);
  }));

test("each kind of damage to a consistent row shows as its own mismatch", () =>
  hegel.test((tc) => {
    const row = drawnRow(tc);

    expect(mismatchesOf({ ...row, bestScore: row.bestScore + 1, regret: row.regret + 1 })).toEqual(["best score is not the top value"]);
    expect(mismatchesOf({ ...row, label: "not a move" })).toEqual(["chosen move has no value"]);
    expect(mismatchesOf({ ...row, chosenScore: row.chosenScore - 1, regret: row.regret + 1 })).toEqual(["chosen value is not the chosen score"]);
    expect(mismatchesOf({ ...row, regret: row.regret + 1 })).toEqual(["regret is not best minus chosen"]);
  }));

test("the consistency check counts every row, the rows that do not decode and each mismatch", () => {
  const random = randomOf(5);
  const stored = (row: MoveRow) => ({ ...row, values: JSON.stringify(row.values) });
  const rows = Array.from({ length: 20 }, (_row, ordinal) => consistentRow(random, ordinal));

  const undertop = (rows[3]?.bestScore ?? 0) === 0 ? 1 : (rows[3]?.bestScore ?? 0) - 1;

  const damaged = [
    ...rows.map(stored),
    { ...stored(rows[0] ?? consistentRow(random, 0)), regret: -1 },
    { ...stored(rows[1] ?? consistentRow(random, 1)), values: "[" },
    { ...stored(rows[2] ?? consistentRow(random, 2)), limited: 2 },
    { ...stored(rows[3] ?? consistentRow(random, 3)), bestScore: undertop, regret: undertop - (rows[3]?.chosenScore ?? 0) },
  ];

  const expected = new Map([["best score is not the top value", 1], ["regret is not best minus chosen", 1]]);

  expect(consistencyOf(damaged)).toEqual({ rows: 24, undecodable: 2, mismatches: MISMATCHES.map((mismatch) => [mismatch, expected.get(mismatch) ?? 0]) });
});
