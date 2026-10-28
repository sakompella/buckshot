import type { Seat, Story } from "../api.ts";
import type { Basis } from "./model.ts";

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

interface Base {
  readonly id: string;
  readonly name: string;
  /** The name within its family, for cohort names. */
  readonly short: string;
  /** OKLCH lightness, chroma and hue. */
  readonly tone: readonly [number, number, number];
}

// Every Claude model is orange and every GPT model blue (sRGB HSL hue 18-36 for Claude, 196-218 for GPT). Within a
// family the strongest model by the merged cross-model Bradley-Terry order (docs/arena/analysis/matchups.md) is
// brightest and most saturated, and each step down is clearly darker (contrast on black about 14, 9, 6 and 4.6 to 1, so the darkest still reads as small text):
// GPT Astra, Sol, Terra, Luna; Claude Opus, Haiku 5.5, Sonnet, Haiku 4.5. Every effort of a model has its colour.
const BASES: ReadonlyArray<Base> = [
  { id: "claude-opus-5-5", name: "Opus 5.5", short: "Opus", tone: [0.868, 0.115, 75.8] },
  { id: "claude-haiku-5-5", name: "Haiku 5.5", short: "Haiku 5.5", tone: [0.763, 0.151, 56.7] },
  { id: "claude-sonnet-5-5", name: "Sonnet 5.5", short: "Sonnet", tone: [0.647, 0.17, 42.4] },
  { id: "claude-haiku-4-5", name: "Haiku 4.5", short: "Haiku 4.5", tone: [0.59, 0.14, 50] },
  { id: "gpt-6-astra", name: "GPT-6 Astra", short: "Astra", tone: [0.89, 0.073, 224.2] },
  { id: "gpt-6.1-sol", name: "GPT-6.1 Sol", short: "Sol", tone: [0.741, 0.131, 240.2] },
  { id: "gpt-5.6-terra", name: "GPT-5.6 Terra", short: "Terra", tone: [0.638, 0.144, 250] },
  { id: "gpt-6-luna", name: "GPT-6 Luna", short: "Luna", tone: [0.563, 0.128, 250] },
];

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

export const colorOf = (model: string): string => {
  const base = baseOf(model);

  if (base === undefined) return "#999";

  const [lightness, chroma, hue] = base.tone;

  return oklch(lightness, chroma, hue);
};

export const isClaude = (model: string): boolean => model.startsWith("claude");

/** A config: one model at one effort. */
export const keyOf = (seat: { readonly model: string; readonly effort: string }): string => `${seat.model}|${seat.effort}`;

export const splitKey = (key: string): readonly [string, string] => {
  const [model = "", effort = ""] = key.split("|");

  return [model, effort];
};

export const labelOf = (key: string): string => {
  const [model, effort] = splitKey(key);

  return `${baseName(model)} ${effort}`;
};

export const colorOfKey = (key: string): string => colorOf(splitKey(key)[0]);

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

/** Regret and regret scores are percentage points of the round win chance. */
export const fmtPoints = (value: number): string => value.toFixed(1);

export const fmtRating = (rating: number): string => {
  const rounded = Math.round(rating) || 0;

  return `${rounded >= 0 ? "+" : ""}${rounded}`;
};

export const eloName = (basis: Basis): string => ({ wins: "Elo", cash: "Cash Elo", rounds: "Rounds Elo" })[basis];

export const shareName = (basis: Basis): string => ({ wins: "win share", cash: "pot share", rounds: "round share" })[basis];

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

/** A deterministic generator (mulberry32: 32-bit state, exact integer arithmetic), so intervals do not flicker between renders. */
export const rng = (seed: number) => {
  let state = seed | 0;

  return () => {
    state = (state + 0x6d2b79f5) | 0;

    let mixed = Math.imul(state ^ (state >>> 15), 1 | state);

    mixed = (mixed + Math.imul(mixed ^ (mixed >>> 7), 61 | mixed)) ^ mixed;

    return ((mixed ^ (mixed >>> 14)) >>> 0) / 4294967296;
  };
};

// COHORTS

/**
 * A seat with its cohort, the kind of comparison its match is part of over every code version and run, and its pot
 * share: its cash over the match's total cash, null when it has no cash recorded.
 */
export type SeatFull = Seat & { readonly cohort: string; readonly potShare: number | null };

/** What a rating counts per match: each player's win share of it, or its pot share. A rounds rating counts rounds instead (see knownRounds). */
export const seatShare = (seat: SeatFull, basis: Exclude<Basis, "rounds">): number => (basis === "wins" ? seat.winShare : seat.potShare) ?? 0;

