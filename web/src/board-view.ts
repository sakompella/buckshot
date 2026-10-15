import { Array as Arr, Option } from "effect";
import type { Html, HtmlBuilder } from "foldkit/html";

import { type BoardMove, boardMoves, type Position, positionOf, Target, targetKey, viewerPrompt } from "./board.ts";
import { Briefcase, Counter, GameEvent, type Item, type Seat, type SeatView, seatsOut, type Shell, Slot, Stage } from "./domain.ts";
import { boltIcon, gunIcon, itemIcon, shellIcon } from "./icons.ts";
import { latestStep, Message, type Session, type StepEvent } from "./model.ts";
import { rosterOf } from "./players.ts";
import { itemName, itemNote } from "./text.ts";

// The table from above. Each seat's things sit in a layer turned to face its
// edge, so one layout serves all four sides. The viewer's legal moves are
// buttons on the things they act on; the latest step's events play once as
// CSS animations, keyed by their place in the event log, and are gone when
// the next step starts.

type H = HtmlBuilder<Message>;

interface Table {
  readonly match: Session;
  readonly matchNumber: number;
  readonly moves: ReadonlyMap<string, BoardMove>;
  readonly toMessage: (move: BoardMove) => Option.Option<Message>;
  readonly recent: ReadonlyArray<StepEvent>;
  readonly out: ReadonlySet<Seat>;
}

const turn = (position: Position): string => `${position * 90}deg`;

/** A one-time animation's key: the match and the event's place in the log. */
const effectKey = (table: Table, name: string, index: number): string => `${table.matchNumber}-${name}-${index}`;

const moveAt = (table: Table, target: Target): Option.Option<BoardMove> => Option.fromNullishOr(table.moves.get(targetKey(target)));

/** An item's one-line caption, shown while the pointer is on it, turned to read upright. */
const captionOf = (h: H, item: Item, position: Position): Html => {
  const name = itemName(item);

  return h.span([h.Class("caption"), h.Style({ rotate: `-${turn(position)}` }), h.AriaHidden(true)], [`${name.charAt(0).toUpperCase()}${name.slice(1)}. ${itemNote(item)}`]);
};

/** A thing on the table: a button while a legal move is played on it, plain otherwise. */
const thing = (h: H, table: Table, target: Target, className: string, children: ReadonlyArray<Html>): Html =>
  Option.match(
    Option.flatMap(moveAt(table, target), (move) => Option.map(table.toMessage(move), (message) => ({ move, message }))),
    {
      onNone: () => h.div([h.Class(className)], children),
      onSome: ({ move, message }) => h.button([h.Type("button"), h.Class(`${className} hot`), h.AriaLabel(move.label), h.OnClick(message)], children),
    },
  );

const lastOf = <A extends GameEvent>(table: Table, isKind: (event: GameEvent) => event is A): Option.Option<{ readonly index: number; readonly event: A }> =>
  Arr.findLast(
    table.recent.flatMap(({ index, event }) => (isKind(event) ? [{ index, event }] : [])),
    () => true,
  );

// SEATS

const boltsView = (h: H, table: Table, seat: Seat, health: number): ReadonlyArray<Html> => {
  const maxHealth = table.match.game.board.round.health;
  const shot = Option.filter(lastOf(table, GameEvent.guards.Fired), ({ event }) => event.target === seat && event.applied > 0);

  return Arr.makeBy(Math.max(maxHealth, health), (charge) => {
    const drainedBy = Option.filter(shot, ({ event }) => charge >= health && charge < health + event.applied);

    return Option.match(drainedBy, {
      onNone: () => h.keyed("span")(`bolt-${charge}`, [h.Class(charge < health ? "bolt" : "bolt spent")], [boltIcon("bolt-icon")]),
      onSome: ({ index }) => h.keyed("span")(effectKey(table, `drain-${charge}`, index), [h.Class("bolt spent drain")], [boltIcon("bolt-icon")]),
    });
  });
};

const counterView = (h: H, table: Table, view: SeatView, position: Position, isActing: boolean): Html => {
  const isOut = table.out.has(view.seat);

  const screen = Counter.match(view.counter, {
    Jammed: () => [h.span([h.Class("counter-static")], ["Jammed"])],
    Unjammed: ({ health }) => (isOut ? [h.span([h.Class("counter-flat")], [])] : boltsView(h, table, view.seat, health)),
  });

  return h.div(
    [h.Class(`counter${isActing ? " acting" : ""}${isOut ? " out" : ""}`)],
    [
      h.div(
        [h.Class("counter-face"), h.Style({ rotate: `-${turn(position)}` })],
        [h.div([h.Class("counter-screen")], screen)],
      ),
    ],
  );
};

