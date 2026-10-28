import type { Html, HtmlBuilder } from "foldkit/html";

import { chartWidth, linScale } from "./charts.ts";
import { addTo, type BlockTally, blockRate, colorOfKey, keyOf, labelOf, type MatchRow, type ModelStats, type Rate, type SeatFull, shortName, winnerOf } from "./data.ts";
import type { Message } from "./model.ts";

type H = HtmlBuilder<Message>;

// Luck vs play: how often the player who gave up more win chance still won. Regret is the minimax player's verdict on each
// move (docs/arena/analysis/regret.md), so "played better" here means "gave up less win chance", not "won".

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

/** Loser's regret minus winner's: positive when the winner played better, zero when it is a tie. */
export const gapOf = ({ winner, loser }: Duel, measure: Measure): number => regretOf(loser, measure) - regretOf(winner, measure);

/** Duels that one player played better; a tie has no better player. */
const separated = (duels: ReadonlyArray<Duel>, measure: Measure): ReadonlyArray<Duel> => duels.filter((duel) => gapOf(duel, measure) !== 0);

export interface Share {
  readonly k: number;
  readonly n: number;
}

/** The share of duels the better player won. */
export const betterShare = (duels: ReadonlyArray<Duel>, measure: Measure): Share => {
  const decided = separated(duels, measure);

  return { k: decided.filter((duel) => gapOf(duel, measure) > 0).length, n: decided.length };
};

/** Gaps in points of regret per move where a bucket of the chart starts. */
export const GAP_EDGES: ReadonlyArray<number> = [0, 0.5, 1, 2, 4];

