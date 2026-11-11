import { existsSync, mkdirSync, readFileSync, writeFileSync } from "node:fs";
import { join } from "node:path";
import { isDeepStrictEqual } from "node:util";

import { Option, Result, Schema } from "effect";

import { SeatCount } from "../domain.ts";
import { AgentId } from "./agent.ts";
import { type PriceTable, totalsBy } from "./cost.ts";
import { type CallLine, endingFault, faultsIn, faultsSinceLastMove, readCalls } from "./runlog.ts";
import {
  ScheduledMatch,
  assignAccounts,
  endpointOf,
  type MatchAccounts,
  type Tournament,
  TournamentConfig,
  TournamentError,
  modelEntrant,
  resolveConfig,
  scheduleOf,
  unfinished,
} from "./tournament.ts";
import { firstPositionOf } from "./seeds.ts";
import { type PlayedMatch, type Player, winShares } from "./tournament-stats.ts";

// A tournament directory: tournament.json and one directory per scheduled match,
// each with the arena's run files. tournament.json and the matches' manifests
// are the sources of truth; nothing else is kept in sync with them.

export const TOURNAMENT_FORMAT = 1;

export const TournamentFile = Schema.Struct({
  format: Schema.Literal(TOURNAMENT_FORMAT),
  config: TournamentConfig,
  created_at: Schema.String,
  git_commit: Schema.String,
  schedule: Schema.Array(ScheduledMatch),
});

export type TournamentFile = typeof TournamentFile.Type;

const fail = (message: string) => Result.fail(new TournamentError({ message }));

const fileOf = (dir: string) => join(dir, "tournament.json");

/** The directory's tournament.json, or an error that says why it can't be read. */
export const readTournamentFile = (dir: string): Result.Result<TournamentFile, TournamentError> =>
  existsSync(fileOf(dir))
    ? Result.mapError(Schema.decodeUnknownResult(Schema.fromJsonString(TournamentFile))(readFileSync(fileOf(dir), "utf8")), (error) => new TournamentError({ message: `${fileOf(dir)} is not valid: ${error.message}` }))
    : fail(`${dir} has no tournament.json`);

export const tournamentOf = (file: TournamentFile): Result.Result<Tournament, TournamentError> => resolveConfig(file.config);

/** A tournament grows by new entrants and endpoints, listed pairings after its own and more seed blocks, so the matches it already scheduled keep their names, seats, seeds and endpoints. */
const growsInto = (before: TournamentConfig, after: TournamentConfig): boolean => {
  const fixed = ({ endpoints: _endpoints, entrants: _entrants, pairings: _pairings, blocksPerPairing: _blocks, ...rest }: TournamentConfig) => rest;

  return (
    !("allOf" in before.pairings) &&
    !("allOf" in after.pairings) &&
    isDeepStrictEqual(fixed(before), fixed(after)) &&
    after.blocksPerPairing >= before.blocksPerPairing &&
    Object.entries(before.endpoints).every(([name, endpoint]) => {
      const next = after.endpoints[name];

      if (next === undefined) return false;

      const { accounts: previousAccounts, ...previousConnection } = endpoint;
      const { accounts: nextAccounts, ...nextConnection } = next;

      return isDeepStrictEqual(previousConnection, nextConnection) && (previousAccounts === undefined || isDeepStrictEqual(previousAccounts, nextAccounts));
    }) &&
    Object.entries(before.entrants).every(([name, entrant]) => isDeepStrictEqual(after.entrants[name], entrant)) &&
    isDeepStrictEqual(after.pairings.slice(0, before.pairings.length), before.pairings)
  );
};

const writeFile = (dir: string, file: TournamentFile) => {
  mkdirSync(dir, { recursive: true });
  writeFileSync(fileOf(dir), `${JSON.stringify(Schema.encodeSync(TournamentFile)(file), null, 2)}\n`);

  return file;
};

