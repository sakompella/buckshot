import { expect, test } from "bun:test";

import { gameAccuracy, moveAccuracy } from "../src/arena-viewer/accuracy.ts";

test("a move that gave up nothing is 100 and the loss of a whole round is 0, falling between along lichess's curve", () => {
  expect(moveAccuracy(60, 60)).toBe(100);
  expect(moveAccuracy(60, 70)).toBe(100);
  expect(moveAccuracy(100, 0)).toBe(0);
  expect(moveAccuracy(60, 50)).toBeCloseTo(64.58, 1);
  expect(moveAccuracy(60, 55)).toBeGreaterThan(moveAccuracy(60, 50));
});

test("a game's accuracy is a mean of the weighted and harmonic means, so it stays between its worst and best move", () => {
  const moves = [{ before: 50, after: 50 }, { before: 60, after: 30 }, { before: 40, after: 38 }, { before: 70, after: 70 }];
  const accuracies = moves.map(({ before, after }) => moveAccuracy(before, after));
  const game = gameAccuracy(moves) ?? Number.NaN;

  expect(game).toBeGreaterThan(Math.min(...accuracies));
  expect(game).toBeLessThan(Math.max(...accuracies));
  expect(gameAccuracy(moves.map(({ before }) => ({ before, after: before })))).toBe(100);
  expect(gameAccuracy([])).toBeNull();
});

test("a one-move game has the accuracy of its move", () => {
  expect(gameAccuracy([{ before: 60, after: 50 }])).toBeCloseTo(moveAccuracy(60, 50), 10);
});
