import { readFileSync, writeFileSync } from "node:fs";
import { mkdtempSync, rmSync } from "node:fs";
import { tmpdir } from "node:os";
import { join, resolve } from "node:path";
import { parseArgs } from "node:util";

import { Database } from "bun:sqlite";
import { Option, Result, Schema } from "effect";

import { type AgentSource } from "../src/agent/view.ts";
import { type BendNode } from "../generated/rules.mjs";
import { boardOf, loadPlayer, logNode, ownLog, type Analysis, type Memo, type Reload } from "../src/analysis/player.ts";
import { RunManifest } from "../src/arena/match.ts";
import { MoveLine } from "../src/arena/runlog.ts";
import { rosterOf } from "../src/players.ts";
import { replayOf } from "../src/arena/replay.ts";

// THROWAWAY: runs the JS minimax player on listed decisions and writes the number lines sim/bend-mp/native.bend decodes.
//   bun scripts/native-eval.ts --db <sqlite> --decisions <list> --out <prefix> [--depth 6] [--budget 20000] [--reload static|expected-deal|sampled] [--samples 256] [--memo off|charged|free]
// Writes <prefix>.in (one input per line) and <prefix>.js (one JSON result per line, with ms).

const { values } = parseArgs({ args: process.argv.slice(2), options: { db: { type: "string" }, decisions: { type: "string" }, out: { type: "string" }, depth: { type: "string", default: "6" }, budget: { type: "string", default: "20000" }, reload: { type: "string", default: "static" }, samples: { type: "string", default: "256" }, memo: { type: "string", default: "off" } } });

const limits = { depth: Number(values.depth), budget: Number(values.budget) };
const reload = (values.reload === "sampled" ? { rule: "sampled", samples: Number(values.samples) } : { rule: values.reload }) as Reload;
const memo = values.memo as Memo;

const ENUMS = ["Seat0", "Seat1", "Seat2", "Seat3"];
const TAGS: Record<string, number> = {};
const tags = (names: ReadonlyArray<string>) => names.forEach((name, index) => (TAGS[name] = index));
tags(["Seat0", "Seat1", "Seat2", "Seat3"]);
tags(["Saw", "Glass", "Jammer", "Cigarettes", "Beer", "Phone", "Inverter", "Adrenaline", "Remote"]);
tags(["Slot0", "Slot1", "Slot2", "Slot3", "Slot4", "Slot5", "Slot6", "Slot7"]);
tags(["Live", "Blank"]);
tags(["Single", "Double"]);
tags(["Clockwise", "CounterClockwise"]);
tags(["Idle", "Aiming", "Jamming", "Stealing"]);
tags(["None", "Some"]);
tags(["Duo", "Trio", "Quad"]);
tags(["Unjammed", "Jammed"]);
tags(["NotGrabbing", "Grabbing", "Holding"]);
tags(["Setup", "Distributing", "Loading", "Playing", "MatchOver"]);
tags(["Witnessed", "Learned"]);
tags(["RoundBegan", "GrabbingBegan", "Granted", "Placed", "GrabbingEnded", "DistributionDone", "Loaded", "TurnSkipped", "JamLifted", "TurnGiven", "PickedUp", "Fired", "Died", "Used", "Healed", "Ejected", "Inverted", "JamApplied", "DirectionFlipped", "RoundWon", "MatchConcluded"]);
tags(["Glimpse", "Clue", "NoClue", "EmptyBriefcase"]);
void ENUMS;

// Types with one constructor carry no tag in the decoders.
const SINGLE = new Set(["Board", "RoundView", "GunView", "SeatView", "Load", "Slots"]);

const nameOf = (node: BendNode): string => node.$.split(/[./]/).pop() ?? "";

/** Numbers of a Bend value, fields in constructor order. A list is its length then its items last first, because native.bend's decoders cons each item onto the front. */
const encode = (value: unknown): ReadonlyArray<number> => {
  if (typeof value === "bigint" || typeof value === "number") return [Number(value)];
  if (typeof value === "boolean") return [value ? 1 : 0];

  const node = value as BendNode;
  const name = nameOf(node);

  if (name === "Nil" || name === "Con") {
    const items: Array<unknown> = [];
    let rest: any = node;

    while (nameOf(rest) === "Con") {
      items.push(rest.head);
      rest = rest.tail;
    }

    return [items.length, ...items.toReversed().flatMap(encode)];
  }

  const fields = Object.entries(node).filter(([key]) => key !== "$").flatMap(([, field]) => encode(field));

  if (SINGLE.has(name)) return fields;

  const tag = TAGS[name];

  if (tag === undefined) throw new Error(`no tag for ${node.$}`);

  return [tag, ...fields];
};

