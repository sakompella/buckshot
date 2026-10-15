import { expect, test } from "bun:test";
import { Option, Result } from "effect";

import { boardMoves, targetKey, targetOf } from "../src/board.ts";
import { rosterOf } from "../src/players.ts";
import { type Move, type SeatCount } from "../src/domain.ts";
import { aiPrompt, aiStep, begin, type Controller, promptsOf } from "../src/driver.ts";
import { seedRng } from "../src/rng.ts";

const MOVE_LIMIT = 5_000;

// Twelve full bot matches: seconds of work, more on a loaded machine.

const BOTS: ReadonlyArray<Controller> = ["DoN", "Story", "DoN", "Story"];

const ALL_KINDS: ReadonlyArray<Move["_tag"]> = ["PickUp", "Shoot", "UseItem", "Grab", "Place", "JamTarget", "Steal"];

test("at every prompt of bot matches, each legal move is on the table exactly once, and every kind of move shows up", () => {
  const seen = new Set<Move["_tag"]>();

  for (const table of [2, 3, 4] satisfies ReadonlyArray<SeatCount>) {
    for (let seed = 1; seed <= 4; seed++) {
      let progress = Result.getOrThrow(begin(table, true, seed, seedRng(seed * 31 + table), BOTS, seed));
      const roster = rosterOf(progress.game.seats);

      for (let moves = 0; moves < MOVE_LIMIT && progress.game.pending.kind === "Choose"; moves++) {
        for (const prompt of promptsOf(progress.game)) {
          const { onTable, buttons } = boardMoves(roster, prompt);
          const offered = [...onTable.values(), ...buttons].map(({ index }) => index).toSorted((left, right) => left - right);

          expect(offered).toEqual(prompt.menu.map((_, index) => index));
          expect(buttons).toEqual([]);

          for (const [key, { index }] of onTable) {
            const move = prompt.menu[index];

            expect(move === undefined ? undefined : targetKey(targetOf(prompt.seat, move))).toBe(key);
          }

          for (const move of prompt.menu) seen.add(move._tag);
        }

        progress = Result.getOrThrow(aiStep(progress, Option.getOrThrow(aiPrompt(progress.game, BOTS))));
      }

      expect(progress.game.pending.kind).toBe("Finished");
    }
  }

  expect([...seen].toSorted()).toEqual([...ALL_KINDS].toSorted());
}, 30_000);
