import { expect, test } from "bun:test";

import { mistakesOf } from "../src/arena-viewer/mistakes.ts";
import { shellLines } from "../src/arena-viewer/page/mistakes.ts";

const regretOf = (matchId: string) => new Map(matchId === "m1" ? [[1, { points: 4 }], [2, { points: 1.234 }]] : []);

test("mistakes join each searched move with its shells left and kind, and skip moves with no regret", () => {
  const decisions = { seat: [0, 0, 0, 1], ord: [1, 2, 3, 1], shot: [1, 0, 2, 1] };
  const mistakes = mistakesOf(decisions, [2, 5, 1, 3], (seat) => (seat === 0 ? "m1" : "m2"), regretOf);

  expect(mistakes).toEqual({ seat: [0, 0], left: [2, 5], isShot: [1, 0], points: [4, 1.23] });
});

test("shell lines average regret per model, split by shots, and drop thin points and filtered seats", () => {
  const seats = [{ model: "claude-opus" }, { model: "claude-opus" }, { model: "gpt-sol" }];
  const many = 40;

  const mistakes = {
    seat: [...Array<number>(many).fill(0), ...Array<number>(many).fill(1), ...Array<number>(many).fill(2), 0],
    left: [...Array<number>(many).fill(2), ...Array<number>(many).fill(2), ...Array<number>(many).fill(1), 6],
    isShot: [...Array<number>(3 * many).fill(1), 1],
    points: [...Array<number>(many).fill(2), ...Array<number>(many).fill(4), ...Array<number>(many).fill(9), 100],
  };

  const [opus] = shellLines(mistakes, seats, [true, true, false], true);

  expect(shellLines(mistakes, seats, [true, true, false], true)).toHaveLength(1);
  expect(opus?.points).toEqual([{ left: 2, moves: 2 * many, mean: 3 }]);
  expect(shellLines(mistakes, seats, [true, true, true], false)).toEqual([]);
});
