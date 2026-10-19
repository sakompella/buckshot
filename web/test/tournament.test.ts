import { expect, test } from "bun:test";
import { existsSync, mkdirSync, mkdtempSync, readFileSync, writeFileSync } from "node:fs";
import { tmpdir } from "node:os";
import { join } from "node:path";

import { ConfigProvider, Effect, Exit, Option, Redacted, Result, type Schema } from "effect";

import { AGENTS } from "../src/arena/agent.ts";
import { DEFAULT_PRICES, loadPrices } from "../src/arena/cost.ts";
import { agentEndpoint } from "../src/arena/endpoints.ts";
import { checkPrices, childCommand, childEnv, parseConfig, resolveKeys, type ScheduledMatch, scheduleOf, type Tournament, unfinished } from "../src/arena/tournament.ts";
import { balancedSeeds, firstPositionOf } from "../src/arena/seeds.ts";
import { cooldownOf, costOf, openTournament, RATE_LIMIT_WAIT_SECONDS, readMatch, runPending, type Scheduling, startedUnder, TOURNAMENT_FORMAT } from "../src/arena/tournament-dir.ts";
import { reportOf } from "../src/arena/tournament-report.ts";
import { codeVersions, fitRatings, ELO_PER_NAT, intervalsOf, type PlayedMatch, resamples, sharesByEntrant, sharesByVersion, starterRates, winShares } from "../src/arena/tournament-stats.ts";

// The tournament's schedule, config checks, stats and runner. No model is called:
// matches are played by fakes that write the manifests an arena match would.

const prices = loadPrices(DEFAULT_PRICES);

const ENDPOINTS = {
  "cpa-anthropic": { api: "anthropic", url: "http://127.0.0.1:8318", keyEnv: "CPA_KEY" },
  "cpa-openai": { api: "openai-responses", url: "http://127.0.0.1:8318/v1", keyEnv: "CPA_KEY" },
};

const ENTRANTS = {
  "haiku-5-5": { endpoint: "cpa-anthropic", model: "claude-haiku-5-5", effort: "medium" },
  "luna": { endpoint: "cpa-openai", model: "gpt-6-luna", effort: "high" },
  "sonnet": { endpoint: "cpa-anthropic", model: "claude-sonnet-5-5", effort: "medium" },
  "opus": { endpoint: "cpa-anthropic", model: "claude-opus-5-5", effort: "medium" },
  "don": { bot: "DoN" },
  "story": { bot: "Story" },
};

const configJson = (changes: Readonly<Record<string, Schema.Json>> = {}) =>
  JSON.stringify({ name: "test", seed: 100, delivery: "on-turn", endpoints: ENDPOINTS, entrants: ENTRANTS, pairings: { allOf: Object.keys(ENTRANTS), size: 2 }, blocksPerPairing: 2, ...changes });

const tournamentFrom = (text: string): Tournament => Result.match(parseConfig(text), { onFailure: (error) => { throw new Error(error.message); }, onSuccess: (value) => value });

const errorOf = (text: string): string => Result.match(parseConfig(text), { onFailure: (error) => error.message, onSuccess: () => "no error" });

const factorial = (n: number): number => (n <= 1 ? 1 : n * factorial(n - 1));

const PAIRINGS = [
  ["haiku-5-5", "luna"],
  ["luna", "don", "haiku-5-5"],
  ["sonnet", "story", "opus", "don"],
  ["don", "story", "luna", "opus"],
];

test("a seed block seats every entrant at every position and at every offset from every other entrant equally often", () => {
  const tournament = tournamentFrom(configJson({ pairings: PAIRINGS, blocksPerPairing: 3 }));
  const schedule = scheduleOf(tournament);

  expect(schedule.length).toBe(3 * PAIRINGS.reduce((total, pairing) => total + factorial(pairing.length), 0));

  for (const [index, pairing] of PAIRINGS.entries()) {
    for (const block of [0, 1, 2]) {
      const matches = schedule.filter((match) => match.pairing === index && match.block === block);
      const size = pairing.length;
      const positionOf = (match: ScheduledMatch, entrant: string) => match.entrants.indexOf(entrant);

      expect(matches.length).toBe(factorial(size));

      for (const entrant of pairing) {
        const counts = Array.from({ length: size }, (_, position) => matches.filter((match) => positionOf(match, entrant) === position).length);

        expect(new Set(counts)).toEqual(new Set([factorial(size - 1)]));
      }

      for (const [from, left] of pairing.entries()) {
        for (const right of pairing.slice(from + 1)) {
          const offsets = Array.from({ length: size - 1 }, (_, away) => matches.filter((match) => (positionOf(match, right) - positionOf(match, left) + size) % size === away + 1).length);

          expect(new Set(offsets)).toEqual(new Set([factorial(size) / (size - 1)]));
        }
      }
    }
  }
});

test("blocks have their own seed, shared by every pairing, and names are unique, stable and made of safe characters", () => {
  const tournament = tournamentFrom(configJson({ blocksPerPairing: 3 }));
  const schedule = scheduleOf(tournament);

  expect(scheduleOf(tournament)).toEqual(schedule);
  expect(new Set(schedule.map((match) => match.name)).size).toBe(schedule.length);
  expect(schedule.every((match) => /^[a-z0-9._-]+$/.test(match.name))).toBe(true);
  expect(schedule.every((match) => match.seed === 100 + match.block)).toBe(true);
  expect(new Set(schedule.map((match) => match.seed)).size).toBe(3);
});

test("model entrants get letters in pairing order, and bots take no letter", () => {
  const schedule = scheduleOf(tournamentFrom(configJson({ pairings: [["luna", "don", "haiku-5-5"]], blocksPerPairing: 1 })));

  for (const match of schedule) {
    expect(match.seats.filter((seat) => seat === "DoN").length).toBe(1);
    expect(match.entrants[match.seats.indexOf("A")]).toBe("luna");
    expect(match.entrants[match.seats.indexOf("B")]).toBe("haiku-5-5");
  }
});

