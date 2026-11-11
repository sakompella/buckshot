import { existsSync, mkdtempSync, rmSync, renameSync, writeFileSync } from "node:fs";
import { basename, dirname, join, resolve } from "node:path";
import { parseArgs } from "node:util";

import { Effect, Schema } from "effect";

import { AGGREGATE_NAMES, aggregatesOf, encodeAggregates } from "../src/arena-viewer/aggregates.ts";
import { openArena } from "../src/arena-viewer/load.ts";
import { withPotShares } from "../src/arena-viewer/page/data.ts";
import { Manifest, privacyViolations } from "../src/arena-viewer/privacy.ts";
import { decodeArgs, runMain, ScriptError } from "../src/script.ts";

// Writes the arena page's aggregate files (src/arena-viewer/aggregates.ts) for the online site: per config and per pair
// of configs, never per match. Reads the arena analysis database and the derived databases, and replaces --out only
// when the files pass src/arena-viewer/privacy.ts.

const USAGE = "usage: bun scripts/arena-export.ts <db> --out <dir> [--regret <regret db>] [--knowledge <knowledge db>] [--certain-mistakes <opportunities db>] [--luck <luck db>]";

const Flags = Schema.Struct({ out: Schema.String, regret: Schema.optional(Schema.String), knowledge: Schema.optional(Schema.String), "certain-mistakes": Schema.optional(Schema.String), luck: Schema.optional(Schema.String) });

const usage = () => new ScriptError({ message: USAGE, exitCode: 1 });

const isMissing = (path: string | undefined) => path !== undefined && !existsSync(path);

const encodeManifest = Schema.encodeSync(Schema.fromJsonString(Manifest));

const ioError = (doing: string) => (cause: unknown) => new ScriptError({ message: `cannot ${doing}: ${String(cause)}`, exitCode: 1 });

const program = Effect.gen(function* () {
  const options = { out: { type: "string" }, regret: { type: "string" }, knowledge: { type: "string" }, "certain-mistakes": { type: "string" }, luck: { type: "string" } } as const;
  const parsed = yield* Effect.try({ try: () => parseArgs({ allowPositionals: true, options }), catch: usage });
  const { out, regret, knowledge, "certain-mistakes": certain, luck } = yield* decodeArgs(Flags, USAGE)(parsed.values);
  const [dbPath] = parsed.positionals;

  if (dbPath === undefined || isMissing(dbPath) || isMissing(regret) || isMissing(knowledge) || isMissing(certain) || isMissing(luck)) return yield* Effect.fail(usage());

  const json = yield* openArena(dbPath, { regret, knowledge, certain, luck }).pipe(
    Effect.map((arena) => encodeAggregates(aggregatesOf({ seats: withPotShares(arena.seats), decisions: arena.decisions, certain: arena.certain.summary.rates, consistency: arena.consistency, luck: arena.luck }))),
    Effect.scoped,
  );

  const generated = new Date().toISOString().slice(0, 10);
  const manifest = encodeManifest({ generated, files: AGGREGATE_NAMES.map((name) => ({ name, bytes: Buffer.byteLength(json[name]) })) });
  const files = new Map<string, string>([...AGGREGATE_NAMES.map((name) => [name, json[name]] as const), ["manifest", manifest]]);
  const target = resolve(out);

  // Removed on every exit; after the rename the path is gone and this does nothing.
  const staging = yield* Effect.acquireRelease(
    Effect.try({ try: () => mkdtempSync(join(dirname(target), `.${basename(target)}-`)), catch: ioError(`make a staging directory beside ${target}`) }),
    (dir) => Effect.sync(() => rmSync(dir, { recursive: true, force: true })),
  );

  yield* Effect.try({ try: () => { for (const [name, text] of files) writeFileSync(join(staging, `${name}.json`), text); }, catch: ioError(`write ${staging}`) });

  const violations = privacyViolations(files);

  if (violations.length > 0) return yield* Effect.fail(new ScriptError({ message: `not written, the files fail the privacy check:\n${violations.join("\n")}`, exitCode: 1 }));

  yield* Effect.try({ try: () => { rmSync(target, { recursive: true, force: true }); renameSync(staging, target); }, catch: ioError(`replace ${target}`) });

  for (const [name, text] of files) console.log(`${`${name}.json`.padEnd(18)} ${String(Buffer.byteLength(text)).padStart(9)} B  ${String(Bun.gzipSync(text).length).padStart(8)} B gzipped`);

  console.log(`wrote ${files.size} files to ${target}`);
}).pipe(Effect.scoped);

await runMain(program);
