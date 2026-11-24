import type { ConfigSummary } from "../src/arena-viewer/aggregates.ts";
import type { Seat } from "../src/arena-viewer/api.ts";

/** A blank seat that tests override field by field. */
export const SEAT: Seat = {
  tournament: "t",
  matchId: "",
  matchName: "",
  status: "completed",
  startedAt: "",
  seed: 1,
  seedBlock: "",
  codeHash: "",
  model: "",
  effort: "medium",
  player: "A",
  position: 0,
  winShare: 1,
  cash: 0,
  cost: 0,
  inp: 0,
  outp: 0,
  cr: 0,
  cw: 0,
  rt: 0,
  lat: 0,
  rsHidden: 0,
  rsText: 0,
  multiTool: 0,
  returned: 0,
  rtUnreported: 0,
  moves: 0,
  reasonedMoves: 0,
  acquired: [],
  used: [],
  stolen: [],
  regret: null,
  story: null,
  round: 0,
  roundThree: null,
  deficits: [],
};


/** A config in an export summary with a luck-adjusted rating, its interval ±20, and the tier given. */
export const summaryConfig = (model: string, effort: string, rating: number, tier: number | null, cost = 0.1): ConfigSummary => {
  const ratingOf = { rating, blocks: 10, interval: { lo: rating - 20, hi: rating + 20 }, tier };

  return {
    model,
    effort,
    started: 40,
    scored: 40,
    winShare: 0.5,
    potShare: 0.5,
    roundShare: 0.5,
    win: { k: 20, n: 40, rate: 0.5, lo: 0.4, hi: 0.6, blocks: 10 },
    vsEngine: null,
    regret: null,
    totalCost: cost * 40,
    startedMoves: 1000,
    avgCost: model.startsWith("Engine") ? 0 : cost,
    avgOut: 0,
    avgMoves: 25,
    scoredCost: cost * 40,
    scoredMoves: 1000,
    scoredLatency: 4_000_000,
    scoredReasoning: 10_000,
    scoredReasonedMoves: 250,
    scoredReturned: 1000,
    scoredUnreported: 0,
    rating: ratingOf,
    luckRating: ratingOf,
    moveRating: null,
    favorite: null,
  };
};

const point = (group: string, pLive: number, pLabel: string, n: number, modelRate: number, searchRate: number) => ({ group, pLive, pLabel, n, modelRate, modelLo: modelRate * 0.9, modelHi: Math.min(1, modelRate * 1.1), searchRate, searchLo: searchRate * 0.8, searchHi: searchRate * 1.2 });

/** A findings.json as tools/arena/analysis/selfshoot.py writes it: 100 + 60 + 40 shots below even odds. */
export const FINDINGS_JSON = {
  generated: "2026-11-24",
  headline: {
    cleanShotsN: 200, modelRate: 0.58, searchRate: 0.2, gap: 0.38, gapLo: 0.31, gapHi: 0.43, strongN: 100, strongModelRate: 0.8, strongSearchRate: 0.17, strongGap: 0.63, strongGapLo: 0.58, strongGapHi: 0.67,
    missedItemLossShare: 0.449, missedItemLossLo: 0.436, missedItemLossHi: 0.463, fixedPosEffortSlope: -0.172, fixedPosEffortLo: -0.197, fixedPosEffortHi: -0.151, fixedPosEffortShareOfRaw: 0.519,
  },
  curve: [
    point("strong", 0.25, "1/4", 30, 0.87, 0.21), point("strong", 1 / 3, "1/3", 50, 0.79, 0.17), point("strong", 0.4, "2/5", 20, 0.7, 0.07), point("strong", 0.5, "1/2", 90, 0.29, 0.19), point("strong", 2 / 3, "2/3", 70, 0.01, 0.03),
    point("haiku", 1 / 3, "1/3", 60, 0.26, 0.26), point("haiku", 2 / 3, "2/3", 50, 0.04, 0.06),
    point("luna", 1 / 3, "1/3", 40, 0.49, 0.2), point("luna", 2 / 3, "2/3", 30, 0.25, 0.06),
  ],
  sonnetEffort: [
    { effort: "off", n: 103, modelRate: 0.95, searchRate: 0.14, gap: 0.81, gapLo: 0.71, gapHi: 0.89 },
    { effort: "max", n: 54, modelRate: 0.09, searchRate: 0.13, gap: -0.04, gapLo: -0.08, gapHi: 0 },
  ],
  gStudy: {
    configs: 36, seeds: 30,
    rounds: { config: 0.066, seed: 0.004, configSeed: 0.008, residual: 0.922 },
    regret: { config: 0.439, seed: 0.007, configSeed: 0.02, residual: 0.534 },
    seedsG80: { rounds: 28.7, regret: 2.6 }, seedsG90: { rounds: 64.6, regret: 5.9 }, ratioAll: 10.98, ratioTop14: 5.69,
  },
};

/** An export summary: three top-tier model configs (one Claude family at two efforts), the depth-7 anchor, a tier-2 and a tier-4 config, and a dealer AI. */
export const SUMMARY_JSON = {
  configs: [
    summaryConfig("gpt-6.1-terra", "max", 13, 1, 0.11),
    summaryConfig("claude-sonnet-5-5", "max", 7, 1, 4.18),
    { ...summaryConfig("claude-sonnet-5-5", "medium", -90, 4, 0.1), scoredReasoning: null },
    summaryConfig("Engine/7/2000000/sampled", "", 0, 1, 0),
    { ...summaryConfig("claude-opus-5-5", "max", 6, 1, 4.14), vsEngine: { k: 46, n: 84, rate: 0.548, lo: 0.476, hi: 0.619, blocks: 14 } },
    summaryConfig("gpt-6.1-sol", "max", -13, 2, 0.12),
    summaryConfig("Story", "", -243, 8, 0),
  ],
  hasCertain: true,
  runs: { from: "2026-10-15", to: "2026-11-16" },
  seedBlocks: { blocks: 3910, unpaired: 823 },
};