test("allOf makes every combination of its size and skips the ones of bots only", () => {
  const schedule = scheduleOf(tournamentFrom(configJson({ blocksPerPairing: 1 })));

  expect(new Set(schedule.map((match) => match.pairing)).size).toBe(15 - 1);
  expect(schedule.length).toBe(2 * (15 - 1));
});

test.each([
  ["an unknown endpoint", { entrants: { ...ENTRANTS, luna: { ...ENTRANTS.luna, endpoint: "nowhere" } } }, 'entrant "luna" uses the unknown endpoint "nowhere"'],
  ["an unknown entrant in a pairing", { pairings: [["luna", "ghost"]] }, 'names the unknown entrant "ghost"'],
  ["an unknown entrant in allOf", { pairings: { allOf: ["luna", "ghost"], size: 2 } }, 'allOf names the unknown entrant "ghost"'],
  ["a duplicate entrant", { pairings: [["luna", "luna"]] }, 'lists the entrant "luna" twice'],
  ["a bots-only pairing", { pairings: [["don", "story"]] }, "has only bots"],
  ["a pairing of one", { pairings: [["luna"]] }, "has 1 entrants; a pairing has 2 to 4"],
  ["a pairing listed twice", { pairings: [["luna", "don"], ["luna", "don"]] }, "is listed twice"],
  ["an allOf smaller than its size", { pairings: { allOf: ["luna", "don"], size: 3 }, }, "fewer than its size 3"],
  ["a bad entrant name", { entrants: { ...ENTRANTS, Luna: ENTRANTS.luna } }, "the config is not valid"],
  ["a mistyped key", { entrants: { ...ENTRANTS, luna: { ...ENTRANTS.luna, efort: "low" } } }, "the config is not valid"],
  ["an unknown effort", { entrants: { ...ENTRANTS, luna: { ...ENTRANTS.luna, effort: "extreme" } } }, "the config is not valid"],
])("a config with %s fails and says so", (_, changes, message) => {
  expect(errorOf(configJson(changes))).toContain(message);
});

test("a model with no price fails before any match, naming the entrant", () => {
  const tournament = tournamentFrom(configJson({ entrants: { ...ENTRANTS, luna: { ...ENTRANTS.luna, model: "gpt-9-unpriced" } } }));
  const checked = checkPrices(tournament, prices);

  expect(Result.isFailure(checked) && checked.failure.message).toContain('entrant "luna" has no entry in prices.json');
  expect(Result.isSuccess(checkPrices(tournamentFrom(configJson()), prices))).toBe(true);
});

// Synthetic matches, drawn from the model the ratings assume.

/** Mulberry32, a generator whose draws are independent enough for a bootstrap check. */
const randomFrom = (seed: number) => {
  let state = seed;

  return () => {
    state = (state + 0x6d2b79f5) >>> 0;

    const mixed = Math.imul(state ^ (state >>> 15), state | 1);
    const stirred = mixed ^ (mixed + Math.imul(mixed ^ (mixed >>> 7), mixed | 61));

    return ((stirred ^ (stirred >>> 14)) >>> 0) / 4_294_967_296;
  };
};

const STRENGTH = new Map([["haiku-5-5", 0.8], ["luna", 0.3], ["sonnet", -0.3], ["opus", -0.7], ["don", 0]]);

const SEAT_TERMS = new Map([["3:2", 0.3], ["3:3", 0.5]]);

const syntheticMatches = (seed: number): ReadonlyArray<PlayedMatch> => {
  const random = randomFrom(seed);
  const tournament = tournamentFrom(configJson({ pairings: { allOf: ["haiku-5-5", "luna", "sonnet", "opus", "don"], size: 3 }, blocksPerPairing: 12 }));

  return scheduleOf(tournament).map((match) => {
    const weights = match.entrants.map((entrant, index) => Math.exp((STRENGTH.get(entrant) ?? 0) + (SEAT_TERMS.get(`3:${index + 1}`) ?? 0)));
    const draw = random() * weights.reduce((total, weight) => total + weight, 0);
    const winner = weights.findIndex((_, index) => weights.slice(0, index + 1).reduce((total, weight) => total + weight, 0) > draw);

    return { name: match.name, pairing: match.pairing, seed: match.seed, code: "abc123", starter: firstPositionOf(match.seed, 3), players: match.entrants.map((entrant, index) => ({ entrant, share: index === winner ? 1 : 0, moves: 10, reminders: 0, interventions: 0 })) };
  });
};

test("ties share the win", () => {
  expect(winShares([100, 100, 50])).toEqual([0.5, 0.5, 0]);
  expect(winShares([10, 90])).toEqual([0, 1]);
});

test("ratings recover the strengths and seat terms that drew the matches, and the bootstrap interval covers them", () => {
  const matches = syntheticMatches(7);
  const fitted = fitRatings(matches, "don");
  const truth = (entrant: string) => (STRENGTH.get(entrant) ?? 0) * ELO_PER_NAT;
  const intervals = intervalsOf(resamples(matches, 200, 1).map((resample) => fitRatings(resample, "don").entrants));

  for (const entrant of ["haiku-5-5", "luna", "sonnet", "opus"]) {
    const rating = fitted.entrants.get(entrant) ?? NaN;
    const interval = intervals.get(entrant);

    expect(Math.abs(rating - truth(entrant))).toBeLessThan(60);
    expect(interval !== undefined && interval.low < truth(entrant) && truth(entrant) < interval.high).toBe(true);
  }

  expect(fitted.entrants.get("don")).toBe(0);

  for (const seat of fitted.seats) expect(Math.abs(seat.rating - (SEAT_TERMS.get(`${seat.size}:${seat.position}`) ?? 0) * ELO_PER_NAT)).toBeLessThan(60);

  expect(fitted.seats.map(({ size, position }) => `${size}:${position}`)).toEqual(["3:2", "3:3"]);
});

test("the same seed gives the same intervals, and win shares sum to one per match", () => {
  const matches = syntheticMatches(3);
  const again = (seed: number) => intervalsOf(resamples(matches, 50, seed).map((resample) => new Map([...sharesByEntrant(resample)].map(([entrant, { share }]) => [entrant, share]))));

  expect(again(5)).toEqual(again(5));
  expect(again(5)).not.toEqual(again(6));
  expect([...sharesByEntrant(matches).values()].reduce((total, { wins }) => total + wins, 0)).toBe(matches.length);
});

