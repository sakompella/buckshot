import { expect, test } from "bun:test";

import { spendOf } from "../src/arena-viewer/page/spend.ts";

const config = (key: string, totalCost: number) => ({ key, model: key, label: key, color: "#fff", totalCost });

test("spend is shared out by cost, biggest first, and leaves out configs that cost nothing", () => {
  const spend = spendOf([config("a", 10), config("free", 0), config("b", 30), config("c", 60)]);

  expect(spend.map(({ key }) => key)).toEqual(["c", "b", "a"]);
  expect(spend.map(({ share }) => share)).toEqual([0.6, 0.3, 0.1]);
});

test("no spend gives no shares", () => {
  expect(spendOf([])).toEqual([]);
  expect(spendOf([config("free", 0)])).toEqual([]);
});
