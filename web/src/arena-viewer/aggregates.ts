import { Match, Schema, SchemaTransformation } from "effect";

import { CertainRate, Consistency, type Decisions, ITEMS, NO_GAP, type Seat } from "./api.ts";
import { addTo, type BlockTally, blockRate, blocksOf, groupBy, keyOf, lossStats, MIN_BLOCKS_FOR_INTERVAL, meanOf, regretStats, roundResults, type SeatFull, sumOf } from "./page/data.ts";
import { pooledRatings } from "./page/ratings.ts";

// What the arena page shows, worked out once from every seat and agent move: per config and per pair of configs, never
// per match or per move. The viewer server serves the set at /api/agg/<name> and scripts/arena-export.ts writes it as
// files. A filter keeps or drops whole configs, so the page picks and sums these to get what it shows.

/** A rate whose sample may be empty: NaN in the page, null in JSON. */
const Real = Schema.NullOr(Schema.Number).pipe(
  Schema.decodeTo(Schema.Number, SchemaTransformation.transform({ decode: (value) => value ?? Number.NaN, encode: (value) => (Number.isNaN(value) ? null : value) })),
);

const Interval = Schema.Struct({ lo: Schema.Number, hi: Schema.Number });

export const Rate = Schema.Struct({ k: Schema.Number, n: Schema.Number, rate: Real, lo: Real, hi: Real, blocks: Schema.Number });

const RatingSchema = Schema.Struct({ rating: Schema.Number, blocks: Schema.Number, interval: Schema.NullOr(Interval) });

const Item = Schema.Literals(ITEMS);

/** One config: one model at one effort. Means are over its scored (completed) matches; totalCost and startedMoves over every started one. */
export const ConfigSummary = Schema.Struct({
  model: Schema.String,
  effort: Schema.String,
  started: Schema.Number,
  scored: Schema.Number,
  winShare: Schema.Number,
  /** Mean pot share over scored matches. */
  potShare: Schema.Number,
  /** Rounds won over rounds played, in the scored matches whose rounds are known. */
  roundShare: Schema.Number,
  /** Observed win share with a seed-block bootstrap interval. */
  win: Rate,
  regret: Schema.NullOr(Schema.Struct({ moves: Schema.Number, mean: Schema.Number, exactShare: Schema.Number })),
  loss: Schema.NullOr(Schema.Struct({ perMatch: Schema.Number, matches: Schema.Number, excluded: Schema.Number })),
  totalCost: Schema.Number,
  startedMoves: Schema.Number,
  avgCost: Schema.Number,
  avgOut: Schema.Number,
  avgMoves: Schema.Number,
  scoredCost: Schema.Number,
  scoredMoves: Schema.Number,
  scoredLatency: Schema.Number,
  /** Round Elo from one fit over every match (page/ratings.ts); null for a config with no rated match. */
  rating: Schema.NullOr(RatingSchema),
  /** The item used most often when legal, over at least MIN_LEGAL legal moves. */
  favorite: Schema.NullOr(Schema.Struct({ item: Item, rate: Schema.Number, k: Schema.Number, n: Schema.Number })),
});

export type ConfigSummary = typeof ConfigSummary.Type;

export const Summary = Schema.Struct({ configs: Schema.Array(ConfigSummary), hasCertain: Schema.Boolean });

/**
 * The two-player matches between two configs, `first` at the table's first position. Wins are win shares summed over
 * scored matches; a starter or round-one count is over the scored matches where it is known.
 */
export const Pair = Schema.Struct({
  first: Schema.String,
  second: Schema.String,
  matches: Schema.Number,
  scored: Schema.Number,
  firstWins: Schema.Number,
  secondWins: Schema.Number,
  starterWins: Schema.Number,
  starts: Schema.Number,
  roundOneWins: Schema.Number,
  roundOnes: Schema.Number,
});

export type Pair = typeof Pair.Type;

export const Fates = Schema.Struct({ used: Schema.Number, stolen: Schema.Number, unused: Schema.Number });

export type Fates = typeof Fates.Type;

/** A move has an item available when legalUse has a bit: an own item, a jam or an adrenaline steal. A steal counts as an adrenaline use. */
export const Behavior = Schema.Struct({ moves: Schema.Number, available: Schema.Number, usedWhenAvailable: Schema.Number, itemActions: Schema.Number });

