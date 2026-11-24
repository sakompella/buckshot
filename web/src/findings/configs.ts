import type { ConfigSummary, Summary } from "../arena-viewer/aggregates.ts";
import { baseName, effortLabel, isClaude, isFixedPlayer, isProvisional } from "../arena-viewer/page/data.ts";

// The 50 model settings and fixed players as the page shows them: one row each with its skill score (the luck-adjusted
// Round Elo, 0 at the depth-7 search, as the arena viewer shows it), best first.

export interface Config {
  readonly key: string;
  readonly model: string;
  readonly effort: string;
  /** "Terra 6.1 · max", or a fixed player's name. */
  readonly label: string;
  /** The label for a phone-width chart: "Terra 6.1 max". */
  readonly short: string;
  /** The model without its effort, for trajectories: "Terra 6.1". */
  readonly family: string;
  readonly isFixed: boolean;
  readonly isClaude: boolean;
  readonly isProvisional: boolean;
  readonly rating: number;
  readonly lo: number;
  readonly hi: number;
  readonly tier: number | null;
  readonly scored: number;
  readonly cost: number;
  readonly secondsPerMove: number | null;
  /** Reasoning tokens per scored move, over every move including those that billed none; 0 for a setting with reasoning off that reports no count. */
  readonly tokensPerMove: number | null;
  /** The share of scored moves that billed any reasoning tokens. */
  readonly reasonedShare: number | null;
  readonly meanLost: number | null;
  readonly vsEngine: ConfigSummary["vsEngine"];
}

/** A fixed player's label and short label: the depth of a search, or the name of one of the two fixed computer players. */
const fixedNames = (model: string): readonly [string, string] => {
  const depth = /^Engine\/(\d+)\//.exec(model)?.[1];

  if (depth !== undefined) { return [`Depth-${depth} search`, `Depth-${depth} search`]; }

  return model === "DoN" ? ["Double or Nothing AI", "DoN AI"] : [`${model} AI`, `${model} AI`];
};

/** "GPT-6.1 Terra" reads "Terra 6.1", as the prose names it. */
export const modelName = (model: string): string => baseName(model).replace(/^GPT-([\d.]+) (.+)$/, "$2 $1");

const perMove = (total: number | null, moves: number): number | null => (total === null || moves === 0 ? null : total / moves);

const configOf = (summary: ConfigSummary): Config | undefined => {
  const { model, effort, luckRating } = summary;

  if (luckRating === null || luckRating.interval === null) { return undefined; }

  const isFixed = isFixedPlayer(model);
  const [fixedLabel, fixedShort] = fixedNames(model);
  const name = modelName(model);
  const effortText = effortLabel(model, effort);

  return {
    key: `${model}|${effort}`,
    model,
    effort,
    label: isFixed ? fixedLabel : `${name} \u00b7 ${effortText}`,
    short: isFixed ? fixedShort : `${name} ${effortText}`,
    family: isFixed ? fixedLabel : name,
    isFixed,
    isClaude: isClaude(model),
    isProvisional: isProvisional(summary),
    rating: luckRating.rating,
    lo: luckRating.interval.lo,
    hi: luckRating.interval.hi,
    tier: luckRating.tier,
    scored: summary.scored,
    cost: summary.avgCost,
    secondsPerMove: isFixed ? null : perMove(summary.scoredLatency / 1000, summary.scoredMoves),
    tokensPerMove: perMove(summary.scoredReasoning ?? (effort === "off" ? 0 : null), summary.scoredMoves),
    reasonedShare: summary.scoredReasoning === null ? null : perMove(summary.scoredReasonedMoves, summary.scoredMoves),
    meanLost: summary.regret?.meanLost ?? null,
    vsEngine: summary.vsEngine,
  };
};

/** Every config with a headline rating, best first. */
export const configsOf = (summary: Summary): ReadonlyArray<Config> =>
  summary.configs.flatMap((config) => configOf(config) ?? []).toSorted((left, right) => right.rating - left.rating);

export const TOP_TIER = 1;

/** The top group: the settings whose 90% ranges cannot be told apart from the best one's. */
export const isTopTier = ({ tier }: Pick<Config, "tier">): boolean => tier === TOP_TIER;

/** The depth-7 search, the anchor at 0, and the game's own two computer players: the reference lines on the scatters. */
export const isReference = ({ isFixed, model }: Pick<Config, "isFixed" | "model">): boolean => isFixed && (!model.startsWith("Engine/") || model.startsWith("Engine/7/"));

/** A model as an attribute value: "Opus 5.5" reads "opus-5-5". */
export const familyId = (family: string): string => family.toLowerCase().replaceAll(/[^a-z0-9]+/g, "-");

/**
 * Each model's shade in the light and the dark theme, strongest first within each company: orange for Anthropic, blue
 * for OpenAI. The strongest is darkest on white and brightest on black.
 */
const SHADES: ReadonlyArray<readonly [string, string, string]> = [
  ["Opus 5.5", "#7c2706", "#ffb47e"],
  ["Sonnet 5.5", "#b2400c", "#ff8a45"],
  ["Haiku 5.5", "#dc6c28", "#d4672a"],
  ["Haiku 4.5", "#eda06e", "#a4542a"],
  ["Terra 6.1", "#0c2c63", "#b5d6ff"],
  ["Astra 6", "#1d4f9a", "#84b7ff"],
  ["Sol 6.1", "#3b72bd", "#5d97ea"],
  ["Terra 5.6", "#6d9dd8", "#3f73c2"],
  ["Luna 6", "#9cc1ea", "#2d5794"],
];

/** The models in shade order, those the data holds. */
export const familiesOf = (configs: ReadonlyArray<Config>): ReadonlyArray<string> => {
  const present = new Set(configs.flatMap(({ isFixed, family }) => (isFixed ? [] : [family])));

  return SHADES.flatMap(([family]) => (present.has(family) ? [family] : []));
};

/** The shades as CSS: every element of a model, its marks, line and legend swatch, paints with `--c`. */
export const shadeCss = (): string => SHADES.map(([family, light, dark]) => `[data-family="${familyId(family)}"]{--c:light-dark(${light},${dark})}`).join("");
