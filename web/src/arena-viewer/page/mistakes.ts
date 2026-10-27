import type { Html, HtmlBuilder } from "foldkit/html";

import type { Mistakes } from "../api.ts";
import { linScale } from "./charts.ts";
import { spreadLabels } from "./effort.ts";
import { baseName, baseOrder, colorOf, fmtCount, fmtPoints, shortName } from "./data.ts";
import type { Message } from "./model.ts";

type H = HtmlBuilder<Message>;

// Where in a load the mistakes are: the mean regret of a model's moves by how many shells are left in the gun,
// shots on one chart and every other move on the other. Both share one y axis, which spans every config whatever the filter.

/** Shells left in a full load: the chart's x axis runs 1 to 6. */
const MOST_LEFT = 6;

/** A point on fewer moves than this is left out. */
const MIN_MOVES = 30;

export interface ShellPoint {
  readonly left: number;
  readonly moves: number;
  /** Mean regret per move, in points of the round win chance. */
  readonly mean: number;
}

export interface ShellLine {
  readonly model: string;
  readonly points: ReadonlyArray<ShellPoint>;
}

/** One line per model, over the kept seats' searched moves of one kind, from the fewest shells left up. */
export const shellLines = (mistakes: Mistakes, seats: ReadonlyArray<{ readonly model: string }>, keep: ReadonlyArray<boolean>, isShot: boolean): ReadonlyArray<ShellLine> => {
  const tallies = new Map<string, Array<{ moves: number; total: number }>>();

  mistakes.seat.forEach((seat, index) => {
    const model = seats[seat]?.model;

    if (model === undefined || keep[seat] !== true || (mistakes.isShot[index] === 1) !== isShot) return;

    const byLeft = tallies.get(model) ?? Array.from({ length: MOST_LEFT + 1 }, () => ({ moves: 0, total: 0 }));
    const tally = byLeft[mistakes.left[index] ?? 0];

    tallies.set(model, byLeft);

    if (tally !== undefined) {
      tally.moves++;
      tally.total += mistakes.points[index] ?? 0;
    }
  });

  return [...tallies]
    .flatMap(([model, byLeft]) => {
      const points = byLeft.flatMap(({ moves, total }, left) => (left >= 1 && moves >= MIN_MOVES ? [{ left, moves, mean: total / moves }] : []));

      return points.length > 0 ? [{ model, points }] : [];
    })
    .toSorted((left, right) => baseOrder(left.model) - baseOrder(right.model));
};

const T = 12;

const B = 40;

const L = 40;

const panelView = (h: H, title: string, lines: ReadonlyArray<ShellLine>, top: number, width: number, isNarrow: boolean): Html => {
  const right = isNarrow ? 70 : 100;
  const height = isNarrow ? 240 : 280;
  const x = linScale(1, MOST_LEFT, L, width - right, []);
  const y = linScale(0, top, height - B, T, []);
  const ticks = Array.from({ length: Math.floor(top / 2) + 1 }, (_, index) => index * 2);
  const spread = spreadLabels(lines.map(({ points }) => y.at(points.at(-1)?.mean ?? 0)));
  const lift = Math.max(0, Math.max(...spread) - (height - 8));
  const labelYs = spread.map((at) => at - lift);

  return h.div(
    [],
    [
      h.h3([], [title]),
      h.svg(
        [h.Width(String(width)), h.Height(String(height))],
        [
          ...ticks.map((tick) =>
            h.g(
              [],
              [
                h.line([h.Class("grid"), h.X1(String(L)), h.X2(String(width - right)), h.Y1(String(y.at(tick))), h.Y2(String(y.at(tick)))], []),
                h.text([h.X(String(L - 6)), h.Y(String(y.at(tick) + 4)), h.TextAnchor("end")], [String(tick)]),
              ],
            ),
          ),
          ...Array.from({ length: MOST_LEFT }, (_, index) => h.text([h.X(String(x.at(index + 1))), h.Y(String(height - B + 18)), h.TextAnchor("middle")], [String(index + 1)])),
          h.text([h.X(String((L + width - right) / 2)), h.Y(String(height - 6)), h.TextAnchor("middle")], ["shells left in the gun"]),
          ...lines.flatMap(({ model, points }, index) => {
            const color = colorOf(model);

            return [
              h.path([h.D(points.map(({ left, mean }, at) => `${at === 0 ? "M" : "L"}${x.at(left)},${y.at(mean)}`).join(" ")), h.Fill("none"), h.Stroke(color), h.StrokeWidth("1.8")], []),
              ...points.map(({ left, moves, mean }) =>
                h.circle([h.Cx(String(x.at(left))), h.Cy(String(y.at(mean))), h.R("3.2"), h.Fill(color)], [h.title([], [`${baseName(model)} · ${left} left · ${fmtPoints(mean)} points over ${fmtCount(moves)} moves`])]),
              ),
              h.text([h.X(String(x.at(points.at(-1)?.left ?? MOST_LEFT) + 8)), h.Y(String((labelYs[index] ?? 0) + 4)), h.Style({ fill: color }), h.Class("lbl")], [isNarrow ? shortName(model) : baseName(model)]),
            ];
          }),
        ],
      ),
    ],
  );
};

const PANEL_GAP = 28;

export const mistakesView = (h: H, mistakes: Mistakes, seats: ReadonlyArray<{ readonly model: string }>, keep: ReadonlyArray<boolean>, viewportWidth: number, cardWidth: number): Html => {
  const every = seats.map(() => true);
  const panelWidth = viewportWidth > 1024 ? Math.floor((cardWidth - PANEL_GAP) / 2) : cardWidth;
  const kinds = [true, false] as const;

  const top = Math.ceil(Math.max(0, ...kinds.flatMap((isShot) => shellLines(mistakes, seats, every, isShot).flatMap(({ points }) => points.map(({ mean }) => mean)))) / 2) * 2;

  return h.div(
    [h.Class("card")],
    [
      h.div([h.Class("lbbar")], [h.h2([], ["Where mistakes happen"]), h.span([h.Class("k")], ["mean regret per move, in points"])]),
      mistakes.seat.length === 0
        ? h.div([h.Class("empty")], ["Start the viewer with --regret to see regret."])
        : h.div([h.Class("chartpair")], [panelView(h, "Shots", shellLines(mistakes, seats, keep, true), top, panelWidth, viewportWidth < 600), panelView(h, "Other moves", shellLines(mistakes, seats, keep, false), top, panelWidth, viewportWidth < 600)]),
    ],
  );
};