/** Starts the directory's tournament, confirms that this config is the one it holds, or grows it: this config's new matches go after the ones scheduled, in the order scheduleOf gives them. */
export const openTournament = (dir: string, tournament: Tournament, gitCommit: string, now: Date): Result.Result<TournamentFile, TournamentError> => {
  if (!existsSync(fileOf(dir))) return Result.succeed(writeFile(dir, { format: TOURNAMENT_FORMAT, config: tournament.config, created_at: now.toISOString(), git_commit: gitCommit, schedule: scheduleOf(tournament) }));

  return Result.flatMap(readTournamentFile(dir), (file) => {
    // A config the tournament has already grown from is part of it, as when a run with several configs is repeated.
    if (isDeepStrictEqual(file.config, tournament.config) || growsInto(tournament.config, file.config)) return Result.succeed(file);

    if (growsInto(file.config, tournament.config)) {
      const scheduled = new Set(file.schedule.map((match) => match.name));

      return Result.succeed(writeFile(dir, { ...file, config: tournament.config, schedule: [...file.schedule, ...scheduleOf(tournament).filter((match) => !scheduled.has(match.name))] }));
    }

    return fail(`${dir} holds the tournament "${file.config.name}", made from a different config; use a new --dir, the config it was made from, or that config with entrants, seed blocks, or listed pairings after its own added`);
  });
};

/** What a tournament reads of a match's manifest. */
const Described = Schema.Struct({ api: Schema.String, url: Schema.NullOr(Schema.String), model: Schema.String, catalog_model: Schema.NullOr(Schema.String), effort: Schema.NullOr(Schema.String), instructions_addendum: Schema.optional(Schema.String) });

/** The provenance `api` of a config endpoint's api: the Endpoint tag in endpoints.ts. */
const API_TAG = { anthropic: "Anthropic", "openai-responses": "OpenAIResponses" } as const;

/** A config URL as provenance records it: baseUrlOf in endpoints.ts, kept local so this module does not pull in the endpoint code. */
const baseUrl = (url: string): string => new URL(url).href.replace(/\/$/, "");

/** What a tournament and the importer read of a match manifest. */
export const MatchManifest = Schema.Struct({
  status: Schema.String,
  seed: Schema.String,
  controllers: Schema.Array(Schema.String),
  letters: Schema.Array(Schema.String),
  delivery: Schema.String,
  standings: Schema.optional(Schema.Array(Schema.Struct({ player: Schema.String, cash: Schema.Number }))),
  provenance: Schema.Struct({ git_commit: Schema.optional(Schema.String), agents: Schema.Record(Schema.String, Described) }),
  agents: Schema.Record(Schema.String, Schema.Struct({ moves: Schema.Int, reminders: Schema.Int, interventions: Schema.Int })),
});

export type MatchManifest = typeof MatchManifest.Type;

const readManifest = (dir: string): Result.Result<MatchManifest, string> => {
  const path = join(dir, "manifest.json");

  return existsSync(path) ? Result.mapError(Schema.decodeUnknownResult(Schema.fromJsonString(MatchManifest))(readFileSync(path, "utf8")), (error) => `manifest.json is not readable: ${error.message}`) : Result.fail("there is no manifest.json");
};

const StatusOnly = Schema.Struct({ status: Schema.String });

const CodeOnly = Schema.Struct({ provenance: Schema.Struct({ git_commit: Schema.String }) });

/** The code version a match started under, as its manifest records it; none before it starts. */
export const startedUnder = (dir: string, match: ScheduledMatch): Option.Option<string> => {
  const path = join(dir, match.name, "manifest.json");

  return existsSync(path) ? Option.map(Result.getSuccess(Schema.decodeUnknownResult(Schema.fromJsonString(CodeOnly))(readFileSync(path, "utf8"))), ({ provenance }) => provenance.git_commit) : Option.none();
};

/** An agent's pin; older manifests name it cpa_auth_id. */
const AccountProvenance = Schema.Struct({ provenance: Schema.Struct({ agents: Schema.Record(Schema.String, Schema.Struct({ account_id: Schema.optional(Schema.String), cpa_auth_id: Schema.optional(Schema.String) })) }) });

/** A started match keeps exactly its recorded pins, including no pins on older matches. */
export const recordedAccounts = (dir: string, match: ScheduledMatch): MatchAccounts | undefined => {
  const path = join(dir, match.name, "manifest.json");

  if (!existsSync(path)) return undefined;

  const manifest = Schema.decodeUnknownSync(Schema.fromJsonString(AccountProvenance))(readFileSync(path, "utf8"));

  return Object.fromEntries(Object.entries(manifest.provenance.agents).flatMap(([agent, provenance]) => {
    const account = provenance.account_id ?? provenance.cpa_auth_id;

    return account === undefined ? [] : [[agent, account]];
  }));
};

