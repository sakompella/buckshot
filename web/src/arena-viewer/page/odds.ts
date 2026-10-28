import type { Html, HtmlBuilder } from "foldkit/html";

import type { Decisions } from "../api.ts";
import { linScale } from "./charts.ts";
import { baseName, DEFAULT_EFFORT, groupBy, keyOf, type ModelStats, type SeatFull, shortName } from "./data.ts";
import { memoLast } from "./derived.ts";
import type { Message } from "./model.ts";

type H = HtmlBuilder<Message>;

// Playing the odds: for a shot with no glass or phone clue, how often a config shot itself, by the chance it counted the
// chambered shell live. A blank at oneself keeps the turn and a live one costs health, so the rule of thumb is a step:
// shoot yourself below 50% and the opponent above it.

/** Chance-live bins in whole percent, ends inclusive. The ends and the even odds are bins of their own: counting shells shows there. */
export const ODDS_BINS: ReadonlyArray<{ readonly label: string; readonly low: number; readonly high: number }> = [
  { label: "0%", low: 0, high: 0 },
  { label: "1–33", low: 1, high: 33 },
  { label: "34–49", low: 34, high: 49 },
  { label: "50", low: 50, high: 50 },
  { label: "51–99", low: 51, high: 99 },
  { label: "100%", low: 100, high: 100 },
];

export const oddsBinOf = (percent: number): number => ODDS_BINS.findIndex(({ low, high }) => percent >= low && percent <= high);

/** Shots aimed at oneself over all shots, per bin, for each config of a kept seat. A shot without clue odds counts nowhere. */
export const selfShotTallies = (decisions: Pick<Decisions, "odds" | "seat" | "shot">, seats: ReadonlyArray<Pick<SeatFull, "model" | "effort">>, keep: ReadonlyArray<boolean>): ReadonlyMap<string, ReadonlyArray<{ readonly self: number; readonly shots: number }>> => {
  const tallies = new Map<string, Array<{ self: number; shots: number }>>();

  decisions.odds.forEach((percent, move) => {
    const seatAt = decisions.seat[move] ?? -1;
    const seat = seats[seatAt];
    const bin = oddsBinOf(percent);

    if (seat === undefined || keep[seatAt] !== true || bin < 0) return;

    const key = keyOf(seat);
    const bins = tallies.get(key) ?? ODDS_BINS.map(() => ({ self: 0, shots: 0 }));
    const tally = bins[bin];

    if (tally) {
      tally.shots++;

      if (decisions.shot[move] === 2) tally.self++;
    }

    tallies.set(key, bins);
  });

  return tallies;
};

/** A bin with fewer shots than this is left off a config's line. */
const MIN_SHOTS = 30;

const T = 16;

const B = 44;

const L = 46;

const LABEL_GAP = 13;

/** End labels from the top down, pushed apart so none overlaps the one above, and pulled up so none passes `bottom`. */
const spreadLabels = (ys: ReadonlyArray<number>, bottom: number): ReadonlyArray<number> => {
  const order = ys.map((y, index) => ({ y, index })).toSorted((left, right) => left.y - right.y);
  const placed = ys.map(() => 0);
  let last = Number.NEGATIVE_INFINITY;

  for (const { y, index } of order) {
    last = Math.max(y, last + LABEL_GAP);
    placed[index] = last;
  }

  let limit = bottom;

  for (const { index } of order.toReversed()) {
    limit = Math.min(placed[index] ?? limit, limit);
    placed[index] = limit;
    limit -= LABEL_GAP;
  }

  return placed;
};

const talliesOf = memoLast(selfShotTallies);

/** Each model's medium config, or its most-shot config where it has no medium, so the lines are models and not every effort. */
export const mainConfigPerModel = (configs: ReadonlyArray<ModelStats>, shotsOf: (key: string) => number): ReadonlyArray<ModelStats> =>
  [...groupBy(configs, ({ model }) => model).values()].flatMap((own) => {
    const medium = own.find(({ effort }) => effort === DEFAULT_EFFORT);
    const [most] = own.toSorted((left, right) => shotsOf(right.key) - shotsOf(left.key));

    return medium ?? most ?? [];
  });

