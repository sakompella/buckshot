import { groupBy, keyOf, meanOf, quantile, rng, roundResults, type SeatFull, seatShare, unique } from "./data.ts";
import type { Basis } from "./model.ts";

// The ratings the whole page reads: Bradley-Terry over every scored two-player match of every tournament.

/** One scored two-player match: a's win share against b. */
export interface Game {
  readonly a: string;
  readonly b: string;
  readonly sa: number;
}

/** A game with the seed block it was played in, which a bootstrap resamples whole. */
export interface BlockGame extends Game {
  readonly block: string;
}

/** Games between configs numbered by first appearance, so many resamples can be fitted without building maps. */
interface NumberedGames {
  readonly ids: ReadonlyArray<string>;
  readonly a: Int32Array;
  readonly b: Int32Array;
  readonly sa: Float64Array;
}

const numberGames = (games: ReadonlyArray<Game>): NumberedGames => {
  const ids = unique(games.flatMap(({ a, b }) => [a, b]));
  const numberOf = new Map(ids.map((id, index) => [id, index]));
  const numbered = (id: string) => numberOf.get(id) ?? -1;

  return { ids, a: Int32Array.from(games, ({ a }) => numbered(a)), b: Int32Array.from(games, ({ b }) => numbered(b)), sa: Float64Array.from(games, ({ sa }) => sa) };
};

const ELO_PER_NAT = 400 / Math.LN10;

/** The standard deviation of the Gaussian prior on a strength, in nats: about 520 Elo, so it only keeps ratings finite and joined (docs/arena/analysis/matchups.md). */
const PRIOR_SD = 3;

const MAX_STEPS = 50;

const CONVERGED = 1e-9;

/** Solves a x = b in place for a symmetric positive definite a, by Cholesky factorization; the answer is left in b. */
const solveInPlace = (a: Float64Array, b: Float64Array, size: number): void => {
  for (let column = 0; column < size; column++) {
    let diagonal = a[column * size + column] ?? 0;

    for (let k = 0; k < column; k++) diagonal -= (a[column * size + k] ?? 0) ** 2;

    const pivot = Math.sqrt(diagonal);

    a[column * size + column] = pivot;

    for (let row = column + 1; row < size; row++) {
      let value = a[row * size + column] ?? 0;

      for (let k = 0; k < column; k++) value -= (a[row * size + k] ?? 0) * (a[column * size + k] ?? 0);

      a[row * size + column] = value / pivot;
    }
  }

  for (let row = 0; row < size; row++) {
    let value = b[row] ?? 0;

    for (let k = 0; k < row; k++) value -= (a[row * size + k] ?? 0) * (b[k] ?? 0);

    b[row] = value / (a[row * size + row] ?? 1);
  }

  for (let row = size - 1; row >= 0; row--) {
    let value = b[row] ?? 0;

    for (let k = row + 1; k < size; k++) value -= (a[k * size + row] ?? 0) * (b[k] ?? 0);

    b[row] = value / (a[row * size + row] ?? 1);
  }
};

/**
 * The most probable Bradley-Terry strengths over the games at `rows`, by Newton steps: a win share w counts as w
 * wins and 1 - w losses, and a mean-zero Gaussian prior gives every config one finite answer. Rated on an Elo scale
 * with mean 0, only the configs the rows mention.
 */
const fitGames = (games: NumberedGames, rows: ArrayLike<number>): Map<string, number> => {
  const slot = new Int32Array(games.ids.length).fill(-1);
  const present: Array<number> = [];

  for (let index = 0; index < rows.length; index++) {
    for (const id of [games.a[rows[index] ?? 0] ?? 0, games.b[rows[index] ?? 0] ?? 0]) {
      if (slot[id] === -1) {
        slot[id] = present.length;
        present.push(id);
      }
    }
  }

  const size = present.length;
  const strength = new Float64Array(size);
  const gradient = new Float64Array(size);
  const curvature = new Float64Array(size * size);
  const precision = 1 / PRIOR_SD ** 2;

  for (let step = 0; step < MAX_STEPS; step++) {
    for (let id = 0; id < size; id++) gradient[id] = -precision * (strength[id] ?? 0);

    curvature.fill(0);

    for (let id = 0; id < size; id++) curvature[id * size + id] = precision;

    for (let index = 0; index < rows.length; index++) {
      const row = rows[index] ?? 0;
      const x = slot[games.a[row] ?? 0] ?? 0;
      const y = slot[games.b[row] ?? 0] ?? 0;
      const expected = 1 / (1 + Math.exp((strength[y] ?? 0) - (strength[x] ?? 0)));
      const weight = expected * (1 - expected);

      gradient[x] = (gradient[x] ?? 0) + (games.sa[row] ?? 0) - expected;
      gradient[y] = (gradient[y] ?? 0) - (games.sa[row] ?? 0) + expected;
      curvature[x * size + x] = (curvature[x * size + x] ?? 0) + weight;
      curvature[y * size + y] = (curvature[y * size + y] ?? 0) + weight;
      curvature[x * size + y] = (curvature[x * size + y] ?? 0) - weight;
      curvature[y * size + x] = (curvature[y * size + x] ?? 0) - weight;
    }

    solveInPlace(curvature, gradient, size);

    let largest = 0;

    for (let id = 0; id < size; id++) {
      strength[id] = (strength[id] ?? 0) + (gradient[id] ?? 0);
      largest = Math.max(largest, Math.abs(gradient[id] ?? 0));
    }

    if (largest < CONVERGED) break;
  }

  const ratings = present.map((id, index) => [games.ids[id] ?? "", (strength[index] ?? 0) * ELO_PER_NAT] as const);
  const mean = meanOf(ratings.map(([, rating]) => rating));

  return new Map(ratings.map(([id, rating]) => [id, rating - mean]));
};

