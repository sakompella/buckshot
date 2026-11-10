import * as hegel from "@hegeldev/hegel";
import * as gs from "@hegeldev/hegel/generators";
import { expect, test } from "bun:test";

import { configSummaries, pairsOf } from "../src/arena-viewer/aggregates.ts";
import type { Seat } from "../src/arena-viewer/api.ts";
import { baseName, keyOf, sumOf, withPotShares } from "../src/arena-viewer/page/data.ts";
import { derive } from "../src/arena-viewer/page/derived.ts";
import { SEAT } from "./fixtures.ts";

const MODELS = ["claude-opus-5-5", "gpt-6-luna", "claude-haiku-5-5"];

const EFFORTS = ["low", "medium", "high"];

const configGen = gs.tuples(gs.sampledFrom(MODELS), gs.sampledFrom(EFFORTS));

const matchGen = gs.tuples(configGen, configGen, gs.booleans(), gs.booleans(), gs.integers({ minValue: 0, maxValue: 5 }));

// The page used to count the hero's matches over the seats of every match with a kept seat; it
// now sums the per-pair aggregates of the pairs with a kept config. Both must give the same numbers under any filter.
test("the kept pairs' sums equal the counts over the matches with a kept seat, under any filter", () =>
  hegel.test((tc) => {
    const played = tc.draw(gs.arrays(matchGen, { minSize: 1, maxSize: 30 }));

    const seats = withPotShares(
      played.flatMap(([[aModel, aEffort], [bModel, bEffort], aWins, isScored, block], index) => {
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
  }));