test("a resample holds whole seeds, each as often as it was drawn", () => {
  const matches = syntheticMatches(3);
  const perSeed = matches.filter((match) => match.seed === matches[0]?.seed).length;

  for (const resample of resamples(matches, 20, 1)) {
    expect(resample.length).toBe(matches.length);

    for (const seed of new Set(resample.map((match) => match.seed))) expect(resample.filter((match) => match.seed === seed).length % perSeed).toBe(0);
  }
});

test("when the matches of a seed agree, a resample over seeds gives a wider interval than one over matches", () => {
  const random = randomFrom(11);

  const matches: ReadonlyArray<PlayedMatch> = Array.from({ length: 200 }, (_, index) => {
    const seed = index % 10;
    const firstWins = random() < (seed % 2 === 0 ? 0.85 : 0.15);

    return { name: `m${index}`, pairing: Math.floor(index / 10), seed, code: "v1", starter: 1, players: [firstWins ? 1 : 0, firstWins ? 0 : 1].map((share, at) => ({ entrant: at === 0 ? "a" : "b", share, moves: 1, reminders: 0, interventions: 0 })) };
  });

  const widthOf = (played: ReadonlyArray<PlayedMatch>) => {
    const interval = intervalsOf(resamples(played, 500, 1).map((resample) => new Map([...sharesByEntrant(resample)].map(([entrant, { share }]) => [entrant, share])))).get("a");

    return (interval?.high ?? NaN) - (interval?.low ?? NaN);
  };

  expect(widthOf(matches)).toBeGreaterThan(2 * widthOf(matches.map((match, index) => ({ ...match, seed: index }))));
});

test("the round 1 starter's rate counts the matches its player won, a tie by its share, for each table size", () => {
  const played = (starter: number, shares: ReadonlyArray<number>): PlayedMatch => ({
    name: "m",
    pairing: 0,
    seed: 0,
    code: "v1",
    starter,
    players: shares.map((share, at) => ({ entrant: `e${at}`, share, moves: 1, reminders: 0, interventions: 0 })),
  });

  expect(starterRates([played(1, [1, 0]), played(1, [0, 1]), played(2, [0, 1]), played(2, [0.5, 0.5]), played(3, [0, 0, 1])])).toEqual([
    { size: 2, matches: 4, started: [2, 2], wins: 2.5, rate: 0.625 },
    { size: 3, matches: 1, started: [0, 0, 1], wins: 1, rate: 1 },
  ]);
});

test("matches are grouped by the code they were played under, and an entrant's share is split by it", () => {
  const played = (code: string, shares: ReadonlyArray<readonly [string, number]>): PlayedMatch => ({
    name: "m",
    pairing: 0,
    seed: 0,
    code,
    starter: 1,
    players: shares.map(([entrant, share]) => ({ entrant, share, moves: 1, reminders: 0, interventions: 0 })),
  });

  const matches = [played("v1", [["a", 1], ["b", 0]]), played("v1", [["a", 0], ["b", 1]]), played("v1", [["a", 1], ["b", 0]]), played("v2", [["a", 0], ["c", 1]])];

  expect(codeVersions(matches)).toEqual([
    { code: "v1", matches: 3, entrants: ["a", "b"] },
    { code: "v2", matches: 1, entrants: ["a", "c"] },
  ]);
  expect(sharesByVersion(matches).filter(({ entrant }) => entrant === "a").map(({ code, matches: count, share }) => [code, count, share])).toEqual([["v1", 3, 2 / 3], ["v2", 1, 0]]);
});

// The fake arena: a child that writes the manifest a finished match would.

const lettersOf = (match: ScheduledMatch) => {
  const spare = AGENTS.filter((letter) => !match.seats.includes(letter));

  return match.seats.map((seat) => (seat === "DoN" || seat === "Story" ? (spare.shift() ?? seat) : seat));
};

const manifestOf = (tournament: Tournament, match: ScheduledMatch, status: "finished" | "running", winner: number) => {
  const letters = lettersOf(match);

  const agents = Object.fromEntries(match.seats.flatMap((seat, index) => {
    const entrant = tournament.config.entrants[match.entrants[index] ?? ""];

    return entrant !== undefined && "model" in entrant ? [[seat, { model: entrant.model, effort: entrant.effort }]] : [];
  }));

  const manifest = {
    format: 1,
    status,
    seed: String(match.seed),
    controllers: match.seats.map((seat) => (seat === "DoN" || seat === "Story" ? seat : "Agent")),
    letters,
    delivery: "on-turn",
    provenance: { code_sha: "abc123", agents },
    agents: Object.fromEntries(Object.keys(agents).map((seat) => [seat, { moves: 2, reminders: 1, interventions: 1 }])),
    standings: letters.map((player, index) => ({ player, cash: index === winner ? 150_000 : 0, controller: null })),
  };

  // A running match has no standings yet.
  return status === "finished" ? manifest : { ...manifest, standings: undefined };
};

const writeManifest = (dir: string, tournament: Tournament, match: ScheduledMatch, status: "finished" | "running") => {
  mkdirSync(join(dir, match.name), { recursive: true });
  writeFileSync(join(dir, match.name, "manifest.json"), JSON.stringify(manifestOf(tournament, match, status, match.block % match.seats.length)));
};

/** No retries and no pause, so each run of runPending plays each pending match once. */
const ONCE = { attempts: 1, pauseMs: 0 };