export type Behavior = typeof Behavior.Type;

/** A config's item fates over its scored two-player matches (`players` of them), in ITEMS order, and its moves' item behaviour over every match. */
export const GapTokens = Schema.Struct({ moves: Schema.Number, tokens: Schema.Number });

export type GapTokens = typeof GapTokens.Type;

export const ConfigItems = Schema.Struct({
  config: Schema.String,
  players: Schema.Number,
  fates: Schema.Array(Fates),
  behavior: Behavior,
  /** Mean output tokens per move at each health gap from GAPS_FROM, the outer ones holding every wider gap. */
  tokensByGap: Schema.Array(GapTokens),
});

export type ConfigItems = typeof ConfigItems.Type;

export const ShotTally = Schema.Struct({ self: Schema.Number, shots: Schema.Number });

export type ShotTally = typeof ShotTally.Type;

/** A config's shots per ODDS_BINS bin. */
export const ConfigOdds = Schema.Struct({ config: Schema.String, bins: Schema.Array(ShotTally) });

export type ConfigOdds = typeof ConfigOdds.Type;

export const CertainRates = Schema.Array(CertainRate);

export const ConsistencyRows = Schema.Array(Consistency);

export const AGGREGATE_NAMES = ["summary", "pairs", "items", "odds", "certain", "consistency"] as const;

export type AggregateName = (typeof AGGREGATE_NAMES)[number];

/** The files of the set, each fetched when the page first needs it. */
export const AGGREGATES = {
  summary: Summary,
  pairs: Schema.Array(Pair),
  items: Schema.Array(ConfigItems),
  odds: Schema.Array(ConfigOdds),
  certain: CertainRates,
  consistency: ConsistencyRows,
} as const satisfies Record<AggregateName, Schema.Top>;

export type Aggregates = { readonly [Name in AggregateName]: (typeof AGGREGATES)[Name]["Type"] };

const jsonOf = <S extends Schema.Codec<unknown, unknown>>(schema: S) => Schema.encodeSync(Schema.fromJsonString(schema));

/** Each file's JSON, as the viewer server serves it and scripts/arena-export.ts writes it. */
export const encodeAggregates = (aggregates: Aggregates): Readonly<Record<AggregateName, string>> => ({
  summary: jsonOf(AGGREGATES.summary)(aggregates.summary),
  pairs: jsonOf(AGGREGATES.pairs)(aggregates.pairs),
  items: jsonOf(AGGREGATES.items)(aggregates.items),
  odds: jsonOf(AGGREGATES.odds)(aggregates.odds),
  certain: jsonOf(AGGREGATES.certain)(aggregates.certain),
  consistency: jsonOf(AGGREGATES.consistency)(aggregates.consistency),
});

// ITEMS

/** A seat's copies of each item, in ITEMS order, by what became of them. Adrenaline steals count as uses of the adrenaline that paid for them. */
export const seatFates = (seat: Pick<Seat, "acquired" | "used">, opponent: Pick<Seat, "stolen">): ReadonlyArray<Fates> =>
  seat.acquired.map((acquired, item) => {
    const used = seat.used[item] ?? 0;
    const stolen = opponent.stolen[item] ?? 0;

    return { used, stolen, unused: acquired - used - stolen };
  });

export const sumFates = (fates: ReadonlyArray<Fates>): Fates => ({
  used: sumOf(fates.map(({ used }) => used)),
  stolen: sumOf(fates.map(({ stolen }) => stolen)),
  unused: sumOf(fates.map(({ unused }) => unused)),
});

export const NO_BEHAVIOR: Behavior = { moves: 0, available: 0, usedWhenAvailable: 0, itemActions: 0 };

export const addBehavior = (left: Behavior, right: Behavior): Behavior => ({
  moves: left.moves + right.moves,
  available: left.available + right.available,
  usedWhenAvailable: left.usedWhenAvailable + right.usedWhenAvailable,
  itemActions: left.itemActions + right.itemActions,
});

export const behaviorBySeat = (decisions: Pick<Decisions, "seat" | "legalUse" | "useItem">, seatCount: number): ReadonlyArray<Behavior> => {
  const tallies = Array.from({ length: seatCount }, () => ({ ...NO_BEHAVIOR }));

  decisions.seat.forEach((seatIndex, move) => {
    const tally = tallies[seatIndex];

    if (tally === undefined) return;

    const available = (decisions.legalUse[move] ?? 0) !== 0;
    const used = (decisions.useItem[move] ?? -1) >= 0;

    tally.moves++;

    if (available) tally.available++;

    if (available && used) tally.usedWhenAvailable++;

    if (used) tally.itemActions++;
  });

  return tallies;
};

