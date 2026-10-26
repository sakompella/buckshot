import { Database } from "bun:sqlite";
import { expect, test } from "bun:test";
import { mkdtempSync } from "node:fs";
import { tmpdir } from "node:os";
import { join } from "node:path";

import { openRegret } from "../src/arena-viewer/regret.ts";

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

  const insert = db.query(`insert into regret values (?, ?, ?, 'chosen move', ?, ?, ?, ?, ?, ?, null, '[]', 'best move', ?, ?, ?, ?, 4, 1, 0, 0)`);

  for (const row of rows) {
    const { evaluator, depth, budget, reload, samples } = { ...RUN, ...row.run };
    const searched = (row.status ?? "searched") === "searched";

    insert.run(row.match, row.ordinal, row.player, evaluator, depth, budget, reload, samples, row.status ?? "searched", searched ? row.best : null, searched ? row.chosen : null, searched ? row.best - row.chosen : null, searched ? Number(row.exact ?? false) : null);
  }

  db.close();

  return path;
};

test("a seat's regret sums its searched moves in percentage points, with its exact count", () => {
  const regret = openRegret(
    regretFile([
      { match: "m1", ordinal: 1, player: "A", best: 600_000, chosen: 500_000 },
      { match: "m1", ordinal: 2, player: "A", best: 1_000_000, chosen: 0, exact: true },
      { match: "m1", ordinal: 3, player: "B", best: 400_000, chosen: 400_000 },
    ]),
  );

  expect(regret.seats.get("m1|A")).toEqual({ moves: 2, total: 110, exact: 1 });
  expect(regret.seats.get("m1|B")).toEqual({ moves: 1, total: 0, exact: 0 });
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

  expect(regret.moves("m1").get(1)).toEqual({ points: 10, exact: false, best: "best move", bestScore: 60, chosenScore: 50, depth: 4, limited: true });
  expect(regret.moves("m1").get(2)?.exact).toBe(true);
  expect(regret.moves("other").size).toBe(0);
});

test("only the run with the most searched moves is read, so evaluators, reload rules and sample counts never mix", () => {
  const regret = openRegret(
    regretFile([
      { match: "m1", ordinal: 1, player: "A", best: 600_000, chosen: 500_000 },
      { match: "m1", ordinal: 2, player: "A", best: 600_000, chosen: 500_000 },
      { match: "m1", ordinal: 1, player: "A", best: 900_000, chosen: 100_000, run: { evaluator: "v2" } },
      { match: "m1", ordinal: 1, player: "A", best: 900_000, chosen: 100_000, run: { depth: 3 } },
      { match: "m1", ordinal: 1, player: "A", best: 900_000, chosen: 100_000, run: { reload: "expected-deal" } },
      { match: "m1", ordinal: 1, player: "A", best: 900_000, chosen: 100_000, run: { reload: "sampled", samples: 256 } },
      { match: "m1", ordinal: 1, player: "A", best: 900_000, chosen: 100_000, run: { reload: "sampled", samples: 64 } },
    ]),
  );

  expect(regret.seats.get("m1|A")).toEqual({ moves: 2, total: 20, exact: 0 });
  expect(regret.moves("m1").size).toBe(2);
});
