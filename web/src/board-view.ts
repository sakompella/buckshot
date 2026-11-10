import { Array as Arr, Option } from "effect";
import type { Html, HtmlBuilder } from "foldkit/html";

import { type BoardMove, boardMoves, type Position, positionOf, type TableMove, Target, targetKey, targetsOf } from "./board.ts";
import { type Board, Briefcase, Counter, GameEvent, type Item, Move, type Seat, type SeatView, type Shell, Slot, Stage } from "./domain.ts";
import { boltIcon, gunIcon, itemIcon, shellIcon } from "./icons.ts";
import { itemName, itemNote } from "./text.ts";

// The table from above, as the arena's replay draws it. Each seat's things sit in a
// layer turned to face its edge, so one layout serves all four sides. Legal
// moves with an onMove are buttons on the things they act on; a chosen move is
// marked on them instead. The latest step's events play once as CSS
// animations, keyed by their place in the event log, and are gone when the
// next step starts.

/** One event of the latest step, with its place in the event log. */
export interface StepEvent {
  readonly index: number;
  readonly event: GameEvent;
}

/** What one seat sees of the table: the machine's public board, and the shells as that seat counts them when known. */
export interface SeatTable {
  readonly board: Board;
  /** The seat drawn nearest. */
  readonly near: Seat;
  readonly out: ReadonlySet<Seat>;
  readonly shells: Option.Option<{ readonly live: number; readonly blank: number; readonly chamber: Option.Option<Shell> }>;
  /** The latest step's events, which play once. */
  readonly recent: ReadonlyArray<StepEvent>;
  /** Tells one match's animations from another's. */
  readonly key: string;
}

export interface Table<M> {
  readonly view: SeatTable;
  /** The legal moves of the seat to act. */
  readonly moves: ReadonlyArray<TableMove>;
  /** The message for the move at an index of `moves`; without it the table only shows them. */
  readonly onMove: Option.Option<(index: number) => M>;
  /** The index of `moves` to mark as the one chosen. */
  readonly chosen: Option.Option<number>;
}

interface Drawn<M> {
  readonly h: HtmlBuilder<M>;
  readonly view: SeatTable;
  readonly onTable: ReadonlyMap<string, BoardMove>;
  readonly onMove: Option.Option<(index: number) => M>;
  readonly marked: ReadonlySet<string>;
  readonly chosen: Option.Option<TableMove>;
}

const turn = (position: Position): string => `${position * 90}deg`;

/** A one-time animation's key: the match and the event's place in the log. */
const effectKey = (view: SeatTable, name: string, index: number): string => `${view.key}-${name}-${index}`;

const position = <M>(table: Drawn<M>, seat: Seat): Position => positionOf(table.view.near, seat);

const clickAt = <M>(table: Drawn<M>, target: Target): Option.Option<{ readonly label: string; readonly message: M }> =>
  Option.flatMap(Option.fromNullishOr(table.onTable.get(targetKey(target))), ({ index, label }) => Option.map(table.onMove, (onMove) => ({ label, message: onMove(index) })));

const isMarked = <M>(table: Drawn<M>, target: Target): boolean => table.marked.has(targetKey(target));

/** An item's one-line caption, shown while the pointer is on it, turned to read upright. */
const captionOf = <M>(h: HtmlBuilder<M>, item: Item, at: Position): Html => {
  const name = itemName(item);

  return h.span([h.Class("caption"), h.Style({ rotate: `-${turn(at)}` }), h.AriaHidden(true)], [`${name.charAt(0).toUpperCase()}${name.slice(1)}. ${itemNote(item)}`]);
};

/** A thing on the table: a button while a legal move is played on it, plain otherwise, and marked when the chosen move acts on it. */
const thing = <M>(table: Drawn<M>, target: Target, className: string, children: ReadonlyArray<Html>): Html => {
  const { h } = table;
  const classes = isMarked(table, target) ? `${className} chosen` : className;

  return Option.match(clickAt(table, target), {
    onNone: () => h.div([h.Class(classes)], children),
    onSome: ({ label, message }) => h.button([h.Type("button"), h.Class(`${classes} hot`), h.AriaLabel(label), h.OnClick(message)], children),
  });
};

const lastOf = <A extends GameEvent>(view: SeatTable, isKind: (event: GameEvent) => event is A): Option.Option<{ readonly index: number; readonly event: A }> =>
  Arr.findLast(
    view.recent.flatMap(({ index, event }) => (isKind(event) ? [{ index, event }] : [])),
    () => true,
  );