/** Each seat of a completed two-player match with its fates; the copies stolen from a seat are its opponent's steals. */
const fatesBySeat = (seats: ReadonlyArray<SeatFull>): ReadonlyMap<SeatFull, ReadonlyArray<Fates>> =>
  new Map(
    [...groupBy(
      seats.filter(({ status }) => status === "completed"),
      ({ matchId }) => matchId,
    ).values()].flatMap((both) => {
      const [one, other, ...rest] = both;

      return one === undefined || other === undefined || rest.length > 0
        ? []
        : [
            [one, seatFates(one, other)],
            [other, seatFates(other, one)],
          ];
    }),
  );

/** The health gaps, own health less the opponent's, that the tokens per move are split by. */
export const GAPS_FROM = -2;

export const GAPS_TO = 2;

const tokensBySeat = (decisions: Pick<Decisions, "seat" | "gap" | "out">, seatCount: number): ReadonlyArray<ReadonlyArray<{ moves: number; out: number }>> => {
  const tallies = Array.from({ length: seatCount }, () => Array.from({ length: GAPS_TO - GAPS_FROM + 1 }, () => ({ moves: 0, out: 0 })));

  decisions.seat.forEach((seatIndex, move) => {
    const gap = decisions.gap[move] ?? NO_GAP;
    const tally = tallies[seatIndex]?.[Math.max(GAPS_FROM, Math.min(GAPS_TO, gap)) - GAPS_FROM];

    if (gap === NO_GAP || tally === undefined) return;

    tally.moves++;
    tally.out += decisions.out[move] ?? 0;
  });

  return tallies;
};

const configItems = (seats: ReadonlyArray<SeatFull>, decisions: Decisions): ReadonlyArray<ConfigItems> => {
  const perSeat = fatesBySeat(seats);
  const bySeat = behaviorBySeat(decisions, seats.length);
  const tokens = tokensBySeat(decisions, seats.length);
  const indexed = seats.map((seat, index) => ({ seat, behavior: bySeat[index] ?? NO_BEHAVIOR, gaps: tokens[index] ?? [] }));

  return [...groupBy(indexed, ({ seat }) => keyOf(seat))].map(([config, own]) => {
    const players = own.filter(({ seat }) => perSeat.has(seat));

    return {
      config,
      players: players.length,
      fates: ITEMS.map((_item, index) => sumFates(players.map(({ seat }) => perSeat.get(seat)?.[index] ?? { used: 0, stolen: 0, unused: 0 }))),
      behavior: own.reduce((sum, { behavior }) => addBehavior(sum, behavior), NO_BEHAVIOR),
      tokensByGap: Array.from({ length: GAPS_TO - GAPS_FROM + 1 }, (_gap, index) => {
        const moves = sumOf(own.map(({ gaps }) => gaps[index]?.moves ?? 0));

        return { moves, tokens: moves === 0 ? 0 : sumOf(own.map(({ gaps }) => gaps[index]?.out ?? 0)) / moves };
      }),
    };
  });
};

const MIN_LEGAL = 30;

/** Per config, the item it used most often when it was legal, over at least MIN_LEGAL legal moves. A steal with adrenaline counts as an adrenaline use. */
const favorites = (seats: ReadonlyArray<SeatFull>, decisions: Pick<Decisions, "seat" | "legalUse" | "useItem">): ReadonlyMap<string, ConfigSummary["favorite"]> => {
  const tallies = new Map<string, Array<[number, number]>>();

  const tallyOfSeat = seats.map((seat) => {
    const key = keyOf(seat);
    const tally = tallies.get(key) ?? ITEMS.map((): [number, number] => [0, 0]);

    tallies.set(key, tally);

    return tally;
  });

  decisions.seat.forEach((seatIndex, move) => {
    const tally = tallyOfSeat[seatIndex];
    const legalUse = decisions.legalUse[move] ?? 0;

    tally?.forEach((counts, index) => {
      if (legalUse & (1 << index)) {
        counts[0] += decisions.useItem[move] === index ? 1 : 0;
        counts[1]++;
      }
    });
  });

  return new Map(
    [...tallies].map(([key, tally]) => {
      const best = tally.reduce<{ readonly index: number; readonly k: number; readonly n: number } | null>(
        (found, [k, n], index) => (n >= MIN_LEGAL && (found === null || k / n > found.k / found.n) ? { index, k, n } : found),
        null,
      );

      return [key, best === null ? null : { item: ITEMS[best.index] ?? ITEMS[0], rate: best.k / best.n, k: best.k, n: best.n }] as const;
    }),
  );
};

