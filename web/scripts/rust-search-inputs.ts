import { mkdtempSync, readFileSync, rmSync, writeFileSync } from "node:fs";
import { tmpdir } from "node:os";
import { join, resolve } from "node:path";
import { parseArgs } from "node:util";

import { Database } from "bun:sqlite";
import { Option, Result, Schema } from "effect";

import { type AgentSource } from "../src/agent/view.ts";
import { moveCode, nativeInput } from "../src/analysis/native-input.ts";
import { boardOf, loadPlayer, ownLog, RELOAD_RULES, type Memo, type Reload } from "../src/analysis/player.ts";
import { RunManifest } from "../src/arena/match.ts";
import { replayOf } from "../src/arena/replay.ts";
import { MoveLine } from "../src/arena/runlog.ts";
import { rosterOf } from "../src/players.ts";
import { agentMoveText } from "../src/text.ts";

// Writes the input rows the Rust searcher (sim/rust/search) and its oracle comparison read: one row per listed arena
// decision, in list order, with the position as the numbers native.bend decodes, the menu in the player's own move
// order, and the label the agent chose. With --js each row also carries the JS player's analysis (js) and its time
// (ms) under the given limits, reload rule and memo, for diffing against the Rust results, and reference, the hash of
// that player build. The player is the current checkout's, which matches the production regret rows only while its
// hash is their evaluator id; sim/rust/search/tests/production pins the production evaluator.
//
//   bun scripts/rust-search-inputs.ts --db <buckshot.sqlite> --decisions <list> --out <prefix> [--js] [--depth 6] [--budget 20000] [--reload static|expected-deal|sampled] [--samples 256] [--memo off|charged|free]
//
// Writes <prefix>.jsonl. Row: {id, ordinal, me, table, input, menu, chosen}, plus js and ms with --js.

const { values } = parseArgs({
  args: process.argv.slice(2),
  options: { js: { type: "boolean", default: false }, db: { type: "string" }, decisions: { type: "string" }, out: { type: "string" }, depth: { type: "string", default: "6" }, budget: { type: "string", default: "20000" }, reload: { type: "string", default: "static" }, samples: { type: "string", default: "256" }, memo: { type: "string", default: "off" } },
});

const isRule = Schema.is(Schema.Literals(RELOAD_RULES));
const isMemo = Schema.is(Schema.Literals(["off", "charged", "free"]));

const depth = Number(values.depth);
const budget = Number(values.budget);
const samples = Number(values.samples);

if (values.db === undefined || values.decisions === undefined || values.out === undefined || !isRule(values.reload) || !isMemo(values.memo) || ![depth, budget, samples].every((n) => Number.isSafeInteger(n) && n >= 1)) {
  console.error("Usage: bun scripts/rust-search-inputs.ts --db <database> --decisions <list> --out <prefix> [--js] [--depth N] [--budget N] [--reload static|expected-deal|sampled] [--samples N] [--memo off|charged|free]");
  process.exit(1);
}

const limits = { depth, budget };
const reload: Reload = values.reload === "sampled" ? { rule: "sampled", samples } : { rule: values.reload };
const memo: Memo = values.memo;

const scratch = mkdtempSync(join(tmpdir(), "buckshot-rust-inputs-"));
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
  readonly by_whom: string;
  readonly legal_json: string;
  readonly label: string;
  readonly raw: string;
}

const listed = new Map<string, Set<number>>();
const order: Array<string> = [];

for (const line of readFileSync(resolve(values.decisions), "utf8").split("\n").filter((text) => text.trim() !== "")) {
  const parsed = /^(\S+) (\d+)$/.exec(line.trim());

  if (parsed === null) {
    console.error(`--decisions takes lines of "<match id> <ordinal>", not "${line}".`);
    process.exit(1);
  }

  const id = parsed[1] ?? "";

  listed.set(id, (listed.get(id) ?? new Set()).add(Number(parsed[2])));
  order.push(`${id} ${Number(parsed[2])}`);
}

const source = new Database(resolve(values.db), { readonly: true });

const matches = source
  .query<MatchRow, []>("SELECT m.id, m.name, m.manifest_json FROM matches m WHERE m.manifest_json IS NOT NULL AND m.replay_status = 'validated'")
  .all()
  .filter((match) => listed.has(match.id));

const rows = new Map<string, string>();

for (const match of matches) {
  const decisions = source
    .query<DecisionRow, [string]>("SELECT d.ordinal, d.player, d.by_whom, d.legal_json, d.label, r.raw FROM decisions d JOIN source_records r ON r.id = d.source_record WHERE d.match_id = ? ORDER BY d.ordinal")
    .all(match.id);

  const manifest = decodeManifest(match.manifest_json);
  const moves: Array<MoveLine> = [];
  let replay = Result.getOrThrow(replayOf(Option.none(), manifest, []));
  const current = (): AgentSource => Option.getOrThrow(replay.session.current(replay.table));
  const roster = rosterOf(current().game.seats, current().letters);

  for (const decision of decisions) {
    if (decision.by_whom === "agent" && listed.get(match.id)?.has(decision.ordinal)) {
      const before = current();
      const me = Option.getOrThrow(roster.find(decodeLetter(decision.player))).seat;
      const input = { table: before.game.table, items: true, board: boardOf(before.game), log: ownLog(before.events, before.learned, me), me };

      // The player's own move order (legal_json orders steal and use moves differently); a search of no depth gives every move its static value.
      const ordered = player.analyse(input, { depth: 0, budget: 0 }, { rule: "static" });

      if (ordered.kind !== "analysed") throw new Error(`${match.name} ${decision.ordinal}: the player calls the position invalid: ${ordered.reason}`);

      const menu = ordered.lines.map((line) => agentMoveText(roster, me, line.steps));
      const legal = new Set(decodeMenu(decision.legal_json).map(({ label }) => label));

      if (menu.length !== legal.size || !menu.every((label) => legal.has(label))) {
        throw new Error(`${match.name} ${decision.ordinal}: the player's moves [${menu.join("; ")}] are not the recorded menu [${[...legal].join("; ")}]`);
      }

      const row = { id: match.id, ordinal: decision.ordinal, me, table: input.table, input: nativeInput(input), menu, chosen: decision.label };

      if (values.js) {
        const started = performance.now();
        const analysis = player.analyse(input, limits, reload, memo);
        const ms = performance.now() - started;

        const js =
          analysis.kind === "invalid"
            ? analysis
            : { kind: analysis.kind, best: analysis.best, score: analysis.lines[analysis.best]?.score, nodes: analysis.nodes, depth: analysis.depth, limited: analysis.limited, ...analysis.cached, lines: analysis.lines.map((line) => ({ code: moveCode(line.steps), score: line.score, reach: line.reach })) };

        rows.set(`${match.id} ${decision.ordinal}`, JSON.stringify({ ...row, js, reference: player.version, ms }));
      } else {
        rows.set(`${match.id} ${decision.ordinal}`, JSON.stringify(row));
      }
    }

    moves.push(decodeMove(decision.raw));
    replay = Result.getOrThrow(replayOf(Option.some(replay), manifest, moves));
  }
}

const out = order.flatMap((key) => rows.get(key) ?? []);

writeFileSync(`${values.out}.jsonl`, out.join("\n") + "\n");

console.error(`${out.length} of ${order.length} decisions`);
