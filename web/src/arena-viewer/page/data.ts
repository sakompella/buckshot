import type { Seat } from "../api.ts";

// The page's numbers: model labels and colours, cohorts, per-config stats, ratings and intervals.

export const EFFORTS = ["off", "minimal", "low", "medium", "high", "xhigh", "max"] as const;

export const DEFAULT_EFFORT = "medium";

/** A line dash per effort, for charts that draw one line per config. */
export const DASH: ReadonlyMap<string, string> = new Map([
  ["off", "1 3"],
  ["minimal", "1 3"],
  ["low", "2 3"],
  ["medium", ""],
  ["high", "7 3"],
  ["xhigh", "4 2"],
  ["max", "9 2 2 2"],
]);

type Family = "claude" | "gpt";

interface Base {
  readonly id: string;
  readonly name: string;
  readonly family: Family;
  /** Strength within the family, strongest first. */
  readonly rank: number;
}

// Brightness follows strength. Within each family (Claude oranges, GPT blues) the strongest model by the merged
// cross-model Bradley-Terry order (docs/arena/analysis/matchups.md) is brightest and most saturated:
// GPT Astra +165, Sol +67, Terra -44, Luna -244; Claude Opus +96, Haiku 5.5 +57, Sonnet +37, Haiku 4.5 -134.
// Effort keeps the hue and shifts lightness a smaller step, brighter for higher effort.
const BASES: ReadonlyArray<Base> = [
  { id: "claude-opus-5-5", name: "Opus 5.5", family: "claude", rank: 0 },
  { id: "claude-haiku-5-5", name: "Haiku 5.5", family: "claude", rank: 1 },
  { id: "claude-sonnet-5-5", name: "Sonnet 5.5", family: "claude", rank: 2 },
  { id: "claude-haiku-4-5", name: "Haiku 4.5", family: "claude", rank: 3 },
  { id: "gpt-6-astra", name: "GPT-6 Astra", family: "gpt", rank: 0 },
  { id: "gpt-6.1-sol", name: "GPT-6.1 Sol", family: "gpt", rank: 1 },
  { id: "gpt-5.6-terra", name: "GPT-5.6 Terra", family: "gpt", rank: 2 },
  { id: "gpt-6-luna", name: "GPT-6 Luna", family: "gpt", rank: 3 },
];

const FAMILY: Readonly<Record<Family, { readonly hue: number; readonly chroma: number }>> = { claude: { hue: 50, chroma: 0.19 }, gpt: { hue: 248, chroma: 0.16 } };

const RANK_LIGHTNESS = [0.82, 0.735, 0.65, 0.57];

const RANK_CHROMA = [1, 0.75, 0.55, 0.38];

const EFFORT_STEP = 0.015;

const clamp = (value: number, low: number, high: number) => Math.max(low, Math.min(high, value));

/** OKLCH to an sRGB hex colour. */
export const oklch = (lightness: number, chroma: number, hue: number): string => {
  const a = chroma * Math.cos((hue * Math.PI) / 180);
  const b = chroma * Math.sin((hue * Math.PI) / 180);
  const l = (lightness + 0.3963377774 * a + 0.2158037573 * b) ** 3;
  const m = (lightness - 0.1055613458 * a - 0.0638541728 * b) ** 3;
  const s = (lightness - 0.0894841775 * a - 1.291485548 * b) ** 3;
  const linear = [4.0767416621 * l - 3.3077115913 * m + 0.2309699292 * s, -1.2684380046 * l + 2.6097574011 * m - 0.3413193965 * s, -0.0041960863 * l - 0.7034186147 * m + 1.707614701 * s];

  const channel = (value: number) => {
    const c = clamp(value, 0, 1);
    const gamma = c <= 0.0031308 ? 12.92 * c : 1.055 * c ** (1 / 2.4) - 0.055;

    return Math.round(gamma * 255)
      .toString(16)
      .padStart(2, "0");
  };

  return `#${linear.map(channel).join("")}`;
};

const baseOf = (model: string): Base | undefined => BASES.find(({ id }) => model.includes(id));

export const baseName = (model: string): string => baseOf(model)?.name ?? model;

const effortIndex = (effort: string): number => EFFORTS.findIndex((known) => known === effort);

