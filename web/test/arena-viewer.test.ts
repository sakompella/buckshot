import { expect, test } from "bun:test";

import { chamberPatterns, roundStory, ShellTracker } from "../src/arena-viewer/analysis.ts";
import type { Seat } from "../src/arena-viewer/api.ts";
import { type BlockTally, blockRate, colorOf, groupBy, matchRows, modelStats, quantile, rankOrder, regretStats, rng, type SeatFull, withCohorts } from "../src/arena-viewer/page/data.ts";
import { type Decisions, NO_GAP } from "../src/arena-viewer/api.ts";
import { pressureCurves, relativeLine } from "../src/arena-viewer/page/pressure.ts";
import { bradleyTerry, expectedShare, type Game, heldOutRatings, pooledRatings, surprises } from "../src/arena-viewer/page/ratings.ts";
import { betterShare, bucketsOf, type Duel } from "../src/arena-viewer/page/luck.ts";
import { ODDS_BINS, oddsBinOf, oddsPanels, selfShotTallies } from "../src/arena-viewer/page/odds.ts";
import { failuresByHour } from "../src/arena-viewer/page/failures-over-time.ts";
import { momentumOf } from "../src/arena-viewer/page/momentum.ts";
import { turningPoints } from "../src/arena-viewer/page/replay.ts";
import { AXES } from "../src/arena-viewer/page/scatter.ts";
import { upsetBins, winChance } from "../src/arena-viewer/page/upset.ts";

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

test("shooting the opponent with a known blank is flagged on a load's last shell too, since a blank at oneself keeps the turn", () => {
  const tracker = new ShellTracker();

  tracker.event("The shotgun is loaded: 1 live, 1 blank.");
  tracker.event("Player A shot Player B: live.");
  tracker.event("The chambered shell is blank.");

  const chamber = tracker.chamber();
  const patterns = chamber === null ? [] : chamberPatterns(chamber, false, new Set(["Shoot yourself", "Shoot Player B"]), "Shoot Player B");

  expect(patterns.filter(([, isAvailable, isChosen]) => isAvailable && isChosen).map(([pattern]) => pattern)).toEqual(["knownBlankOpp", "glassBlankOpp"]);
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
  regret: null,
  story: null,
  round: 0,
  roundThree: null,
  low: null,
  callHours: [],
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

      return { ...SEAT, matchId: `m${index}`, tournament: `t${index % 2}`, seedBlock: `block${Math.floor(index / 2)}`, model, effort, position, winShare, cohort: "", potShare: null };
    };

    return [split(a, aWins ? 1 : 0, 0), split(b, aWins ? 0 : 1, 1)];
  }).flat();

  const partial = { ...SEAT, matchId: "partial", model: "c", effort: "low", status: "partial" as const, cohort: "", potShare: null };
  const ratings = pooledRatings([...seats, partial, { ...partial, model: "d", player: "B", position: 1 }], "wins");

  expect([...ratings.keys()].toSorted()).toEqual(TRUE_ELO.map(([id]) => id.replace("-", "|")).toSorted());

  for (const { lo, hi } of ratings.values()) expect(lo).toBeLessThan(hi);
});

// Two-player matches over the sweeps' pairings, each with a pot of its own, the winner taking `winnerShare` of it.
const playedSeats = (seed: number, winnerShare: number) => {
  const random = rng(seed);
  const strength = new Map(TRUE_ELO);

  const seats = Array.from({ length: 60 }, (_match, index) => {
    const [a, b] = PAIRINGS[index % PAIRINGS.length] ?? ["", ""];
    const pot = [150_000, 225_000, 300_000][Math.floor(random() * 3)] ?? 225_000;
    const aWins = random() < 1 / (1 + 10 ** (((strength.get(b) ?? 0) - (strength.get(a) ?? 0)) / 400));

    const seatOf = (config: string, isWinner: boolean, position: number): Seat => {
      const [model = "", effort = ""] = config.split("-");

      return { ...SEAT, matchId: `m${index}`, tournament: `t${index % 2}`, seedBlock: `block${Math.floor(index / 2)}`, model, effort, position, winShare: isWinner ? 1 : 0, cash: isWinner ? winnerShare * pot : (1 - winnerShare) * pot };
    };

    return [seatOf(a, aWins, 0), seatOf(b, !aWins, 1)];
  }).flat();

  return withCohorts(seats);
};

