import type { Html, HtmlBuilder } from "foldkit/html";

import { baseName, baseOrder, byEffort, costPerMove, fmtUsd, groupBy, type ModelStats, type SeatFull, sumOf } from "./data.ts";
import type { Message } from "./model.ts";

type H = HtmlBuilder<Message>;

export interface PerMove {
  readonly key: string;
  readonly model: string;
  readonly effort: string;
  readonly color: string;
  readonly cost: number;
}

type Config = Pick<ModelStats, "key" | "model" | "effort" | "color"> & { readonly scored: ReadonlyArray<Pick<SeatFull, "cost" | "moves">> };

export const perMoveOf = (stats: ReadonlyArray<Config>): ReadonlyArray<PerMove> =>
  stats.flatMap(({ key, model, effort, color, scored }) => {
    const cost = costPerMove({ scored });

    return cost === null || cost <= 0 ? [] : [{ key, model, effort, color, cost }];
  });

const rowView = (h: H, { effort, color, cost }: PerMove, most: number): Html =>
  h.div(
    [h.Class("cpm-row")],
    [h.span([], [effort]), h.span([h.Class("cpm-bar")], [h.i([h.Style({ width: `${((cost / most) * 100).toFixed(2)}%`, background: color })], [])]), h.span([h.Class("cpm-val")], [fmtUsd(cost)])],
  );

export const spendView = (h: H, stats: ReadonlyArray<ModelStats>): Html => {
  const rows = perMoveOf(stats);
  const most = Math.max(...rows.map(({ cost }) => cost));
  const total = sumOf(stats.map(({ totalCost }) => totalCost));
  const models = [...groupBy(rows, ({ model }) => model)].toSorted(([left], [right]) => baseOrder(left) - baseOrder(right));

  return h.div(
    [h.Class("chart spend")],
    [
      h.div([h.Class("lbbar")], [h.h2([], ["List-price cost per move"]), h.span([h.Class("k")], [`$${Math.round(total).toLocaleString()} at list prices`])]),
      rows.length === 0
        ? h.div([h.Class("empty")], ["No spend in this filter."])
        : h.div(
            [h.Class("cpm")],
            models.map(([model, configs]) =>
              h.div(
                [h.Class("cpm-model")],
                [
                  h.h3([h.Style({ color: configs[0]?.color ?? "" })], [baseName(model)]),
                  ...configs.toSorted((left, right) => byEffort(left.effort, right.effort)).map((row) => rowView(h, row, most)),
                ],
              ),
            ),
          ),
    ],
  );
};
