import { mkdirSync, mkdtempSync, rmSync, writeFileSync } from "node:fs";
import { tmpdir } from "node:os";
import { dirname, join, resolve } from "node:path";
import { parseArgs } from "node:util";

import { Option, Result, Schema } from "effect";

import { agentMoves, playChain } from "../src/agent/moves.ts";
import { moveCode, nativeInput } from "../src/analysis/native-input.ts";
import { boardOf, loadPlayer, ownLog, RELOAD_RULES, type Memo, type Reload } from "../src/analysis/player.ts";
import { nextPrompt } from "../src/bend.ts";
import { SeatCount } from "../src/domain.ts";
import { begin, promptsOf } from "../src/driver.ts";
import { rosterOf } from "../src/players.ts";
import { nextBelow, seedRng } from "../src/rng.ts";

// Writes synthetic 2/3/4-seat input rows for the Rust searcher (sim/rust/search) and its oracle comparison, in the row
// shape of rust-search-inputs.ts with its --js fields always present: {id, ordinal, me, table, input, menu, chosen, js, ms}.
// Games are played with random legal choices and random draws from the seed; up to --per-game decision points with two
// or more options per game are analysed by the JS player and emitted.
//
//   bun scripts/rust-search-synth.ts --out <file.jsonl> [--tables 2,3,4] [--games 5] [--per-game 4] [--seed 1] [--memo off|charged|free] [--depth 6] [--budget 20000] [--reload static|sampled] [--samples 256]
//
// Under --reload sampled only 2-seat tables are generated.

const { values } = parseArgs({
  args: process.argv.slice(2),
  options: { tables: { type: "string", default: "2,3,4" }, games: { type: "string", default: "5" }, "per-game": { type: "string", default: "4" }, seed: { type: "string", default: "1" }, memo: { type: "string", default: "off" }, depth: { type: "string", default: "6" }, budget: { type: "string", default: "20000" }, reload: { type: "string", default: "static" }, samples: { type: "string", default: "256" }, out: { type: "string" } },
});

const isRule = Schema.is(Schema.Literals(RELOAD_RULES));
const isMemo = Schema.is(Schema.Literals(["off", "charged", "free"]));
const isSeatCount = Schema.is(SeatCount);

const depth = Number(values.depth);
const budget = Number(values.budget);
const samples = Number(values.samples);
const games = Number(values.games);
const perGame = Number(values["per-game"]);
const baseSeed = Number(values.seed);
const requested = values.tables.split(",").map(Number);

if (values.out === undefined || !isRule(values.reload) || !isMemo(values.memo) || !requested.every(isSeatCount) || ![depth, budget, samples, games, perGame].every((n) => Number.isSafeInteger(n) && n >= 1) || !Number.isSafeInteger(baseSeed)) {
  console.error("Usage: bun scripts/rust-search-synth.ts --out <file.jsonl> [--tables 2,3,4] [--games N] [--per-game N] [--seed N] [--memo off|charged|free] [--depth N] [--budget N] [--reload static|sampled] [--samples N]");
  process.exit(1);
}

const limits = { depth, budget };
const reload: Reload = values.reload === "sampled" ? { rule: "sampled", samples } : { rule: values.reload };
const memo: Memo = values.memo;
const tables = requested.filter((table) => values.reload !== "sampled" || table === 2);

const scratch = mkdtempSync(join(tmpdir(), "buckshot-rust-synth-"));
const player = await loadPlayer(scratch).finally(() => rmSync(scratch, { recursive: true, force: true }));

const ok = <A>(result: Result.Result<A, unknown>): A => Result.getOrThrowWith(result, (error) => new Error(String(error)));

/** Plays one game with random legal choices. Analyses and emits the decision points whose index is in `chosen`; returns how many decision points had two or more options. */
const playGame = (table: SeatCount, game: number, seed: number, chosen: ReadonlySet<number>, rows: Array<string>): number => {
  let progress = ok(begin(table, true, 1, seedRng(seed), [], seed));
  let choice = seedRng(seed ^ 0x5bd1e995);
  let eligible = 0;

  for (let guard = 0; progress.game.pending.kind === "Choose"; guard++) {
    if (guard > 5000) throw new Error(`seed ${seed}: the game did not end`);

    const prompt = Option.getOrThrow(nextPrompt(progress.game, promptsOf(progress.game)));
    const me = prompt.seat;
    const roster = rosterOf(progress.game.seats);
    const moves = ok(agentMoves(progress, roster, me));
    let index = 0;

    if (moves.length > 1) {
      const [pick, next] = nextBelow(choice, moves.length);
      choice = next;
      index = pick;

      if (chosen.has(eligible)) {
        const input = { table: progress.game.table, items: true, board: boardOf(progress.game), log: ownLog(progress.events, progress.learned, me), me };
        const started = performance.now();
        const analysis = player.analyse(input, limits, reload, memo);
        const ms = performance.now() - started;

        const js =
          analysis.kind === "invalid"
            ? analysis
            : { kind: analysis.kind, best: analysis.best, score: analysis.lines[analysis.best]?.score, nodes: analysis.nodes, depth: analysis.depth, limited: analysis.limited, ...analysis.cached, lines: analysis.lines.map((line) => ({ code: moveCode(line.steps), score: line.score, reach: line.reach })) };

        rows.push(JSON.stringify({ id: `synth-${table}-${game}`, ordinal: eligible, me, table: input.table, input: nativeInput(input), menu: moves.map((move) => move.label), chosen: moves[index]?.label, js, ms }));
      }

      eligible += 1;
    }

    const move = moves[index];

    if (move === undefined) throw new Error(`seed ${seed}: no move at index ${index}`);

    progress = ok(playChain(progress, me, move.chain));
  }

  return eligible;
};

const rows: Array<string> = [];
const counts: Record<number, number> = {};

for (const table of tables) {
  for (let game = 0; game < games; game++) {
    const seed = baseSeed * 1000003 + table * 10007 + game;
    const total = playGame(table, game, seed, new Set(), []);
    let pick = seedRng(seed ^ 0x2545f491);
    const indices = new Set<number>();
    const want = Math.min(perGame, total);

    while (indices.size < want) {
      const [value, next] = nextBelow(pick, total);
      pick = next;
      indices.add(value);
    }

    const before = rows.length;

    playGame(table, game, seed, indices, rows);
    counts[table] = (counts[table] ?? 0) + rows.length - before;
  }
}

mkdirSync(dirname(resolve(values.out)), { recursive: true });

writeFileSync(resolve(values.out), rows.join("\n") + "\n");

console.error(`${rows.length} rows ${JSON.stringify(counts)}`);
