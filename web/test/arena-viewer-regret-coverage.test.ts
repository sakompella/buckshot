import { expect, test } from "bun:test";

import { coverageOfMatch, type Decision, regretCoverageOf } from "../scripts/arena-viewer-regret-coverage.ts";

const move = (byWhom: "agent" | "forced", points: number | null): Decision => ({ byWhom, regret: points === null ? null : { points } });

const UNCOVERED = [move("agent", null), move("agent", null)];

const COVERED = [move("agent", 1.9), move("agent", 2), move("agent", 5), move("agent", 7), move("agent", 9), move("agent", 30), move("forced", 40), move("agent", null)];

test("a match the derived database has not reached expects no regret on its replay", () => {
  expect(regretCoverageOf(UNCOVERED)).toEqual({ searched: 0, tagged: 0, rings: 0, turning: 0 });
});

test("tags start at 2 points, rings and turning points at 5, at most 3 turning points, and forced moves are not listed", () => {
  expect(regretCoverageOf(COVERED)).toEqual({ searched: 6, tagged: 5, rings: 4, turning: 3 });
  expect(regretCoverageOf([move("agent", 4.9), move("agent", 5)]).turning).toBe(1);
});

test("the opened replay's coverage comes from its own match, whatever other matches the page has loaded or fetched", async () => {
  const fetched: Array<string> = [];

  const decisionsOf = (id: string) => {
    fetched.push(id);

    return Promise.resolve(id === "covered" ? COVERED : UNCOVERED);
  };

  expect((await coverageOfMatch("covered", decisionsOf)).turning).toBe(3);
  expect((await coverageOfMatch("uncovered", decisionsOf)).searched).toBe(0);
  expect(fetched).toEqual(["covered", "uncovered"]);
});
