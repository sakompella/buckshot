import type { Html, HtmlBuilder } from "foldkit/html";

import { anchorId, markTip } from "./charts.ts";
import { baseName, baseOrder, colorOf, fmtUsd, groupBy, type ModelStats, sumOf } from "./data.ts";
import type { Message } from "./model.ts";

type H = HtmlBuilder<Message>;

export interface Spend {
  readonly key: string;
  readonly model: string;
  readonly label: string;
  readonly color: string;
  readonly cost: number;
  readonly share: number;
}

export const spendOf = (stats: ReadonlyArray<Pick<ModelStats, "key" | "model" | "label" | "color" | "totalCost">>): ReadonlyArray<Spend> => {
  const paid = stats.filter(({ totalCost }) => totalCost > 0);
  const total = sumOf(paid.map(({ totalCost }) => totalCost));

  return paid.map(({ key, model, label, color, totalCost }) => ({ key, model, label, color, cost: totalCost, share: totalCost / total })).toSorted((left, right) => right.cost - left.cost);
};

/** The bar's segments are named only where they are wide enough to hold the name. */
const NAMED_FROM = 0.12;

const pct = (share: number): string => `${(share * 100).toFixed(1)}%`;

const segmentTitle = ({ label, cost, share }: Spend): string => `${label} · ${fmtUsd(cost)} at list price · ${pct(share)}`;

/** The bar runs model by model in the filter bar's order, so a model's configs sit together. */
const barOrder = (spend: ReadonlyArray<Spend>): ReadonlyArray<Spend> =>
  [...groupBy(spend, ({ model }) => model)].toSorted(([left], [right]) => baseOrder(left) - baseOrder(right)).flatMap(([, configs]) => configs);

export const spendView = (h: H, stats: ReadonlyArray<ModelStats>): Html => {
  const spend = spendOf(stats);
  const total = sumOf(spend.map(({ cost }) => cost));
  const models = [...groupBy(spend, ({ model }) => model)].toSorted(([left], [right]) => baseOrder(left) - baseOrder(right));

  return h.div(
    [h.Class("chart spend")],
    [
      h.div([h.Class("lbbar")], [h.h2([], ["List-price spend"]), h.span([h.Class("k")], [`$${Math.round(total).toLocaleString()} over ${spend.length} configs`])]),
      spend.length === 0
        ? h.div([h.Class("empty")], ["No spend in this filter."])
        : h.div(
            [],
            [
              h.div(
                [h.Class("spendbar")],
                barOrder(spend).map((part) =>
                  h.div([h.Class("seg"), ...markTip(h, anchorId("spend", part.key), segmentTitle(part)), h.Style({ flex: `${part.share} 1 0`, background: part.color })], [part.share >= NAMED_FROM ? part.label : ""]),
                ),
              ),
              h.div(
                [h.Class("legend")],
                models.map(([model, configs]) =>
                  h.span([h.Style({ color: colorOf(model) })], [`${baseName(model)} ${fmtUsd(sumOf(configs.map(({ cost }) => cost)))} · ${pct(sumOf(configs.map(({ share }) => share)))}`]),
                ),
              ),
            ],
          ),
    ],
  );
};
