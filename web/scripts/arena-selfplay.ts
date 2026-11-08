import { appendFileSync, existsSync, mkdirSync, mkdtempSync, readFileSync, rmSync } from "node:fs";
import { tmpdir } from "node:os";
import { dirname, join, resolve } from "node:path";
import { parseArgs } from "node:util";

import { Option, Result, Schema } from "effect";

import { agentMoves, playChain } from "../src/agent/moves.ts";
import { boardOf, type Limits, loadPlayer, ownLog } from "../src/analysis/player.ts";
import { answerDraw, nextPrompt, startGame } from "../src/bend.ts";
import { GameEvent, type Seat } from "../src/domain.ts";
import { type Progress, promptsOf, settleDraws } from "../src/driver.ts";
import { rosterOf } from "../src/players.ts";
import { nextBelow, seedRng } from "../src/rng.ts";
import { agentMoveText } from "../src/text.ts";

// Plays the minimax player (sim/bend-mp/player/) against itself, one match at a
// time, with the arena's rules: two seats, items, three rounds. Every move is
// the player's own analysis of its own log and the public board, through the
// same calls as `analyse`; TypeScript only marshals. A match is
// played from a seed as the arena starts it. With --swap the round 1 starter
// is the other seat: the first draw (FirstSeat) is answered with the value the
// seed did not give, every later draw as before. Equal best moves are broken
// by --ties: first (the machine's first), or at random from the seed, swap and
// rep. One JSON line per match goes to --out; a rerun skips the matches in it, and refuses a file played with other depth, budget or ties.
// `openings` holds, for each round, the best score (the mover's chance of winning
// the round, in millionths) at the first decision it analysed, and who moved.
//
//   bun scripts/arena-selfplay.ts --out <file.jsonl> --from 10000 --count 1000 [--swap both|no|only] [--reps 1] [--depth 4] [--budget 20000] [--ties first|random] [--shard K/N]

const { values } = parseArgs({
  args: process.argv.slice(2),
  options: { out: { type: "string" }, from: { type: "string" }, count: { type: "string" }, swap: { type: "string", default: "both" }, reps: { type: "string", default: "1" }, depth: { type: "string", default: "4" }, budget: { type: "string", default: "20000" }, ties: { type: "string", default: "first" }, shard: { type: "string", default: "1/1" } },
});

const USAGE = "Usage: bun scripts/arena-selfplay.ts --out <file.jsonl> --from SEED --count N [--swap both|no|only] [--reps N] [--depth N] [--budget N] [--ties first|random] [--shard K/N]";

const whole = (text: string | undefined): number => (text !== undefined && /^\d+$/.test(text) ? Number(text) : NaN);

const from = whole(values.from);
const count = whole(values.count);
const reps = whole(values.reps);
const limits: Limits = { depth: whole(values.depth), budget: whole(values.budget) };
const shard = /^(\d+)\/(\d+)$/.exec(values.shard);

const swaps = ((name: string): ReadonlyArray<boolean> | undefined => {
  switch (name) {
    case "both":
      return [false, true];
    case "no":
      return [false];
    case "only":
      return [true];
    default:
      return undefined;
  }
})(values.swap);

if (values.out === undefined || [from, count, reps, limits.depth, limits.budget].some(Number.isNaN) || reps < 1 || shard === null || swaps === undefined || (values.ties !== "first" && values.ties !== "random")) {
  console.error(USAGE);
  process.exit(1);
}

const shardNumber = Number(shard[1]);
const shardCount = Number(shard[2]);
const randomTies = values.ties === "random";
const out = resolve(values.out);

const scratch = mkdtempSync(join(tmpdir(), "buckshot-selfplay-"));

const player = await loadPlayer(scratch).finally(() => rmSync(scratch, { recursive: true, force: true }));

const ok = <A>(result: Result.Result<A, unknown>): A => Result.getOrThrowWith(result, (error) => new Error(String(error)));

/** The match from its seed, as begin (src/driver.ts) starts it, but with the first draw answered for the other seat when `swap`. */
const start = (seed: number, swap: boolean): Progress => {
  const first = ok(startGame(2, true, 1));
  const pending = first.game.pending;

  if (pending.kind !== "Draw" || pending.label !== "FirstSeat") throw new Error("a match does not open with the FirstSeat draw");

  const [drawn, rng] = nextBelow(seedRng(seed), pending.size);
  const step = ok(answerDraw(first.game, pending.ticket, swap ? pending.size - 1 - drawn : drawn));
  const events = [...first.events, ...step.events];
  const learned = [...first.learned, ...step.learned].map((heard) => ({ ...heard, at: events.length }));

  return ok(settleDraws({ game: step.game, rng, events, learned, ais: [], seed }));
};

/** A small hash of the match and the decision, to break ties the same way on a rerun. */
const mixed = (...parts: ReadonlyArray<number>): number => parts.reduce((state, part) => nextBelow((state ^ Math.imul(part + 1, 0x9e3779b1)) >>> 0, 2 ** 32)[0], 0x12345678);

