import { existsSync, readdirSync, readFileSync, statSync } from "node:fs";
import { basename, join, resolve } from "node:path";

import { Option, Result, Schema } from "effect";

import { DELIVERIES } from "../arena/match.ts";
import { CallLine } from "../arena/runlog.ts";
import { Controller } from "../driver.ts";
import { Letter } from "../players.ts";
import { EventLine, type JsonlLine, type MoveLine, type RunStatus, type RunSummary, type Unreadable } from "./api.ts";

// Reads arena run directories (src/arena/runlog.ts describes the layout) for
// the viewer. Nothing here writes. A match may still be playing, so a JSONL
// file can end in a line its writer has not finished.

/** The fields of manifest.json, format 1, that the viewer reads. */
const RunManifest = Schema.Struct({
  format: Schema.Literal(1),
  status: Schema.Literals(["running", "finished"]),
  seed: Schema.String,
  /** By position, in table order. */
  controllers: Schema.Array(Controller),
  letters: Schema.Array(Letter),
  delivery: Schema.Literals(DELIVERIES),
  standings: Schema.optional(Schema.Array(Schema.Struct({ player: Letter, cash: Schema.Number, controller: Schema.NullOr(Controller) }))),
});

export type RunManifest = typeof RunManifest.Type;

const Versioned = Schema.Struct({ format: Schema.optional(Schema.Json) });

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

    if (format !== 1) return Result.fail(`format ${JSON.stringify(format)}: this viewer reads format 1`);

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

    const first = calls.find((call) => call.agent === player);

    return [first === undefined ? { agent: player } : { agent: player, model: first.model, api: first.api }];
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
