import type { Html, HtmlBuilder } from "foldkit/html";

import { type Decisions, NO_GAP } from "../api.ts";
import { chartWidth, linScale, logScale } from "./charts.ts";
import { baseName, baseOrder, colorOf, DASH, EFFORTS, fmtCount, groupBy, keyOf, labelOf, type SeatFull } from "./data.ts";
import { memoLast } from "./derived.ts";
import { spreadLabels } from "./effort.ts";
import type { Message } from "./model.ts";

type H = HtmlBuilder<Message>;

// Output tokens by health gap: output tokens per model move at each health gap, as a multiple of what the config writes when
// the health is level. One panel per model and a line per effort; a line's label gives its tokens per move when level.
// Two-player matches only. The gaps beyond the ends count in the end points, and a point under MIN_MOVES moves is left out.

/** Health gaps shown, own health minus the opponent's: behind, level, ahead. The two ends take every gap beyond them. */
export const GAPS = [-2, -1, 0, 1, 2] as const;

const MIN_MOVES = 30;

export interface PressurePoint {
  readonly gap: number;
  readonly moves: number;
  /** Mean output tokens per move. */
  readonly tokens: number;
}

/** Each config's points over the moves of the seats in `keep`, by gap from behind to ahead. */
export const pressureCurves = (decisions: Decisions, seats: ReadonlyArray<Pick<SeatFull, "model" | "effort">>, keep: ReadonlyArray<boolean>): ReadonlyMap<string, ReadonlyArray<PressurePoint>> => {
  const lowest = GAPS[0];
  const highest = GAPS[GAPS.length - 1] ?? lowest;
  const tallies = new Map<string, { moves: Array<number>; tokens: Array<number> }>();

  decisions.seat.forEach((seatIndex, move) => {
    const seat = seats[seatIndex];
    const gap = decisions.gap[move] ?? NO_GAP;

    if (seat === undefined || !keep[seatIndex] || gap === NO_GAP) return;

    const key = keyOf(seat);
    const tally = tallies.get(key) ?? { moves: GAPS.map(() => 0), tokens: GAPS.map(() => 0) };
    const slot = Math.max(lowest, Math.min(highest, gap)) - lowest;

    tally.moves[slot] = (tally.moves[slot] ?? 0) + 1;
    tally.tokens[slot] = (tally.tokens[slot] ?? 0) + (decisions.out[move] ?? 0);
    tallies.set(key, tally);
  });

  return new Map(
    [...tallies].map(([key, { moves, tokens }]) => [
      key,
      GAPS.flatMap((gap, slot) => {
        const count = moves[slot] ?? 0;

        return count < MIN_MOVES ? [] : [{ gap, moves: count, tokens: (tokens[slot] ?? 0) / count }];
      }),
    ]),
  );
};

export interface RelativeLine {
  /** Mean output tokens per move when the health is level. */
  readonly level: number;
  readonly points: ReadonlyArray<PressurePoint & { readonly ratio: number }>;
}

/** A curve as multiples of its level-health point; null when it has no such point, or none else to compare it with. */
export const relativeLine = (points: ReadonlyArray<PressurePoint>): RelativeLine | null => {
  const level = points.find(({ gap }) => gap === 0)?.tokens;

  return level === undefined || level === 0 || points.length < 2 ? null : { level, points: points.map((point) => ({ ...point, ratio: point.tokens / level })) };
};

const pressureOf = memoLast(pressureCurves);

const EFFORT_ORDER: ReadonlyArray<string> = EFFORTS;

interface Panel {
  readonly model: string;
  readonly lines: ReadonlyArray<RelativeLine & { readonly key: string; readonly effort: string }>;
}

const panelsOf = (curves: ReadonlyMap<string, ReadonlyArray<PressurePoint>>): ReadonlyArray<Panel> => {
  const lines = [...curves].flatMap(([key, points]) => {
    const line = relativeLine(points);

    return line === null ? [] : [{ key, effort: key.split("|")[1] ?? "", ...line }];
  });

  return [...groupBy(lines, ({ key }) => key.split("|")[0] ?? "")]
    .toSorted(([left], [right]) => baseOrder(left) - baseOrder(right) || left.localeCompare(right))
    .map(([model, modelLines]) => ({ model, lines: modelLines.toSorted((left, right) => EFFORT_ORDER.indexOf(left.effort) - EFFORT_ORDER.indexOf(right.effort)) }));
};

