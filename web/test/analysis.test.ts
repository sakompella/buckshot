import { expect, test } from "bun:test";
import { appendFileSync, mkdtempSync, mkdirSync, readFileSync, rmSync, writeFileSync } from "node:fs";
import { tmpdir } from "node:os";
import { join } from "node:path";

import { importTournaments, openAnalysis } from "../src/analysis/import.ts";
import { playFauxRun } from "./faux-run.ts";

test("refreshes resumed logs without duplicating calls, retains bad observations, and rebuilds the same projections", async () => {
  const root = mkdtempSync(join(tmpdir(), "buckshot-analysis-"));
  const source = join(root, "tournament");
  const database = join(root, "analysis.sqlite");
  const match = join(source, "a_b_b0_p0");
  mkdirSync(source);

  try {
    await playFauxRun(match, ["Agent", "Agent"], "on-turn");
    const schedule = [{ name: "a_b_b0_p0", pairing: 0, block: 0, seed: 42, seats: ["A", "B"], entrants: ["a", "b"] }, { name: "b_a_b0_p1", pairing: 0, block: 0, seed: 42, seats: ["B", "A"], entrants: ["b", "a"] }];
    writeFileSync(join(source, "tournament.json"), JSON.stringify({ format: 1, created_at: "2026-01-01T00:00:00Z", git_commit: "test", config: { name: "test", seed: 42, delivery: "on-turn", endpoints: { fake: { api: "anthropic", url: "http://invalid", keyEnv: "UNUSED" } }, entrants: { a: { endpoint: "fake", model: "faux-a", effort: "medium" }, b: { endpoint: "fake", model: "faux-b", effort: "medium" } }, pairings: [["a", "b"]], blocksPerPairing: 1 }, schedule }));
    const eventsPath = join(match, "events.jsonl");
    const callsPath = join(match, "calls.jsonl");
    const events = readFileSync(eventsPath, "utf8");
    const calls = readFileSync(callsPath, "utf8");
    const refresh = () => importTournaments({ database, sources: [source], skipped: { [source]: { b_a_b0_p1: "never played" } } });

    const snapshot = () => {
      const db = openAnalysis(database);

      try {
        return {
          matches: db.query("SELECT name,status,seed,seed_block_id,replay_status FROM matches ORDER BY name").all(),
          seats: db.query("SELECT position,player,cash,win_share FROM match_seats ORDER BY match_id,position").all(),
          calls: db.query("SELECT id,decision_id,reasoning_text,reasoning_tokens,cost_usd FROM calls ORDER BY id").all(),
          decisions: db.query("SELECT turn,player,selected_move,visible_json,legal_json FROM decisions ORDER BY match_id,ordinal").all(),
        };
      } finally { db.close(); }
    };

    refresh();
    const complete = snapshot();
    expect(complete.matches).toMatchObject([{ status: "completed", replay_status: "validated" }, { status: "skipped" }]);
    expect(complete.calls.length).toBe(calls.trimEnd().split("\n").length);
    expect(complete.decisions.length).toBeGreaterThan(0);
    const inspection = openAnalysis(database);
    expect(inspection.query("SELECT COUNT(*) AS n FROM calls WHERE cost_usd IS NULL").get()).toEqual({ n: 0 });
    expect(inspection.query("SELECT COUNT(*) AS n FROM decisions WHERE visible_json LIKE '%I weigh the shells%'").get()).toEqual({ n: 0 });
    expect(inspection.query("SELECT reasoning_text FROM calls LIMIT 1").get()).toEqual({ reasoning_text: "I weigh the shells left against the items I hold." });
    inspection.close();
    refresh();
    expect(snapshot()).toEqual(complete);
    // Read all prefixes of the last call. Neither valid-but-unterminated JSON nor fragments count as calls.
    const lastNewline = calls.lastIndexOf("\n", calls.length - 2);
    const last = calls.slice(lastNewline + 1, -1);

    for (const length of [1, Math.floor(last.length / 2), last.length]) {
      writeFileSync(callsPath, calls.slice(0, lastNewline + 1) + last.slice(0, length));
      refresh();
      expect(snapshot().calls.length).toBe(complete.calls.length - 1);
    }

    writeFileSync(callsPath, calls);
    const manifestPath = join(match, "manifest.json");
    const manifest = readFileSync(manifestPath, "utf8");
    writeFileSync(manifestPath, manifest.replace('"status": "finished"', '"status": "running"'));
    appendFileSync(callsPath, JSON.stringify({ t: "2026-01-01T00:00:00Z", agent: "A", position: 1, provider: "faux", api: "faux", model: "unpriced", stop_reason: "error", error: "quota exhausted", usage: { input: 0, output: 0, cacheRead: 0, cacheWrite: 0 }, tool_calls: [], text: "", thinking: "" }) + "\n");
    refresh();
    const partial = openAnalysis(database);
    expect(partial.query("SELECT status FROM matches WHERE name = 'a_b_b0_p0'").get()).toEqual({ status: "partial" });
    expect(partial.query("SELECT status,input_tokens,reasoning_tokens,cost_usd,latency_ms FROM calls WHERE model = 'unpriced'").get()).toEqual({ status: "failed", input_tokens: 0, reasoning_tokens: null, cost_usd: null, latency_ms: null });
    expect(partial.query("SELECT COUNT(*) AS n FROM match_seats s JOIN matches m ON m.id=s.match_id WHERE m.status='partial' AND s.win_share IS NOT NULL").get()).toEqual({ n: 0 });
    partial.close();
    writeFileSync(manifestPath, manifest);
    writeFileSync(callsPath, calls);
    const moveLine = events.split("\n").find((line) => line.includes('"kind":"move"'));
    expect(moveLine).toBeDefined();
    appendFileSync(eventsPath, `${moveLine}\nnot json\n`);
    refresh();
    expect(snapshot()).toEqual(complete);
    const db = openAnalysis(database);
    expect(db.query("SELECT COUNT(*) AS n FROM issues").get()).not.toEqual({ n: 0 });
    expect(db.query("SELECT COUNT(*) AS n FROM source_records WHERE current = 0").get()).not.toEqual({ n: 0 });
    expect(db.query("PRAGMA foreign_key_check").all()).toEqual([]);
    db.close();
    writeFileSync(eventsPath, events);
    refresh();
    expect(snapshot()).toEqual(complete);
    rmSync(database);
    refresh();
    expect(snapshot()).toEqual(complete);
  } finally { rmSync(root, { recursive: true, force: true }); }
});

