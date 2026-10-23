import { mkdirSync, mkdtempSync, rmSync } from "node:fs";
import { tmpdir } from "node:os";
import { dirname, join, resolve } from "node:path";
import { parseArgs } from "node:util";

import { Database } from "bun:sqlite";
import { Option, Result, Schema } from "effect";

import { type AgentSource } from "../src/agent/view.ts";
import { boardOf, loadPlayer, ownLog } from "../src/analysis/player.ts";
import { type Limits, type Regret, regretAt } from "../src/analysis/regret.ts";
import { RunManifest } from "../src/arena/match.ts";
import { MoveLine } from "../src/arena/runlog.ts";
import { rosterOf } from "../src/players.ts";
import { agentMoveText } from "../src/text.ts";
import { replayOf } from "../src/viewer/replay.ts";

// Scores every agent decision of one match with the minimax player
// (src/analysis/regret.ts) and writes the rows to the `regret` table of a
// derived database. The analysis database (docs/arena/database.md) is opened
// read only. Each decision's position is the deciding player's own log and the
// public board, rebuilt by replaying the match as scripts/arena-knowledge.ts
// does; forced grabs and fallback moves are not scored. A rerun replaces the
// match's rows for the same player version, depth and budget.
//
//   bun scripts/arena-regret.ts --db <buckshot.sqlite> --out <derived.sqlite> --match <match name> [--depth 6] [--budget 20000]

const { values } = parseArgs({
  args: process.argv.slice(2),
  options: { db: { type: "string" }, out: { type: "string" }, match: { type: "string" }, depth: { type: "string", default: "6" }, budget: { type: "string", default: "20000" } },
});

if (values.db === undefined || values.out === undefined || values.match === undefined) {
  console.error("Usage: bun scripts/arena-regret.ts --db <database> --out <derived.sqlite> --match <match name> [--depth N] [--budget N]");
  process.exit(1);
}

const limits: Limits = { depth: Number(values.depth), budget: Number(values.budget) };

const source = new Database(resolve(values.db), { readonly: true });

const scratch = mkdtempSync(join(tmpdir(), "buckshot-regret-"));

const player = await loadPlayer(scratch).finally(() => rmSync(scratch, { recursive: true, force: true }));

const decodeManifest = Schema.decodeUnknownSync(Schema.fromJsonString(RunManifest));

const decodeMove = Schema.decodeUnknownSync(Schema.fromJsonString(MoveLine));

const decodeMenu = Schema.decodeUnknownSync(Schema.fromJsonString(Schema.Array(Schema.Struct({ label: Schema.String }))));

const decodeLetter = Schema.decodeUnknownSync(Schema.Literals(["A", "B", "C", "D"]));

interface MatchRow {
  readonly id: string;
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

const match = source.query<MatchRow, [string]>("SELECT id, manifest_json FROM matches WHERE name = ? AND manifest_json IS NOT NULL AND replay_status = 'validated'").get(values.match);

if (match === null) {
  console.error(`No replay-validated match named ${values.match}.`);
  process.exit(1);
}

const decisions = source
  .query<DecisionRow, [string]>("SELECT d.ordinal, d.player, d.label, d.by_whom, d.legal_json, r.raw FROM decisions d JOIN source_records r ON r.id = d.source_record WHERE d.match_id = ? ORDER BY d.ordinal")
  .all(match.id);

mkdirSync(dirname(resolve(values.out)), { recursive: true });

const out = new Database(resolve(values.out), { create: true, strict: true });

out.exec(`
  PRAGMA journal_mode = WAL;
  CREATE TABLE IF NOT EXISTS regret (
    match_id TEXT, ordinal INTEGER, player TEXT, label TEXT,
    evaluator TEXT, max_depth INTEGER, budget INTEGER,
    status TEXT, reason TEXT, values_json TEXT, best TEXT, best_score INTEGER, chosen_score INTEGER, regret INTEGER, exact INTEGER,
    depth INTEGER, limited INTEGER, nodes INTEGER, ms REAL,
    PRIMARY KEY (match_id, ordinal, evaluator, max_depth, budget));
`);

/** The columns that depend on how the decision was scored. Only a searched decision has a regret; a fallback or invalid one has none, never 0. */
const scored = (regret: Regret) => {
  switch (regret.status) {
    case "searched":
      return { values_json: JSON.stringify(regret.values), best: regret.best.label, best_score: regret.best.score, chosen_score: regret.chosen.score, regret: regret.regret, exact: regret.exact ? 1 : 0, depth: regret.depth, limited: regret.limited ? 1 : 0 };
    case "fallback":
      return { values_json: JSON.stringify(regret.values), depth: 0, limited: 1 };
    case "invalid":
      return { reason: regret.reason };
  }
};

const put = (row: Readonly<Record<string, string | number | null>>): void => {
  const keys = Object.keys(row);
  out.query(`INSERT OR REPLACE INTO regret (${keys.join(",")}) VALUES (${keys.map(() => "?").join(",")})`).run(...Object.values(row));
};

const manifest = decodeManifest(match.manifest_json);
const moves: Array<MoveLine> = [];
let replay = Result.getOrThrow(replayOf(Option.none(), manifest, []));
const current = (): AgentSource => Option.getOrThrow(replay.session.current(replay.table));
const roster = rosterOf(current().game.seats, current().letters);
const times: Array<number> = [];

out.exec("BEGIN");

for (const decision of decisions) {
  if (decision.by_whom === "agent") {
    const before = current();
    const me = Option.getOrThrow(roster.find(decodeLetter(decision.player))).seat;
    // The arena plays every match with items (src/viewer/replay.ts starts it so).
    const position = { table: before.game.table, items: true, board: boardOf(before.game), log: ownLog(before.events, before.learned, me), me };
    const menu = decodeMenu(decision.legal_json).map(({ label }) => label);
    const started = performance.now();
    const regret = regretAt(player, position, limits, (steps) => agentMoveText(roster, me, steps), menu, decision.label);
    const ms = performance.now() - started;
    times.push(ms);

    put({ match_id: match.id, ordinal: decision.ordinal, player: decision.player, label: decision.label, evaluator: player.version, max_depth: limits.depth, budget: limits.budget, status: regret.status, nodes: regret.nodes, ms, ...scored(regret) });
  }

  moves.push(decodeMove(decision.raw));
  replay = Result.getOrThrow(replayOf(Option.some(replay), manifest, moves));

  if (Option.isSome(replay.divergence)) throw new Error(`${values.match}: ${Option.getOrThrow(replay.divergence)}`);
}

out.exec("COMMIT");

out.close();

source.close();

const sorted = times.toSorted((a, b) => a - b);

const at = (share: number) => Math.round(sorted[Math.min(sorted.length - 1, Math.floor(share * sorted.length))] ?? 0);

console.error(JSON.stringify({ decisions: times.length, ms: { mean: Math.round(times.reduce((sum, ms) => sum + ms, 0) / Math.max(1, times.length)), p50: at(0.5), p95: at(0.95), max: at(1) } }));
