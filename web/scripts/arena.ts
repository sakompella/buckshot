import { createModels } from "@earendil-works/pi-ai";
import { Cause, Effect, Exit } from "effect";

import { describeEndpoint, modelRefOf, PLAYER_PREFIXES, playerEndpoint, providerOf } from "../src/arena/endpoints.ts";
import { type Entrant, playMatch } from "../src/arena/match.ts";

// Plays one 2-player match between the two models configured in web/.env (see
// .env.example), to game over, and writes its run directory. Rerunning with the
// same --dir resumes the match from its store.
// Usage: bun scripts/arena.ts [--dir ../_work/arena/<name>] [--seed N]

const flag = (name: string, fallback: string): string => {
  const at = process.argv.indexOf(`--${name}`);

  return at === -1 ? fallback : (process.argv[at + 1] ?? fallback);
};

const dir = flag("dir", `../_work/arena/${new Date().toISOString().replaceAll(":", "").slice(0, 15)}`);

const seed = flag("seed", String(Math.floor(Math.random() * 2 ** 31)));

const program = Effect.gen(function* () {
  const endpoints = yield* Effect.all(PLAYER_PREFIXES.slice(0, 2).map(playerEndpoint));
  const models = createModels();

  const entrants = endpoints.map((endpoint, index): Entrant => {
    const providerId = `player-${index + 1}`;

    models.setProvider(providerOf(providerId, endpoint));

    return { model: modelRefOf(providerId, endpoint), thinkingLevel: endpoint.effort, describe: describeEndpoint(endpoint) };
  });

  console.error(`arena: ${dir}, seed ${seed}`);

  return yield* playMatch({ dir, seed, controllers: ["Agent", "Agent"], entrants, models, compaction: {} });
});

Exit.match(await Effect.runPromiseExit(program), {
  onSuccess: (result) => console.log(JSON.stringify({ dir, ...result }, null, 2)),
  onFailure: (cause) => {
    console.error(Cause.pretty(cause));
    process.exitCode = 1;
  },
});
