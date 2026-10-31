import { type Decisions, ITEMS } from "../api.ts";
import { addTo, baseName, type BlockTally, blockRate, keyOf, type MatchRow, matchRows, type ModelStats, modelStats, type Rate, type SeatFull } from "./data.ts";
import type { Filter, Loaded } from "./model.ts";
import { pooledRatings, type Rating } from "./ratings.ts";

// What the page shows, worked out from the loaded data and the filter. Each is
// recomputed only when its inputs change, so hovering a chart stays cheap.

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
  readonly useLegal: ReadonlyArray<Rate>;
  readonly acqUse: ReadonlyArray<Rate>;
  readonly steal: ReadonlyArray<Rate>;
  readonly favorite: { readonly item: string; readonly rate: number; readonly k: number; readonly n: number } | null;
  readonly violations: ReadonlyArray<number>;
}

const MIN_LEGAL = 30;

interface ItemTally {
  readonly use: ReadonlyArray<BlockTally>;
  readonly acq: ReadonlyArray<BlockTally>;
  readonly steal: ReadonlyArray<BlockTally>;
  readonly bad: Array<number>;
}

/** Per config. A steal with adrenaline counts as an adrenaline use and, separately, as a steal of the item taken. */
const itemSummaries = (decisions: Decisions, seats: ReadonlyArray<SeatFull>): ReadonlyMap<string, ItemSummary> => {
  const tallies = new Map<string, ItemTally>();

  const tallyOf = (seat: SeatFull): ItemTally => {
    const id = keyOf(seat);
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
  readonly consistency: Loaded["consistency"];
  readonly keep: ReadonlyArray<boolean>;
  readonly filtered: ReadonlyArray<SeatFull>;
  readonly matchSeats: ReadonlyArray<SeatFull>;
  readonly pooled: ReadonlyArray<ModelStats>;
  /** One round-win rating per config, fitted over every match of every tournament: filters pick rows, not the scale. */
  readonly ratings: ReadonlyMap<string, Rating>;
  readonly ranks: ReadonlyMap<string, number>;
  readonly everyPooled: ReadonlyArray<ModelStats>;
  readonly matches: ReadonlyArray<MatchRow>;
  readonly allMatches: ReadonlyArray<MatchRow>;
  readonly items: ReadonlyMap<string, ItemSummary>;
}

// A filter keeps or drops whole configs, so whatever is grouped by config is worked out once for every seat and then
// picked by the filter.

const ratingsOf = memoLast((seats: ReadonlyArray<SeatFull>): ReadonlyMap<string, Rating> => pooledRatings(seats));

const allMatchesOf = memoLast((seats: ReadonlyArray<SeatFull>) => matchRows(seats));

const everyPooledOf = memoLast((seats: ReadonlyArray<SeatFull>) => modelStats(seats));

const itemsOf = memoLast((decisions: Decisions, seats: ReadonlyArray<SeatFull>) => itemSummaries(decisions, seats));

const passes = (filter: Filter, seat: SeatFull): boolean => !filter.offEfforts.includes(seat.effort) && !filter.offModels.includes(baseName(seat.model));

const passingConfigs = (stats: ReadonlyArray<ModelStats>, filter: Filter) => stats.filter(({ started: [first] }) => first !== undefined && passes(filter, first));

/** Each rated config's place by rating, ties by label so places are distinct; a config without a rating has none. */
export const ranksOf = memoLast((pooled: ReadonlyArray<ModelStats>, ratings: ReadonlyMap<string, Rating>): ReadonlyMap<string, number> => {
  const eloOf = (m: ModelStats) => ratings.get(m.key)?.rating ?? 0;
  const ordered = pooled.filter((m) => m.scored.length > 0 && ratings.has(m.key)).toSorted((left, right) => eloOf(right) - eloOf(left) || left.label.localeCompare(right.label));

  return new Map(ordered.map((m, index) => [m.key, index + 1]));
});

export const derive = memoLast((loaded: Loaded, filter: Filter): Derived => {
  const { seats, decisions, consistency } = loaded;
  const keep = seats.map((seat) => passes(filter, seat));
  const filtered = seats.filter((_seat, index) => keep[index]);
  const kept = new Set(filtered.map(({ matchId }) => matchId));
  const matchSeats = seats.filter(({ matchId }) => kept.has(matchId));
  const every = everyPooledOf(seats);
  const ratings = ratingsOf(seats);

  return {
    seats,
    decisions,
    consistency,
    keep,
    filtered,
    matchSeats,
    pooled: passingConfigs(every, filter),
    ratings,
    ranks: ranksOf(every, ratings),
    everyPooled: every,
    matches: matchRows(matchSeats),
    allMatches: allMatchesOf(seats),
    items: itemsOf(decisions, seats),
  };
});
