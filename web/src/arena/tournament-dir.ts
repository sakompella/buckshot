import { existsSync, mkdirSync, readFileSync, writeFileSync } from "node:fs";
import { join } from "node:path";
import { isDeepStrictEqual } from "node:util";

import { Result, Schema } from "effect";

import { AgentId } from "./agent.ts";
import { type PriceTable, totalsBy } from "./cost.ts";
import { type CallLine, faultsIn, readCalls } from "./runlog.ts";
import {
  ScheduledMatch,
  type Tournament,
  TournamentConfig,
  TournamentError,
  modelEntrant,
  resolveConfig,
  scheduleOf,
  unfinished,
} from "./tournament.ts";
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

/** A tournament grows by new entrants, listed pairings after its own and more seed blocks, so the matches it already scheduled keep their names, seats and seeds. */
const growsInto = (before: TournamentConfig, after: TournamentConfig): boolean => {
  const fixed = ({ entrants: _entrants, pairings: _pairings, blocksPerPairing: _blocks, ...rest }: TournamentConfig) => rest;

  return (
    !("allOf" in before.pairings) &&
    !("allOf" in after.pairings) &&
    isDeepStrictEqual(fixed(before), fixed(after)) &&
    after.blocksPerPairing >= before.blocksPerPairing &&
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
const Described = Schema.Struct({ model: Schema.String, effort: Schema.NullOr(Schema.String) });

const MatchManifest = Schema.Struct({
  status: Schema.String,
  seed: Schema.String,
  controllers: Schema.Array(Schema.String),
  letters: Schema.Array(Schema.String),
  delivery: Schema.String,
  standings: Schema.optional(Schema.Array(Schema.Struct({ player: Schema.String, cash: Schema.Number }))),
  provenance: Schema.Struct({ agents: Schema.Record(Schema.String, Described) }),
  agents: Schema.Record(Schema.String, Schema.Struct({ moves: Schema.Int, reminders: Schema.Int, interventions: Schema.Int })),
});

type MatchManifest = typeof MatchManifest.Type;

const readManifest = (dir: string): Result.Result<MatchManifest, string> => {
  const path = join(dir, "manifest.json");

  return existsSync(path) ? Result.mapError(Schema.decodeUnknownResult(Schema.fromJsonString(MatchManifest))(readFileSync(path, "utf8")), (error) => `manifest.json is not readable: ${error.message}`) : Result.fail("there is no manifest.json");
};

const StatusOnly = Schema.Struct({ status: Schema.String });

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

    if (!isLetter(seat) || entrant === undefined) return [];

    const played = manifest.provenance.agents[seat];

    if (played === undefined) return [`the manifest does not say which model agent ${seat} played`];

    return [
      ...(played.model === entrant.model ? [] : [`agent ${seat} played ${played.model}, the schedule says ${entrant.model}`]),
      ...(played.effort === entrant.effort ? [] : [`agent ${seat} played at effort ${played.effort ?? "unset"}, the schedule says ${entrant.effort}`]),
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

/** A finished match as a played one, or why it is left out. */
export const readMatch = (dir: string, tournament: Tournament, match: ScheduledMatch): Result.Result<PlayedMatch, ReadonlyArray<string>> =>
  Result.gen(function* () {
    const matchDir = join(dir, match.name);
    const manifest = yield* Result.mapError(readManifest(matchDir), (message) => [message]);
    const problems = manifestProblems(tournament, match, manifest);

    if (problems.length > 0) return yield* Result.fail(problems);

    const shares = yield* Result.mapError(sharesOf(match, manifest), (message) => [message]);
    const players: ReadonlyArray<Player> = match.entrants.map((entrant, index) => ({ entrant, share: shares[index] ?? 0, ...countsOf(manifest, match.seats[index] ?? "") }));

    return { name: match.name, pairing: match.pairing, block: match.block, players };
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

export interface Settled {
  readonly match: ScheduledMatch;
  readonly status: "finished" | "failed";
}

/** What happens to a failed match: it goes to the back of the queue, for `attempts` runs in all, and its slot waits `pauseMs` first, so a provider's cooldown has fewer matches at once. */
export interface Retry {
  readonly attempts: number;
  readonly pauseMs: number;
}

export const RETRY: Retry = { attempts: 3, pauseMs: 120_000 };

const pause = (ms: number, stop: AbortSignal) =>
  new Promise<void>((resume) => {
    if (stop.aborted) return resume();

    const timer = setTimeout(resume, ms);

    stop.addEventListener("abort", () => (clearTimeout(timer), resume()), { once: true });
  });

/**
 * Runs the matches that are not finished, in schedule order, at most `parallel` at a time. `runOne` plays one and gives
 * its exit code. A match is finished when it exited 0 and its manifest says so; any other is retried as `retry` says,
 * and then left for the next run.
 */
export const runPending = async (
  dir: string,
  schedule: ReadonlyArray<ScheduledMatch>,
  parallel: number,
  runOne: (match: ScheduledMatch) => Promise<number>,
  onSettled: (settled: Settled) => void,
  stop: AbortSignal,
  retry: Retry = RETRY,
): Promise<ReadonlyArray<Settled>> => {
  const settled: Array<Settled> = [];
  const queue = [...unfinished(schedule, finishedNames(dir, schedule))];
  const failures = new Map<string, number>();

  const slot = async (): Promise<void> => {
    for (let match = queue.shift(); match !== undefined && !stop.aborted; match = queue.shift()) {
      const exitCode = await runOne(match);
      const result: Settled = { match, status: exitCode === 0 && isFinished(join(dir, match.name)) ? "finished" : "failed" };

      settled.push(result);
      onSettled(result);

      if (result.status === "failed") {
        const failed = (failures.get(match.name) ?? 0) + 1;

        failures.set(match.name, failed);

        if (failed < retry.attempts) queue.push(match);

        await pause(retry.pauseMs, stop);
      }
    }
  };

  await Promise.all(Array.from({ length: parallel }, slot));

  return settled;
};
