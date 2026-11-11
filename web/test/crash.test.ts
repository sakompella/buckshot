import { Database } from "bun:sqlite";
import { beforeAll, expect, test } from "bun:test";
import { createHash } from "node:crypto";
import { appendFileSync, mkdtempSync, readFileSync, writeFileSync } from "node:fs";
import { tmpdir } from "node:os";
import { join } from "node:path";

import { Option, Result, Schema } from "effect";

import { RunManifest } from "../src/arena/match.ts";
import { entriesSentTo } from "../src/arena/runlog.ts";
import { decodeEventLine, movesOf, readJsonl } from "../src/arena/jsonl.ts";
import { replayOf } from "../src/arena/replay.ts";

// Ends test/crash-run.ts's faux match at each journal commit and log export,
// resumes it, and checks the run against one never stopped: the same moves,
// every move and delivery exported once, and a viewer replay that matches.

const CRASH_EXIT = 86;

const WEB = join(import.meta.dir, "..");

/** Each crash point, with the occurrence to crash at: a number, or the last time the match reaches it. */
const POINTS = [
  ["start:before-commit", 1],
  ["start:after-commit", 1],
  ["start:after-export", 1],
  ["delivery:before-commit", 3],
  ["delivery:after-export", 3],
  ["forced:after-export", 2],
  ["fallback:before-commit", 1],
  ["fallback:after-export", 1],
  ["move:before-commit", 3],
  ["move:after-commit", 3],
  ["move:after-export", 3],
  ["forced:before-commit", 2],
  ["forced:after-commit", 2],
  ["delivery:after-submit", 3],
  ["delivery:after-commit", 3],
  ["reminder:after-submit", 1],
  ["fallback:after-commit", 1],
  ["delivery:before-commit", "last"],
  ["delivery:after-commit", "last"],
  ["delivery:after-export", "last"],
] as const;

