import { expect, test } from "bun:test";

import type { Blunders } from "../src/arena-viewer/api.ts";
import { blunderRates, galleryOf } from "../src/arena-viewer/page/blunders.ts";

const seat = (matchId: string, player: string, model: string, regretMoves: number | null) => ({ matchId, player, model, effort: "medium", seedBlock: matchId, regret: regretMoves === null ? null : { moves: regretMoves, total: 0, exact: 0 } });

const blunders = (...moves: ReadonlyArray<readonly [number, number, number, boolean]>): Blunders => ({
  labels: ["Shoot yourself", "Shoot Player B"],
  seat: moves.map(([at]) => at),
  ord: moves.map(([, ordinal]) => ordinal),
  points: moves.map(([, , points]) => points),
  exact: moves.map(([, , , isExact]) => (isExact ? 1 : 0)),
  chosen: moves.map(() => 0),
  best: moves.map(() => 1),
  bestScore: moves.map(() => 60),
  chosenScore: moves.map(() => 10),
});

test("a config's blunder rate is its blunders over its searched moves, from kept seats, lowest first", () => {
  const seats = [seat("m1", "A", "claude-opus-5-5", 40), seat("m1", "B", "gpt-6-luna", 50), seat("m2", "A", "claude-opus-5-5", 60), seat("m2", "B", "gpt-6-luna", null), seat("m3", "A", "gpt-6-luna", 10)];
  const found = blunders([0, 1, 20, false], [0, 2, 12, false], [1, 1, 15, false], [2, 3, 30, true], [4, 1, 11, false]);
  const rates = blunderRates(seats, [true, true, true, true, false], found);

  expect(rates.map(({ key, rate }) => [key, rate.k, rate.n])).toEqual([
    ["gpt-6-luna|medium", 1, 50],
    ["claude-opus-5-5|medium", 3, 100],
  ]);
});

test("the gallery takes proven exact blunders first, then the costliest, at most one per config and per match, and ties go to the stronger config", () => {
  const seats = [seat("m1", "A", "weak", 5), seat("m1", "B", "strong", 5), seat("m2", "A", "weak", 5), seat("m2", "B", "strong", 5), seat("m3", "A", "weak", 5), seat("m4", "A", "dropped", 5)];
  const ratings = new Map([["weak|medium", { rating: -50 }], ["strong|medium", { rating: 80 }], ["dropped|medium", { rating: 500 }]]);
  const found = blunders([0, 1, 100, true], [1, 2, 100, true], [2, 3, 100, true], [3, 4, 99, false], [4, 5, 99.9, false], [5, 6, 100, true]);
  const cards = galleryOf(seats, [true, true, true, true, true, false], ratings, found, 3);

  expect(cards.map(({ seat: { matchId, player }, ordinal }) => `${matchId}${player}${ordinal}`)).toEqual(["m1B2", "m2A3"]);
  expect(cards.map(({ opponent }) => opponent?.player)).toEqual(["A", "B"]);
});
