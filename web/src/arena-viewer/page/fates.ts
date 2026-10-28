import type { Html, HtmlBuilder } from "foldkit/html";

import { ITEMS, type Seat } from "../api.ts";
import { anchorId, markTip } from "./charts.ts";
import { colorOfKey, groupBy, keyOf, labelOf, type SeatFull, sumOf } from "./data.ts";
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

/** One row per config over its scored matches, and one per item over all of them, the most unused first. */
const rowsOf = (seats: ReadonlyArray<SeatFull>, focal: ReadonlyArray<SeatFull>) => {
  const perSeat = fatesBySeat(seats);
  const scored = focal.filter((seat) => perSeat.has(seat));
  const mostUnused = (rows: ReadonlyArray<Row>) => rows.toSorted((left, right) => unusedShare(right) - unusedShare(left));

  const configs = [...groupBy(scored, keyOf)].map(([key, played]) => {
    const fates = sumFates(played.flatMap((seat) => perSeat.get(seat) ?? []));

    return rowOf(labelOf(key), colorOfKey(key), fates, `${(receivedOf(fates) / played.length).toFixed(1)} items per match`);
  });

  const items = ITEMS.map((item, index) => rowOf(item, "#d9d9d9", sumFates(scored.flatMap((seat) => perSeat.get(seat)?.[index] ?? [])), `${scored.length.toLocaleString()} player-matches`));

  return { configs: mostUnused(configs), items: mostUnused(items) };
};

const OPACITY = { used: "0.95", stolen: "0.5", unused: "0.2" } as const;

const rowView = (h: H, { name, color, fates, tip }: Row, label: ReadonlyArray<Html | string>): Html => {
  const received = receivedOf(fates);

  return h.div(
    [h.Class("fate")],
    [
      h.span([h.Class("fate-name"), h.Style({ color })], label),
      h.span(
        [h.Class("fate-bar"), ...markTip(h, anchorId("fate", name), tip)],
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

/** The Items section: what became of the items each config received, and of each kind of item. The number at the end of a bar is the share left unused. */
export const fatesView = (h: H, seats: ReadonlyArray<SeatFull>, focal: ReadonlyArray<SeatFull>): Html => {
  const { configs, items } = rowsOf(seats, focal);

  return h.div(
    [],
    [
      h.h2([], ["Item fates"]),
      legendView(h),
      h.div(
        [h.Class("chartrow")],
        [
          h.figure(
            [h.Class("wide")],
            [
              h.h3([], ["By config"]),
              configs.length === 0 ? h.div([h.Class("empty")], ["No scored matches for this filter."]) : h.div([h.Class("fates")], configs.map((row) => rowView(h, row, [row.name]))),
            ],
          ),
          h.figure([], [h.h3([], ["By item"]), h.div([h.Class("fates")], items.map((row) => rowView(h, row, [itemIconOf(h, row.name), row.name])))]),
        ],
      ),
    ],
  );
};