export const colorOf = (model: string, effort?: string): string => {
  const base = baseOf(model);

  if (base === undefined) return "#999";

  const family = FAMILY[base.family];
  const shift = effort === undefined ? 0 : (Math.max(0, effortIndex(effort)) - 3) * EFFORT_STEP;

  return oklch((RANK_LIGHTNESS[base.rank] ?? 0.6) + shift, family.chroma * (RANK_CHROMA[base.rank] ?? 0.5), family.hue);
};

export const isClaude = (model: string): boolean => model.startsWith("claude");

/** A config: one model at one effort. */
export const keyOf = (seat: { readonly model: string; readonly effort: string }): string => `${seat.model}|${seat.effort}`;

const splitKey = (key: string): readonly [string, string] => {
  const [model = "", effort = ""] = key.split("|");

  return [model, effort];
};

export const labelOf = (key: string): string => {
  const [model, effort] = splitKey(key);

  return `${baseName(model)} ${effort}`;
};

export const colorOfKey = (key: string): string => {
  const [model, effort] = splitKey(key);

  return colorOf(model, effort);
};

export const baseOrder = (model: string): number => {
  const index = BASES.findIndex(({ id }) => model.includes(id));

  return index < 0 ? BASES.length : index;
};

// FORMATS

export const fmtUsd = (value: number | null | undefined): string => {
  if (value === null || value === undefined) return "–";

  if (value === 0) return "$0";

  if (value >= 100) return `$${value.toFixed(0)}`;

  if (value >= 1) return `$${value.toFixed(2)}`;

  return value >= 0.01 ? `$${value.toFixed(3)}` : `$${value.toFixed(4)}`;
};

export const fmtCount = (value: number | null | undefined): string => {
  if (value === null || value === undefined) return "–";

  if (value >= 1e9) return `${(value / 1e9).toFixed(1)}B`;

  if (value >= 1e6) return `${(value / 1e6).toFixed(1)}M`;

  if (value >= 1e4) return `${Math.round(value / 1e3)}k`;

  return value >= 1e3 ? `${(value / 1e3).toFixed(1)}k` : `${Math.round(value)}`;
};

export const fmtPct = (value: number): string => `${(value * 100).toFixed(0)}%`;

export const fmtSec = (ms: number | null | undefined): string => {
  if (ms === null || ms === undefined) return "–";

  if (ms >= 60_000) return `${(ms / 60_000).toFixed(1)}m`;

  return ms >= 10_000 ? `${(ms / 1000).toFixed(0)}s` : `${(ms / 1000).toFixed(1)}s`;
};

const PACIFIC_TIME = new Intl.DateTimeFormat("en-US", { timeZone: "America/Los_Angeles", month: "short", day: "numeric", hour: "numeric", minute: "2-digit" });

export const fmtTime = (iso: string): string => PACIFIC_TIME.format(new Date(iso));

export const fmtRating = (rating: number): string => `${rating >= 0 ? "+" : ""}${rating.toFixed(0)}`;

// GROUPS AND SUMS

export const sumOf = (values: Iterable<number>): number => {
  let total = 0;

  for (const value of values) total += value;

  return total;
};

export const meanOf = (values: ReadonlyArray<number>): number => sumOf(values) / (values.length || 1);

export const groupBy = <A, K>(items: Iterable<A>, keyOfItem: (item: A) => K): Map<K, Array<A>> => {
  const groups = new Map<K, Array<A>>();

  for (const item of items) {
    const key = keyOfItem(item);
    const group = groups.get(key);

    if (group) group.push(item);
    else groups.set(key, [item]);
  }

  return groups;
};

export const unique = <A>(items: Iterable<A>): Array<A> => [...new Set(items)];

export const quantile = (sorted: ArrayLike<number>, p: number): number => {
  if (sorted.length === 0) return Number.NaN;

  const at = (sorted.length - 1) * p;
  const low = sorted[Math.floor(at)] ?? Number.NaN;
  const high = sorted[Math.ceil(at)] ?? Number.NaN;

  return low + (high - low) * (at - Math.floor(at));
};

/** A deterministic generator, so intervals do not flicker between renders. */
export const rng = (seed: number) => {
  let state = seed;

  return () => {
    state = (state * 1103515245 + 12345) & 0x7fffffff;

    return state / 0x80000000;
  };
};

// COHORTS

/** A seat with its cohort: one tournament, one gameplay code hash and one kind of pairing. */
export type SeatFull = Seat & { readonly cohort: string };

