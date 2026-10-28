import type { Html, HtmlBuilder } from "foldkit/html";

import { linScale } from "./charts.ts";
import { baseName, baseOrder, EFFORTS, eloName, fmtRating, groupBy, type ModelStats, shortName } from "./data.ts";
import type { Basis, Message } from "./model.ts";
import type { Rating } from "./ratings.ts";

type H = HtmlBuilder<Message>;

// Does thinking harder help? One line per model across its efforts, each point its rating with the 95% interval.
// The y axis spans every config's interval whatever the filter, so a filter only shows or hides lines.

const T = 16;

const B = 34;

const L = 46;

const LABEL_GAP = 13;

/** Effort names short enough for a phone's axis. */
const SHORT_EFFORT = new Map([
  ["minimal", "min"],
  ["medium", "med"],
  ["xhigh", "xhi"],
]);

interface Line {
  readonly name: string;
  readonly color: string;
  readonly points: ReadonlyArray<{ readonly m: ModelStats; readonly rating: Rating }>;
}

/** End labels from the top down, pushed apart so none overlaps the one above. */
export const spreadLabels = (ys: ReadonlyArray<number>): ReadonlyArray<number> => {
  const order = ys.map((y, index) => ({ y, index })).toSorted((left, right) => left.y - right.y);
  const placed = ys.map(() => 0);
  let last = Number.NEGATIVE_INFINITY;

  for (const { y, index } of order) {
    last = Math.max(y, last + LABEL_GAP);
    placed[index] = last;
  }

  return placed;
};

export const effortView = (h: H, stats: ReadonlyArray<ModelStats>, ratings: ReadonlyMap<string, Rating>, basis: Basis, width: number): Html => {
  const isNarrow = width < 600;
  const efforts: ReadonlyArray<string> = EFFORTS.filter((effort) => [...ratings.keys()].some((key) => key.endsWith(`|${effort}`)));

  const lines: ReadonlyArray<Line> = [...groupBy(stats, (m) => m.model)]
    .toSorted(([left], [right]) => baseOrder(left) - baseOrder(right))
    .flatMap(([model, configs]) => {
      const points = configs
        .flatMap((m) => {
          const rating = ratings.get(m.key);

          return rating === undefined || m.scored.length === 0 ? [] : [{ m, rating }];
        })
        .toSorted((left, right) => efforts.indexOf(left.m.effort) - efforts.indexOf(right.m.effort));

      return points.length > 1 ? [{ name: isNarrow ? shortName(model) : baseName(model), color: configs[0]?.color ?? "#999", points }] : [];
    });

  const every = [...ratings.values()];
  const low = Math.floor(Math.min(...every.map(({ lo }) => lo)) / 100) * 100;
  const high = Math.ceil(Math.max(...every.map(({ hi }) => hi)) / 100) * 100;
  const right = isNarrow ? 78 : 110;
  const height = isNarrow ? 300 : 360;
  const x = linScale(0, Math.max(1, efforts.length - 1), L, width - right, []);
  const ticks = Array.from({ length: Math.floor((high - low) / 100) + 1 }, (_, index) => low + index * 100);
  const y = linScale(low, high, height - B, T, ticks);
  const xOf = (effort: string) => x.at(efforts.indexOf(effort));
  const labelYs = spreadLabels(lines.map(({ points }) => y.at(points.at(-1)?.rating.rating ?? 0)));

  return h.div(
    [h.Class("chart")],
    [
      h.div([h.Class("lbbar")], [h.h2([], [`Effort vs ${eloName(basis)}`])]),
      lines.length === 0
        ? h.div([h.Class("empty")], ["No model has two efforts in this filter."])
        : h.svg(
            [h.Width(String(width)), h.Height(String(height))],
            [
              ...y.ticks.map((tick) =>
                h.g(
                  [],
                  [
                    h.line([h.Class("grid"), h.X1(String(L)), h.X2(String(width - right)), h.Y1(String(y.at(tick))), h.Y2(String(y.at(tick)))], []),
                    h.text([h.X(String(L - 6)), h.Y(String(y.at(tick) + 4)), h.TextAnchor("end")], [fmtRating(tick)]),
                  ],
                ),
              ),
              ...efforts.map((effort) => h.text([h.X(String(xOf(effort))), h.Y(String(height - B + 18)), h.TextAnchor("middle")], [isNarrow ? (SHORT_EFFORT.get(effort) ?? effort) : effort])),
              ...lines.flatMap(({ name, color, points }, index) => [
                h.path([h.D(points.map(({ m, rating }, at) => `${at === 0 ? "M" : "L"}${xOf(m.effort)},${y.at(rating.rating)}`).join(" ")), h.Fill("none"), h.Stroke(color), h.StrokeWidth("1.6")], []),
                ...points.map(({ m, rating }) =>
                  h.g(
                    [],
                    [
                      h.line([h.X1(String(xOf(m.effort))), h.X2(String(xOf(m.effort))), h.Y1(String(y.at(rating.lo))), h.Y2(String(y.at(rating.hi))), h.Stroke(color), h.StrokeOpacity("0.35"), h.StrokeWidth("3")], []),
                      h.circle([h.Cx(String(xOf(m.effort))), h.Cy(String(y.at(rating.rating))), h.R("3.5"), h.Fill(color)], [h.title([], [`${m.label} · ${fmtRating(rating.rating)} [${fmtRating(rating.lo)}, ${fmtRating(rating.hi)}]`])]),
                    ],
                  ),
                ),
                h.text([h.X(String(xOf(points.at(-1)?.m.effort ?? "") + 8)), h.Y(String((labelYs[index] ?? 0) + 4)), h.Style({ fill: color }), h.Class("lbl")], [name]),
              ]),
            ],
          ),
    ],
  );
};