const RATIO_LOW = 0.3;

const RATIO_HIGH = 3;

const AXIS_TICKS = [0.5, 1, 2];

const gapName = (gap: number): string => (gap > 0 ? `+${gap}` : gap < 0 ? `−${-gap}` : "0");

const ratioName = (ratio: number): string => `${ratio >= 10 ? ratio.toFixed(0) : ratio.toFixed(1)}×`;

const panelView = (h: H, { model, lines }: Panel, width: number): Html => {
  const [top, bottom, left, right, height] = [10, 36, 40, 86, 180];
  const x = linScale(GAPS[0], GAPS[GAPS.length - 1] ?? 0, left, width - right, GAPS);
  const y = logScale(RATIO_LOW, RATIO_HIGH, height - bottom, top);
  const color = colorOf(model);
  const labelYs = spreadLabels(lines.map(({ points }) => y.at(points.at(-1)?.ratio ?? 1)));

  return h.svg(
    [h.Width(String(width)), h.Height(String(height))],
    [
      ...AXIS_TICKS.map((tick) =>
        h.g(
          [],
          [
            h.line([h.Class("grid"), h.X1(String(left)), h.X2(String(width - right)), h.Y1(String(y.at(tick))), h.Y2(String(y.at(tick))), ...(tick === 1 ? [h.StrokeDasharray("4 3")] : [])], []),
            h.text([h.X(String(left - 6)), h.Y(String(y.at(tick) + 4)), h.TextAnchor("end")], [ratioName(tick)]),
          ],
        ),
      ),
      ...GAPS.map((gap) => h.text([h.X(String(x.at(gap))), h.Y(String(height - bottom + 16)), h.TextAnchor("middle")], [gapName(gap)])),
      h.text([h.X(String(left)), h.Y(String(height - 4)), h.Class("small")], ["behind"]),
      h.text([h.X(String(width - right)), h.Y(String(height - 4)), h.TextAnchor("end"), h.Class("small")], ["ahead"]),
      ...lines.flatMap(({ key, effort, level, points }, index) => [
        h.path(
          [h.D(points.map(({ gap, ratio }, at) => `${at === 0 ? "M" : "L"}${x.at(gap)},${y.at(ratio)}`).join(" ")), h.Fill("none"), h.Stroke(color), h.StrokeWidth("1.8"), h.StrokeDasharray(DASH.get(effort) ?? "")],
          [],
        ),
        ...points.map(({ gap, moves, tokens, ratio }) =>
          h.circle(
            [h.Cx(String(x.at(gap))), h.Cy(String(y.at(ratio))), h.R("3"), h.Fill(color)],
            [h.title([], [`${labelOf(key)} · gap ${gapName(gap)} · ${fmtCount(tokens)} tokens per move, ${ratioName(ratio)} its level-health ${fmtCount(level)} · ${moves.toLocaleString()} moves`])],
          ),
        ),
        h.text([h.X(String(width - right + 7)), h.Y(String((labelYs[index] ?? 0) + 4)), h.Style({ fill: color }), h.Class("small")], [`${effort} ${fmtCount(level)}`]),
      ]),
    ],
  );
};

export const pressureView = (h: H, decisions: Decisions, seats: ReadonlyArray<SeatFull>, keep: ReadonlyArray<boolean>, width: number, content: number): Html => {
  const panels = panelsOf(pressureOf(decisions, seats, keep));
  const figure = chartWidth(width, content);

  return h.div(
    [],
    [
      h.h2([], ["Output tokens by health gap"]),
      h.p([h.Class("sub")], ["Output tokens per model move by health gap, yours minus the opponent's, as a multiple of the level-health move. Labels give tokens per move when level."]),
      panels.length === 0
        ? h.div([h.Class("empty")], ["No model has enough two-player moves in this filter."])
        : h.div([h.Class("chartrow")], panels.map((panel) => h.figure([], [h.h3([], [baseName(panel.model)]), panelView(h, panel, figure)]))),
    ],
  );
};
