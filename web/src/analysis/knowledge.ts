import { createHash } from "node:crypto";

import { Option } from "effect";

import { type Board, type GameEvent as Event, GameEvent, Item, type LearnedSecret, type Seat, Secret, type Shell } from "../domain.ts";
import { type Roster } from "../players.ts";
import { eventText, itemName, secretText } from "../text.ts";
import { type Orders, type OwnEntry, ownLog, type Player } from "./player.ts";

// One player's own information at a decision, rebuilt from its log: the public
// events and the secrets that player heard. The shell belief comes from the
// minimax player's belief module in Bend (sim/bend-mp/player/belief.bend), which
// enumerates the shell orders the log allows, with multiplicity. Nothing here
// knows how a shot, a beer or an inverter changes the gun; it only marshals the
// log into Bend (through ./player.ts) and reads marginals off the orders Bend
// returns. The hidden gun and other players' secrets never enter.

// A player's own log
// ==================

/** The seat's log from the latest load on, in the order the seat heard it. Empty before the first load. */
export const loadLog = (events: ReadonlyArray<Event>, learned: ReadonlyArray<LearnedSecret>, seat: Seat): ReadonlyArray<OwnEntry> => {
  const from = events.findLastIndex(GameEvent.guards.Loaded);
  const log = ownLog(events, learned, seat);

  return from < 0 ? [] : log.slice(log.findIndex((entry) => entry.kind === "event" && entry.index === from));
};

/** A shell clue: the magnifier shows the chamber, the phone a later shell. */
export type ClueKind = "glass" | "phone";

const clueKind = (entry: OwnEntry): Option.Option<ClueKind> =>
  entry.kind === "secret" ? Secret.match(entry.secret, { Glimpse: () => Option.some<ClueKind>("glass"), Clue: () => Option.some<ClueKind>("phone"), NoClue: () => Option.none(), EmptyBriefcase: () => Option.none() }) : Option.none();

/** Whether the clue a seat heard after `at` events came from a magnifier or phone taken with adrenaline: its latest glass or phone use before then was another player's item. */
export const stolenClue = (events: ReadonlyArray<Event>, at: number, seat: Seat): boolean => {
  const use = events.slice(0, at).findLast((event) => GameEvent.matchOrElse(event, { Used: (used) => used.seat === seat && (used.item === "Glass" || used.item === "Phone") }, () => false));

  return use !== undefined && GameEvent.matchOrElse(use, { Used: (used) => used.owner !== used.seat }, () => false);
};

// Beliefs
// =======

export interface Summary {
  /** Orders the log allows, counted with weight. */
  readonly orders: number;
  /** Live shells among those left: the fewest and most any allowed order holds. Equal unless an inversion is still unresolved. */
  readonly liveMin: number;
  readonly liveMax: number;
  /** Each position from the chamber out: allowed orders with a live shell there. */
  readonly live: ReadonlyArray<number>;
}

export const summaryOf = (orders: Orders): Summary => {
  const lives = orders.map((order) => [...order].filter((shell) => shell === "L").length);
  const length = orders[0]?.length ?? 0;

  return {
    orders: orders.length,
    liveMin: Math.min(...lives),
    liveMax: Math.max(...lives),
    live: Array.from({ length }, (_, position) => orders.filter((order) => order[position] === "L").length),
  };
};

/** The shell at a position, when every allowed order agrees. */
export const certainAt = (summary: Summary, position: number): Option.Option<Shell> => {
  const live = summary.live[position];

  if (live === undefined || summary.orders === 0) return Option.none();

  return live === summary.orders ? Option.some("Live") : live === 0 ? Option.some("Blank") : Option.none();
};

/** Certain positions, from 1, as "1L 3B". */
export const knownText = (summary: Summary): string =>
  summary.live.flatMap((_, position) => Option.toArray(certainAt(summary, position)).map((shell) => `${position + 1}${shell === "Live" ? "L" : "B"}`)).join(" ");

/**
 * Where a certain chamber comes from: "public" when the public log alone settles it, as when every shell left is live; otherwise the most recent single clue that
 * settles it with the public log, or "combined" when only several clues together do.
 */
export type Source = "public" | ClueKind | "combined";

export interface Knowledge {
  readonly public: Summary;
  readonly private: Summary;
  readonly chamber: Option.Option<Shell>;
  readonly source: Option.Option<Source>;
  /** The clue `source` names: its index among the match's learned secrets. */
  readonly clue: Option.Option<number>;
}

