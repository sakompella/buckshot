import { readFileSync } from "node:fs";

import { Schema } from "effect";

/** A struct that names the fields a test reads and keeps every other field, so a file read, changed and written back stays whole. */
export const loose = <const Fields extends Schema.Struct.Fields>(fields: Fields) => Schema.StructWithRest(Schema.Struct(fields), [Schema.Record(Schema.String, Schema.Json)]);

/** A JSON file decoded with `schema`. */
export const readJson = <const S extends Schema.Top & { readonly DecodingServices: never }>(schema: S) => {
  const decode = Schema.decodeUnknownSync(Schema.fromJsonString(schema));

  return (path: string): S["Type"] => decode(readFileSync(path, "utf8"));
};

export const Agents = Schema.Record(Schema.String, Schema.Record(Schema.String, Schema.Json));

/** The fields of a match's manifest.json that tests change. */
export const Manifest = loose({ provenance: loose({ agents: Agents }) });

export const readManifest = readJson(Manifest);
