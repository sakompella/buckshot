import { expect, test } from "bun:test";
import * as hegel from "@hegeldev/hegel";
import * as gs from "@hegeldev/hegel/generators";
import { Option, Predicate, Result } from "effect";

import { answerPrompt } from "../src/bend.ts";
import { type GameEvent, type Seat, type SeatCount } from "../src/domain.ts";
import { aiPrompt, aiStep, begin, type Controller, type Progress, promptsOf } from "../src/driver.ts";
import { seedRng } from "../src/rng.ts";

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

const table = gs.sampledFrom([2, 3, 4] as const);

test("Story and DoN finish a match at any table, items on or off, from any seed", () => {
  hegel.test((tc) => {
    const progress = playOut(tc.draw(table), tc.draw(gs.booleans()), tc.draw(gs.integers()), MIXED);

    expect(progress.game.pending.kind).toBe("Finished");
    expect(progress.events.at(-1)?._tag).toBe("MatchConcluded");
  }, { testCases: 20 });
});

test("an AI match is reproducible from its seed", () => {
  hegel.test((tc) => {
    const [size, items, seed] = [tc.draw(table), tc.draw(gs.booleans()), tc.draw(gs.integers())];

    expect(playOut(size, items, seed, MIXED).events).toEqual(playOut(size, items, seed, MIXED).events);
  }, { testCases: 10 });
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

const SOCKETS: ReadonlyArray<Seat> = [0, 1, 2, 3];

interface Take {
  readonly seat: Seat;
  /** Events in the log once this take had happened. */
  readonly after: number;
  /** Ties on `after` go to the Granted, which a later secret follows. */
  readonly rank: 0 | 1;
}

interface Distribution {
  readonly first: Seat;
  readonly takers: ReadonlyArray<Seat>;
}

const takesOf = ({ events, learned }: Progress): ReadonlyArray<Take> =>
  [
    ...events.flatMap((event, index): ReadonlyArray<Take> => (Predicate.isTagged(event, "Granted") ? [{ seat: event.seat, after: index + 1, rank: 0 }] : [])),
    ...learned.flatMap(({ seat, secret, at }): ReadonlyArray<Take> => (Predicate.isTagged(secret, "EmptyBriefcase") ? [{ seat, after: at, rank: 1 }] : [])),
  ].sort((a, b) => a.after - b.after || a.rank - b.rank);

const indexFrom = (events: ReadonlyArray<GameEvent>, from: number, matches: Predicate.Predicate<GameEvent>): number => {
  const found = events.slice(from).findIndex(matches);

  if (found < 0) throw new Error("expected a later event");

  return from + found;
};

const isTurnStart = (event: GameEvent): event is Extract<GameEvent, { readonly _tag: "TurnGiven" | "TurnSkipped" }> =>
  Predicate.isTagged(event, "TurnGiven") || Predicate.isTagged(event, "TurnSkipped");

/** RoundBegan.first at a round start; at a reload, the first seat given or skipped a turn after the Loaded that follows. */
const firstShooterAt = (events: ReadonlyArray<GameEvent>, began: number): Seat => {
  const mark = events.slice(0, began).findLast(Predicate.or(Predicate.isTagged("RoundBegan"), Predicate.isTagged("Loaded")));

  if (mark !== undefined && Predicate.isTagged(mark, "RoundBegan")) return mark.first;

  const turn = events.slice(indexFrom(events, began, Predicate.isTagged("Loaded"))).find(isTurnStart);

  if (turn === undefined) throw new Error("expected a turn after the reload");

  return turn.seat;
};

const distributionsOf = (progress: Progress): ReadonlyArray<Distribution> => {
  const takes = takesOf(progress);

  return progress.events.flatMap((event, began): ReadonlyArray<Distribution> => {
    if (!Predicate.isTagged(event, "GrabbingBegan")) return [];

    const done = indexFrom(progress.events, began, Predicate.isTagged("DistributionDone"));

    return [{ first: firstShooterAt(progress.events, began), takers: takes.filter(({ after }) => after > began && after <= done + 1).map(({ seat }) => seat) }];
  });
};

/** Starting after the first shooter, each next taker is the next seat in socket order, wrapping, that still takes later. */
const roundRobin = ({ first, takers }: Distribution): ReadonlyArray<Seat> => {
  const remaining = new Map(SOCKETS.map((seat) => [seat, takers.filter((taker) => taker === seat).length]));
  const order: Array<Seat> = [];
  let previous = first;

  for (let taken = 0; taken < takers.length; taken++) {
    const next = [1, 2, 3, 4].map((step) => SOCKETS[(previous + step) % SOCKETS.length]).find((seat) => seat !== undefined && (remaining.get(seat) ?? 0) > 0);

    if (next === undefined) throw new Error("expected a seat that still takes");

    remaining.set(next, (remaining.get(next) ?? 0) - 1);
    order.push(next);
    previous = next;
  }

  return order;
};

test("bots take their items one seat at a time from the seat after the first shooter", () => {
  let distributions = 0;
  let shared = 0;

  hegel.test((tc) => {
    for (const distribution of distributionsOf(playOut(tc.draw(table), true, tc.draw(gs.integers()), MIXED))) {
      expect(distribution.takers).toEqual(roundRobin(distribution));
      distributions++;

      if (new Set(distribution.takers).size > 1) shared++;
    }
  }, { testCases: 20, derandomize: true });

  expect(distributions).toBeGreaterThan(0);
  expect(shared).toBeGreaterThan(0);
});