const isFinished = (matchDir: string): boolean => {
  const path = join(matchDir, "manifest.json");

  return existsSync(path) && Result.match(Schema.decodeUnknownResult(Schema.fromJsonString(StatusOnly))(readFileSync(path, "utf8")), { onFailure: () => false, onSuccess: ({ status }) => status === "finished" });
};

/** The names of the scheduled matches whose manifest says finished. It reads only the status, so a finished match is never run again over another field. */
export const finishedNames = (dir: string, schedule: ReadonlyArray<ScheduledMatch>): ReadonlySet<string> => new Set(schedule.flatMap((match) => (isFinished(join(dir, match.name)) ? [match.name] : [])));

const isLetter = Schema.is(AgentId);

/** The ways a finished match's manifest differs from what the schedule asked for. */
export const manifestProblems = (tournament: Tournament, match: ScheduledMatch, manifest: MatchManifest): ReadonlyArray<string> => {
  const { config } = tournament;
  const controllers = match.seats.map((seat) => (isLetter(seat) ? "Agent" : seat));

  const seats = match.seats.flatMap((seat, index) => {
    const entrant = modelEntrant(config, match.entrants[index] ?? "");
    const endpoint = endpointOf(config, match.entrants[index] ?? "");

    if (!isLetter(seat) || entrant === undefined || endpoint === undefined) return [];

    const played = manifest.provenance.agents[seat];

    if (played === undefined) return [`the manifest does not say which model agent ${seat} played`];

    return [
      ...(played.model === entrant.model ? [] : [`agent ${seat} played ${played.model}, the schedule says ${entrant.model}`]),
      ...(played.api === API_TAG[endpoint.api] ? [] : [`agent ${seat} played through the ${played.api} API, the schedule says ${API_TAG[endpoint.api]}`]),
      ...(played.url === baseUrl(endpoint.url) ? [] : [`agent ${seat} played at ${played.url ?? "no URL"}, the schedule says ${baseUrl(endpoint.url)}`]),
      ...(played.catalog_model === (entrant.catalogModel ?? null) ? [] : [`agent ${seat} played as the catalog model ${played.catalog_model ?? "unset"}, the schedule says ${entrant.catalogModel ?? "unset"}`]),
      ...(played.effort === entrant.effort ? [] : [`agent ${seat} played at effort ${played.effort ?? "unset"}, the schedule says ${entrant.effort}`]),
      ...(played.instructions_addendum === entrant.instructionsAddendum ? [] : [`agent ${seat} played with the instructions addendum ${JSON.stringify(played.instructions_addendum ?? null)}, the schedule says ${JSON.stringify(entrant.instructionsAddendum ?? null)}`]),
      ...(manifest.letters[index] === seat ? [] : [`position ${index + 1} is player ${manifest.letters[index] ?? "none"}, the schedule says ${seat}`]),
    ];
  });

  return [
    ...(isDeepStrictEqual(manifest.controllers, controllers) ? [] : [`controllers are ${manifest.controllers.join(",")}, the schedule says ${controllers.join(",")}`]),
    ...(manifest.seed === String(match.seed) ? [] : [`seed is ${manifest.seed}, the schedule says ${match.seed}`]),
    ...(manifest.delivery === config.delivery ? [] : [`delivery is ${manifest.delivery}, the schedule says ${config.delivery}`]),
    ...seats,
  ];
};

/** What one entrant did in a match, from the manifest; a bot's counts are zero. */
const countsOf = (manifest: MatchManifest, seat: string) => manifest.agents[seat] ?? { moves: 0, reminders: 0, interventions: 0 };

/** Each player's share of the win, in table order, from the manifest's standings. */
const sharesOf = (match: ScheduledMatch, manifest: MatchManifest): Result.Result<ReadonlyArray<number>, string> => {
  const cash = match.seats.map((_, index) => manifest.standings?.find((standing) => standing.player === manifest.letters[index])?.cash);

  return cash.every((amount) => amount !== undefined) ? Result.succeed(winShares(cash)) : Result.fail("the standings do not cover every player");
};

const decodeSeatCount = Schema.decodeUnknownResult(SeatCount);

