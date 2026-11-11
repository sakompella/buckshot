import { Result, Schema } from "effect";

import { AGGREGATE_NAMES, AGGREGATES, type AggregateName, Summary } from "./aggregates.ts";
import { ITEMS, OpportunityType } from "./api.ts";

// The last gate before the aggregate files leave this machine: they must hold per-config and per-pair numbers only,
// never a match, seed, move or account. Each file decodes strictly, no key names a per-match field, and every string
// is a model, effort, config, item or label from the files themselves, with nothing that looks like an id or an email.

export const Manifest = Schema.Struct({
  generated: Schema.String.check(Schema.isPattern(/^\d{4}-\d{2}-\d{2}$/)),
  files: Schema.Array(Schema.Struct({ name: Schema.Literals(AGGREGATE_NAMES), bytes: Schema.Number })),
});

export type Manifest = typeof Manifest.Type;

type FileName = AggregateName | "manifest";

export const FILE_NAMES: ReadonlyArray<FileName> = [...AGGREGATE_NAMES, "manifest"];

const FORBIDDEN_KEYS = new Set(
  ["matchId", "match_id", "seed", "seedBlock", "seed_block", "decision", "decisions", "ordinal", "provenance", "provenance_json", "response", "reasoning", "text", "player", "email", "account", "accountId", "startedAt", "endedAt", "timestamp"].map((key) => key.toLowerCase()),
);

const SUSPECT: ReadonlyArray<readonly [RegExp, string]> = [
  [/[^\s@]+@[^\s@]+\.[^\s@]+/, "looks like an email"],
  [/[0-9a-f]{12,}/i, "has a run of 12 or more hex digits"],
  [/^.{81,}$/s, "is longer than 80 characters"],
];

const STRICT = { onExcessProperty: "error" } as const;

const schemaOf = (name: FileName): Schema.Codec<unknown, unknown> => (name === "manifest" ? Manifest : AGGREGATES[name]);

/** A JSON string token, and the colon after it when it is a key. */
const STRING_TOKEN = /("(?:[^"\\]|\\.)*")(\s*:)?/g;

const decodeString = Schema.decodeUnknownSync(Schema.fromJsonString(Schema.String));

/** Every string in a JSON text, keys included, unescaped. */
const stringsOf = (json: string): ReadonlyArray<{ readonly text: string; readonly isKey: boolean }> =>
  [...json.matchAll(STRING_TOKEN)].map(([, token = '""', colon]) => ({ text: decodeString(token), isKey: colon !== undefined }));

const decodeSummary = Schema.decodeUnknownResult(Schema.fromJsonString(Summary));

const decodeManifest = Schema.decodeUnknownResult(Schema.fromJsonString(Manifest));

/** The strings the files may hold: the configs the summary lists, the items, the certain-mistake scopes and types, the empty model and effort of a pooled scope, and the manifest's own. */
const allowedStrings = (files: ReadonlyMap<string, string>): ReadonlySet<string> => {
  const { configs, runs } = Result.getOrElse(decodeSummary(files.get("summary") ?? ""), () => ({ configs: [], runs: undefined }));
  const { generated } = Result.getOrElse(decodeManifest(files.get("manifest") ?? ""), () => ({ generated: "" }));

  return new Set(["", ...configs.flatMap(({ model, effort }) => [model, effort, `${model}|${effort}`]), ...ITEMS, "config", "model", "all", ...OpportunityType.literals, generated, ...(runs === undefined ? [] : [runs.from, runs.to]), ...AGGREGATE_NAMES]);
};

const fileViolations = (name: FileName, json: string, allowed: ReadonlySet<string>): ReadonlyArray<string> => {
  const decoded = Schema.decodeUnknownResult(Schema.fromJsonString(schemaOf(name)))(json, STRICT);
  const undecodable = Result.isFailure(decoded) ? [`${name}: ${decoded.failure.message}`] : [];

  const strings = stringsOf(json).flatMap(({ text, isKey }) => {
    const quoted = JSON.stringify(text.slice(0, 40));
    const named = isKey && FORBIDDEN_KEYS.has(text.toLowerCase()) ? [`${name}: forbidden key ${quoted}`] : [];
    const unexpected = !isKey && !allowed.has(text) ? [`${name}: unexpected string ${quoted}`] : [];

    return [...named, ...unexpected, ...SUSPECT.flatMap(([pattern, why]) => (pattern.test(text) ? [`${name}: ${quoted} ${why}`] : []))];
  });

  return [...undecodable, ...strings];
};

/** What is wrong with a set of export files, by file name; empty when they may be published. */
export const privacyViolations = (files: ReadonlyMap<string, string>): ReadonlyArray<string> => {
  const allowed = allowedStrings(files);
  const unknown = [...files.keys()].flatMap((name) => (FILE_NAMES.some((known) => known === name) ? [] : [`${name}: not an export file`]));

  return [...unknown, ...FILE_NAMES.flatMap((name) => {
    const json = files.get(name);

    return json === undefined ? [`${name}: missing`] : fileViolations(name, json, allowed);
  })];
};
