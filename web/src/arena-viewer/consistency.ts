import { Database } from "bun:sqlite";

import { Schema } from "effect";

import type { Consistency } from "./api.ts";

// How often a config repeats itself, from the knowledge database that scripts/arena-knowledge.ts builds. An exact_key
// names one position: the same board, cash, round, log since the load, legal moves, code and instructions. Within one
// config, the chance that two different decisions in the same position chose the same move, averaged over positions.

/** A config needs this many repeated positions to be shown. */
const MIN_POSITIONS = 30;

const Z = 1.96;

const PositionRow = Schema.Struct({ model: Schema.String, effort: Schema.String, counts: Schema.String });

const decodeRow = Schema.decodeUnknownSync(PositionRow);

/** The chance two different decisions chose the same move, given how many decisions chose each move. */
export const agreement = (counts: ReadonlyArray<number>): number => {
  const decisions = counts.reduce((sum, count) => sum + count, 0);

  return counts.reduce((sum, count) => sum + count * (count - 1), 0) / (decisions * (decisions - 1));
};

/**
 * One config's repeated positions, each as its decisions' counts per move. Every position weighs the same, so the
 * few positions every match opens with do not drown the rest. The interval is the normal one over positions.
 */
export const consistencyOf = (positions: ReadonlyArray<ReadonlyArray<number>>): Pick<Consistency, "positions" | "decisions" | "agree" | "lo" | "hi"> => {
  const shares = positions.map(agreement);
  const mean = shares.reduce((sum, share) => sum + share, 0) / shares.length;
  const variance = shares.reduce((sum, share) => sum + (share - mean) ** 2, 0) / (shares.length - 1);
  const margin = Z * Math.sqrt(variance / shares.length);

  return {
    positions: positions.length,
    decisions: positions.reduce((sum, counts) => sum + counts.reduce((total, count) => total + count, 0), 0),
    agree: mean,
    lo: Math.max(0, mean - margin),
    hi: Math.min(1, mean + margin),
  };
};

/** Every config's consistency, read only. Matches with a DeepSeek seat are left out, as in the rest of the viewer. */
export const openConsistency = (path: string): ReadonlyArray<Consistency> => {
  const db = new Database(path, { readonly: true });

  // counts: the decisions that chose each move, comma separated, of a position the config met at least twice.
  const rows = db
    .query(
      `select model, effort, group_concat(moves) counts from (
         select p.model, p.effort, d.exact_key position, d.choice, count(*) moves from decisions d join players p on p.match_id = d.match_id and p.player = d.player
         where d.by_whom = 'agent' and d.match_id not in (select match_id from players where model = 'oc/deepseek-v4.1-flash-free')
         group by p.model, p.effort, d.exact_key, d.choice)
       group by model, effort, position having sum(moves) >= 2`,
    )
    .all()
    .map((raw) => decodeRow(raw));

  const positionsOf = new Map<string, { readonly model: string; readonly effort: string; readonly positions: Array<ReadonlyArray<number>> }>();

  for (const { model, effort, counts } of rows) {
    const config = positionsOf.get(`${model}|${effort}`) ?? { model, effort, positions: [] };

    config.positions.push(counts.split(",").map(Number));
    positionsOf.set(`${model}|${effort}`, config);
  }

  return [...positionsOf.values()].flatMap(({ model, effort, positions }) => (positions.length < MIN_POSITIONS ? [] : [{ model, effort, ...consistencyOf(positions) }]));
};
