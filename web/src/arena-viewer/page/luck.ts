import type { Html, HtmlBuilder } from "foldkit/html";

import { chartWidth, linScale } from "./charts.ts";
import { addTo, type BlockTally, blockRate, type MatchRow, type Rate, type SeatFull, winnerOf } from "./data.ts";
import type { Message } from "./model.ts";

type H = HtmlBuilder<Message>;

// Won with higher estimated regret: how often the player who gave up more estimated round-win chance still won the match.
// Regret is an evaluator's estimate per move (docs/arena/analysis/regret.md), with depth limits and its own objective, so
// a win against lower regret is a disagreement between the estimate and the result, not a measurement of luck.

/** A decided two-player match whose seats both have searched moves. */
export interface Duel {
  readonly winner: SeatFull;
  readonly loser: SeatFull;
}

export const duelsOf = (matches: ReadonlyArray<MatchRow>): ReadonlyArray<Duel> =>
  matches.flatMap((match) => {
    const winner = winnerOf(match);
    const loser = match.seats.find((seat) => seat !== winner);

    return match.status === "completed" && match.seats.length === 2 && winner?.regret && loser?.regret ? [{ winner, loser }] : [];
  });

/** What a regret gap is counted in: the mean per move, or the total over the match. */
export type Measure = "mean" | "total";

const regretOf = ({ regret }: SeatFull, measure: Measure): number => (regret === null ? Number.NaN : measure === "mean" ? regret.total / regret.moves : regret.total);

/** Loser's regret minus winner's: positive when the winner had the lower regret, zero when it is a tie. */
export const gapOf = ({ winner, loser }: Duel, measure: Measure): number => regretOf(loser, measure) - regretOf(winner, measure);

/** Duels where one player had lower regret by more than `minGap`; a tie has no lower player. */
const separated = (duels: ReadonlyArray<Duel>, measure: Measure, minGap = 0): ReadonlyArray<Duel> =>
  duels.filter((duel) => gapOf(duel, measure) !== 0 && Math.abs(gapOf(duel, measure)) >= minGap);

export interface Share {
  readonly k: number;
  readonly n: number;
}

/** The share of duels won by the player with lower regret, counting only gaps of at least `minGap`. */
export const betterShare = (duels: ReadonlyArray<Duel>, measure: Measure, minGap = 0): Share => {
  const decided = separated(duels, measure, minGap);

  return { k: decided.filter((duel) => gapOf(duel, measure) > 0).length, n: decided.length };
};

/** Gaps in points of regret per move where a bucket of the chart starts. */
export const GAP_EDGES: ReadonlyArray<number> = [0, 0.5, 1, 2, 4];

export interface GapBucket {
  readonly from: number;
  readonly to: number | null;
  /** The win share of the player with lower regret, with a seed-block interval. */
  readonly rate: Rate;
}

export const bucketsOf = (duels: ReadonlyArray<Duel>): ReadonlyArray<GapBucket> =>
  GAP_EDGES.map((from, index) => {
    const to = GAP_EDGES[index + 1] ?? null;
    const tally: BlockTally = new Map();

    for (const duel of separated(duels, "mean")) {
      const gap = gapOf(duel, "mean");
      const size = Math.abs(gap);

      if (size >= from && (to === null || size < to)) addTo(tally, duel.winner.seedBlock, gap > 0 ? 1 : 0, 1);
    }

    return { from, to, rate: blockRate(tally) };
  });

const pct = (value: number): string => `${(value * 100).toFixed(0)}%`;

const S = (value: number): string => value.toFixed(1);

const bigNumberView = (h: H, share: Share, label: string): Html =>
  h.div([h.Class("bignum")], [h.b([], [share.n === 0 ? "–" : pct(share.k / share.n)]), h.span([h.Class("lbl")], [label]), h.span([h.Class("pm")], [`${share.k.toLocaleString()} of ${share.n.toLocaleString()} decided matches`])]);

const gapName = ({ from, to }: GapBucket): string => (to === null ? `${from}+` : from === 0 ? `under ${to}` : `${from}–${to}`);

