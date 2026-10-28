import { type Blunders, type Decisions, ITEMS, type Mistakes } from "../api.ts";
import { addTo, baseName, type BlockTally, blockRate, configShare, groupBy, keyOf, type MatchRow, matchRows, type ModelStats, modelStats, rankOrder, type Rate, type SeatFull } from "./data.ts";
import type { Basis, Filter, Loaded } from "./model.ts";
import { pooledRatings, type Rating } from "./ratings.ts";

// What the page shows, worked out from the loaded data and the filter. Each is
// recomputed only when its inputs change, so hovering a chart stays cheap.

/** Remembers the last result, recomputing only when an argument changes identity. */
export const memoLast = <Args extends ReadonlyArray<object | string | number | boolean>, Result>(compute: (...args: Args) => Result) => {
  let last: { readonly args: Args; readonly result: Result } | undefined;

  return (...args: Args): Result => {
    if (last !== undefined && last.args.length === args.length && last.args.every((arg, index) => arg === args[index])) return last.result;

    const result = compute(...args);

    last = { args, result };

    return result;
  };
};

export interface ItemSummary {
  /** Uses of each item over the agent moves where using it was legal. */
  readonly useLegal: ReadonlyArray<Rate>;
  /** Own copies used over copies acquired. */
  readonly acqUse: ReadonlyArray<Rate>;
  /** Steals of each item over the moves where stealing it was legal. */
  readonly steal: ReadonlyArray<Rate>;
  readonly favorite: { readonly item: string; readonly rate: number; readonly k: number; readonly n: number } | null;
  /** Player-matches that used more copies than they acquired. */
  readonly violations: ReadonlyArray<number>;
}

const MIN_LEGAL = 30;

interface ItemTally {
  readonly use: ReadonlyArray<BlockTally>;
  readonly acq: ReadonlyArray<BlockTally>;
  readonly steal: ReadonlyArray<BlockTally>;
  readonly bad: Array<number>;
}

/** Per cohort and config. A steal with adrenaline counts as an adrenaline use and, separately, as a steal of the item taken. */
const itemSummaries = (decisions: Decisions, seats: ReadonlyArray<SeatFull>): ReadonlyMap<string, ItemSummary> => {
  const tallies = new Map<string, ItemTally>();

  const tallyOf = (seat: SeatFull): ItemTally => {
    const id = `${seat.cohort}||${keyOf(seat)}`;
    const known = tallies.get(id);

    if (known) return known;

    const fresh: ItemTally = { use: ITEMS.map(() => new Map()), acq: ITEMS.map(() => new Map()), steal: ITEMS.map(() => new Map()), bad: ITEMS.map(() => 0) };

    tallies.set(id, fresh);

    return fresh;
  };

  const tallyOfSeat = seats.map(tallyOf);

  decisions.seat.forEach((seatIndex, move) => {
    const seat = seats[seatIndex];
    const tally = tallyOfSeat[seatIndex];

    if (seat === undefined || tally === undefined) return;

    const legalUse = decisions.legalUse[move] ?? 0;
    const legalSteal = decisions.legalSteal[move] ?? 0;

    ITEMS.forEach((_item, index) => {
      const use = tally.use[index];
      const steal = tally.steal[index];

      if (use && legalUse & (1 << index)) addTo(use, seat.seedBlock, decisions.useItem[move] === index ? 1 : 0, 1);

      if (steal && legalSteal & (1 << index)) addTo(steal, seat.seedBlock, decisions.stealItem[move] === index ? 1 : 0, 1);
    });
  });

  seats.forEach((seat) => {
    const tally = tallyOf(seat);

    // "Use X" moves only ever spend own copies; each adrenaline steal spends one own adrenaline. Overuse is reported, not clamped.
    seat.acquired.forEach((acquired, index) => {
      const used = seat.used[index] ?? 0;
      const acq = tally.acq[index];

      if (acquired > 0 && acq) addTo(acq, seat.seedBlock, used, acquired);

      if (used > acquired) tally.bad[index] = (tally.bad[index] ?? 0) + 1;
    });
  });

  return new Map(
    [...tallies].map(([id, tally]) => {
      const useLegal = tally.use.map((use) => blockRate(use, 200));
      const best = useLegal.reduce<{ readonly index: number; readonly rate: Rate } | null>((found, rate, index) => (rate.n >= MIN_LEGAL && (found === null || rate.rate > found.rate.rate) ? { index, rate } : found), null);

      return [
        id,
        {
          useLegal,
          acqUse: tally.acq.map((acq) => blockRate(acq, 200)),
          steal: tally.steal.map((steal) => blockRate(steal, 200)),
          favorite: best === null ? null : { item: ITEMS[best.index] ?? "", rate: best.rate.rate, k: best.rate.k, n: best.rate.n },
          violations: tally.bad,
        },
      ] as const;
    }),
  );
};