// SEATS

const boltsView = <M>(table: Drawn<M>, seat: Seat, health: number): ReadonlyArray<Html> => {
  const { h, view } = table;
  const shot = Option.filter(lastOf(view, GameEvent.guards.Fired), ({ event }) => event.target === seat && event.applied > 0);

  return Arr.makeBy(Math.max(view.board.round.health, health), (charge) => {
    const drainedBy = Option.filter(shot, ({ event }) => charge >= health && charge < health + event.applied);

    return Option.match(drainedBy, {
      onNone: () => h.keyed("span")(`bolt-${charge}`, [h.Class(charge < health ? "bolt" : "bolt spent")], [boltIcon("bolt-icon")]),
      onSome: ({ index }) => h.keyed("span")(effectKey(view, `drain-${charge}`, index), [h.Class("bolt spent drain")], [boltIcon("bolt-icon")]),
    });
  });
};

const counterView = <M>(table: Drawn<M>, seatView: SeatView, at: Position, isActing: boolean): Html => {
  const { h } = table;
  const isOut = table.view.out.has(seatView.seat);

  const screen = Counter.match(seatView.counter, {
    Jammed: () => [h.span([h.Class("counter-static")], ["Jammed"])],
    Unjammed: ({ health }) => (isOut ? [h.span([h.Class("counter-flat")], [])] : boltsView(table, seatView.seat, health)),
  });

  return h.div(
    [h.Class(`counter${isActing ? " acting" : ""}${isOut ? " out" : ""}`)],
    [h.div([h.Class("counter-face"), h.Style({ rotate: `-${turn(at)}` })], [h.div([h.Class("counter-screen")], screen)])],
  );
};

/** An empty slot shows only while it is somewhere to place an item. */
const slotView = <M>(table: Drawn<M>, seatView: SeatView, slot: Slot, at: Position): Html => {
  const target = Target.cases.Slot.make({ seat: seatView.seat, slot });

  return Option.match(Option.flatten(Arr.get(seatView.slots, slot)), {
    onNone: () => (Option.isSome(clickAt(table, target)) || isMarked(table, target) ? thing(table, target, `slot slot-${slot}`, []) : table.h.empty),
    onSome: (item) => thing(table, target, `slot slot-${slot} filled`, [itemIcon(item), captionOf(table.h, item, at)]),
  });
};

const briefcaseView = <M>(table: Drawn<M>, seatView: SeatView): Html => {
  const { h } = table;
  const target = Target.cases.Briefcase.make({ seat: seatView.seat });

  return Briefcase.match(seatView.briefcase, {
    NotGrabbing: () => h.empty,
    Grabbing: () => thing(table, target, "briefcase", [h.span([h.Class("briefcase-lid")], []), h.span([h.Class("briefcase-tray")], [])]),
    Holding: ({ item }) => thing(table, target, "briefcase holding", [h.span([h.Class("briefcase-lid")], []), h.span([h.Class("briefcase-tray")], [itemIcon(item)])]),
  });
};

const figureView = <M>(h: HtmlBuilder<M>): Html =>
  h.div([h.Class("figure")], [h.span([h.Class("figure-shoulders")], []), h.span([h.Class("figure-head")], [h.span([h.Class("figure-eyes")], [])])]);

/** The item a seat just used, lifting off its slot. */
const usedGhost = <M>(table: Drawn<M>, seat: Seat): Html =>
  Option.match(
    Option.filter(lastOf(table.view, GameEvent.guards.Used), ({ event }) => event.owner === seat),
    {
      onNone: () => table.h.empty,
      onSome: ({ index, event }) => table.h.keyed("div")(effectKey(table.view, "used", index), [table.h.Class(`slot ghost slot-${event.slot}`), table.h.AriaHidden(true)], [itemIcon(event.item)]),
    },
  );

/** Where a seat is aimed at or jammed: a button while that is a legal move, a mark when the chosen move does it. */
const seatTargetView = <M>(table: Drawn<M>, seat: Seat, at: Position): Html => {
  const { h } = table;
  const target = Target.cases.Seat.make({ seat });

  return Option.match(clickAt(table, target), {
    onNone: () => (isMarked(table, target) ? h.div([h.Class("seat-target chosen"), h.DataAttribute("aim", `${at}`)], []) : h.empty),
    onSome: ({ label, message }) => h.button([h.Type("button"), h.Class("seat-target hot"), h.AriaLabel(label), h.DataAttribute("aim", `${at}`), h.OnClick(message)], []),
  });
};

