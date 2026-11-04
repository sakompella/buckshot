import type { Html, HtmlBuilder } from "foldkit/html";

import { addBehavior, type Behavior, type ConfigItems, type Fates, NO_BEHAVIOR, sumFates } from "../aggregates.ts";
import { ITEMS } from "../api.ts";
import { anchorId, markTip } from "./charts.ts";
import { baseName, baseOrder, colorOf, groupBy, splitKey, sumOf } from "./data.ts";
import { memoLast } from "./derived.ts";
import { itemIconOf } from "./items.ts";
import type { Message } from "./model.ts";

type H = HtmlBuilder<Message>;

// What became of the items players received: used, stolen by the opponent, or still in hand when the round ended.
// Only completed two-player matches count, since the copies stolen from a seat are its opponent's steals.

const receivedOf = ({ used, stolen, unused }: Fates): number => used + stolen + unused;

interface Row {
  readonly name: string;
  readonly color: string;
  readonly fates: Fates;
  readonly tip: string;
}

const pct = (share: number) => `${Math.round(share * 100)}%`;

const unusedShare = ({ fates }: Row) => fates.unused / receivedOf(fates);

const rowOf = (name: string, color: string, fates: Fates, per: string): Row => {
  const received = receivedOf(fates);
  const share = (count: number) => pct(count / received);

  return { name, color, fates, tip: `${name}: ${share(fates.used)} used, ${share(fates.stolen)} stolen, ${share(fates.unused)} left unused, ${per}` };
};

const ITEM_COLOR = "#d9d9d9";

interface ItemFates {
  readonly all: Row | null;
  readonly items: ReadonlyArray<Row>;
}

const itemFates = (focal: ReadonlyArray<ConfigItems>, color: string): ItemFates => {
  const per = `${sumOf(focal.map(({ players }) => players)).toLocaleString()} player-matches`;
  const all = sumFates(focal.flatMap(({ fates }) => fates));

  const items = ITEMS.flatMap((item, index) => {
    const fates = sumFates(focal.flatMap(({ fates: own }) => own[index] ?? []));

    return receivedOf(fates) === 0 ? [] : [rowOf(item, color, fates, per)];
  });

  return { all: receivedOf(all) === 0 ? null : rowOf("All items", color, all, per), items: items.toSorted((left, right) => unusedShare(right) - unusedShare(left)) };
};

export const useShare = ({ available, usedWhenAvailable }: Behavior): number | null => (available === 0 ? null : usedWhenAvailable / available);

interface UseRow {
  readonly name: string;
  readonly color: string;
  readonly share: number | null;
  readonly tip: string;
}

const useRowsOf = (focal: ReadonlyArray<ConfigItems>): ReadonlyArray<UseRow> =>
  [...groupBy(focal, ({ config }) => splitKey(config)[0])]
    .toSorted(([left], [right]) => baseOrder(left) - baseOrder(right))
    .map(([model, played]): UseRow => {
      const behavior = played.reduce((sum, { behavior: own }) => addBehavior(sum, own), NO_BEHAVIOR);
      const { moves, available, itemActions } = behavior;
      const name = baseName(model);
      const share = useShare(behavior);
      const used = share === null ? "no move had an item available" : `${pct(share)} of ${available.toLocaleString()} moves with an item available used one`;
      const perHundred = moves === 0 ? "" : `, ${(itemActions / moves * 100).toFixed(1)} item actions per 100 of ${moves.toLocaleString()} moves`;

      return { name, color: colorOf(model), share, tip: `${name}: ${used}${perHundred}` };
    })
    .toSorted((left, right) => (right.share ?? -1) - (left.share ?? -1));

const useRowView = (h: H, { name, color, share, tip }: UseRow): Html =>
  h.div(
    [h.Class("fate")],
    [
      h.span([h.Class("fate-name"), h.Style({ color })], [name]),
      h.span([h.Class("fate-bar fate-hit"), ...markTip(h, anchorId("use", name), tip)], [h.i([h.Style({ width: `${((share ?? 0) * 100).toFixed(2)}%`, background: color, opacity: OPACITY.used })], [])]),
      h.span([h.Class("fate-val")], [share === null ? "–" : pct(share)]),
    ],
  );

const OPACITY = { used: "0.95", stolen: "0.5", unused: "0.2" } as const;

const rowView = (h: H, scope: string, { name, color, fates, tip }: Row, label: ReadonlyArray<Html | string>): Html => {
  const received = receivedOf(fates);

  return h.div(
    [h.Class("fate")],
    [
      h.span([h.Class("fate-name"), h.Style({ color })], label),
      h.span(
        [h.Class("fate-bar fate-hit"), ...markTip(h, anchorId("fate", scope, name), tip)],
        (["used", "stolen", "unused"] as const).map((fate) => h.i([h.Style({ width: `${(fates[fate] / received * 100).toFixed(2)}%`, background: color, opacity: OPACITY[fate] })], [])),
      ),
      h.span([h.Class("fate-val")], [`${pct(fates.unused / received)} unused`]),
    ],
  );
};

const LEGEND = [
  ["used", "used"],
  ["stolen", "stolen by the opponent"],
  ["unused", "left unused"],
] as const;

const legendView = (h: H, color: string): Html =>
  h.div([h.Class("fate-legend")], LEGEND.map(([fate, label]) => h.span([], [h.i([h.Style({ background: color, opacity: OPACITY[fate] })], []), label])));

const itemLabel = (h: H, name: string): ReadonlyArray<Html | string> => (name === "All items" ? [name] : [itemIconOf(h, name), name]);

/** One config's items, as its drill-down shows them. */
export const itemBarsView = (h: H, own: ConfigItems | undefined, color: string, scope: string): Html => {
  const { all, items } = itemFates(own === undefined ? [] : [own], color);

  return h.div([], [legendView(h, color), h.div([h.Class("fates")], [...(all === null ? [] : [rowView(h, scope, all, [all.name])]), ...items.map((row) => rowView(h, scope, row, itemLabel(h, row.name)))])]);
};

const focalOf = memoLast((items: ReadonlyArray<ConfigItems>, kept: ReadonlySet<string>): ReadonlyArray<ConfigItems> => items.filter(({ config }) => kept.has(config)));

export const itemUsageView = (h: H, every: ReadonlyArray<ConfigItems>, kept: ReadonlySet<string>): Html => {
  const focal = focalOf(every, kept);
  const { items } = itemFates(focal, ITEM_COLOR);
  const useRows = useRowsOf(focal);

  return h.div(
    [],
    [
      h.h2([], ["Item usage"]),
      h.p([h.Class("sub")], ["All selected efforts, pooled."]),
      h.div(
        [h.Class("chartrow two")],
        [
          h.figure(
            [],
            [h.h3([], ["Moves using an item when one is available"]), useRows.length === 0 ? h.div([h.Class("empty")], ["No moves for this filter."]) : h.div([h.Class("fates")], useRows.map((row) => useRowView(h, row)))],
          ),
          h.figure(
            [],
            [
              h.h3([], ["What became of each item"]),
              items.length === 0 ? h.div([h.Class("empty")], ["No scored matches for this filter."]) : h.div([], [legendView(h, ITEM_COLOR), h.div([h.Class("fates")], items.map((row) => rowView(h, "page", row, itemLabel(h, row.name))))]),
            ],
          ),
        ],
      ),
    ],
  );
};
