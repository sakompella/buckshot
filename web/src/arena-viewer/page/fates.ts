import type { Html, HtmlBuilder } from "foldkit/html";

import { type Decisions, ITEMS, type Seat } from "../api.ts";
import { anchorId, markTip } from "./charts.ts";
import { baseName, baseOrder, colorOf, groupBy, type SeatFull, sumOf } from "./data.ts";
import { memoLast } from "./derived.ts";
import { itemIconOf } from "./items.ts";
import type { Message } from "./model.ts";

type H = HtmlBuilder<Message>;

// What became of the items players received: used, stolen by the opponent, or still in hand when the round ended.
// Only completed two-player matches count, since the copies stolen from a seat are its opponent's steals.

export interface Fates {
  readonly used: number;
  readonly stolen: number;
  readonly unused: number;
}

/** A seat's copies of each item, in ITEMS order, by what became of them. Adrenaline steals count as uses of the adrenaline that paid for them. */
export const seatFates = (seat: Pick<Seat, "acquired" | "used">, opponent: Pick<Seat, "stolen">): ReadonlyArray<Fates> =>
  seat.acquired.map((acquired, item) => {
    const used = seat.used[item] ?? 0;
    const stolen = opponent.stolen[item] ?? 0;

    return { used, stolen, unused: acquired - used - stolen };
  });

export const sumFates = (fates: ReadonlyArray<Fates>): Fates => ({
  used: sumOf(fates.map(({ used }) => used)),
  stolen: sumOf(fates.map(({ stolen }) => stolen)),
  unused: sumOf(fates.map(({ unused }) => unused)),
});

const receivedOf = ({ used, stolen, unused }: Fates): number => used + stolen + unused;

const fatesBySeat = memoLast(
  (seats: ReadonlyArray<SeatFull>): ReadonlyMap<SeatFull, ReadonlyArray<Fates>> =>
    new Map(
      [...groupBy(seats.filter(({ status }) => status === "completed"), ({ matchId }) => matchId).values()].flatMap((both) => {
        const [one, other, ...rest] = both;

        return one === undefined || other === undefined || rest.length > 0
          ? []
          : [
              [one, seatFates(one, other)],
              [other, seatFates(other, one)],
            ];
      }),
    ),
);

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

const itemFates = (seats: ReadonlyArray<SeatFull>, focal: ReadonlyArray<SeatFull>, color: string): ItemFates => {
  const perSeat = fatesBySeat(seats);
  const scored = focal.filter((seat) => perSeat.has(seat));
  const per = `${scored.length.toLocaleString()} player-matches`;
  const all = sumFates(scored.flatMap((seat) => perSeat.get(seat) ?? []));

  const items = ITEMS.flatMap((item, index) => {
    const fates = sumFates(scored.flatMap((seat) => perSeat.get(seat)?.[index] ?? []));

    return receivedOf(fates) === 0 ? [] : [rowOf(item, color, fates, per)];
  });

  return { all: receivedOf(all) === 0 ? null : rowOf("All items", color, all, per), items: items.toSorted((left, right) => unusedShare(right) - unusedShare(left)) };
};

/** A move has an item available when legalUse has a bit: an own item, a jam or an adrenaline steal. A steal counts as an adrenaline use. */
export interface Behavior {
  readonly moves: number;
  readonly available: number;
  readonly usedWhenAvailable: number;
  readonly itemActions: number;
}

const NO_BEHAVIOR: Behavior = { moves: 0, available: 0, usedWhenAvailable: 0, itemActions: 0 };

export const addBehavior = (left: Behavior, right: Behavior): Behavior => ({
  moves: left.moves + right.moves,
  available: left.available + right.available,
  usedWhenAvailable: left.usedWhenAvailable + right.usedWhenAvailable,
  itemActions: left.itemActions + right.itemActions,
});

