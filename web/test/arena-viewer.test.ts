import * as hegel from "@hegeldev/hegel";
import * as gs from "@hegeldev/hegel/generators";
import { expect, test } from "bun:test";
import { Option } from "effect";

import { configSummaries, ODDS_BINS, oddsBinOf, selfShotTallies } from "../src/arena-viewer/aggregates.ts";
import { chamberPatterns, roundStory, ShellTracker } from "../src/arena-viewer/analysis.ts";
import type { Seat, SeatRegret } from "../src/arena-viewer/api.ts";
import { isEngine as isArenaEngine } from "../src/arena/agent.ts";
import { type BlockTally, baseName, blockRate, fmtBytes, groupBy, isEngine, labelOf, matchRows, quantile, regretStats, type SeatFull, withPotShares } from "../src/arena-viewer/page/data.ts";
import { mulberry32 } from "../src/arena/tournament-stats.ts";
import { ANCHOR, bradleyTerry, type Game, heldOutRatings, matchWinVsAnchor, pooledRatings, type Rating } from "../src/arena-viewer/page/ratings.ts";
import { droppedConfigs, oddsPanels } from "../src/arena-viewer/page/odds.ts";
import { rowsOf } from "../src/arena-viewer/page/matches.ts";
import { modelStatsOf, ranksOf } from "../src/arena-viewer/page/derived.ts";
import { inRankOrder } from "../src/arena-viewer/page/leaderboard.ts";
import { FULL_N, shadeOf } from "../src/arena-viewer/page/heat.ts";
import { GameEvent, type Seat as Socket, Secret } from "../src/domain.ts";
import { rosterOf } from "../src/players.ts";
import { AXES, frontierOf } from "../src/arena-viewer/page/scatter.ts";
import { SEAT } from "./fixtures.ts";

const PLAYERS = ["a", "b", "c", "d", "e"];

const modelStats = (seats: ReadonlyArray<SeatFull>) => modelStatsOf(configSummaries(seats, { seat: [], legalUse: [], useItem: [] }));

const gamesGen = gs.composite<ReadonlyArray<Game>>((tc) => {
  const game = gs.tuples(gs.integers({ minValue: 0, maxValue: 4 }), gs.integers({ minValue: 1, maxValue: 4 }), gs.sampledFrom([0, 0.5, 1])).map(([a, offset, sa]) => ({ a: PLAYERS[a] ?? "a", b: PLAYERS[(a + offset) % 5] ?? "b", sa }));

  return tc.draw(gs.arrays(game, { minSize: 1, maxSize: 40 }));
});

test("Bradley-Terry ratings have mean 0", () =>
  hegel.test((tc) => {
    const values = [...bradleyTerry(tc.draw(gamesGen)).values()];

    expect(Math.abs(values.reduce((total, value) => total + value, 0))).toBeLessThan(1e-6);
  }));

test("Bradley-Terry ratings do not depend on which side a game lists first", () =>
  hegel.test((tc) => {
    const games = tc.draw(gamesGen);
    const swapped = bradleyTerry(games.map(({ a, b, sa }) => ({ a: b, b: a, sa: 1 - sa })));

    for (const [id, rating] of bradleyTerry(games)) expect(swapped.get(id) ?? Number.NaN).toBeCloseTo(rating, 6);
  }));

test("one more win for a player over another never narrows the gap between them", () =>
  hegel.test((tc) => {
    const games = tc.draw(gamesGen);
    const winnerAt = tc.draw(gs.integers({ minValue: 0, maxValue: 4 }));
    const winner = PLAYERS[winnerAt] ?? "a";
    const loser = PLAYERS[(winnerAt + tc.draw(gs.integers({ minValue: 1, maxValue: 4 }))) % 5] ?? "b";

    const gap = (played: ReadonlyArray<Game>) => {
      const ratings = bradleyTerry(played);

      return (ratings.get(winner) ?? 0) - (ratings.get(loser) ?? 0);
    };

    expect(gap([...games, { a: winner, b: loser, sa: 1 }])).toBeGreaterThanOrEqual(gap(games) - 1e-6);
  }));

