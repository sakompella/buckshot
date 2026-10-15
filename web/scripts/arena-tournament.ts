import { spawn } from "node:child_process";
import { closeSync, mkdirSync, openSync, readFileSync } from "node:fs";
import { join, resolve } from "node:path";

import { Result } from "effect";

import { DEFAULT_PRICES, loadPrices } from "../src/arena/cost.ts";
import { checkPrices, childCommand, childEnv, parseConfig, resolveKeys, type ScheduledMatch, scheduleOf, type TournamentError } from "../src/arena/tournament.ts";
import { costOf, finishedNames, openTournament, runPending, type Settled, winnersOf } from "../src/arena/tournament-dir.ts";

// Plays a tournament: every scheduled match, as a child process running
// scripts/arena.ts, at most --parallel at a time (1 or 2, default 2). The config
// says who plays whom, as tournaments/cpa-medium.json does. The first run writes
// <dir>/tournament.json, and a later run needs the same config, or that config
// with entrants added and listed pairings added after its own, which it schedules. Keys come from
// the environment, and Bun loads web/.env for this script; each match gets only
// its own PLAYER_* variables. A match that fails is reported and left, and the
// rest go on. Rerun the same command to resume: finished matches never run
// again. Do not run two of these on one directory. --dry-run prints the schedule.
// Usage: bun scripts/arena-tournament.ts <config.json> --dir <tournament dir> [--parallel 1|2] [--dry-run]
//        bun scripts/arena-stats.ts <tournament dir> [--json]

const WEB = join(import.meta.dir, "..");

const args = process.argv.slice(2);

const flag = (name: string): string | undefined => {
  const at = args.indexOf(`--${name}`);

  return at === -1 ? undefined : args[at + 1];
};

const configPath = args.find((arg, index) => !arg.startsWith("--") && args[index - 1] !== "--dir" && args[index - 1] !== "--parallel");

const parallel = Number(flag("parallel") ?? "2");

const exit = (message: string): never => {
  console.error(message);

  return process.exit(1);
};

const unwrap = <A>(result: Result.Result<A, TournamentError>): A => Result.match(result, { onFailure: (error) => exit(error.message), onSuccess: (value) => value });

if (configPath === undefined) exit("Usage: bun scripts/arena-tournament.ts <config.json> --dir <tournament dir> [--parallel 1|2] [--dry-run]");

if (parallel !== 1 && parallel !== 2) exit("--parallel must be 1 or 2");

const prices = loadPrices(DEFAULT_PRICES);

const tournament = unwrap(parseConfig(readFileSync(configPath ?? "", "utf8")));

unwrap(checkPrices(tournament, prices));

const money = (dollars: number): string => `$${dollars.toFixed(4)}`;

if (args.includes("--dry-run")) {
  const schedule = scheduleOf(tournament);
  const { name, seed, delivery, blocksPerPairing } = tournament.config;

  console.log(`${name}: ${tournament.pairings.length} pairings, ${blocksPerPairing} block${blocksPerPairing === 1 ? "" : "s"} each, ${schedule.length} matches, ${delivery} delivery, seeds ${seed} to ${seed + blocksPerPairing - 1}`);

  for (const [index, pairing] of tournament.pairings.entries()) console.log(`  ${pairing.join(" vs ")}: ${schedule.filter((match) => match.pairing === index).length} matches`);

  process.exit(0);
}

const dir = resolve(flag("dir") ?? exit("--dir is required"));

const gitCommit = Bun.spawnSync(["git", "rev-parse", "HEAD"], { cwd: WEB }).stdout.toString().trim();

const keys = unwrap(resolveKeys(tournament.config, scheduleOf(tournament), process.env));

const file = unwrap(openTournament(dir, tournament, gitCommit, new Date()));

const children = new Set<ReturnType<typeof spawn>>();

const stop = new AbortController();

for (const signal of ["SIGINT", "SIGTERM"] as const) {
  process.on(signal, () => {
    stop.abort();

    for (const child of children) child.kill("SIGTERM");
  });
}

/** One match as a child process, which gives its exit code. Its output is appended to the match's arena.log. */
const runOne = (match: ScheduledMatch): Promise<number> =>
  new Promise((done) => {
    const matchDir = join(dir, match.name);

    mkdirSync(matchDir, { recursive: true });

    const log = openSync(join(matchDir, "arena.log"), "a");
    const [command = "nice", ...rest] = childCommand(matchDir, file.config, match);
    const child = spawn(command, rest, { cwd: WEB, env: childEnv(process.env, file.config, match, keys), stdio: ["ignore", log, log] });

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

const report = ({ match, status }: Settled) => {
  const done = finishedNames(dir, file.schedule).size;
  const winning = status === "finished" ? winnersOf(dir, match) : [];
  const winners = winning.length === 0 ? "" : `, won by ${winning.join(" and ")}`;

  console.log(`[${done}/${file.schedule.length}] ${match.name} ${status}${winners}, ${money(costOf(dir, prices, [match]))}, total ${money(costOf(dir, prices, file.schedule))}`);

  if (status === "failed") console.log(`${tail(match, 8)}\n  Rerun the same command to resume it.`);
};

const pending = file.schedule.length - finishedNames(dir, file.schedule).size;

console.log(`${file.config.name}: ${pending} of ${file.schedule.length} matches to run, ${parallel} at a time, in ${dir}`);

const settled = await runPending(dir, file.schedule, parallel, runOne, report, stop.signal);

const failed = settled.filter(({ status }) => status === "failed").length;

const remaining = file.schedule.length - finishedNames(dir, file.schedule).size;

console.log(`\n${settled.length - failed} matches finished, ${failed} failed, ${remaining} not finished. Total cost ${money(costOf(dir, prices, file.schedule))}.`);

if (remaining > 0) console.log("Rerun the same command to resume the rest.");

console.log(`Stats: bun scripts/arena-stats.ts ${dir}`);

process.exitCode = remaining > 0 ? 1 : 0;