test("an interrupted tournament and its restart finish every match once, and a failed match is the only one run again", async () => {
  const tournament = tournamentFrom(configJson({ pairings: { allOf: ["haiku-5-5", "luna", "don"], size: 2 }, blocksPerPairing: 2 }));
  const schedule = scheduleOf(tournament);
  const dir = mkdtempSync(join(tmpdir(), "tournament-run-"));
  const ran: Array<string> = [];

  const interrupted = new AbortController();

  const fake = (breaks: ReadonlySet<string>, interrupt: AbortController) => async (match: ScheduledMatch) => {
    ran.push(match.name);

    if (match.name === schedule[2]?.name) interrupt.abort();

    await Promise.resolve();

    if (breaks.has(match.name)) {
      writeManifest(dir, tournament, match, "running");

      return 1;
    }

    writeManifest(dir, tournament, match, "finished");

    return 0;
  };

  const broken = new Set([schedule[5]?.name ?? ""]);
  const first = await runPending(dir, tournament.config, schedule, 2, fake(broken, interrupted), () => undefined, interrupted.signal, { retry: ONCE });

  expect(first.length).toBeLessThan(schedule.length);

  const second = await runPending(dir, tournament.config, schedule, 2, fake(broken, new AbortController()), () => undefined, new AbortController().signal, { retry: ONCE });

  expect(second.filter(({ status }) => status === "failed").map(({ match }) => match.name)).toEqual([...broken]);

  const third = await runPending(dir, tournament.config, schedule, 2, fake(new Set(), new AbortController()), () => undefined, new AbortController().signal, { retry: ONCE });

  expect(third.map(({ match }) => match.name)).toEqual([...broken]);
  expect(third.every(({ status }) => status === "finished")).toBe(true);
  expect([...ran].toSorted()).toEqual([...schedule.map((match) => match.name), ...broken].toSorted());
  expect(unfinished(schedule, new Set(schedule.map((match) => match.name)))).toEqual([]);
  expect((await runPending(dir, tournament.config, schedule, 2, fake(new Set(), new AbortController()), () => undefined, new AbortController().signal, { retry: ONCE })).length).toBe(0);

  const [opening] = schedule;
  const at = opening?.seats.findIndex((seat) => AGENTS.some((letter) => letter === seat)) ?? -1;
  const entrant = tournament.config.entrants[opening?.entrants[at] ?? ""];

  if (opening === undefined || entrant === undefined || !("model" in entrant)) throw new Error("the first match has no model");

  const call = { t: "2026-10-16T00:00:00Z", agent: opening.seats[at], position: at + 1, provider: "p", api: "a", model: entrant.model, stop_reason: "stop", usage: { input: 1000, output: 0, cacheRead: 0, cacheWrite: 0 }, tool_calls: [], text: "", thinking: "" };

  writeFileSync(join(dir, opening.name, "calls.jsonl"), `${JSON.stringify(call)}\n`);
  writeFileSync(join(dir, opening.name, "events.jsonl"), `${JSON.stringify({ t: call.t, kind: "fault", agent: call.agent, player: call.agent, position: call.position, turn: 3, error: "429" })}\n`);

  const priced = (prices.models[entrant.model]?.input ?? NaN) * 1000 / 1_000_000;
  const report = reportOf(dir, { format: TOURNAMENT_FORMAT, config: tournament.config, created_at: "", git_commit: "", schedule }, tournament, prices, 20);

  expect(report.matches).toEqual({ scheduled: schedule.length, finished: schedule.length, scored: schedule.length });
  expect(report.excluded).toEqual([]);
  expect(report.seeds).toBe(new Set(schedule.map((match) => match.seed)).size);
  expect(report.starters.map(({ size, started }) => [size, started])).toEqual([[2, [1, 2].map((position) => schedule.filter((match) => firstPositionOf(match.seed, 2) === position).length)]]);
  expect(report.versions.map(({ code, matches }) => [code, matches])).toEqual([["abc123", schedule.length]]);
  expect(report.versionShares).toEqual([]);
  expect(report.anchor).toBe("don");
  expect(report.cost.find((row) => row.entrant === opening.entrants[at])).toMatchObject({ calls: 1, faults: 1, dollars: priced });
  expect(costOf(dir, prices, schedule)).toBe(priced);
});

test("a model at its usage limit holds back its matches until the reset, other matches fill the slot, and the wait is no failed run", async () => {
  const tournament = tournamentFrom(configJson({ pairings: [["luna", "haiku-5-5"], ["haiku-5-5", "sonnet"]], blocksPerPairing: 1 }));
  const schedule = scheduleOf(tournament);
  const [lunaFirst, lunaSecond, ...claude] = schedule;

  if (lunaFirst === undefined || lunaSecond === undefined || claude.length !== 2) throw new Error("the schedule is not two luna matches, then two others");

  /** The fault line a match's run ends on when CLIProxyAPI reports luna at its usage limit for `seconds`. */
  const coolDown = (dir: string, match: ScheduledMatch, seconds: number) => {
    const agent = match.seats[match.entrants.indexOf("luna")];
    const error = `openai-responses-A API error (429): ${JSON.stringify({ code: "model_cooldown", model: "gpt-6-luna", reset_seconds: seconds })}`;

    mkdirSync(join(dir, match.name), { recursive: true });
    writeFileSync(join(dir, match.name, "events.jsonl"), `${JSON.stringify({ t: new Date().toISOString(), kind: "fault", agent, player: agent, position: 1, turn: 4, error })}\n`);
    writeManifest(dir, tournament, match, "running");
  };

  const playAll = async (dir: string, runOne: (match: ScheduledMatch) => number) => {
    const runs: Array<string> = [];
    const settled = await runPending(dir, tournament.config, schedule, 1, async (match) => (runs.push(match.name), runOne(match)), () => undefined, new AbortController().signal, { retry: { attempts: 1, pauseMs: 60_000 } });

    return { runs, settled };
  };

  const finish = (dir: string) => (match: ScheduledMatch) => (writeManifest(dir, tournament, match, "finished"), 0);

  const inRun = mkdtempSync(join(tmpdir(), "tournament-cooldown-"));
  const played = await playAll(inRun, (match) => (match === lunaFirst && !existsSync(join(inRun, match.name)) ? (coolDown(inRun, match, 1), 1) : finish(inRun)(match)));

  expect(played.runs).toEqual([lunaFirst, ...claude, lunaFirst, lunaSecond].map((match) => match.name));
  expect(played.settled.map(({ status }) => status)).toEqual(["cooling", "finished", "finished", "finished", "finished"]);

  const earlier = mkdtempSync(join(tmpdir(), "tournament-cooldown-"));

  coolDown(earlier, lunaFirst, 1);

  expect((await playAll(earlier, finish(earlier))).runs).toEqual([...claude, lunaFirst, lunaSecond].map((match) => match.name));
});

