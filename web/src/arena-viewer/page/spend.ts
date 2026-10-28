import type { Html, HtmlBuilder } from "foldkit/html";

import { baseOrder, fmtUsd, groupBy, type ModelStats, sumOf } from "./data.ts";
import type { Message } from "./model.ts";

type H = HtmlBuilder<Message>;

// Where the money went: every config's share of the spend, as one bar and a ranking of the biggest.

export interface Spend {
  readonly key: string;
  readonly model: string;
  readonly label: string;
  readonly color: string;
  readonly cost: number;
  /** Of the spend of all the configs given. */
  readonly share: number;
}

/** Each config that cost anything, biggest first, with its share of the total. */
export const spendOf = (stats: ReadonlyArray<Pick<ModelStats, "key" | "model" | "label" | "color" | "totalCost">>): ReadonlyArray<Spend> => {
  const paid = stats.filter(({ totalCost }) => totalCost > 0);
  const total = sumOf(paid.map(({ totalCost }) => totalCost));

  return paid.map(({ key, model, label, color, totalCost }) => ({ key, model, label, color, cost: totalCost, share: totalCost / total })).toSorted((left, right) => right.cost - left.cost);
};

const RANKED = 8;

/** The bar's segments are named only where they are wide enough to hold the name. */
const NAMED_FROM = 0.12;

const pct = (share: number): string => `${(share * 100).toFixed(1)}%`;

const segmentTitle = ({ label, cost, share }: Spend): string => `${label} · ${fmtUsd(cost)} · ${pct(share)}`;

/** The bar runs model by model in the filter bar's order, so a model's configs sit together. */
const barOrder = (spend: ReadonlyArray<Spend>): ReadonlyArray<Spend> =>
  [...groupBy(spend, ({ model }) => model)].toSorted(([left], [right]) => baseOrder(left) - baseOrder(right)).flatMap(([, configs]) => configs);

export const spendView = (h: H, stats: ReadonlyArray<ModelStats>): Html => {
  const spend = spendOf(stats);
  const total = sumOf(spend.map(({ cost }) => cost));
  const top = spend.slice(0, RANKED);
  const rest = spend.slice(RANKED);
  const biggest = top[0]?.share ?? 1;

  return h.div(
    [h.Class("chart")],
    [
      h.div([h.Class("lbbar")], [h.h2([], ["Where the money went"]), h.span([h.Class("k")], [`$${Math.round(total).toLocaleString()} over ${spend.length} configs`])]),
      spend.length === 0
        ? h.div([h.Class("empty")], ["No spend in this filter."])
        : h.div(
            [],
            [
              h.div(
                [h.Class("spendbar")],
                barOrder(spend).map((part) =>
                  h.div([h.Class("seg"), h.Title(segmentTitle(part)), h.Style({ flex: `${part.share} 1 0`, background: part.color })], [part.share >= NAMED_FROM ? part.label : ""]),
                ),
              ),
              h.div(
                [h.Class("spendrows")],
                [
                  ...top.flatMap((part) => [
                    h.span([h.Class("name")], [part.label]),
                    h.span([h.Class("track")], [h.span([h.Style({ width: `${(part.share / biggest) * 100}%`, background: part.color })], [])]),
                    h.span([h.Class("amt")], [`${fmtUsd(part.cost)} · ${pct(part.share)}`]),
                  ]),
                  ...(rest.length === 0
                    ? []
                    : [
                        h.span([h.Class("name k")], [`${rest.length} other configs`]),
                        h.span([], []),
                        h.span([h.Class("amt k")], [`${fmtUsd(sumOf(rest.map(({ cost }) => cost)))} · ${pct(sumOf(rest.map(({ share }) => share)))}`]),
                      ]),
                ],
              ),
            ],
          ),
    ],
  );
};
