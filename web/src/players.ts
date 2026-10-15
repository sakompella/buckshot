import { Array as Arr, Option, Schema } from "effect";

import type { Seat } from "./domain.ts";

// What people and agents call a seat: Player A to Player D. By default letters
// follow the table's seat order, so a 2-seat table's seats 1 and 3 are Player A
// and Player B; a Roster built from an explicit assignment keeps its letters
// whichever seats they sit in. Bend and the driver keep raw seat ids; only a
// Roster converts between the two.

const Letter = Schema.Literals(["A", "B", "C", "D"]);

export const PlayerLetter = Letter.pipe(Schema.brand("PlayerLetter"));

export type PlayerLetter = typeof PlayerLetter.Type;

export const playerName = (player: PlayerLetter): string => `Player ${player}`;

/** The letter of each seat at a table. */
export type Assignment = ReadonlyMap<Seat, PlayerLetter>;

/** The seats at one table, in table order. */
export interface Roster {
  readonly players: ReadonlyArray<PlayerLetter>;
  /** The player in a seat of this table. Events and boards only name seated seats, so any other seat is a bug. */
  readonly playerOf: (seat: Seat) => PlayerLetter;
  /** The seat of a player a caller named, or none when the table has no such player. */
  readonly seatOf: (player: PlayerLetter) => Option.Option<Seat>;
  readonly nameOf: (seat: Seat) => string;
}

const toLetter = Schema.decodeUnknownOption(PlayerLetter);

const inTableOrder = (seats: ReadonlyArray<Seat>): Assignment => new Map(Arr.zip(seats, Arr.getSomes(Letter.literals.map((letter) => toLetter(letter)))));

/** A roster for the seats of a table. Without an assignment the letters run A, B, ... in the order of the seats. */
export const rosterOf = (seats: ReadonlyArray<Seat>, assignment: Assignment = inTableOrder(seats)): Roster => {
  const seated = Arr.getSomes(seats.map((seat) => Option.fromUndefinedOr(assignment.get(seat)).pipe(Option.map((player) => [player, seat] as const))));

  if (seated.length !== seats.length || new Set(seated.map(([player]) => player)).size !== seats.length) {
    throw new Error("A roster needs every seat at the table to have its own letter.");
  }

  const playerOf = (seat: Seat): PlayerLetter =>
    Arr.findFirst(seated, ([, seatOfPlayer]) => seatOfPlayer === seat).pipe(
      Option.map(([player]) => player),
      Option.getOrThrowWith(() => new Error("A player was asked for a seat that is not at this table.")),
    );

  return {
    players: seated.map(([player]) => player),
    playerOf,
    seatOf: (player) => Arr.findFirst(seated, ([candidate]) => candidate === player).pipe(Option.map(([, seat]) => seat)),
    nameOf: (seat) => playerName(playerOf(seat)),
  };
};
