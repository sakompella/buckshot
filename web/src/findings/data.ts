import { Schema } from "effect";

import { Summary } from "../arena-viewer/aggregates.ts";

// The findings page's numbers, decoded at build time from the two files in web/online/data: the arena export's
// summary.json and findings.json, which tools/arena/analysis/selfshoot.py writes. Rates and shares are fractions, gaps
// are fractions too (0.377 is +37.7 points), effort slopes are points of round-win chance.

const Share = Schema.Finite.check(Schema.isBetween({ minimum: 0, maximum: 1 }));

const Signed = Schema.Finite.check(Schema.isBetween({ minimum: -1, maximum: 1 }));

const Count = Schema.Int.check(Schema.isGreaterThanOrEqualTo(0));

export const GROUPS = ["strong", "haiku", "luna"] as const;

export type Group = (typeof GROUPS)[number];

export const SONNET_EFFORTS = ["off", "low", "medium", "high", "xhigh", "max"] as const;

const Headline = Schema.Struct({
  cleanShotsN: Count,
  modelRate: Share,
  searchRate: Share,
  gap: Signed,
  gapLo: Signed,
  gapHi: Signed,
  strongN: Count,
  strongModelRate: Share,
  strongSearchRate: Share,
  strongGap: Signed,
  strongGapLo: Signed,
  strongGapHi: Signed,
  missedItemLossShare: Share,
  missedItemLossLo: Share,
  missedItemLossHi: Share,
  fixedPosEffortSlope: Schema.Finite,
  fixedPosEffortLo: Schema.Finite,
  fixedPosEffortHi: Schema.Finite,
  fixedPosEffortShareOfRaw: Share,
});

/** One P(live) value for one group of models: how often they shot themselves, and how often the depth-7 search preferred that on the same states. */
export const CurvePoint = Schema.Struct({
  group: Schema.Literals(GROUPS),
  pLive: Share,
  pLabel: Schema.String.check(Schema.isPattern(/^\d\/\d$/)),
  n: Count,
  modelRate: Share,
  modelLo: Share,
  modelHi: Share,
  searchRate: Share,
  searchLo: Share,
  searchHi: Share,
});

export type CurvePoint = typeof CurvePoint.Type;

export const EffortRow = Schema.Struct({ effort: Schema.Literals(SONNET_EFFORTS), n: Count, modelRate: Share, searchRate: Share, gap: Signed, gapLo: Signed, gapHi: Signed });

export type EffortRow = typeof EffortRow.Type;

const Split = Schema.Struct({ config: Share, seed: Share, configSeed: Share, residual: Share }).check(
  Schema.makeFilter(({ config, seed, configSeed, residual }) => Math.abs(config + seed + configSeed - 1 + residual) < 0.02 || "variance shares must sum to 1"),
);

export type Split = typeof Split.Type;

const Seeds = Schema.Struct({ rounds: Schema.Finite, regret: Schema.Finite });

const GStudy = Schema.Struct({ configs: Count, seeds: Count, rounds: Split, regret: Split, seedsG80: Seeds, seedsG90: Seeds, ratioAll: Schema.Finite, ratioTop14: Schema.Finite });

const BELOW_EVEN = 0.5;

/** A clean shot below even odds, the population every self-shot claim is about. */
export const isBelowEven = ({ pLive }: { readonly pLive: number }): boolean => pLive < BELOW_EVEN;

export const Findings = Schema.Struct({
  generated: Schema.String.check(Schema.isPattern(/^\d{4}-\d{2}-\d{2}$/)),
  headline: Headline,
  curve: Schema.Array(CurvePoint),
  sonnetEffort: Schema.Array(EffortRow),
  gStudy: GStudy,
}).check(
  Schema.makeFilter(({ headline, curve }) => {
    const below = curve.filter(isBelowEven).reduce((total, { n }) => total + n, 0);

    return below === headline.cleanShotsN || `the curve holds ${below} shots below even odds, the headline ${headline.cleanShotsN}`;
  }),
);

export type Findings = typeof Findings.Type;

export interface FindingsData {
  readonly summary: Summary;
  readonly findings: Findings;
}

const decodeSummary = Schema.decodeUnknownSync(Schema.fromJsonString(Summary));

const decodeFindings = Schema.decodeUnknownSync(Schema.fromJsonString(Findings));

export const decodeFindingsData = (summaryJson: string, findingsJson: string): FindingsData => ({ summary: decodeSummary(summaryJson), findings: decodeFindings(findingsJson) });
