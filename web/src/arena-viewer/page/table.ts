import type { Html, HtmlBuilder } from "foldkit/html";

import type { Message } from "./model.ts";
import { itemIconOf } from "./items.ts";

type H = HtmlBuilder<Message>;

// A flat drawing of the table at one moment: the seats around it with their health and items, and the gun's shells in
// the middle as the acting player knows them. It takes no rules and sends no messages, so a replay and a live game can
// both draw it from their own state.

export type TableSeat = {
  readonly letter: string;
  readonly name: string;
  readonly color: string;
  readonly health: number;
  readonly items: ReadonlyArray<string>;
  readonly isActing: boolean;
};

export type TableState = {
  readonly seats: ReadonlyArray<TableSeat>;
  /** The most health any seat can hold, so every health bar has the same length. */
  readonly maxHealth: number;
  readonly live: number;
  readonly blank: number;
  readonly known: "live" | "blank" | null;
  readonly viewer: string;
  readonly action: Html;
};

/** Grid areas in table order, starting at the bottom and going clockwise, for a table of one to four seats. */
const PLACES = [["bottom"], ["bottom", "top"], ["bottom", "left", "top"], ["bottom", "left", "top", "right"]] as const;

const countItems = (items: ReadonlyArray<string>): ReadonlyArray<readonly [string, number]> => [
  ...items.reduce((counts, item) => counts.set(item, (counts.get(item) ?? 0) + 1), new Map<string, number>()),
];

const seatView = (h: H, seat: TableSeat, place: string, maxHealth: number): Html =>
  h.div(
    [h.Class(`seat ${seat.isActing ? "acting" : ""}`), h.Style({ "grid-area": place, "border-color": seat.color })],
    [
      h.div(
        [h.Class("who")],
        [
          h.span([h.Class("letter"), h.Style({ color: seat.color })], [seat.letter]),
          h.b([h.Class("name"), h.Style({ color: seat.color }), h.Title(seat.name)], [seat.name]),
          seat.isActing ? h.span([h.Class("turn")], ["to move"]) : h.empty,
        ],
      ),
      h.div(
        [h.Class("health"), h.AriaLabel(`${seat.health} of ${maxHealth} health`)],
        [
          h.span([h.Class("bolts")], Array.from({ length: maxHealth }, (_bolt, index) => h.i(index < seat.health ? [h.Class("full"), h.Style({ background: seat.color })] : [], []))),
          h.span([h.Class("k")], [`${seat.health}/${maxHealth}`]),
        ],
      ),
      h.div(
        [h.Class("items")],
        seat.items.length === 0
          ? [h.span([h.Class("k")], ["no items"])]
          : countItems(seat.items).map(([item, copies]) => h.span([h.Class("tag")], [itemIconOf(h, item), copies > 1 ? `${item} ×${copies}` : item])),
      ),
    ],
  );

export const tableView = (h: H, table: TableState): Html => {
  const places: ReadonlyArray<string> = PLACES[table.seats.length - 1] ?? [];
  const chamber = table.known === null ? "chamber unknown" : `chamber ${table.known}`;

  return h.div(
    [h.Class(`table seats-${table.seats.length}`)],
    [
      ...table.seats.map((seat, index) => seatView(h, seat, places[index] ?? "bottom", table.maxHealth)),
      h.div(
        [h.Class("felt")],
        [
          h.div(
            [h.Class("shells"), h.AriaLabel(`${table.live} live and ${table.blank} blank shells left`)],
            [...Array.from({ length: table.live }, () => h.i([h.Class("live")], [])), ...Array.from({ length: table.blank }, () => h.i([], []))],
          ),
          h.div([h.Class("count")], [h.b([], [`${table.live} live`]), ` · ${table.blank} blank · `, h.span([h.Class(table.known === null ? "k" : "known")], [chamber])]),
          h.div([h.Class("k")], [`before the move, as ${table.viewer} sees it`]),
          table.action,
        ],
      ),
    ],
  );
};
