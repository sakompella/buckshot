import { expect, test } from "bun:test";
import { Option, Result } from "effect";

import { startGame } from "../src/bend.ts";
import { type Assignment, Letter, type Player, rosterOf } from "../src/players.ts";
import { SEATS_BY_TABLE, SeatCount } from "../src/domain.ts";

const EVERY_LETTER = Letter.literals;

/** Every way to give `count` seats distinct letters. */
const arrangements = (letters: ReadonlyArray<Letter>, count: number): ReadonlyArray<ReadonlyArray<Letter>> =>
  count === 0 ? [[]] : letters.flatMap((letter) => arrangements(letters.filter((other) => other !== letter), count - 1).map((rest) => [letter, ...rest]));

test("at 2, 3 and 4 seats the players are exactly Player A to Player N in table order, and a letter and its seat round-trip", () => {
  for (const table of SeatCount.literals) {
    const seats = SEATS_BY_TABLE[table];
    const roster = rosterOf(seats);

    expect(seats.map(roster.nameOf)).toEqual(["Player A", "Player B", "Player C", "Player D"].slice(0, table));

    for (const seat of seats) expect(roster.find(roster.playerOf(seat).letter)).toEqual(Option.some(roster.playerOf(seat)));

    for (const { letter, seat } of roster.players) expect(roster.find(letter).pipe(Option.map((player) => player.seat))).toEqual(Option.some(seat));

    for (const letter of EVERY_LETTER.slice(table)) expect(roster.find(letter)).toEqual(Option.none());
  }
});

test("an explicit assignment names every seat as given, whichever seats the letters sit in, and the mapping round-trips", () => {
  for (const table of SeatCount.literals) {
    const seats = SEATS_BY_TABLE[table];

    for (const letters of arrangements(EVERY_LETTER, table)) {
      const assignment: Assignment = new Map(seats.map((seat, position) => [seat, letters[position] ?? expect.unreachable("a letter for every seat")]));
      const roster = rosterOf(seats, assignment);

      expect(roster.players.map(({ letter }) => letter)).toEqual([...letters]);
      expect(seats.map(roster.nameOf)).toEqual(letters.map((letter) => `Player ${letter}`));

      for (const seat of seats) expect(roster.find(roster.playerOf(seat).letter)).toEqual(Option.some(roster.playerOf(seat)));

      for (const { letter, seat } of roster.players) expect(roster.find(letter).pipe(Option.map((player) => player.seat))).toEqual(Option.some(seat));

      for (const letter of EVERY_LETTER.filter((candidate) => !letters.includes(candidate))) expect(roster.find(letter)).toEqual(Option.none());
    }
  }
});

test("an assignment that leaves a seat without a letter, or gives two seats one letter, is refused", () => {
  const [first, second] = SEATS_BY_TABLE[2];
  const a = "A" satisfies Letter;

  if (first === undefined || second === undefined) return expect.unreachable("a 2-seat table has two seats");

  expect(() => rosterOf(SEATS_BY_TABLE[2], new Map([[first, a]]))).toThrow();
  expect(() => rosterOf(SEATS_BY_TABLE[2], new Map([[first, a], [second, a]]))).toThrow();
});

test("the seats Bend deals are the seats the roster is built from", () => {
  for (const table of SeatCount.literals) {
    const { game } = Result.getOrThrow(startGame(table, false, 1));

    expect(game.seats).toEqual(SEATS_BY_TABLE[table]);
  }
});

test("a player found by a letter keeps that letter in its type", () => {
  const roster = rosterOf(SEATS_BY_TABLE[2]);
  const a: Option.Option<Player<"A">> = roster.find("A");

  // @ts-expect-error a Player<"A"> must not be assignable to a Player<"B">
  const asB: Option.Option<Player<"B">> = a;

  expect(Option.map(asB, ({ letter }) => letter)).toEqual(Option.some("A"));
});