export const behaviorBySeat = memoLast((decisions: Pick<Decisions, "seat" | "legalUse" | "useItem">, seatCount: number): ReadonlyArray<Behavior> => {
  const tallies = Array.from({ length: seatCount }, () => ({ moves: 0, available: 0, usedWhenAvailable: 0, itemActions: 0 }));

  decisions.seat.forEach((seatIndex, move) => {
    const tally = tallies[seatIndex];

    if (tally === undefined) return;

    const available = (decisions.legalUse[move] ?? 0) !== 0;
    const used = (decisions.useItem[move] ?? -1) >= 0;

    tally.moves++;

    if (available) tally.available++;

    if (available && used) tally.usedWhenAvailable++;

    if (used) tally.itemActions++;
  });

  return tallies;
});

export const useShare = ({ available, usedWhenAvailable }: Behavior): number | null => (available === 0 ? null : usedWhenAvailable / available);

interface UseRow {
  readonly name: string;
  readonly color: string;
  readonly share: number | null;
  readonly tip: string;
}

const useRowsOf = (decisions: Decisions, seats: ReadonlyArray<SeatFull>, focal: ReadonlyArray<SeatFull>): ReadonlyArray<UseRow> => {
  const bySeat = behaviorBySeat(decisions, seats.length);
  const indexOf = new Map(seats.map((seat, index) => [seat, index]));

  return [...groupBy(focal, ({ model }) => model)]
    .toSorted(([left], [right]) => baseOrder(left) - baseOrder(right))
    .map(([model, played]): UseRow => {
      const { moves, available, usedWhenAvailable, itemActions } = played.reduce((sum, seat) => addBehavior(sum, bySeat[indexOf.get(seat) ?? -1] ?? NO_BEHAVIOR), NO_BEHAVIOR);
      const name = baseName(model);
      const share = useShare({ moves, available, usedWhenAvailable, itemActions });
      const used = share === null ? "no move had an item available" : `${pct(share)} of ${available.toLocaleString()} moves with an item available used one`;
      const perHundred = moves === 0 ? "" : `, ${(itemActions / moves * 100).toFixed(1)} item actions per 100 of ${moves.toLocaleString()} moves`;

      return { name, color: colorOf(model), share, tip: `${name}: ${used}${perHundred}` };
    })
    .toSorted((left, right) => (right.share ?? -1) - (left.share ?? -1));
};

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
        [h.Class("fate-bar"), ...markTip(h, anchorId("fate", scope, name), tip)],
        (["used", "stolen", "unused"] as const).map((fate) => h.i([h.Style({ width: `${(fates[fate] / received * 100).toFixed(2)}%`, background: color, opacity: OPACITY[fate] })], [])),
      ),
      h.span([h.Class("fate-val")], [pct(fates.unused / received)]),
    ],
  );
};

const LEGEND = [
  ["used", "used"],
  ["stolen", "stolen by the opponent"],
  ["unused", "left unused"],
] as const;

const legendView = (h: H): Html =>
  h.div([h.Class("fate-legend")], LEGEND.map(([fate, label]) => h.span([], [h.i([h.Style({ opacity: OPACITY[fate] })], []), label])));

const itemLabel = (h: H, name: string): ReadonlyArray<Html | string> => (name === "All items" ? [name] : [itemIconOf(h, name), name]);

export const itemBarsView = (h: H, seats: ReadonlyArray<SeatFull>, focal: ReadonlyArray<SeatFull>, color: string, scope: string): Html => {
  const { all, items } = itemFates(seats, focal, color);

  return h.div([], [legendView(h), h.div([h.Class("fates")], [...(all === null ? [] : [rowView(h, scope, all, [all.name])]), ...items.map((row) => rowView(h, scope, row, itemLabel(h, row.name)))])]);
};

export const itemUsageView = (h: H, decisions: Decisions, seats: ReadonlyArray<SeatFull>, focal: ReadonlyArray<SeatFull>): Html => {
  const { items } = itemFates(seats, focal, ITEM_COLOR);
  const useRows = useRowsOf(decisions, seats, focal);

  return h.div(
    [],
    [
      h.h2([], ["Item usage"]),
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
              items.length === 0 ? h.div([h.Class("empty")], ["No scored matches for this filter."]) : h.div([], [legendView(h), h.div([h.Class("fates")], items.map((row) => rowView(h, "page", row, itemLabel(h, row.name))))]),
            ],
          ),
        ],
      ),
    ],
  );
};
