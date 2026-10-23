import { expect, test } from "bun:test";

import { roundStory, ShellTracker } from "../src/arena-viewer/analysis.ts";
import type { Seat } from "../src/arena-viewer/api.ts";
import { type BlockTally, blockRate, colorOf, quantile, rankOrder, rng, withCohorts } from "../src/arena-viewer/page/data.ts";
import { bradleyTerry, type Game, pooledRatings } from "../src/arena-viewer/page/ratings.ts";

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

// Two models' effort sweeps joined only through their medium configs: the shape of the real data.
const TRUE_ELO: ReadonlyArray<readonly [string, number]> = [
  ["a-low", -120],
  ["a-medium", 40],
  ["a-high", 90],
  ["b-low", -60],
  ["b-medium", 10],
  ["b-high", 40],
];

const PAIRINGS: ReadonlyArray<readonly [string, string]> = [
  ["a-low", "a-medium"],
  ["a-medium", "a-high"],
  ["a-low", "a-high"],
  ["b-low", "b-medium"],
  ["b-medium", "b-high"],
  ["b-low", "b-high"],
  ["a-medium", "b-medium"],
];

const playedGames = (random: () => number, perPairing: number): ReadonlyArray<Game> => {
  const elo = new Map(TRUE_ELO);
  const strength = (id: string) => elo.get(id) ?? 0;

  return PAIRINGS.flatMap(([a, b]) =>
    Array.from({ length: perPairing }, () => ({ a, b, sa: random() < 1 / (1 + 10 ** ((strength(b) - strength(a)) / 400)) ? 1 : 0 })),
  );
};

test("one pooled Bradley-Terry fit recovers known strengths, including configs that only met their own model", () => {
  for (let seed = 1; seed <= 10; seed++) {
    const ratings = bradleyTerry(playedGames(rng(seed), 1000));
    const mean = TRUE_ELO.reduce((total, [, elo]) => total + elo, 0) / TRUE_ELO.length;

    for (const [id, elo] of TRUE_ELO) expect(Math.abs((ratings.get(id) ?? Number.NaN) - (elo - mean))).toBeLessThan(35);
  }
});

test("a block bootstrap's resamples include every block about equally often", () => {
  const blocks = 1000;
  const reps = 400;
  const random = rng(3);
  const included = new Float64Array(blocks);

  for (let draw = 0; draw < blocks * reps; draw++) {
    const block = Math.floor(random() * blocks);

    included[block] = (included[block] ?? 0) + 1;
  }

  const perRep = Array.from(included, (count) => count / reps);
  const spread = Math.sqrt(perRep.reduce((total, value) => total + (value - 1) ** 2, 0) / blocks);

  expect(Math.min(...perRep)).toBeGreaterThan(0.8);
  expect(Math.max(...perRep)).toBeLessThan(1.2);
  expect(spread).toBeLessThan(0.1);
});

test("a config that wins every game is rated high but finite", () => {
  const ratings = bradleyTerry(Array.from({ length: 30 }, () => ({ a: "x", b: "y", sa: 1 })));

  expect(ratings.get("x") ?? 0).toBeGreaterThan(100);
  expect(Number.isFinite(ratings.get("x"))).toBe(true);
  expect(Number.isFinite(ratings.get("y"))).toBe(true);
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
      expect(stronger?.lightness ?? 0).toBeGreaterThan(weaker.lightness + 0.08);
      expect(stronger?.saturation ?? 0).toBeGreaterThan(weaker.saturation);
    }
  }
});

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
  calls: 0,
  cost: 0,
  inp: 0,
  outp: 0,
  cr: 0,
  cw: 0,
  rt: 0,
  lat: 0,
  failed: 0,
  fcost: 0,
  flat: 0,
  rcost: 0,
  rlat: 0,
  rsHidden: 0,
  rsText: 0,
  multiTool: 0,
  moves: 0,
  acquired: [],
  used: [],
  stolen: [],
  faults: 0,
  reminders: 0,
  fallbacks: 0,
  story: null,
  round: 0,
  low: null,
};

