import { spawn } from "node:child_process";
import { appendFileSync, closeSync, mkdirSync, openSync, readFileSync } from "node:fs";
import { basename, join, resolve } from "node:path";

import { Option, Result } from "effect";

import { DEFAULT_PRICES, loadPrices } from "../src/arena/cost.ts";
import { checkPrices, childCommand, childEnv, parseConfig, resolveKeys, type ScheduledMatch, type MatchAccounts, scheduleOf, type TournamentError, unfinished } from "../src/arena/tournament.ts";
import { codeSha } from "../src/arena/match.ts";
import { cooldownOf, costOf, faultsOf, finishedNames, openTournament, runPending, type Settled, startedUnder, winnersOf } from "../src/arena/tournament-dir.ts";

// Plays a tournament: every scheduled match, in schedule order, as a child
// process running scripts/arena.ts, at most --parallel at a time (default 5).
// The config says who plays whom, as tournaments/cpa-medium.json does. The
// first run writes <dir>/tournament.json, and a later run needs the same
// config, or one that grows it; with several configs, each grows the tournament
// in turn, so their new matches play in that order. Keys come from the
// environment, and Bun loads web/.env for this script; each match gets only its
// own PLAYER_* variables. A match stopped by a model's usage or rate limit (a
// 429) waits for the reset, with matches on that model/account pair when pinned,
// or every match of that model otherwise, and does not count
// as failed; other matches fill the slots. --cap <model>=N, given once per
// model, plays at most N matches of that model at once; --last <model> starts
// its matches only when no other match can; --forget-cooldown <model> ignores
// the model's recorded cooldowns at the start, after its provider reset early;
// --skip <entrant> leaves that entrant's matches unplayed this run; --prefer-account <CPA auth id>, in order of
// preference, pins new matches to those accounts first when accounts are equally loaded.
// A match resumes under the code version it started under (its manifest's
// code_sha), so a tournament can span versions: --code <code_sha>=<web dir>,
// once per older version, names a checkout of it to resume its matches from,
// and without one they wait. New matches start under this checkout's code.
// A match that fails goes to the back of the queue after a pause, up to three
// runs, and the rest go on. Rerun the same command to resume: finished matches
// never run again. Do not run two of these on one directory. --limit plays at
// most that many matches. The runner appends a line to <dir>/PROGRESS.md when
// it starts, every 30 minutes and when it ends. --dry-run prints the schedule
// of the last config.
// Usage: bun scripts/arena-tournament.ts <config.json>... --dir <tournament dir> [--parallel N] [--cap <model>=N]... [--last <model>]...
//          [--forget-cooldown <model>]... [--skip <entrant>]... [--prefer-account <id>]... [--code <code_sha>=<web dir>]... [--limit N] [--dry-run]
//        bun scripts/arena-stats.ts <tournament dir> [--json]

const WEB = join(import.meta.dir, "..");

const args = process.argv.slice(2);

const flag = (name: string): string | undefined => {
  const at = args.indexOf(`--${name}`);

  return at === -1 ? undefined : args[at + 1];
};

const VALUED = new Set(["--dir", "--parallel", "--limit", "--cap", "--last", "--forget-cooldown", "--skip", "--prefer-account", "--code"]);

const configPaths = args.filter((arg, index) => !arg.startsWith("--") && !VALUED.has(args[index - 1] ?? ""));

const parallel = Number(flag("parallel") ?? "5");

const limit = flag("limit") === undefined ? undefined : Number(flag("limit"));

/** The values of a flag given once per value, as --cap is. */
const repeated = (name: string): ReadonlyArray<string> => args.flatMap((arg, index) => (arg === `--${name}` ? [args[index + 1] ?? ""] : []));

const exit = (message: string): never => {
  console.error(message);

  return process.exit(1);
};

const unwrap = <A>(result: Result.Result<A, TournamentError>): A => Result.match(result, { onFailure: (error) => exit(error.message), onSuccess: (value) => value });

if (configPaths.length === 0) exit("Usage: bun scripts/arena-tournament.ts <config.json>... --dir <tournament dir> [--parallel N] [--cap <model>=N]... [--last <model>]... [--forget-cooldown <model>]... [--skip <entrant>]... [--prefer-account <id>]... [--code <code_sha>=<web dir>]... [--limit N] [--dry-run]");

if (!Number.isInteger(parallel) || parallel < 1) exit("--parallel must be a whole number from 1");

if (limit !== undefined && (!Number.isInteger(limit) || limit < 1)) exit("--limit must be a whole number from 1");