test("Bradley-Terry ranks a player that wins more of the same games higher", () => {
  const games = [
    { a: "x", b: "y", sa: 1 },
    { a: "x", b: "y", sa: 1 },
    { a: "x", b: "y", sa: 0 },
  ];

  expect(bradleyTerry(games).get("x") ?? 0).toBeGreaterThan(bradleyTerry(games).get("y") ?? 0);
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
    const ratings = bradleyTerry(playedGames(mulberry32(seed), 1000));
    const mean = TRUE_ELO.reduce((total, [, elo]) => total + elo, 0) / TRUE_ELO.length;

    for (const [id, elo] of TRUE_ELO) expect(Math.abs((ratings.get(id) ?? Number.NaN) - (elo - mean))).toBeLessThan(35);
  }
});

test("a config that wins every game is rated high but finite", () => {
  const ratings = bradleyTerry(Array.from({ length: 30 }, () => ({ a: "x", b: "y", sa: 1 })));

  expect(ratings.get("x") ?? 0).toBeGreaterThan(100);
  expect(Number.isFinite(ratings.get("x"))).toBe(true);
  expect(Number.isFinite(ratings.get("y"))).toBe(true);
});

const plainBlockRate = (tally: BlockTally, reps: number) => {
  const blocks = [...tally.values()];
  const random = mulberry32(7);
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

test("the block bootstrap's kept draws give the same interval as drawing afresh, whatever sizes came before", () =>
  hegel.test(
    (tc) => {
      const draws = gs.tuples(gs.integers({ minValue: 1, maxValue: 120 }), gs.sampledFrom([200, 300, 400, 1000]));

      for (const [size, reps] of tc.draw(gs.arrays(draws, { minSize: 1, maxSize: 5 }))) {
        const block = gs.tuples(gs.integers({ minValue: 0, maxValue: 2 }).map((half) => half / 2), gs.integers({ minValue: 1, maxValue: 3 }));
        const tally: BlockTally = new Map(tc.draw(gs.arrays(block, { minSize: size, maxSize: size })).map((counts, index) => [String(index), counts]));
        const { lo, hi } = blockRate(tally, reps);

        expect({ lo, hi }).toEqual(plainBlockRate(tally, reps));
      }
    },
    { testCases: 30 },
  ));

const fired = (shooter: Socket, target: Socket, shell: "Live" | "Blank"): GameEvent => GameEvent.cases.Fired.make({ shooter, target, shell, captured: "Single", applied: shell === "Live" ? 1 : 0, health: 3 });

test("the shell tracker knows the chamber from a glass, a phone and the count", () => {
  const tracker = new ShellTracker();

  tracker.hear(GameEvent.cases.Loaded.make({ load: { live: 1, blank: 2 } }));
  expect(tracker.chamber()?.pLive).toBeCloseTo(1 / 3);

  tracker.hear(Secret.cases.Glimpse.make({ shell: "Blank" }));
  expect(tracker.chamber()).toEqual({ known: "blank", by: "glass", pLive: 0 });

  tracker.hear(fired(0, 1, "Blank"));
  tracker.hear(Secret.cases.Clue.make({ position: 2, shell: "Blank" }));
  expect(tracker.chamber()).toEqual({ known: "live", by: "count", pLive: 1 });

  tracker.hear(GameEvent.cases.Inverted.make({ seat: 0 }));
  expect(tracker.chamber()).toEqual({ known: "blank", by: "count", pLive: 0 });

  tracker.hear(GameEvent.cases.Ejected.make({ seat: 0, shell: "Blank" }));
  tracker.hear(fired(0, 1, "Blank"));
  expect(tracker.chamber()).toBeNull();
  expect(tracker.checks).toEqual({ ok: 3, bad: 0 });
});

test("shooting the opponent with a known blank is flagged on a load's last shell too, since a blank at oneself keeps the turn", () => {
  const tracker = new ShellTracker();

  tracker.hear(GameEvent.cases.Loaded.make({ load: { live: 1, blank: 1 } }));
  tracker.hear(fired(0, 1, "Live"));
  tracker.hear(Secret.cases.Glimpse.make({ shell: "Blank" }));

  const chamber = tracker.chamber();
  const patterns = chamber === null ? [] : chamberPatterns(chamber, false, new Set(["Shoot yourself", "Shoot Player B"]), "Shoot Player B");

  expect(patterns.filter(([, isAvailable, isChosen]) => isAvailable && isChosen).map(([pattern]) => pattern)).toEqual(["knownBlankOpp", "glassBlankOpp"]);
});

test("the round story reads each round's winner from the events, and is ok when every round has one and the prizes add up to the final cash", () => {
  const events: ReadonlyArray<GameEvent> = [
    GameEvent.cases.RoundBegan.make({ round: 0, health: 2, first: 1 }),
    GameEvent.cases.RoundWon.make({ seat: 1, prize: 10_000 }),
    GameEvent.cases.RoundBegan.make({ round: 1, health: 4, first: 0 }),
    GameEvent.cases.RoundWon.make({ seat: 0, prize: 20_000 }),
    GameEvent.cases.RoundBegan.make({ round: 2, health: 5, first: 0 }),
    GameEvent.cases.RoundWon.make({ seat: 1, prize: 60_000 }),
  ];

  const roster = rosterOf([0, 1]);
  const cash = new Map([["A", 20_000], ["B", 70_000]]);

  expect(roundStory({ events, roster }, cash)).toEqual({ starter: "B", rounds: [{ winner: "B", prize: 10_000 }, { winner: "A", prize: 20_000 }, { winner: "B", prize: 60_000 }], ok: true });
  expect(roundStory({ events, roster }, new Map([["A", 30_000], ["B", 70_000]])).ok).toBe(false);
  expect(roundStory({ events: events.slice(0, -1), roster }, cash).ok).toBe(false);
});

test("pooled ratings cover every config of a completed match, over every tournament, with an interval around each", () => {
  const random = mulberry32(4);

  const seats = Array.from({ length: 60 }, (_match, index) => {
    const [a, b] = PAIRINGS[index % PAIRINGS.length] ?? ["", ""];
    const aWins = random() < 0.5;

    const story = { starter: "A", ok: true, rounds: [{ winner: aWins ? "A" : "B", prize: 1 }] };

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
  const random = mulberry32(seed);
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
    expect(config.potShare).toBeCloseTo(config.winShare * (2 / 3) + (1 - config.winShare) / 3, 12);
  }
});

const seatRegret = (moves: number, losses: ReadonlyArray<number>, rest: Partial<SeatRegret> = {}): SeatRegret => ({ moves, total: losses.reduce((sum, loss) => sum + loss, 0), accuracy: 50, best: 0, inaccuracies: 0, mistakes: 0, blunders: 0, losses, ...rest });

test("a config's regret weighs every searched move equally, whichever seat it came from, and is null with none", () => {
  const seats = [{ regret: seatRegret(1, [10], { accuracy: 40, blunders: 0, mistakes: 1, best: 0 }) }, { regret: seatRegret(3, [1, 1], { accuracy: 80, best: 1 }) }, { regret: null }];

  expect(regretStats(seats)).toEqual({ moves: 4, accuracy: 60, meanLost: 3, p99Lost: 10, bestShare: 0.25, inaccuraciesPer100: 0, mistakesPer100: 25, blundersPer100: 0 });
  expect(regretStats([{ regret: null }])).toBeNull();
  expect(regretStats([])).toBeNull();
});

test("the 99th-percentile loss counts the moves that lost nothing, by nearest rank", () => {
  const losses = Array.from({ length: 5 }, (_, at) => at + 1);

  expect(regretStats([{ regret: seatRegret(1000, losses) }])?.p99Lost).toBe(0);
  expect(regretStats([{ regret: seatRegret(100, [...losses, 40, 50]) }])?.p99Lost).toBe(40);
  expect(regretStats([{ regret: seatRegret(5, losses) }])?.p99Lost).toBe(5);
});

// Two-player matches over the sweeps' pairings where every match lasts `rounds` rounds and the winner takes `winnerRounds` of them.
const playedRoundSeats = (seed: number, rounds: number, winnerRounds: number, isStoryOk = true) => {
  const random = mulberry32(seed);
  const strength = new Map(TRUE_ELO);

  const seats = Array.from({ length: 60 }, (_match, index) => {
    const [a, b] = PAIRINGS[index % PAIRINGS.length] ?? ["", ""];
    const aWins = random() < 1 / (1 + 10 ** (((strength.get(b) ?? 0) - (strength.get(a) ?? 0)) / 400));
    const winner = aWins ? "A" : "B";
    const story = { starter: "A", ok: isStoryOk, rounds: Array.from({ length: rounds }, (_round, round) => ({ winner: round < winnerRounds ? winner : aWins ? "B" : "A", prize: 1 })) };

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
  const seatOf = (model: string, matchId: string, player: string, total: number): SeatFull => ({ ...SEAT, potShare: null, matchId, player, model, regret: seatRegret(10, [total]) });
  const seats = [seatOf("claude-opus-5-5", "m1", "A", 20), seatOf("claude-haiku-4-5-20251001", "m1", "B", 60), seatOf("claude-opus-5-5", "m2", "B", 40), seatOf("claude-haiku-4-5-20251001", "m2", "A", 80)];
  const meanOf = (model: string) => modelStats(seats).find((config) => config.model === model)?.regret?.meanLost;

  expect(meanOf("claude-opus-5-5")).toBe(3);
  expect(meanOf("claude-haiku-4-5-20251001")).toBe(7);
});

test("the scatter's accuracy axis places a config with no searched move nowhere and a measured zero at zero", () => {
  const [unsearched, flawless, flawed] = modelStats(
    [null, seatRegret(4, [], { accuracy: 100 }), seatRegret(2, [2, 1], { accuracy: 98.5 })].map((regret, index) => ({ ...SEAT, matchId: `m${index}`, effort: `e${index}`, potShare: null, regret })),
  );

  expect([unsearched, flawless, flawed].map((config) => (config === undefined ? undefined : AXES.regret.valueOf(config)))).toEqual([null, 100, 98.5]);
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

  // Tiers leave provisional configs out, and the unknown matches still count toward a config's scored matches.
  const withoutTiers = (ratings: ReadonlyMap<string, Rating>) => new Map([...ratings].map(([key, { tier: _tier, ...rest }]) => [key, rest]));

  expect(withoutTiers(pooledRatings([...known, ...unknown]))).toEqual(withoutTiers(pooledRatings(known)));
});

test("a config's round share is the rounds it won over the rounds it played", () => {
  for (const config of modelStats(playedRoundSeats(1, 3, 2))) {
    expect(config.roundShare).toBeCloseTo((config.winShare * 2 + (1 - config.winShare)) / 3, 12);
  }
});

const oneRoundWonBy = (winner: string) => ({ starter: "A", ok: true, rounds: [{ winner, prize: 1 }] });

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

test("ranks go to rated configs of 20 or more matches by rating, equal ratings by label; the rest have no rank and the leaderboard lists them after, the better rated first", () => {
  const played = (model: string, matches: number) => Array.from({ length: matches }, (_, index) => ({ ...SEAT, matchId: `${model}${index}`, model, potShare: null }));
  const stats = modelStats([...played("delta", 20), ...played("alpha", 20), ...played("charlie", 20), ...played("bravo", 20), ...played("echo", 19), ...played("foxtrot", 3)]);
  const rated = (rating: number) => ({ rating, blocks: 4, interval: { lo: rating, hi: rating }, tier: null });
  const ratings = new Map([["charlie|medium", rated(5)], ["bravo|medium", rated(5)], ["alpha|medium", rated(-20)], ["echo|medium", rated(90)], ["foxtrot|medium", rated(10)]]);
  const ranks = ranksOf(stats, ratings);

  expect([...ranks]).toEqual([["bravo|medium", 1], ["charlie|medium", 2], ["alpha|medium", 3]]);
  expect(inRankOrder(stats, ranks, ratings).map(({ model }) => model)).toEqual(["bravo", "charlie", "alpha", "echo", "foxtrot", "delta"]);
});

test("the page reads engine seats as the arena defines them", () => {
  for (const seat of ["Engine/2/20000", "Engine/6/20000/sampled", "Engine/6/20000/static", "Engine/x/1", "claude-opus-5-5"]) expect(isEngine(seat)).toBe(isArenaEngine(seat));

  expect(baseName("Engine/6/20000/sampled")).toBe("Search engine, depth 6 (sampled reloads)");
});

test("the anchor is rated 0, and an even match against it is a coin flip", () => {
  const games = [{ a: ANCHOR, b: "x|medium", sa: 0.3 }, { a: "x|medium", b: "y|medium", sa: 0.6 }];

  expect(bradleyTerry(games).get(ANCHOR)).toBe(0);
  expect(matchWinVsAnchor(0)).toBe(0.5);
  expect(matchWinVsAnchor(200)).toBeGreaterThan(1 / (1 + 10 ** (-200 / 400)));
});

test("a config the data clearly ranks below the top starts the next tier; one it cannot tell apart joins it", () => {
  const seatsOf = (a: string, b: string, aRounds: (index: number) => number) =>
    Array.from({ length: 40 }, (_match, index) => {
      const won = aRounds(index);
      const story = { starter: "A", ok: true, rounds: Array.from({ length: 3 }, (_round, round) => ({ winner: round < won ? "A" : "B", prize: 1 })) };
      const seatOf = (model: string, player: string, position: number, share: number): Seat => ({ ...SEAT, matchId: `${a}${b}${index}`, seedBlock: `${a}${b}${index}`, model, effort: "medium", player, position, winShare: share, story });

      return [seatOf(a, "A", 0, won >= 2 ? 1 : 0), seatOf(b, "B", 1, won >= 2 ? 0 : 1)];
    }).flat();

  const ratings = pooledRatings(withPotShares([...seatsOf("strong", "mid", () => 3), ...seatsOf("mid", "low", (index) => (index % 2 === 0 ? 2 : 1))]));

  expect(["strong", "mid", "low"].map((model) => ratings.get(`${model}|medium`)?.tier)).toEqual([1, 2, 2]);
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

test("off reads none, and Astra's off, low effort with the recall prompt, is starred", () => {
  expect(["claude-opus-5-5|off", "gpt-6-astra|off", "gpt-6-astra|low"].map(labelOf)).toEqual(["Opus 5.5 none", "GPT-6 Astra none*", "GPT-6 Astra low"]);
});

test("the configs left off the odds chart are those of the kept seats with no line, named by model with their efforts", () => {
  const seats = [{ model: "claude-opus-5-5", effort: "low" }, { model: "claude-opus-5-5", effort: "off" }, { model: "gpt-6.1-sol", effort: "max" }, { model: "gpt-6.1-sol", effort: "low" }];
  const odds = Array.from({ length: 120 }, (_, shot) => (shot < 60 ? 0 : 100));
  const decisions = { odds: [...odds, ...odds], seat: [...odds.map(() => 0), ...odds.map(() => 2)], shot: [...odds.map(() => 1), ...odds.map(() => 2)] };
  const panels = oddsPanels(selfShotTallies(decisions, seats, [true, true, true, true]));
  const dropped = droppedConfigs(new Set(["claude-opus-5-5|low", "claude-opus-5-5|off", "gpt-6.1-sol|max"]), panels);

  expect(panels.map(({ model }) => model)).toEqual(["claude-opus-5-5", "gpt-6.1-sol"]);
  expect(dropped).toEqual(["claude-opus-5-5|off"]);
  expect(droppedConfigs(new Set(seats.map(({ model, effort }) => `${model}|${effort}`)), panels)).toEqual(["claude-opus-5-5|off", "gpt-6.1-sol|low"]);
});
