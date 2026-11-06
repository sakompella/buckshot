import { createHash } from "node:crypto";
import { mkdirSync, mkdtempSync, readFileSync, rmSync, writeFileSync } from "node:fs";
import { tmpdir } from "node:os";
import { dirname, join, resolve } from "node:path";
import { parseArgs } from "node:util";

import { Database } from "bun:sqlite";
import { Option, Result, Schema } from "effect";

import { type AgentSource } from "../src/agent/view.ts";
import { moveCode, nativeInput } from "../src/analysis/native-input.ts";
import { type Analysis, boardOf, loadPlayer, ownLog } from "../src/analysis/player.ts";
import { regretOf } from "../src/analysis/regret.ts";
import { CREATE_REGRET, scored } from "../src/analysis/regret-rows.ts";
import { RunManifest } from "../src/arena/match.ts";
import { MoveLine } from "../src/arena/runlog.ts";
import { rosterOf } from "../src/players.ts";
import { agentMoveText } from "../src/text.ts";
import { replayOf } from "../src/arena/replay.ts";

// Scores the agent decisions a list names with the native evaluator (sim/bend-mp/native.bend; player/deal.bend forks
// the sampled deals across threads), under the sampled rule with --samples deals and the charged memo, and writes
// rows of the same shape as scripts/arena-regret.ts --reload sampled. The rows equal that script's (the JS player's
// scores, best move, depth, limited and nodes), so they carry the JS evaluator's id (--evaluator) and the `evaluator_group`
// table says so. `evaluator_build` lists each native build (--commit, binary hash) and `regret_build` names the build
// that scored each row. Each row is committed as it is scored; a rerun skips the decisions already in --out.
// Each decision is one native process, `+RTS --threads` wide. Shards split the matches and may share --out (WAL).
//
//   bun scripts/arena-regret-native.ts --db <buckshot.sqlite> --out <derived.sqlite> --decisions <list> --binary <native-par> --evaluator <id> [--shard K/N] [--threads 8] [--depth 6] [--budget 20000] [--samples 256] [--commit <sha>]

const { values } = parseArgs({
  args: process.argv.slice(2),
  options: { db: { type: "string" }, out: { type: "string" }, decisions: { type: "string" }, binary: { type: "string" }, evaluator: { type: "string" }, commit: { type: "string", default: "" }, shard: { type: "string", default: "1/1" }, threads: { type: "string", default: "8" }, depth: { type: "string", default: "6" }, budget: { type: "string", default: "20000" }, samples: { type: "string", default: "256" } },
});

if (values.db === undefined || values.out === undefined || values.decisions === undefined || values.binary === undefined || values.evaluator === undefined) {
  console.error("Usage: bun scripts/arena-regret-native.ts --db <database> --out <derived.sqlite> --decisions <list> --binary <native-par> --evaluator <id> [--shard K/N] [--threads N] [--depth N] [--budget N] [--samples N] [--commit <sha>]");
  process.exit(1);
}

const evaluator = values.evaluator;
const depth = Number(values.depth);
const budget = Number(values.budget);
const samples = Number(values.samples);
const binary = resolve(values.binary);
const parsedShard = /^(\d+)\/(\d+)$/.exec(values.shard);
const shard = { number: Number(parsedShard?.[1]), count: Number(parsedShard?.[2]) };

if (parsedShard === null || shard.number < 1 || shard.number > shard.count || ![depth, budget, samples].every((n) => Number.isSafeInteger(n) && n >= 1)) {
  console.error("--shard takes K/N with 1 <= K <= N; --depth, --budget and --samples take whole numbers of at least 1.");
  process.exit(1);
}

const source = new Database(resolve(values.db), { readonly: true });

source.exec("PRAGMA busy_timeout = 30000");

const scratch = mkdtempSync(join(tmpdir(), "buckshot-regret-native-"));

const player = await loadPlayer(scratch);

const decodeManifest = Schema.decodeUnknownSync(Schema.fromJsonString(RunManifest));

const decodeMove = Schema.decodeUnknownSync(Schema.fromJsonString(MoveLine));

const decodeMenu = Schema.decodeUnknownSync(Schema.fromJsonString(Schema.Array(Schema.Struct({ label: Schema.String }))));

const decodeLetter = Schema.decodeUnknownSync(Schema.Literals(["A", "B", "C", "D"]));

interface MatchRow {
  readonly id: string;
  readonly name: string;
  readonly manifest_json: string;
}

interface DecisionRow {
  readonly ordinal: number;
  readonly player: string;
  readonly label: string;
  readonly by_whom: string;
  readonly legal_json: string;
  readonly raw: string;
}

const listed = new Map<string, Set<number>>();