test.each([
  ['openai-responses-A API error (429): {"code":"model_cooldown","reset_seconds":90}', 90],
  ['openai-responses-A API error (503): {"error":{"message":"[oc/deepseek-v4.1-flash-free] Rate limited (reset after 1h 2m 3s)"}}', 3723],
  ['openai-responses-A API error (429): {"error":{"message":"Too many requests"}}', RATE_LIMIT_WAIT_SECONDS],
  ['429 {"type":"error","error":{"type":"rate_limit_error","message":"Number of requests has exceeded your rate limit"}}', RATE_LIMIT_WAIT_SECONDS],
  ['openai-responses-A API error (503): {"message":"server_is_overloaded"}', undefined],
])("a fault holds back the model for the reset its error gives, any 429 for a while, and nothing else: %s", (error, seconds) => {
  const tournament = tournamentFrom(configJson({ pairings: [["luna", "haiku-5-5"]], blocksPerPairing: 1 }));
  const [match] = scheduleOf(tournament);
  const dir = mkdtempSync(join(tmpdir(), "tournament-limit-"));
  const at = Date.parse("2026-10-16T01:00:00Z");

  if (match === undefined) throw new Error("no match");

  mkdirSync(join(dir, match.name));
  writeFileSync(join(dir, match.name, "events.jsonl"), `${JSON.stringify({ t: new Date(at).toISOString(), kind: "fault", agent: match.seats[match.entrants.indexOf("luna")], error })}\n`);

  expect(Option.getOrUndefined(cooldownOf(dir, tournament.config, match, at))).toEqual(seconds === undefined ? undefined : { model: "gpt-6-luna", until: at + 1000 * seconds });
});

test("each refusal in a row doubles the wait after a 429 without a reset, and a move starts it over", () => {
  const tournament = tournamentFrom(configJson({ pairings: [["luna", "haiku-5-5"]], blocksPerPairing: 1 }));
  const [match] = scheduleOf(tournament);
  const dir = mkdtempSync(join(tmpdir(), "tournament-backoff-"));
  const at = Date.parse("2026-10-16T01:00:00Z");

  if (match === undefined) throw new Error("no match");

  const agent = match.seats[match.entrants.indexOf("luna")];
  const line = (kind: string) => JSON.stringify({ t: new Date(at).toISOString(), kind, agent, error: 'openai-responses-A API error (429): {"message":"Rate limit exceeded. Please try again later."}' });

  const waitAfter = (kinds: ReadonlyArray<string>) => {
    mkdirSync(join(dir, match.name), { recursive: true });
    writeFileSync(join(dir, match.name, "events.jsonl"), `${kinds.map(line).join("\n")}\n`);

    return Option.match(cooldownOf(dir, tournament.config, match, at), { onNone: () => 0, onSome: ({ until }) => (until - at) / 1000 });
  };

  expect(waitAfter(["fault", "resumed", "fault", "resumed", "fault"])).toBe(4 * RATE_LIMIT_WAIT_SECONDS);
  expect(waitAfter(["fault", "resumed", "move", "fault"])).toBe(RATE_LIMIT_WAIT_SECONDS);
  expect(waitAfter(Array.from({ length: 9 }, () => "fault"))).toBe(16 * RATE_LIMIT_WAIT_SECONDS);
});

test("a match with a model in last starts only when no other can, and a forgotten cooldown does not hold its model back", async () => {
  const tournament = tournamentFrom(configJson({ pairings: [["luna", "haiku-5-5"], ["haiku-5-5", "sonnet"]], blocksPerPairing: 1 }));
  const schedule = scheduleOf(tournament);
  const [lunaFirst, lunaSecond, ...claude] = schedule;

  if (lunaFirst === undefined || lunaSecond === undefined || claude.length !== 2) throw new Error("the schedule is not two luna matches, then two others");

  const playAll = async (dir: string, scheduling: Scheduling) => {
    const runs: Array<string> = [];

    await runPending(dir, tournament.config, schedule, 1, async (match) => (runs.push(match.name), writeManifest(dir, tournament, match, "finished"), 0), () => undefined, new AbortController().signal, scheduling);

    return runs;
  };

  const lunaLast = await playAll(mkdtempSync(join(tmpdir(), "tournament-last-")), { last: new Set(["gpt-6-luna"]) });

  expect(lunaLast).toEqual([...claude, lunaFirst, lunaSecond].map((match) => match.name));

  const resetEarly = mkdtempSync(join(tmpdir(), "tournament-forget-"));
  const error = `openai-responses-A API error (429): ${JSON.stringify({ code: "model_cooldown", reset_seconds: 3600 })}`;

  mkdirSync(join(resetEarly, lunaFirst.name));
  writeFileSync(join(resetEarly, lunaFirst.name, "events.jsonl"), `${JSON.stringify({ t: new Date().toISOString(), kind: "fault", agent: lunaFirst.seats[lunaFirst.entrants.indexOf("luna")], error })}\n`);

  expect(await playAll(resetEarly, { forget: new Set(["gpt-6-luna"]) })).toEqual(schedule.map((match) => match.name));
});

test("a capped model plays at most that many matches at once, and the other slots go on", async () => {
  const tournament = tournamentFrom(configJson({ pairings: [["luna", "haiku-5-5"], ["haiku-5-5", "sonnet"]], blocksPerPairing: 2 }));
  const schedule = scheduleOf(tournament);
  const dir = mkdtempSync(join(tmpdir(), "tournament-cap-"));
  const playing = { luna: 0, all: 0, mostLuna: 0, mostAll: 0 };

  const runOne = async (match: ScheduledMatch) => {
    const luna = match.entrants.includes("luna") ? 1 : 0;

    playing.luna += luna;
    playing.all += 1;
    playing.mostLuna = Math.max(playing.mostLuna, playing.luna);
    playing.mostAll = Math.max(playing.mostAll, playing.all);
    await Bun.sleep(20);
    writeManifest(dir, tournament, match, "finished");
    playing.luna -= luna;
    playing.all -= 1;

    return 0;
  };

  const settled = await runPending(dir, tournament.config, schedule, 3, runOne, () => undefined, new AbortController().signal, { retry: ONCE, caps: new Map([["gpt-6-luna", 1]]) });

  expect(settled.filter(({ status }) => status === "finished").length).toBe(schedule.length);
  expect(playing.mostLuna).toBe(1);
  expect(playing.mostAll).toBe(3);
});

