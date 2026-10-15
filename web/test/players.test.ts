import { expect, test } from "bun:test";
import { Array as Arr, Option, Result } from "effect";

import { startGame } from "../src/bend.ts";
import { SEATS_BY_TABLE, SeatCount } from "../src/domain.ts";
import { rosterOf } from "../src/players.ts";

const OUT_OF_RANGE = [0, -1, 1.5, Number.NaN, 5, 100];

test("at 2, 3 and 4 seats the players are exactly Player 1 to Player N in table order, and a number and its seat round-trip", () => {
  for (const table of SeatCount.literals) {
    const roster = rosterOf(SEATS_BY_TABLE[table]);
    const numbers = Arr.range(1, table);

    expect(SEATS_BY_TABLE[table].map(roster.nameOf)).toEqual(numbers.map((number) => `Player ${number}`));

    for (const seat of SEATS_BY_TABLE[table]) expect(roster.seatOf(roster.playerOf(seat))).toEqual(Option.some(seat));

    for (const player of roster.players) expect(roster.seatOf(player).pipe(Option.map(roster.playerOf))).toEqual(Option.some(player));

    for (const player of [...OUT_OF_RANGE, table + 1]) expect(Option.isNone(roster.seatOf(player))).toBe(true);
  }
});

test("the seats Bend deals are the seats the roster is built from", () => {
  for (const table of SeatCount.literals) {
    const { game } = Result.getOrThrow(startGame(table, false, 1));

    expect(game.seats).toEqual(SEATS_BY_TABLE[table]);
  }
});