const caps = new Map(
  repeated("cap").map((cap) => {
    const [, model = "", most = ""] = /^(.+)=([1-9]\d*)$/.exec(cap) ?? exit(`--cap takes <model>=<matches at once>, not "${cap}"`);

    return [model, Number(most)] as const;
  }),
);

const last = new Set(repeated("last"));

const forget = new Set(repeated("forget-cooldown"));

const skipped = new Set(repeated("skip"));

const prefer = repeated("prefer-account");

const CODE = codeSha();

/** Checkouts of older code versions, by code_sha, for the matches that started under them. */
const checkouts = new Map(
  repeated("code").map((entry) => {
    const [, code = "", web = ""] = /^([0-9a-f]+)=(.+)$/.exec(entry) ?? exit(`--code takes <code_sha>=<web dir>, not "${entry}"`);

    return [code, resolve(web)] as const;
  }),
);

const prices = loadPrices(DEFAULT_PRICES);

const tournaments = configPaths.map((path) => {
  const parsed = unwrap(parseConfig(readFileSync(path, "utf8")));

  unwrap(checkPrices(parsed, prices));

  return parsed;
});

const tournament = tournaments.at(-1) ?? exit("no config");

const money = (dollars: number): string => `$${dollars.toFixed(4)}`;

if (args.includes("--dry-run")) {
  const schedule = scheduleOf(tournament);
  const { name, delivery, blocksPerPairing } = tournament.config;

  console.log(`${name}: ${tournament.pairings.length} pairings, ${blocksPerPairing} block${blocksPerPairing === 1 ? "" : "s"} each, ${schedule.length} matches, ${delivery} delivery`);

  for (const [index, pairing] of tournament.pairings.entries()) console.log(`  ${pairing.join(" vs ")}: ${schedule.filter((match) => match.pairing === index).length} matches, seeds ${tournament.seeds[index]?.slice(0, blocksPerPairing).join(", ")}`);

  process.exit(0);
}

const dir = resolve(flag("dir") ?? exit("--dir is required"));

const gitCommit = Bun.spawnSync(["git", "rev-parse", "HEAD"], { cwd: WEB }).stdout.toString().trim();

const keys = unwrap(resolveKeys(tournament.config, scheduleOf(tournament), process.env));

const file = tournaments.map((each) => unwrap(openTournament(dir, each, gitCommit, new Date()))).at(-1) ?? exit("no config");

const children = new Set<ReturnType<typeof spawn>>();

const stop = new AbortController();

for (const signal of ["SIGINT", "SIGTERM"] as const) {
  process.on(signal, () => {
    stop.abort();

    for (const child of children) child.kill("SIGTERM");
  });
}

/** The web dir whose code a match plays under: this one for a new match or one of this version, else a checkout of the version it started under. */
const webOf = (match: ScheduledMatch): string | undefined =>
  Option.match(startedUnder(dir, match), { onNone: () => WEB, onSome: (code) => (code === CODE ? WEB : checkouts.get(code)) });

/** One match as a child process, which gives its exit code. Its output is appended to the match's arena.log. */
const runOne = (match: ScheduledMatch, accounts: MatchAccounts): Promise<number> =>
  new Promise((done) => {
    const matchDir = join(dir, match.name);

    mkdirSync(matchDir, { recursive: true });

    const log = openSync(join(matchDir, "arena.log"), "a");
    const [command = "nice", ...rest] = childCommand(matchDir, file.config, match);
    const child = spawn(command, rest, { cwd: webOf(match) ?? WEB, env: childEnv(process.env, file.config, match, keys, accounts), stdio: ["ignore", log, log] });

    children.add(child);
    child.on("close", (code) => {
      children.delete(child);
      closeSync(log);
      done(code ?? 1);
    });
    child.on("error", () => done(1));
  });

const tail = (match: ScheduledMatch, lines: number): string => {
  const text = readFileSync(join(dir, match.name, "arena.log"), "utf8").trimEnd().split("\n");

  return text.slice(-lines).map((line) => `    ${line}`).join("\n");
};

const clock = (time: number): string => new Date(time).toLocaleString("sv-SE").slice(0, 16);

