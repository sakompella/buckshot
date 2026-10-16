import { existsSync, readdirSync, readFileSync, statSync } from "node:fs";
import { basename, join, resolve } from "node:path";

import { Option, Result, Schema } from "effect";

import { RunManifest } from "../arena/match.ts";
import { CallLine, EventLine, type MoveLine, RUN_FORMAT } from "../arena/runlog.ts";
import type { JsonlLine, RunStatus, RunSummary, Unreadable } from "./api.ts";

// Reads arena run directories (src/arena/runlog.ts describes the layout) for
// the viewer. Nothing here writes. A match may still be playing, so a JSONL
// file can end in a line its writer has not finished.

const Versioned = Schema.Struct({ format: Schema.optional(Schema.Json) });

const Endpoint = Schema.Struct({ model: Schema.String, api: Schema.String, effort: Schema.optional(Schema.NullOr(Schema.String)) });

const decodeEntry = Schema.decodeUnknownOption(Schema.Union([Endpoint, Schema.Struct({ endpoint: Endpoint })]));

/** An agent's model, api and effort from its manifest entry: the endpoint itself, or under `endpoint`. */
const endpointOf = (entry: Schema.Json | undefined): Option.Option<typeof Endpoint.Type> => Option.map(decodeEntry(entry), (decoded) => ("endpoint" in decoded ? decoded.endpoint : decoded));

/** A run is live while one of its files changed this recently: a turn can wait minutes on a slow model and its retries. */
const LIVE_WITHIN_MS = 5 * 60_000;

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

export const decodeCallLine = lineDecoder(CallLine);

const textOf = (path: string): string => (existsSync(path) ? readFileSync(path, "utf8") : "");

const manifestOf = (dir: string): Result.Result<RunManifest, string> => {
  const path = join(dir, "manifest.json");

  if (!existsSync(path)) return Result.fail("no manifest.json");

  const text = readFileSync(path, "utf8");

  return Result.flatMap(Result.mapError(lineDecoder(Versioned)(text), (issue) => `manifest.json: ${issue}`), ({ format }) => {
    if (format === undefined) return Result.fail("format 0 (before agent letters): not readable by this viewer");

    if (format !== RUN_FORMAT) return Result.fail(`format ${JSON.stringify(format)}: this viewer reads format ${RUN_FORMAT}`);

    return Result.mapError(lineDecoder(RunManifest)(text), (issue) => `manifest.json: ${issue}`);
  });
};

/** Everything the viewer reads from one run directory, at one moment. */
export interface RunRead {
  readonly id: string;
  readonly manifest: RunManifest;
  readonly events: ReadonlyArray<JsonlLine<EventLine>>;
  readonly calls: ReadonlyArray<JsonlLine<CallLine>>;
  readonly summary: RunSummary;
}

const readValues = <A>(lines: ReadonlyArray<JsonlLine<A>>): ReadonlyArray<A> => lines.flatMap((line) => (line.kind === "read" ? [line.value] : []));

export const movesOf = (events: ReadonlyArray<JsonlLine<EventLine>>): ReadonlyArray<MoveLine> => readValues(events).filter((event): event is MoveLine => event.kind === "move" || event.kind === "fallback");

const statusOf = (manifest: RunManifest, events: ReadonlyArray<EventLine>, lastWrite: Date, now: Date): RunStatus => {
  if (manifest.status === "finished") return "finished";

  if (events.findLastIndex((event) => event.kind === "fault") > events.findLastIndex((event) => event.kind === "resumed")) return "fault";

  return now.getTime() - lastWrite.getTime() <= LIVE_WITHIN_MS ? "live" : "stopped";
};

const summaryOf = (id: string, dir: string, manifest: RunManifest, eventLines: ReadonlyArray<JsonlLine<EventLine>>, callLines: ReadonlyArray<JsonlLine<CallLine>>, now: Date): RunSummary => {
  const events = readValues(eventLines);
  const calls = readValues(callLines);
  const writes = ["events.jsonl", "calls.jsonl", "manifest.json"].flatMap((file) => (existsSync(join(dir, file)) ? [statSync(join(dir, file)).mtimeMs] : []));
  const lastWrite = new Date(Math.max(statSync(dir).mtimeMs, ...writes));
  const seating = manifest.controllers.flatMap((controller, index) => Option.toArray(Option.map(Option.fromUndefinedOr(manifest.letters[index]), (player) => ({ player, controller }))));

  const agents = seating.flatMap(({ player, controller }) => {
    if (controller !== "Agent") return [];

    // manifest.agents is the endpoint while running and {endpoint, ...} once finished, a bare string in faux runs; the first call fills in until it has one shape.
    const described = Option.orElse(endpointOf(manifest.agents?.[player]), () => Option.map(Option.fromUndefinedOr(calls.find((call) => call.agent === player)), ({ model, api }) => ({ model, api, effort: undefined })));

    return [Option.match(described, { onNone: () => ({ agent: player }), onSome: ({ model, api, effort }) => ({ agent: player, model, api, effort: effort ?? undefined }) })];
  });

  const summary: RunSummary = {
    kind: "readable",
    id,
    started: events[0]?.t ?? statSync(dir).mtime.toISOString(),
    lastWrite: lastWrite.toISOString(),
    status: statusOf(manifest, events, lastWrite, now),
    seed: manifest.seed,
    delivery: manifest.delivery,
    seating,
    agents,
  };

  return manifest.standings === undefined ? summary : { ...summary, standings: manifest.standings };
};

/** The run directory `id` names inside `runsDir`; none for a name that leaves it or is not a directory. */
const runDir = (runsDir: string, id: string): Option.Option<string> => {
  const dir = resolve(runsDir, id);

  return basename(dir) === id && resolve(dir, "..") === resolve(runsDir) && existsSync(dir) && statSync(dir).isDirectory() ? Option.some(dir) : Option.none();
};

export const readRun = (runsDir: string, id: string, now: Date): Option.Option<Result.Result<RunRead, Unreadable>> =>
  Option.map(runDir(runsDir, id), (dir) =>
    Result.mapBoth(manifestOf(dir), {
      onFailure: (reason): Unreadable => ({ kind: "unreadable", id, reason }),
      onSuccess: (manifest) => {
        const events = readJsonl(textOf(join(dir, "events.jsonl")), decodeEventLine);
        const calls = readJsonl(textOf(join(dir, "calls.jsonl")), decodeCallLine);

        return { id, manifest, events, calls, summary: summaryOf(id, dir, manifest, events, calls, now) };
      },
    }),
  );

/** Every run directory in `runsDir`, readable or not. */
export const readRuns = (runsDir: string, now: Date): ReadonlyArray<Result.Result<RunRead, Unreadable>> =>
  readdirSync(runsDir, { withFileTypes: true }).flatMap((entry) => (entry.isDirectory() ? Option.toArray(readRun(runsDir, entry.name, now)) : []));

export const callsOf = (run: RunRead): ReadonlyArray<CallLine> => readValues(run.calls);