test("when every match is a sweep, cash ratings equal win ratings", () => {
  for (let seed = 1; seed <= 5; seed++) {
    const seats = playedSeats(seed, 1);
    const wins = pooledRatings(seats, "wins");
    const cash = pooledRatings(seats, "cash");

    expect([...cash.keys()].toSorted()).toEqual([...wins.keys()].toSorted());

    for (const [key, rating] of wins) {
      expect(cash.get(key)?.rating ?? Number.NaN).toBeCloseTo(rating.rating, 6);
      expect(cash.get(key)?.lo ?? Number.NaN).toBeCloseTo(rating.lo, 6);
      expect(cash.get(key)?.hi ?? Number.NaN).toBeCloseTo(rating.hi, 6);
    }
  }
});

test("when losers bank part of the pot, cash ratings keep the order of win ratings but sit closer together", () => {
  for (let seed = 1; seed <= 5; seed++) {
    const seats = playedSeats(seed, 2 / 3);
    const wins = pooledRatings(seats, "wins");
    const cash = pooledRatings(seats, "cash");
    const spread = (ratings: ReadonlyMap<string, { readonly rating: number }>) => Math.max(...[...ratings.values()].map(({ rating }) => rating)) - Math.min(...[...ratings.values()].map(({ rating }) => rating));
    const order = (ratings: ReadonlyMap<string, { readonly rating: number }>) => [...ratings].toSorted(([, left], [, right]) => left.rating - right.rating).map(([key]) => key);

    expect(order(cash)).toEqual(order(wins));
    expect(spread(cash)).toBeLessThan(spread(wins));
  }
});

test("a config's pot share is its cash over the match's cash, averaged over scored matches", () => {
  const seats = playedSeats(1, 2 / 3);

  for (const match of groupBy(seats, ({ matchId }) => matchId).values()) {
    expect(match.reduce((total, seat) => total + (seat.potShare ?? 0), 0)).toBeCloseTo(1, 12);
  }

  for (const config of modelStats(seats)) {
    const wins = config.scored.filter(({ winShare }) => winShare === 1).length;

    expect(config.potShare).toBeCloseTo((wins * (2 / 3) + (config.scored.length - wins) / 3) / config.scored.length, 12);
  }
});

