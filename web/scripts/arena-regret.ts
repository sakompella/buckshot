import { mkdirSync, mkdtempSync, readFileSync, rmSync } from "node:fs";
import { tmpdir } from "node:os";
import { dirname, join, resolve } from "node:path";
import { parseArgs } from "node:util";

import { Database } from "bun:sqlite";
import { Option, Result, Schema } from "effect";

import { type AgentSource } from "../src/agent/view.ts";
import { boardOf, type Limits, loadPlayer, ownLog, RELOAD_RULES, type Reload, type ReloadRule } from "../src/analysis/player.ts";
import { type Regret, regretOf } from "../src/analysis/regret.ts";
import { RunManifest } from "../src/arena/match.ts";
import { MoveLine } from "../src/arena/runlog.ts";
import { rosterOf } from "../src/players.ts";
import { agentMoveText } from "../src/text.ts";
import { replayOf } from "../src/viewer/replay.ts";

// Scores every agent decision of one match, of every replay-validated match, or of
// the decisions a list names, with the minimax player (src/analysis/regret.ts) and writes the rows to the
// `regret` table of a derived database. The analysis database
// (docs/arena/database.md) is opened read only. Each decision's position is the
// deciding player's own log and the public board, rebuilt by replaying the match
// as scripts/arena-knowledge.ts does; forced grabs and fallback moves are not
// scored. Each row is committed as it is scored, and a rerun skips the decisions
// already scored with the same player version, depth, budget and reload rule
// (--reload: static, the default, expected-deal or sampled, with --samples deals
// per leaf, 256 by default; the last two take two seats only). Shards split
// the matches between processes that may share one output file (WAL, so their
// writes queue). See docs/arena/analysis/regret.md.
//
//   bun scripts/arena-regret.ts --db <buckshot.sqlite> --out <derived.sqlite> (--match <match name> | --all [--shard K/N] | --decisions <list>) [--depth 6] [--budget 20000] [--reload static] [--samples 256]

const USAGE = "Usage: bun scripts/arena-regret.ts --db <database> --out <derived.sqlite> (--match <match name> | --all [--shard K/N] | --decisions <list>) [--depth N] [--budget N] [--reload static|expected-deal|sampled] [--samples N]";

const { values } = parseArgs({
  args: process.argv.slice(2),
  options: { db: { type: "string" }, out: { type: "string" }, match: { type: "string" }, all: { type: "boolean" }, decisions: { type: "string" }, shard: { type: "string" }, depth: { type: "string", default: "6" }, budget: { type: "string", default: "20000" }, reload: { type: "string", default: "static" }, samples: { type: "string" } },
});

if (values.db === undefined || values.out === undefined || [values.match !== undefined, values.all === true, values.decisions !== undefined].filter(Boolean).length !== 1 || (values.shard !== undefined && values.all !== true)) {
  console.error(USAGE);
  process.exit(1);
}

const limits: Limits = { depth: Number(values.depth), budget: Number(values.budget) };

if (!Number.isSafeInteger(limits.depth) || !Number.isSafeInteger(limits.budget) || limits.depth < 0 || limits.budget < 0) {
  console.error("--depth and --budget take whole numbers of at least 0.");
  process.exit(1);
}

const isReloadRule = (rule: string): rule is ReloadRule => RELOAD_RULES.some((known) => known === rule);

if (!isReloadRule(values.reload)) {
  console.error(`--reload takes ${RELOAD_RULES.join(" or ")}, not ${values.reload}.`);
  process.exit(1);
}

if (values.samples !== undefined && values.reload !== "sampled") {
  console.error("--samples goes with --reload sampled.");
  process.exit(1);
}

const reload = ((rule: ReloadRule): Reload => {
  switch (rule) {
    case "static":
    case "expected-deal":
      return { rule };
    case "sampled": {
      const samples = Number(values.samples ?? "256");

      if (!Number.isSafeInteger(samples) || samples < 1) {
        console.error(`--samples takes a whole number of at least 1, not ${values.samples}.`);
        process.exit(1);
      }

      return { rule, samples };
    }
  }
})(values.reload);

/** The deals each reload leaf averages; 0 for the rules that do not sample. */
const samples = reload.rule === "sampled" ? reload.samples : 0;

