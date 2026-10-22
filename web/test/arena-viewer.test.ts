import { expect, test } from "bun:test";

import { roundStory, ShellTracker } from "../src/arena-viewer/analysis.ts";
import { type BlockTally, blockRate, bradleyTerry, colorOf, type Game, quantile, rng } from "../src/arena-viewer/page/data.ts";

const randomGames = (seed: number): ReadonlyArray<Game> => {
  const random = rng(seed);
  const players = ["a", "b", "c", "d", "e"];
  const pick = () => players[Math.floor(random() * players.length)] ?? "a";

  return Array.from({ length: 40 }, () => [pick(), pick()] as const).flatMap(([a, b]) => (a === b ? [] : [{ a, b, sa: [0, 0.5, 1][Math.floor(random() * 3)] ?? 0 }]));
};

test("Bradley-Terry ratings have mean 0 and do not depend on which side a game lists first", () => {
  for (let seed = 1; seed <= 20; seed++) {
    const games = randomGames(seed);
    const ratings = bradleyTerry(games);
    const swapped = bradleyTerry(games.map(({ a, b, sa }) => ({ a: b, b: a, sa: 1 - sa })));
    const values = [...ratings.values()];

    expect(Math.abs(values.reduce((total, value) => total + value, 0))).toBeLessThan(1e-6);

    for (const [id, rating] of ratings) expect(swapped.get(id) ?? Number.NaN).toBeCloseTo(rating, 6);
  }
});

test("Bradley-Terry ranks a player that wins more of the same games higher", () => {
  const games = [
    { a: "x", b: "y", sa: 1 },
    { a: "x", b: "y", sa: 1 },
    { a: "x", b: "y", sa: 0 },
  ];

  const ratings = bradleyTerry(games);

  expect(ratings.get("x") ?? 0).toBeGreaterThan(ratings.get("y") ?? 0);
  expect(bradleyTerry([...games, { a: "x", b: "y", sa: 1 }]).get("x") ?? 0).toBeGreaterThan(ratings.get("x") ?? 0);
});

// The bootstrap as written out plainly: every resample draws from a fresh rng(7).
const plainBlockRate = (tally: BlockTally, reps: number) => {
  const blocks = [...tally.values()];
  const random = rng(7);
  const rates: Array<number> = [];

  for (let rep = 0; rep < reps; rep++) {
    let hits = 0;
    let trials = 0;

    for (let draw = 0; draw < blocks.length; draw++) {
      const [blockHits = 0, blockTrials = 0] = blocks[Math.floor(random() * blocks.length)] ?? [];

      hits += blockHits;
      trials += blockTrials;
    }

    if (trials > 0) rates.push(hits / trials);
  }

  rates.sort((left, right) => left - right);

  return { lo: quantile(rates, 0.025), hi: quantile(rates, 0.975) };
};

test("the block bootstrap's kept draws give the same interval as drawing afresh, whatever sizes came before", () => {
  const random = rng(11);

  for (let round = 0; round < 60; round++) {
    const size = 1 + Math.floor(random() * (round % 2 === 0 ? 40 : 900));
    const reps = [200, 300, 400, 1000][round % 4] ?? 200;
    const tally: BlockTally = new Map(Array.from({ length: size }, (_block, index) => [String(index), [Math.floor(random() * 3) / 2, 1 + Math.floor(random() * 3)]]));
    const { lo, hi } = blockRate(tally, reps);

    expect({ lo, hi }).toEqual(plainBlockRate(tally, reps));
  }
});

test("the shell tracker knows the chamber from a glass, a phone and the count", () => {
  const tracker = new ShellTracker();

  tracker.event("The shotgun is loaded: 1 live, 2 blank.");
  expect(tracker.chamber()?.pLive).toBeCloseTo(1 / 3);

  tracker.event("The chambered shell is blank.");
  expect(tracker.chamber()).toEqual({ known: "blank", by: "glass", pLive: 0 });

  tracker.event("Player A shot Player B: blank.");
  tracker.event("The 2nd shell is blank.");
  expect(tracker.chamber()).toEqual({ known: "live", by: "count", pLive: 1 });

  tracker.event("Player A inverted the chambered shell.");
  expect(tracker.chamber()).toEqual({ known: "blank", by: "count", pLive: 0 });

  tracker.event("Player A racked out a blank shell.");
  tracker.event("Player A shot Player B: blank.");
  expect(tracker.chamber()).toBeNull();
  expect(tracker.checks).toEqual({ ok: 3, bad: 0 });
});

test("the round story infers the last round's winner from final cash", () => {
  const events = [
    "Round 1 begins. Everyone has 2 health; Player B starts.",
    "Player B wins the round and $10,000.",
    "Round 2 begins. Everyone has 4 health; Player A starts.",
    "Player A wins the round and $20,000.",
    "Round 3 begins. Everyone has 5 health; Player A starts.",
  ];

  expect(roundStory(events, new Map([["A", 20_000], ["B", 70_000]]))).toEqual({
    starter: "B",
    rounds: [
      { winner: "B", prize: 10_000, inferred: false },
      { winner: "A", prize: 20_000, inferred: false },
      { winner: "B", prize: 60_000, inferred: true },
    ],
    ok: true,
  });
  expect(roundStory(events, new Map([["A", 30_000], ["B", 70_000]])).ok).toBe(false);
});

const hsl = (hex: string) => {
  const [r = 0, g = 0, b = 0] = [1, 3, 5].map((start) => Number.parseInt(hex.slice(start, start + 2), 16) / 255);
  const high = Math.max(r, g, b);
  const low = Math.min(r, g, b);
  const lightness = (high + low) / 2;
  const span = high - low;
  const sector = high === r ? ((g - b) / span + 6) % 6 : high === g ? (b - r) / span + 2 : (r - g) / span + 4;

  return { hue: sector * 60, saturation: span / (1 - Math.abs(2 * lightness - 1)), lightness };
};

test("Claude models are orange and GPT models blue, each family brightest and most saturated for its strongest model", () => {
  const families = [
    { strongestFirst: ["claude-opus-5-5", "claude-haiku-5-5", "claude-sonnet-5-5", "claude-haiku-4-5"], hues: [18, 40] },
    { strongestFirst: ["gpt-6-astra", "gpt-6.1-sol", "gpt-5.6-terra", "gpt-6-luna"], hues: [195, 225] },
  ];

  for (const { strongestFirst, hues } of families) {
    const tones = strongestFirst.map((model) => hsl(colorOf(model)));

    for (const tone of tones) {
      expect(tone.hue).toBeGreaterThanOrEqual(hues[0] ?? 0);
      expect(tone.hue).toBeLessThanOrEqual(hues[1] ?? 0);
      expect(tone.lightness).toBeGreaterThan(0.4);
    }

    for (const [weaker, stronger] of tones.slice(1).map((tone, index) => [tone, tones[index]] as const)) {
      expect(stronger?.lightness ?? 0).toBeGreaterThan(weaker.lightness + 0.05);
      expect(stronger?.saturation ?? 0).toBeGreaterThan(weaker.saturation);
    }
  }
});
