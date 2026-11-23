import { existsSync, mkdtempSync, readdirSync, readFileSync, rmSync, renameSync, statSync, writeFileSync } from "node:fs";
import { basename, dirname, join, resolve } from "node:path";
import { parseArgs } from "node:util";

import { Console, DateTime, Effect, Option, Schema } from "effect";

import { AGGREGATE_NAMES, aggregatesOf, encodeAggregates } from "../src/arena-viewer/aggregates.ts";
import { certainProblems } from "../src/arena-viewer/certain.ts";
import { openArena } from "../src/arena-viewer/load.ts";
import { luckProblems } from "../src/arena-viewer/luck.ts";
import { withPotShares } from "../src/arena-viewer/page/data.ts";
import { Manifest, privacyViolations } from "../src/arena-viewer/privacy.ts";
import { decodeArgs, runMain, ScriptError } from "../src/script.ts";

// Writes the arena page's aggregate files (src/arena-viewer/aggregates.ts) for the online site: per config and per pair
// of configs, never per match. Reads the arena analysis database and the derived databases, refuses luck or
// certain-mistake inputs that do not fit the database's scored seats, and replaces --out only when the files pass
// src/arena-viewer/privacy.ts and --out is empty or an earlier export (it holds an export manifest).

const USAGE = "usage: bun scripts/arena-export.ts <db> --out <dir> [--regret <regret db>] [--knowledge <knowledge db>] [--certain-mistakes <opportunities db>] [--luck <luck db>]";

const Flags = Schema.Struct({ out: Schema.String, regret: Schema.optional(Schema.String), knowledge: Schema.optional(Schema.String), "certain-mistakes": Schema.optional(Schema.String), luck: Schema.optional(Schema.String) });

const usage = () => ScriptError.make({ message: USAGE, exitCode: 1 });

const isMissing = (path: string | undefined) => path !== undefined && !existsSync(path);

const encodeManifest = Schema.encodeSync(Schema.fromJsonString(Manifest));

/** What marks a directory as an export: a manifest, from this version or an earlier one. */
const decodeMarker = Schema.decodeUnknownOption(Schema.fromJsonString(Schema.Struct({ generated: Schema.String, files: Schema.Array(Schema.Unknown) })));

/** Whether `--out` may be replaced: missing, empty, or a directory this script wrote, which holds its manifest. */
const isReplaceable = (target: string): boolean => {
  if (!existsSync(target)) { return true; }

  const manifest = join(target, "manifest.json");

  return !statSync(target).isDirectory() ? false : readdirSync(target).length === 0 || (existsSync(manifest) && Option.isSome(decodeMarker(readFileSync(manifest, "utf8"))));
};

const sourceId = (path: string | undefined): string | null => (path === undefined ? null : `sha256:${new Bun.CryptoHasher("sha256").update(readFileSync(path)).digest("hex")}`);

const ioError = (doing: string) => (cause: unknown) => ScriptError.make({ message: `cannot ${doing}: ${String(cause)}`, exitCode: 1 });

const program = Effect.gen(function* () {
  const options = { out: { type: "string" }, regret: { type: "string" }, knowledge: { type: "string" }, "certain-mistakes": { type: "string" }, luck: { type: "string" } } as const;
  const parsed = yield* Effect.try({ try: () => parseArgs({ allowPositionals: true, options }), catch: usage });
  const { out, regret, knowledge, "certain-mistakes": certain, luck } = yield* decodeArgs(Flags, USAGE)(parsed.values);
  const [dbPath] = parsed.positionals;

  const db = yield* dbPath === undefined || isMissing(dbPath) || isMissing(regret) || isMissing(knowledge) || isMissing(certain) || isMissing(luck) ? usage() : Effect.succeed(dbPath);

  const target = resolve(out);

  yield* isReplaceable(target) ? Effect.void : ScriptError.make({ message: `refusing --out ${target}: it is not empty and holds no export manifest; nothing deleted`, exitCode: 1 });

  const { json, problems } = yield* openArena(db, { regret, knowledge, certain, luck }).pipe(
    Effect.map((arena) => {
      const seats = withPotShares(arena.seats);
      const completed = new Set(seats.flatMap(({ matchId, player, status }) => (status === "completed" ? [`${matchId}|${player}`] : [])));

      return {
        json: encodeAggregates(aggregatesOf({ seats, decisions: arena.decisions, certain: arena.certain.summary.rates, consistency: arena.consistency, luck: arena.luck })),
        problems: [...(luck === undefined ? [] : luckProblems(arena.luck, seats)), ...(certain === undefined ? [] : certainProblems(certain, completed))],
      };
    }),
    Effect.scoped,
  );

  yield* problems.length === 0 ? Effect.void : ScriptError.make({ message: `not written, the inputs do not fit the database:\n${problems.join("\n")}`, exitCode: 1 });

  const now = yield* DateTime.now;
  const generated = DateTime.formatIso(now).slice(0, 10);
  const manifest = encodeManifest({ generated, files: AGGREGATE_NAMES.map((name) => ({ name, bytes: Buffer.byteLength(json[name]) })), sources: { luck: sourceId(luck), certain: sourceId(certain) } });
  const files = new Map<string, string>([...AGGREGATE_NAMES.map((name) => [name, json[name]] as const), ["manifest", manifest]]);

  // Removed on every exit; after the rename the path is gone and this does nothing.
  const staging = yield* Effect.acquireRelease(
    Effect.try({ try: () => mkdtempSync(join(dirname(target), `.${basename(target)}-`)), catch: ioError(`make a staging directory beside ${target}`) }),
    (dir) => Effect.sync(() => { rmSync(dir, { recursive: true, force: true }); }),
  );

  yield* Effect.try({ try: () => { for (const [name, text] of files) { writeFileSync(join(staging, `${name}.json`), text); } }, catch: ioError(`write ${staging}`) });

  const violations = privacyViolations(files);

  yield* violations.length === 0 ? Effect.void : ScriptError.make({ message: `not written, the files fail the privacy check:\n${violations.join("\n")}`, exitCode: 1 });

  yield* Effect.try({ try: () => { rmSync(target, { recursive: true, force: true }); renameSync(staging, target); }, catch: ioError(`replace ${target}`) });

  for (const [name, text] of files) { yield* Console.log(`${`${name}.json`.padEnd(18)} ${String(Buffer.byteLength(text)).padStart(9)} B  ${String(Bun.gzipSync(text).length).padStart(8)} B gzipped`); }

  yield* Console.log(`wrote ${files.size} files to ${target}`);
}).pipe(Effect.scoped);

await runMain(program);