const itemIndex = (item: string): number => TAGS[item] ?? -1;

/** A move as native.bend's show.move prints it, from the steps the player's analysis gives. */
const moveCode = (steps: Analysis extends infer A ? any : never): string => {
  const [first, second, third] = steps as ReadonlyArray<any>;

  if (first._tag === "PickUp") return `0.${second.target}`;
  if (first.item === "Jammer") return `2.${second.target}`;
  if (first.item === "Adrenaline") return second.item === "Jammer" ? `4.${second.owner}.${third.target}` : `3.${second.owner}.${itemIndex(second.item)}`;

  return `1.${itemIndex(first.item)}`;
};

const scratch = mkdtempSync(join(tmpdir(), "buckshot-native-"));
const player = await loadPlayer(scratch).finally(() => rmSync(scratch, { recursive: true, force: true }));

const decodeManifest = Schema.decodeUnknownSync(Schema.fromJsonString(RunManifest));
const decodeMove = Schema.decodeUnknownSync(Schema.fromJsonString(MoveLine));
const decodeLetter = Schema.decodeUnknownSync(Schema.Literals(["A", "B", "C", "D"]));

const listed = new Map<string, Set<number>>();

for (const line of readFileSync(resolve(values.decisions!), "utf8").split("\n").filter((l) => l.trim() !== "")) {
  const [id, ordinal] = line.trim().split(" ");
  listed.set(id!, (listed.get(id!) ?? new Set()).add(Number(ordinal)));
}

const source = new Database(resolve(values.db!), { readonly: true });
const matches = source.query<{ id: string; name: string; manifest_json: string }, []>("SELECT m.id, m.name, m.manifest_json FROM matches m WHERE m.manifest_json IS NOT NULL AND m.replay_status = 'validated'").all().filter((m) => listed.has(m.id));

const inputs: Array<string> = [];
const results: Array<string> = [];

for (const match of matches) {
  const decisions = source.query<{ ordinal: number; player: string; by_whom: string; raw: string }, [string]>("SELECT d.ordinal, d.player, d.by_whom, r.raw FROM decisions d JOIN source_records r ON r.id = d.source_record WHERE d.match_id = ? ORDER BY d.ordinal").all(match.id);
  const manifest = decodeManifest(match.manifest_json);
  const moves: Array<MoveLine> = [];
  let replay = Result.getOrThrow(replayOf(Option.none(), manifest, []));
  const current = (): AgentSource => Option.getOrThrow(replay.session.current(replay.table));
  const roster = rosterOf(current().game.seats, current().letters);

  for (const decision of decisions) {
    if (decision.by_whom === "agent" && listed.get(match.id)!.has(decision.ordinal)) {
      const before = current();
      const me = Option.getOrThrow(roster.find(decodeLetter(decision.player))).seat;
      const input = { table: before.game.table, items: true, board: boardOf(before.game), log: ownLog(before.events, before.learned, me), me };
      const started = performance.now();
      const analysis = player.analyse(input, limits, reload, memo);
      const ms = performance.now() - started;
      const numbers = [input.table, 1, ...encode({ $: "domain.Seat" + me }), ...encode(input.board), ...encode(logNode(input.log))];
      inputs.push(numbers.join(" "));
      results.push(JSON.stringify({ id: match.id, ordinal: decision.ordinal, ms, analysis: analysis.kind === "invalid" ? analysis : { best: analysis.best, nodes: analysis.nodes, depth: analysis.depth, limited: analysis.limited, ...analysis.cached, lines: analysis.lines.map((l) => `${moveCode(l.steps)}:${l.score}:${l.reach}`) } }));
    }

    moves.push(decodeMove(decision.raw));
    replay = Result.getOrThrow(replayOf(Option.some(replay), manifest, moves));
  }
}

writeFileSync(`${values.out}.in`, inputs.join("\n") + "\n");
writeFileSync(`${values.out}.js`, results.join("\n") + "\n");
console.error(`${inputs.length} decisions`);
