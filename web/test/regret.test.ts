import assert from "node:assert/strict";

import { Database } from "bun:sqlite";
import { beforeAll, expect, test } from "bun:test";
import { mkdirSync, mkdtempSync, rmSync, writeFileSync } from "node:fs";
import { tmpdir } from "node:os";
import { join } from "node:path";

import { Option, Result } from "effect";

import { agentGame } from "../src/agent/view.ts";
import { importTournaments, openAnalysis } from "../src/analysis/import.ts";
import { boardOf, type Limits, loadPlayer, ownLog, type Player, type PlayerInput } from "../src/analysis/player.ts";
import { regretOf, WIN } from "../src/analysis/regret.ts";
import { type MoveLine } from "../src/arena/runlog.ts";
import { answerDraw, answerPrompt, type Game, startGame } from "../src/bend.ts";
import { Counter, type GameEvent, type LearnedSecret, type Move, type Seat, Secret, Stage } from "../src/domain.ts";
import { rosterOf } from "../src/players.ts";
import { agentMoveText } from "../src/text.ts";
import { replayOf } from "../src/viewer/replay.ts";
import { playFauxRun } from "./faux-run.ts";

// Regret on known positions. Most are two-player games without items, played
// through the rules by a fixed list of answers, one per request point: a draw's
// value or a menu index. The last tests run recorded arena matches through the
// script. The player sees only the board and the mover's log.

let player: Player;

beforeAll(async () => {
  const dir = mkdtempSync(join(tmpdir(), "buckshot-regret-test-"));

  try {
    player = await loadPlayer(dir);
  } finally {
    rmSync(dir, { recursive: true, force: true });
  }
}, 60_000);

interface Played {
  readonly game: Game;
  readonly events: ReadonlyArray<GameEvent>;
  readonly learned: ReadonlyArray<LearnedSecret>;
}

const play = (answers: ReadonlyArray<number>): Played => {
  let step = Result.getOrThrow(startGame(2, false, 0));
  const events = [...step.events];

  for (const answer of answers) {
    const pending = step.game.pending;

    if (pending.kind === "Draw") step = Result.getOrThrow(answerDraw(step.game, pending.ticket, answer));
    else if (pending.kind === "Choose" && pending.prompts[0] !== undefined) step = Result.getOrThrow(answerPrompt(step.game, pending.prompts[0].ticket, pending.prompts[0].seat, answer));
    else throw new Error(`no request point for answer ${answer}`);

    events.push(...step.events);
  }

  return { game: step.game, events, learned: [] };
};

const mover = ({ game }: Played): Seat => {
  return Stage.matchOrElse(game.board.stage, { Playing: ({ seat, mode }) => (mode === "Idle" ? seat : undefined) }, () => undefined) ?? assert.fail("the game must wait on a whole move");
};

const inputOf = (played: Played): PlayerInput => ({ table: 2, items: false, board: boardOf(played.game), log: ownLog(played.events, played.learned, mover(played)), me: mover(played) });

const health = ({ game }: Played): ReadonlyArray<number> => game.board.seats.map((view) => Counter.match(view.counter, { Unjammed: ({ health }) => health, Jammed: () => 0 }));

const regretAt = (played: Played, limits: Limits, chosen: string) => {
  const me = mover(played);
  const labelOf = (steps: ReadonlyArray<Move>) => agentMoveText(rosterOf(played.game.seats), me, steps);
  const menu = ["Shoot yourself", `Shoot ${rosterOf(played.game.seats).nameOf(me === 1 ? 3 : 1)}`];

  return regretOf(player.analyse(inputOf(played), limits), labelOf, menu, chosen);
};

// Both players at 1 health, and two shells left that the count shows are live. Player B moves.
const FORCED_WIN = [1, 0, 0, 1, 0, 1, 0, 1, 0, 0, 0, 1, 3, 1, 0, 0, 0, 0, 5, 1, 0, 1, 0, 1, 0, 1];

// Player A at 1 health against 4, and two shells left that the count shows are live. Player A moves.
const CERTAIN_LOSS = [0, 1, 0, 4, 1, 0, 0, 0, 1, 7, 0, 1, 1, 1, 0, 0, 0, 0, 1, 0, 0, 0, 0];

const LIMITS: Limits = { depth: 3, budget: 100_000 };

