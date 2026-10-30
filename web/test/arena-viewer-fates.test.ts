import { expect, test } from "bun:test";

import { rng } from "../src/arena-viewer/page/data.ts";
import { behaviorBySeat, seatFates, sumFates } from "../src/arena-viewer/page/fates.ts";

test("a seat's fates read the stolen copies from its opponent and add up to what it received", () => {
  for (let seed = 1; seed <= 20; seed++) {
    const random = rng(seed);
    const counts = (cap: number) => Array.from({ length: 8 }, () => Math.floor(random() * (cap + 1)));
    const acquired = counts(6);
    const used = acquired.map((count) => Math.floor(random() * (count + 1)));
    const stolen = acquired.map((count, item) => Math.floor(random() * (count - (used[item] ?? 0) + 1)));
    const fates = seatFates({ acquired, used }, { stolen });
    const total = sumFates(fates);

    expect(total.used + total.stolen + total.unused).toBe(acquired.reduce((sum, count) => sum + count, 0));
    expect(fates.every(({ unused }) => unused >= 0)).toBe(true);
    expect(fates.map((fate) => fate.stolen)).toEqual(stolen);
  }
});

test("a seat's own steals do not count as its items stolen", () => {
  const own = { acquired: [3, 0], used: [1, 0], stolen: [0, 2] };
  const opponent = { acquired: [0, 4], used: [0, 1], stolen: [1, 0] };

  expect(seatFates(own, opponent)).toEqual([
    { used: 1, stolen: 1, unused: 1 },
    { used: 0, stolen: 0, unused: 0 },
  ]);
});

test("item use is counted over the moves with an item available, and item actions over all moves", () => {
  const decisions = {
    seat: [0, 0, 0, 1],
    legalUse: [0b1, 0b1, 0, 0b10],
    useItem: [0, -1, -1, 1],
  };

  expect(behaviorBySeat(decisions, 3)).toEqual([
    { moves: 3, available: 2, usedWhenAvailable: 1, itemActions: 1 },
    { moves: 1, available: 1, usedWhenAvailable: 1, itemActions: 1 },
    { moves: 0, available: 0, usedWhenAvailable: 0, itemActions: 0 },
  ]);
});
