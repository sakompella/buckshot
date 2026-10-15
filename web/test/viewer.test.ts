import { beforeAll, expect, test } from "bun:test";
import { appendFileSync, cpSync, mkdirSync, mkdtempSync, readFileSync, writeFileSync } from "node:fs";
import { tmpdir } from "node:os";
import { join } from "node:path";

import { Option, Result, Schema } from "effect";

import type { JsonlLine } from "../src/viewer/api.ts";
import { replayOf } from "../src/viewer/replay.ts";
import { decodeCallLine, decodeEventLine, movesOf, readJsonl, readRun } from "../src/viewer/runs.ts";
import { playFauxRun } from "./faux-run.ts";

const tempDir = (prefix: string) => mkdtempSync(join(tmpdir(), prefix));

const Numbered = Schema.Struct({ n: Schema.Int });

const decodeNumbered = (line: string) => Result.mapError(Schema.decodeUnknownResult(Schema.fromJsonString(Numbered))(line), (error) => error.message);

const runs = tempDir("viewer-runs-");

const dir = join(runs, "faux");

beforeAll(() => playFauxRun(dir, ["Agent", "Agent", "DoN"], "live"));

test("a line cut mid-JSON is left out until it is complete, and a malformed complete line is unreadable in place", () => {
  const cut = '{"n":1}\n{"n":2}\n{"n":';

  expect(readJsonl(cut, decodeNumbered).map((line) => line.kind === "read" && line.value.n)).toEqual([1, 2]);
  expect(readJsonl(`${cut}3}\n`, decodeNumbered).map((line) => line.kind === "read" && line.value.n)).toEqual([1, 2, 3]);

  const malformed = readJsonl('{"n":1}\n{"n":"two"}\n{"n":3}\n', decodeNumbered);

  expect(malformed.map((line) => line.kind)).toEqual(["read", "unreadable", "read"]);
  expect(malformed[1]).toMatchObject({ kind: "unreadable", line: 2 });
});

/** A seeded linear congruential generator, so a failing cut sequence repeats. */
const randomFrom = (seed: number) => {
  let state = seed;

  return () => {
    state = (state * 1_103_515_245 + 12_345) % 2 ** 31;

    return state / 2 ** 31;
  };
};

/** Writes `file` from the faux run into a new file in chunks cut at seeded random byte offsets, reading it with a cursor after each. */
const tailInChunks = <A>(file: string, decode: (line: string) => Result.Result<A, string>) => {
  const bytes = readFileSync(join(dir, file));
  const path = join(tempDir("viewer-tail-"), file);
  const random = randomFrom(7);
  const cuts = Array.from({ length: 50 }, () => Math.floor(random() * bytes.length)).toSorted((left, right) => left - right);
  const seen: Array<JsonlLine<A>> = [];

  writeFileSync(path, "");

  for (const [from, to] of [0, ...cuts].map((cut, index) => [cut, cuts[index] ?? bytes.length])) {
    appendFileSync(path, bytes.subarray(from, to));
    seen.push(...readJsonl(readFileSync(path, "utf8"), decode).slice(seen.length));
  }

  expect(seen).toEqual([...readJsonl(bytes.toString("utf8"), decode)]);
  expect(seen.every((line) => line.kind === "read")).toBe(true);
};

test("reading events.jsonl with a cursor while it is written in random chunks gives every line once, in order", () => tailInChunks("events.jsonl", decodeEventLine));

test("reading calls.jsonl with a cursor while it is written in random chunks gives every line once, in order", () => tailInChunks("calls.jsonl", decodeCallLine));

test("a faux match replays move for move to its final cash, extends a partial replay, and a format-0 run is unreadable", () => {
  const run = Result.getOrThrow(Option.getOrThrow(readRun(runs, "faux", new Date())));
  const moves = movesOf(run.events);
  const replay = Result.getOrThrow(replayOf(Option.none(), run.manifest, moves));
  const last = replay.frames.at(-1);

  expect(Option.getOrUndefined(replay.divergence)).toBeUndefined();
  expect(replay.frames.slice(1).map((frame) => frame.move?.label)).toEqual(moves.map((line) => line.label));
  expect(last?.players.map(({ player, cash }) => ({ player, cash })).toSorted((left, right) => right.cash - left.cash)).toEqual((run.manifest.standings ?? []).map(({ player, cash }) => ({ player, cash })));
  expect(replay.frames.some((frame) => frame.entries.some((entry) => entry.heardBy !== undefined))).toBe(true);

  const partial = Result.getOrThrow(replayOf(Option.none(), run.manifest, moves.slice(0, 40)));

  expect(Result.getOrThrow(replayOf(Option.some(partial), run.manifest, moves)).frames).toEqual(replay.frames);

  mkdirSync(join(runs, "older"));
  cpSync(join(dir, "events.jsonl"), join(runs, "older", "events.jsonl"));
  writeFileSync(join(runs, "older", "manifest.json"), JSON.stringify({ status: "finished", seed: "42", controllers: ["Agent", "Agent"] }));

  expect(Option.getOrThrow(readRun(runs, "older", new Date()))).toEqual(Result.fail({ kind: "unreadable", id: "older", reason: "format 0 (before agent letters): not readable by this viewer" }));
});