test("a forced win: shooting yourself on a known live shell costs the whole win", () => {
  const played = play(FORCED_WIN);
  expect(health(played)).toEqual([1, 1]);

  const regret = regretAt(played, LIMITS, "Shoot yourself");

  expect(regret).toMatchObject({ status: "searched", best: { label: "Shoot Player A", score: WIN }, chosen: { score: 0 }, regret: WIN, exact: true, limited: false });
});

test("the winning shot ends the round: an exact value with regret 0, though the match goes on", () => {
  const played = play(FORCED_WIN);
  expect(played.game.board.round).toMatchObject({ index: 0, rounds: 3 });

  expect(regretAt(played, LIMITS, "Shoot Player A")).toMatchObject({ status: "searched", chosen: { score: WIN }, regret: 0, exact: true });
});

test("a certain loss: every move scores 0, so no move has regret", () => {
  const played = play(CERTAIN_LOSS);
  expect(health(played)).toEqual([1, 4]);

  const regret = regretAt(played, LIMITS, "Shoot Player B");

  expect(regret).toMatchObject({ status: "searched", values: [{ score: 0 }, { score: 0 }], regret: 0, exact: true });
});

test("the depth-0 fallback is marked and has no regret, whether the budget or the depth stopped it", () => {
  for (const limits of [{ depth: 3, budget: 1 }, { depth: 0, budget: 100_000 }]) {
    const regret = regretAt(play(FORCED_WIN), limits, "Shoot yourself");

    expect(regret.status).toBe("fallback");
    expect(regret).not.toHaveProperty("regret");
  }
});

test("another player's secret never reaches the player; the mover's own does", () => {
  const played = play(FORCED_WIN);
  const blank = Secret.cases.Glimpse.make({ shell: "Blank" });
  const heardBy = (seat: Seat): Played => ({ ...played, learned: [{ seat, secret: blank, at: played.events.length }] });

  expect(regretAt(heardBy(1), LIMITS, "Shoot yourself")).toEqual(regretAt(played, LIMITS, "Shoot yourself"));
  // The count says the chamber is live, so a glimpse of a blank leaves the mover no consistent belief.
  expect(regretAt(heardBy(3), LIMITS, "Shoot yourself").status).toBe("invalid");
});

test("the script scores every agent decision of a recorded match once, and stores a fallback with no regret", async () => {
  const root = mkdtempSync(join(tmpdir(), "buckshot-regret-script-"));
  const source = join(root, "tournament");
  const database = join(root, "analysis.sqlite");
  const derived = join(root, "derived.sqlite");
  mkdirSync(source);

  try {
    await playFauxRun(join(source, "a_b_b0_p0"), ["Agent", "Agent"], "on-turn");
    const schedule = [{ name: "a_b_b0_p0", pairing: 0, block: 0, seed: 42, seats: ["A", "B"], entrants: ["a", "b"] }];
    writeFileSync(join(source, "tournament.json"), JSON.stringify({ format: 1, created_at: "2026-01-01T00:00:00Z", git_commit: "test", config: { name: "test", seed: 42, delivery: "on-turn", endpoints: { fake: { api: "anthropic", url: "http://invalid", keyEnv: "UNUSED" } }, entrants: { a: { endpoint: "fake", model: "faux-a", effort: "medium" }, b: { endpoint: "fake", model: "faux-b", effort: "medium" } }, pairings: [["a", "b"]], blocksPerPairing: 1 }, schedule }));
    importTournaments({ database, sources: [source], skipped: {} });

    const score = async (budget: number) => {
      const run = Bun.spawn(["nice", "-n", "10", "bun", "scripts/arena-regret.ts", "--db", database, "--out", derived, "--match", "a_b_b0_p0", "--depth", "2", "--budget", String(budget)], { cwd: join(import.meta.dir, ".."), stdout: "ignore", stderr: "pipe" });
      expect(await run.exited).toBe(0);
    };

    await score(2000);
    // A rerun with the same settings skips the scored decisions; a budget of one node leaves only the fallback.
    await score(2000);
    await score(1);

    const analysis = new Database(database, { readonly: true });
    const agent = analysis.query<{ ordinal: number; label: string }, []>("SELECT ordinal, label FROM decisions WHERE by_whom = 'agent' ORDER BY ordinal").all();
    analysis.close();
    const out = new Database(derived, { readonly: true });
    const rows = out.query<{ ordinal: number; label: string; status: string; regret: number | null; values_json: string }, []>("SELECT ordinal, label, status, regret, values_json FROM regret WHERE budget = 2000 ORDER BY ordinal").all();
    const fallbacks = out.query<{ status: string; regret: number | null }, []>("SELECT status, regret FROM regret WHERE budget = 1").all();
    out.close();

    expect(fallbacks).toEqual(agent.map(() => ({ status: "fallback", regret: null })));
    expect(agent.length).toBeGreaterThan(0);
    expect(rows.map(({ ordinal, label }) => ({ ordinal, label }))).toEqual(agent);
    expect(rows.every((row) => row.status === "searched" && row.regret !== null && row.regret >= 0)).toBe(true);
    expect(rows.every((row) => JSON.parse(row.values_json).some((value: { label: string }) => value.label === row.label))).toBe(true);
  } finally {
    rmSync(root, { recursive: true, force: true });
  }
}, 120_000);

