import { expect, test } from "bun:test";

import { costPerMove } from "../src/arena-viewer/page/data.ts";
import { perMoveOf } from "../src/arena-viewer/page/spend.ts";

const config = (key: string, scoredCost: number, scoredMoves: number) => ({ key, model: key, effort: "medium", color: "#fff", scoredCost, scoredMoves });

test("a config with no move has no cost per move", () => {
  expect(costPerMove({ scoredCost: 0, scoredMoves: 0 })).toBeNull();
  expect(costPerMove({ scoredCost: 10, scoredMoves: 40 })).toBe(0.25);
});

test("the cost-per-move chart leaves off configs with no cost per move and configs that cost nothing", () => {
  expect(perMoveOf([config("free", 0, 10), config("none", 0, 0), config("paid", 2, 4)]).map(({ key, cost }) => [key, cost])).toEqual([["paid", 0.5]]);
});