/** Rankings and rates are only compared within a cohort: cross-model games, or one model's effort sweep. */
export const withCohorts = (seats: ReadonlyArray<Seat>): ReadonlyArray<SeatFull> => {
  const cohortOf = new Map(
    [...groupBy(seats, ({ matchId }) => matchId)].map(([matchId, matchSeats]) => {
      const [first] = matchSeats;
      const isSweep = matchSeats.every(({ model }) => model === first?.model);

      return [matchId, `${first?.tournament ?? ""} · ${first?.codeHash ?? ""} · ${isSweep ? `${baseName(first?.model ?? "")} efforts` : "cross-model"}`];
    }),
  );

  return seats.map((seat) => ({ ...seat, cohort: cohortOf.get(seat.matchId) ?? "" }));
};

// INTERVALS

/** Hits and trials per seed block: a seed's two seat orders together. */
export type BlockTally = Map<string, [number, number]>;

export const addTo = (tally: BlockTally, block: string, hits: number, trials: number): void => {
  const counts = tally.get(block);

  if (counts) {
    counts[0] += hits;
    counts[1] += trials;
  } else tally.set(block, [hits, trials]);
};

export interface Rate {
  readonly k: number;
  readonly n: number;
  readonly rate: number;
  readonly lo: number;
  readonly hi: number;
  readonly blocks: number;
}

// Every bootstrap draws from rng(7) from the start, so the draws are generated once and kept, as the generator's
// 31-bit states, and extended when a bootstrap needs more.
let draws = new Int32Array(0);

const drawsFor = (count: number): Int32Array => {
  if (draws.length >= count) return draws;

  const random = rng(7);
  const more = new Int32Array(Math.max(count, 2 * draws.length));

  for (let index = 0; index < more.length; index++) more[index] = random() * 0x80000000;

  draws = more;

  return draws;
};

/** A ratio of sums with a 95% percentile bootstrap that resamples seed blocks. */
export const blockRate = (tally: BlockTally, reps = 400): Rate => {
  const blocks = [...tally.values()];
  const blockHits = Float64Array.from(blocks, ([hits]) => hits);
  const blockTrials = Float64Array.from(blocks, ([, trials]) => trials);
  const k = sumOf(blockHits);
  const n = sumOf(blockTrials);

  if (n === 0) return { k, n, rate: Number.NaN, lo: Number.NaN, hi: Number.NaN, blocks: blocks.length };

  const states = drawsFor(reps * blocks.length);
  const rates = new Float64Array(reps);
  let count = 0;

  for (let rep = 0; rep < reps; rep++) {
    let hits = 0;
    let trials = 0;

    for (let draw = rep * blocks.length; draw < (rep + 1) * blocks.length; draw++) {
      const block = Math.floor(((states[draw] ?? 0) / 0x80000000) * blocks.length);

      hits += blockHits[block] ?? 0;
      trials += blockTrials[block] ?? 0;
    }

    if (trials > 0) rates[count++] = hits / trials;
  }

  const sorted = rates.subarray(0, count).sort();

  return { k, n, rate: k / n, lo: quantile(sorted, 0.025), hi: quantile(sorted, 0.975), blocks: blocks.length };
};

/** A bootstrap of a cell with no events, or only events, collapses to a point. */
export const isDegenerate = (rate: Rate): boolean => rate.n > 0 && (rate.k === 0 || rate.k === rate.n);

export const fmtCI = (rate: Rate): string => {
  if (rate.n === 0) return "";

  if (isDegenerate(rate)) return `${rate.k === 0 ? "0" : "all"} of ${rate.n}, no interval · ${rate.blocks} seed blocks`;

  return `95% CI ${(rate.lo * 100).toFixed(1)}–${(rate.hi * 100).toFixed(1)}% · ${rate.blocks} seed blocks`;
};

// CONFIG STATS

