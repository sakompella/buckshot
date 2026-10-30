import { expect, test } from "bun:test";

import { mistakesOf } from "../src/arena-viewer/mistakes.ts";

const regretOf = (matchId: string) => new Map(matchId === "m1" ? [[1, { points: 4 }], [2, { points: 1.234 }]] : []);

test("mistakes join each searched move with its shells left and kind, and skip moves with no regret", () => {
  const decisions = { seat: [0, 0, 0, 1], ord: [1, 2, 3, 1], shot: [1, 0, 2, 1] };
  const mistakes = mistakesOf(decisions, [2, 5, 1, 3], (seat) => (seat === 0 ? "m1" : "m2"), regretOf);

  expect(mistakes).toEqual({ seat: [0, 0], left: [2, 5], isShot: [1, 0], points: [4, 1.23] });
});

