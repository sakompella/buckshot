import * as hegel from "@hegeldev/hegel";
import * as gs from "@hegeldev/hegel/generators";
import { expect, test } from "bun:test";

import { itemsOf } from "../src/arena-viewer/analysis.ts";
import { behaviorBySeat, seatFates, sumFates } from "../src/arena-viewer/aggregates.ts";
import { useShare } from "../src/arena-viewer/page/fates.ts";
import { GameEvent } from "../src/domain.ts";
import { rosterOf } from "../src/players.ts";

const counts = (tc: hegel.TestCase) => Array.from({ length: 8 }, () => tc.draw(gs.integers({ minValue: 0, maxValue: 6 })));

test("a seat's fates read the stolen copies from its opponent and add up to what it received", () =>
  hegel.test((tc) => {
    const acquired = counts(tc);
    const used = acquired.map((count) => tc.draw(gs.integers({ minValue: 0, maxValue: count })));
    const stolen = acquired.map((count, item) => tc.draw(gs.integers({ minValue: 0, maxValue: count - (used[item] ?? 0) })));
    const fates = seatFates({ matchId: "m", player: "A", acquired, used }, { stolen });
    const total = sumFates(fates);

    expect(total.used + total.stolen + total.unused).toBe(acquired.reduce((sum, count) => sum + count, 0));
    expect(fates.every(({ unused }) => unused >= 0)).toBe(true);
    expect(fates.map((fate) => fate.stolen)).toEqual(stolen);
  }));

test("a seat's own steals do not count as its items stolen", () => {
  const own = { matchId: "m", player: "A", acquired: [3, 0], used: [1, 0], stolen: [0, 2] };
  const opponent = { acquired: [0, 4], used: [0, 1], stolen: [1, 0] };

  expect(seatFates(own, opponent)).toEqual([
    { used: 1, stolen: 1, unused: 1 },
    { used: 0, stolen: 0, unused: 0 },
  ]);
});

test("a seat's items come from every public placement and use, a steal counting for the seat that took the item", () => {
  const events: ReadonlyArray<GameEvent> = [
    GameEvent.cases.Placed.make({ seat: 0, slot: 0, item: "Beer" }),
    GameEvent.cases.Placed.make({ seat: 1, slot: 0, item: "Beer" }),
    GameEvent.cases.Granted.make({ seat: 0, item: "Saw" }),
    GameEvent.cases.Placed.make({ seat: 1, slot: 1, item: "Saw" }),
    GameEvent.cases.Used.make({ seat: 0, owner: 0, slot: 0, item: "Adrenaline" }),
    GameEvent.cases.Used.make({ seat: 0, owner: 1, slot: 1, item: "Saw" }),
    GameEvent.cases.Used.make({ seat: 1, owner: 1, slot: 0, item: "Beer" }),
  ];

  const items = itemsOf({ events, roster: rosterOf([0, 1]) });

  expect(items.get("A")).toEqual({ acquired: [0, 0, 0, 1, 0, 0, 0, 0], used: [0, 0, 0, 0, 0, 0, 0, 1], stolen: [0, 0, 1, 0, 0, 0, 0, 0] });
  expect(items.get("B")).toEqual({ acquired: [0, 0, 1, 1, 0, 0, 0, 0], used: [0, 0, 0, 1, 0, 0, 0, 0], stolen: [0, 0, 0, 0, 0, 0, 0, 0] });
});

test("more copies used and stolen than received stops with the match and counts", () => {
  expect(() => seatFates({ matchId: "m1", player: "B", acquired: [3], used: [2] }, { stolen: [2] })).toThrow("match m1 Player B: magnifying glass acquired 3, used 2, stolen 2");
});

const ADRENALINE_BIT = 1 << 7;
const JAMMER_BIT = 1 << 6;

test("an adrenaline-only or jammer-only option makes an item available, and a steal counts as an adrenaline use", () => {
  const decisions = {
    seat: [0, 0, 0],
    legalUse: [ADRENALINE_BIT, JAMMER_BIT, ADRENALINE_BIT | 0b1],
    useItem: [7, -1, -1],
  };

  expect(behaviorBySeat(decisions, 1)).toEqual([{ moves: 3, available: 3, usedWhenAvailable: 1, itemActions: 1 }]);
});

test("a seat without moves, or whose moves never had an item available, has no use share", () => {
  const [unseen, noItems] = behaviorBySeat({ seat: [1, 1], legalUse: [0, 0], useItem: [-1, -1] }, 2);

  expect(unseen && useShare(unseen)).toBeNull();
  expect(noItems && useShare(noItems)).toBeNull();
  expect(useShare({ moves: 4, available: 2, usedWhenAvailable: 1, itemActions: 1 })).toBe(0.5);
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
