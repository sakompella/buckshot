import { parseArgs } from "node:util";

import { createModels } from "@earendil-works/pi-ai";
import { Console, Effect, Random, Schema } from "effect";

import { AgentId, SeatSpec, seatingOf } from "../src/arena/agent.ts";
import { agentEndpoint, labelOf, modelRefOf, provenanceOf, providerIdOf, providerOf } from "../src/arena/endpoints.ts";
import { listenForHuman } from "../src/arena/human.ts";
import { playMatch } from "../src/arena/match.ts";
import { DELIVERIES } from "../src/arena/runlog.ts";
import type { Letter } from "../src/players.ts";
import { decodeArgs, runMain, ScriptError } from "../src/script.ts";

// Plays one match to game over and writes its run directory. --seats lists who
// plays: agents by letter, configured in web/.env (see .env.example), the DoN
// and Story bots, Human for a person at a terminal, and Engine/<depth>/<budget>
// for the Rust search (src/arena/engine.ts). --rotation rotates the
// seats: rotation 0 puts the first at position 1. Agent A plays as Player A
// wherever it sits. --delivery picks how the log reaches players (on-turn or
// live). For each Human seat the arena prints a command to run in another
// terminal, and waits for it. Rerunning with the same --dir resumes the match
// from its store, with the settings it started with.
// Usage: bun scripts/arena.ts [--dir ../_work/arena/<name>] [--seed N] [--seats A,B,DoN,Engine/4/20000] [--rotation 0] [--delivery on-turn]

const { values } = parseArgs({
  args: process.argv.slice(2),
  options: {
    dir: { type: "string", default: `../_work/arena/${new Date().toISOString().replaceAll(":", "").slice(0, 15)}` },
    seed: { type: "string" },
    seats: { type: "string", default: "A,B" },
    rotation: { type: "string", default: "0" },
    delivery: { type: "string", default: "on-turn" },
  },
});

const USAGE = "usage: bun scripts/arena.ts [--dir ../_work/arena/<name>] [--seed N] [--seats A,B,DoN,Engine/4/20000] [--rotation 0] [--delivery on-turn|live]";

const Flags = Schema.Struct({
  dir: Schema.String,
  seed: Schema.optional(Schema.String),
  seats: Schema.String,
  rotation: Schema.NumberFromString.check(Schema.isInt()),
  delivery: Schema.Literals(DELIVERIES),
});

const encodeJson = Schema.encodeEffect(Schema.fromJsonString(Schema.Unknown, { space: 2 }));

const isAgent = Schema.is(AgentId);

/** A Human seat's socket. It sits in /tmp because a Unix socket path must be short. */
const connectHuman = async (player: Letter) => {
  const path = `/tmp/buckshot-arena-${process.pid}-${player}.sock`;
  const { connected } = await listenForHuman(path);

  console.error(`Player ${player} is Human. In another terminal, from web/, run: bun scripts/arena-human.ts ${path}`);

  return connected;
};

const program = Effect.gen(function* () {
  const { dir, seed: given, rotation, delivery, ...flags } = yield* decodeArgs(Flags, USAGE)(values);
  const random = yield* Random.nextIntBetween(0, 2 ** 31 - 1);
  const seed = given ?? String(random);
  const seats = yield* Schema.decodeUnknownEffect(Schema.Array(SeatSpec))(flags.seats.split(",")).pipe(Effect.mapError((error) => ScriptError.make({ message: `--seats: ${error.message}\n${USAGE}`, exitCode: 1 })));
  const seating = seatingOf(seats, rotation);
  const models = createModels();

  const entrants = yield* Effect.forEach(seating.filter(isAgent), (agent) =>
    Effect.map(agentEndpoint(agent), (endpoint) => {
      const providerId = providerIdOf(agent, endpoint);

      models.setProvider(providerOf(providerId, endpoint));

      return { agent, label: labelOf(endpoint), model: modelRefOf(providerId, endpoint), thinkingLevel: endpoint.effort, provenance: provenanceOf(providerId, endpoint) };
    }),
    { concurrency: 1 },
  );

  yield* Console.error(`arena: ${dir}, seed ${seed}, ${delivery} delivery, seating ${seating.map((seat, index) => `position ${index + 1}: ${seat}`).join(", ")}`);

  const result = yield* playMatch({ dir, seed, controllers: seating.map((seat) => (isAgent(seat) ? "Agent" : seat)), entrants, connectHuman, models, delivery });

  const summary = yield* encodeJson({ dir, ...result });

  yield* Console.log(summary);
});

await runMain(program);