test("a cohort is the kind of comparison, pooled over code hashes, and named for it", () => {
  const match = (matchId: string, tournament: string, codeHash: string, ...configs: ReadonlyArray<readonly [string, string]>) =>
    configs.map(([model, effort], position) => ({ ...SEAT, matchId, tournament, codeHash, model, effort, position }));

  const seats = [
    ...match("a", "one", "old", ["claude-opus-5-5", "medium"], ["gpt-6-astra", "medium"]),
    ...match("b", "one", "new", ["claude-sonnet-5-5", "medium"], ["gpt-6-luna", "medium"]),
    ...match("c", "one", "old", ["claude-sonnet-5-5", "low"], ["claude-sonnet-5-5", "high"]),
    ...match("d", "one", "new", ["claude-sonnet-5-5", "max"], ["claude-sonnet-5-5", "medium"]),
    ...match("e", "two", "new", ["gpt-6-astra", "medium"], ["claude-opus-5-5", "xhigh"]),
    ...match("f", "two", "old", ["claude-opus-5-5", "xhigh"], ["gpt-6-astra", "medium"]),
  ];

  const cohortOf = new Map(withCohorts(seats).map(({ matchId, cohort }) => [matchId, cohort]));

  expect([..."abcdef"].map((matchId) => cohortOf.get(matchId))).toEqual(["Cross-model (medium)", "Cross-model (medium)", "Sonnet efforts", "Sonnet efforts", "Opus xhigh vs Astra", "Opus xhigh vs Astra"]);
});

test("pooled ratings cover every config of a completed match, over every tournament, with an interval around each", () => {
  const random = rng(4);

  const seats = Array.from({ length: 60 }, (_match, index) => {
    const [a, b] = PAIRINGS[index % PAIRINGS.length] ?? ["", ""];
    const aWins = random() < 0.5;

    const split = (config: string, winShare: number, position: number) => {
      const [model = "", effort = ""] = config.split("-");

      return { ...SEAT, matchId: `m${index}`, tournament: `t${index % 2}`, seedBlock: `block${Math.floor(index / 2)}`, model, effort, position, winShare, cohort: "" };
    };

    return [split(a, aWins ? 1 : 0, 0), split(b, aWins ? 0 : 1, 1)];
  }).flat();

  const partial = { ...SEAT, matchId: "partial", model: "c", effort: "low", status: "partial" as const, cohort: "" };
  const ratings = pooledRatings([...seats, partial, { ...partial, model: "d", player: "B", position: 1 }]);

  expect([...ratings.keys()].toSorted()).toEqual(TRUE_ELO.map(([id]) => id.replace("-", "|")).toSorted());

  for (const { lo, hi } of ratings.values()) expect(lo).toBeLessThan(hi);
});

test("rank order puts higher win share first, breaks ties by Elo, and keeps every config once", () => {
  const random = rng(5);

  for (let round = 0; round < 50; round++) {
    // Win shares on a coarse grid so ties are common.
    const configs = Array.from({ length: 1 + Math.floor(random() * 12) }, (_config, index) => ({ label: `c${index}`, winShare: Math.floor(random() * 5) / 4, elo: Math.round(random() * 400 - 200) }));
    const ordered = rankOrder(configs, ({ elo }) => elo);

    expect(ordered.map(({ label }) => label).toSorted()).toEqual(configs.map(({ label }) => label).toSorted());

    ordered.slice(1).forEach((config, index) => {
      const above = ordered[index];

      expect(above).toBeDefined();

      if (above === undefined) return;

      expect(above.winShare).toBeGreaterThanOrEqual(config.winShare);

      if (above.winShare === config.winShare) expect(above.elo).toBeGreaterThanOrEqual(config.elo);
    });
  }
});