// ODDS

/** Chance-live bins in whole percent, ends inclusive. The ends and the even odds are bins of their own: counting shells shows there. */
export const ODDS_BINS: ReadonlyArray<{ readonly label: string; readonly low: number; readonly high: number }> = [
  { label: "0%", low: 0, high: 0 },
  { label: "1–33", low: 1, high: 33 },
  { label: "34–49", low: 34, high: 49 },
  { label: "50", low: 50, high: 50 },
  { label: "51–99", low: 51, high: 99 },
  { label: "100%", low: 100, high: 100 },
];

export const oddsBinOf = (percent: number): number => ODDS_BINS.findIndex(({ low, high }) => percent >= low && percent <= high);

/** Shots aimed at oneself over all shots, per bin, for each config of a kept seat. A shot without clue odds counts nowhere. */
export const selfShotTallies = (decisions: Pick<Decisions, "odds" | "seat" | "shot">, seats: ReadonlyArray<Pick<SeatFull, "model" | "effort">>, keep: ReadonlyArray<boolean>): ReadonlyMap<string, ReadonlyArray<ShotTally>> => {
  const tallies = new Map<string, Array<{ self: number; shots: number }>>();

  decisions.odds.forEach((percent, move) => {
    const seatAt = decisions.seat[move] ?? -1;
    const seat = seats[seatAt];
    const bin = oddsBinOf(percent);

    if (seat === undefined || keep[seatAt] !== true || bin < 0) return;

    const key = keyOf(seat);
    const bins = tallies.get(key) ?? ODDS_BINS.map(() => ({ self: 0, shots: 0 }));
    const tally = bins[bin];

    if (tally) {
      tally.shots++;

      if (decisions.shot[move] === 2) tally.self++;
    }

    tallies.set(key, bins);
  });

  return tallies;
};

// PAIRS

/** A started two-player match, its seats in table order. */
const twoPlayerMatches = (seats: ReadonlyArray<SeatFull>): ReadonlyArray<readonly [SeatFull, SeatFull]> =>
  [...groupBy(seats, ({ matchId }) => matchId).values()].flatMap((both) => {
    const [first, second, ...rest] = both.toSorted((left, right) => left.position - right.position);

    return first !== undefined && second !== undefined && rest.length === 0 ? [[first, second] as const] : [];
  });

const starterWon = (first: SeatFull, second: SeatFull): ReadonlyArray<number> => {
  const starter = first.story?.starter;

  if (starter === first.player) return [first.winShare ?? 0];

  return starter === second.player ? [second.winShare ?? 0] : [];
};

const roundOneWinnerWon = (first: SeatFull, second: SeatFull): ReadonlyArray<number> => {
  const winner = (first.winShare ?? 0) >= 1 ? first.player : (second.winShare ?? 0) >= 1 ? second.player : null;
  const story = first.story;

  return winner === null || story === null || !story.ok ? [] : [story.rounds[0]?.winner === winner ? 1 : 0];
};

export const pairsOf = (seats: ReadonlyArray<SeatFull>): ReadonlyArray<Pair> =>
  [...groupBy(twoPlayerMatches(seats), ([first, second]) => `${keyOf(first)} ${keyOf(second)}`).values()].flatMap((matches) => {
    const [[first, second] = []] = matches;
    const scored = matches.filter(([seat]) => seat.status === "completed");
    const starters = scored.flatMap(([one, other]) => starterWon(one, other));
    const roundOnes = scored.flatMap(([one, other]) => roundOneWinnerWon(one, other));

    return first === undefined || second === undefined
      ? []
      : [
          {
            first: keyOf(first),
            second: keyOf(second),
            matches: matches.length,
            scored: scored.length,
            firstWins: sumOf(scored.map(([one]) => one.winShare ?? 0)),
            secondWins: sumOf(scored.map(([, other]) => other.winShare ?? 0)),
            starterWins: sumOf(starters),
            starts: starters.length,
            roundOneWins: sumOf(roundOnes),
            roundOnes: roundOnes.length,
          },
        ];
  });