test("rank order puts higher share first, breaks ties by Elo, and keeps every config once", () => {
  const random = rng(5);

  for (let round = 0; round < 50; round++) {
    // Win shares on a coarse grid so ties are common.
    const configs = Array.from({ length: 1 + Math.floor(random() * 12) }, (_config, index) => ({ label: `c${index}`, winShare: Math.floor(random() * 5) / 4, elo: Math.round(random() * 400 - 200) }));
    const ordered = rankOrder(configs, ({ winShare }) => winShare, ({ elo }) => elo);

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

test("a config's regret weights every searched move equally, whichever seat it came from, and is null with none", () => {
  const seats = [{ regret: { moves: 1, total: 10, exact: 1 } }, { regret: { moves: 3, total: 2, exact: 0 } }, { regret: null }];

  expect(regretStats(seats)).toEqual({ moves: 4, mean: 3, exactShare: 0.25 });
  expect(regretStats([{ regret: null }])).toBeNull();
  expect(regretStats([])).toBeNull();
});

// Two-player matches over the sweeps' pairings where every match lasts `rounds` rounds and the winner takes `winnerRounds` of them.
const playedRoundSeats = (seed: number, rounds: number, winnerRounds: number, isStoryOk = true) => {
  const random = rng(seed);
  const strength = new Map(TRUE_ELO);

  const seats = Array.from({ length: 60 }, (_match, index) => {
    const [a, b] = PAIRINGS[index % PAIRINGS.length] ?? ["", ""];
    const aWins = random() < 1 / (1 + 10 ** (((strength.get(b) ?? 0) - (strength.get(a) ?? 0)) / 400));
    const winner = aWins ? "A" : "B";
    const story = { starter: "A", ok: isStoryOk, rounds: Array.from({ length: rounds }, (_round, round) => ({ winner: round < winnerRounds ? winner : aWins ? "B" : "A", prize: 1, inferred: false })) };

    const seatOf = (config: string, player: string, position: number): Seat => {
      const [model = "", effort = ""] = config.split("-");

      return { ...SEAT, matchId: `m${index}`, tournament: `t${index % 2}`, seedBlock: `block${Math.floor(index / 2)}`, model, effort, player, position, winShare: winner === player ? 1 : 0, cash: winner === player ? 2 : 1, story };
    };

    return [seatOf(a, "A", 0), seatOf(b, "B", 1)];
  }).flat();

  return withCohorts(seats);
};

// The viewer check used to require Opus's mean regret below Haiku 4.5's on the live data; on fixed data it is a property of modelStats.
test("a config's mean regret comes from its own scored seats, so a lower-regret config shows the lower mean", () => {
  const seatOf = (model: string, matchId: string, player: string, total: number): SeatFull => ({ ...SEAT, cohort: "c", potShare: null, matchId, player, model, regret: { moves: 10, total, exact: 0 } });
  const seats = [seatOf("claude-opus-5-5", "m1", "A", 20), seatOf("claude-haiku-4-5-20251001", "m1", "B", 60), seatOf("claude-opus-5-5", "m2", "B", 40), seatOf("claude-haiku-4-5-20251001", "m2", "A", 80)];
  const meanOf = (model: string) => modelStats(seats).find((config) => config.model === model)?.regret?.mean;

  expect(meanOf("claude-opus-5-5")).toBe(3);
  expect(meanOf("claude-haiku-4-5-20251001")).toBe(7);
});

test("the scatter's regret axis places a config with no searched move nowhere and a measured zero at zero", () => {
  const [unsearched, flawless, flawed] = modelStats(
    [null, { moves: 4, total: 0, exact: 4 }, { moves: 2, total: 3, exact: 0 }].map((regret, index) => ({ ...SEAT, matchId: `m${index}`, effort: `e${index}`, cohort: "", potShare: null, regret })),
  );

  expect([unsearched, flawless, flawed].map((config) => (config === undefined ? undefined : AXES.regret.valueOf(config)))).toEqual([null, 0, 1.5]);
});

test("when every match is a single round, rounds ratings equal win ratings", () => {
  for (let seed = 1; seed <= 5; seed++) {
    const seats = playedRoundSeats(seed, 1, 1);
    const wins = pooledRatings(seats, "wins");
    const rounds = pooledRatings(seats, "rounds");

    expect([...rounds.keys()].toSorted()).toEqual([...wins.keys()].toSorted());

    for (const [key, rating] of wins) {
      expect(rounds.get(key)?.rating ?? Number.NaN).toBeCloseTo(rating.rating, 6);
      expect(rounds.get(key)?.lo ?? Number.NaN).toBeCloseTo(rating.lo, 6);
      expect(rounds.get(key)?.hi ?? Number.NaN).toBeCloseTo(rating.hi, 6);
    }
  }
});

test("when losers win rounds, rounds ratings keep the order of win ratings but sit closer together", () => {
  for (let seed = 1; seed <= 5; seed++) {
    const seats = playedRoundSeats(seed, 3, 2);
    const wins = pooledRatings(seats, "wins");
    const rounds = pooledRatings(seats, "rounds");
    const spread = (ratings: ReadonlyMap<string, { readonly rating: number }>) => Math.max(...[...ratings.values()].map(({ rating }) => rating)) - Math.min(...[...ratings.values()].map(({ rating }) => rating));
    const order = (ratings: ReadonlyMap<string, { readonly rating: number }>) => [...ratings].toSorted(([, left], [, right]) => left.rating - right.rating).map(([key]) => key);

    expect(order(rounds)).toEqual(order(wins));
    expect(spread(rounds)).toBeLessThan(spread(wins));
  }
});

test("rounds ratings leave out matches whose round winners are not all known", () => {
  const known = playedRoundSeats(1, 3, 2);
  const unknown = playedRoundSeats(2, 3, 3, false).map((seat) => ({ ...seat, matchId: `unknown-${seat.matchId}` }));

  expect(pooledRatings([...known, ...unknown], "rounds")).toEqual(pooledRatings(known, "rounds"));
});

test("a config's round share is the rounds it won over the rounds it played", () => {
  for (const config of modelStats(playedRoundSeats(1, 3, 2))) {
    const wins = config.scored.filter(({ winShare }) => winShare === 1).length;

    expect(config.roundShare).toBeCloseTo((wins * 2 + (config.scored.length - wins)) / (3 * config.scored.length), 12);
  }
});

// Two-player matches of the "strong" config against the "weak" one, the strong one winning `strongWins` of `count`.
const upsetSeats = (count: number, strongWins: number) =>
  withCohorts(
    Array.from({ length: count }, (_match, index) => {
      const isStrong = index < strongWins;

      return [
        { ...SEAT, matchId: `m${index}`, seedBlock: `block${index}`, model: "strong", position: 0, winShare: isStrong ? 1 : 0 },
        { ...SEAT, matchId: `m${index}`, seedBlock: `block${index}`, model: "weak", position: 1, winShare: isStrong ? 0 : 1 },
      ];
    }).flat(),
  );

const RATINGS = new Map([
  ["strong|medium", { rating: 100, lo: 90, hi: 110 }],
  ["weak|medium", { rating: -100, lo: -110, hi: -90 }],
]);

test("a match's held-out ratings do not depend on its own seed block's results", () => {
  const seats = upsetSeats(40, 30);
  const flipped = seats.map((seat) => (seat.seedBlock === "block3" ? { ...seat, winShare: 1 - (seat.winShare ?? 0) } : seat));
  const strongIn = (played: ReadonlyArray<SeatFull>, block: string) => heldOutRatings(played, "wins")(block).get("strong|medium")?.rating;

  expect(strongIn(flipped, "block3")).toBe(strongIn(seats, "block3"));
  expect(strongIn(flipped, "block4")).not.toBe(strongIn(seats, "block4"));
  expect(strongIn(seats, "block3")).toBeGreaterThan(0);
});

test("the upset curve scores the higher-rated config's wins whichever seat it sat in", () => {
  const seats = upsetSeats(32, 24);
  const swapped = seats.map((seat) => ({ ...seat, position: 1 - seat.position }));

  for (const played of [seats, swapped]) {
    const [bin, ...others] = upsetBins(matchRows(played), () => RATINGS);

    expect(others).toEqual([]);
    expect(bin?.rate.rate).toBeCloseTo(0.75, 9);
    expect(bin?.gap).toBe(200);
    expect(bin?.expected).toBeCloseTo(winChance(200), 9);
  }
});

test("the upset curve leaves out matches between equal ratings, unfinished matches and too few matches", () => {
  const equal = new Map([...RATINGS].map(([key, rating]) => [key, { ...rating, rating: 0 }]));
  const unfinished = upsetSeats(40, 30).map((seat) => ({ ...seat, status: "partial" as const }));

  expect(upsetBins(matchRows(upsetSeats(40, 30)), () => equal)).toEqual([]);
  expect(upsetBins(matchRows(unfinished), () => RATINGS)).toEqual([]);
  expect(upsetBins(matchRows(upsetSeats(19, 10)), () => RATINGS)).toEqual([]);
});

test("the upset curve cuts matches into groups of near-equal size, widest gap last", () => {
  const gaps = Array.from({ length: 160 }, (_, index) => index);
  const seats = withCohorts(gaps.flatMap((gap) => [{ ...SEAT, matchId: `m${gap}`, seedBlock: `b${gap}`, model: `s${gap}`, position: 0 }, { ...SEAT, matchId: `m${gap}`, seedBlock: `b${gap}`, model: "base", position: 1, winShare: 0 }]));
  const ratings = new Map([["base|medium", { rating: 0, lo: 0, hi: 0 }], ...gaps.map((gap) => [`s${gap}|medium`, { rating: gap + 1, lo: 0, hi: 0 }] as const)]);
  const bins = upsetBins(matchRows(seats), () => ratings);

  expect(bins.map(({ rate }) => rate.n)).toEqual(Array.from({ length: 8 }, () => 20));
  expect(bins.map(({ gap }) => gap)).toEqual(bins.map(({ gap }) => gap).toSorted((left, right) => left - right));
});

// A duel between configs `winner` and `loser`, each with a mean regret per move of `moves` moves.
const duelOf = (winner: readonly [string, number], loser: readonly [string, number], block = "b"): Duel => {
  const seat = ([config, mean]: readonly [string, number], winShare: number) => ({ ...SEAT, cohort: "c", potShare: null, model: config, effort: "medium", seedBlock: block, winShare, regret: { moves: 10, total: mean * 10, exact: 0 } });

  return { winner: seat(winner, 1), loser: seat(loser, 0) };
};

test("the regret check counts wins by the player with lower regret, ignores ties, and can leave out small gaps", () => {
  const duels = [duelOf(["a", 1], ["b", 3]), duelOf(["a", 4], ["b", 2]), duelOf(["b", 2], ["b", 2]), duelOf(["b", 5], ["a", 1]), duelOf(["a", 1], ["b", 1.25])];

  expect(betterShare(duels, "mean")).toEqual({ k: 2, n: 4 });
  expect(betterShare(duels, "mean", 0.5)).toEqual({ k: 1, n: 3 });
  expect(bucketsOf(duels).map(({ rate }) => rate.n)).toEqual([1, 0, 0, 2, 1]);
});

test("odds bins cover every whole percent once, with the ends and even odds on their own", () => {
  for (let percent = 0; percent <= 100; percent++) {
    const hits = ODDS_BINS.filter(({ low, high }) => percent >= low && percent <= high);

    expect(hits).toHaveLength(1);
  }

  expect(ODDS_BINS[oddsBinOf(50)]?.label).toBe("50");
  expect(oddsBinOf(-1)).toBe(-1);
});

test("self-shot tallies count shots with odds per config and bin, and skip clued shots and filtered seats", () => {
  const seat = (model: string) => ({ model, effort: "medium" });
  const decisions = { odds: [0, 0, 50, -1, 100, 0], seat: [0, 0, 0, 0, 1, 1], shot: [2, 1, 1, 2, 2, 2] };
  const tallies = selfShotTallies(decisions, [seat("a"), seat("b")], [true, false]);

  expect([...tallies.keys()]).toEqual(["a|medium"]);
  expect(tallies.get("a|medium")?.map(({ self, shots }) => [self, shots])).toEqual([[1, 2], [0, 0], [0, 0], [0, 1], [0, 0], [0, 0]]);
});

test("playing the odds keeps every effort the filter keeps, named as itself, with or without medium", () => {
  const seats = ["low", "medium", "high", "max"].map((effort) => ({ model: "claude-opus-5-5", effort }));
  // Each config shoots itself 30 times at 0% live and 30 times at 100% live.
  const odds = seats.flatMap((_seat, index) => Array.from({ length: 120 }, (_, shot) => ({ index, percent: shot < 60 ? 0 : 100, isSelf: shot % 2 === 0 })));
  const decisions = { odds: odds.map(({ percent }) => percent), seat: odds.map(({ index }) => index), shot: odds.map(({ isSelf }) => (isSelf ? 2 : 1)) };
  const effortsOf = (keep: ReadonlyArray<boolean>) => oddsPanels(selfShotTallies(decisions, seats, keep)).map(({ model, lines }) => [model, lines.map(({ effort }) => effort)]);

  expect(effortsOf([true, true, true, true])).toEqual([["claude-opus-5-5", ["low", "medium", "high", "max"]]]);
  expect(effortsOf([true, false, true, true])).toEqual([["claude-opus-5-5", ["low", "high", "max"]]]);
});

const movesAtGaps = (gaps: ReadonlyArray<number>, out: number): Decisions => ({
  seat: gaps.map(() => 0),
  gap: [...gaps],
  out: gaps.map(() => out),
  ord: [], moveNo: [], opp: [], pick: [], failedCalls: [], rt: [], rc: [], cost: [], lat: [], tok: [], calls: [], legalUse: [], legalSteal: [], useItem: [], stealItem: [], shot: [], odds: [],
  checks: { ok: 0, bad: 0 },
});

test("pressure curves pool the gaps beyond the ends, skip moves with no gap and seats the filter drops, and leave out thin points", () => {
  const seats = [{ model: "m", effort: "high" }];
  const gaps = [...Array.from({ length: 30 }, () => -3), ...Array.from({ length: 30 }, () => -2), ...Array.from({ length: 29 }, () => 0), ...Array.from({ length: 40 }, () => NO_GAP)];
  const curves = pressureCurves(movesAtGaps(gaps, 50), seats, [true]);

  expect(curves.get("m|high")).toEqual([{ gap: -2, moves: 60, tokens: 50 }]);
  expect(pressureCurves(movesAtGaps(gaps, 50), seats, [false]).size).toBe(0);
});

test("a pressure line is read against its level-health point and has none without one", () => {
  const point = (gap: number, tokens: number) => ({ gap, moves: 100, tokens });

  expect(relativeLine([point(-2, 300), point(0, 100), point(2, 50)])?.points.map(({ ratio }) => ratio)).toEqual([3, 1, 0.5]);
  expect(relativeLine([point(-2, 300), point(2, 50)])).toBeNull();
  expect(relativeLine([point(0, 100)])).toBeNull();
});

test("failures by hour pool a model's efforts into the hour each call was logged, and leave out seats the filter drops", () => {
  const hour = Date.parse("2026-10-16T10:00:00Z") / 3.6e6;

  const seats = [
    { model: "m", callHours: [[hour, 100, 10], [hour + 1, 40, 0]] as const },
    { model: "m", callHours: [[hour, 50, 5]] as const },
    { model: "other", callHours: [[hour, 30, 30]] as const },
  ];

  expect(failuresByHour(seats, [true, true, false]).get("m")).toEqual([
    { hour, calls: 150, failed: 15 },
    { hour: hour + 1, calls: 40, failed: 0 },
  ]);
  expect(failuresByHour(seats, [true, true, false]).has("other")).toBe(false);
});

test("surprises compare each config's share with the ratings' prediction, from both sides of a game", () => {
  const ratings = new Map([["x|", 0], ["y|", 0], ["z|", 400]]);

  const games: ReadonlyArray<Game> = [
    { a: "x|", b: "y|", sa: 1 },
    { a: "x|", b: "y|", sa: 0 },
    { a: "z|", b: "x|", sa: 0 },
  ];

  const table = surprises(games, ratings, (config) => config.toUpperCase());
  const xVersusY = table.get("x|")?.get("Y|");
  const xVersusZ = table.get("x|")?.get("Z|");

  expect(xVersusY).toEqual({ observed: 0.5, expected: 0.5, games: 2 });
  expect(xVersusZ?.observed).toBe(1);
  expect(xVersusZ?.expected).toBeCloseTo(1 - expectedShare(400, 0), 12);
  expect(table.get("z|")?.get("X|")?.observed).toBe(0);
  expect(surprises(games, new Map([["x|", 0]]), (config) => config).size).toBe(0);
});

test("momentum counts round 2 after a round-1 win, and round 3 only when the first two rounds were split", () => {
  const seat = (winners: ReadonlyArray<string>, seedBlock: string) => ({
    player: "a",
    seedBlock,
    story: { starter: "a", rounds: winners.map((winner) => ({ winner, prize: 1, inferred: false })), ok: true },
  });

  const momentum = momentumOf([seat(["a", "a", "b"], "s1"), seat(["a", "b", "a"], "s1"), seat(["b", "a", "a"], "s2"), seat(["b", "b", "b"], "s2"), seat(["a", "b", "b"], "s3")]);

  expect([momentum.afterWin.k, momentum.afterWin.n]).toEqual([1, 3]);
  expect([momentum.decider.k, momentum.decider.n]).toEqual([2, 3]);
});

test("the two seats of a match split round 3 between them at 1-1", () => {
  const rounds = ["a", "b", "b"].map((winner) => ({ winner, prize: 1, inferred: false }));
  const story = { starter: "a", rounds, ok: true };
  const [a, b] = ["a", "b"].map((player) => momentumOf([{ player, seedBlock: "s", story }]).decider);

  expect([a?.n, b?.n]).toEqual([1, 1]);
  expect((a?.k ?? 0) + (b?.k ?? 0)).toBe(1);
});

test("turning points are the biggest blunders, biggest first, and none when no move gave up 5 points", () => {
  const stepWith = (points: number | null) => ({ regret: points === null ? null : { points } });
  const steps = [4.9, null, 12, 5, 30, 12, 8].map(stepWith);

  expect(turningPoints(steps)).toEqual([4, 2, 5]);
  expect(turningPoints(steps, 10)).toEqual([4, 2, 5, 6, 3]);
  expect(turningPoints([4.9, null, 0].map(stepWith))).toEqual([]);
});
