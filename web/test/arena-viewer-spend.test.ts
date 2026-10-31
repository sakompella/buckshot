import { expect, test } from "bun:test";

import { costPerMove } from "../src/arena-viewer/page/data.ts";
import { perMoveOf } from "../src/arena-viewer/page/spend.ts";

const seat = (cost: number | null, moves: number | null) => ({ cost, moves });

const config = (key: string, scored: ReadonlyArray<ReturnType<typeof seat>>) => ({ key, model: key, effort: "medium", color: "#fff", scored });

test("cost per move is the cost over the moves of every scored match, not a mean of per-match ratios", () => {
  expect(costPerMove({ scored: [seat(1, 10), seat(9, 30)] })).toBe(0.25);
});

test("a config with no move or no cost has no cost per move", () => {
  expect(costPerMove({ scored: [] })).toBeNull();
  expect(costPerMove({ scored: [seat(1, 0), seat(null, null)] })).toBeNull();
  expect(perMoveOf([config("free", [seat(0, 10)]), config("none", [seat(null, null)]), config("paid", [seat(2, 4)])]).map(({ key, cost }) => [key, cost])).toEqual([["paid", 0.5]]);
});
