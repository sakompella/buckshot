import { EFFORTS, effortName } from "../../arena/model-names.ts";
import { mulberry32 } from "../../arena/tournament-stats.ts";
import type { CertainType, Seat, SeatRegret, Story } from "../api.ts";

// The page's numbers: model labels and colours, per-config stats, ratings and intervals.

/** Sorts efforts weakest first; one model-names.ts does not list sorts before them all. */
export const byEffort = (left: string, right: string): number => EFFORTS.indexOf(left) - EFFORTS.indexOf(right);

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
  /** The name within its family. */
  readonly short: string;
  /** OKLCH lightness, chroma and hue. */
  readonly tone: readonly [number, number, number];
}

// Every Claude model is orange and every GPT model blue (sRGB HSL hue 18-36 for Claude, 196-218 for GPT). Within a
// family the strongest model, by its Round Elo with all its efforts pooled as one player, is brightest and most saturated,
// and each step down is clearly darker (contrast on black about 14, 9, 6 and 4.6 to 1, so the darkest still reads as small text):
// GPT Astra, Sol, Terra 6.1, Terra 5.6, Luna; Claude Opus, Sonnet, Haiku 5.5, Haiku 4.5. Every effort of a model has its colour.
const BASES: ReadonlyArray<Base> = [
  { id: "claude-opus-5-5", name: "Opus 5.5", short: "Opus", tone: [0.868, 0.115, 75.8] },
  { id: "claude-sonnet-5-5", name: "Sonnet 5.5", short: "Sonnet", tone: [0.763, 0.151, 56.7] },
  { id: "claude-haiku-5-5", name: "Haiku 5.5", short: "Haiku 5.5", tone: [0.647, 0.17, 42.4] },
  { id: "claude-haiku-4-5", name: "Haiku 4.5", short: "Haiku 4.5", tone: [0.59, 0.14, 50] },
  { id: "gpt-6-astra", name: "GPT-6 Astra", short: "Astra", tone: [0.89, 0.073, 224.2] },
  { id: "gpt-6.1-sol", name: "GPT-6.1 Sol", short: "Sol", tone: [0.741, 0.131, 240.2] },
  { id: "gpt-6.1-terra", name: "GPT-6.1 Terra", short: "Terra 6.1", tone: [0.69, 0.137, 245] },
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

/** Models with no reasoning-off whose "off" config is low effort plus the immediate-recall prompt (ADR-0048), marked with an asterisk. */
const PROMPTED_OFF: ReadonlySet<string> = new Set(["gpt-6-astra"]);

/** How the page names a config's effort, everywhere it shows one. */
export const effortLabel = (model: string, effort: string): string => `${effortName(effort)}${effort === "off" && PROMPTED_OFF.has(model) ? "*" : ""}`;

export const labelOf = (key: string): string => {
  const [model, effort] = splitKey(key);

  return `${baseName(model)} ${effortLabel(model, effort)}`;
};

export const CERTAIN_NAMES: Readonly<Record<CertainType, string>> = {
  self_on_live: "Shot itself on a proven live shell",
  gave_up_guaranteed_win: "Shot the opponent, giving up a guaranteed win",
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

export const fmtBytes = (bytes: number): string => {
  if (bytes >= 1e9) return `${(bytes / 1e9).toFixed(1)} GB`;

  return bytes >= 1e6 ? `${Math.round(bytes / 1e6)} MB` : `${Math.max(1, Math.round(bytes / 1e3))} KB`;
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

// POT SHARES

/** A seat with its pot share: its cash over the match's total cash, null when it has no cash recorded. */
export type SeatFull = Seat & { readonly potShare: number | null };

/** A match's rounds with their winners, or none when the events do not give every round (Story.ok). */
const knownRounds = (seat: Pick<Seat, "story">): Story["rounds"] => (seat.story?.ok ? seat.story.rounds : []);

/** What each known round of a match was to a seat: 1 for a round it won, 0 for one it lost. */
export const roundResults = (seat: Pick<Seat, "story" | "player">): ReadonlyArray<number> => knownRounds(seat).map(({ winner }) => (winner === seat.player ? 1 : 0));

export const shortName = (model: string): string => baseOf(model)?.short ?? model;

export const withPotShares = (seats: ReadonlyArray<Seat>): ReadonlyArray<SeatFull> => {
  const potOf = new Map([...groupBy(seats, ({ matchId }) => matchId)].map(([matchId, matchSeats]) => [matchId, sumOf(matchSeats.map(({ cash }) => cash ?? 0))]));

  return seats.map((seat) => ({ ...seat, potShare: seat.cash === null ? null : seat.cash / (potOf.get(seat.matchId) ?? 1) }));
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

// Every bootstrap draws from mulberry32(7) from the start, so the draws are generated once and kept, as 31-bit integers
// (the generator's draws scaled), and extended when a bootstrap needs more.
let draws = new Int32Array(0);

const drawsFor = (count: number): Int32Array => {
  if (draws.length >= count) return draws;

  const random = mulberry32(7);
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

// CONFIG STATS

const PROVISIONAL_BELOW = 20;

export const MIN_BLOCKS_FOR_INTERVAL = 4;

export const isProvisional = ({ scored }: { readonly scored: number }): boolean => scored < PROVISIONAL_BELOW;

export const blocksOf = (seats: ReadonlyArray<Pick<SeatFull, "seedBlock">>): number => new Set(seats.map(({ seedBlock }) => seedBlock)).size;

export const costPerMove = ({ scoredCost, scoredMoves }: { readonly scoredCost: number; readonly scoredMoves: number }): number | null => (scoredMoves > 0 ? scoredCost / scoredMoves : null);

export interface MatchRow {
  readonly matchId: string;
  /** In table order. */
  readonly seats: ReadonlyArray<SeatFull>;
  readonly startedAt: string;
  readonly status: string;
  readonly seed: number;
}

export const matchRows = (seats: ReadonlyArray<SeatFull>): ReadonlyArray<MatchRow> =>
  [...groupBy(seats, ({ matchId }) => matchId).values()].flatMap((matchSeats) => {
    const ordered = matchSeats.toSorted((left, right) => left.position - right.position);
    const [first] = ordered;

    return first === undefined ? [] : [{ matchId: first.matchId, seats: ordered, startedAt: first.startedAt, status: first.status, seed: first.seed }];
  });

/**
 * A config's searched moves, leaving out decisions with no real choice: its accuracy (the mean of its seats' game
 * accuracies), the mean and 99th percentile of the points of round win chance a move gave up, the share of best moves,
 * inaccuracies, mistakes and blunders per 100 moves. Null with no such move.
 */
export interface RegretStats {
  readonly moves: number;
  readonly accuracy: number;
  readonly meanLost: number;
  readonly p99Lost: number;
  readonly bestShare: number;
  readonly inaccuraciesPer100: number;
  readonly mistakesPer100: number;
  readonly blundersPer100: number;
}

export const regretStats = (seats: ReadonlyArray<Pick<SeatFull, "regret">>): RegretStats | null => {
  const totals = seats.flatMap(({ regret }) => (regret === null ? [] : [regret]));
  const moves = sumOf(totals.map((total) => total.moves));

  if (moves === 0) return null;

  const per100 = (count: (seat: SeatRegret) => number) => (sumOf(totals.map(count)) / moves) * 100;
  const losses = totals.flatMap((total) => total.losses).toSorted((left, right) => left - right);
  const zeros = moves - losses.length;
  const rank = Math.ceil(moves * 0.99) - 1;

  return {
    moves,
    accuracy: meanOf(totals.map((total) => total.accuracy)),
    meanLost: sumOf(totals.map((total) => total.total)) / moves,
    p99Lost: rank < zeros ? 0 : (losses[rank - zeros] ?? 0),
    bestShare: sumOf(totals.map((total) => total.best)) / moves,
    inaccuraciesPer100: per100((seat) => seat.inaccuracies),
    mistakesPer100: per100((seat) => seat.mistakes),
    blundersPer100: per100((seat) => seat.blunders),
  };
};

type Scored<S> = { readonly status: string; readonly seats: ReadonlyArray<S> };

export const winnerOf = <S extends { readonly winShare: number | null }>(match: Pick<Scored<S>, "seats">): S | undefined => match.seats.find(({ winShare }) => (winShare ?? 0) >= 1);

/** A match's result as the match list and the replay print it. */
export const resultOf = <S extends { readonly winShare: number | null; readonly model: string; readonly effort: string }>(match: Scored<S>): string => {
  const winner = winnerOf(match);

  if (match.status !== "completed") return "unscored";

  return winner === undefined ? `split ${fmtPct(match.seats[0]?.winShare ?? 0)}` : `${labelOf(keyOf(winner))} wins`;
};