export const bradleyTerry = (games: ReadonlyArray<Game>): Map<string, number> => fitGames(numberGames(games), Int32Array.from(games.keys()));

/** Completed two-player matches, as their two seats in table order. */
const pairsOf = (seats: ReadonlyArray<SeatFull>): ReadonlyArray<readonly [SeatFull, SeatFull]> =>
  [...groupBy(
    seats.filter(({ status }) => status === "completed"),
    ({ matchId }) => matchId,
  ).values()].flatMap((matchSeats) => {
    const [first, second] = matchSeats;

    return matchSeats.length === 2 && first !== undefined && second !== undefined ? [[first, second] as const] : [];
  });

/** What one match adds to a fit: its share on the basis, or with rounds, a game for each of its rounds. */
const gamesOf = ([x, y]: readonly [SeatFull, SeatFull], basis: Basis): ReadonlyArray<BlockGame> => {
  const game = (sa: number): BlockGame => ({ a: keyOf(x), b: keyOf(y), sa, block: x.seedBlock });

  return basis === "rounds" ? roundResults(x).map(game) : [game(seatShare(x, basis))];
};

/** Every completed two-player match in `seats`, as the games a rating on `basis` counts. */
export const gamesOfSeats = (seats: ReadonlyArray<SeatFull>, basis: Basis): ReadonlyArray<BlockGame> => pairsOf(seats).flatMap((pair) => gamesOf(pair, basis));

/** The share a config rated `rating` is expected to take from one rated `opponent`: the model the ratings are fitted to. */
export const expectedShare = (rating: number, opponent: number): number => 1 / (1 + 10 ** ((opponent - rating) / 400));

export interface Surprise {
  /** The config's mean share of these games. */
  readonly observed: number;
  /** The mean share the ratings predict for the same games. */
  readonly expected: number;
  readonly games: number;
}

/**
 * Per config and opponent group, how far its share beat what the ratings predict for those games. A game counts
 * for both its configs. Configs without a rating are left out.
 */
export const surprises = (games: ReadonlyArray<Game>, ratings: ReadonlyMap<string, number>, groupOf: (config: string) => string): ReadonlyMap<string, ReadonlyMap<string, Surprise>> => {
  const sums = new Map<string, Map<string, { observed: number; expected: number; games: number }>>();

  const add = (config: string, opponent: string, observed: number, expected: number) => {
    const row = sums.get(config) ?? new Map<string, { observed: number; expected: number; games: number }>();
    const cell = row.get(groupOf(opponent)) ?? { observed: 0, expected: 0, games: 0 };

    cell.observed += observed;
    cell.expected += expected;
    cell.games++;
    row.set(groupOf(opponent), cell);
    sums.set(config, row);
  };

  for (const { a, b, sa } of games) {
    const ratingA = ratings.get(a);
    const ratingB = ratings.get(b);

    if (ratingA === undefined || ratingB === undefined) continue;

    const expected = expectedShare(ratingA, ratingB);

    add(a, b, sa, expected);
    add(b, a, 1 - sa, 1 - expected);
  }

  return new Map([...sums].map(([config, row]) => [config, new Map([...row].map(([group, { observed, expected, games }]) => [group, { observed: observed / games, expected: expected / games, games }]))]));
};

export interface Rating {
  readonly rating: number;
  readonly lo: number;
  readonly hi: number;
}

const BOOTSTRAP_REPS = 200;

/**
 * Every config's rating from one fit over all the seats' completed two-player matches, with 95% percentile
 * intervals from refitting resamples of whole seed blocks. Effort sweeps join the other models through their
 * medium configs, so one scale covers every config. The fit counts each match as the basis's share: win shares,
 * or pot shares for a cash rating. A rounds rating counts each round as a game, in the matches whose rounds are known;
 * its resamples still take whole seed blocks, since a match's rounds are not independent.
 */
export const pooledRatings = (seats: ReadonlyArray<SeatFull>, basis: Basis): ReadonlyMap<string, Rating> => {
  const games = gamesOfSeats(seats, basis);
  const numbered = numberGames(games);
  const point = fitGames(numbered, Int32Array.from(games.keys()));
  const blocks = [...groupBy(games.keys(), (index) => games[index]?.block).values()];
  const random = rng(3);
  const draws = new Map<string, Array<number>>();

  for (let rep = 0; rep < BOOTSTRAP_REPS; rep++) {
    const sample = Array.from({ length: blocks.length }, () => blocks[Math.floor(random() * blocks.length)] ?? []).flat();

    for (const [key, rating] of fitGames(numbered, sample)) {
      const keyDraws = draws.get(key);

      if (keyDraws) keyDraws.push(rating);
      else draws.set(key, [rating]);
    }
  }

  return new Map(
    [...point].map(([key, rating]) => {
      const sorted = (draws.get(key) ?? []).toSorted((left, right) => left - right);

      return [key, { rating, lo: quantile(sorted, 0.025), hi: quantile(sorted, 0.975) }] as const;
    }),
  );
};