for (const line of readFileSync(resolve(values.decisions), "utf8").split("\n").filter((text) => text.trim() !== "")) {
  const parsed = /^(\S+) (\d+)$/.exec(line.trim());

  if (parsed === null) {
    console.error(`--decisions takes lines of "<match id> <ordinal>", not "${line}".`);
    process.exit(1);
  }

  listed.set(parsed[1] ?? "", (listed.get(parsed[1] ?? "") ?? new Set()).add(Number(parsed[2])));
}

const matches = source
  .query<MatchRow, []>(
    `SELECT m.id, m.name, m.manifest_json FROM matches m JOIN tournaments t ON t.id = m.tournament_id
     WHERE m.manifest_json IS NOT NULL AND m.replay_status = 'validated' ORDER BY t.name, m.name`,
  )
  .all()
  .filter((match) => listed.has(match.id))
  .filter((_, index) => index % shard.count === shard.number - 1);

mkdirSync(dirname(resolve(values.out)), { recursive: true });

const out = new Database(resolve(values.out), { create: true, strict: true });

out.exec("PRAGMA busy_timeout = 30000; PRAGMA journal_mode = WAL;");

out.exec(CREATE_REGRET);

out.exec(`CREATE TABLE IF NOT EXISTS evaluator_group (
    evaluator TEXT, max_depth INTEGER, budget INTEGER, reload TEXT, samples INTEGER,
    engine TEXT, checks_json TEXT,
    PRIMARY KEY (evaluator, max_depth, budget, reload, samples))`);

out
  .query("INSERT OR IGNORE INTO evaluator_group (evaluator, max_depth, budget, reload, samples, engine) VALUES (?, ?, ?, 'sampled', ?, ?)")
  .run(evaluator, depth, budget, samples, "native: sim/bend-mp/native.bend, sampled deals, charged memo; rows equal the JS (production) sampled evaluator of this id. Builds: evaluator_build; the build of each row: regret_build");

out.exec(`CREATE TABLE IF NOT EXISTS evaluator_build (
    evaluator TEXT, max_depth INTEGER, budget INTEGER, reload TEXT, samples INTEGER, source_commit TEXT, binary_sha256 TEXT, binary TEXT,
    PRIMARY KEY (evaluator, max_depth, budget, reload, samples, source_commit))`);

out.exec(`CREATE TABLE IF NOT EXISTS regret_build (
    match_id TEXT, ordinal INTEGER, evaluator TEXT, max_depth INTEGER, budget INTEGER, reload TEXT, samples INTEGER, source_commit TEXT,
    PRIMARY KEY (match_id, ordinal, evaluator, max_depth, budget, reload, samples))`);

out
  .query("INSERT OR IGNORE INTO evaluator_build (evaluator, max_depth, budget, reload, samples, source_commit, binary_sha256, binary) VALUES (?, ?, ?, 'sampled', ?, ?, ?, ?)")
  .run(evaluator, depth, budget, samples, values.commit, createHash("sha256").update(readFileSync(binary)).digest("hex"), binary);

const inputPath = join(scratch, `input-${shard.number}.txt`);

const times: Array<number> = [];

/** The native evaluator on one input: its output line and its wall time. */
const native = (input: string) => {
  writeFileSync(inputPath, `${input}\n`);

  const started = performance.now();
  const run = Bun.spawnSync([binary, inputPath, String(depth), String(budget), "2", String(samples), "1", "0", "+RTS", "--threads", String(values.threads)], { stdout: "pipe", stderr: "pipe" });
  const ms = performance.now() - started;

  if (run.exitCode !== 0) throw new Error(`native evaluator exit ${run.exitCode}: ${run.stderr.toString().slice(0, 300)}`);

  return { text: run.stdout.toString().split("\n")[0] ?? "", ms };
};

const REACH = ["settled", "reloads", "cut"] as const;

/** `A best nodes depth limited entries hits deals dealhits | move:score:reach ...` (or `I reason nodes`) against the moves of the player's own order. */
const analysisOf = (text: string, moves: () => Analysis): Analysis => {
  if (text.startsWith("I ")) {
    const words = text.slice(2).split(" ");

    return { kind: "invalid", reason: words.slice(0, -1).join(" "), nodes: Number(words.at(-1)) };
  }

  const [head = "", tail = ""] = text.split(" | ");
  const [kind, best, nodes, reached, limited, entries, hits, deals, dealHits] = head.split(" ");
  const reported = tail.split(" ").map((line) => line.split(":"));
  const base = moves();

  if (kind !== "A" || base.kind !== "analysed") throw new Error(`unreadable native output: ${text.slice(0, 200)}`);

  if (reported.length !== base.lines.length || reported.some(([code], index) => code !== moveCode(base.lines[index]?.steps ?? []))) {
    throw new Error(`native moves ${reported.map(([code]) => code).join(",")} are not the player's ${base.lines.map((line) => moveCode(line.steps)).join(",")}`);
  }

  return {
    kind: "analysed",
    lines: base.lines.map((line, index) => ({ steps: line.steps, score: Number(reported[index]?.[1]), reach: REACH[Number(reported[index]?.[2])] ?? "cut" })),
    best: Number(best),
    depth: Number(reached),
    limited: limited === "1",
    nodes: Number(nodes),
    cached: { entries: Number(entries), hits: Number(hits), deals: Number(deals), dealHits: Number(dealHits) },
  };
};

