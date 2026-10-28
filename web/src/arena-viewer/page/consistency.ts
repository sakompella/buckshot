import type { Html, HtmlBuilder } from "foldkit/html";

import type { Consistency } from "../api.ts";
import { anchorId, linScale, tippedDot } from "./charts.ts";
import { baseName, colorOf, EFFORTS, fmtPct, groupBy, keyOf, type ModelStats, shortName } from "./data.ts";
import type { Message } from "./model.ts";

type H = HtmlBuilder<Message>;

// Is a config steady? The chance that two of its decisions in the same position chose the same move, within the chosen
// cohort, one row per config, the steadiest model first. The axis spans every cohort's intervals whatever the filter,
// so a filter only shows or hides rows and moves their points.

const ROW = 15;

const GAP = 8;

const T = 8;

const B = 26;

const STEP = 0.1;

const effortOrder = (effort: string): number => EFFORTS.findIndex((known) => known === effort);

/** Configs grouped by model, the model with the highest share of repeated decisions agreeing first, its efforts in order. */
const modelsByAgreement = (rows: ReadonlyArray<Consistency>): ReadonlyArray<ReadonlyArray<Consistency>> =>
  [...groupBy(rows, ({ model }) => model).values()]
    .map((configs) => ({ configs, mean: configs.reduce((sum, { agree, decisions }) => sum + agree * decisions, 0) / configs.reduce((sum, { decisions }) => sum + decisions, 0) }))
    .toSorted((left, right) => right.mean - left.mean)
    .map(({ configs }) => configs.toSorted((left, right) => effortOrder(left.effort) - effortOrder(right.effort)));

export const consistencyView = (h: H, stats: ReadonlyArray<ModelStats>, consistency: ReadonlyArray<Consistency>, cohort: string, width: number): Html => {
  if (consistency.length === 0) return h.empty;

  const isNarrow = width < 600;
  const shown = new Set(stats.map(({ key }) => key));
  const models = modelsByAgreement(consistency.filter((row) => row.cohort === cohort && shown.has(keyOf(row)))).map((configs) => configs.map((config) => ({ ...config, key: keyOf(config) })));
  const left = isNarrow ? 120 : 150;
  const right = isNarrow ? 34 : 44;
  const low = Math.floor(Math.min(...consistency.map(({ lo }) => lo)) / STEP) * STEP;
  const ticks = Array.from({ length: Math.round((1 - low) / STEP) + 1 }, (_, index) => low + index * STEP);
  const x = linScale(low, 1, left, width - right, ticks);
  const rowCount = models.reduce((sum, configs) => sum + configs.length, 0);
  const height = T + rowCount * ROW + Math.max(0, models.length - 1) * GAP + B;

  const placed = models.reduce<{ readonly y: number; readonly rows: ReadonlyArray<readonly [Consistency, number]> }>(
    (done, configs, index) => ({
      y: done.y + configs.length * ROW + (index < models.length - 1 ? GAP : 0),
      rows: [...done.rows, ...configs.map((config, at): readonly [Consistency, number] => [config, done.y + at * ROW + ROW / 2])],
    }),
    { y: T, rows: [] },
  );

  const chart = h.div(
    [h.Class("chart")],
    [
      h.div([h.Class("lbbar")], [h.h2([], ["Same position, same move"])]),
      placed.rows.length === 0
        ? h.div([h.Class("empty")], ["No config has enough repeated positions in this filter."])
        : h.svg(
            [h.Width(String(width)), h.Height(String(height))],
            [
              ...x.ticks.map((tick) =>
                h.g(
                  [],
                  [
                    h.line([h.Class("grid"), h.X1(String(x.at(tick))), h.X2(String(x.at(tick))), h.Y1(String(T)), h.Y2(String(height - B))], []),
                    h.text([h.X(String(x.at(tick))), h.Y(String(height - B + 16)), h.TextAnchor("middle")], [fmtPct(tick)]),
                  ],
                ),
              ),
              ...placed.rows.map(([config, y]) => {
                const color = colorOf(config.model);
                const label = `${isNarrow ? shortName(config.model) : baseName(config.model)} ${config.effort}`;

                return h.g(
                  [],
                  [
                    h.text([h.X(String(left - 8)), h.Y(String(y + 4)), h.TextAnchor("end"), h.Style({ fill: color })], [label]),
                    h.line([h.X1(String(x.at(config.lo))), h.X2(String(x.at(config.hi))), h.Y1(String(y)), h.Y2(String(y)), h.Stroke(color), h.StrokeOpacity("0.4"), h.StrokeWidth("3")], []),
                    tippedDot(h, anchorId("consistency", keyOf(config)), `${label} · ${fmtPct(config.agree)} [${fmtPct(config.lo)}, ${fmtPct(config.hi)}] over ${config.positions} positions, ${config.decisions} decisions`, String(x.at(config.agree)), String(y), [
                      h.R("3.5"),
                      h.Fill(color),
                    ]),
                    h.text([h.X(String(width - right + 8)), h.Y(String(y + 4))], [String(config.positions)]),
                  ],
                );
              }),
            ],
          ),
    ],
  );

  return h.div([h.Class("card")], [chart, h.p([h.Class("sub")], ["Chance two decisions in the same position chose the same move: repeatability, not correctness. 95% interval from resampling seed blocks. Right: the positions met at least twice."])]);
};
