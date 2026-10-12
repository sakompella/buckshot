import { expect, test } from "bun:test";
import { Option, Predicate, Result } from "effect";

import { answerPrompt } from "../src/bend.ts";
import type { SeatCount } from "../src/domain.ts";
import { begin, botPrompt, botStep, type Controller, type Progress, promptsOf } from "../src/driver.ts";
import { seedRng } from "../src/rng.ts";
import { titles } from "../src/titles.ts";

const MOVE_LIMIT = 5_000;

const playOut = (table: SeatCount, items: boolean, seed: number): Progress => {
  const controllers: ReadonlyArray<Controller> = ["Bot", "Bot", "Bot", "Bot"];
  let progress = Result.getOrThrow(begin(table, items, seed, seedRng(seed)));

  for (let moves = 0; moves < MOVE_LIMIT && progress.game.pending.kind === "Choose"; moves++) {
    const prompt = Option.getOrThrow(botPrompt(progress.game, controllers));

    progress = Result.getOrThrow(botStep(progress, prompt));
  }

  return progress;
};

for (const table of [2, 3, 4] as const) {
  test(`random bots finish a ${table}-seat match`, () => {
    for (let seed = 1; seed <= 5; seed++) {
      const progress = playOut(table, false, seed * 7919 + table);

      expect(progress.game.pending.kind).toBe("Finished");
      expect(progress.events.at(-1)?._tag).toBe("MatchConcluded");
      expect(titles(progress.events, progress.game.seats)).toHaveLength(5);
    }
  });
}

test("an answer for an earlier request point is rejected", () => {
  let progress = Result.getOrThrow(begin(2, false, 1, seedRng(1)));
  const [first] = promptsOf(progress.game);

  if (first === undefined) throw new Error("expected a prompt");

  progress = Result.getOrThrow(botStep(progress, first));

  const stale = answerPrompt(progress.game, first.ticket, first.seat, 0);

  expect(Result.isFailure(stale) && Predicate.isTagged(stale.failure, "StaleAnswer")).toBe(true);
});
