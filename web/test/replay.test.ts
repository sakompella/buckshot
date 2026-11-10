import * as hegel from "@hegeldev/hegel";
import * as gs from "@hegeldev/hegel/generators";
import { beforeAll, expect, test } from "bun:test";
import { mkdtempSync, readFileSync } from "node:fs";
import { tmpdir } from "node:os";
import { join } from "node:path";

import { Option, Result, Schema } from "effect";

import { decodeEventLine, type JsonlLine, movesOf, readJsonl } from "../src/arena/jsonl.ts";
import { RunManifest } from "../src/arena/match.ts";
import { replayOf } from "../src/arena/replay.ts";
import { playFauxRun } from "./faux-run.ts";

const tempDir = (prefix: string) => mkdtempSync(join(tmpdir(), prefix));

const Numbered = Schema.Struct({ n: Schema.Int });

const decodeNumbered = (line: string) => Result.mapError(Schema.decodeUnknownResult(Schema.fromJsonString(Numbered))(line), (error) => error.message);

const dir = join(tempDir("replay-run-"), "faux");

beforeAll(() => playFauxRun(dir, ["Agent", "Agent", "DoN"], "live"));

test("a line cut mid-JSON is left out until it is complete, and a malformed complete line is unreadable in place", () => {
  const cut = '{"n":1}\n{"n":2}\n{"n":';

  expect(readJsonl(cut, decodeNumbered).map((line) => line.kind === "read" && line.value.n)).toEqual([1, 2]);
  expect(readJsonl(`${cut}3}\n`, decodeNumbered).map((line) => line.kind === "read" && line.value.n)).toEqual([1, 2, 3]);

  const malformed = readJsonl('{"n":1}\n{"n":"two"}\n{"n":3}\n', decodeNumbered);

  expect(malformed.map((line) => line.kind)).toEqual(["read", "unreadable", "read"]);
  expect(malformed[1]).toMatchObject({ kind: "unreadable", line: 2 });
});

/** Reads `file` from the faux run with a cursor after each of a series of prefixes cut at arbitrary byte offsets, as a tailing reader sees a file being written. */
const tailInChunks = <A>(file: string, decode: (line: string) => Result.Result<A, string>) =>
  hegel.test((tc) => {
    const bytes = readFileSync(join(dir, file));
    const cuts = tc.draw(gs.arrays(gs.integers({ minValue: 0, maxValue: bytes.length }), { maxSize: 50 })).toSorted((left, right) => left - right);
    const seen: Array<JsonlLine<A>> = [];

    for (const cut of [...cuts, bytes.length]) seen.push(...readJsonl(bytes.subarray(0, cut).toString("utf8"), decode).slice(seen.length));

    expect(seen).toEqual([...readJsonl(bytes.toString("utf8"), decode)]);
    expect(seen.every((line) => line.kind === "read")).toBe(true);
  });

test("reading events.jsonl with a cursor while it is written in chunks gives every line once, in order", () => tailInChunks("events.jsonl", decodeEventLine));

test("a faux match replays move for move to its final cash, extends a partial replay", () => {
  const manifest = Schema.decodeUnknownSync(Schema.fromJsonString(RunManifest))(readFileSync(join(dir, "manifest.json"), "utf8"));
  const moves = movesOf(readJsonl(readFileSync(join(dir, "events.jsonl"), "utf8"), decodeEventLine));
  const replay = Result.getOrThrow(replayOf(Option.none(), manifest, moves));
  const last = replay.frames.at(-1);

  expect(Option.getOrUndefined(replay.divergence)).toBeUndefined();
  expect(replay.frames.slice(1).map((frame) => frame.move?.label)).toEqual(moves.map((line) => line.label));
  expect(last?.players.map(({ player, cash }) => ({ player, cash })).toSorted((left, right) => right.cash - left.cash)).toEqual((manifest.standings ?? []).map(({ player, cash }) => ({ player, cash })));
  expect(replay.frames.some((frame) => frame.entries.some((entry) => entry.heardBy !== undefined))).toBe(true);

  const partial = Result.getOrThrow(replayOf(Option.none(), manifest, moves.slice(0, 40)));

  expect(Result.getOrThrow(replayOf(Option.some(partial), manifest, moves)).frames).toEqual(replay.frames);
});
