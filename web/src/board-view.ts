import { Array as Arr, Option } from "effect";
import { CustomElement } from "foldkit";
import type { Html, HtmlBuilder } from "foldkit/html";

import { type BoardMove, boardMoves, type Position, positionOf, Target, targetKey, viewerPrompt } from "./board.ts";
import { Briefcase, Counter, GameEvent, type Load, type Seat, type SeatView, seatsOut, type Shell, Slot, Stage } from "./domain.ts";
import { boltIcon, gunIcon, itemIcon, shellIcon } from "./icons.ts";
import { Message, type Session } from "./model.ts";
import { itemName, itemNote, seatName } from "./text.ts";

// The table from above. Each seat's things sit in a layer turned to face its
// edge, so one layout serves all four sides. The viewer's legal moves are
// buttons on the things they act on; recent events play once as CSS
// animations, keyed by their place in the event log.

type H = HtmlBuilder<Message>;

/** The lazily loaded three.js shotgun (gun-model.ts); until it is defined the SVG gun shows. */
const gunModel = CustomElement.define({ tag: "gun-model", properties: {}, events: {} });

/** How many of the latest events may still be animating. */
const RECENT_EVENTS = 12;

interface Recent {
  readonly index: number;
  readonly event: GameEvent;
}

interface Table {
  readonly match: Session;
  readonly matchNumber: number;
  readonly moves: ReadonlyMap<string, BoardMove>;
  readonly toMessage: (move: BoardMove) => Option.Option<Message>;
  readonly recent: ReadonlyArray<Recent>;
  readonly out: ReadonlySet<Seat>;
}

const turn = (position: Position): string => `${position * 90}deg`;

/** A one-time animation's key: the match and the event's place in the log. */
const effectKey = (table: Table, name: string, index: number): string => `${table.matchNumber}-${name}-${index}`;

const moveAt = (table: Table, target: Target): Option.Option<BoardMove> => Option.fromNullishOr(table.moves.get(targetKey(target)));

const tip = (h: H, label: string, note: string): Html => h.span([h.Class("tip")], [label, note === "" ? h.empty : h.span([h.Class("tip-note")], [note])]);

/** A thing on the table: a button while a legal move is played on it, plain otherwise. */
const thing = (h: H, table: Table, target: Target, className: string, children: ReadonlyArray<Html>, note = ""): Html =>
  Option.match(
    Option.flatMap(moveAt(table, target), (move) => Option.map(table.toMessage(move), (message) => ({ move, message }))),
    {
      onNone: () => h.div([h.Class(className)], children),
      onSome: ({ move, message }) =>
        h.button([h.Type("button"), h.Class(`${className} hot`), h.AriaLabel(move.label), h.OnClick(message)], [...children, tip(h, move.label, note)]),
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
        [
          h.p([h.Class("counter-name")], [h.span([], [seatName(view.seat)]), h.span([h.Class("counter-cash")], [`$${view.cash.toLocaleString("en-US")}`])]),
          h.div([h.Class("counter-screen")], screen),
        ],
      ),
    ],
  );
};

const slotView = (h: H, table: Table, view: SeatView, slot: Slot): Html => {
  const target = Target.cases.Slot.make({ seat: view.seat, slot });
  const item = Option.flatten(Arr.get(view.slots, slot));
  const isMove = Option.isSome(moveAt(table, target));

  return thing(
    h,
    table,
    target,
    `slot slot-${slot}`,
    Option.match(item, { onNone: () => [], onSome: (shown) => [itemIcon(shown), isMove ? h.empty : tip(h, itemName(shown), itemNote(shown))] }),
    Option.match(item, { onNone: () => "", onSome: itemNote }),
  );
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

/** Words that rise over a seat's counter for one event. */
const floatText = (event: GameEvent, seat: Seat): Option.Option<readonly [string, string]> =>
  GameEvent.matchOrElse(
    event,
    {
      Fired: ({ target, shell, applied }) => (target === seat ? Option.some(shell === "Live" ? ([`Live −${applied}`, "live"] as const) : (["Blank", "blank"] as const)) : Option.none()),
      Healed: ({ seat: healed }) => (healed === seat ? Option.some(["+1", "good"] as const) : Option.none()),
      JamApplied: ({ target }) => (target === seat ? Option.some(["Jammed", ""] as const) : Option.none()),
      TurnSkipped: ({ seat: skipped }) => (skipped === seat ? Option.some(["Skipped", ""] as const) : Option.none()),
      Died: ({ seat: died }) => (died === seat ? Option.some(["Out", "live late"] as const) : Option.none()),
      Used: ({ seat: user, owner, item }) => (user === seat ? Option.some([user === owner ? itemName(item) : `${itemName(item)}, taken`, "item"] as const) : Option.none()),
    },
    () => Option.none(),
  );

const seatEffects = (h: H, table: Table, seat: Seat, position: Position): ReadonlyArray<Html> =>
  table.recent.flatMap(({ index, event }) =>
    Option.match(floatText(event, seat), {
      onNone: () => [],
      onSome: ([text, tone]) => [h.keyed("p")(effectKey(table, `float-${seat}`, index), [h.Class(`float ${tone}`), h.Style({ rotate: `-${turn(position)}` }), h.AriaHidden(true)], [text])],
    }),
  );

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
      ...Slot.literals.map((slot) => slotView(h, table, view, slot)),
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
                [h.span([h.Class("tip"), h.Style({ rotate: `-${turn(position)}` })], [move.label])],
              ),
          }),
      }),
      ...seatEffects(h, table, view.seat, position),
    ],
  );
};

