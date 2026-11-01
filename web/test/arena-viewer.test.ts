import { expect, test } from "bun:test";
import { Option } from "effect";

import { chamberPatterns, roundStory, ShellTracker, shotLineIn } from "../src/arena-viewer/analysis.ts";
import type { Seat } from "../src/arena-viewer/api.ts";
import { type BlockTally, blockRate, colorOf, fmtBytes, groupBy, matchRows, modelStats, quantile, regretStats, rng, type SeatFull, withPotShares } from "../src/arena-viewer/page/data.ts";
import { bradleyTerry, type Game, heldOutRatings, pooledRatings } from "../src/arena-viewer/page/ratings.ts";
import { droppedConfigs, droppedText, ODDS_BINS, oddsBinOf, oddsPanels, selfShotTallies } from "../src/arena-viewer/page/odds.ts";
import { shotOf, showsReloadNote, turningPoints } from "../src/arena-viewer/page/replay.ts";
import { rowsOf } from "../src/arena-viewer/page/matches.ts";
import { ranksOf } from "../src/arena-viewer/page/derived.ts";
import { inRankOrder } from "../src/arena-viewer/page/leaderboard.ts";
import { FULL_N, shadeOf } from "../src/arena-viewer/page/heat.ts";
import { AXES, frontierOf } from "../src/arena-viewer/page/scatter.ts";

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
    { strongestFirst: ["claude-opus-5-5", "claude-sonnet-5-5", "claude-haiku-5-5", "claude-haiku-4-5"], hues: [18, 40] },
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
  cost: 0,
  inp: 0,
  outp: 0,
  cr: 0,
  cw: 0,
  rt: 0,
  lat: 0,
  rsHidden: 0,
  rsText: 0,
  multiTool: 0,
  moves: 0,
  acquired: [],
  used: [],
  stolen: [],
  regret: null,
  story: null,
  round: 0,
  roundThree: null,
  deficits: [],
};

test("pooled ratings cover every config of a completed match, over every tournament, with an interval around each", () => {
  const random = rng(4);

  const seats = Array.from({ length: 60 }, (_match, index) => {
    const [a, b] = PAIRINGS[index % PAIRINGS.length] ?? ["", ""];
    const aWins = random() < 0.5;

    const story = { starter: "A", ok: true, rounds: [{ winner: aWins ? "A" : "B", prize: 1, inferred: false }] };

    const split = (config: string, player: string, position: number) => {
      const [model = "", effort = ""] = config.split("-");

      return { ...SEAT, matchId: `m${index}`, tournament: `t${index % 2}`, seedBlock: `block${Math.floor(index / 2)}`, model, effort, player, position, winShare: (player === "A") === aWins ? 1 : 0, potShare: null, story };
    };

    return [split(a, "A", 0), split(b, "B", 1)];
  }).flat();

  const partial = { ...SEAT, matchId: "partial", model: "c", effort: "low", status: "partial" as const, potShare: null };
  const ratings = pooledRatings([...seats, partial, { ...partial, model: "d", player: "B", position: 1 }]);

  expect([...ratings.keys()].toSorted()).toEqual(TRUE_ELO.map(([id]) => id.replace("-", "|")).toSorted());

  for (const { interval } of ratings.values()) expect(interval?.lo).toBeLessThan(interval?.hi ?? Number.NEGATIVE_INFINITY);
});

test("a config over fewer than 4 seed blocks has a rating and no interval", () => {
  const seats = Array.from({ length: 12 }, (_match, index) => [
    { ...SEAT, matchId: `m${index}`, seedBlock: `block${index % 3}`, model: "strong", player: "A", position: 0, winShare: index % 3 === 0 ? 0 : 1, potShare: null, story: oneRoundWonBy(index % 3 === 0 ? "B" : "A") },
    { ...SEAT, matchId: `m${index}`, seedBlock: `block${index % 3}`, model: "weak", player: "B", position: 1, winShare: index % 3 === 0 ? 1 : 0, potShare: null, story: oneRoundWonBy(index % 3 === 0 ? "B" : "A") },
  ]).flat();

  expect([...pooledRatings(seats).values()].map(({ blocks, interval }) => [blocks, interval])).toEqual([[3, null], [3, null]]);
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

  return withPotShares(seats);
};

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

  return withPotShares(seats);
};

