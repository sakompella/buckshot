import type { Html, HtmlBuilder } from "foldkit/html";

import { linScale } from "./charts.ts";
import { addTo, baseOrder, type BlockTally, blockRate, EFFORTS, fmtCI, type ModelStats, type Rate, roundResults, type SeatFull } from "./data.ts";
import type { Message } from "./model.ts";

type H = HtmlBuilder<Message>;

// Results after round 1: how often a config wins round 2 after winning round 1, and round 3 at 1-1. One row per config.
// Descriptive only: opponents, seeds and which matches reach each state differ between rows.

/** A config's chance of the round after a lead, and at 1-1, each a rate over its scored matches with seed-block intervals. */
export interface Momentum {
  /** Wins round 2 after winning round 1. */
  readonly afterWin: Rate;
  /** Wins round 3 when rounds 1 and 2 were split. */
  readonly decider: Rate;
}

export const momentumOf = (seats: ReadonlyArray<Pick<SeatFull, "story" | "player" | "seedBlock">>): Momentum => {
  const afterWin: BlockTally = new Map();
  const decider: BlockTally = new Map();

  for (const seat of seats) {
    const [first, second, third] = roundResults(seat);

    if (first === 1 && second !== undefined) addTo(afterWin, seat.seedBlock, second, 1);

    if (first !== undefined && second !== undefined && first !== second && third !== undefined) addTo(decider, seat.seedBlock, third, 1);
  }

  return { afterWin: blockRate(afterWin), decider: blockRate(decider) };
};

interface Row {
  readonly m: ModelStats;
  readonly momentum: Momentum;
}

const ROW = 22;

const T = 8;

const B = 26;

const EFFORT_ORDER: ReadonlyArray<string> = EFFORTS;

const rowsOf = (stats: ReadonlyArray<ModelStats>): ReadonlyArray<Row> =>
  stats
    .toSorted((left, right) => baseOrder(left.model) - baseOrder(right.model) || left.model.localeCompare(right.model) || EFFORT_ORDER.indexOf(left.effort) - EFFORT_ORDER.indexOf(right.effort))
    .flatMap((m) => {
      const momentum = momentumOf(m.scored);

      return Number.isNaN(momentum.afterWin.rate) || Number.isNaN(momentum.decider.rate) ? [] : [{ m, momentum }];
    });

const percent = (rate: number): string => `${Math.round(rate * 100)}%`;

const tipOf = (name: string, rate: Rate): string => `${name}: ${percent(rate.rate)} of ${rate.n} · ${fmtCI(rate)}`;

export const momentumView = (h: H, stats: ReadonlyArray<ModelStats>, width: number): Html => {
  const rows = rowsOf(stats);
  const isNarrow = width < 600;
  const left = isNarrow ? 146 : 170;
  const right = 12;
  const height = T + rows.length * ROW + B;
  const x = linScale(0, 1, left, width - right, [0, 0.25, 0.5, 0.75, 1]);
  const y = (index: number) => T + index * ROW + ROW / 2;

  return h.div(
    [h.Class("chart")],
    [
      h.div(
        [h.Class("lbbar")],
        [h.h2([], ["Results after round 1"]), h.span([h.Class("k")], ["● wins round 2 after winning round 1"]), h.span([h.Class("k")], ["◇ wins round 3 when it is 1–1"]), h.span([h.Class("k")], ["| its round share"])],
      ),
      rows.length === 0
        ? h.div([h.Class("empty")], ["No config has matches with known rounds in this filter."])
        : h.svg(
            [h.Width(String(width)), h.Height(String(height))],
            [
              ...x.ticks.map((tick) =>
                h.g(
                  [],
                  [
                    h.line([h.Class("grid"), h.X1(String(x.at(tick))), h.X2(String(x.at(tick))), h.Y1(String(T)), h.Y2(String(height - B))], []),
                    h.text([h.X(String(x.at(tick))), h.Y(String(height - B + 16)), h.TextAnchor("middle")], [percent(tick)]),
                  ],
                ),
              ),
              ...rows.flatMap(({ m, momentum }, index) => {
                const dot = (rate: Rate, dy: number, isRing: boolean, name: string): Html =>
                  h.circle(
                    [h.Cx(String(x.at(rate.rate))), h.Cy(String(y(index) + dy)), h.R("3.5"), h.Fill(isRing ? "#000" : m.color), h.Stroke(m.color), h.StrokeWidth("1.5")],
                    [h.title([], [`${m.label} · ${tipOf(name, rate)}`])],
                  );

                return [
                  h.text([h.X(String(left - 8)), h.Y(String(y(index) + 4)), h.TextAnchor("end"), h.Style({ fill: m.color }), h.Class("lbl")], [m.label]),
                  h.line([h.X1(String(x.at(m.roundShare))), h.X2(String(x.at(m.roundShare))), h.Y1(String(y(index) - 9)), h.Y2(String(y(index) + 9)), h.Stroke("#8b8b8b"), h.StrokeWidth("1.5")], []),
                  h.line([h.X1(String(x.at(momentum.afterWin.rate))), h.X2(String(x.at(momentum.decider.rate))), h.Y1(String(y(index) - 3)), h.Y2(String(y(index) + 3)), h.Stroke(m.color), h.StrokeOpacity("0.5"), h.StrokeWidth("1.5")], []),
                  dot(momentum.afterWin, -3, false, "wins round 2 after winning round 1"),
                  dot(momentum.decider, 3, true, "wins round 3 at 1–1"),
                ];
              }),
            ],
          ),
    ],
  );
};