/** One line per model, at medium. Each stays within its bins that have enough shots. */
export const oddsView = (h: H, decisions: Decisions, seats: ReadonlyArray<SeatFull>, keep: ReadonlyArray<boolean>, configs: ReadonlyArray<ModelStats>, width: number): Html => {
  const isNarrow = width < 600;
  const tallies = talliesOf(decisions, seats, keep);
  const right = isNarrow ? 66 : 120;
  const height = isNarrow ? 300 : 360;
  const x = linScale(0, ODDS_BINS.length - 1, L + 8, width - right - 14, []);
  const y = linScale(0, 1, height - B, T, [0, 0.25, 0.5, 0.75, 1]);

  const shots = (key: string) => (tallies.get(key) ?? []).reduce((total, bin) => total + bin.shots, 0);

  const lines = mainConfigPerModel(configs, shots).flatMap((m) => {
    const bins = tallies.get(m.key) ?? [];
    const points = bins.flatMap(({ self, shots }, bin) => (shots >= MIN_SHOTS ? [{ bin, self, shots, share: self / shots }] : []));

    return points.length > 1 ? [{ m, points }] : [];
  });

  const labelYs = spreadLabels(lines.map(({ points }) => y.at(points.at(-1)?.share ?? 0)), height - B);
  const rule = ODDS_BINS.map(({ low }, bin) => `${bin === 0 ? "M" : "L"}${x.at(bin)},${y.at(low < 50 ? 1 : low === 50 ? 0.5 : 0)}`).join(" ");

  return h.div(
    [h.Class("chart")],
    [
      h.div([h.Class("lbbar")], [h.h2([], ["Playing the odds"])]),
      h.p([h.Class("sub")], ["How often each model, at medium effort, shoots itself, by the chance the chambered shell is live as it counts the shells. The grey line is the rule of thumb. Shots with no glass or phone clue."]),
      lines.length === 0
        ? h.div([h.Class("empty")], ["No config in this filter has enough shots."])
        : h.svg(
            [h.Width(String(width)), h.Height(String(height))],
            [
              ...y.ticks.map((tick) =>
                h.g(
                  [],
                  [
                    h.line([h.Class("grid"), h.X1(String(L)), h.X2(String(width - right)), h.Y1(String(y.at(tick))), h.Y2(String(y.at(tick)))], []),
                    h.text([h.X(String(L - 6)), h.Y(String(y.at(tick) + 4)), h.TextAnchor("end")], [`${tick * 100}%`]),
                  ],
                ),
              ),
              ...ODDS_BINS.map(({ label }, bin) => h.text([h.X(String(x.at(bin))), h.Y(String(height - B + 18)), h.TextAnchor("middle")], [label])),
              h.text([h.X(String((L + width - right) / 2)), h.Y(String(height - 6)), h.TextAnchor("middle")], ["chance the chambered shell is live"]),
              h.path([h.D(rule), h.Fill("none"), h.Stroke("#555"), h.StrokeWidth("1.2"), h.StrokeDasharray("4 4")], []),
              ...lines.flatMap(({ m, points }, index) => {
                const color = m.color;

                return [
                  h.path([h.D(points.map(({ bin, share }, at) => `${at === 0 ? "M" : "L"}${x.at(bin)},${y.at(share)}`).join(" ")), h.Fill("none"), h.Stroke(color), h.StrokeWidth("1.6"), h.StrokeDasharray(m.dash)], []),
                  ...points.map(({ bin, self, shots, share }) =>
                    h.circle([h.Cx(String(x.at(bin))), h.Cy(String(y.at(share))), h.R("3.2"), h.Fill(color)], [h.title([], [`${m.label} · chance live ${ODDS_BINS[bin]?.label} · ${self} of ${shots} shots at itself (${Math.round(share * 100)}%)`])]),
                  ),
                  h.text([h.X(String(width - right + 8)), h.Y(String((labelYs[index] ?? 0) + 4)), h.Style({ fill: color }), h.Class("lbl")], [isNarrow ? shortName(m.model) : baseName(m.model)]),
                ];
              }),
            ],
          ),
    ],
  );
};