/** A finished match as a played one, or why it is left out. */
export const readMatch = (dir: string, tournament: Tournament, match: ScheduledMatch): Result.Result<PlayedMatch, ReadonlyArray<string>> =>
  Result.gen(function* () {
    const matchDir = join(dir, match.name);
    const manifest = yield* Result.mapError(readManifest(matchDir), (message) => [message]);
    const problems = manifestProblems(tournament, match, manifest);

    if (problems.length > 0) return yield* Result.fail(problems);

    const code = manifest.provenance.git_commit;

    if (code === undefined) return yield* Result.fail(["the manifest records no git commit, so the match started before the code version was one (ADR-0054)"]);

    const shares = yield* Result.mapError(sharesOf(match, manifest), (message) => [message]);
    const table = yield* Result.mapError(decodeSeatCount(match.seats.length), () => [`${match.seats.length} seats is not a table size`]);
    const players: ReadonlyArray<Player> = match.entrants.map((entrant, index) => ({ entrant, share: shares[index] ?? 0, ...countsOf(manifest, match.seats[index] ?? "") }));

    return { name: match.name, pairing: match.pairing, seed: match.seed, code, starter: firstPositionOf(match.seed, table), players };
  });

/** The entrants that won a finished match, from its manifest alone, even when the match is left out of the stats. */
export const winnersOf = (dir: string, match: ScheduledMatch): ReadonlyArray<string> =>
  Result.match(
    Result.flatMap(readManifest(join(dir, match.name)), (manifest) => sharesOf(match, manifest)),
    { onFailure: () => [], onSuccess: (shares) => match.entrants.filter((_, index) => (shares[index] ?? 0) > 0) },
  );

/** The model calls of a match, each with the entrant that made it. */
export const callsOf = (dir: string, match: ScheduledMatch): ReadonlyArray<readonly [string, CallLine]> =>
  readCalls(join(dir, match.name)).map((call) => [match.entrants[match.seats.indexOf(call.agent)] ?? call.agent, call] as const);

/** The entrant each provider fault of a match stopped it on. A fault pauses a match to be resumed; it is never a move or a loss. */
export const faultsOf = (dir: string, match: ScheduledMatch): ReadonlyArray<string> => faultsIn(join(dir, match.name)).map((agent) => match.entrants[match.seats.indexOf(agent)] ?? agent);

/** Dollars spent in these matches, from their calls and the price table. */
export const costOf = (dir: string, prices: PriceTable, matches: ReadonlyArray<ScheduledMatch>): number =>
  [...totalsBy(prices, matches.flatMap((match) => callsOf(dir, match))).values()].reduce((total, entrant) => total + entrant.dollars, 0);

/** A model its provider refuses until a time, after a usage or rate limit. */
export interface Cooldown {
  readonly model: string;
  readonly account?: string;
  /** Milliseconds since the epoch. */
  readonly until: number;
}

/** A provider's usage-limit refusal, with the seconds until it resets: the proxy's model cooldown, or the upstream limit it passes on. */
const UsageLimit = Schema.Union([
  Schema.Struct({ code: Schema.Literal("model_cooldown"), reset_seconds: Schema.Number }),
  Schema.Struct({ type: Schema.Literal("usage_limit_reached"), resets_in_seconds: Schema.Number }),
]);

const decodeUsageLimit = Schema.decodeUnknownOption(Schema.fromJsonString(UsageLimit));

/** How long a model waits after a 429 that gives no reset time. Each further refusal of the match, with no move between, doubles the wait, at most MOST_DOUBLINGS times. */
export const RATE_LIMIT_WAIT_SECONDS = 120;

const MOST_DOUBLINGS = 4;

/** pi-ai shows the status as "API error (429)" for OpenAI and first for Anthropic. */
const isRateLimit = (error: string): boolean => /^429 |API error \(429\)/.test(error);

/**
 * The seconds until a provider takes the model again, when the error is a usage or rate limit: a usage limit with its
 * reset, a router's "reset after 1m 30s" (once every account of a model is limited), or else any 429, which
 * waits RATE_LIMIT_WAIT_SECONDS, doubled for each earlier refusal in a row.
 */
