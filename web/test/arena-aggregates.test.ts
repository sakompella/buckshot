import * as hegel from "@hegeldev/hegel";
import * as gs from "@hegeldev/hegel/generators";
import { expect, test } from "bun:test";

import { configSummaries, pairsOf } from "../src/arena-viewer/aggregates.ts";
import type { Seat } from "../src/arena-viewer/api.ts";
import { baseName, keyOf, sumOf, withPotShares } from "../src/arena-viewer/page/data.ts";
import { derive } from "../src/arena-viewer/page/derived.ts";

const SEAT: Seat = {
  tournament: "t",
  matchId: "",
  matchName: "",
  status: "completed",
  startedAt: "",
  seed: 1,
  seedBlock: "",
  codeHash: "",
  model: "",
  effort: "medium",
  player: "A",
  position: 0,
  winShare: 1,
  cash: 0,
  cost: 0,
  inp: 0,
  outp: 0,
  cr: 0,
  cw: 0,
  rt: 0,
  lat: 0,
  rsHidden: 0,
  rsText: 0,
  multiTool: 0,
  moves: 0,
  acquired: [],
  used: [],
  stolen: [],
  regret: null,
  story: null,
  round: 0,
  roundThree: null,
  deficits: [],
};

const MODELS = ["claude-opus-5-5", "gpt-6-luna", "claude-haiku-5-5"];

const EFFORTS = ["low", "medium", "high"];

const configGen = gs.tuples(gs.sampledFrom(MODELS), gs.sampledFrom(EFFORTS));

const matchGen = gs.tuples(configGen, configGen, gs.booleans(), gs.booleans(), gs.sampledFrom(["A", "B"]), gs.integers({ minValue: 0, maxValue: 5 }));

// The page used to count the hero's and the seat balance's matches over the seats of every match with a kept seat; it
// now sums the per-pair aggregates of the pairs with a kept config. Both must give the same numbers under any filter.
test("the kept pairs' sums equal the counts over the matches with a kept seat, under any filter", () =>
  hegel.test((tc) => {
    const played = tc.draw(gs.arrays(matchGen, { minSize: 1, maxSize: 30 }));

    const seats = withPotShares(
      played.flatMap(([[aModel, aEffort], [bModel, bEffort], aWins, isScored, starter, block], index) => {
        const story = { starter, ok: true, rounds: [{ winner: aWins ? "A" : "B", prize: 1, inferred: false }] };

        const seat = (model: string, effort: string, player: string, position: number, isWinner: boolean): Seat => ({
          ...SEAT,
          matchId: `m${index}`,
          seedBlock: `block${block}`,
          status: isScored ? "completed" : "partial",
          model,
          effort,
          player,
          position,
          winShare: isWinner ? 1 : 0,
          story,
        });

        return [seat(aModel, aEffort, "A", 0, aWins), seat(bModel, bEffort, "B", 1, !aWins)];
      }),
    );

    const offModels = tc.draw(gs.arrays(gs.sampledFrom(MODELS.map(baseName)), { maxSize: 2, unique: true }));
    const offEfforts = tc.draw(gs.arrays(gs.sampledFrom(EFFORTS), { maxSize: 2, unique: true }));
    const isKept = (seat: Seat) => !offModels.includes(baseName(seat.model)) && !offEfforts.includes(seat.effort);
    const { pairs, kept } = derive({ summary: { configs: configSummaries(seats, { seat: [], legalUse: [], useItem: [] }), hasCertain: false }, pairs: pairsOf(seats) }, { offModels, offEfforts });

    const scoredWithKept = played.flatMap((_match, index) => {
      const both = seats.filter(({ matchId }) => matchId === `m${index}`);

      return both.some(isKept) && both.every(({ status }) => status === "completed") ? [both] : [];
    });

    expect(kept).toEqual(new Set(seats.filter(isKept).map(keyOf)));
    expect(sumOf(pairs.map(({ scored }) => scored))).toBe(scoredWithKept.length);
    expect(sumOf(pairs.map(({ firstWins }) => firstWins))).toBe(sumOf(scoredWithKept.map(([first]) => first?.winShare ?? 0)));
    expect(sumOf(pairs.map(({ starts }) => starts))).toBe(scoredWithKept.length);
    expect(sumOf(pairs.map(({ starterWins }) => starterWins))).toBe(sumOf(scoredWithKept.map((both) => both.find(({ player }) => player === both[0]?.story?.starter)?.winShare ?? 0)));
  }));
