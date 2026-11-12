import { groupBy, isProvisional, keyOf, MIN_BLOCKS_FOR_INTERVAL, meanOf, quantile, roundResults, type SeatFull, sumOf, unique } from "./data.ts";
import { BOOTSTRAP_DRAWS } from "../../arena/bootstrap.ts";
import { mulberry32 } from "../../arena/tournament-stats.ts";

// The ratings the whole page reads: Bradley-Terry over every scored two-player match of every tournament.
// tools/arena/analysis/test_round_elo.py ties this fit to bt.round_elo, the docs' Round Elo.

/** One scored two-player match: a's share against b. With a weight, it stands for that many games with that mean share. */
export interface Game {
  readonly a: string;
  readonly b: string;
  readonly sa: number;
  readonly weight?: number;
}

export interface BlockGame extends Game {
  readonly block: string;
}

interface NumberedGames {
  readonly ids: ReadonlyArray<string>;
  readonly a: Int32Array;
  readonly b: Int32Array;
  readonly sa: Float64Array;
  readonly weight: Float64Array;
}

const numberGames = (games: ReadonlyArray<Game>): NumberedGames => {
  const ids = unique(games.flatMap(({ a, b }) => [a, b]));
  const numberOf = new Map(ids.map((id, index) => [id, index]));
  const numbered = (id: string) => numberOf.get(id) ?? -1;

  return { ids, a: Int32Array.from(games, ({ a }) => numbered(a)), b: Int32Array.from(games, ({ b }) => numbered(b)), sa: Float64Array.from(games, ({ sa }) => sa), weight: Float64Array.from(games, ({ weight = 1 }) => weight) };
};

const ELO_PER_NAT = 400 / Math.LN10;

/** The config rated 0: the depth-2 search engine, so adding a config moves no other rating (bt.ANCHOR in tools/arena/analysis). */
export const ANCHOR = keyOf({ model: "Engine/2/20000", effort: "" });

