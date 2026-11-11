import type { ConfigSummary, Pair, Runs } from "../aggregates.ts";
import { baseName, colorOf, DASH, isProvisional, keyOf, labelOf, type MatchRow, matchRows, type SeatFull } from "./data.ts";
import type { Filter, Loaded } from "./model.ts";
import type { Rating } from "./ratings.ts";

// What the page shows, worked out from the loaded aggregates and the filter. Each is recomputed only when its inputs
// change, so hovering a chart stays cheap.

export const memoLast = <Args extends ReadonlyArray<object | string | number | boolean>, Result>(compute: (...args: Args) => Result) => {
  let last: { readonly args: Args; readonly result: Result } | undefined;

  return (...args: Args): Result => {
    if (last !== undefined && last.args.length === args.length && last.args.every((arg, index) => arg === args[index])) return last.result;

    const result = compute(...args);

    last = { args, result };

    return result;
  };
};

/** A config's stats as the page draws them. */
export interface ModelStats extends ConfigSummary {
  /** The config key. */
  readonly key: string;
  readonly label: string;
  readonly color: string;
  readonly dash: string;
}

export interface Derived {
  /** Every config, kept or not. */
  readonly everyPooled: ReadonlyArray<ModelStats>;
  readonly pooled: ReadonlyArray<ModelStats>;
  /** The keys of the configs the filter keeps. */
  readonly kept: ReadonlySet<string>;
  /** One round-win rating per config, fitted over every match of every tournament: filters pick rows, not the scale. */
  readonly ratings: ReadonlyMap<string, Rating>;
  readonly ranks: ReadonlyMap<string, number>;
  /** The pairs with a kept config on either side: a match counts when either of its configs is kept. */
  readonly pairs: ReadonlyArray<Pair>;
  readonly hasCertain: boolean;
  /** The first and last day a match started, when the aggregate files carry it. */
  readonly runs: Runs | undefined;
}

// A filter keeps or drops whole configs, so whatever is grouped by config is worked out once for every config and then
// picked by the filter.

export const modelStatsOf = memoLast((configs: ReadonlyArray<ConfigSummary>): ReadonlyArray<ModelStats> =>
  configs.map((config) => {
    const key = keyOf(config);

    return { ...config, key, label: labelOf(key), color: colorOf(config.model), dash: DASH.get(config.effort) ?? "" };
  }),
);

const ratingsOf = memoLast((every: ReadonlyArray<ModelStats>): ReadonlyMap<string, Rating> => new Map(every.flatMap(({ key, rating }) => (rating === null ? [] : [[key, rating] as const]))));

const passes = (filter: Filter, config: Pick<ConfigSummary, "model" | "effort">): boolean => !filter.offEfforts.includes(config.effort) && !filter.offModels.includes(baseName(config.model));

/** Each rated config's place by rating, ties by label so places are distinct; a provisional config or one without a rating has none. */
export const ranksOf = memoLast((pooled: ReadonlyArray<ModelStats>, ratings: ReadonlyMap<string, Rating>): ReadonlyMap<string, number> => {
  const eloOf = (m: ModelStats) => ratings.get(m.key)?.rating ?? 0;
  const ordered = pooled.filter((m) => !isProvisional(m) && ratings.has(m.key)).toSorted((left, right) => eloOf(right) - eloOf(left) || left.label.localeCompare(right.label));

  return new Map(ordered.map((m, index) => [m.key, index + 1]));
});

export const derive = memoLast((loaded: Loaded, filter: Filter): Derived => {
  const every = modelStatsOf(loaded.summary.configs);
  const pooled = every.filter((m) => passes(filter, m));
  const kept = new Set(pooled.map(({ key }) => key));
  const ratings = ratingsOf(every);

  return {
    everyPooled: every,
    pooled,
    kept,
    ratings,
    ranks: ranksOf(every, ratings),
    pairs: loaded.pairs.filter(({ first, second }) => kept.has(first) || kept.has(second)),
    hasCertain: loaded.summary.hasCertain,
    runs: loaded.summary.runs,
  };
});

/** Every match. */
export const allMatchesOf = memoLast((seats: ReadonlyArray<SeatFull>): ReadonlyArray<MatchRow> => matchRows(seats));

/** The matches with a kept config in either seat. */
export const keptMatchesOf = memoLast((matches: ReadonlyArray<MatchRow>, kept: ReadonlySet<string>): ReadonlyArray<MatchRow> => matches.filter(({ seats }) => seats.some((seat) => kept.has(keyOf(seat)))));