export interface ModelStats {
  /** The config key, or cohort and key when grouped by cohort. */
  readonly id: string;
  readonly cohort: string;
  readonly key: string;
  readonly model: string;
  readonly effort: string;
  readonly label: string;
  readonly color: string;
  readonly dash: string;
  /** Completed and partial matches. */
  readonly started: ReadonlyArray<SeatFull>;
  /** Completed matches only. */
  readonly scored: ReadonlyArray<SeatFull>;
  readonly winShare: number;
  /** Observed win share with a seed-block bootstrap interval. */
  readonly win: Rate;
  /** Every started match, failed calls included. */
  readonly totalCost: number;
  /** Completed matches, cheapest first. */
  readonly costs: ReadonlyArray<{ readonly cost: number; readonly seat: SeatFull }>;
  readonly avgCost: number;
  readonly avgOut: number;
  readonly avgMoves: number;
  /** Means per completed match. */
  readonly tokens: { readonly cr: number; readonly cw: number; readonly inp: number; readonly outp: number };
}

export const modelStats = (seats: ReadonlyArray<SeatFull>, isByCohort = false): ReadonlyArray<ModelStats> =>
  [...groupBy(seats, (seat) => (isByCohort ? `${seat.cohort}||${keyOf(seat)}` : keyOf(seat)))].flatMap(([id, started]) => {
    const [first] = started;

    if (first === undefined) return [];

    const scored = started.filter(({ status }) => status === "completed");
    const wins: BlockTally = new Map();

    for (const seat of scored) addTo(wins, seat.seedBlock, seat.winShare ?? 0, 1);

    const costs = scored.flatMap((seat) => (seat.cost === null ? [] : [{ cost: seat.cost, seat }])).toSorted((left, right) => left.cost - right.cost);
    const scoredMean = (value: (seat: SeatFull) => number | null) => meanOf(scored.map((seat) => value(seat) ?? 0));

    return [
      {
        id,
        cohort: isByCohort ? first.cohort : "",
        key: keyOf(first),
        model: first.model,
        effort: first.effort,
        label: labelOf(keyOf(first)),
        color: colorOf(first.model, first.effort),
        dash: DASH.get(first.effort) ?? "",
        started,
        scored,
        winShare: scoredMean(({ winShare }) => winShare),
        win: blockRate(wins),
        totalCost: sumOf(started.map(({ cost }) => cost ?? 0)),
        costs,
        avgCost: meanOf(costs.map(({ cost }) => cost)),
        avgOut: scoredMean(({ outp }) => outp),
        avgMoves: scoredMean(({ moves }) => moves),
        tokens: { cr: scoredMean(({ cr }) => cr), cw: scoredMean(({ cw }) => cw), inp: scoredMean(({ inp }) => inp), outp: scoredMean(({ outp }) => outp) },
      },
    ];
  });

export interface MatchRow {
  readonly matchId: string;
  /** In table order. */
  readonly seats: ReadonlyArray<SeatFull>;
  readonly startedAt: string;
  readonly tournament: string;
  readonly status: string;
  readonly seed: number;
}

export const matchRows = (seats: ReadonlyArray<SeatFull>): ReadonlyArray<MatchRow> =>
  [...groupBy(seats, ({ matchId }) => matchId).values()].flatMap((matchSeats) => {
    const ordered = matchSeats.toSorted((left, right) => left.position - right.position);
    const [first] = ordered;

    return first === undefined ? [] : [{ matchId: first.matchId, seats: ordered, startedAt: first.startedAt, tournament: first.tournament, status: first.status, seed: first.seed }];
  });

export const winnerOf = (match: MatchRow): SeatFull | undefined => match.seats.find(({ winShare }) => (winShare ?? 0) >= 1);

// RATINGS

/** One scored two-player match: a's win share against b. */
export interface Game {
  readonly a: string;
  readonly b: string;
  readonly sa: number;
}

/** Games between configs numbered by first appearance, so many resamples can be fitted without building maps. */
export interface NumberedGames {
  readonly ids: ReadonlyArray<string>;
  readonly a: Int32Array;
  readonly b: Int32Array;
  readonly sa: Float64Array;
}

export const numberGames = (games: ReadonlyArray<Game>): NumberedGames => {
  const ids = unique(games.flatMap(({ a, b }) => [a, b]));
  const numberOf = new Map(ids.map((id, index) => [id, index]));
  const numbered = (id: string) => numberOf.get(id) ?? -1;

  return { ids, a: Int32Array.from(games, ({ a }) => numbered(a)), b: Int32Array.from(games, ({ b }) => numbered(b)), sa: Float64Array.from(games, ({ sa }) => sa) };
};

/**
 * Bradley-Terry with fractional wins over the games at `rows`, fitted by minorization-maximization on an Elo scale
 * with mean 0. One virtual drawn game against a fixed average player keeps every rating finite. Rates only the
 * configs the rows mention, in order of first appearance. Each iteration only needs the games per pair and the wins
 * per config, so they are counted once.
 */