// The viewer check used to require Opus's mean regret below Haiku 4.5's on the live data; on fixed data it is a property of modelStats.
test("a config's mean regret comes from its own scored seats, so a lower-regret config shows the lower mean", () => {
  const seatOf = (model: string, matchId: string, player: string, total: number): SeatFull => ({ ...SEAT, potShare: null, matchId, player, model, regret: { moves: 10, total, exact: 0 } });
  const seats = [seatOf("claude-opus-5-5", "m1", "A", 20), seatOf("claude-haiku-4-5-20251001", "m1", "B", 60), seatOf("claude-opus-5-5", "m2", "B", 40), seatOf("claude-haiku-4-5-20251001", "m2", "A", 80)];
  const meanOf = (model: string) => modelStats(seats).find((config) => config.model === model)?.regret?.mean;

  expect(meanOf("claude-opus-5-5")).toBe(3);
  expect(meanOf("claude-haiku-4-5-20251001")).toBe(7);
});

test("the scatter's regret axis places a config with no searched move nowhere and a measured zero at zero", () => {
  const [unsearched, flawless, flawed] = modelStats(
    [null, { moves: 4, total: 0, exact: 4 }, { moves: 2, total: 3, exact: 0 }].map((regret, index) => ({ ...SEAT, matchId: `m${index}`, effort: `e${index}`, potShare: null, regret })),
  );

  expect([unsearched, flawless, flawed].map((config) => (config === undefined ? undefined : AXES.regret.valueOf(config)))).toEqual([null, 0, 1.5]);
});

test("when losers win rounds, rounds ratings keep the order of sweeps' ratings but sit closer together", () => {
  for (let seed = 1; seed <= 5; seed++) {
    const seats = playedRoundSeats(seed, 3, 2);
    const sweeps = pooledRatings(playedRoundSeats(seed, 3, 3));
    const rounds = pooledRatings(seats);
    const spread = (ratings: ReadonlyMap<string, { readonly rating: number }>) => Math.max(...[...ratings.values()].map(({ rating }) => rating)) - Math.min(...[...ratings.values()].map(({ rating }) => rating));
    const order = (ratings: ReadonlyMap<string, { readonly rating: number }>) => [...ratings].toSorted(([, left], [, right]) => left.rating - right.rating).map(([key]) => key);

    expect(order(rounds)).toEqual(order(sweeps));
    expect(spread(rounds)).toBeLessThan(spread(sweeps));
  }
});

test("rounds ratings leave out matches whose round winners are not all known", () => {
  const known = playedRoundSeats(1, 3, 2);
  const unknown = playedRoundSeats(2, 3, 3, false).map((seat) => ({ ...seat, matchId: `unknown-${seat.matchId}` }));

  expect(pooledRatings([...known, ...unknown])).toEqual(pooledRatings(known));
});

test("a config's round share is the rounds it won over the rounds it played", () => {
  for (const config of modelStats(playedRoundSeats(1, 3, 2))) {
    const wins = config.scored.filter(({ winShare }) => winShare === 1).length;

    expect(config.roundShare).toBeCloseTo((wins * 2 + (config.scored.length - wins)) / (3 * config.scored.length), 12);
  }
});

const oneRoundWonBy = (winner: string) => ({ starter: "A", ok: true, rounds: [{ winner, prize: 1, inferred: false }] });

// Two-player matches of the "strong" config against the "weak" one, the strong one winning `strongWins` of `count`.
const upsetSeats = (count: number, strongWins: number) =>
  withPotShares(
    Array.from({ length: count }, (_match, index) => {
      const isStrong = index < strongWins;

      return [
        { ...SEAT, matchId: `m${index}`, seedBlock: `block${index}`, model: "strong", player: "A", position: 0, winShare: isStrong ? 1 : 0, story: oneRoundWonBy(isStrong ? "A" : "B") },
        { ...SEAT, matchId: `m${index}`, seedBlock: `block${index}`, model: "weak", player: "B", position: 1, winShare: isStrong ? 0 : 1, story: oneRoundWonBy(isStrong ? "A" : "B") },
      ];
    }).flat(),
  );