/** A recorded match: the seed, and each agent move by its label. Forced grabs are played as the arena plays them. */
interface Recorded {
  readonly name: string;
  readonly seed: number;
  readonly moves: ReadonlyArray<string>;
}

/** Writes recorded matches into an analysis database, as the importer would store their replayed decisions. */
const writeRecorded = (database: string, matches: ReadonlyArray<Recorded>): void => {
  const db = openAnalysis(database);
  db.query("INSERT INTO tournaments VALUES ('t', 'fixture', '/fixture', '2026-01-01', 'test', 'complete', '{}', 'r')").run();

  for (const match of matches) {
    const setup = { seed: String(match.seed), controllers: ["Agent", "Agent"] as const, letters: ["A", "B"] as const };
    const manifest = { format: 1, status: "finished", ...setup, delivery: "on-turn", agents: {} };
    db.query("INSERT INTO matches (id, tournament_id, name, pairing, block, seed, seed_block_id, status, source_dir, schedule_json, manifest_json, fingerprint, replay_status) VALUES (?, 't', ?, 0, 0, ?, 'b', 'completed', '/fixture', '{}', ?, 'f', 'validated')").run(match.name, match.name, match.seed, JSON.stringify(manifest));
    const lines: Array<MoveLine> = [];
    let replay = Result.getOrThrow(replayOf(Option.none(), setup, []));
    const agentMoves = [...match.moves];

    while (agentMoves.length > 0) {
      const source = Option.getOrThrow(replay.session.current(replay.table));
      const turn = replay.session.turn(replay.table);
      const [player, game] = (["A", "B"] as const).map((letter) => [letter, Result.getOrThrow(agentGame(source, turn, letter))] as const).find(([, view]) => view.status === "your turn") ?? assert.fail("a recorded match ran out of turns");
      const menu = game.status === "your turn" ? game.moves : [];
      const forced = menu.length === 1 && menu[0]?.label === "Grab an item";
      const label = forced ? "Grab an item" : (agentMoves.shift() ?? "");
      const move = menu.findIndex((entry) => entry.label === label);
      expect(move).toBeGreaterThanOrEqual(0);
      const line: MoveLine = { t: "", kind: "move", player, position: player === "A" ? 1 : 2, turn, move, label, by: forced ? "forced" : "agent" };
      const record = `${match.name}:${lines.length}`;
      db.query("INSERT INTO source_records (id, path, line, raw, current) VALUES (?, 'events.jsonl', ?, ?, 1)").run(record, lines.length, JSON.stringify(line));
      db.query("INSERT INTO decisions (id, match_id, ordinal, turn, player, position, selected_move, label, by_whom, legal_json, delivered_json, source_record) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, '[]', ?)").run(
        record, match.name, lines.length, turn, player, line.position, move, label, line.by, JSON.stringify(menu), record,
      );
      lines.push(line);
      replay = Result.getOrThrow(replayOf(Option.some(replay), setup, lines));
    }
  }

  db.close();
};

// Seed 11 reaches both players at 1 health with live shells known to Player B, who moves next with
// "Shoot Player A", "Shoot yourself" and "Use handsaw". Seed 16 reaches Player A at 1 health, its
// shells known live and no item to turn it: both shots lose.
const BEFORE_THE_WIN = ["Shoot Player A", "Shoot yourself", "Use cigarettes", "Use magnifying glass", "Shoot yourself", "Shoot Player A", "Use handsaw", "Jam Player B", "Shoot Player B", "Shoot yourself", "Shoot Player B", "Use burner phone", "Use magnifying glass"];

