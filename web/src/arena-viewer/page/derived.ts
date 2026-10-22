import { type Decisions, ITEMS } from "../api.ts";
import { addTo, approxRatings, baseName, type BlockTally, blockRate, keyOf, type MatchRow, matchRows, type ModelStats, modelStats, type Rate, type SeatFull } from "./data.ts";
import type { Filter, Loaded } from "./model.ts";

// What the tabs show, worked out from the loaded data and the filter. Each is
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
  /** Whether each seat, by index, passes the filter. */
  readonly keep: ReadonlyArray<boolean>;
  readonly filtered: ReadonlyArray<SeatFull>;
  /** Both seats of any match where either seat passes the filter, so opponents stay visible. */
  readonly matchSeats: ReadonlyArray<SeatFull>;
  readonly byCohort: ReadonlyArray<ModelStats>;
  readonly pooled: ReadonlyArray<ModelStats>;
  /** One approximate scale fitted on every seat: filters pick rows, not the scale. */
  readonly ratings: ReadonlyMap<string, number>;
  readonly matches: ReadonlyArray<MatchRow>;
  readonly allMatches: ReadonlyArray<MatchRow>;
  /** Every cohort and config, whether the filter keeps it or not. */
  readonly items: ReadonlyMap<string, ItemSummary>;
}

// A filter keeps or drops whole configs of a cohort, so whatever is grouped by cohort and config is worked out
// once for every seat and then picked by the filter.

const ratingsOf = memoLast((seats: ReadonlyArray<SeatFull>) => approxRatings(seats));

const allMatchesOf = memoLast((seats: ReadonlyArray<SeatFull>) => matchRows(seats));

const byCohortOf = memoLast((seats: ReadonlyArray<SeatFull>) => modelStats(seats, true));

const itemsOf = memoLast((decisions: Decisions, seats: ReadonlyArray<SeatFull>) => itemSummaries(decisions, seats));

const pooledOf = memoLast((seats: ReadonlyArray<SeatFull>, cohort: string) => modelStats(cohort === "all" ? seats : seats.filter((seat) => seat.cohort === cohort)));

const passes = (filter: Filter, seat: SeatFull): boolean =>
  (filter.cohort === "all" || seat.cohort === filter.cohort) && !filter.offEfforts.includes(seat.effort) && !filter.offModels.includes(baseName(seat.model));

const passingConfigs = (stats: ReadonlyArray<ModelStats>, filter: Filter) => stats.filter(({ started: [first] }) => first !== undefined && passes(filter, first));

export const derive = memoLast((loaded: Loaded, filter: Filter): Derived => {
  const { seats, decisions } = loaded;
  const keep = seats.map((seat) => passes(filter, seat));
  const filtered = seats.filter((_seat, index) => keep[index]);
  const kept = new Set(filtered.map(({ matchId }) => matchId));
  const matchSeats = seats.filter(({ matchId }) => kept.has(matchId));

  return {
    seats,
    decisions,
    keep,
    filtered,
    matchSeats,
    byCohort: passingConfigs(byCohortOf(seats), filter),
    pooled: passingConfigs(pooledOf(seats, filter.cohort), filter),
    ratings: ratingsOf(seats),
    matches: matchRows(matchSeats),
    allMatches: allMatchesOf(seats),
    items: itemsOf(decisions, seats),
  };
});