/** Shard `number` of `count`, counted from 1. */
const shard = (() => {
  const parsed = /^(\d+)\/(\d+)$/.exec(values.shard ?? "1/1");
  const number = Number(parsed?.[1]);
  const count = Number(parsed?.[2]);

  if (parsed === null || number < 1 || number > count) {
    console.error(`--shard takes K/N with 1 <= K <= N, not ${values.shard}.`);
    process.exit(1);
  }

  return { number, count };
})();

const source = new Database(resolve(values.db), { readonly: true });

// The importer may be writing the analysis database; wait for it instead of failing.
source.exec("PRAGMA busy_timeout = 30000");

const scratch = mkdtempSync(join(tmpdir(), "buckshot-regret-"));

const player = await loadPlayer(scratch).finally(() => rmSync(scratch, { recursive: true, force: true }));

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

/** The decisions a list names, one `<match id> <ordinal>` per line, by match. Absent when the run scores one match or every match. */
const listed = ((path: string | undefined): ReadonlyMap<string, ReadonlySet<number>> | undefined => {
  if (path === undefined) return undefined;

  const byMatch = new Map<string, Set<number>>();

  for (const line of readFileSync(resolve(path), "utf8").split("\n").filter((text) => text.trim() !== "")) {
    const parsed = /^(\S+) (\d+)$/.exec(line.trim());

    if (parsed === null) {
      console.error(`--decisions takes lines of "<match id> <ordinal>", not "${line}".`);
      process.exit(1);
    }

    byMatch.set(parsed[1] ?? "", (byMatch.get(parsed[1] ?? "") ?? new Set()).add(Number(parsed[2])));
  }

  return byMatch;
})(values.decisions);

const matches = source
  .query<MatchRow, []>(
    `SELECT m.id, m.name, m.manifest_json FROM matches m JOIN tournaments t ON t.id = m.tournament_id
     WHERE m.manifest_json IS NOT NULL AND m.replay_status = 'validated' ORDER BY t.name, m.name`,
  )
  .all()
  .filter((match) => values.all === true || (listed === undefined ? match.name === values.match : listed.has(match.id)))
  .filter((_, index) => index % shard.count === shard.number - 1);

if (values.match !== undefined && matches.length === 0) {
  console.error(`No replay-validated match named ${values.match}.`);
  process.exit(1);
}

if (listed !== undefined) {
  const agentOrdinals = (id: string): ReadonlySet<number> =>
    new Set(source.query<{ ordinal: number }, [string]>("SELECT ordinal FROM decisions WHERE match_id = ? AND by_whom = 'agent'").all(id).map(({ ordinal }) => ordinal));

  const unknown = [...listed].flatMap(([id, ordinals]) => {
    const agent = matches.some((match) => match.id === id) ? agentOrdinals(id) : new Set<number>();

    return [...ordinals].flatMap((ordinal) => (agent.has(ordinal) ? [] : [`${id} ${ordinal}`]));
  });

  if (unknown.length > 0) {
    console.error(`--decisions names decisions that are not agent decisions of a replay-validated match: ${unknown.slice(0, 5).join(", ")}${unknown.length > 5 ? ", ..." : ""}.`);
    process.exit(1);
  }
}

mkdirSync(dirname(resolve(values.out)), { recursive: true });

const out = new Database(resolve(values.out), { create: true, strict: true });

out.exec("PRAGMA busy_timeout = 30000; PRAGMA journal_mode = WAL;");

const CREATE = `CREATE TABLE IF NOT EXISTS regret (
    match_id TEXT, ordinal INTEGER, player TEXT, label TEXT,
    evaluator TEXT, max_depth INTEGER, budget INTEGER, reload TEXT NOT NULL, samples INTEGER NOT NULL CHECK ((reload = 'sampled') = (samples > 0)),
    status TEXT, reason TEXT, values_json TEXT, best TEXT, best_score INTEGER, chosen_score INTEGER, regret INTEGER, exact INTEGER,
    depth INTEGER, limited INTEGER, nodes INTEGER, ms REAL,
    PRIMARY KEY (match_id, ordinal, evaluator, max_depth, budget, reload, samples))`;