/** An empty slot shows only while it is somewhere to place an item. */
const slotView = (h: H, table: Table, view: SeatView, slot: Slot, position: Position): Html => {
  const target = Target.cases.Slot.make({ seat: view.seat, slot });

  return Option.match(Option.flatten(Arr.get(view.slots, slot)), {
    onNone: () => (Option.isSome(moveAt(table, target)) ? thing(h, table, target, `slot slot-${slot}`, []) : h.empty),
    onSome: (item) => thing(h, table, target, `slot slot-${slot} filled`, [itemIcon(item), captionOf(h, item, position)]),
  });
};

const briefcaseView = (h: H, table: Table, view: SeatView): Html =>
  Briefcase.match(view.briefcase, {
    NotGrabbing: () => h.empty,
    Grabbing: () => thing(h, table, Target.cases.Briefcase.make({ seat: view.seat }), "briefcase", [h.span([h.Class("briefcase-lid")], []), h.span([h.Class("briefcase-tray")], [])]),
    Holding: ({ item }) =>
      thing(h, table, Target.cases.Briefcase.make({ seat: view.seat }), "briefcase holding", [h.span([h.Class("briefcase-lid")], []), h.span([h.Class("briefcase-tray")], [itemIcon(item)])]),
  });

const figureView = (h: H): Html =>
  h.div([h.Class("figure")], [h.span([h.Class("figure-shoulders")], []), h.span([h.Class("figure-head")], [h.span([h.Class("figure-eyes")], [])])]);

/** The item a seat just used, lifting off its slot. */
const usedGhost = (h: H, table: Table, seat: Seat): Html =>
  Option.match(
    Option.filter(lastOf(table, GameEvent.guards.Used), ({ event }) => event.owner === seat),
    {
      onNone: () => h.empty,
      onSome: ({ index, event }) => h.keyed("div")(effectKey(table, "used", index), [h.Class(`slot ghost slot-${event.slot}`), h.AriaHidden(true)], [itemIcon(event.item)]),
    },
  );

const zoneView = (h: H, table: Table, view: SeatView, position: Position): Html => {
  const isActing = Stage.matchOrElse(table.match.game.board.stage, { Playing: ({ seat }) => seat === view.seat }, () => false);
  const seatTarget = Target.cases.Seat.make({ seat: view.seat });
  const isOut = table.out.has(view.seat);

  return h.div(
    [h.Class(`zone pos-${position}${isOut ? " is-out" : ""}`), h.Style({ rotate: turn(position) }), h.DataAttribute("pos", `${position}`)],
    [
      position === 0 ? h.empty : figureView(h),
      ...Slot.literals.map((slot) => slotView(h, table, view, slot, position)),
      usedGhost(h, table, view.seat),
      briefcaseView(h, table, view),
      counterView(h, table, view, position, isActing),
      Option.match(moveAt(table, seatTarget), {
        onNone: () => h.empty,
        onSome: (move) =>
          Option.match(table.toMessage(move), {
            onNone: () => h.empty,
            onSome: (message) =>
              h.button(
                [h.Type("button"), h.Class("seat-target hot"), h.AriaLabel(move.label), h.DataAttribute("aim", `${position}`), h.OnClick(message)],
                [],
              ),
          }),
      }),
    ],
  );
};

// GUN

const shellGroup = (h: H, count: number, shell: Shell): Html =>
  h.div([h.Class("shell-group")], Arr.makeBy(count, () => h.span([h.Class("shell")], [shellIcon(shell)])));

/** The shells of the newest load, set out on the cloth in a live group and a blank group long enough to count, then gone into the gun. */
const revealView = (h: H, table: Table): Html =>
  Option.match(lastOf(table, GameEvent.guards.Loaded), {
    onNone: () => h.empty,
    onSome: ({ index, event }) =>
      h.keyed("div")(
        effectKey(table, "reveal", index),
        [h.Class("reveal"), h.AriaHidden(true)],
        [shellGroup(h, event.load.live, "Live"), shellGroup(h, event.load.blank, "Blank")],
      ),
  });

const ejectView = (h: H, table: Table): Html =>
  Option.match(lastOf(table, GameEvent.guards.Ejected), {
    onNone: () => h.empty,
    onSome: ({ index, event }) =>
      h.keyed("div")(effectKey(table, "eject", index), [h.Class("eject"), h.Role("img"), h.AriaLabel(`Racked out a ${event.shell === "Live" ? "live" : "blank"} shell`)], [
        h.span([h.Class("shell")], [shellIcon(event.shell)]),
      ]),
  });