test("a stop during a failed match's pause ends the run at once", async () => {
  const tournament = tournamentFrom(configJson({ pairings: [["luna", "don"]], blocksPerPairing: 1 }));
  const dir = mkdtempSync(join(tmpdir(), "tournament-stop-"));
  const stop = new AbortController();
  const started = Date.now();

  await runPending(dir, tournament.config, scheduleOf(tournament), 1, async () => (stop.abort(), 1), () => undefined, stop.signal, { retry: { attempts: 3, pauseMs: 60_000 } });

  expect(Date.now() - started).toBeLessThan(5_000);
});

test("a restarted runner gets a fresh three-run failure allowance", async () => {
  const tournament = tournamentFrom(configJson({ pairings: [["luna", "don"]], blocksPerPairing: 1 }));
  const schedule = scheduleOf(tournament).slice(0, 1);
  const dir = mkdtempSync(join(tmpdir(), "tournament-restart-retry-"));

  const runThree = () => runPending(dir, tournament.config, schedule, 1, async (candidate) => (writeManifest(dir, tournament, candidate, "running"), 1), () => undefined, new AbortController().signal, { retry: { attempts: 3, pauseMs: 0 } });

  expect((await runThree()).map(({ status }) => status)).toEqual(["failed", "failed", "failed"]);
  expect((await runThree()).map(({ status }) => status)).toEqual(["failed", "failed", "failed"]);
});

test("restart scheduling preserves last priority and can forget persisted cooldowns", async () => {
  const tournament = tournamentFrom(configJson({ pairings: [["luna", "haiku-5-5"], ["haiku-5-5", "sonnet"]], blocksPerPairing: 1 }));
  const schedule = scheduleOf(tournament);
  const [lunaFirst, lunaSecond, ...other] = schedule;
  const dir = mkdtempSync(join(tmpdir(), "tournament-restart-scheduling-"));

  if (lunaFirst === undefined || lunaSecond === undefined || other.length !== 2) throw new Error("unexpected schedule");

  const lunaSeat = lunaFirst.seats[lunaFirst.entrants.indexOf("luna")];
  const error = `openai-responses-A API error (429): ${JSON.stringify({ code: "model_cooldown", model: "gpt-6-luna", reset_seconds: 3600 })}`;

  mkdirSync(join(dir, lunaFirst.name));
  writeFileSync(join(dir, lunaFirst.name, "events.jsonl"), `${JSON.stringify({ t: new Date().toISOString(), kind: "fault", agent: lunaSeat, error })}\n`);

  const runs: Array<string> = [];

  const stop = new AbortController();

  const resumedRuns = await runPending(dir, tournament.config, schedule, 1, async (match) => {
    runs.push(match.name);
    writeManifest(dir, tournament, match, "finished");

    if (runs.length === other.length) stop.abort();

    return 0;
  }, () => undefined, stop.signal, { last: new Set(["gpt-6-luna"]) });

  expect(runs).toEqual(other.map(({ name }) => name));
  expect(resumedRuns.every(({ status }) => status === "finished")).toBe(true);

  const restart = new AbortController();
  runs.length = 0;
  const afterForget = await runPending(dir, tournament.config, schedule, 1, async (match) => (runs.push(match.name), writeManifest(dir, tournament, match, "finished"), 0), () => undefined, restart.signal, { forget: new Set(["gpt-6-luna"]) });
  expect(runs).toEqual([lunaFirst.name, lunaSecond.name]);
  expect(afterForget.every(({ status }) => status === "finished")).toBe(true);
});

test("a failed match goes to the back of the queue and is retried, up to its attempts", async () => {
  const tournament = tournamentFrom(configJson({ pairings: [["luna", "don"], ["haiku-5-5", "story"]], blocksPerPairing: 1 }));
  const schedule = scheduleOf(tournament);
  const dir = mkdtempSync(join(tmpdir(), "tournament-retry-"));
  const [flaky, broken] = schedule;
  const runs: Array<string> = [];

  if (flaky === undefined || broken === undefined) throw new Error("too few matches scheduled");

  const settled = await runPending(
    dir,
    tournament.config,
    schedule,
    1,
    async (match) => {
      runs.push(match.name);

      const fails = match.name === broken.name || (match.name === flaky.name && runs.filter((name) => name === flaky.name).length === 1);

      writeManifest(dir, tournament, match, fails ? "running" : "finished");

      return fails ? 1 : 0;
    },
    () => undefined,
    new AbortController().signal,
    { retry: { attempts: 3, pauseMs: 0 } },
  );

  expect(runs).toEqual([flaky.name, ...schedule.slice(1).map((match) => match.name), flaky.name, broken.name, broken.name]);
  expect(settled.filter(({ status }) => status === "finished").map(({ match }) => match.name).toSorted()).toEqual(schedule.filter((match) => match !== broken).map((match) => match.name).toSorted());
});

test("one directory holds one tournament", () => {
  const dir = join(mkdtempSync(join(tmpdir(), "tournament-dir-")), "t");
  const tournament = tournamentFrom(configJson());
  const opened = openTournament(dir, tournament, "abc123", new Date(0));

  expect(Result.isSuccess(opened) && opened.success.schedule).toEqual(scheduleOf(tournament));
  expect(JSON.parse(readFileSync(join(dir, "tournament.json"), "utf8"))).toMatchObject({ format: 1, git_commit: "abc123", created_at: "1970-01-01T00:00:00.000Z" });
  expect(Result.isSuccess(openTournament(dir, tournamentFrom(configJson()), "def456", new Date(1)))).toBe(true);

  const other = openTournament(dir, tournamentFrom(configJson({ seed: 101 })), "abc123", new Date(0));

  expect(Result.isFailure(other) && other.failure.message).toContain("made from a different config");
});

