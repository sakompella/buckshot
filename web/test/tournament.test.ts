import { expect, test } from "bun:test";
import { mkdirSync, mkdtempSync, readFileSync, writeFileSync } from "node:fs";
import { tmpdir } from "node:os";
import { join } from "node:path";

import { ConfigProvider, Effect, Exit, Redacted, Result, type Schema } from "effect";

import { AGENTS } from "../src/arena/agent.ts";
import { DEFAULT_PRICES, loadPrices } from "../src/arena/cost.ts";
import { agentEndpoint } from "../src/arena/endpoints.ts";
import { checkPrices, childCommand, childEnv, parseConfig, resolveKeys, type ScheduledMatch, scheduleOf, type Tournament, unfinished } from "../src/arena/tournament.ts";
import { costOf, openTournament, readMatch, runPending, TOURNAMENT_FORMAT } from "../src/arena/tournament-dir.ts";
import { reportOf } from "../src/arena/tournament-report.ts";
import { fitRatings, ELO_PER_NAT, intervalsOf, type PlayedMatch, resamples, sharesByEntrant, winShares } from "../src/arena/tournament-stats.ts";

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

    return { name: match.name, pairing: match.pairing, block: match.block, players: match.entrants.map((entrant, index) => ({ entrant, share: index === winner ? 1 : 0, moves: 10, reminders: 0, interventions: 0 })) };
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
    provenance: { agents },
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
  const first = await runPending(dir, schedule, 2, fake(broken, interrupted), () => undefined, interrupted.signal);

  expect(first.length).toBeLessThan(schedule.length);

  const second = await runPending(dir, schedule, 2, fake(broken, new AbortController()), () => undefined, new AbortController().signal);

  expect(second.filter(({ status }) => status === "failed").map(({ match }) => match.name)).toEqual([...broken]);

  const third = await runPending(dir, schedule, 2, fake(new Set(), new AbortController()), () => undefined, new AbortController().signal);

  expect(third.map(({ match }) => match.name)).toEqual([...broken]);
  expect(third.every(({ status }) => status === "finished")).toBe(true);
  expect([...ran].toSorted()).toEqual([...schedule.map((match) => match.name), ...broken].toSorted());
  expect(unfinished(schedule, new Set(schedule.map((match) => match.name)))).toEqual([]);
  expect((await runPending(dir, schedule, 2, fake(new Set(), new AbortController()), () => undefined, new AbortController().signal)).length).toBe(0);

  const [opening] = schedule;
  const at = opening?.seats.findIndex((seat) => AGENTS.some((letter) => letter === seat)) ?? -1;
  const entrant = tournament.config.entrants[opening?.entrants[at] ?? ""];

  if (opening === undefined || entrant === undefined || !("model" in entrant)) throw new Error("the first match has no model");

  const call = { t: "2026-10-16T00:00:00Z", agent: opening.seats[at], position: at + 1, provider: "p", api: "a", model: entrant.model, stop_reason: "stop", usage: { input: 1000, output: 0, cacheRead: 0, cacheWrite: 0 }, tool_calls: [], text: "", thinking: "" };

  writeFileSync(join(dir, opening.name, "calls.jsonl"), `${JSON.stringify(call)}\n`);

  const priced = (prices.models[entrant.model]?.input ?? NaN) * 1000 / 1_000_000;
  const report = reportOf(dir, { format: TOURNAMENT_FORMAT, config: tournament.config, created_at: "", git_commit: "", schedule }, tournament, prices, 20);

  expect(report.matches).toEqual({ scheduled: schedule.length, finished: schedule.length, scored: schedule.length });
  expect(report.excluded).toEqual([]);
  expect(report.anchor).toBe("don");
  expect(report.cost.find((row) => row.entrant === opening.entrants[at])).toMatchObject({ calls: 1, dollars: priced });
  expect(costOf(dir, prices, schedule)).toBe(priced);
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