export interface Derived {
  readonly seats: ReadonlyArray<SeatFull>;
  readonly decisions: Decisions;
  readonly blunders: Blunders;
  readonly mistakes: Mistakes;
  readonly consistency: Loaded["consistency"];
  /** Whether each seat, by index, passes the filter. */
  readonly keep: ReadonlyArray<boolean>;
  readonly filtered: ReadonlyArray<SeatFull>;
  /** Both seats of any match where either seat passes the filter, so opponents stay visible. */
  readonly matchSeats: ReadonlyArray<SeatFull>;
  readonly byCohort: ReadonlyArray<ModelStats>;
  readonly pooled: ReadonlyArray<ModelStats>;
  /** What the ratings count: win shares, pot shares or rounds. */
  readonly basis: Basis;
  /** One rating per config on that basis, fitted over every match of every tournament: filters pick rows, not the scale. */
  readonly ratings: ReadonlyMap<string, Rating>;
  /**
   * Each config's place among all the chosen cohort's configs whatever the filter: by observed share within one
   * cohort (see rankOrder), by rating under "All cohorts", since pooling every cohort would count effort sweeps' self-play.
   */
  readonly ranks: ReadonlyMap<string, number>;
  /** Every config pooled over each cohort and over all of them, whatever the filter: the scatter's fixed axes. */
  readonly everyPooled: ReadonlyArray<ModelStats>;
  /** Every config of every cohort, whatever the filter: leaderboard places. */
  readonly everyByCohort: ReadonlyArray<ModelStats>;
  readonly matches: ReadonlyArray<MatchRow>;
  readonly allMatches: ReadonlyArray<MatchRow>;
  /** Every cohort and config, whether the filter keeps it or not. */
  readonly items: ReadonlyMap<string, ItemSummary>;
}

// A filter keeps or drops whole configs of a cohort, so whatever is grouped by cohort and config is worked out
// once for every seat and then picked by the filter.

// Each basis is fitted when first asked for, and kept, so the load pays only for the win ratings and switching back is free.
export const ratingsOf = memoLast((seats: ReadonlyArray<SeatFull>) => {
  const fitted = new Map<Basis, ReadonlyMap<string, Rating>>();

  return (basis: Basis): ReadonlyMap<string, Rating> => {
    const known = fitted.get(basis);

    if (known) return known;

    const fresh = pooledRatings(seats, basis);

    fitted.set(basis, fresh);

    return fresh;
  };
});

const allMatchesOf = memoLast((seats: ReadonlyArray<SeatFull>) => matchRows(seats));

const byCohortOf = memoLast((seats: ReadonlyArray<SeatFull>) => modelStats(seats, true));

const itemsOf = memoLast((decisions: Decisions, seats: ReadonlyArray<SeatFull>) => itemSummaries(decisions, seats));

