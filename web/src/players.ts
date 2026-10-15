import { Array as Arr, Option, Schema } from "effect";

import type { Seat } from "./domain.ts";

// What people and agents call a seat: Player 1 to Player N in the table's seat
// order, so a 2-seat table's seats 1 and 3 are Player 1 and Player 2. Bend and
// the driver keep raw seat ids; only a Roster converts between the two.

export const PlayerNumber = Schema.Literals([1, 2, 3, 4]).pipe(Schema.brand("PlayerNumber"));

export type PlayerNumber = typeof PlayerNumber.Type;

export const playerName = (player: PlayerNumber): string => `Player ${player}`;

/** The seats at one table, in table order. */
export interface Roster {
  readonly players: ReadonlyArray<PlayerNumber>;
  /** The player in a seat of this table. Events and boards only name seated seats, so any other seat is a bug. */
  readonly playerOf: (seat: Seat) => PlayerNumber;
  /** The seat of a player number a caller typed, or none when the table has no such player. */
  readonly seatOf: (player: number) => Option.Option<Seat>;
  readonly nameOf: (seat: Seat) => string;
}

const toPlayer = Schema.decodeUnknownOption(PlayerNumber);

export const rosterOf = (seats: ReadonlyArray<Seat>): Roster => {
  const players = Arr.getSomes(seats.map((_, position) => toPlayer(position + 1)));
  const seated = Arr.zip(players, seats);

  const playerOf = (seat: Seat): PlayerNumber =>
    Arr.findFirst(seated, ([, seatOfPlayer]) => seatOfPlayer === seat).pipe(
      Option.map(([player]) => player),
      Option.getOrThrowWith(() => new Error("A player was asked for a seat that is not at this table.")),
    );

  return {
    players,
    playerOf,
    seatOf: (player) => Arr.findFirst(seated, ([candidate]) => candidate === player).pipe(Option.map(([, seat]) => seat)),
    nameOf: (seat) => playerName(playerOf(seat)),
  };
};