interface Stats {
  decisions: number;
  nodes: number;
  limited: number;
  depthSum: number;
  ties: number;
}

const playMatch = (seed: number, swap: boolean, rep: number) => {
  let progress = start(seed, swap);
  const stats: Stats = { decisions: 0, nodes: 0, limited: 0, depthSum: 0, ties: 0 };
  const openings: Array<{ round: number; position: number; score: number }> = [];

  for (let guard = 0; progress.game.pending.kind === "Choose"; guard++) {
    if (guard > 5000) throw new Error(`seed ${seed}: the match did not end`);

    const prompt = Option.getOrThrow(nextPrompt(progress.game, promptsOf(progress.game)));
    const me = prompt.seat;
    const roster = rosterOf(progress.game.seats);
    const moves = ok(agentMoves(progress, roster, me));
    let index = 0;

    if (moves.length > 1) {
      const analysis = player.analyse({ table: 2, items: true, board: boardOf(progress.game), log: ownLog(progress.events, progress.learned, me), me }, limits, { rule: "static" });

      if (analysis.kind === "invalid") throw new Error(`seed ${seed}: the player cannot analyse the position: ${analysis.reason}`);

      const best = analysis.lines[analysis.best];
      const tied = analysis.lines.filter((line) => line.score === best?.score);

      stats.decisions += 1;
      stats.nodes += analysis.nodes;
      stats.limited += analysis.limited ? 1 : 0;
      stats.depthSum += analysis.depth;
      stats.ties += tied.length > 1 ? 1 : 0;

      const round = progress.events.filter(GameEvent.guards.RoundBegan).length;

      if (best !== undefined && !openings.some((opening) => opening.round === round)) openings.push({ round, position: progress.game.seats.indexOf(me) + 1, score: best.score });

      const line = randomTies ? tied[mixed(seed, swap ? 1 : 0, rep, stats.decisions) % tied.length] : best;
      const label = line === undefined ? "" : agentMoveText(roster, me, line.steps);

      index = moves.findIndex((move) => move.label === label);

      if (index < 0) throw new Error(`seed ${seed}: the player's move "${label}" is not on the menu ${JSON.stringify(moves.map((move) => move.label))}`);
    }

    progress = ok(playChain(progress, me, (moves[index] ?? moves[0])!.chain));
  }

  if (progress.game.pending.kind !== "Finished") throw new Error(`seed ${seed}: the match stopped at ${progress.game.pending.kind}`);

  const position = (seat: Seat): number => progress.game.seats.indexOf(seat) + 1;
  const rounds: Array<{ round: number; starter: number; winner: number; prize: number }> = [];

  for (const event of progress.events) {
    GameEvent.matchOrElse(
      event,
      {
        RoundBegan: ({ round, first }) => void rounds.push({ round: round + 1, starter: position(first), winner: 0, prize: 0 }),
        RoundWon: ({ seat, prize }) => void Object.assign(rounds.at(-1) ?? {}, { winner: position(seat), prize }),
      },
      () => undefined,
    );
  }

  const cash = progress.game.board.seats.map((view) => view.cash);

  return { seed, swap, rep, depth: limits.depth, budget: limits.budget, tieRule: values.ties, rounds, openings, cash, ...stats };
};

const key = (seed: number, swap: boolean, rep: number): string => `${seed}/${swap ? 1 : 0}/${rep}`;

mkdirSync(dirname(out), { recursive: true });

const decodeDone = Schema.decodeUnknownSync(
  Schema.fromJsonString(Schema.Struct({ seed: Schema.Number, swap: Schema.Boolean, rep: Schema.Number, depth: Schema.Number, budget: Schema.Number, tieRule: Schema.String })),
);

const finished = (existsSync(out) ? readFileSync(out, "utf8").split("\n") : []).filter((line) => line !== "").map((line) => decodeDone(line));

const mismatch = finished.find((match) => match.depth !== limits.depth || match.budget !== limits.budget || match.tieRule !== values.ties);

if (mismatch !== undefined) {
  console.error(`${out} holds matches played with depth ${mismatch.depth}, budget ${mismatch.budget}, ties ${mismatch.tieRule}; use another --out for these settings`);
  process.exit(1);
}

const done = new Set(finished.map(({ seed, swap, rep }) => key(seed, swap, rep)));

const started = performance.now();
let played = 0;

for (let seed = from; seed < from + count; seed++) {
  if ((seed - from) % shardCount !== shardNumber - 1) continue;

  for (let rep = 0; rep < reps; rep++) {
    for (const swap of swaps) {
      if (done.has(key(seed, swap, rep))) continue;

      appendFileSync(out, `${JSON.stringify(playMatch(seed, swap, rep))}\n`);
      played += 1;
    }
  }

  if ((seed - from) % 10 === shardNumber - 1) console.error(`seed ${seed}: ${played} matches in ${Math.round((performance.now() - started) / 1000)} s`);
}

console.error(`done: ${played} matches in ${Math.round((performance.now() - started) / 1000)} s`);