export const fitGames = (games: NumberedGames, rows: ArrayLike<number>): Map<string, number> => {
  const size = games.ids.length;
  const present: Array<number> = [];
  const isPresent = new Uint8Array(size);
  const wins = new Float64Array(size).fill(0.5);
  const pairGames = new Float64Array(size * size);

  for (let index = 0; index < rows.length; index++) {
    const row = rows[index] ?? 0;
    const a = games.a[row] ?? 0;
    const b = games.b[row] ?? 0;
    const sa = games.sa[row] ?? 0;

    for (const id of [a, b]) {
      if (isPresent[id] === 0) {
        isPresent[id] = 1;
        present.push(id);
      }
    }

    wins[a] = (wins[a] ?? 0) + sa;
    wins[b] = (wins[b] ?? 0) + 1 - sa;
    pairGames[Math.min(a, b) * size + Math.max(a, b)] = (pairGames[Math.min(a, b) * size + Math.max(a, b)] ?? 0) + 1;
  }

  const pairs = present.flatMap((x) => present.flatMap((y) => (x < y && (pairGames[x * size + y] ?? 0) > 0 ? [y * size + x] : [])));
  const strength = new Float64Array(size).fill(1);
  const denominators = new Float64Array(size);

  for (let iteration = 0; iteration < 300; iteration++) {
    for (const id of present) denominators[id] = 1 / ((strength[id] ?? 1) + 1);

    for (const pair of pairs) {
      const x = pair % size;
      const y = Math.floor(pair / size);
      const share = (pairGames[x * size + y] ?? 0) / ((strength[x] ?? 1) + (strength[y] ?? 1));

      denominators[x] = (denominators[x] ?? 0) + share;
      denominators[y] = (denominators[y] ?? 0) + share;
    }

    for (const id of present) strength[id] = (wins[id] ?? 0) / (denominators[id] ?? 1);
  }

  const ratings = present.map((id) => [games.ids[id] ?? "", 400 * Math.log10(strength[id] ?? 1)] as const);
  const mean = meanOf(ratings.map(([, rating]) => rating));

  return new Map(ratings.map(([id, rating]) => [id, rating - mean]));
};

export const bradleyTerry = (games: ReadonlyArray<Game>): Map<string, number> => fitGames(numberGames(games), Int32Array.from(games.keys()));

/** Completed two-player matches, as their two seats in table order. */
export const pairsOf = (seats: ReadonlyArray<SeatFull>): ReadonlyArray<readonly [SeatFull, SeatFull]> =>
  [...groupBy(
    seats.filter(({ status }) => status === "completed"),
    ({ matchId }) => matchId,
  ).values()].flatMap((matchSeats) => {
    const [first, second] = matchSeats;

    return matchSeats.length === 2 && first !== undefined && second !== undefined ? [[first, second] as const] : [];
  });

/**
 * One approximate scale. Effort sweeps only play their own model, so a pooled fit stretches them. Instead:
 * Bradley-Terry over all cross-model games, and per model over its effort-sweep games; an effort row is its model's
 * medium cross-model rating plus its offset from medium within the sweep. Rows with no sweep keep their cross-model rating.
 */
export const approxRatings = (seats: ReadonlyArray<SeatFull>): ReadonlyMap<string, number> => {
  const pairs = pairsOf(seats);
  const gameOf = ([x, y]: readonly [SeatFull, SeatFull]): Game => ({ a: keyOf(x), b: keyOf(y), sa: x.winShare ?? 0 });
  const ratings = bradleyTerry(pairs.filter(([x, y]) => x.model !== y.model).map(gameOf));

  const sweeps = groupBy(
    pairs.filter(([x, y]) => x.model === y.model),
    ([x]) => x.model,
  );

  for (const [model, sweepPairs] of sweeps) {
    const anchor = ratings.get(`${model}|${DEFAULT_EFFORT}`);
    const sweep = bradleyTerry(sweepPairs.map(gameOf));
    const middle = sweep.get(`${model}|${DEFAULT_EFFORT}`);

    if (anchor === undefined || middle === undefined) continue;

    for (const [key, rating] of sweep) ratings.set(key, anchor + rating - middle);
  }

  return ratings;
};