export const knowledgeOf = (belief: Pick<Player, "orders">, log: ReadonlyArray<OwnEntry>): Knowledge => {
  const publicSummary = summaryOf(belief.orders(log, false));
  const privateSummary = summaryOf(belief.orders(log, true));
  const chamber = certainAt(privateSummary, 0);
  const none = { public: publicSummary, private: privateSummary, chamber, source: Option.none(), clue: Option.none() };

  if (Option.isNone(chamber)) return none;

  if (Option.isSome(certainAt(publicSummary, 0))) return { ...none, source: Option.some("public") };

  const clues = log.filter((entry) => Option.isSome(clueKind(entry)));
  const alone = (clue: OwnEntry): boolean => Option.isSome(certainAt(summaryOf(belief.orders(log.filter((entry) => entry.kind === "event" || entry === clue), true)), 0));
  const deciding = clues.findLast(alone);

  if (deciding === undefined) return { ...none, source: Option.some("combined"), clue: Option.fromUndefinedOr(clues.at(-1)?.index) };

  return { ...none, source: clueKind(deciding), clue: Option.some(deciding.index) };
};

// Items
// =====

/** How an item left its owner's slots: used, stolen with adrenaline, still held when the owner died, or still held when the round or match ended. */
export type ItemEnd = "used" | "stolen" | "died" | "round end" | "match end";

export interface Holding {
  readonly seat: Seat;
  readonly slot: number;
  readonly item: Item;
  /** The event that placed it. */
  readonly placed: number;
}

export interface ItemRecord extends Holding {
  readonly end: ItemEnd;
  /** The event that ended it. */
  readonly ended: number;
  /** The thief, for a stolen item. */
  readonly by: Option.Option<Seat>;
}

export interface Ledger {
  readonly open: ReadonlyArray<Holding>;
  readonly closed: ReadonlyArray<ItemRecord>;
  /** Where the log contradicts the ledger: a placement into a held slot, or a use of an item the ledger does not hold. */
  readonly problems: ReadonlyArray<string>;
}

export const emptyLedger: Ledger = { open: [], closed: [], problems: [] };

const closeWhere = (ledger: Ledger, ends: (holding: Holding) => boolean, end: ItemEnd, ended: number, by: Option.Option<Seat> = Option.none()): Ledger => ({
  ...ledger,
  open: ledger.open.filter((holding) => !ends(holding)),
  closed: [...ledger.closed, ...ledger.open.filter(ends).map((holding) => ({ ...holding, end, ended, by }))],
});

/** The ledger after event `index`. Items follow the public log only: a placement opens one, and a use, steal, death or new round ends it. */
export const ledgerStep = (ledger: Ledger, event: Event, index: number): Ledger =>
  GameEvent.matchOrElse(
    event,
    {
      Placed: ({ seat, slot, item }) =>
        ledger.open.some((holding) => holding.seat === seat && holding.slot === slot)
          ? { ...ledger, problems: [...ledger.problems, `event ${index}: placed ${item} in an occupied slot`] }
          : { ...ledger, open: [...ledger.open, { seat, slot, item, placed: index }] },
      Used: ({ seat, owner, slot, item }) => {
        const held = (holding: Holding) => holding.seat === owner && holding.slot === slot && holding.item === item;

        if (!ledger.open.some(held)) return { ...ledger, problems: [...ledger.problems, `event ${index}: used ${item} that the ledger does not hold`] };

        return seat === owner ? closeWhere(ledger, held, "used", index) : closeWhere(ledger, held, "stolen", index, Option.some(seat));
      },
      Died: ({ seat }) => closeWhere(ledger, (holding) => holding.seat === seat, "died", index),
      RoundBegan: () => closeWhere(ledger, () => true, "round end", index),
      MatchConcluded: () => closeWhere(ledger, () => true, "match end", index),
    },
    () => ledger,
  );

/** Where the ledger and the board disagree about a seat's items: they must hold the same item in every slot. */
export const ledgerMismatch = (ledger: Ledger, board: Board): Option.Option<string> => {
  const fromBoard = board.seats.flatMap((view) => view.slots.flatMap((slot, index) => Option.toArray(slot).map((item) => `${view.seat}:${index}:${item}`))).toSorted();
  const fromLedger = ledger.open.map((holding) => `${holding.seat}:${holding.slot}:${holding.item}`).toSorted();

  return fromBoard.join() === fromLedger.join() ? Option.none() : Option.some(`board ${fromBoard.join(" ")} vs ledger ${fromLedger.join(" ")}`);
};

