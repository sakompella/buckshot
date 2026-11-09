import { mkdtempSync, rmSync } from "node:fs";
import { tmpdir } from "node:os";
import { join } from "node:path";

import { Option, Schema } from "effect";

import { type AgentSource } from "../agent/view.ts";
import { nativeInput } from "../analysis/native-input.ts";
import { boardOf, loadPlayer, ownLog } from "../analysis/player.ts";
import { type Letter, rosterOf } from "../players.ts";
import { agentMoveText } from "../text.ts";
import { type EngineSeat } from "./agent.ts";

// Engine seats: the Rust search (sim/rust, buckshot-search) plays them the way the regret scorer
// (tools/arena/score_regret.py) values a move. The position is the player's own log and the public board, so the
// engine knows what the player knows and nothing else; every move is valued at the seat's depth and node budget with
// static reload, unpruned, and the first best move is played. The Bend player (sim/bend-mp/analysis.bend) gives the
// moves' order, as in web/scripts/rust-search-inputs.ts, so each search line gets its arena label.

const RUST = new URL("../../../sim/rust", import.meta.url).pathname;

const SearchResult = Schema.Struct({
  lines: Schema.optional(Schema.Array(Schema.Struct({ score: Schema.Number }))),
  best: Schema.optional(Schema.Int),
  depth: Schema.optional(Schema.Int),
  nodes: Schema.Number,
  error: Schema.optional(Schema.String),
});

const decodeResult = Schema.decodeUnknownSync(Schema.fromJsonString(SearchResult));

/** The binary $BUCKSHOT_SEARCH names, or the one cargo builds in sim/rust with the scorer's features. */
const searchBinary = (): string => {
  const given = process.env["BUCKSHOT_SEARCH"];

  if (given !== undefined) return given;

  const build = Bun.spawnSync([process.env["CARGO"] ?? "cargo", "build", "--release", "--quiet", "-p", "buckshot-search", "--no-default-features", "--features", "f64,seats-2", "--message-format", "json"], { cwd: RUST, stderr: "pipe" });

  if (build.exitCode !== 0) throw new Error(`buckshot-search build failed:\n${build.stderr.toString()}`);

  const built = build.stdout
    .toString()
    .split("\n")
    .flatMap((line) => {
      const message: unknown = line.startsWith("{") ? JSON.parse(line) : undefined;

      return Schema.is(Schema.Struct({ reason: Schema.Literal("compiler-artifact"), target: Schema.Struct({ name: Schema.Literal("buckshot-search") }), executable: Schema.String }))(message) ? [message.executable] : [];
    })[0];

  if (built === undefined) throw new Error("cargo built no buckshot-search binary");

  return built;
};

/** One engine move: its label in the player's view, and what the search reached. */
export interface EngineChoice {
  readonly label: string;
  readonly depth: number;
  readonly nodes: number;
}

export interface Engine {
  readonly choose: (source: AgentSource, player: Letter, seat: EngineSeat) => EngineChoice;
}

/** Builds the Bend player and finds the search binary, once per match process. */
export const openEngine = async (): Promise<Engine> => {
  const scratch = mkdtempSync(join(tmpdir(), "buckshot-engine-"));
  const player = await loadPlayer(scratch).finally(() => rmSync(scratch, { recursive: true, force: true }));
  const binary = searchBinary();

  return {
    choose: (source, letter, seat) => {
      const [, depth, budget, reload] = seat.split("/");
      const roster = rosterOf(source.game.seats, source.letters);
      const me = Option.getOrThrow(roster.find(letter)).seat;

      const input = { table: source.game.table, items: true, board: boardOf(source.game), log: ownLog(source.events, source.learned, me), me };
      const ordered = player.analyse(input, { depth: 0, budget: 0 }, { rule: "static" });

      if (ordered.kind !== "analysed") throw new Error(`the player refuses Player ${letter}'s position: ${ordered.reason}`);

      const search = Bun.spawnSync([binary, "--evaluator", "bounded-v1-f64", "--unpruned", "--depth", depth ?? "", "--budget", budget ?? "", "--reload", reload ?? "static", "--threads", "1"], {
        stdin: Buffer.from(`${JSON.stringify({ id: "engine", ordinal: 0, input: nativeInput(input) })}\n`),
        stderr: "pipe",
      });

      if (search.exitCode !== 0) throw new Error(`buckshot-search exited ${search.exitCode}: ${search.stderr.toString()}`);

      const result = decodeResult(search.stdout.toString().trim());

      if (result.error !== undefined || result.lines?.length !== ordered.lines.length || result.best === undefined) throw new Error(`buckshot-search: ${result.error ?? `${result.lines?.length} lines for ${ordered.lines.length} moves`}`);

      const best = ordered.lines[result.best];

      if (best === undefined) throw new Error(`buckshot-search's best move ${result.best} is not a move`);

      return { label: agentMoveText(roster, me, best.steps), depth: result.depth ?? 0, nodes: result.nodes };
    },
  };
};