test("a match's held-out ratings do not depend on its own seed block's results", () => {
  const seats = upsetSeats(40, 30);
  const flipped = seats.map((seat) => (seat.seedBlock === "block3" ? { ...seat, winShare: 1 - (seat.winShare ?? 0), story: oneRoundWonBy(seat.story?.rounds[0]?.winner === "A" ? "B" : "A") } : seat));
  const strongIn = (played: ReadonlyArray<SeatFull>, block: string) => heldOutRatings(played)(block).get("strong|medium")?.rating;

  expect(strongIn(flipped, "block3")).toBe(strongIn(seats, "block3"));
  expect(strongIn(flipped, "block4")).not.toBe(strongIn(seats, "block4"));
  expect(strongIn(seats, "block3")).toBeGreaterThan(0);
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
  const odds = seats.flatMap((_seat, index) => Array.from({ length: 120 }, (_, shot) => ({ index, percent: shot < 60 ? 0 : 100, isSelf: shot % 2 === 0 })));
  const decisions = { odds: odds.map(({ percent }) => percent), seat: odds.map(({ index }) => index), shot: odds.map(({ isSelf }) => (isSelf ? 2 : 1)) };
  const effortsOf = (keep: ReadonlyArray<boolean>) => oddsPanels(selfShotTallies(decisions, seats, keep)).map(({ model, lines }) => [model, lines.map(({ effort }) => effort)]);

  expect(effortsOf([true, true, true, true])).toEqual([["claude-opus-5-5", ["low", "medium", "high", "max"]]]);
  expect(effortsOf([true, false, true, true])).toEqual([["claude-opus-5-5", ["low", "high", "max"]]]);
});

test("turning points are the biggest blunders, biggest first, and none when no move gave up 5 points", () => {
  const stepWith = (points: number | null) => ({ regret: points === null ? null : { points } });
  const steps = [4.9, null, 12, 5, 30, 12, 8].map(stepWith);

  expect(turningPoints(steps)).toEqual([4, 2, 5]);
  expect(turningPoints(steps, 10)).toEqual([4, 2, 5, 6, 3]);
  expect(turningPoints([4.9, null, 0].map(stepWith))).toEqual([]);
});

test("ranks go to rated configs of 20 or more matches by rating, equal ratings by label; the rest have no rank and the leaderboard lists them after, the better rated first", () => {
  const played = (model: string, matches: number) => Array.from({ length: matches }, (_, index) => ({ ...SEAT, matchId: `${model}${index}`, model, potShare: null }));
  const stats = modelStats([...played("delta", 20), ...played("alpha", 20), ...played("charlie", 20), ...played("bravo", 20), ...played("echo", 19), ...played("foxtrot", 3)]);
  const rated = (rating: number) => ({ rating, blocks: 4, interval: { lo: rating, hi: rating } });
  const ratings = new Map([["charlie|medium", rated(5)], ["bravo|medium", rated(5)], ["alpha|medium", rated(-20)], ["echo|medium", rated(90)], ["foxtrot|medium", rated(10)]]);
  const ranks = ranksOf(stats, ratings);

  expect([...ranks]).toEqual([["bravo|medium", 1], ["charlie|medium", 2], ["alpha|medium", 3]]);
  expect(inRankOrder(stats, ranks, ratings).map(({ model }) => model)).toEqual(["bravo", "charlie", "alpha", "echo", "foxtrot", "delta"]);
});

test("the reload note shows only when a reload is within the depth reached and 1 to 3 shells are left", () => {
  expect([1, 2, 3].map((shells) => showsReloadNote(shells, 6))).toEqual([true, true, true]);
  expect([4, 5, 6].map((shells) => showsReloadNote(shells, 6))).toEqual([false, false, false]);
  expect([showsReloadNote(2, 1), showsReloadNote(1, 1), showsReloadNote(3, 3), showsReloadNote(3, 2)]).toEqual([false, true, true, false]);
});

test("the best-value line runs through ranked configs only", () => {
  const stats = modelStats([
    ...Array.from({ length: 20 }, (_, index) => ({ ...SEAT, matchId: `ranked${index}`, model: "ranked", cost: 2, potShare: null })),
    ...Array.from({ length: 3 }, (_, index) => ({ ...SEAT, matchId: `new${index}`, model: "new", cost: 1, potShare: null })),
  ]);

  const points = stats.map((m) => ({ m, x: m.model === "new" ? 1 : 2, rating: m.model === "new" ? 50 : 10, rank: undefined }));

  expect(frontierOf(points).map(({ m }) => m.model)).toEqual(["ranked"]);
});

