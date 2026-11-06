import { existsSync } from "node:fs";
import { fileURLToPath } from "node:url";
import { parseArgs } from "node:util";

import { Effect, Schema } from "effect";

import { serveArenaViewer } from "../src/arena-viewer/server.ts";
import { decodeArgs, runMain, ScriptError } from "../src/script.ts";

// Serves the site (web/dist, from `bun run build`) with the arena viewer's API over the arena analysis database (docs/arena/database.md). With --regret it also shows the
// regret table of a derived database (docs/arena/analysis/regret.md); without, the viewer has no regret. With --regret-sampled, the sampled-reload scores replace the static ones for the decisions they cover (docs/arena/analysis/accuracy.md). With --knowledge
// it also shows how consistent each config is in repeated positions (the knowledge database of scripts/arena-knowledge.ts).
// Usage: bun scripts/arena-viewer.ts <db> [host] [port] [--regret <regret db>] [--regret-sampled <sampled regret db>] [--knowledge <knowledge db>] [--certain-mistakes <opportunities db>]

const USAGE = "usage: bun scripts/arena-viewer.ts <db> [host] [port] [--regret <regret db>] [--regret-sampled <sampled regret db>] [--knowledge <knowledge db>] [--certain-mistakes <opportunities db>]";

const Flags = Schema.Struct({ regret: Schema.optional(Schema.String), "regret-sampled": Schema.optional(Schema.String), knowledge: Schema.optional(Schema.String), "certain-mistakes": Schema.optional(Schema.String) });

const Port = Schema.NumberFromString.check(Schema.isInt());

const usage = () => new ScriptError({ message: USAGE, exitCode: 1 });

const isMissing = (path: string | undefined) => path !== undefined && !existsSync(path);

const program = Effect.gen(function* () {
  const parsed = yield* Effect.try({ try: () => parseArgs({ allowPositionals: true, options: { regret: { type: "string" }, "regret-sampled": { type: "string" }, knowledge: { type: "string" }, "certain-mistakes": { type: "string" } } }), catch: usage });
  const flags = yield* decodeArgs(Flags, USAGE)(parsed.values);
  const [dbPath, host = "127.0.0.1", port = "8790"] = parsed.positionals;
  const { regret: regretPath, "regret-sampled": sampledPath, knowledge: knowledgePath, "certain-mistakes": certainPath } = flags;

  if (dbPath === undefined || isMissing(dbPath) || isMissing(regretPath) || isMissing(sampledPath) || isMissing(knowledgePath) || isMissing(certainPath)) return yield* Effect.fail(usage());

  const siteDir = fileURLToPath(new URL("../dist", import.meta.url));

  if (!existsSync(`${siteDir}/index.html`)) return yield* Effect.fail(new ScriptError({ message: `no built site at ${siteDir}: run \`bun run build\` first`, exitCode: 1 }));

  const listenPort = yield* Schema.decodeUnknownEffect(Port)(port).pipe(Effect.mapError(usage));

  const server = yield* Effect.acquireRelease(
    Effect.try({ try: () => serveArenaViewer(dbPath, siteDir, host, listenPort, { regret: regretPath, regretSampled: sampledPath, knowledge: knowledgePath, certain: certainPath }), catch: (cause) => new ScriptError({ message: `cannot serve: ${String(cause)}`, exitCode: 1 }) }),
    (running) => Effect.promise(() => running.stop()),
  );

  console.log(`arena viewer: ${server.url.href} reading ${[dbPath, regretPath, sampledPath, knowledgePath, certainPath].filter((path) => path !== undefined).join(" and ")}`);

  return yield* Effect.never;
}).pipe(Effect.scoped);

await runMain(program);
