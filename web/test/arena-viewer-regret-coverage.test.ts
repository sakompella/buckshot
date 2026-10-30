import { expect, test } from "bun:test";

import { regretCoverageOf } from "../scripts/arena-viewer-regret-coverage.ts";

const move = (byWhom: "agent" | "forced", points: number | null) => ({ byWhom, regret: points === null ? null : { points } });

test("a match the derived database has not reached expects no regret on its replay", () => {
  expect(regretCoverageOf([move("agent", null), move("agent", null)])).toEqual({ searched: 0, tagged: 0, rings: 0, turning: 0 });
});

test("tags start at 2 points, rings and turning points at 5, at most 3 turning points, and forced moves are not listed", () => {
  const moves = [move("agent", 1.9), move("agent", 2), move("agent", 5), move("agent", 7), move("agent", 9), move("agent", 30), move("forced", 40), move("agent", null)];

  expect(regretCoverageOf(moves)).toEqual({ searched: 6, tagged: 5, rings: 4, turning: 3 });
});