test("balanced block seeds start every position as evenly as they can in every prefix, after the kept ones", () => {
  for (const table of [2, 3, 4] as const) {
    for (const blocks of [1, 4, 7, 10]) {
      const from = 1000 * table + blocks;
      const keep = blocks > 2 ? [from - 1] : [];
      const seeds = balancedSeeds(table, blocks, from, keep);

      expect(seeds.length).toBe(blocks);
      expect(new Set(seeds).size).toBe(blocks);
      expect(seeds.slice(0, keep.length)).toEqual(keep);

      for (let length = keep.length + 1; length <= blocks; length++) {
        const started = Array.from({ length: table }, (_, position) => seeds.slice(0, length).filter((seed) => firstPositionOf(seed, table) === position + 1).length);

        expect(Math.max(...started) - Math.min(...started)).toBeLessThanOrEqual(1);
      }
    }
  }
});

test("a match started under a code version is resumed under it, and a match not yet started under none", () => {
  const dir = mkdtempSync(join(tmpdir(), "tournament-code-"));
  const [started, fresh] = scheduleOf(tournamentFrom(configJson({ pairings: [["luna", "don"]] })));

  if (started === undefined || fresh === undefined) throw new Error("the schedule has fewer than two matches");

  mkdirSync(join(dir, started.name));
  writeFileSync(join(dir, started.name, "manifest.json"), JSON.stringify({ status: "running", provenance: { code_sha: "51b8366684f0", agents: {} } }));

  expect(startedUnder(dir, started)).toEqual(Option.some("51b8366684f0"));
  expect(startedUnder(dir, fresh)).toEqual(Option.none());
});

test("a pairing that lists its block seeds plays its blocks at them, and a tournament grows by such a pairing", () => {
  const seeded = { entrants: ["haiku-5-5", "sonnet"], seeds: [7, 3] };
  const tournament = tournamentFrom(configJson({ pairings: [["luna", "don"], seeded] }));
  const schedule = scheduleOf(tournament);

  expect(schedule.filter((match) => match.pairing === 0).map((match) => match.seed)).toEqual([100, 100, 101, 101]);
  expect(schedule.filter((match) => match.pairing === 1).map((match) => [match.block, match.seed])).toEqual([[0, 7], [0, 7], [1, 3], [1, 3]]);

  expect(errorOf(configJson({ pairings: [{ ...seeded, seeds: [7] }] }))).toContain("lists 1 seeds for 2 blocks");
  expect(errorOf(configJson({ pairings: [{ ...seeded, seeds: [7, 7] }] }))).toContain("lists the seed 7 twice");
  expect(scheduleOf(tournamentFrom(configJson({ pairings: { allOf: ["luna", "opus"], size: 2, seeds: [5, 9] } }))).map((match) => match.seed)).toEqual([5, 5, 9, 9]);

  const dir = join(mkdtempSync(join(tmpdir(), "tournament-seeded-")), "t");
  const first = tournamentFrom(configJson({ pairings: [["luna", "don"]] }));

  openTournament(dir, first, "abc123", new Date(0));

  const grown = openTournament(dir, tournament, "abc123", new Date(0));

  expect(Result.isSuccess(grown) && grown.success.schedule).toEqual([...scheduleOf(first), ...schedule.filter((match) => match.pairing === 1)]);
});

test("a tournament grows by entrants and their endpoints, by pairings listed after its own and by seed blocks, its scheduled matches stay first and unchanged, and a config it grew from opens it as it is", () => {
  const dir = join(mkdtempSync(join(tmpdir(), "tournament-dir-")), "t");
  const first = tournamentFrom(configJson({ entrants: { luna: ENTRANTS.luna, don: ENTRANTS.don }, pairings: [["luna", "don"]] }));
  const grown = tournamentFrom(configJson({ pairings: [["luna", "don"], ["haiku-5-5", "luna"], ["opus", "story"]] }));

  openTournament(dir, first, "abc123", new Date(0));

  const opened = openTournament(dir, grown, "def456", new Date(1));

  const schedule = Result.isSuccess(opened) ? opened.success.schedule : [];

  expect(openTournament(dir, first, "abc123", new Date(0))).toEqual(opened);

  expect(schedule.slice(0, scheduleOf(first).length)).toEqual([...scheduleOf(first)]);
  expect(schedule.toSorted((a, b) => a.name.localeCompare(b.name))).toEqual(scheduleOf(grown).toSorted((a, b) => a.name.localeCompare(b.name)));
  expect(JSON.parse(readFileSync(join(dir, "tournament.json"), "utf8"))).toMatchObject({ git_commit: "abc123", created_at: "1970-01-01T00:00:00.000Z" });

  for (const pairings of [[["haiku-5-5", "luna"]], [["haiku-5-5", "luna"], ["luna", "don"]]]) {
    expect(Result.isFailure(openTournament(dir, tournamentFrom(configJson({ pairings })), "abc123", new Date(0)))).toBe(true);
  }

  expect(openTournament(dir, tournamentFrom(configJson({ pairings: [["luna", "don"], ["haiku-5-5", "luna"], ["opus", "story"]], blocksPerPairing: 1 })), "abc123", new Date(0))).toEqual(opened);
  expect(Result.isFailure(openTournament(dir, tournamentFrom(configJson({ pairings: [["luna", "don"], ["haiku-5-5", "luna"], ["opus", "story"]], delivery: "live" })), "abc123", new Date(0)))).toBe(true);

  const more = tournamentFrom(configJson({ pairings: [["luna", "don"], ["haiku-5-5", "luna"], ["opus", "story"]], blocksPerPairing: 3 }));
  const extended = openTournament(dir, more, "abc123", new Date(0));

  expect(Result.isSuccess(extended) && extended.success.schedule.slice(0, schedule.length)).toEqual([...schedule]);
  expect(Result.isSuccess(extended) && extended.success.schedule.slice(schedule.length).every((match) => match.block === 2)).toBe(true);

  const withRouter = { ...ENDPOINTS, router: { api: "openai-responses", url: "http://localhost:20128/v1", keyEnv: "ROUTER_KEY" } };

  const routed = (endpoints: Readonly<Record<string, Schema.Json>>) =>
    tournamentFrom(configJson({ endpoints, entrants: { ...ENTRANTS, routed: { endpoint: "router", model: "oc/routed", catalogModel: "gpt-6-luna", effort: "high" } }, pairings: [["luna", "don"], ["haiku-5-5", "luna"], ["opus", "story"], ["routed", "luna"]], blocksPerPairing: 3 }));

  expect(Result.isSuccess(openTournament(dir, routed(withRouter), "abc123", new Date(0)))).toBe(true);
  expect(Result.isFailure(openTournament(dir, routed({ ...withRouter, "cpa-openai": { ...ENDPOINTS["cpa-openai"], url: "http://127.0.0.1:9999/v1" } }), "abc123", new Date(0)))).toBe(true);
});

