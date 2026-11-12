import { groupBy, keyOf, type SeatFull, sumOf } from "./data.ts";
import type { Rating } from "./ratings.ts";

// The Elo from play and move quality: each language-model config's headline rating combined with the rating its points
// lost per move predict. Across the configs the headline rating lies close to a line in points lost per move, and a
// config's own distance from the line has a spread of its own, fitted with the line by maximum likelihood. Each config
// then weighs its two ratings by their precision, so one with few matches leans on its move scores and one with many on
// its results. A 30-fold split-half test found it closer to the other half's rating than the results alone
// (docs/arena/analysis/matchups.md).

const Z95 = 1.96;

/** The largest spread of the configs around the line that the fit tries, and its step, in Elo. */
const MAX_SPREAD = 100;
const SPREAD_STEP = 0.25;

/** Re-weightings per tried spread: the weights depend on the slope, which settles in a few. */
const PASSES = 5;

interface Point {
  readonly key: string;
  readonly rating: number;
  /** The variance of the headline rating, from its 95% interval. */
  readonly ratingVariance: number;
  readonly lost: number;
  /** The variance of `lost`, clustered by seed block. */
  readonly lostVariance: number;
}

interface Line {
  readonly intercept: number;
  readonly slope: number;
  /** The variance of the configs' true ratings around the line. */
  readonly spread: number;
}

/** Points lost per move over a config's completed seats with scored moves, and its sampling variance over seed blocks. */
const lostOf = (seats: ReadonlyArray<SeatFull>): { readonly lost: number; readonly variance: number } | null => {
  const blocks = [...groupBy(seats.filter(({ status, regret }) => status === "completed" && regret !== null), ({ seedBlock }) => seedBlock).values()].map((block) => ({
    total: sumOf(block.map(({ regret }) => regret?.total ?? 0)),
    moves: sumOf(block.map(({ regret }) => regret?.moves ?? 0)),
  }));

  const moves = sumOf(blocks.map((block) => block.moves));

  if (blocks.length < 2 || moves === 0) return null;

  const lost = sumOf(blocks.map(({ total }) => total)) / moves;

  return { lost, variance: (sumOf(blocks.map(({ total, moves: own }) => (total - lost * own) ** 2)) / moves ** 2) * (blocks.length / (blocks.length - 1)) };
};

/** The variance of each point's rating around a line with this slope and spread. */
const varianceAround = (point: Point, slope: number, spread: number): number => point.ratingVariance + spread + slope ** 2 * point.lostVariance;

const weightedLine = (points: ReadonlyArray<Point>, weights: ReadonlyArray<number>): Pick<Line, "intercept" | "slope"> => {
  const weighted = (term: (point: Point) => number) => sumOf(points.map((point, index) => (weights[index] ?? 0) * term(point))) / sumOf(weights);
  const meanX = weighted(({ lost }) => lost);
  const meanY = weighted(({ rating }) => rating);
  const slope = weighted(({ lost, rating }) => (lost - meanX) * (rating - meanY)) / weighted(({ lost }) => (lost - meanX) ** 2);

  return { intercept: meanY - slope * meanX, slope };
};

/** The line and spread of most likelihood: for each tried spread, the weighted line, scored by the normal likelihood. */
const fitLine = (points: ReadonlyArray<Point>): Line => {
  let best = { line: { intercept: 0, slope: 0, spread: 0 }, cost: Number.POSITIVE_INFINITY };

  for (let sd = 0; sd <= MAX_SPREAD; sd += SPREAD_STEP) {
    const spread = sd ** 2;
    let line: Pick<Line, "intercept" | "slope"> = { intercept: 0, slope: 0 };

    for (let pass = 0; pass < PASSES; pass++) line = weightedLine(points, points.map((point) => 1 / varianceAround(point, line.slope, spread)));

    const cost = sumOf(
      points.map((point) => {
        const variance = varianceAround(point, line.slope, spread);

        return Math.log(variance) + (point.rating - line.intercept - line.slope * point.lost) ** 2 / variance;
      }),
    );

    if (cost < best.cost) best = { line: { ...line, spread }, cost };
  }

  return best.line;
};

/** The Elo from play and move quality of each config with a headline interval and scored moves; none with fewer than three. */
export const playAndMoveRatings = (headline: ReadonlyMap<string, Rating>, seats: ReadonlyArray<SeatFull>): ReadonlyMap<string, Rating> => {
  const points = [...groupBy(seats, keyOf)].flatMap(([key, own]): ReadonlyArray<Point> => {
    const rating = headline.get(key);
    const lost = lostOf(own);

    return rating?.interval == null || lost === null
      ? []
      : [{ key, rating: rating.rating, ratingVariance: ((rating.interval.hi - rating.interval.lo) / (2 * Z95)) ** 2, lost: lost.lost, lostVariance: lost.variance }];
  });

  if (points.length < 3) return new Map();

  const line = fitLine(points);

  return new Map(
    points.map((point) => {
      const predicted = line.intercept + line.slope * point.lost;
      const predictedVariance = line.spread + line.slope ** 2 * point.lostVariance;
      const variance = 1 / (1 / point.ratingVariance + 1 / predictedVariance);
      const rating = variance * (point.rating / point.ratingVariance + predicted / predictedVariance);
      const half = Z95 * Math.sqrt(variance);

      return [point.key, { rating, blocks: headline.get(point.key)?.blocks ?? 0, interval: { lo: rating - half, hi: rating + half }, tier: null }] as const;
    }),
  );
};
