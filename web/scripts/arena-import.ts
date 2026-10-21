import { readFileSync } from "node:fs";
import { parseArgs } from "node:util";

import { Schema } from "effect";

import { importTournaments } from "../src/analysis/import.ts";

const { values, positionals } = parseArgs({ args: process.argv.slice(2), allowPositionals: true, options: { db: { type: "string" }, skips: { type: "string" } } });

if (values.db === undefined || positionals.length === 0) {
  console.error("Usage: bun scripts/arena-import.ts --db <database> [--skips <json>] <tournament-dir>...");
  process.exit(1);
}

const skipped = values.skips === undefined ? {} : Schema.decodeUnknownSync(Schema.fromJsonString(Schema.Record(Schema.String, Schema.Array(Schema.String))))(readFileSync(values.skips, "utf8"));

importTournaments({ database: values.db, sources: positionals, skipped });