const RECORDED: ReadonlyArray<Recorded> = [
  { name: "self_shot", seed: 11, moves: [...BEFORE_THE_WIN, "Shoot yourself"] },
  { name: "winning_shot", seed: 11, moves: [...BEFORE_THE_WIN, "Shoot Player A"] },
  { name: "lost", seed: 16, moves: ["Steal magnifying glass from Player B", "Shoot yourself", "Use magnifying glass", "Shoot Player B", "Steal handsaw from Player A", "Shoot Player A", "Shoot Player B"] },
];

test("the script stores known values of recorded decisions, from the mover's side", async () => {
  const root = mkdtempSync(join(tmpdir(), "buckshot-regret-recorded-"));
  const database = join(root, "analysis.sqlite");
  const derived = join(root, "derived.sqlite");

  try {
    writeRecorded(database, RECORDED);

    for (const { name } of RECORDED) {
      const run = Bun.spawn(["nice", "-n", "10", "bun", "scripts/arena-regret.ts", "--db", database, "--out", derived, "--match", name, "--depth", "3", "--budget", "20000"], { cwd: join(import.meta.dir, ".."), stdout: "ignore", stderr: "pipe" });
      expect(await run.exited).toBe(0);
    }

    const out = new Database(derived, { readonly: true });
    const last = (name: string) => out.query<{ values_json: string }, [string]>("SELECT player, label, status, best, best_score, chosen_score, regret, exact, values_json FROM regret WHERE match_id = ? ORDER BY ordinal DESC LIMIT 1").get(name);
    const scored = out.query<{ match_id: string; n: number }, []>("SELECT match_id, COUNT(*) AS n FROM regret GROUP BY match_id ORDER BY match_id").all();
    const rows = { self: last("self_shot"), win: last("winning_shot"), lost: last("lost") };
    out.close();

    expect(scored).toEqual([{ match_id: "lost", n: 7 }, { match_id: "self_shot", n: 14 }, { match_id: "winning_shot", n: 14 }]);
    expect(rows.self).toMatchObject({ player: "B", label: "Shoot yourself", status: "searched", best: "Shoot Player A", best_score: WIN, chosen_score: 0, regret: WIN, exact: 1 });
    expect(rows.win).toMatchObject({ player: "B", label: "Shoot Player A", status: "searched", best: "Shoot Player A", chosen_score: WIN, regret: 0, exact: 1 });
    expect(rows.lost).toMatchObject({ player: "A", label: "Shoot Player B", status: "searched", best_score: 0, chosen_score: 0, regret: 0, exact: 1 });
    expect(JSON.parse(rows.lost?.values_json ?? "null")).toEqual([{ label: "Shoot yourself", score: 0 }, { label: "Shoot Player B", score: 0 }]);
  } finally {
    rmSync(root, { recursive: true, force: true });
  }
}, 120_000);

test("two shards write one output file together, each match once, and a rerun scores nothing", async () => {
  const root = mkdtempSync(join(tmpdir(), "buckshot-regret-shards-"));
  const database = join(root, "analysis.sqlite");
  const derived = join(root, "derived.sqlite");

  try {
    writeRecorded(database, RECORDED);

    const run = (...selection: ReadonlyArray<string>) =>
      Bun.spawn(["nice", "-n", "10", "bun", "scripts/arena-regret.ts", "--db", database, "--out", derived, ...selection, "--depth", "3", "--budget", "20000"], { cwd: join(import.meta.dir, ".."), stdout: "ignore", stderr: "pipe" });

    const decisionsOf = async (child: ReturnType<typeof run>): Promise<number> => {
      const [code, report] = await Promise.all([child.exited, new Response(child.stderr).text()]);
      expect(code).toBe(0);

      return JSON.parse(report.trim().split("\n").at(-1) ?? "null").decisions;
    };

    const shards = await Promise.all([decisionsOf(run("--all", "--shard", "1/2")), decisionsOf(run("--all", "--shard", "2/2"))]);

    // Matches go to shards in name order: "lost" and "winning_shot" to the first, "self_shot" to the second.
    expect(shards).toEqual([21, 14]);
    expect(await decisionsOf(run("--all"))).toBe(0);

    const out = new Database(derived, { readonly: true });
    const scored = out.query<{ match_id: string; n: number }, []>("SELECT match_id, COUNT(*) AS n FROM regret GROUP BY match_id ORDER BY match_id").all();
    out.close();

    expect(scored).toEqual([{ match_id: "lost", n: 7 }, { match_id: "self_shot", n: 14 }, { match_id: "winning_shot", n: 14 }]);
  } finally {
    rmSync(root, { recursive: true, force: true });
  }
}, 120_000);