const play = async (dir: string, point: string, occurrence: number, signal = "exit"): Promise<number> => Bun.spawn(["nice", "-n", "10", "bun", "test/crash-run.ts", dir, point, String(occurrence), signal], { cwd: WEB, env: { ...process.env, CRASH_TEST_EFFORT: undefined }, stdout: "ignore", stderr: "pipe" }).exited;

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

  const lastDelivery = seqsOf(baseline, ["delivered"]).length;

  // Two at a time: the machine is small.
  for (let at = 0; at < CASES.length; at += 2) {
    await Promise.all(
      CASES.slice(at, at + 2).map(async ({ name, point, occurrence }) => {
        const dir = join(root, name);
        const crashed = await play(dir, point, occurrence === "last" ? lastDelivery : occurrence);

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
  expect(deliverySeqs).toEqual(seqsOf(baseline, ["delivered"]));
  expect(entriesSentTo(dir, "A")).toEqual(entriesSentTo(baseline, "A"));

  const replay = Result.getOrThrow(replayOf(Option.none(), manifest, movesOf(eventsOf(dir))));

  expect(Option.getOrUndefined(replay.divergence)).toBeUndefined();
  expect(replay.applied.length).toBe(moveSeqs.length);
  expect(replay.frames.at(-1)?.entries.map((entry) => entry.text)).toContain("The match is over.");
});

test.each(["SIGTERM", "SIGKILL", "model:in-flight"])("a %s stop resumes without repeating work", async (signal) => {
  const dir = join(root, signal);

  expect(await play(dir, signal === "model:in-flight" ? signal : "move:after-commit", 3, signal)).not.toBe(0);
  expect(await play(dir, "none", 0)).toBe(0);
  expect(moveLogSha(dir)).toBe(moveLogSha(baseline));
  expect(exportedSha(dir)).toBe(moveLogSha(dir));
  expect(entriesSentTo(dir, "A")).toEqual(entriesSentTo(baseline, "A"));
  const seqs = seqsOf(dir, ["move", "fallback"]);

  expect(seqs).toEqual(seqs.map((_, index) => index));
});

test("resuming a finished match makes no model calls, moves or deliveries", async () => {
  const before = readManifest(baseline);
  const calls = readFileSync(join(baseline, "calls.jsonl"), "utf8");
  const moves = movesOf(eventsOf(baseline));
  const deliveries = seqsOf(baseline, ["delivered"]);

  expect(await play(baseline, "none", 0)).toBe(0);
  expect(readManifest(baseline)).toEqual(before);
  expect(readFileSync(join(baseline, "calls.jsonl"), "utf8")).toBe(calls);
  expect(movesOf(eventsOf(baseline))).toEqual(moves);
  expect(seqsOf(baseline, ["delivered"])).toEqual(deliveries);
});

test("a changed agent provenance is refused before more calls or moves", async () => {
  const dir = join(root, "provenance");

  expect(await play(dir, "move:after-export", 3)).toBe(CRASH_EXIT);
  const calls = readFileSync(join(dir, "calls.jsonl"), "utf8");
  const moves = movesOf(eventsOf(dir));

  const refused = Bun.spawn(["nice", "-n", "10", "bun", "test/crash-run.ts", dir], {
    cwd: WEB, env: { ...process.env, CRASH_TEST_EFFORT: "medium" }, stdout: "ignore", stderr: "pipe",
  });

  expect(await refused.exited).not.toBe(0);
  const error = await new Response(refused.stderr).text();

  expect(error).toContain("cannot resume");
  expect(readFileSync(join(dir, "calls.jsonl"), "utf8")).toBe(calls);
  expect(movesOf(eventsOf(dir))).toEqual(moves);
  expect(await play(dir, "none", 0)).toBe(0);
  expect(moveLogSha(dir)).toBe(moveLogSha(baseline));
});

test("a journal started under another commit refuses to resume and names both versions", async () => {
  const dir = join(root, "old-code");

  expect(await play(dir, "move:after-export", 3)).toBe(CRASH_EXIT);
  const code = Schema.decodeUnknownSync(Schema.Struct({ provenance: Schema.Struct({ git_commit: Schema.String }) }))(readManifest(dir)).provenance.git_commit;
  const old = "0".repeat(40);
  const db = new Database(join(dir, "session.sqlite"));

  try {
    expect(db.query("UPDATE document_revisions SET content = replace(content, ?, ?) WHERE content LIKE ?").run(code, old, `%${code}%`).changes).toBeGreaterThan(0);
  } finally {
    db.close();
  }

  const refused = Bun.spawn(["nice", "-n", "10", "bun", "test/crash-run.ts", dir], { cwd: WEB, stdout: "ignore", stderr: "pipe" });

  expect(await refused.exited).not.toBe(0);
  const error = await new Response(refused.stderr).text();

  expect(error).toContain(`git_commit was ${old}, now ${code}`);
});

test("a truncated manifest is rebuilt from the journal after a stop", async () => {
  const dir = join(root, "manifest-write");

  expect(await play(dir, "move:after-export", 3)).toBe(CRASH_EXIT);
  writeFileSync(join(dir, "manifest.json"), '{"status":"run');
  expect(await play(dir, "none", 0)).toBe(0);
  expect(readManifest(dir).status).toBe("finished");
  expect(moveLogSha(dir)).toBe(moveLogSha(baseline));
  expect(exportedSha(dir)).toBe(moveLogSha(dir));
});

test("a provider fault resumes the interrupted turn without losing or duplicating a delivery", async () => {
  const dir = join(root, "provider-fault");

  expect(await play(dir, "model:fault", 0)).not.toBe(0);
  expect(readFileSync(join(dir, "events.jsonl"), "utf8")).toContain("503 faux provider unavailable");
  expect(await play(dir, "none", 0)).toBe(0);
  expect(moveLogSha(dir)).toBe(moveLogSha(baseline));
  expect(exportedSha(dir)).toBe(moveLogSha(dir));
  expect(entriesSentTo(dir, "A")).toEqual(entriesSentTo(baseline, "A"));
});
