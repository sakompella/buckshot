import { beforeAll, expect, test } from "bun:test";
import { createHash } from "node:crypto";
import { appendFileSync, mkdtempSync, readFileSync } from "node:fs";
import { tmpdir } from "node:os";
import { join } from "node:path";

import { Option, Result, Schema } from "effect";

import { RunManifest } from "../src/arena/match.ts";
import { entriesSentTo } from "../src/arena/runlog.ts";
import { decodeEventLine, movesOf, readJsonl } from "../src/viewer/runs.ts";
import { replayOf } from "../src/viewer/replay.ts";

// Ends test/crash-run.ts's faux match at each journal commit and log export,
// resumes it, and checks the run against one never stopped: the same moves,
// every move and delivery exported once, and a viewer replay that matches.

const CRASH_EXIT = 86;

const WEB = join(import.meta.dir, "..");

/** Each crash point, with the occurrence to crash at. */
const POINTS = [
  ["move:before-commit", 3],
  ["move:after-commit", 3],
  ["move:after-export", 3],
  ["forced:before-commit", 2],
  ["forced:after-commit", 2],
  ["delivery:after-submit", 3],
  ["delivery:after-commit", 3],
  ["reminder:after-submit", 1],
  ["fallback:after-commit", 1],
  ["delivery:after-commit", 25],
] as const;

const play = async (dir: string, point: string, occurrence: number): Promise<number> => Bun.spawn(["bun", "test/crash-run.ts", dir, point, String(occurrence)], { cwd: WEB, stdout: "ignore", stderr: "inherit" }).exited;

const readManifest = (dir: string) => Schema.decodeUnknownSync(Schema.fromJsonString(RunManifest))(readFileSync(join(dir, "manifest.json"), "utf8"));

const ManifestSha = Schema.Struct({ move_log_sha: Schema.String });

const moveLogSha = (dir: string) => Schema.decodeUnknownSync(Schema.fromJsonString(ManifestSha))(readFileSync(join(dir, "manifest.json"), "utf8")).move_log_sha;

const eventsOf = (dir: string) => readJsonl(readFileSync(join(dir, "events.jsonl"), "utf8"), decodeEventLine);

/** The exported moves, as the journal holds them, hashed the way the manifest's move_log_sha is. */
const exportedSha = (dir: string) =>
  createHash("sha256")
    .update(JSON.stringify(movesOf(eventsOf(dir)).map(({ turn, player, move, label, by }) => ({ turn, player, move, label, by }))))
    .digest("hex")
    .slice(0, 12);

const seqsOf = (dir: string, kinds: ReadonlyArray<string>) => eventsOf(dir).flatMap((line) => (line.kind === "read" && kinds.includes(line.value.kind) && "seq" in line.value ? [line.value.seq] : []));

const root = mkdtempSync(join(tmpdir(), "arena-crash-"));

const baseline = join(root, "baseline");

const runs = new Map<string, { crashed: number; resumed: number }>();

const CASES = [...POINTS.map(([point, occurrence]) => ({ name: `${point}#${occurrence}`, point, occurrence })), { name: "half-written lines", point: "move:after-export", occurrence: 5 }];

beforeAll(async () => {
  expect(await play(baseline, "none", 0)).toBe(0);

  // Two at a time: the machine is small.
  for (let at = 0; at < CASES.length; at += 2) {
    await Promise.all(
      CASES.slice(at, at + 2).map(async ({ name, point, occurrence }) => {
        const dir = join(root, name);
        const crashed = await play(dir, point, occurrence);

        if (name === "half-written lines") for (const file of ["events.jsonl", "calls.jsonl"]) appendFileSync(join(dir, file), '{"t":"2026-');

        runs.set(name, { crashed, resumed: await play(dir, "none", 0) });
      }),
    );
  }
}, 120_000);

test.each(CASES.map(({ name }) => name))("a crash at %s resumes to the match a run with no crash plays, exported once", (name) => {
  const dir = join(root, name);

  expect(runs.get(name)).toEqual({ crashed: CRASH_EXIT, resumed: 0 });

  const manifest = readManifest(dir);

  expect(manifest.status).toBe("finished");
  expect(manifest.provenance).toBeDefined();
  expect(moveLogSha(dir)).toBe(moveLogSha(baseline));
  expect(exportedSha(dir)).toBe(moveLogSha(dir));

  const moveSeqs = seqsOf(dir, ["move", "fallback"]);
  const deliverySeqs = seqsOf(dir, ["delivered"]);

  expect(moveSeqs).toEqual(moveSeqs.map((_, index) => index));
  expect(deliverySeqs).toEqual(deliverySeqs.map((_, index) => index));
  expect(entriesSentTo(dir, "A")).toEqual(entriesSentTo(baseline, "A"));

  const replay = Result.getOrThrow(replayOf(Option.none(), manifest, movesOf(eventsOf(dir))));

  expect(Option.getOrUndefined(replay.divergence)).toBeUndefined();
  expect(replay.applied.length).toBe(moveSeqs.length);
  expect(replay.frames.at(-1)?.entries.map((entry) => entry.text)).toContain("The match is over.");
});
