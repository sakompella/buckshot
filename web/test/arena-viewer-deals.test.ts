import { expect, test } from "bun:test";

import { type DealMatch, dealsOf } from "../src/arena-viewer/page/deals.ts";

const seat = (model: string, winShare: number, codeHash = "a") => ({ model, effort: "medium", winShare, codeHash });

const match = (seed: number, first: ReturnType<typeof seat>, second: ReturnType<typeof seat>, status = "completed"): DealMatch => ({
  seed,
  startedAt: "2026-10-01T00:00:00Z",
  status,
  seats: [first, second],
});

/** Every pairing of three models from both table positions on one seed, position 1 winning when `firstWins`. */
const roundRobin = (seed: number, firstWins: boolean, codeHash = "a"): ReadonlyArray<DealMatch> =>
  ["x", "y", "z"].flatMap((one) =>
    ["x", "y", "z"].flatMap((two) => (one === two ? [] : [match(seed, seat(one, firstWins ? 1 : 0, codeHash), seat(two, firstWins ? 0 : 1, codeHash))])),
  );

test("a deal splits each config's wins by table position", () => {
  const [deal] = dealsOf([...roundRobin(1, true), ...roundRobin(1, true), ...roundRobin(1, true)]);
  const x = deal?.cells.get("x|medium");

  expect(deal?.games).toBe(18);
  expect(x?.first).toEqual({ wins: 6, games: 6 });
  expect(x?.second).toEqual({ wins: 0, games: 6 });
  expect(deal?.firstShare).toBe(1);
});

test("deals run from the seed that favours position 1 the most, and each deal's cells sum to its matches", () => {
  const matches = [...roundRobin(1, false), ...roundRobin(2, true), ...roundRobin(2, true), ...roundRobin(3, true), ...roundRobin(3, false), ...roundRobin(3, false), ...roundRobin(3, true)];
  const deals = dealsOf(matches);

  expect(deals.map(({ seed }) => seed)).toEqual([2, 3, 1]);

  for (const deal of deals) {
    const seated = [...deal.cells.values()].reduce((total, { first, second }) => total + first.games + second.games, 0);

    expect(seated).toBe(2 * deal.games);
  }
});

test("seeds with few matches per config, unscored matches and other code versions do not make a deal", () => {
  const few = roundRobin(1, true).slice(0, 3);
  const unscored = roundRobin(2, true).map((played) => ({ ...played, status: "partial" }));
  const split = [...roundRobin(3, true).slice(0, 4), ...roundRobin(3, true, "b").slice(0, 4)];

  expect(dealsOf([...few, ...unscored, ...split])).toEqual([]);
});