/** A scored row and the build that scored it, in one transaction. */
const put = out.transaction((row: Readonly<Record<string, string | number | null>>): void => {
  const keys = Object.keys(row);

  out.query(`INSERT INTO regret (${keys.join(",")}) VALUES (${keys.map(() => "?").join(",")})`).run(...Object.values(row));
  out
    .query("INSERT INTO regret_build (match_id, ordinal, evaluator, max_depth, budget, reload, samples, source_commit) VALUES (?, ?, ?, ?, ?, 'sampled', ?, ?)")
    .run(row["match_id"] ?? null, row["ordinal"] ?? null, evaluator, depth, budget, samples, values.commit);
});

const scoreMatch = (match: MatchRow): void => {
  const decisions = source
    .query<DecisionRow, [string]>("SELECT d.ordinal, d.player, d.label, d.by_whom, d.legal_json, r.raw FROM decisions d JOIN source_records r ON r.id = d.source_record WHERE d.match_id = ? ORDER BY d.ordinal")
    .all(match.id);

  const done = new Set(
    out
      .query<{ ordinal: number }, [string, string, number, number, number]>("SELECT ordinal FROM regret WHERE match_id = ? AND evaluator = ? AND max_depth = ? AND budget = ? AND reload = 'sampled' AND samples = ?")
      .all(match.id, evaluator, depth, budget, samples)
      .map(({ ordinal }) => ordinal),
  );

  const wanted = (decision: DecisionRow): boolean => decision.by_whom === "agent" && (listed.get(match.id)?.has(decision.ordinal) ?? false) && !done.has(decision.ordinal);

  if (!decisions.some(wanted)) return;

  const manifest = decodeManifest(match.manifest_json);
  const moves: Array<MoveLine> = [];
  let replay = Result.getOrThrow(replayOf(Option.none(), manifest, []));
  const current = (): AgentSource => Option.getOrThrow(replay.session.current(replay.table));
  const roster = rosterOf(current().game.seats, current().letters);

  for (const decision of decisions) {
    if (wanted(decision)) {
      const before = current();
      const me = Option.getOrThrow(roster.find(decodeLetter(decision.player))).seat;
      const input = { table: before.game.table, items: true, board: boardOf(before.game), log: ownLog(before.events, before.learned, me), me };
      const menu = decodeMenu(decision.legal_json).map(({ label }) => label);
      const ran = native(nativeInput(input));
      // The moves in the player's order, to name the native lines; a search of no depth gives every move its static value.
      const analysis = analysisOf(ran.text, () => player.analyse(input, { depth: 0, budget: 0 }, { rule: "static" }));
      const regret = regretOf(analysis, (steps) => agentMoveText(roster, me, steps), menu, decision.label);
      times.push(ran.ms);

      put({ match_id: match.id, ordinal: decision.ordinal, player: decision.player, label: decision.label, evaluator, max_depth: depth, budget, reload: "sampled", samples, status: regret.status, nodes: regret.nodes, ms: ran.ms, ...scored(regret) });
    }

    moves.push(decodeMove(decision.raw));
    replay = Result.getOrThrow(replayOf(Option.some(replay), manifest, moves));

    if (Option.isSome(replay.divergence)) throw new Error(`${match.name}: ${Option.getOrThrow(replay.divergence)}`);
  }
};

const failed: Array<string> = [];

for (const [index, match] of matches.entries()) {
  try {
    scoreMatch(match);
  } catch (error) {
    // One bad match must not stop the shard for hours; it is listed at the end and a rerun retries it.
    failed.push(match.id);
    console.error(`FAILED ${match.name} (${match.id}): ${error instanceof Error ? error.message : String(error)}`);
  }

  console.error(`shard ${shard.number}/${shard.count}: match ${index + 1}/${matches.length}, ${times.length} decisions scored, ${Math.round(times.reduce((sum, ms) => sum + ms, 0) / 1000)} s native`);
}

out.close();

source.close();

rmSync(scratch, { recursive: true, force: true });

console.error(JSON.stringify({ decisions: times.length, failed }));

if (failed.length > 0) process.exit(1);