// GUN

const shellsRow = (h: H, load: Load): ReadonlyArray<Html> => [
  ...Arr.makeBy(load.live, (): Shell => "Live"),
  ...Arr.makeBy(load.blank, (): Shell => "Blank"),
].map((shell) => h.span([h.Class("shell")], [shellIcon(shell)]));

/** The shells of the newest load, laid out for a moment and then gone into the gun. */
const revealView = (h: H, table: Table): Html =>
  Option.match(lastOf(table, GameEvent.guards.Loaded), {
    onNone: () => h.empty,
    onSome: ({ index, event }) =>
      h.keyed("div")(
        effectKey(table, "reveal", index),
        [h.Class("reveal"), h.AriaHidden(true)],
        [
          h.p([h.Class("reveal-count")], [h.span([h.Class("live")], [`${event.load.live} live`]), " · ", h.span([h.Class("blank")], [`${event.load.blank} blank`])]),
          h.div([h.Class("reveal-shells")], shellsRow(h, event.load)),
        ],
      ),
  });

const ejectView = (h: H, table: Table): Html =>
  Option.match(lastOf(table, GameEvent.guards.Ejected), {
    onNone: () => h.empty,
    onSome: ({ index, event }) =>
      h.keyed("div")(effectKey(table, "eject", index), [h.Class(`eject ${event.shell === "Live" ? "live" : "blank"}`), h.AriaHidden(true)], [
        h.span([h.Class("shell")], [shellIcon(event.shell)]),
        h.p([h.Class("eject-text")], [event.shell === "Live" ? "Live" : "Blank"]),
      ]),
  });

const centreText = (h: H, table: Table): ReadonlyArray<Html> =>
  table.recent.flatMap(({ index, event }) =>
    GameEvent.matchOrElse(
      event,
      {
        Inverted: () => [h.keyed("p")(effectKey(table, "centre", index), [h.Class("float centre")], ["Inverted"])],
        DirectionFlipped: () => [h.keyed("p")(effectKey(table, "centre", index), [h.Class("float centre")], ["Order reversed"])],
      },
      () => [],
    ),
  );

/**
 * The gun rests across the plate. A seat aiming holds it at its edge, turned
 * toward the seat under the pointer; after a shot it shows the shooter's aim
 * for a moment, then goes back to rest. The gun's elements stay the same
 * across renders (the 3D model holds a WebGL context), so a new shot restarts
 * the animation by switching between two copies of its keyframes.
 */
const gunView = (h: H, table: Table): ReadonlyArray<Html> => {
  const { board } = table.match.game;
  const aimer = Stage.matchOrElse(board.stage, { Playing: ({ seat, mode }) => (mode === "Aiming" ? Option.some(seat) : Option.none<Seat>()) }, () => Option.none<Seat>());
  const shot = lastOf(table, GameEvent.guards.Fired);
  const position = (seat: Seat): Position => positionOf(table.match, seat);

  const rigStyle = Option.match(aimer, {
    onSome: (seat) => ({ "--holder": turn(position(seat)) }),
    onNone: () =>
      Option.match(shot, {
        onNone: () => ({}),
        onSome: ({ event }) => ({ "--holder": turn(position(event.shooter)), "--aim": `${((position(event.target) - position(event.shooter) + 4) % 4) * 90}deg` }),
      }),
  });

  const rigClass = Option.isSome(aimer) ? "gun-rig held" : Option.match(shot, { onNone: () => "gun-rig", onSome: ({ index }) => `gun-rig fired-${index % 2 === 0 ? "a" : "b"}` });
  const liveShot = Option.filter(shot, ({ event }) => event.shell === "Live");
  const model = gunModel.withMessage(h);

  return [
    h.div(
      [h.Class(rigClass), h.Style(rigStyle), h.AriaHidden(true)],
      [
        h.div(
          [h.Class("gun-body")],
          [
            gunIcon(board.gun.sawed),
            model(
              [
                h.Key("gun-model"),
                h.DataAttribute("sawed", `${board.gun.sawed}`),
                h.DataAttribute("held", `${Option.isSome(aimer)}`),
                h.DataAttribute("shot", Option.match(liveShot, { onNone: () => "", onSome: ({ index }) => `${index}` })),
              ],
              [],
            ),
          ],
        ),
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
      h.p([h.Class("plate-count"), h.AriaLabel(`${gun.remaining} shells in the gun; last load ${gun.shown.live} live, ${gun.shown.blank} blank`)], [`${gun.remaining}`]),
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
    moves: Option.match(prompt, { onNone: () => new Map<string, BoardMove>(), onSome: (mine) => boardMoves(mine).onTable }),
    toMessage: (move) => Option.map(prompt, ({ ticket, seat }) => Message.ClickedMove({ match: ticket.match, generation: ticket.generation, seat, index: move.index })),
    recent: match.events.slice(-RECENT_EVENTS).map((event, offset) => ({ index: Math.max(0, match.events.length - RECENT_EVENTS) + offset, event })),
    out: seatsOut(match.events),
  };
};

export const tableView = (h: H, match: Session, matchNumber: number): Html => {
  const table = tableOf(match, matchNumber);

  return h.div(
    [h.Class("stage"), h.AriaLabel("Table")],
    [
      h.div([h.Class("cloth")], []),
      plateView(h, table),
      ...match.game.board.seats.map((view) => zoneView(h, table, view, positionOf(match, view.seat))),
      revealView(h, table),
      ejectView(h, table),
      ...gunView(h, table),
      ...centreText(h, table),
    ],
  );
};