/**
 * The gun lies across the plate. A seat aiming holds it on its side of the
 * plate, turned toward the seat under the pointer. On a shot it turns from
 * wherever it is to the target (a CSS transition, so a bot's shot turns as
 * smoothly as a human's), fires and recoils, holds, then settles back on the
 * plate. A new shot restarts the keyframes by switching between two copies.
 */
const gunView = (h: H, table: Table): ReadonlyArray<Html> => {
  const { board } = table.match.game;
  const aimer = Stage.matchOrElse(board.stage, { Playing: ({ seat, mode }) => (mode === "Aiming" ? Option.some(seat) : Option.none<Seat>()) }, () => Option.none<Seat>());
  const shot = lastOf(table, GameEvent.guards.Fired);
  const position = (seat: Seat): Position => positionOf(table.match, seat);

  // The right-hand seat holds it at -90deg, so the gun never swings the long way round.
  const holder = (seat: Seat): string => `${position(seat) === 3 ? -90 : position(seat) * 90}deg`;

  const rigStyle = Option.match(aimer, {
    onSome: (seat) => ({ "--holder": holder(seat) }),
    onNone: () =>
      Option.match(shot, {
        onNone: () => ({}),
        onSome: ({ event }) => ({ "--holder": holder(event.shooter), "--aim": `${((position(event.target) - position(event.shooter) + 4) % 4) * 90}deg` }),
      }),
  });

  const rigClass = Option.isSome(aimer) ? "gun-rig held" : Option.match(shot, { onNone: () => "gun-rig", onSome: ({ index }) => `gun-rig fired-${index % 2 === 0 ? "a" : "b"}` });
  const liveShot = Option.filter(shot, ({ event }) => event.shell === "Live");

  return [
    h.div(
      [h.Class(rigClass), h.Style(rigStyle), h.AriaHidden(true)],
      [
        h.div([h.Class("gun-body")], [gunIcon(board.gun.sawed)]),
        Option.match(liveShot, { onNone: () => h.empty, onSome: ({ index }) => h.keyed("span")(effectKey(table, "flash", index), [h.Class("flash")], []) }),
      ],
    ),
    Option.isSome(moveAt(table, Target.cases.Gun.make({}))) ? thing(h, table, Target.cases.Gun.make({}), "gun-pick", []) : h.empty,
  ];
};

const plateView = (h: H, table: Table): Html => {
  const { gun } = table.match.game.board;

  return h.div(
    [h.Class("plate")],
    [
      ...Arr.makeBy(12, (light) => h.span([h.Class("plate-light"), h.Style({ rotate: `${light * 30}deg` })], [])),
      h.p([h.Class("sr-only")], [`${gun.remaining} shells in the gun; last load ${gun.shown.live} live, ${gun.shown.blank} blank.`]),
    ],
  );
};

/** A red edge on the screen when the viewer takes a live shell; outside the tilted table. */
export const hurtView = (h: H, match: Session, matchNumber: number): Html => {
  const table = tableOf(match, matchNumber);

  return hurtFlash(h, table);
};

const hurtFlash = (h: H, table: Table): Html =>
  Option.match(
    Option.filter(lastOf(table, GameEvent.guards.Fired), ({ event }) => event.applied > 0 && positionOf(table.match, event.target) === 0 && table.match.viewer === event.target),
    { onNone: () => h.empty, onSome: ({ index }) => h.keyed("div")(effectKey(table, "hurt", index), [h.Class("hurt"), h.AriaHidden(true)], []) },
  );

const tableOf = (match: Session, matchNumber: number): Table => {
  const prompt = viewerPrompt(match);

  return {
    match,
    matchNumber,
    moves: Option.match(prompt, { onNone: () => new Map<string, BoardMove>(), onSome: (mine) => boardMoves(rosterOf(match.game.seats), mine).onTable }),
    toMessage: (move) => Option.map(prompt, ({ ticket, seat }) => Message.ClickedMove({ match: ticket.match, generation: ticket.generation, seat, index: move.index })),
    recent: latestStep(match),
    out: seatsOut(match.events),
  };
};

export const tableView = (h: H, match: Session, matchNumber: number): Html => {
  const table = tableOf(match, matchNumber);

  return h.div(
    [h.Class("stage"), h.AriaLabel("Table"), h.DataAttribute("seats", `${match.game.seats.length}`)],
    [
      h.div([h.Class("cloth")], []),
      plateView(h, table),
      ...match.game.board.seats.map((view) => zoneView(h, table, view, positionOf(match, view.seat))),
      revealView(h, table),
      ejectView(h, table),
      ...gunView(h, table),
    ],
  );
};
