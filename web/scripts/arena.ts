import { createModels } from "@earendil-works/pi-ai";
import { Cause, Effect, Exit, Schema } from "effect";

import { AgentId, seatingOf } from "../src/arena/agent.ts";
import { agentEndpoint, describeEndpoint, modelRefOf, providerIdOf, providerOf } from "../src/arena/endpoints.ts";
import { DELIVERIES, playMatch } from "../src/arena/match.ts";

// Plays one match between agents configured in web/.env (see .env.example), to
// game over, and writes its run directory. --agents picks the agents, and
// --rotation seats them: rotation 0 puts the first at Player 1. --delivery picks
// how the log reaches players (on-turn or live). Rerunning with the same --dir
// resumes the match from its store, with the settings it started with.
// Usage: bun scripts/arena.ts [--dir ../_work/arena/<name>] [--seed N] [--agents A,B] [--rotation 0] [--delivery on-turn]

const flag = (name: string, fallback: string): string => {
  const at = process.argv.indexOf(`--${name}`);

  return at === -1 ? fallback : (process.argv[at + 1] ?? fallback);
};

const dir = flag("dir", `../_work/arena/${new Date().toISOString().replaceAll(":", "").slice(0, 15)}`);

const seed = flag("seed", String(Math.floor(Math.random() * 2 ** 31)));

const agents = Schema.decodeUnknownSync(Schema.Array(AgentId))(flag("agents", "A,B").split(","));

const seating = seatingOf(agents, Number(flag("rotation", "0")));

const delivery = Schema.decodeUnknownSync(Schema.Literals(DELIVERIES))(flag("delivery", "on-turn"));

const program = Effect.gen(function* () {
  const models = createModels();

  const entrants = yield* Effect.forEach(seating, (agent) =>
    Effect.map(agentEndpoint(agent), (endpoint) => {
      const providerId = providerIdOf(agent, endpoint);

      models.setProvider(providerOf(providerId, endpoint));

      return { agent, model: modelRefOf(providerId, endpoint), thinkingLevel: endpoint.effort, describe: describeEndpoint(endpoint) };
    }),
  );

  console.error(`arena: ${dir}, seed ${seed}, ${delivery} delivery, seating ${seating.map((agent, index) => `Player ${index + 1}: ${agent}`).join(", ")}`);

  return yield* playMatch({ dir, seed, controllers: seating.map(() => "Agent"), entrants, models, compaction: {}, delivery });
});

Exit.match(await Effect.runPromiseExit(program), {
  onSuccess: (result) => console.log(JSON.stringify({ dir, ...result }, null, 2)),
  onFailure: (cause) => {
    console.error(Cause.pretty(cause));
    process.exitCode = 1;
  },
});
