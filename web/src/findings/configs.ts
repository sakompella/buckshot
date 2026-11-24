import type { ConfigSummary, Summary } from "../arena-viewer/aggregates.ts";
import { baseName, effortLabel, isClaude, isFixedPlayer, isProvisional } from "../arena-viewer/page/data.ts";

// The 50 configs as the page shows them: one row per config with a headline rating (the luck-adjusted Round Elo, as
// the arena viewer shows it), best first.

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
  /** Reasoning tokens per scored move, over every move including those that billed none. */
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
    tokensPerMove: perMove(summary.scoredReasoning, summary.scoredMoves),
    reasonedShare: summary.scoredReasoning === null ? null : perMove(summary.scoredReasonedMoves, summary.scoredMoves),
    meanLost: summary.regret?.meanLost ?? null,
    vsEngine: summary.vsEngine,
  };
};

/** Every config with a headline rating, best first. */
export const configsOf = (summary: Summary): ReadonlyArray<Config> =>
  summary.configs.flatMap((config) => configOf(config) ?? []).toSorted((left, right) => right.rating - left.rating);

export const TOP_TIER = 1;

export const isTopTier = ({ tier }: Pick<Config, "tier">): boolean => tier === TOP_TIER;