test("a heat cell grows brighter with its win share, and fades toward the page below the matches that give full strength", () => {
  const level = (value: number, n: number) => Number(/rgb\((\d+)/.exec(shadeOf(value, n).background)?.[1]);

  expect(level(0.8, FULL_N)).toBeGreaterThan(level(0.4, FULL_N));
  expect(level(0.8, FULL_N - 1)).toBeLessThan(level(0.8, FULL_N));
  expect(level(0.8, 1)).toBeLessThan(level(0.8, FULL_N - 1));
  expect(level(0.8, FULL_N * 5)).toBe(level(0.8, FULL_N));
});

test("a shooter with no later window gets its shot line from the next window of another player, its last shot there", () => {
  const windows = [
    { player: "B", events: ["Player B shot Player A: blank."] },
    { player: "A", events: ["Player B used handsaw.", "Player B shot Player A: live, 2 damage, 1 health left.", "Player A's turn."] },
  ];

  expect(shotLineIn("B", windows)).toBe("Player B shot Player A: live, 2 damage, 1 health left.");
  expect(shotLineIn("B", windows.slice(0, 1))).toBeUndefined();
  expect(shotLineIn("A", windows)).toBeUndefined();
});

test("a shot shows what its log says, and the last move of a completed match is live because only a live shell ends it", () => {
  const step = (id: string, label: string, outcome: ReadonlyArray<string>) => ({ id, label, outcome });
  const logged = step("a", "Shoot yourself", ["Player A shot Player A: blank."]);
  const last = step("c", "Shoot Player B", []);
  const detail = (status: string) => ({ match: { status }, decisions: [logged, step("b", "Shoot Player B", []), last] });

  expect(shotOf(detail("completed"), logged)).toBe("blank");
  expect(shotOf(detail("completed"), last)).toBe("live");
  expect(shotOf(detail("completed"), step("b", "Shoot Player B", []))).toBeNull();
  expect(shotOf(detail("partial"), last)).toBeNull();
  expect(shotOf(detail("completed"), step("c", "Use handsaw", []))).toBeNull();
});

test("a match search needs each of its words in a seat's label or the seed, in any order and with any spacing", () => {
  const played = (matchId: string, seed: number, ...configs: ReadonlyArray<readonly [string, string]>) =>
    matchRows(configs.map(([model, effort], position) => ({ ...SEAT, matchId, seed, model, effort, position, potShare: null })))[0] ?? { matchId, seats: [], startedAt: "", status: "", seed };

  const matches = [played("a", 4006, ["claude-opus-5-5", "max"], ["gpt-6.1-sol", "medium"]), played("b", 4007, ["claude-opus-5-5", "low"], ["gpt-6.1-sol", "max"]), played("c", 4008, ["gpt-6-luna", "max"], ["gpt-6.1-sol", "low"])];
  const found = (query: string) => rowsOf(matches, new Map(), query, Option.none()).map(({ match }) => match.matchId).toSorted();

  expect(found("opus max")).toEqual(["a", "b"]);
  expect(found("  max   OPUS ")).toEqual(["a", "b"]);
  expect(found("opus 4006")).toEqual(["a"]);
  expect(found("sol low")).toEqual(["b", "c"]);
  expect(found("opus luna")).toEqual([]);
  expect(found("")).toEqual(["a", "b", "c"]);
});

test("a file size is in KB, MB or GB, whichever reads shortest", () => {
  expect([fmtBytes(2_400), fmtBytes(87_300_000), fmtBytes(1_540_000_000)]).toEqual(["2 KB", "87 MB", "1.5 GB"]);
});

test("the configs left off the odds chart are those of the kept seats with no line, named by model with their efforts", () => {
  const seats = [{ model: "claude-opus-5-5", effort: "low" }, { model: "claude-opus-5-5", effort: "off" }, { model: "gpt-6.1-sol", effort: "max" }, { model: "gpt-6.1-sol", effort: "low" }];
  const odds = Array.from({ length: 120 }, (_, shot) => (shot < 60 ? 0 : 100));
  const decisions = { odds: [...odds, ...odds], seat: [...odds.map(() => 0), ...odds.map(() => 2)], shot: [...odds.map(() => 1), ...odds.map(() => 2)] };
  const panels = oddsPanels(selfShotTallies(decisions, seats, [true, true, true, true]));
  const dropped = droppedConfigs(seats, [true, true, true, false], panels);

  expect(panels.map(({ model }) => model)).toEqual(["claude-opus-5-5", "gpt-6.1-sol"]);
  expect(dropped).toEqual(["claude-opus-5-5|off"]);
  expect(droppedConfigs(seats, [true, true, true, true], panels)).toEqual(["claude-opus-5-5|off", "gpt-6.1-sol|low"]);
  expect(droppedText(["claude-opus-5-5|off", "claude-opus-5-5|medium", "gpt-6.1-sol|low"])).toBe("Opus 5.5 off, medium · GPT-6.1 Sol low");
});
