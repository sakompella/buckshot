import { Result } from "effect";

import { GameEvent, type SeatCount } from "../domain.ts";
import { begin } from "../driver.ts";
import { seedRng } from "../rng.ts";

// Round 1 of a match starts at a seat its seed draws, so a block seed decides
// which position shoots first. A tournament whose block seeds favour one
// position would credit that position with the first shooter's edge: the
// seeds 3000 to 3009 start position 2 six times in ten. These pick block seeds
// that start each position equally often.

/** The position, from 1, whose seat starts round 1 of a match with this seed: the game's own first draw, read from a fresh start. */
export const firstPositionOf = (seed: number, table: SeatCount): number =>
  Result.match(begin(table, true, 1, seedRng(seed), [], seed), {
    onFailure: (error) => {
      throw new Error(`the game did not start from seed ${seed}: ${String(error)}`);
    },
    onSuccess: (progress) => {
      const [first] = progress.events.flatMap((event) => GameEvent.matchOrElse(event, { RoundBegan: ({ first: seat }) => [seat] }, () => []));

      if (first === undefined) throw new Error(`the game from seed ${seed} began no round`);

      return progress.game.seats.indexOf(first) + 1;
    },
  });

/**
 * `blocks` block seeds: `keep` as given, then for each further block the smallest seed from `from` up, not yet taken,
 * whose round 1 starts at the position started least so far (the lowest such position on a tie). After `keep`, every
 * prefix of the list starts the positions as evenly as it can.
 */
export const balancedSeeds = (table: SeatCount, blocks: number, from: number, keep: ReadonlyArray<number> = []): ReadonlyArray<number> => {
  const seeds = [...keep];
  const started = Array.from({ length: table }, (_, position) => keep.filter((seed) => firstPositionOf(seed, table) === position + 1).length);
  let candidate = from;

  while (seeds.length < blocks) {
    const wanted = started.indexOf(Math.min(...started)) + 1;

    while (seeds.includes(candidate) || firstPositionOf(candidate, table) !== wanted) candidate += 1;

    seeds.push(candidate);
    started[wanted - 1] = (started[wanted - 1] ?? 0) + 1;
    candidate = from;
  }

  return seeds;
};