export interface GapBucket {
  readonly from: number;
  readonly to: number | null;
  /** The better player's win share, with a seed-block interval. */
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

export interface ConfigLuck {
  readonly key: string;
  readonly matches: number;
  /** Matches won while playing worse than the opponent. */
  readonly luckyWins: number;
  /** Matches lost while playing better than the opponent. */
  readonly unluckyLosses: number;
}

/** Each config's luck over every duel it played, the luckiest first. A config that plays itself is counted on both sides. */
export const luckByConfig = (duels: ReadonlyArray<Duel>, isFocal: (key: string) => boolean): ReadonlyArray<ConfigLuck> => {
  const rows = new Map<string, { matches: number; luckyWins: number; unluckyLosses: number }>();
  const rowOf = (key: string) => rows.get(key) ?? (rows.set(key, { matches: 0, luckyWins: 0, unluckyLosses: 0 }), rows.get(key));

  for (const duel of duels) {
    const gap = gapOf(duel, "mean");
    const [won, lost] = [rowOf(keyOf(duel.winner)), rowOf(keyOf(duel.loser))];

    if (won === undefined || lost === undefined) continue;

    won.matches++;
    lost.matches++;

    if (gap < 0) {
      won.luckyWins++;
      lost.unluckyLosses++;
    }
  }

  return [...rows]
    .flatMap(([key, row]) => (isFocal(key) ? [{ key, ...row }] : []))
    .toSorted((left, right) => (right.luckyWins - right.unluckyLosses) / right.matches - (left.luckyWins - left.unluckyLosses) / left.matches);
};

const pct = (value: number): string => `${(value * 100).toFixed(0)}%`;

const S = (value: number): string => value.toFixed(1);

const bigNumberView = (h: H, share: Share, label: string): Html =>
  h.div([h.Class("bignum")], [h.b([], [pct(share.k / share.n)]), h.span([h.Class("lbl")], [label]), h.span([h.Class("pm")], [`${share.k.toLocaleString()} of ${share.n.toLocaleString()} decided matches`])]);

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

/** Matches under which a config's luck row fades: its shares rest on a few games. */
const FEW = 20;

const rowsView = (h: H, rows: ReadonlyArray<ConfigLuck>, width: number): Html => {
  const isNarrow = width < 600;
  const [L, R, T] = [isNarrow ? 122 : 150, isNarrow ? 28 : 40, 34];
  const step = 22;
  const height = T + rows.length * step + 4;
  const reach = Math.max(0.05, ...rows.flatMap((row) => [row.luckyWins / row.matches, row.unluckyLosses / row.matches]));
  const half = (width - L - R) / 2;
  const mid = L + half;
  const x = linScale(0, reach, 0, half - 34, []);
  const name = (key: string) => (isNarrow ? `${shortName(key.split("|")[0] ?? "")} ${key.split("|")[1] ?? ""}` : labelOf(key));

  return h.svg(
    [h.Width(String(width)), h.Height(String(height))],
    [
      h.text([h.X(S(mid - 8)), h.Y("14"), h.TextAnchor("end"), h.Class("dimtext")], ["← lost though better"]),
      h.text([h.X(S(mid + 8)), h.Y("14"), h.Class("dimtext")], ["won though worse →"]),
      h.line([h.X1(S(mid)), h.X2(S(mid)), h.Y1(String(T - 6)), h.Y2(String(height)), h.Stroke("#3a3a3a")], []),
      ...rows.flatMap((row, index) => {
        const top = T + index * step;
        const color = colorOfKey(row.key);
        const [lucky, unlucky] = [row.luckyWins / row.matches, row.unluckyLosses / row.matches];

        return [
          h.g(
            [h.Opacity(row.matches < FEW ? "0.45" : "1")],
            [
              h.text([h.X(String(L - 8)), h.Y(S(top + 12)), h.TextAnchor("end"), h.Style({ fill: color })], [name(row.key)]),
              h.rect([h.X(S(mid - x.at(unlucky))), h.Y(S(top + 3)), h.Width(S(x.at(unlucky))), h.Height("13"), h.Fill(color), h.FillOpacity("0.4")], [h.title([], [`${labelOf(row.key)}: lost ${row.unluckyLosses} of ${row.matches} matches while playing better`])]),
              h.rect([h.X(S(mid)), h.Y(S(top + 3)), h.Width(S(x.at(lucky))), h.Height("13"), h.Fill(color)], [h.title([], [`${labelOf(row.key)}: won ${row.luckyWins} of ${row.matches} matches while playing worse`])]),
              h.text([h.X(S(mid - x.at(unlucky) - 4)), h.Y(S(top + 13)), h.TextAnchor("end"), h.Class("dimtext")], [pct(unlucky)]),
              h.text([h.X(S(mid + x.at(lucky) + 4)), h.Y(S(top + 13)), h.Class("dimtext")], [pct(lucky)]),
            ],
          ),
        ];
      }),
    ],
  );
};

export const luckView = (h: H, matches: ReadonlyArray<MatchRow>, configs: ReadonlyArray<ModelStats>, width: number, content: number, card: number): Html => {
  const duels = duelsOf(matches);
  const isNarrow = width <= 1024;
  const side = chartWidth(width, content);
  const focal = new Set(configs.map(({ key }) => key));
  const rows = luckByConfig(duels, (key) => focal.has(key));
  const [mean, total] = [betterShare(duels, "mean"), betterShare(duels, "total")];

  return h.div(
    [],
    [
      h.h2([], ["Luck vs play"]),
      duels.length === 0
        ? h.div([h.Class("empty")], ["No match with searched moves on both sides. Start the viewer with --regret."])
        : h.div(
            [],
            [
              h.div(
                [h.Class("luckrow")],
                [
                  h.div(
                    [h.Class("luckbig")],
                    [
                      bigNumberView(h, { k: mean.n - mean.k, n: mean.n }, "of matches went to the player who gave up more win chance per move"),
                      bigNumberView(h, { k: total.n - total.k, n: total.n }, "went to the one who gave up more in total"),
                    ],
                  ),
                  h.figure(
                    [],
                    [h.h3([], ["Better play wins more often"]), h.p([h.Class("sub")], ["The better player's win share by the gap in regret per move, in points."]), bucketsView(h, bucketsOf(duels), isNarrow ? content : content - side - 28)],
                  ),
                ],
              ),
              h.div([h.Class("card")], [h.h3([], ["Who got lucky"]), rowsView(h, rows, card)]),
            ],
          ),
    ],
  );
};