test("a finished match that disagrees with the schedule is left out, and its counts come from the manifest", () => {
  const tournament = tournamentFrom(configJson({ pairings: [["luna", "don"]], blocksPerPairing: 1 }));
  const dir = mkdtempSync(join(tmpdir(), "tournament-read-"));
  const [match] = scheduleOf(tournament);

  if (match === undefined) throw new Error("no match scheduled");

  writeManifest(dir, tournament, match, "finished");

  const played = readMatch(dir, tournament, match);

  expect(Result.isSuccess(played) && played.success.players).toEqual([
    { entrant: "luna", share: expect.any(Number), moves: 2, reminders: 1, interventions: 1 },
    { entrant: "don", share: expect.any(Number), moves: 0, reminders: 0, interventions: 0 },
  ].toSorted((a, b) => match.entrants.indexOf(a.entrant) - match.entrants.indexOf(b.entrant)));

  const manifest = JSON.parse(readFileSync(join(dir, match.name, "manifest.json"), "utf8"));
  const write = (changes: Readonly<Record<string, Schema.Json>>) => writeFileSync(join(dir, match.name, "manifest.json"), JSON.stringify({ ...manifest, ...changes }));

  write({ provenance: { agents: { A: { model: "gpt-6-luna", effort: "low" } } } });
  expect(Result.isFailure(readMatch(dir, tournament, match))).toBe(true);

  write({ provenance: { agents: { A: { model: "claude-haiku-5-5", effort: "high" } } } });
  expect(Result.isFailure(readMatch(dir, tournament, match))).toBe(true);

  write({ controllers: ["Agent", "Story"] });
  expect(Result.isFailure(readMatch(dir, tournament, match))).toBe(true);
});

const BASE_ENV = { PATH: "/usr/bin", HOME: "/home/x", PLAYER_A_ANT_KEY: "leaked-a", PLAYER_C_MODEL: "leaked-c", PLAYER_B_OAI_URL: "http://leaked" };

test("a match's child gets no PLAYER_* variable but its own, and no key shows in its command", () => {
  const tournament = tournamentFrom(configJson({ pairings: [["luna", "don", "haiku-5-5"]], blocksPerPairing: 1 }));
  const [match] = scheduleOf(tournament);
  const keys = resolveKeys(tournament.config, scheduleOf(tournament), { CPA_KEY: "sk-secret-value" });

  if (match === undefined || Result.isFailure(keys)) throw new Error("setup failed");

  const env = childEnv(BASE_ENV, tournament.config, match, keys.success);

  expect(Object.keys(env).filter((name) => name.startsWith("PLAYER_")).toSorted()).toEqual(["PLAYER_A_EFFORT", "PLAYER_A_MODEL", "PLAYER_A_OAI_KEY", "PLAYER_A_OAI_URL", "PLAYER_B_ANT_KEY", "PLAYER_B_ANT_URL", "PLAYER_B_EFFORT", "PLAYER_B_MODEL"]);
  expect(env).toMatchObject({ PATH: "/usr/bin", HOME: "/home/x", PLAYER_A_MODEL: "gpt-6-luna", PLAYER_A_EFFORT: "high", PLAYER_B_MODEL: "claude-haiku-5-5", PLAYER_B_ANT_KEY: "sk-secret-value" });
  expect(Redacted.value(keys.success.get("CPA_KEY") ?? Redacted.make(""))).toBe("sk-secret-value");

  const command = childCommand("/tmp/t/m", tournament.config, match);

  expect(command.join(" ")).not.toContain("sk-secret-value");
  expect(command.slice(0, 5)).toEqual(["nice", "-n", "10", "bun", "--no-env-file"]);
  expect(command.slice(command.indexOf("--seats"))).toEqual(["--seats", match.seats.join(","), "--rotation", "0", "--delivery", "on-turn"]);
});

test("a missing key variable is named and its value is never shown", () => {
  const tournament = tournamentFrom(configJson());
  const keys = resolveKeys(tournament.config, scheduleOf(tournament), { PATH: "/usr/bin" });

  expect(Result.isFailure(keys) && keys.failure.message).toContain("CPA_KEY");
});

test("the example tournament's models all start as arena agents from the variables the runner sets", async () => {
  const tournament = tournamentFrom(readFileSync(join(import.meta.dir, "../tournaments/cpa-medium.json"), "utf8"));
  const schedule = scheduleOf(tournament);
  const keys = resolveKeys(tournament.config, schedule, { CPA_KEY: "sk-test" });

  expect(Result.isSuccess(checkPrices(tournament, prices))).toBe(true);

  if (Result.isFailure(keys)) throw new Error(keys.failure.message);

  const agents = schedule.flatMap((match) => AGENTS.flatMap((letter) => (match.seats.includes(letter) ? [{ match, letter }] : [])));

  for (const { match, letter } of agents.filter(({ match: each }) => each.pairing >= 0 && each.name.endsWith("_b0_p0"))) {
    const env = Object.fromEntries(Object.entries(childEnv({}, tournament.config, match, keys.success)).flatMap(([name, value]) => (value === undefined ? [] : [[name, value]])));
    const exit = await Effect.runPromiseExit(agentEndpoint(letter).pipe(Effect.provideService(ConfigProvider.ConfigProvider, ConfigProvider.fromEnvRecord(env))));

    expect(Exit.isSuccess(exit) ? "ok" : `${match.name} ${letter}: ${String(exit.cause)}`).toBe("ok");
  }
});