/** A match's rounds with their winners, or none when the events do not give every round (Story.ok). */
export const knownRounds = (seat: Pick<Seat, "story">): Story["rounds"] => (seat.story?.ok ? seat.story.rounds : []);

/** What each known round of a match was to a seat: 1 for a round it won, 0 for one it lost. */
export const roundResults = (seat: Pick<Seat, "story" | "player">): ReadonlyArray<number> => knownRounds(seat).map(({ winner }) => (winner === seat.player ? 1 : 0));

export const shortName = (model: string): string => baseOf(model)?.short ?? model;

/** Rankings and rates are only compared within a cohort: the cross-model games, or one model's effort sweep, from every tournament. */
export const withCohorts = (seats: ReadonlyArray<Seat>): ReadonlyArray<SeatFull> => {
  const byMatch = groupBy(seats, ({ matchId }) => matchId);
  const potOf = new Map([...byMatch].map(([matchId, matchSeats]) => [matchId, sumOf(matchSeats.map(({ cash }) => cash ?? 0))]));

  const cohortOf = new Map(
    [...byMatch].map(([matchId, matchSeats]) => {
      const models = unique(matchSeats.map(({ model }) => model));

      return [matchId, models.length === 1 ? `${shortName(models[0] ?? "")} efforts` : "Cross-model"] as const;
    }),
  );

  return seats.map((seat) => ({ ...seat, cohort: cohortOf.get(seat.matchId) ?? "", potShare: seat.cash === null ? null : seat.cash / (potOf.get(seat.matchId) ?? 1) }));
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

// Every bootstrap draws from rng(7) from the start, so the draws are generated once and kept, as 31-bit integers
// (the generator's draws scaled), and extended when a bootstrap needs more.
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
  /** Mean pot share over scored matches. */
  readonly potShare: number;
  /** Rounds won over rounds played, in the scored matches whose rounds are known. */
  readonly roundShare: number;
  /** Over scored matches; null when the viewer has no regret. */
  readonly regret: RegretStats | null;
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
        color: colorOf(first.model),
        dash: DASH.get(first.effort) ?? "",
        started,
        scored,
        winShare: scoredMean(({ winShare }) => winShare),
        potShare: scoredMean(({ potShare }) => potShare),
        roundShare: meanOf(scored.flatMap(roundResults)),
        regret: regretStats(scored),
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
  readonly cohort: string;
  readonly status: string;
  readonly seed: number;
}

export const matchRows = (seats: ReadonlyArray<SeatFull>): ReadonlyArray<MatchRow> =>
  [...groupBy(seats, ({ matchId }) => matchId).values()].flatMap((matchSeats) => {
    const ordered = matchSeats.toSorted((left, right) => left.position - right.position);
    const [first] = ordered;

    return first === undefined ? [] : [{ matchId: first.matchId, seats: ordered, startedAt: first.startedAt, cohort: first.cohort, status: first.status, seed: first.seed }];
  });

/** Regret of a config's searched moves: their mean in points, and the share of them that are proven exact. Null with no searched move. */
export interface RegretStats {
  readonly moves: number;
  readonly mean: number;
  readonly exactShare: number;
}

export const regretStats = (seats: ReadonlyArray<Pick<SeatFull, "regret">>): RegretStats | null => {
  const totals = seats.flatMap(({ regret }) => (regret === null ? [] : [regret]));
  const moves = sumOf(totals.map((total) => total.moves));

  return moves === 0 ? null : { moves, mean: sumOf(totals.map((total) => total.total)) / moves, exactShare: sumOf(totals.map((total) => total.exact)) / moves };
};

/** A config's observed share on a basis: the mean over its scored matches. */
export const configShare = (config: Pick<ModelStats, "winShare" | "potShare" | "roundShare">, basis: Basis): number => ({ wins: config.winShare, cash: config.potShare, rounds: config.roundShare })[basis];

/**
 * Configs in place order for the "Rank" view: highest observed share (mean over scored matches) first. Ties go to
 * the higher Elo, then the label, so the places 1, 2, 3… are always distinct.
 */
export const rankOrder = <A extends { readonly label: string }>(configs: ReadonlyArray<A>, shareOf: (config: A) => number, eloOf: (config: A) => number): ReadonlyArray<A> =>
  configs.toSorted((left, right) => shareOf(right) - shareOf(left) || eloOf(right) - eloOf(left) || left.label.localeCompare(right.label));

export const winnerOf = (match: MatchRow): SeatFull | undefined => match.seats.find(({ winShare }) => (winShare ?? 0) >= 1);