const zoneView = <M>(table: Drawn<M>, seatView: SeatView): Html => {
  const { h, view } = table;
  const at = position(table, seatView.seat);
  const isActing = Stage.matchOrElse(view.board.stage, { Playing: ({ seat }) => seat === seatView.seat }, () => false);
  const isOut = view.out.has(seatView.seat);

  return h.div(
    [h.Class(`zone pos-${at}${isOut ? " is-out" : ""}`), h.Style({ rotate: turn(at) }), h.DataAttribute("pos", `${at}`)],
    [
      at === 0 ? h.empty : figureView(h),
      ...Slot.literals.map((slot) => slotView(table, seatView, slot, at)),
      usedGhost(table, seatView.seat),
      briefcaseView(table, seatView),
      counterView(table, seatView, at, isActing),
      seatTargetView(table, seatView.seat, at),
    ],
  );
};

// GUN

const shellGroup = <M>(h: HtmlBuilder<M>, count: number, shell: Shell): Html =>
  h.div([h.Class("shell-group")], Arr.makeBy(count, () => h.span([h.Class("shell")], [shellIcon(shell)])));

/** The shells of the newest load, set out on the cloth in a live group and a blank group long enough to count, then gone into the gun. */
const revealView = <M>(table: Drawn<M>): Html =>
  Option.match(lastOf(table.view, GameEvent.guards.Loaded), {
    onNone: () => table.h.empty,
    onSome: ({ index, event }) =>
      table.h.keyed("div")(
        effectKey(table.view, "reveal", index),
        [table.h.Class("reveal"), table.h.AriaHidden(true)],
        [shellGroup(table.h, event.load.live, "Live"), shellGroup(table.h, event.load.blank, "Blank")],
      ),
  });

const ejectView = <M>(table: Drawn<M>): Html => {
  const { h } = table;

  return Option.match(lastOf(table.view, GameEvent.guards.Ejected), {
    onNone: () => h.empty,
    onSome: ({ index, event }) =>
      h.keyed("div")(effectKey(table.view, "eject", index), [h.Class("eject"), h.Role("img"), h.AriaLabel(`Racked out a ${event.shell === "Live" ? "live" : "blank"} shell`)], [
        h.span([h.Class("shell")], [shellIcon(event.shell)]),
      ]),
  });
};

/** The chosen move's shot, if it shoots: who holds the gun and whom it points at. */
const chosenShot = <M>(table: Drawn<M>): Option.Option<{ readonly shooter: Seat; readonly target: Seat }> =>
  Option.flatMap(table.chosen, (move) =>
    Option.map(Arr.findFirst(move.steps, Move.guards.Shoot), ({ target }) => ({ shooter: move.seat, target })),
  );

/**
 * The gun lies across the plate. A seat aiming holds it on its side of the
 * plate, turned toward the seat under the pointer. On a shot it turns from
 * wherever it is to the target (a CSS transition, so a bot's shot turns as
 * smoothly as a human's), fires and recoils, holds, then settles back on the
 * plate. A new shot restarts the keyframes by switching between two copies.
 * A chosen shot holds the gun pointed at its target.
 */
