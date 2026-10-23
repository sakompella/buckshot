import assert from "node:assert/strict";

import { Database } from "bun:sqlite";
import { beforeAll, expect, test } from "bun:test";
import { mkdirSync, mkdtempSync, rmSync, writeFileSync } from "node:fs";
import { tmpdir } from "node:os";
import { join } from "node:path";

import { Result } from "effect";

import { importTournaments } from "../src/analysis/import.ts";
import { boardOf, loadPlayer, ownLog, type Player, type Position } from "../src/analysis/player.ts";
import { type Limits, regretAt, WIN } from "../src/analysis/regret.ts";
import { answerDraw, answerPrompt, type Game, startGame } from "../src/bend.ts";
import { Counter, type GameEvent, type LearnedSecret, type Move, type Seat, Secret, Stage } from "../src/domain.ts";
import { rosterOf } from "../src/players.ts";
import { agentMoveText } from "../src/text.ts";
import { playFauxRun } from "./faux-run.ts";

// Regret on known positions. Each is a two-player game without items, played
// through the rules by a fixed list of answers, one per request point: a draw's
// value or a menu index. The player sees only the board and the mover's log.

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

const positionOf = (played: Played): Position => ({ table: 2, items: false, board: boardOf(played.game), log: ownLog(played.events, played.learned, mover(played)), me: mover(played) });

const health = ({ game }: Played): ReadonlyArray<number> => game.board.seats.map((view) => Counter.match(view.counter, { Unjammed: ({ health }) => health, Jammed: () => 0 }));

const regretOf = (played: Played, limits: Limits, chosen: string) => {
  const me = mover(played);
  const labelOf = (steps: ReadonlyArray<Move>) => agentMoveText(rosterOf(played.game.seats), me, steps);
  const menu = ["Shoot yourself", `Shoot ${rosterOf(played.game.seats).nameOf(me === 1 ? 3 : 1)}`];

  return regretAt(player, positionOf(played), limits, labelOf, menu, chosen);
};

// Both players at 1 health, and two shells left that the count shows are live. Player B moves.
const FORCED_WIN = [1, 0, 0, 1, 0, 1, 0, 1, 0, 0, 0, 1, 3, 1, 0, 0, 0, 0, 5, 1, 0, 1, 0, 1, 0, 1];

// Player A at 1 health against 4, and two shells left that the count shows are live. Player A moves.
const CERTAIN_LOSS = [0, 1, 0, 4, 1, 0, 0, 0, 1, 7, 0, 1, 1, 1, 0, 0, 0, 0, 1, 0, 0, 0, 0];

const LIMITS: Limits = { depth: 3, budget: 100_000 };

test("a forced win: shooting yourself on a known live shell costs the whole win", () => {
  const played = play(FORCED_WIN);
  expect(health(played)).toEqual([1, 1]);

  const regret = regretOf(played, LIMITS, "Shoot yourself");

  expect(regret).toMatchObject({ status: "searched", best: { label: "Shoot Player A", score: WIN }, chosen: { score: 0 }, regret: WIN, exact: true, limited: false });
});

test("the winning shot ends the round: an exact value with regret 0, though the match goes on", () => {
  const played = play(FORCED_WIN);
  expect(played.game.board.round).toMatchObject({ index: 0, rounds: 3 });

  expect(regretOf(played, LIMITS, "Shoot Player A")).toMatchObject({ status: "searched", chosen: { score: WIN }, regret: 0, exact: true });
});

test("a certain loss: every move scores 0, so no move has regret", () => {
  const played = play(CERTAIN_LOSS);
  expect(health(played)).toEqual([1, 4]);

  const regret = regretOf(played, LIMITS, "Shoot Player B");

  expect(regret).toMatchObject({ status: "searched", values: [{ score: 0 }, { score: 0 }], regret: 0, exact: true });
});

test("the depth-0 fallback is marked and has no regret", () => {
  const regret = regretOf(play(FORCED_WIN), { depth: 3, budget: 1 }, "Shoot yourself");

  expect(regret.status).toBe("fallback");
  expect(regret).not.toHaveProperty("regret");
});

test("another player's secret never reaches the player; the mover's own does", () => {
  const played = play(FORCED_WIN);
  const blank = Secret.cases.Glimpse.make({ shell: "Blank" });
  const heardBy = (seat: Seat): Played => ({ ...played, learned: [{ seat, secret: blank, at: played.events.length }] });

  expect(regretOf(heardBy(1), LIMITS, "Shoot yourself")).toEqual(regretOf(played, LIMITS, "Shoot yourself"));
  // The count says the chamber is live, so a glimpse of a blank leaves the mover no consistent belief.
  expect(regretOf(heardBy(3), LIMITS, "Shoot yourself").status).toBe("invalid");
});

test("the script scores every agent decision of a recorded match, and only those", async () => {
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

    const run = Bun.spawn(["nice", "-n", "10", "bun", "scripts/arena-regret.ts", "--db", database, "--out", derived, "--match", "a_b_b0_p0", "--depth", "2", "--budget", "2000"], { cwd: join(import.meta.dir, ".."), stdout: "ignore", stderr: "pipe" });
    expect(await run.exited).toBe(0);

    const analysis = new Database(database, { readonly: true });
    const agent = analysis.query<{ ordinal: number; label: string }, []>("SELECT ordinal, label FROM decisions WHERE by_whom = 'agent' ORDER BY ordinal").all();
    analysis.close();
    const out = new Database(derived, { readonly: true });
    const rows = out.query<{ ordinal: number; label: string; status: string; regret: number | null; values_json: string }, []>("SELECT ordinal, label, status, regret, values_json FROM regret ORDER BY ordinal").all();
    out.close();

    expect(agent.length).toBeGreaterThan(0);
    expect(rows.map(({ ordinal, label }) => ({ ordinal, label }))).toEqual(agent);
    expect(rows.every((row) => row.status === "searched" && row.regret !== null && row.regret >= 0)).toBe(true);
    expect(rows.every((row) => JSON.parse(row.values_json).some((value: { label: string }) => value.label === row.label))).toBe(true);
  } finally {
    rmSync(root, { recursive: true, force: true });
  }
}, 120_000);
