import { Database } from "bun:sqlite";
import { existsSync, mkdtempSync, rmSync, renameSync, writeFileSync } from "node:fs";
import { basename, dirname, join, resolve } from "node:path";
import { parseArgs } from "node:util";

import { Effect, Schema } from "effect";

import { AGGREGATE_NAMES, aggregatesOf, encodeAggregates } from "../src/arena-viewer/aggregates.ts";
import { loadArena } from "../src/arena-viewer/load.ts";
import { withPotShares } from "../src/arena-viewer/page/data.ts";
import { Manifest, privacyViolations } from "../src/arena-viewer/privacy.ts";
import { decodeArgs, runMain, ScriptError } from "../src/script.ts";

// Writes the arena page's aggregate files (src/arena-viewer/aggregates.ts) for the online site: per config and per pair
// of configs, never per match. Reads only a public database, one whose provenance is blanked
// (tools/arena/redact_database.py), and replaces --out only when the files pass src/arena-viewer/privacy.ts.

const USAGE = "usage: bun scripts/arena-export.ts <public db> --out <dir> [--regret <regret db>] [--knowledge <knowledge db>] [--certain-mistakes <opportunities db>]";

const Flags = Schema.Struct({ out: Schema.String, regret: Schema.optional(Schema.String), knowledge: Schema.optional(Schema.String), "certain-mistakes": Schema.optional(Schema.String) });

const usage = () => new ScriptError({ message: USAGE, exitCode: 1 });

const isMissing = (path: string | undefined) => path !== undefined && !existsSync(path);

const encodeManifest = Schema.encodeSync(Schema.fromJsonString(Manifest));

const provenanceCount = (dbPath: string): number => {
  const db = new Database(dbPath, { readonly: true });
  const row = db.query<{ readonly n: number }, []>("select count(*) n from match_seats where provenance_json is not null").get();

  db.close();

  return row?.n ?? 0;
};

const program = Effect.gen(function* () {
  const options = { out: { type: "string" }, regret: { type: "string" }, knowledge: { type: "string" }, "certain-mistakes": { type: "string" } } as const;
  const parsed = yield* Effect.try({ try: () => parseArgs({ allowPositionals: true, options }), catch: usage });
  const { out, regret, knowledge, "certain-mistakes": certain } = yield* decodeArgs(Flags, USAGE)(parsed.values);
  const [dbPath] = parsed.positionals;

  if (dbPath === undefined || isMissing(dbPath) || isMissing(regret) || isMissing(knowledge) || isMissing(certain)) return yield* Effect.fail(usage());

  const withProvenance = provenanceCount(dbPath);

  if (withProvenance > 0) return yield* Effect.fail(new ScriptError({ message: `${dbPath} is not a public database: ${withProvenance} seats keep their provenance`, exitCode: 1 }));

  const arena = loadArena(dbPath, { regret, knowledge, certain });
  const json = encodeAggregates(aggregatesOf({ seats: withPotShares(arena.seats), decisions: arena.decisions, certain: arena.certain.summary.rates, consistency: arena.consistency }));

  arena.db.close();

  const generated = new Date().toISOString().slice(0, 10);
  const manifest = encodeManifest({ generated, files: AGGREGATE_NAMES.map((name) => ({ name, bytes: Buffer.byteLength(json[name]) })) });
  const files = new Map<string, string>([...AGGREGATE_NAMES.map((name) => [name, json[name]] as const), ["manifest", manifest]]);
  const target = resolve(out);
  const staging = mkdtempSync(join(dirname(target), `.${basename(target)}-`));

  for (const [name, text] of files) writeFileSync(join(staging, `${name}.json`), text);

  const violations = privacyViolations(files);

  if (violations.length > 0) {
    rmSync(staging, { recursive: true });

    return yield* Effect.fail(new ScriptError({ message: `not written, the files fail the privacy check:\n${violations.join("\n")}`, exitCode: 1 }));
  }

  rmSync(target, { recursive: true, force: true });
  renameSync(staging, target);

  for (const [name, text] of files) console.log(`${`${name}.json`.padEnd(18)} ${String(Buffer.byteLength(text)).padStart(9)} B  ${String(Bun.gzipSync(text).length).padStart(8)} B gzipped`);

  console.log(`wrote ${files.size} files to ${target}`);
});

await runMain(program);
