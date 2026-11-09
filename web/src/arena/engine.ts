import { writeFileSync } from "node:fs";
import { join } from "node:path";

import { Option, Schema } from "effect";

import { type AgentSource } from "../agent/view.ts";
import { nativeInput } from "../analysis/native-input.ts";
import { boardOf, ownLog, RawMove, stepsOf } from "../analysis/player.ts";
import { type Letter, rosterOf } from "../players.ts";
import { agentMoveText } from "../text.ts";
import { type EngineSeat } from "./agent.ts";

// Engine seats: the Rust search (sim/rust, buckshot-search) plays them the way the regret scorer
// (tools/arena/score_regret.py) values a move. The position is the player's own log and the public board, so the
// engine knows what the player knows and nothing else; every move is valued at the seat's depth and node budget with
// static reload, unpruned, and the first best move is played. Rust's root moves must be Bend's menu: if they differ,
// the rules disagree, which is a bug, so the match stops and the position is dumped for a look.

const RUST = new URL("../../../sim/rust", import.meta.url).pathname;

const SearchResult = Schema.Struct({
  lines: Schema.optional(Schema.Array(Schema.Struct({ move: RawMove, score: Schema.Number }))),
  best: Schema.optional(Schema.Int),
  depth: Schema.optional(Schema.Int),
  nodes: Schema.Number,
  error: Schema.optional(Schema.String),
});

const decodeResult = Schema.decodeUnknownOption(Schema.fromJsonString(SearchResult));

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
  /** The move for `player` at its turn, from `menu`, the labels of its moves in Bend's menu. A disagreement with Bend is dumped in the match's `dir`. */
  readonly choose: (source: AgentSource, player: Letter, seat: EngineSeat, menu: ReadonlyArray<string>, at: { readonly dir: string; readonly turn: number }) => EngineChoice;
}

const sameMoves = (left: ReadonlyArray<string>, right: ReadonlyArray<string>) => JSON.stringify([...new Set(left)].toSorted()) === JSON.stringify([...new Set(right)].toSorted());

/** Finds the search binary, once per match process. */
export const openEngine = (): Engine => {
  const binary = searchBinary();

  return {
    choose: (source, letter, seat, menu, { dir, turn }) => {
      const [, depth, budget, reload] = seat.split("/");
      const roster = rosterOf(source.game.seats, source.letters);
      const me = Option.getOrThrow(roster.find(letter)).seat;
      const input = nativeInput({ table: source.game.table, items: true, board: boardOf(source.game), log: ownLog(source.events, source.learned, me), me });

      const search = Bun.spawnSync([binary, "--evaluator", "bounded-v1-f64", "--unpruned", "--depth", depth ?? "", "--budget", budget ?? "", "--reload", reload ?? "static", "--threads", "1"], {
        stdin: Buffer.from(`${JSON.stringify({ id: "engine", ordinal: 0, input })}\n`),
        stderr: "pipe",
      });

      const output = search.stdout.toString().trim();

      const fault = (problem: string): never => {
        const dump = join(dir, `engine-fault-turn-${turn}-${letter}.json`);

        writeFileSync(dump, `${JSON.stringify({ match: dir, turn, player: letter, seat, input, menu, exit_code: search.exitCode, output, stderr: search.stderr.toString() }, null, 2)}\n`);
        console.error(`engine fault, dumped to ${dump}`);

        throw new Error(`${problem}; dumped to ${dump}`);
      };

      if (search.exitCode !== 0) return fault(`buckshot-search exited ${search.exitCode}`);

      const result = Option.getOrElse(decodeResult(output), () => fault("buckshot-search wrote no result"));

      if (result.error !== undefined) return fault(`buckshot-search: ${result.error}`);

      const labels = (() => {
        try {
          return (result.lines ?? []).map(({ move }) => agentMoveText(roster, me, stepsOf(move)));
        } catch (cause) {
          return fault(`buckshot-search wrote a move this table cannot have: ${String(cause)}`);
        }
      })();

      if (!sameMoves(labels, menu)) return fault(`buckshot-search's root moves ${JSON.stringify(labels)} are not Bend's menu ${JSON.stringify(menu)}`);

      const label = labels[result.best ?? -1];

      if (label === undefined) return fault(`buckshot-search's best move ${result.best} is not one of its moves`);

      return { label, depth: result.depth ?? 0, nodes: result.nodes };
    },
  };
};
