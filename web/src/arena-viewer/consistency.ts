import { Database } from "bun:sqlite";

import { Schema } from "effect";

import type { Consistency } from "./api.ts";
import { groupBy, quantile, rng } from "./page/data.ts";

// How often a config repeats itself, from the knowledge database that scripts/arena-knowledge.ts builds. An exact_key
// names one position: the same board, cash, round, log since the load, legal moves, code and instructions. Within one
// config, the chance that two different decisions in the same position chose the same move, averaged over positions.
// The estimate and its interval are the ones docs/arena/analysis/beliefs-and-items.md reports.

/** A config needs this many repeated positions to be shown. */
const MIN_POSITIONS = 30;

const DRAWS = 1000;

/** One decision in a repeated position: the move it chose and the seed block of its match. */
export interface Repeat {
  readonly choice: string;
  readonly block: string;
}

/**
 * One config's repeated positions, and the seed blocks of all its decisions, which a resample draws from. Every position weighs the same, so the few positions every match opens with do not
 * drown the rest. The interval is a 95% percentile bootstrap that resamples seed blocks. Within a resample a pair of
 * distinct decisions weighs the product of its blocks' counts and a decision never pairs with itself, so a block drawn
 * twice cannot agree with its own copy.
 */
export const consistencyOf = (positions: ReadonlyArray<ReadonlyArray<Repeat>>, everyBlock: Iterable<string> = positions.flat().map(({ block }) => block)): Pick<Consistency, "positions" | "agree" | "lo" | "hi"> => {
  const blockIds = new Map<string, number>();
  const idOf = (ids: Map<string, number>, value: string) => ids.get(value) ?? (ids.set(value, ids.size), ids.size - 1);

  for (const block of everyBlock) idOf(blockIds, block);

  // Every decision in one run, each position's from its start to the next one's; a choice is numbered within its position.
  const decisions = positions.flat();
  const starts = new Int32Array(positions.length + 1);

  positions.forEach((repeats, index) => (starts[index + 1] = (starts[index] ?? 0) + repeats.length));

  const blocks = Int32Array.from(decisions, ({ block }) => idOf(blockIds, block));

  const choices = Int32Array.from(
    positions.flatMap((repeats) => {
      const local = new Map<string, number>();

      return repeats.map(({ choice }) => idOf(local, choice));
    }),
  );

  const sums = new Float64Array(decisions.length);
  const squares = new Float64Array(decisions.length);

  const meanOver = (weights: Float64Array): number => {
    let [total, counted] = [0, 0];

    for (let position = 0; position < positions.length; position++) {
      const [from, to] = [starts[position] ?? 0, starts[position + 1] ?? 0];

      sums.fill(0, 0, to - from);
      squares.fill(0, 0, to - from);

      for (let index = from; index < to; index++) {
        const weight = weights[blocks[index] ?? 0] ?? 0;
        const choice = choices[index] ?? 0;

        sums[choice] = (sums[choice] ?? 0) + weight;
        squares[choice] = (squares[choice] ?? 0) + weight * weight;
      }

      let [agreeing, weight, square] = [0, 0, 0];

      for (let choice = 0; choice < to - from; choice++) {
        agreeing += (sums[choice] ?? 0) ** 2 - (squares[choice] ?? 0);
        weight += sums[choice] ?? 0;
        square += squares[choice] ?? 0;
      }

      const pairs = weight * weight - square;

      if (pairs > 0) {
        total += agreeing / pairs;
        counted++;
      }
    }

    return counted === 0 ? Number.NaN : total / counted;
  };

  const random = rng(11);

  const draws = Array.from({ length: DRAWS }, () => {
    const weights = new Float64Array(blockIds.size);

    for (let draw = 0; draw < blockIds.size; draw++) {
      const block = Math.floor(random() * blockIds.size);

      weights[block] = (weights[block] ?? 0) + 1;
    }

    return meanOver(weights);
  })
    .filter((value) => !Number.isNaN(value))
    .toSorted((left, right) => left - right);

  return { positions: positions.length, agree: meanOver(new Float64Array(blockIds.size).fill(1)), lo: quantile(draws, 0.025), hi: quantile(draws, 0.975) };
};

const DecisionRow = Schema.Struct({ matchId: Schema.String, model: Schema.String, effort: Schema.String, position: Schema.String, choice: Schema.String });

const decodeRow = Schema.decodeUnknownSync(DecisionRow);

/**
 * Every config's consistency, read only. Only the agents' own moves in the matches the viewer shows count, so
 * DeepSeek's matches are left out here as everywhere. `seedBlocks` maps each shown match to its seed block.
 */
export const openConsistency = (path: string, seedBlocks: ReadonlyMap<string, string>): ReadonlyArray<Consistency> => {
  const db = new Database(path, { readonly: true });

  const rows = db
    .query(`select d.match_id matchId, p.model, p.effort, d.exact_key position, d.choice from decisions d join players p on p.match_id = d.match_id and p.player = d.player where d.by_whom = 'agent'`)
    .all()
    .map((raw) => decodeRow(raw));

  db.close();

  const scoped = rows.flatMap((row) => {
    const block = seedBlocks.get(row.matchId);

    return block === undefined ? [] : [{ row, repeat: { choice: row.choice, block } }];
  });

  return [...groupBy(scoped, ({ row }) => `${row.model}|${row.effort}`).values()].flatMap((config) => {
    const [first] = config;
    const repeated = [...groupBy(config, ({ row }) => row.position).values()].filter((decisions) => decisions.length >= 2);

    return first === undefined || repeated.length < MIN_POSITIONS
      ? []
      : [{ model: first.row.model, effort: first.row.effort, ...consistencyOf(repeated.map((decisions) => decisions.map(({ repeat }) => repeat)), new Set(config.map(({ repeat }) => repeat.block))) }];
  });
};
