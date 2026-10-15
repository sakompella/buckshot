import { Array as Arr, Option, Schema } from "effect";

import type { Seat } from "./domain.ts";

// What people and agents call a seat: Player A to Player D. By default letters
// follow the table's seat order, so a 2-seat table's seats 1 and 3 are Player A
// and Player B; a Roster built from an explicit assignment keeps its letters
// whichever seats they sit in. Bend and the driver keep raw seat ids; only a
// Roster converts between the two.

/** A player's letter as people, agents and logs write it. Parse it with this schema wherever text comes in. */
export const Letter = Schema.Literals(["A", "B", "C", "D"]);

export type Letter = typeof Letter.Type;

/**
 * A player seated at a table. Only a Roster makes one, so holding a Player proves the table has it and its seat is known.
 * `Player<"A">` is Player A where the letter is known statically and `Player` is any player; a call that names a letter gets a `Player` from `Roster.find`.
 */
export interface Player<L extends Letter = Letter> {
  readonly letter: L;
  readonly seat: Seat;
}

export const playerName = (letter: Letter): string => `Player ${letter}`;

/** The letter of each seat at a table. */
export type Assignment = ReadonlyMap<Seat, Letter>;

/** The players at one table, in table order. */
export interface Roster {
  readonly players: ReadonlyArray<Player>;
  /** The player in a seat of this table. Events and boards only name seated seats, so any other seat is a bug. */
  readonly playerOf: (seat: Seat) => Player;
  /** The player a caller named, or none when the table has no such player. */
  readonly find: <L extends Letter>(letter: L) => Option.Option<Player<L>>;
  readonly nameOf: (seat: Seat) => string;
}

const inTableOrder = (seats: ReadonlyArray<Seat>): Assignment => new Map(Arr.zip(seats, Letter.literals));

/** A roster for the seats of a table. Without an assignment the letters run A, B, ... in the order of the seats. */
export const rosterOf = (seats: ReadonlyArray<Seat>, assignment: Assignment = inTableOrder(seats)): Roster => {
  const players = Arr.getSomes(seats.map((seat) => Option.fromUndefinedOr(assignment.get(seat)).pipe(Option.map((letter): Player => ({ letter, seat })))));

  if (players.length !== seats.length || new Set(players.map(({ letter }) => letter)).size !== seats.length) {
    throw new Error("A roster needs every seat at the table to have its own letter.");
  }

  const playerOf = (seat: Seat): Player =>
    Arr.findFirst(players, (player) => player.seat === seat).pipe(Option.getOrThrowWith(() => new Error("A player was asked for a seat that is not at this table.")));

  return {
    players,
    playerOf,
    find: <L extends Letter>(letter: L) => Arr.findFirst(players, (player): player is Player<L> => player.letter === letter),
    nameOf: (seat) => playerName(playerOf(seat).letter),
  };
};