const report = (settled: Settled) => {
  const { match, status } = settled;
  const done = finishedNames(dir, file.schedule).size;
  const winning = status === "finished" ? winnersOf(dir, match) : [];
  const winners = winning.length === 0 ? "" : `, won by ${winning.join(" and ")}`;

  console.log(`[${done}/${file.schedule.length}] ${match.name} ${status}${winners}, ${money(costOf(dir, prices, [match]))}, total ${money(costOf(dir, prices, file.schedule))}`);

  if (settled.status === "cooling") console.log(`  ${settled.cooldown.model}${settled.cooldown.account === undefined ? "" : ` on ${settled.cooldown.account}`} is at its usage limit until ${clock(settled.cooldown.until)}; its matches wait, and this one resumes then.`);

  if (status === "failed") console.log(`${tail(match, 8)}\n  It is retried after a pause, up to three runs; rerun the same command to resume it after that.`);
};

/** Each config's own matches, the ones it added to the tournament, for the progress lines. */
const phases = configPaths.map((path, index) => {
  const before = new Set(index === 0 ? [] : scheduleOf(tournaments[index - 1] ?? tournament).map((match) => match.name));

  return { label: basename(path, ".json"), names: scheduleOf(tournaments[index] ?? tournament).flatMap((match) => (before.has(match.name) ? [] : [match.name])) };
});

const startedAt = new Date();

let failedRuns = 0;

/** Appends one line to <dir>/PROGRESS.md, so the tournament's progress is on disk without anyone watching it. */
const noteProgress = (event: string) => {
  const finished = finishedNames(dir, file.schedule);
  const faults = file.schedule.reduce((total, match) => total + faultsOf(dir, match).length, 0);
  const byPhase = phases.map(({ label, names }) => `${label} ${names.filter((name) => finished.has(name)).length}/${names.length}`).join(", ");
  const cooling = new Map(file.schedule.flatMap((match) => Option.toArray(cooldownOf(dir, file.config, match, Date.now())).map(({ model, account, until }) => [account === undefined ? model : `${model} on ${account}`, until] as const)));
  const waiting = [...cooling].map(([model, until]) => `${model} until ${clock(until)}`).join(", ");

  appendFileSync(
    join(dir, "PROGRESS.md"),
    `- ${clock(Date.now())} runner ${event}: ${finished.size}/${file.schedule.length} finished (${byPhase}); ${children.size} running; ${failedRuns} failed runs since ${clock(startedAt.getTime())}; ${faults} provider faults in all;${waiting === "" ? "" : ` at the usage limit: ${waiting};`} ${money(costOf(dir, prices, file.schedule))} at list prices\n`,
  );
};

const settle = (settled: Settled) => {
  if (settled.status === "failed") failedRuns += 1;

  report(settled);
};

const isPlayed = (match: ScheduledMatch) => !match.entrants.some((entrant) => skipped.has(entrant));

const played = unfinished(file.schedule, finishedNames(dir, file.schedule)).filter(isPlayed);

const pending = played.filter((match) => webOf(match) !== undefined).slice(0, limit);

console.log(`${file.config.name}: ${pending.length} of ${file.schedule.length} matches to run, ${parallel} at a time${[...caps].map(([model, most]) => `, at most ${most} with ${model}`).join("")}${[...last].map((model) => `, ${model} last`).join("")}${[...forget].map((model) => `, ${model}'s recorded cooldowns ignored`).join("")}, in ${dir}, new matches under code ${CODE}${[...checkouts].map(([code, web]) => `, code ${code} from ${web}`).join("")}`);

const waitingCodes = played.flatMap((match) => (webOf(match) === undefined ? Option.toArray(startedUnder(dir, match)) : []));

for (const code of new Set(waitingCodes)) {
  console.log(`  ${waitingCodes.filter((each) => each === code).length} matches started under code ${code} wait for a checkout of it: --code ${code}=<web dir>`);
}

noteProgress("started");

const every30Minutes = setInterval(() => noteProgress("check"), 30 * 60 * 1000);

const settled = await runPending(dir, file.config, pending, parallel, runOne, settle, stop.signal, { caps, last, forget, prefer });

clearInterval(every30Minutes);

const failed = settled.filter(({ status }) => status === "failed").length;

// Skipped matches do not count, so a run that skips an entrant ends with exit 0 once the rest are finished.
const remaining = unfinished(file.schedule, finishedNames(dir, file.schedule)).filter(isPlayed).length;

console.log(`\n${settled.length - failed} matches finished, ${failed} failed runs, ${remaining} not finished. Total cost ${money(costOf(dir, prices, file.schedule))}.`);

if (remaining > 0) console.log("Rerun the same command to resume the rest.");

console.log(`Stats: bun scripts/arena-stats.ts ${dir}`);

noteProgress("ended");

process.exitCode = remaining > 0 ? 1 : 0;
