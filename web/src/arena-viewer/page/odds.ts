import type { Html, HtmlBuilder } from "foldkit/html";

import { type ConfigOdds, ODDS_BINS, type ShotTally } from "../aggregates.ts";
import { anchorId, chartWidth, lineKeyView, linScale, tippedDot } from "./charts.ts";
import { baseName, baseOrder, byEffort, colorOf, DASH, effortLabel, groupBy, labelOf, splitKey } from "./data.ts";
import { memoLast } from "./derived.ts";
import type { Message } from "./model.ts";

type H = HtmlBuilder<Message>;

// Playing the odds: for a shot with no glass or phone clue, how often a config shot itself, by the chance it counted the
// chambered shell live. One panel per model and a line per effort, every config the filter keeps.

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

/** The kept configs' shots per bin. */
const talliesOf = memoLast((odds: ReadonlyArray<ConfigOdds>, kept: ReadonlySet<string>): ReadonlyMap<string, ReadonlyArray<ShotTally>> => new Map(odds.flatMap(({ config, bins }) => (kept.has(config) ? [[config, bins] as const] : []))));

interface OddsLine {
  readonly key: string;
  readonly effort: string;
  readonly points: ReadonlyArray<{ readonly bin: number; readonly self: number; readonly shots: number; readonly share: number }>;
}

/** Each model's configs as lines, its efforts in order; a line keeps the bins with enough shots, and needs two of them. */
export const oddsPanels = (tallies: ReadonlyMap<string, ReadonlyArray<ShotTally>>): ReadonlyArray<{ readonly model: string; readonly lines: ReadonlyArray<OddsLine> }> => {
  const lines = [...tallies].flatMap(([key, bins]): ReadonlyArray<OddsLine> => {
    const points = bins.flatMap(({ self, shots }, bin) => (shots >= MIN_SHOTS ? [{ bin, self, shots, share: self / shots }] : []));

    return points.length > 1 ? [{ key, effort: splitKey(key)[1], points }] : [];
  });

  return [...groupBy(lines, ({ key }) => splitKey(key)[0])]
    .toSorted(([left], [right]) => baseOrder(left) - baseOrder(right) || left.localeCompare(right))
    .map(([model, own]) => ({ model, lines: own.toSorted((left, right) => byEffort(left.effort, right.effort)) }));
};

export const droppedConfigs = (kept: ReadonlySet<string>, panels: ReturnType<typeof oddsPanels>): ReadonlyArray<string> => {
  const drawn = new Set(panels.flatMap(({ lines }) => lines.map(({ key }) => key)));

  return [...kept]
    .filter((key) => !drawn.has(key))
    .toSorted((left, right) => baseOrder(left) - baseOrder(right) || byEffort(splitKey(left)[1], splitKey(right)[1]));
};

/** A panel narrower than this keys its lines below instead of naming them at their ends. */
const KEYED_BELOW = 480;

/** The tip at one dot: every effort drawn on that spot, since the dot drawn last would hide the others from a tap. */
const spotText = (lines: ReadonlyArray<OddsLine>, bin: number, isSameSpot: (share: number) => boolean): string =>
  `chance live ${ODDS_BINS[bin]?.label}: ` +
  lines
    .flatMap(({ key, points }) => points.filter((point) => point.bin === bin && isSameSpot(point.share)).map(({ self, shots, share }) => `${labelOf(key)} · ${self} of ${shots} shots at itself (${Math.round(share * 100)}%)`))
    .join("; ");

const panelView = (h: H, model: string, lines: ReadonlyArray<OddsLine>, width: number): Html => {
  const isKeyedBelow = width < KEYED_BELOW;
  const right = isKeyedBelow ? 14 : 62;
  const height = 240;
  const x = linScale(0, ODDS_BINS.length - 1, L + 8, width - right - 10, []);
  const y = linScale(0, 1, height - B, T, [0, 0.25, 0.5, 0.75, 1]);
  const color = colorOf(model);
  const labelYs = spreadLabels(lines.map(({ points }) => y.at(points.at(-1)?.share ?? 0)), height - B);

  const chart = h.svg(
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
      ...ODDS_BINS.map(({ label }, bin) => h.text([h.X(String(x.at(bin))), h.Y(String(height - B + 18)), h.TextAnchor("middle"), h.Class("small")], [label])),
      h.text([h.X(String((L + width - right) / 2)), h.Y(String(height - 6)), h.TextAnchor("middle"), h.Class("small")], ["chance the chambered shell is live"]),
      ...lines.flatMap(({ key, effort, points }, index) => [
        h.path([h.D(points.map(({ bin, share }, at) => `${at === 0 ? "M" : "L"}${x.at(bin)},${y.at(share)}`).join(" ")), h.Fill("none"), h.Stroke(color), h.StrokeWidth("1.6"), h.StrokeDasharray(DASH.get(effort) ?? "")], []),
        ...points.map(({ bin, share }) =>
          tippedDot(h, anchorId("odds", key, bin), spotText(lines, bin, (other) => Math.abs(y.at(other) - y.at(share)) < 1), String(x.at(bin)), String(y.at(share)), [h.R("3"), h.Fill(color)]),
        ),
        ...(isKeyedBelow
          ? []
          : [
              h.path([h.D(`M${x.at(points.at(-1)?.bin ?? 0) + 3},${y.at(points.at(-1)?.share ?? 0)} L${width - right + 6},${labelYs[index] ?? 0} h2`), h.Fill("none"), h.Stroke(color), h.StrokeOpacity("0.6")], []),
              h.text([h.X(String(width - right + 10)), h.Y(String((labelYs[index] ?? 0) + 4)), h.Style({ fill: color }), h.Class("small")], [effortLabel(model, effort)]),
            ]),
      ]),
    ],
  );

  return isKeyedBelow ? h.div([], [chart, lineKeyView(h, lines.map(({ effort }) => ({ label: effortLabel(model, effort), color, dash: DASH.get(effort) ?? "" })))]) : chart;
};

export const droppedText = (keys: ReadonlyArray<string>): string =>
  [...groupBy(keys, (key) => splitKey(key)[0])].map(([model, own]) => `${baseName(model)} ${own.map((key) => effortLabel(model, splitKey(key)[1])).join(", ")}`).join(" · ");

export const oddsView = (h: H, odds: ReadonlyArray<ConfigOdds>, kept: ReadonlySet<string>, width: number, content: number): Html => {
  const panels = oddsPanels(talliesOf(odds, kept));
  const dropped = droppedConfigs(kept, panels);
  const figure = chartWidth(width, content);

  return h.div(
    [],
    [
      h.h2([], ["Playing the odds"]),
      h.p([h.Class("sub")], ["How often each config shoots itself, by the chance the chambered shell is live as it counts the shells. One panel per model, a line per effort. Shots with no glass or phone clue."]),
      panels.length === 0
        ? h.div([h.Class("empty")], ["No config in this filter has enough shots."])
        : h.div([h.Class("chartrow")], panels.map(({ model, lines }) => h.figure([], [h.h3([], [baseName(model)]), panelView(h, model, lines, figure)]))),
      dropped.length === 0 ? h.empty : h.p([h.Class("k dropped")], [`Left out for too few shots: ${droppedText(dropped)}.`]),
    ],
  );
};