// Moves
// =====

/** The item a move spends, and whether it is taken from another player with adrenaline. Shots and grabs spend none. */
export interface ItemMove {
  readonly item: Item;
  readonly stolen: boolean;
}

const ITEM_BY_NAME = new Map<string, Item>(Item.literals.map((item) => [itemName(item), item]));

/** Reads a move's label, as src/text.ts words it: "Use beer", "Jam Player B", "Steal handsaw from Player A". */
export const itemMoveOf = (label: string): Option.Option<ItemMove> => {
  const used = /^Use (.+)$/.exec(label);
  const stolen = /^Steal (.+?) from Player [A-D]/.exec(label);

  if (stolen?.[1] !== undefined) return Option.map(Option.fromUndefinedOr(ITEM_BY_NAME.get(stolen[1])), (item) => ({ item, stolen: true }));

  if (used?.[1] !== undefined) return Option.map(Option.fromUndefinedOr(ITEM_BY_NAME.get(used[1])), (item) => ({ item, stolen: false }));

  return /^Jam Player [A-D]/.test(label) ? Option.some({ item: "Jammer", stolen: false }) : Option.none();
};

export type ShotTarget = "self" | "opponent";

export const shotOf = (label: string): Option.Option<ShotTarget> => (label === "Shoot yourself" ? Option.some("self") : /^Shoot Player [A-D]$/.test(label) ? Option.some("opponent") : Option.none());

// Positions
// =========

const hash = (text: string): string => createHash("sha256").update(text).digest("hex").slice(0, 24);

/** Names players relative to `seat`, in table order: "you", then "player +1" and so on. Letters never reach a key. */
const relativeNames = (roster: Roster, seat: Seat): ReadonlyMap<string, string> => {
  const own = roster.players.findIndex((player) => player.seat === seat);
  const count = roster.players.length;

  return new Map(roster.players.map((player, index) => [`Player ${player.letter}`, index === own ? "you" : `player +${(index - own + count) % count}`]));
};

export const relativeText = (roster: Roster, seat: Seat, text: string): string => {
  const names = relativeNames(roster, seat);

  return text.replaceAll(/Player [A-D]/g, (name) => names.get(name) ?? name);
};

export interface PositionKeys {
  /** The board, the load shown, cash and round, the player's whole log since the load, and its legal moves. */
  readonly exact: string;
  /** The board, the load shown, cash and round, the public and private shell beliefs, what each opponent has learned with items this load, and the legal moves. */
  readonly belief: string;
}

/**
 * Keys under which two decisions are the same position for the deciding player. Both name players relative to the decider and
 * include the code and instructions hashes; neither includes the player's letter, seat, opponent or match.
 */
export const positionKeys = (roster: Roster, seat: Seat, board: Board, log: ReadonlyArray<OwnEntry>, orders: { readonly public: Orders; readonly private: Orders }, legal: ReadonlyArray<string>, version: ReadonlyArray<string | null>): PositionKeys => {
  const own = roster.players.findIndex((player) => player.seat === seat);
  const ordered = [...board.seats.slice(own), ...board.seats.slice(0, own)];

  const table = {
    round: [board.round.index, board.round.health],
    players: ordered.map((view) => [view.counter, view.slots.flatMap((slot) => Option.toArray(slot)).toSorted(), view.cash]),
    shown: [board.gun.shown.live, board.gun.shown.blank],
    sawed: board.gun.sawed,
    moves: legal.map((label) => relativeText(roster, seat, label)).toSorted(),
    version,
  };

  const entries = log.map((entry) => relativeText(roster, seat, entry.kind === "event" ? eventText(roster, entry.event) : secretText(entry.secret)));

  const learnedBy = ordered.slice(1).map((view) =>
    log.filter((entry) => entry.kind === "event" && GameEvent.matchOrElse(entry.event, { Used: (used) => used.seat === view.seat && (used.item === "Glass" || used.item === "Phone") }, () => false)).length,
  );

  const weights = (orders: Orders) => [...new Set(orders)].toSorted().map((order) => [order, orders.filter((other) => other === order).length]);

  return { exact: hash(JSON.stringify([table, entries])), belief: hash(JSON.stringify([table, weights(orders.public), weights(orders.private), learnedBy])) };
};