// CONFIGS

export const configSummaries = (seats: ReadonlyArray<SeatFull>, decisions: Pick<Decisions, "seat" | "legalUse" | "useItem">): ReadonlyArray<ConfigSummary> => {
  const ratings = pooledRatings(seats);
  const favoriteOf = favorites(seats, decisions);

  return [...groupBy(seats, keyOf)].flatMap(([key, started]) => {
    const [first] = started;

    if (first === undefined) return [];

    const scored = started.filter(({ status }) => status === "completed");
    const wins: BlockTally = new Map();

    for (const seat of scored) addTo(wins, seat.seedBlock, seat.winShare ?? 0, 1);

    const costs = scored.flatMap(({ cost }) => (cost === null ? [] : [cost]));
    const scoredMean = (value: (seat: SeatFull) => number | null) => meanOf(scored.map((seat) => value(seat) ?? 0));
    const scoredSum = (value: (seat: SeatFull) => number | null) => sumOf(scored.map((seat) => value(seat) ?? 0));
    const loss = lossStats(scored);

    return [
      {
        model: first.model,
        effort: first.effort,
        started: started.length,
        scored: scored.length,
        winShare: scoredMean(({ winShare }) => winShare),
        potShare: scoredMean(({ potShare }) => potShare),
        roundShare: meanOf(scored.flatMap(roundResults)),
        win: blockRate(wins),
        regret: regretStats(scored),
        loss: loss === null ? null : { perMatch: loss.perMatch, matches: loss.matches, excluded: loss.excluded },
        totalCost: sumOf(started.map(({ cost }) => cost ?? 0)),
        startedMoves: sumOf(started.map(({ moves }) => moves ?? 0)),
        avgCost: meanOf(costs),
        avgOut: scoredMean(({ outp }) => outp),
        avgMoves: scoredMean(({ moves }) => moves),
        scoredCost: scoredSum(({ cost }) => cost),
        scoredMoves: scoredSum(({ moves }) => moves),
        scoredLatency: scoredSum(({ lat }) => lat),
        rating: ratings.get(key) ?? null,
        favorite: favoriteOf.get(key) ?? null,
      },
    ];
  });
};

// CERTAIN MISTAKES

/** A written interval stays only over enough seed blocks: of the config's, the model's or every completed seat. */
export const thresholdedCertain = (rates: ReadonlyArray<CertainRate>, seats: ReadonlyArray<Pick<SeatFull, "model" | "effort" | "seedBlock" | "status">>): ReadonlyArray<CertainRate> => {
  const completed = seats.filter(({ status }) => status === "completed");
  const configBlocks = new Map([...groupBy(completed, keyOf)].map(([key, own]) => [key, blocksOf(own)]));
  const modelBlocks = new Map([...groupBy(completed, ({ model }) => model)].map(([model, own]) => [model, blocksOf(own)]));
  const allBlocks = blocksOf(completed);

  const blocksOfRate = ({ scope, model, effort }: CertainRate) =>
    Match.value(scope).pipe(
      Match.when("config", () => configBlocks.get(keyOf({ model, effort })) ?? 0),
      Match.when("model", () => modelBlocks.get(model) ?? 0),
      Match.when("all", () => allBlocks),
      Match.exhaustive,
    );

  return rates.map((rate) => (blocksOfRate(rate) < MIN_BLOCKS_FOR_INTERVAL ? { ...rate, bounds: null } : rate));
};

export interface Sources {
  readonly seats: ReadonlyArray<SeatFull>;
  readonly decisions: Decisions;
  readonly certain: ReadonlyArray<CertainRate>;
  readonly consistency: ReadonlyArray<Consistency>;
}

export const aggregatesOf = ({ seats, decisions, certain, consistency }: Sources): Aggregates => ({
  summary: { configs: configSummaries(seats, decisions), hasCertain: certain.length > 0 },
  pairs: pairsOf(seats),
  items: configItems(seats, decisions),
  odds: [...selfShotTallies(decisions, seats, seats.map(() => true))].map(([config, bins]) => ({ config, bins })),
  certain: thresholdedCertain(certain, seats),
  consistency,
});
