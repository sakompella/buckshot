import { Array as Arr, Match } from "effect";

import type { GameEvent, Seat } from "./domain.ts";

// End-of-match titles, computed only from the public event log.

export interface Title {
  readonly name: string;
  readonly description: string;
  readonly seats: ReadonlyArray<Seat>;
  readonly score: number;
}

type Tally = (event: GameEvent) => ReadonlyArray<Seat>;

const fired = (toSeats: (shooter: Seat, target: Seat, applied: number, live: boolean) => ReadonlyArray<Seat>): Tally => (event) =>
  Match.value(event).pipe(
    Match.tag("Fired", ({ shooter, target, applied, shell }) => toSeats(shooter, target, applied, shell === "Live")),
    Match.orElse(() => []),
  );

const used = (counts: (item: GameEvent & { readonly _tag: "Used" }) => boolean): Tally => (event) =>
  Match.value(event).pipe(
    Match.tag("Used", (use) => (counts(use) ? [use.seat] : [])),
    Match.orElse(() => []),
  );

// A Tally yields one seat per point scored, so damage repeats the shooter.
const TALLIES: ReadonlyArray<{ readonly name: string; readonly description: string; readonly tally: Tally }> = [
  { name: "Most damage", description: "health taken from other seats", tally: fired((shooter, target, applied) => (shooter === target ? [] : Arr.replicate(shooter, applied))) },
  { name: "Most hits taken", description: "live shells received", tally: fired((_, target, applied) => (applied > 0 ? [target] : [])) },
  { name: "Chimney", description: "cigarettes smoked", tally: used((use) => use.item === "Cigarettes") },
  { name: "Least careful", description: "live shells fired at themselves", tally: fired((shooter, target, _, live) => (live && shooter === target ? [shooter] : [])) },
  { name: "Most resourceful", description: "items used", tally: used(() => true) },
];

export const titles = (events: ReadonlyArray<GameEvent>, seats: ReadonlyArray<Seat>): ReadonlyArray<Title> =>
  TALLIES.map(({ name, description, tally }) => {
    const points = events.flatMap(tally);
    const scores = seats.map((seat) => [seat, points.filter((scorer) => scorer === seat).length] as const);
    const score = Math.max(0, ...scores.map(([, count]) => count));

    return { name, description, score, seats: score === 0 ? [] : scores.flatMap(([seat, count]) => (count === score ? [seat] : [])) };
  });