// A table from before the reload rule holds static rows only. It is rebuilt with the rule in its key, once, while other shards wait.
out
  .transaction(() => {
    const columns = out.query<{ name: string }, []>("SELECT name FROM pragma_table_info('regret')").all().map(({ name }) => name);

    if (columns.length > 0 && !columns.includes("reload")) {
      out.exec(`ALTER TABLE regret RENAME TO regret_before_reload; ${CREATE}; INSERT INTO regret (${columns.join(", ")}, reload, samples) SELECT ${columns.join(", ")}, 'static', 0 FROM regret_before_reload; DROP TABLE regret_before_reload;`);
    }

    out.exec(CREATE);
  })
  .immediate();

/** The columns that depend on how the decision was scored. Only a searched decision has a regret; a fallback or invalid one has none, never 0. */
const scored = (regret: Regret) => {
  switch (regret.status) {
    case "searched":
      return { values_json: JSON.stringify(regret.values), best: regret.best.label, best_score: regret.best.score, chosen_score: regret.chosen.score, regret: regret.regret, exact: regret.exact ? 1 : 0, depth: regret.depth, limited: regret.limited ? 1 : 0 };
    case "fallback":
      return { values_json: JSON.stringify(regret.values), depth: 0, limited: regret.limited ? 1 : 0 };
    case "invalid":
      return { reason: regret.reason };
  }
};

const put = (row: Readonly<Record<string, string | number | null>>): void => {
  const keys = Object.keys(row);
  out.query(`INSERT INTO regret (${keys.join(",")}) VALUES (${keys.map(() => "?").join(",")})`).run(...Object.values(row));
};

const times: Array<number> = [];

/** Scores the agent decisions of a match that the output does not hold yet. */
const scoreMatch = (match: MatchRow): void => {
  const decisions = source
    .query<DecisionRow, [string]>("SELECT d.ordinal, d.player, d.label, d.by_whom, d.legal_json, r.raw FROM decisions d JOIN source_records r ON r.id = d.source_record WHERE d.match_id = ? ORDER BY d.ordinal")
    .all(match.id);

  const done = new Set(
    out
      .query<{ ordinal: number }, [string, string, number, number, string, number]>("SELECT ordinal FROM regret WHERE match_id = ? AND evaluator = ? AND max_depth = ? AND budget = ? AND reload = ? AND samples = ?")
      .all(match.id, player.version, limits.depth, limits.budget, reload.rule, samples)
      .map(({ ordinal }) => ordinal),
  );

  const wanted = (decision: DecisionRow): boolean => decision.by_whom === "agent" && (listed?.get(match.id)?.has(decision.ordinal) ?? true) && !done.has(decision.ordinal);

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
      // The arena plays every match with items (src/viewer/replay.ts starts it so).
      const input = { table: before.game.table, items: true, board: boardOf(before.game), log: ownLog(before.events, before.learned, me), me };
      const menu = decodeMenu(decision.legal_json).map(({ label }) => label);
      const started = performance.now();
      const regret = regretOf(player.analyse(input, limits, reload), (steps) => agentMoveText(roster, me, steps), menu, decision.label);
      const ms = performance.now() - started;
      times.push(ms);

      put({ match_id: match.id, ordinal: decision.ordinal, player: decision.player, label: decision.label, evaluator: player.version, max_depth: limits.depth, budget: limits.budget, reload: reload.rule, samples, status: regret.status, nodes: regret.nodes, ms, ...scored(regret) });
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
    // One bad match must not stop the shard for hours; it is listed again at the end and a rerun retries it.
    failed.push(match.id);
    console.error(`FAILED ${match.name} (${match.id}): ${error instanceof Error ? error.message : String(error)}`);
  }

  if (values.match === undefined) console.error(`shard ${shard.number}/${shard.count}: match ${index + 1}/${matches.length}, ${times.length} decisions scored`);
}

out.close();

source.close();

const sorted = times.toSorted((a, b) => a - b);

const at = (share: number) => Math.round(sorted[Math.min(sorted.length - 1, Math.floor(share * sorted.length))] ?? 0);

console.error(JSON.stringify({ decisions: times.length, failed, ms: { mean: Math.round(times.reduce((sum, ms) => sum + ms, 0) / Math.max(1, times.length)), p50: at(0.5), p95: at(0.95), max: at(1) } }));

if (failed.length > 0) process.exit(1);
