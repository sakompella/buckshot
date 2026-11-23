import { existsSync } from "node:fs";
import { parseArgs } from "node:util";

import { Console, Effect, Schema } from "effect";

import { openArena } from "../src/arena-viewer/load.ts";
import { groupBy, keyOf, meanOf, withPotShares } from "../src/arena-viewer/page/data.ts";
import type { SeatFull } from "../src/arena-viewer/page/data.ts";
import { MOVES_BELOW, playAndMoveRatings } from "../src/arena-viewer/page/play-and-moves.ts";
import { fittedRatings, INTERVAL_Z, pairsOf } from "../src/arena-viewer/page/ratings.ts";
import type { Luck, Rating } from "../src/arena-viewer/page/ratings.ts";
import { mulberry32 } from "../src/arena/tournament-stats.ts";
import { decodeArgs, runMain, ScriptError } from "../src/script.ts";

// The split-half test behind ADR-0060: the seed blocks are split in two at random, each half is rated with the
// production fit (fittedRatings, then the rule of play-and-moves.ts), and the half's ratings are compared with the
// other half's results-only ratings. The comparison is over the language-model configs both halves rate from play and
// move quality. "Real error" is the RMS difference after removing the other half's own noise (its interval's SD).
// The differences are centred on their mean in each comparison, because the engine anchor's own noise is in no interval. Coverage counts a config when the difference is within the 90% z of the two halves' SDs together. Top six: the six
// configs with the highest results-only rating on all the data; z is signed, a positive z has the half above the other.

const USAGE = "usage: bun scripts/arena-split-half.ts <db> --regret <regret db> --luck <luck db> [--splits 30] [--below N]";

const Flags = Schema.Struct({ regret: Schema.String, luck: Schema.String, splits: Schema.optional(Schema.FiniteFromString), below: Schema.optional(Schema.FiniteFromString) });

const usage = () => ScriptError.make({ message: USAGE, exitCode: 1 });

const SEED = 20_261_114;

const sdOf = (rating: Rating): number => (rating.interval === null ? Number.NaN : (rating.interval.hi - rating.interval.lo) / (2 * INTERVAL_Z));

interface Half {
  /** Each config's results-only rating. */
  readonly results: ReadonlyMap<string, Rating>;
  /** Each config's rating under the rule: from play and move quality below the threshold, else results only. */
  readonly rule: ReadonlyMap<string, Rating>;
  /** Configs with a rating from play and move quality. */
  readonly moves: ReadonlySet<string>;
}

const halfOf = (seats: ReadonlyArray<SeatFull>, luck: Luck, below: number): Half => {
  const fitted = fittedRatings(seats, luck);
  const moves = playAndMoveRatings(fitted.ratings, seats);
  const matches = groupBy(pairsOf(seats).flat(), keyOf);
  const rule = new Map(fitted.ratings);

  for (const [key, rating] of moves) { if ((matches.get(key)?.length ?? 0) < below) { rule.set(key, rating); } }

  return { results: fitted.ratings, rule, moves: new Set(moves.keys()) };
};

interface Score {
  readonly squared: number;
  readonly noise: number;
  readonly z: number;
  readonly width: number;
}

interface Gap {
  readonly key: string;
  readonly gap: number;
  readonly ownSd: number;
  readonly otherSd: number;
}

const gapOf = (key: string, own: Rating, other: Rating): Gap => ({ key, gap: own.rating - other.rating, ownSd: sdOf(own), otherSd: sdOf(other) });

/** The scores of one comparison, its gaps centred: each half's ratings are anchored to the engine, whose own noise the intervals leave out, so a common offset says nothing about the configs. */
const scoresOf = (gaps: ReadonlyArray<Gap>): ReadonlyArray<readonly [string, Score]> => {
  const offset = meanOf(gaps.map(({ gap }) => gap));

  return gaps.map(({ key, gap, ownSd, otherSd }) => [key, { squared: (gap - offset) ** 2, noise: otherSd ** 2, z: (gap - offset) / Math.hypot(ownSd, otherSd), width: ownSd * INTERVAL_Z }] as const);
};

const report = (name: string, scores: ReadonlyArray<Score>, top: ReadonlyArray<Score>): string => {
  const real = Math.sqrt(Math.max(0, meanOf(scores.map(({ squared }) => squared)) - meanOf(scores.map(({ noise }) => noise))));
  const covered = scores.filter(({ z }) => Math.abs(z) <= INTERVAL_Z).length / scores.length;

  return `${name}: real error ${real.toFixed(1)} Elo, coverage ${(100 * covered).toFixed(1)}%, top six mean z ${meanOf(top.map(({ z }) => z)).toFixed(2)}, top six widest half-width ${Math.max(...top.map(({ width }) => width)).toFixed(1)} Elo (${scores.length} comparisons)`;
};

const program = Effect.gen(function* () {
  const options = { regret: { type: "string" }, luck: { type: "string" }, splits: { type: "string" }, below: { type: "string" } } as const;
  const parsed = yield* Effect.try({ try: () => parseArgs({ allowPositionals: true, options }), catch: usage });
  const { regret, luck, splits = 30, below = MOVES_BELOW / 2 } = yield* decodeArgs(Flags, USAGE)(parsed.values);
  const [dbPath] = parsed.positionals;
  const db = yield* dbPath === undefined || !existsSync(dbPath) || !existsSync(regret) || !existsSync(luck) ? usage() : Effect.succeed(dbPath);
  const arena = yield* openArena(db, { regret, luck });
  const seats = withPotShares(arena.seats);
  const blocks = [...new Set(seats.map(({ seedBlock }) => seedBlock))];
  const all = halfOf(seats, arena.luck, 0);
  const random = mulberry32(SEED);
  const results: Array<Score> = [];
  const rule: Array<Score> = [];
  const topResults: Array<Score> = [];
  const topRule: Array<Score> = [];
  const top = new Set([...all.moves].toSorted((a, b) => (all.results.get(b)?.rating ?? 0) - (all.results.get(a)?.rating ?? 0)).slice(0, 6));

  for (let split = 0; split < splits; split++) {
    const chosen = new Set(blocks.filter(() => random() < 0.5));
    const halves = [halfOf(seats.filter(({ seedBlock }) => chosen.has(seedBlock)), arena.luck, below), halfOf(seats.filter(({ seedBlock }) => !chosen.has(seedBlock)), arena.luck, below)] as const;

    for (const [own, other] of [[halves[0], halves[1]], [halves[1], halves[0]]] as const) {
      const plain: Array<Gap> = [];
      const combined: Array<Gap> = [];

      for (const key of own.moves) {
        const theirs = other.results.get(key);
        const ours = own.results.get(key);
        const ruled = own.rule.get(key);

        if (!other.moves.has(key) || theirs === undefined || ours === undefined || ruled === undefined) { continue; }

        plain.push(gapOf(key, ours, theirs));
        combined.push(gapOf(key, ruled, theirs));
      }

      for (const [key, score] of scoresOf(plain)) {
        results.push(score);

        if (top.has(key)) { topResults.push(score); }
      }

      for (const [key, score] of scoresOf(combined)) {
        rule.push(score);

        if (top.has(key)) { topRule.push(score); }
      }
    }
  }

  yield* Console.log(`${pairsOf(seats).length} scored two-player matches in ${blocks.length} seed blocks, ${splits} random halvings, the rule below ${below} matches per half`);
  yield* Console.log(report("results only", results, topResults));
  yield* Console.log(report("with the rule", rule, topRule));
}).pipe(Effect.scoped);

await runMain(program);