const gunView = <M>(table: Drawn<M>): ReadonlyArray<Html> => {
  const { h, view } = table;
  const { board } = view;
  const aimer = Stage.matchOrElse(board.stage, { Playing: ({ seat, mode }) => (mode === "Aiming" ? Option.some(seat) : Option.none<Seat>()) }, () => Option.none<Seat>());
  const shot = lastOf(view, GameEvent.guards.Fired);
  const aimed = chosenShot(table);

  // The right-hand seat holds it at -90deg, so the gun never swings the long way round.
  const holder = (seat: Seat): string => `${position(table, seat) === 3 ? -90 : position(table, seat) * 90}deg`;
  const aim = (shooter: Seat, target: Seat): string => `${((position(table, target) - position(table, shooter) + 4) % 4) * 90}deg`;

  const rigStyle = Option.match(aimer, {
    onSome: (seat) => ({ "--holder": holder(seat) }),
    onNone: () =>
      Option.match(Option.orElse(aimed, () => Option.map(shot, ({ event }) => event)), {
        onNone: () => ({}),
        onSome: ({ shooter, target }) => ({ "--holder": holder(shooter), "--aim": aim(shooter, target) }),
      }),
  });

  const rigClass = Option.isSome(aimer)
    ? "gun-rig held"
    : Option.isSome(aimed)
      ? "gun-rig aimed"
      : Option.match(shot, { onNone: () => "gun-rig", onSome: ({ index }) => `gun-rig fired-${index % 2 === 0 ? "a" : "b"}` });

  const liveShot = Option.filter(shot, ({ event }) => event.shell === "Live");
  const gun = Target.cases.Gun.make({});

  return [
    h.div(
      [h.Class(rigClass), h.Style(rigStyle), h.AriaHidden(true)],
      [
        h.div([h.Class("gun-body")], [gunIcon(board.gun.sawed)]),
        Option.match(liveShot, { onNone: () => h.empty, onSome: ({ index }) => h.keyed("span")(effectKey(view, "flash", index), [h.Class("flash")], []) }),
      ],
    ),
    Option.isSome(clickAt(table, gun)) ? thing(table, gun, "gun-pick", []) : h.empty,
  ];
};

/** The shells as the seat counts them, laid out under the plate, and the chambered one when the seat knows it. */
const tallyView = <M>(table: Drawn<M>): Html => {
  const { h } = table;

  return Option.match(table.view.shells, {
    onNone: () => h.empty,
    onSome: ({ live, blank, chamber }) =>
      h.div(
        [h.Class("tally"), h.AriaHidden(true)],
        [
          Option.match(chamber, { onNone: () => h.empty, onSome: (shell) => h.div([h.Class("chamber")], [h.span([h.Class("shell")], [shellIcon(shell)])]) }),
          shellGroup(h, live, "Live"),
          shellGroup(h, blank, "Blank"),
        ],
      ),
  });
};

const shellsText = (view: SeatTable): string => {
  const { gun } = view.board;

  return Option.match(view.shells, {
    onNone: () => `${gun.remaining} shells in the gun; last load ${gun.shown.live} live, ${gun.shown.blank} blank.`,
    onSome: ({ live, blank, chamber }) =>
      `${live} live and ${blank} blank shells left; ${Option.match(chamber, { onNone: () => "chamber unknown", onSome: (shell) => `the chamber holds a ${shell === "Live" ? "live" : "blank"} shell` })}.`,
  });
};

const plateView = <M>(table: Drawn<M>): Html => {
  const { h } = table;

  return h.div(
    [h.Class("plate")],
    [...Arr.makeBy(12, (light) => h.span([h.Class("plate-light"), h.Style({ rotate: `${light * 30}deg` })], [])), h.p([h.Class("sr-only")], [shellsText(table.view)])],
  );
};

const drawn = <M>(h: HtmlBuilder<M>, table: Table<M>): Drawn<M> => {
  const chosen = Option.flatMap(table.chosen, (index) => Arr.get(table.moves, index));

  return {
    h,
    view: table.view,
    onTable: boardMoves(table.moves).onTable,
    onMove: table.onMove,
    marked: new Set(Option.match(chosen, { onNone: () => [], onSome: (move) => targetsOf(move).map(targetKey) })),
    chosen,
  };
};

/** A red edge on the screen when the near seat takes a live shot; outside the tilted table. Only a seated viewer feels it. */
export const hurtView = <M>(h: HtmlBuilder<M>, view: SeatTable): Html =>
  Option.match(
    Option.filter(lastOf(view, GameEvent.guards.Fired), ({ event }) => event.applied > 0 && event.target === view.near),
    { onNone: () => h.empty, onSome: ({ index }) => h.keyed("div")(effectKey(view, "hurt", index), [h.Class("hurt"), h.AriaHidden(true)], []) },
  );

export const tableView = <M>(h: HtmlBuilder<M>, table: Table<M>): Html => {
  const drawing = drawn(h, table);
  const { board } = table.view;

  return h.div(
    [h.Class("stage"), h.AriaLabel("Table"), h.DataAttribute("seats", `${board.seats.length}`)],
    [
      h.div([h.Class("cloth")], []),
      plateView(drawing),
      tallyView(drawing),
      ...board.seats.map((seatView) => zoneView(drawing, seatView)),
      revealView(drawing),
      ejectView(drawing),
      ...gunView(drawing),
    ],
  );
};