const bucketsView = (h: H, buckets: ReadonlyArray<GapBucket>, width: number): Html => {
  const [L, R, T, B] = [42, 8, 22, 44];
  const height = 250;
  const y = linScale(0, 1, height - B, T, [0, 0.5, 1]);
  const slot = (width - L - R) / buckets.length;
  const bar = Math.min(54, slot * 0.6);

  return h.svg(
    [h.Width(String(width)), h.Height(String(height))],
    [
      ...y.ticks.map((tick) =>
        h.g(
          [],
          [
            h.line([h.Class("grid"), h.X1(String(L)), h.X2(String(width - R)), h.Y1(S(y.at(tick))), h.Y2(S(y.at(tick)))], []),
            h.text([h.X(String(L - 6)), h.Y(S(y.at(tick) + 4)), h.TextAnchor("end")], [pct(tick)]),
          ],
        ),
      ),
      ...buckets.flatMap(({ rate, ...bucket }, index) => {
        const centre = L + slot * (index + 0.5);

        // A filter can leave a gap with no matches: it keeps its label and count but has no bar.
        const drawn = rate.n === 0 ? [] : [
          h.rect([h.X(S(centre - bar / 2)), h.Y(S(y.at(rate.rate))), h.Width(S(bar)), h.Height(S(y.at(0) - y.at(rate.rate))), h.Fill("#cfcfcf"), h.Rx("2")], [h.title([], [`${rate.k} of ${rate.n} matches, 95% CI ${pct(rate.lo)}–${pct(rate.hi)}`])]),
          h.line([h.X1(S(centre)), h.X2(S(centre)), h.Y1(S(y.at(rate.lo))), h.Y2(S(y.at(rate.hi))), h.Stroke("#000"), h.StrokeWidth("1.5")], []),
          h.text([h.X(S(centre)), h.Y(S(y.at(rate.hi) - 6)), h.TextAnchor("middle"), h.Class("val")], [pct(rate.rate)]),
        ];

        return [
          ...drawn,
          h.text([h.X(S(centre)), h.Y(String(height - B + 16)), h.TextAnchor("middle")], [gapName({ ...bucket, rate })]),
          h.text([h.X(S(centre)), h.Y(String(height - B + 30)), h.TextAnchor("middle"), h.Class("dimtext")], [`n ${rate.n}`]),
        ];
      }),
    ],
  );
};

/** A gap in mean regret under this many points per move is left out of the sensitivity check: the first bucket below. */
const TINY_GAP = GAP_EDGES[1] ?? 0;

export const luckView = (h: H, matches: ReadonlyArray<MatchRow>, width: number, content: number): Html => {
  const duels = duelsOf(matches);
  const isNarrow = width <= 1024;
  const side = chartWidth(width, content);
  const higher = ({ k, n }: Share): Share => ({ k: n - k, n });

  return h.div(
    [],
    [
      h.h2([], ["Won with higher estimated regret"]),
      h.p([h.Class("sub")], ["Regret estimates round-win chance, not match-win chance."]),
      duels.length === 0
        ? h.div([h.Class("empty")], ["No match with searched moves on both sides. Start the viewer with --regret."])
        : h.div(
            [h.Class("luckrow")],
            [
              h.div(
                [h.Class("luckbig")],
                [
                  bigNumberView(h, higher(betterShare(duels, "mean")), "of decided matches went to the player with higher regret per move"),
                  bigNumberView(h, higher(betterShare(duels, "total")), "went to the one with higher total regret"),
                  bigNumberView(h, higher(betterShare(duels, "mean", TINY_GAP)), `per move, leaving out gaps under ${TINY_GAP} points`),
                ],
              ),
              h.figure(
                [],
                [h.h3([], ["Regret gap and result"]), h.p([h.Class("sub")], ["Win share of the player with lower regret, by the gap in regret per move, in points."]), bucketsView(h, bucketsOf(duels), isNarrow ? content : content - side - 28)],
              ),
            ],
          ),
    ],
  );
};