test("a finished match with an explicit skip keeps its moves and costs but is not scored, and each skip keeps its own reason", async () => {
  const root = mkdtempSync(join(tmpdir(), "buckshot-analysis-"));
  const source = join(root, "tournament");
  const database = join(root, "analysis.sqlite");
  mkdirSync(source);

  try {
    await playFauxRun(join(source, "a_b_b0_p0"), ["Agent", "Agent"], "on-turn");
    const schedule = [{ name: "a_b_b0_p0", pairing: 0, block: 0, seed: 42, seats: ["A", "B"], entrants: ["a", "b"] }, { name: "b_a_b0_p1", pairing: 0, block: 0, seed: 42, seats: ["B", "A"], entrants: ["b", "a"] }];
    writeFileSync(join(source, "tournament.json"), JSON.stringify({ format: 1, created_at: "2026-01-01T00:00:00Z", git_commit: "test", config: { name: "test", seed: 42, delivery: "on-turn", endpoints: { fake: { api: "anthropic", url: "http://invalid", keyEnv: "UNUSED" } }, entrants: { a: { endpoint: "fake", model: "faux-a", effort: "medium" }, b: { endpoint: "fake", model: "faux-b", effort: "medium" } }, pairings: [["a", "b"]], blocksPerPairing: 1 }, schedule }));
    importTournaments({ database, sources: [source], skipped: { [source]: { a_b_b0_p0: "over the cap", b_a_b0_p1: "never played" } } });
    const db = openAnalysis(database);

    try {
      expect(db.query("SELECT name,status,disposition,status_reason FROM matches ORDER BY name").all()).toEqual([
        { name: "a_b_b0_p0", status: "partial", disposition: "skipped", status_reason: "over the cap" },
        { name: "b_a_b0_p1", status: "skipped", disposition: "skipped", status_reason: "never played" },
      ]);
      expect(db.query("SELECT COUNT(*) AS n FROM match_seats WHERE win_share IS NOT NULL").get()).toEqual({ n: 0 });
      expect(db.query("SELECT COUNT(*) > 0 AS has FROM calls").get()).toEqual({ has: 1 });
      expect(db.query("SELECT status FROM tournaments").get()).toEqual({ status: "completed" });
    } finally { db.close(); }
  } finally { rmSync(root, { recursive: true, force: true }); }
});