const limitSecondsOf = (error: string, refusals: number): Option.Option<number> => {
  const usageLimit = Option.map(decodeUsageLimit(error.slice(error.indexOf("{"))), (limit) => ("code" in limit ? limit.reset_seconds : limit.resets_in_seconds));
  const routerLimit = Option.map(Option.fromNullishOr(/reset after (?:(\d+)h ?)?(?:(\d+)m ?)?(?:(\d+)s)?/.exec(error)), ([, hours = "0", minutes = "0", seconds = "0"]) => 3600 * Number(hours) + 60 * Number(minutes) + Number(seconds));
  const rateLimit = isRateLimit(error) ? Option.some(RATE_LIMIT_WAIT_SECONDS * 2 ** Math.min(refusals - 1, MOST_DOUBLINGS)) : Option.none();

  return Option.firstSomeOf([usageLimit, routerLimit, rateLimit]);
};

/** The cooldown the match's last run ended on, while it lasts: a fault whose error is a usage or rate limit, for the model of the agent it stopped. */
export const cooldownOf = (dir: string, config: TournamentConfig, match: ScheduledMatch, now: number): Option.Option<Cooldown> =>
  Option.flatMap(endingFault(join(dir, match.name)), (fault) => {
    const entrant = modelEntrant(config, match.entrants[match.seats.indexOf(fault.agent)] ?? "");
    const account = recordedAccounts(dir, match)?.[fault.agent];
    const refusals = faultsSinceLastMove(join(dir, match.name)).filter((earlier) => earlier.agent === fault.agent && isRateLimit(earlier.error)).length;

    return Option.filter(
      Option.flatMap(limitSecondsOf(fault.error, refusals), (seconds) => {
        if (entrant === undefined) return Option.none();

        const cooldown = { model: entrant.model, until: Date.parse(fault.t) + 1000 * seconds };

        return Option.some(account === undefined ? cooldown : { ...cooldown, account });
      }),
      ({ until }) => until > now,
    );
  });

export type Settled =
  | { readonly match: ScheduledMatch; readonly status: "finished" | "failed" }
  /** Stopped by a model's usage limit: it waits for the reset, and the stop is not a failed run. */
  | { readonly match: ScheduledMatch; readonly status: "cooling"; readonly cooldown: Cooldown };

/** What happens to a failed match: when it ended on a provider fault (network, timeout, an error status), it goes to the back of the queue, for `attempts` runs in all; any other failure is deterministic and final, and its slot waits `pauseMs` first, so a provider's cooldown has fewer matches at once. */
export interface Retry {
  readonly attempts: number;
  readonly pauseMs: number;
}

export const RETRY: Retry = { attempts: 3, pauseMs: 120_000 };

/** How long a slot with no match to start waits before it looks again, at most. */
const IDLE_MS = 60_000;

const pause = (ms: number, stop: AbortSignal) =>
  new Promise<void>((resume) => {
    if (stop.aborted) return resume();

    const timer = setTimeout(resume, ms);

    stop.addEventListener("abort", () => (clearTimeout(timer), resume()), { once: true });
  });

/** How runPending treats models: `caps` holds the most matches a model plays at once, for a model with a tight rate limit; a match with a model in `last` starts only when no other match can; a recorded cooldown of a model in `forget` is not read at the start, as when its provider reset early; a new match pins the `prefer` accounts first among equally loaded ones, as when the operator picks the account that resets soonest. */
export interface Scheduling {
  readonly retry?: Retry;
  readonly caps?: ReadonlyMap<string, number>;
  readonly last?: ReadonlySet<string>;
  readonly forget?: ReadonlySet<string>;
  readonly prefer?: ReadonlyArray<string>;
}

/**
 * Runs the matches that are not finished, in schedule order, at most `parallel` at a time. `runOne` plays one and gives
 * its exit code. A match is finished when it exited 0 and its manifest says so. One stopped by a model's usage limit
 * goes back to the front of the queue. Its model/account pair waits until reset when pinned, otherwise its model
 * waits. Earlier cooldowns are read from the matches' logs at the start. A failure on a provider fault is retried as `retry` says, and then left for the
 * next run.
 */