/** The chance of winning a match against the anchor: the round win chance of the Elo gap, in two rounds of three. */
export const matchWinVsAnchor = (rating: number): number => {
  const round = 1 / (1 + 10 ** (-rating / 400));

  return round * round * (3 - 2 * round);
};

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
 * wins and 1 - w losses, and a mean-zero Gaussian prior gives every config one finite answer. On an Elo scale centred
 * on the configs the rows mention: the prior makes their strengths sum to 0. Only those configs.
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

  const pairOf = new Int32Array(size * size).fill(-1);
  const pairX: Array<number> = [];
  const pairY: Array<number> = [];
  const pairGames: Array<number> = [];
  const pairShare: Array<number> = [];

  for (let index = 0; index < rows.length; index++) {
    const row = rows[index] ?? 0;
    const x = slot[games.a[row] ?? 0] ?? 0;
    const y = slot[games.b[row] ?? 0] ?? 0;
    const known = pairOf[x * size + y] ?? -1;
    const pair = known === -1 ? pairX.length : known;

    if (known === -1) {
      pairOf[x * size + y] = pair;
      pairX.push(x);
      pairY.push(y);
      pairGames.push(0);
      pairShare.push(0);
    }

    pairGames[pair] = (pairGames[pair] ?? 0) + (games.weight[row] ?? 1);
    pairShare[pair] = (pairShare[pair] ?? 0) + (games.sa[row] ?? 0) * (games.weight[row] ?? 1);
  }

  const strength = new Float64Array(size);
  const gradient = new Float64Array(size);
  const curvature = new Float64Array(size * size);
  const precision = 1 / PRIOR_SD ** 2;

  for (let step = 0; step < MAX_STEPS; step++) {
    for (let id = 0; id < size; id++) gradient[id] = -precision * (strength[id] ?? 0);

    curvature.fill(0);

    for (let id = 0; id < size; id++) curvature[id * size + id] = precision;

    for (let pair = 0; pair < pairX.length; pair++) {
      const x = pairX[pair] ?? 0;
      const y = pairY[pair] ?? 0;
      const count = pairGames[pair] ?? 0;
      const expected = 1 / (1 + Math.exp((strength[y] ?? 0) - (strength[x] ?? 0)));
      const weight = count * expected * (1 - expected);
      const surplus = (pairShare[pair] ?? 0) - count * expected;

      gradient[x] = (gradient[x] ?? 0) + surplus;
      gradient[y] = (gradient[y] ?? 0) - surplus;
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

  return new Map(present.map((id, index) => [games.ids[id] ?? "", (strength[index] ?? 0) * ELO_PER_NAT] as const));
};

/** Where the anchor sits on a centred scale, or the mean when the ratings leave it out: what to subtract so it reads 0. */
const zeroOf = (centred: ReadonlyMap<string, number>): number => centred.get(ANCHOR) ?? meanOf([...centred.values()]);

const shifted = (ratings: ReadonlyMap<string, number>, by: number): Map<string, number> => new Map([...ratings].map(([id, rating]) => [id, rating - by]));

const anchored = (centred: ReadonlyMap<string, number>): Map<string, number> => shifted(centred, zeroOf(centred));

export const bradleyTerry = (games: ReadonlyArray<Game>): Map<string, number> => anchored(fitGames(numberGames(games), Int32Array.from(games.keys())));

const pairsOf = (seats: ReadonlyArray<SeatFull>): ReadonlyArray<readonly [SeatFull, SeatFull]> =>
  [...groupBy(
    seats.filter(({ status }) => status === "completed"),
    ({ matchId }) => matchId,
  ).values()].flatMap((matchSeats) => {
    const [first, second] = matchSeats;

    return matchSeats.length === 2 && first !== undefined && second !== undefined ? [[first, second] as const] : [];
  });

/** Per "<match id>|<player>", what to add to the player's round wins: the luck correction of the luck-adjusted rating. */
export type Luck = ReadonlyMap<string, number>;

/** What one match adds to a fit: its known rounds as that many games, x's round wins shifted by its luck correction. */
const gamesOf =
  (luck: Luck) =>
  ([x, y]: readonly [SeatFull, SeatFull]): ReadonlyArray<BlockGame> => {
    const rounds = roundResults(x);
    const shift = luck.get(`${x.matchId}|${x.player}`) ?? 0;

    return rounds.length === 0 ? [] : [{ a: keyOf(x), b: keyOf(y), sa: (sumOf(rounds) + shift) / rounds.length, weight: rounds.length, block: x.seedBlock }];
  };

/** Every completed two-player match in `seats`, as the games the round rating counts. */
const gamesOfSeats = (seats: ReadonlyArray<SeatFull>, luck: Luck = new Map()): ReadonlyArray<BlockGame> => pairsOf(seats).flatMap(gamesOf(luck));

export interface Rating {
  readonly rating: number;
  readonly blocks: number;
  readonly interval: { readonly lo: number; readonly hi: number } | null;
  /** The config's tier among the ranked configs, from 1; null for a provisional config. */
  readonly tier: number | null;
}

/**
 * Tiers of configs the data cannot tell apart. Down the ranked configs by rating, a new tier starts at the first config
 * clearly below the top of the current tier: the 95% bootstrap interval of the gap between the two excludes 0.
 */
const tiersOf = (ranked: ReadonlyArray<string>, draws: ReadonlyMap<string, Float64Array>): ReadonlyMap<string, number> => {
  const tiers = new Map<string, number>();
  let top = ranked[0] ?? "";
  let tier = 1;

  for (const key of ranked) {
    const above = draws.get(top) ?? new Float64Array();
    const own = draws.get(key) ?? new Float64Array();

    const gaps = Array.from(above, (rating, rep) => rating - (own[rep] ?? Number.NaN))
      .filter((gap) => !Number.isNaN(gap))
      .toSorted((left, right) => left - right);

    if (quantile(gaps, 0.025) > 0) {
      top = key;
      tier++;
    }

    tiers.set(key, tier);
  }

  return tiers;
};

/**
 * Every config's rating from one fit over all the seats' completed two-player matches, with 95% percentile
 * intervals from refitting resamples of whole seed blocks, and its tier. The resamples are centred on the mean config and
 * moved by the point fit's shift, so an interval leaves out the anchor's own noise and the anchor's interval is the
 * uncertainty of the zero. Effort sweeps join the other models through their
 * medium configs, so one scale covers every config. The fit counts each round as a game, in the matches whose
 * rounds are known; its resamples still take whole seed blocks, since a match's rounds are not independent. With
 * `luck`, each match's round wins are first corrected for luck (tools/arena/analysis/aivat.py).
 */
export const pooledRatings = (seats: ReadonlyArray<SeatFull>, luck: Luck = new Map()): ReadonlyMap<string, Rating> => {
  const games = gamesOfSeats(seats, luck);
  const numbered = numberGames(games);
  const centred = fitGames(numbered, Int32Array.from(games.keys()));
  const zero = zeroOf(centred);
  const point = shifted(centred, zero);
  const blocks = [...groupBy(games.keys(), (index) => games[index]?.block).values()];
  const random = mulberry32(3);
  const draws = new Map([...point.keys()].map((key) => [key, new Float64Array(BOOTSTRAP_DRAWS).fill(Number.NaN)]));

  for (let rep = 0; rep < BOOTSTRAP_DRAWS; rep++) {
    const sample = Array.from({ length: blocks.length }, () => blocks[Math.floor(random() * blocks.length)] ?? []).flat();

    for (const [key, rating] of fitGames(numbered, sample)) {
      const keyDraws = draws.get(key);

      if (keyDraws) keyDraws[rep] = rating - zero;
    }
  }

  const spans = new Map<string, Set<string>>();

  for (const { a, b, block } of games) for (const key of [a, b]) spans.set(key, (spans.get(key) ?? new Set<string>()).add(block));

  const scored = groupBy(
    seats.filter(({ status }) => status === "completed"),
    keyOf,
  );

  const ranked = [...point.keys()].filter((key) => !isProvisional({ scored: scored.get(key)?.length ?? 0 })).toSorted((left, right) => (point.get(right) ?? 0) - (point.get(left) ?? 0));
  const tiers = tiersOf(ranked, draws);

  return new Map(
    [...point].map(([key, rating]) => {
      const sorted = [...(draws.get(key) ?? [])].filter((draw) => !Number.isNaN(draw)).toSorted((left, right) => left - right);
      const spanned = spans.get(key)?.size ?? 0;

      return [key, { rating, blocks: spanned, interval: spanned < MIN_BLOCKS_FOR_INTERVAL ? null : { lo: quantile(sorted, 0.025), hi: quantile(sorted, 0.975) }, tier: tiers.get(key) ?? null }] as const;
    }),
  );
};

const FOLDS = 5;

/**
 * Ratings that never saw a match's own seed block: the blocks are dealt into FOLDS folds in order, and each fold's
 * matches are rated by one fit over the other folds. By seed block; a config absent from the other folds has no rating.
 */
export const heldOutRatings = (seats: ReadonlyArray<SeatFull>): ((block: string) => ReadonlyMap<string, { readonly rating: number }>) => {
  const games = gamesOfSeats(seats);
  const numbered = numberGames(games);
  const foldOf = new Map(unique(games.map(({ block }) => block)).toSorted().map((block, index) => [block, index % FOLDS]));

  const fits = Array.from({ length: FOLDS }, (_, fold) => {
    const training = Int32Array.from(games.keys()).filter((index) => foldOf.get(games[index]?.block ?? "") !== fold);

    return new Map([...anchored(fitGames(numbered, training))].map(([key, rating]) => [key, { rating }]));
  });

  return (block) => fits[foldOf.get(block) ?? -1] ?? new Map();
};