// Every config pooled over one cohort or all of them, kept per cohort so switching back is free.
const pooledByCohort = memoLast((seats: ReadonlyArray<SeatFull>) => {
  const pooled = new Map<string, ReadonlyArray<ModelStats>>();

  return (cohort: string): ReadonlyArray<ModelStats> => {
    const known = pooled.get(cohort);

    if (known) return known;

    const fresh = modelStats(cohort === "all" ? seats : seats.filter((seat) => seat.cohort === cohort));

    pooled.set(cohort, fresh);

    return fresh;
  };
});

/** A main config has at least this many scored matches. */
const MIN_SCORED = 20;

/**
 * The configs shown by default: those with a scored match against another model and at least MIN_SCORED scored
 * matches. The rest only played their own model's effort sweep, or too few matches.
 */
export const mainConfigsOf = memoLast((seats: ReadonlyArray<SeatFull>): ReadonlySet<string> => {
  const modelsIn = new Map([...groupBy(seats, ({ matchId }) => matchId)].map(([matchId, both]) => [matchId, new Set(both.map(({ model }) => model)).size]));
  const scored = [...groupBy(seats.filter(({ status }) => status === "completed"), keyOf)];

  return new Set(scored.flatMap(([key, played]) => (new Set(played.map(({ matchId }) => matchId)).size >= MIN_SCORED && played.some(({ matchId }) => (modelsIn.get(matchId) ?? 0) > 1) ? [key] : [])));
});

const passes = (filter: Filter, main: ReadonlySet<string>, seat: SeatFull): boolean =>
  (filter.cohort === "all" || seat.cohort === filter.cohort) &&
  !filter.offEfforts.includes(seat.effort) &&
  !filter.offModels.includes(baseName(seat.model)) &&
  (filter.isAllConfigs || main.has(keyOf(seat)));

const passingConfigs = (stats: ReadonlyArray<ModelStats>, filter: Filter, main: ReadonlySet<string>) => stats.filter(({ started: [first] }) => first !== undefined && passes(filter, main, first));

const ranksOf = memoLast((pooled: ReadonlyArray<ModelStats>, ratings: ReadonlyMap<string, Rating>, cohort: string, basis: Basis): ReadonlyMap<string, number> => {
  const rated = pooled.filter((m) => m.scored.length > 0 && ratings.has(m.key));
  const eloOf = (m: ModelStats) => ratings.get(m.key)?.rating ?? 0;
  const ordered = cohort === "all" ? rated.toSorted((left, right) => eloOf(right) - eloOf(left) || left.label.localeCompare(right.label)) : rankOrder(rated, (m) => configShare(m, basis), eloOf);

  return new Map(ordered.map((m, index) => [m.key, index + 1]));
});

const everyPooledOf = memoLast((seats: ReadonlyArray<SeatFull>): ReadonlyArray<ModelStats> => {
  const pooledIn = pooledByCohort(seats);

  return ["all", ...new Set(seats.map(({ cohort }) => cohort))].flatMap(pooledIn);
});

export const derive = memoLast((loaded: Loaded, filter: Filter, basis: Basis): Derived => {
  const { seats, decisions, blunders, mistakes, consistency } = loaded;
  const main = mainConfigsOf(seats);
  const keep = seats.map((seat) => passes(filter, main, seat));
  const filtered = seats.filter((_seat, index) => keep[index]);
  const kept = new Set(filtered.map(({ matchId }) => matchId));
  const matchSeats = seats.filter(({ matchId }) => kept.has(matchId));
  const inCohort = pooledByCohort(seats)(filter.cohort);
  const ratings = ratingsOf(seats)(basis);

  return {
    seats,
    decisions,
    blunders,
    mistakes,
    consistency,
    keep,
    filtered,
    matchSeats,
    byCohort: passingConfigs(byCohortOf(seats), filter, main),
    pooled: passingConfigs(inCohort, filter, main),
    basis,
    ratings,
    ranks: ranksOf(inCohort, ratings, filter.cohort, basis),
    everyPooled: everyPooledOf(seats),
    everyByCohort: byCohortOf(seats),
    matches: matchRows(matchSeats),
    allMatches: allMatchesOf(seats),
    items: itemsOf(decisions, seats),
  };
});
