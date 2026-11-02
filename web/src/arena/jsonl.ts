import { Result, Schema } from "effect";

import { EventLine, type MoveLine } from "./runlog.ts";

// Reads the JSONL files of arena run directories (runlog.ts describes the
// layout). A match may still be playing, so a file can end in a line its writer
// has not finished.

/** One complete line of a JSONL file: decoded, or why not. `line` counts from 1. */
export type JsonlLine<A> = { readonly kind: "read"; readonly line: number; readonly value: A } | { readonly kind: "unreadable"; readonly line: number; readonly reason: string };

const firstIssue = (error: Schema.SchemaError): string => error.message.replaceAll(/\s*\n\s*/g, " ");

/** Decodes one JSON line with a schema, or gives its first issue. */
export const lineDecoder = <A>(schema: Schema.Codec<A, unknown>) => {
  const decode = Schema.decodeUnknownResult(Schema.fromJsonString(schema));

  return (line: string): Result.Result<A, string> => Result.mapError(decode(line), firstIssue);
};

/** The complete lines of a JSONL file's text, each decoded or not. Text after the last newline is a line still being written, and is left out. */
export const readJsonl = <A>(text: string, decode: (line: string) => Result.Result<A, string>): ReadonlyArray<JsonlLine<A>> =>
  text
    .split("\n")
    .slice(0, -1)
    .map((raw, index) =>
      Result.match(decode(raw), {
        onSuccess: (value): JsonlLine<A> => ({ kind: "read", line: index + 1, value }),
        onFailure: (reason): JsonlLine<A> => ({ kind: "unreadable", line: index + 1, reason }),
      }),
    );

export const decodeEventLine = lineDecoder(EventLine);

export const movesOf = (events: ReadonlyArray<JsonlLine<EventLine>>): ReadonlyArray<MoveLine> =>
  events.flatMap((line) => (line.kind === "read" && (line.value.kind === "move" || line.value.kind === "fallback") ? [line.value] : []));