export const runPending = async (
  dir: string,
  config: TournamentConfig,
  schedule: ReadonlyArray<ScheduledMatch>,
  parallel: number,
  runOne: (match: ScheduledMatch, accounts: MatchAccounts) => Promise<number>,
  onSettled: (settled: Settled) => void,
  stop: AbortSignal,
  { retry = RETRY, caps = new Map(), last = new Set(), forget = new Set(), prefer = [] }: Scheduling = {},
): Promise<ReadonlyArray<Settled>> => {
  const settled: Array<Settled> = [];
  const queue = [...unfinished(schedule, finishedNames(dir, schedule))];
  const failures = new Map<string, number>();
  const coolingUntil = new Map<string, number>();

  const playing = new Map<string, number>();

  const modelsOf = (match: ScheduledMatch) => new Set(match.entrants.flatMap((name) => modelEntrant(config, name)?.model ?? []));
  const cooldownKey = (model: string, account?: string) => JSON.stringify([model, account ?? null]);

  const cool = ({ model, account, until }: Cooldown) => {
    const key = cooldownKey(model, account);

    coolingUntil.set(key, Math.max(until, coolingUntil.get(key) ?? 0));
  };

  const isCooling = (model: string, account?: string) => (coolingUntil.get(cooldownKey(model, account)) ?? 0) > Date.now();
  const assigned = new Map<string, MatchAccounts>();
  const accountLoad = new Map<string, number>();
  const accountsFor = (match: ScheduledMatch) => assigned.get(match.name) ?? assignAccounts(config, match, isCooling, (account) => accountLoad.get(account) ?? 0, prefer);

  const isReady = (match: ScheduledMatch) => {
    if (![...modelsOf(match)].every((model) => !isCooling(model) && (playing.get(model) ?? 0) < (caps.get(model) ?? Infinity))) return false;

    const accounts = accountsFor(match);

    return accounts !== undefined && match.seats.every((seat, index) => {
      const entrant = modelEntrant(config, match.entrants[index] ?? "");

      return entrant === undefined || !isCooling(entrant.model, accounts[seat]);
    });
  };

  const isLast = (match: ScheduledMatch) => [...modelsOf(match)].some((model) => last.has(model));

  const countPlaying = (match: ScheduledMatch, change: 1 | -1) => {
    for (const model of modelsOf(match)) playing.set(model, (playing.get(model) ?? 0) + change);

    for (const account of new Set(Object.values(assigned.get(match.name) ?? {}))) accountLoad.set(account, (accountLoad.get(account) ?? 0) + change);
  };

  // A slot with nothing to start waits until a reset, a minute, or the end of a
  // match, which can free a capped model.
  let matchEnded = new AbortController();

  const nextReset = () => Math.min(...[...coolingUntil.values()].filter((until) => until > Date.now()));

  for (const match of queue) {
    const accounts = recordedAccounts(dir, match);

    if (accounts !== undefined) assigned.set(match.name, accounts);

    Option.match(Option.filter(cooldownOf(dir, config, match, Date.now()), ({ model }) => !forget.has(model)), { onNone: () => undefined, onSome: cool });
  }

  const slot = async (): Promise<void> => {
    while (queue.length > 0 && !stop.aborted) {
      const first = queue.findIndex((candidate) => isReady(candidate) && !isLast(candidate));
      const at = first === -1 ? queue.findIndex(isReady) : first;
      const match = at === -1 ? undefined : queue.splice(at, 1)[0];

      if (match === undefined) {
        await pause(Math.min(IDLE_MS, nextReset() - Date.now()), AbortSignal.any([stop, matchEnded.signal]));
        continue;
      }

      const accounts = accountsFor(match);

      if (accounts === undefined) throw new Error("a ready match has no available accounts");

      assigned.set(match.name, accounts);
      countPlaying(match, 1);
      const exitCode = await runOne(match, accounts);
      countPlaying(match, -1);
      matchEnded.abort();
      matchEnded = new AbortController();
      const cooldown = cooldownOf(dir, config, match, Date.now());

      const result: Settled =
        exitCode === 0 && isFinished(join(dir, match.name))
          ? { match, status: "finished" }
          : Option.match(cooldown, { onNone: () => ({ match, status: "failed" as const }), onSome: (value) => ({ match, status: "cooling" as const, cooldown: value }) });

      settled.push(result);
      onSettled(result);

      if (result.status === "cooling") {
        cool(result.cooldown);
        queue.unshift(match);
      }

      if (result.status === "failed") {
        const failed = (failures.get(match.name) ?? 0) + 1;

        failures.set(match.name, failed);

        if (failed < retry.attempts && Option.isSome(endingFault(join(dir, match.name)))) queue.push(match);

        await pause(retry.pauseMs, stop);
      }
    }
  };

  await Promise.all(Array.from({ length: parallel }, slot));

  return settled;
};
