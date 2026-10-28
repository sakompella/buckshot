import { expect, test } from "bun:test";

import type { Story } from "../src/arena-viewer/api.ts";
import { type RubberSeat, rubberRows, stakeOfRoundThree } from "../src/arena-viewer/page/rubbers.ts";

const roundsWonBy = (...winners: ReadonlyArray<string>): Story => ({ starter: "A", ok: true, rounds: winners.map((winner) => ({ winner, prize: 1, inferred: false })) });

test("round 3 is level after one round each, and decided for both players after two wins", () => {
  expect(stakeOfRoundThree({ story: roundsWonBy("A", "B", "A") })).toBe("level");
  expect(stakeOfRoundThree({ story: roundsWonBy("B", "A", "B") })).toBe("level");
  expect(stakeOfRoundThree({ story: roundsWonBy("A", "A", "B") })).toBe("decided");
});

test("a match without a known round 3 has no stake", () => {
  expect(stakeOfRoundThree({ story: roundsWonBy("A", "A") })).toBeNull();
  expect(stakeOfRoundThree({ story: { starter: "A", ok: false, rounds: roundsWonBy("A", "A", "A").rounds } })).toBeNull();
  expect(stakeOfRoundThree({ story: null })).toBeNull();
});

test("output tokens per round 3 move are pooled by stake, and thin configs are left out", () => {
  const seat = (matchId: string, model: string, story: Story, round3: readonly [number, number]): RubberSeat => ({ seedBlock: matchId, model, effort: "medium", story, roundThree: round3 });

  const rows = rubberRows([
    ...Array.from({ length: 20 }, (_, index) => seat(`l${index}`, "wide", roundsWonBy("A", "B", "A"), [10, 1000])),
    ...Array.from({ length: 10 }, (_, index) => seat(`a${index}`, "wide", roundsWonBy("A", "A", "A"), [10, 500])),
    ...Array.from({ length: 10 }, (_, index) => seat(`b${index}`, "wide", roundsWonBy("B", "B", "B"), [10, 250])),
    seat("thin", "thin", roundsWonBy("A", "A", "A"), [10, 1]),
  ]);

  expect(rows.map(({ key }) => key)).toEqual(["wide|medium"]);
  expect(rows[0]?.level.rate).toBe(100);
  expect(rows[0]?.decided.rate).toBe(37.5);
});
