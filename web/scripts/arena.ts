import { createModels } from "@earendil-works/pi-ai";
import { Cause, Effect, Exit, Schema } from "effect";

import { type AgentId, SeatSpec, seatingOf } from "../src/arena/agent.ts";
import { agentEndpoint, modelRefOf, provenanceOf, providerIdOf, providerOf } from "../src/arena/endpoints.ts";
import { listenForHuman } from "../src/arena/human.ts";
import { DELIVERIES, playMatch } from "../src/arena/match.ts";
import type { Letter } from "../src/players.ts";

// Plays one match to game over and writes its run directory. --seats lists who
// plays: agents by letter, configured in web/.env (see .env.example), the DoN
// and Story bots, and Human for a person at a terminal. --rotation rotates the
// seats: rotation 0 puts the first at position 1. Agent A plays as Player A
// wherever it sits. --delivery picks how the log reaches players (on-turn or
// live). For each Human seat the arena prints a command to run in another
// terminal, and waits for it. Rerunning with the same --dir resumes the match
// from its store, with the settings it started with.
// Usage: bun scripts/arena.ts [--dir ../_work/arena/<name>] [--seed N] [--seats A,B,DoN] [--rotation 0] [--delivery on-turn]

const flag = (name: string, fallback: string): string => {
  const at = process.argv.indexOf(`--${name}`);

  return at === -1 ? fallback : (process.argv[at + 1] ?? fallback);
};

const dir = flag("dir", `../_work/arena/${new Date().toISOString().replaceAll(":", "").slice(0, 15)}`);

const seed = flag("seed", String(Math.floor(Math.random() * 2 ** 31)));

const seating = seatingOf(Schema.decodeUnknownSync(Schema.Array(SeatSpec))(flag("seats", "A,B").split(",")), Number(flag("rotation", "0")));

const delivery = Schema.decodeUnknownSync(Schema.Literals(DELIVERIES))(flag("delivery", "on-turn"));

const isAgent = (seat: SeatSpec): seat is AgentId => seat !== "DoN" && seat !== "Story" && seat !== "Human";

/** A Human seat's socket. It sits in /tmp because a Unix socket path must be short. */
const connectHuman = async (player: Letter) => {
  const path = `/tmp/buckshot-arena-${process.pid}-${player}.sock`;
  const { connected } = await listenForHuman(path);

  console.error(`Player ${player} is Human. In another terminal, from web/, run: bun scripts/arena-human.ts ${path}`);

  return connected;
};

const program = Effect.gen(function* () {
  const models = createModels();

  const entrants = yield* Effect.forEach(seating.filter(isAgent), (agent) =>
    Effect.map(agentEndpoint(agent), (endpoint) => {
      const providerId = providerIdOf(agent, endpoint);

      models.setProvider(providerOf(providerId, endpoint));

      return { agent, model: modelRefOf(providerId, endpoint), thinkingLevel: endpoint.effort, provenance: provenanceOf(providerId, endpoint) };
    }),
  );

  console.error(`arena: ${dir}, seed ${seed}, ${delivery} delivery, seating ${seating.map((seat, index) => `position ${index + 1}: ${seat}`).join(", ")}`);

  return yield* playMatch({ dir, seed, controllers: seating.map((seat) => (isAgent(seat) ? "Agent" : seat)), entrants, connectHuman, models, delivery });
});

Exit.match(await Effect.runPromiseExit(program), {
  onSuccess: (result) => console.log(JSON.stringify({ dir, ...result }, null, 2)),
  onFailure: (cause) => {
    console.error(Cause.pretty(cause));
    process.exitCode = 1;
  },
});
