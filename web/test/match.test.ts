import { expect, test } from "bun:test";
import { Option, Predicate, Result } from "effect";

import { answerPrompt } from "../src/bend.ts";
import { type SeatCount } from "../src/domain.ts";
import { aiPrompt, aiStep, begin, type Controller, type Progress, promptsOf } from "../src/driver.ts";
import { seedRng } from "../src/rng.ts";
import { titles } from "../src/titles.ts";

const MOVE_LIMIT = 5_000;

const MIXED: ReadonlyArray<Controller> = ["DoN", "Story", "DoN", "Story"];

const playOut = (table: SeatCount, items: boolean, seed: number, controllers: ReadonlyArray<Controller>): Progress => {
  let progress = Result.getOrThrow(begin(table, items, seed, seedRng(seed), controllers, seed));

  for (let moves = 0; moves < MOVE_LIMIT && progress.game.pending.kind === "Choose"; moves++) {
    const prompt = Option.getOrThrow(aiPrompt(progress.game, controllers));

    progress = Result.getOrThrow(aiStep(progress, prompt));
  }

  return progress;
};

for (const table of [2, 3, 4] as const) {
  for (const items of [false, true]) {
    test(`Story and DoN finish a ${table}-seat match, items ${items ? "on" : "off"}`, () => {
      for (let seed = 1; seed <= 3; seed++) {
        const progress = playOut(table, items, seed * 7919 + table, MIXED);

        expect(progress.game.pending.kind).toBe("Finished");
        expect(progress.events.at(-1)?._tag).toBe("MatchConcluded");
        expect(titles(progress.events, progress.game.seats)).toHaveLength(5);
      }
    });
  }
}

test("an AI match with items is reproducible from its seed", () => {
  const first = playOut(3, true, 42, MIXED);
  const second = playOut(3, true, 42, MIXED);

  expect(second.events).toEqual(first.events);
});

test("items are used when they are on", () => {
  const used = [1, 2, 3].flatMap((seed) => playOut(2, true, seed, MIXED).events).filter(Predicate.isTagged("Used"));

  expect(used.length).toBeGreaterThan(0);
});

test("an answer for an earlier request point is rejected", () => {
  let progress = Result.getOrThrow(begin(2, false, 1, seedRng(1), MIXED, 1));
  const [first] = promptsOf(progress.game);

  if (first === undefined) throw new Error("expected a prompt");

  progress = Result.getOrThrow(aiStep(progress, first));

  const stale = answerPrompt(progress.game, first.ticket, first.seat, 0);

  expect(Result.isFailure(stale) && Predicate.isTagged(stale.failure, "StaleAnswer")).toBe(true);
});
