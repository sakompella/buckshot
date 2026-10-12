// A small seeded generator (mulberry32) kept as plain data so the Model can
// hold it and update stays pure. Used for draws and the stand-in bot until
// the Bend driver supplies its own source.

export type Rng = number;

export const seedRng = (seed: number): Rng => seed >>> 0;

/** A value in 0..size-1 and the next generator state. */
export const nextBelow = (rng: Rng, size: number): readonly [number, Rng] => {
  const state = (rng + 0x6d2b79f5) >>> 0;
  let mixed = Math.imul(state ^ (state >>> 15), state | 1);

  mixed ^= mixed + Math.imul(mixed ^ (mixed >>> 7), mixed | 61);

  const word = (mixed ^ (mixed >>> 14)) >>> 0;

  return [word % size, state];
};
