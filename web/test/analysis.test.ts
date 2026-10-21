import { expect, test } from "bun:test";
import { appendFileSync, cpSync, mkdtempSync, mkdirSync, readFileSync, rmSync, writeFileSync } from "node:fs";
import { tmpdir } from "node:os";
import { join } from "node:path";

import { Option, Result } from "effect";

import { importTournaments, openAnalysis } from "../src/analysis/import.ts";
import { replayOf } from "../src/viewer/replay.ts";
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

const probeTournament = async (root: string, effort: string) => {
  const source = join(root, "source");
  const name = "a_b_b0_p0";
  mkdirSync(source);
  await playFauxRun(join(source, name), ["Agent", "Agent"], "on-turn");
  const manifestPath = join(source, name, "manifest.json");
  const manifest = JSON.parse(readFileSync(manifestPath, "utf8"));

  for (const agent of Object.values<{ effort: string | null }>(manifest.provenance.agents)) agent.effort = "medium";

  writeFileSync(manifestPath, JSON.stringify(manifest));
  const configured = (aEffort: string) => ({ format: 1, created_at: "2026-01-01T00:00:00Z", git_commit: "test", config: { name: "probe", seed: 42, delivery: "on-turn", endpoints: { fake: { api: "anthropic", url: "http://invalid", keyEnv: "UNUSED" } }, entrants: { a: { endpoint: "fake", model: "faux-a", effort: aEffort }, b: { endpoint: "fake", model: "faux-b", effort: "medium" } }, pairings: [["a", "b"]], blocksPerPairing: 1 }, schedule: [{ name, pairing: 0, block: 0, seed: 42, seats: ["A", "B"], entrants: ["a", "b"] }] });
  const configure = (aEffort: string) => writeFileSync(join(source, "tournament.json"), JSON.stringify(configured(aEffort)));
  configure(effort);

  return { source, manifestPath, configure };
};

const rowsOf = (database: string, sql: string) => {
  const db = openAnalysis(database);

  try { return db.query(sql).all(); } finally { db.close(); }
};

test("a changed tournament config revalidates unchanged matches, as a fresh rebuild does", async () => {
  const root = mkdtempSync(join(tmpdir(), "buckshot-analysis-"));

  try {
    const { source, configure } = await probeTournament(root, "medium");
    const database = join(root, "analysis.sqlite");
    const fresh = join(root, "fresh.sqlite");
    importTournaments({ database, sources: [source] });
    expect(rowsOf(database, "SELECT message FROM issues")).toEqual([]);
    configure("high");
    importTournaments({ database, sources: [source] });
    importTournaments({ database: fresh, sources: [source] });
    expect(rowsOf(database, "SELECT message FROM issues")).toEqual([{ message: "agent A played at effort medium, the schedule says high" }]);
    expect(rowsOf(database, "SELECT message FROM issues")).toEqual(rowsOf(fresh, "SELECT message FROM issues"));
    configure("medium");
    importTournaments({ database, sources: [source] });
    expect(rowsOf(database, "SELECT message FROM issues")).toEqual([]);
  } finally { rmSync(root, { recursive: true, force: true }); }
});

test("importing the same tournament from a new directory leaves every row and source observation pointing at the new one", async () => {
  const root = mkdtempSync(join(tmpdir(), "buckshot-analysis-"));

  try {
    const { source } = await probeTournament(root, "medium");
    const database = join(root, "analysis.sqlite");
    const relocated = join(root, "relocated");
    importTournaments({ database, sources: [source] });
    const before = rowsOf(database, "SELECT id,tournament_id FROM matches");
    const decisions = rowsOf(database, "SELECT COUNT(*) AS n FROM decisions");
    cpSync(source, relocated, { recursive: true });
    importTournaments({ database, sources: [relocated] });
    expect(rowsOf(database, "SELECT id,tournament_id FROM matches")).toEqual(before);
    expect(rowsOf(database, "SELECT COUNT(*) AS n FROM tournaments")).toEqual([{ n: 1 }]);
    expect(rowsOf(database, "SELECT COUNT(*) AS n FROM decisions")).toEqual(decisions);
    expect(rowsOf(database, "SELECT t.source_dir AS tournament, m.source_dir AS match FROM matches m JOIN tournaments t ON t.id = m.tournament_id")).toEqual([{ tournament: relocated, match: join(relocated, "a_b_b0_p0") }]);
    expect(rowsOf(database, "SELECT COUNT(*) AS n FROM source_files WHERE path NOT LIKE '" + relocated + "/%'")).toEqual([{ n: 0 }]);
    expect(rowsOf(database, "SELECT COUNT(*) AS n FROM source_records WHERE current = 1 AND path NOT LIKE '" + relocated + "/%'")).toEqual([{ n: 0 }]);
    expect(rowsOf(database, "SELECT COUNT(*) AS n FROM issues")).toEqual([{ n: 0 }]);
    expect(rowsOf(database, "PRAGMA foreign_key_check")).toEqual([]);
  } finally { rmSync(root, { recursive: true, force: true }); }
});

test("a finished match whose standings do not cover every player is reported and not counted as completed or scored", async () => {
  const root = mkdtempSync(join(tmpdir(), "buckshot-analysis-"));

  try {
    const { source, manifestPath } = await probeTournament(root, "medium");
    const database = join(root, "analysis.sqlite");
    const manifest = JSON.parse(readFileSync(manifestPath, "utf8"));
    const standings = manifest.standings;

    for (const [label, broken] of [["no standings", undefined], ["one player", standings.slice(0, 1)], ["a repeated player", [standings[0], standings[0]]], ["an unscheduled player", [standings[0], { ...standings[1], player: "C" }]]] as const) {
      writeFileSync(manifestPath, JSON.stringify({ ...manifest, standings: broken }));
      importTournaments({ database, sources: [source] });
      expect([label, rowsOf(database, "SELECT status FROM matches")]).toEqual([label, [{ status: "partial" }]]);
      expect([label, rowsOf(database, "SELECT COUNT(*) AS n FROM issues WHERE message LIKE 'Finished manifest%'")]).toEqual([label, [{ n: 1 }]]);
      expect(rowsOf(database, "SELECT COUNT(*) AS n FROM match_seats WHERE win_share IS NOT NULL")).toEqual([{ n: 0 }]);
      expect(rowsOf(database, "SELECT status FROM tournaments")).toEqual([{ status: "partial" }]);
    }

    writeFileSync(manifestPath, JSON.stringify(manifest));
    importTournaments({ database, sources: [source] });
    expect(rowsOf(database, "SELECT status FROM matches")).toEqual([{ status: "completed" }]);
    expect(rowsOf(database, "SELECT COUNT(*) AS n FROM issues")).toEqual([{ n: 0 }]);
    expect(rowsOf(database, "SELECT COUNT(*) AS n FROM match_seats WHERE win_share IS NOT NULL")).toEqual([{ n: 2 }]);
  } finally { rmSync(root, { recursive: true, force: true }); }
});

test("a finished match is scored only when its replay and end event confirm the manifest", async () => {
  const root = mkdtempSync(join(tmpdir(), "buckshot-analysis-"));

  try {
    const { source, manifestPath } = await probeTournament(root, "medium");
    const database = join(root, "analysis.sqlite");
    const eventsPath = join(source, "a_b_b0_p0", "events.jsonl");
    const manifest = JSON.parse(readFileSync(manifestPath, "utf8"));
    const events = readFileSync(eventsPath, "utf8");
    const scored = () => rowsOf(database, "SELECT m.status, COUNT(s.win_share) AS shares FROM matches m JOIN match_seats s ON s.match_id = m.id GROUP BY m.id");
    importTournaments({ database, sources: [source] });
    expect(scored()).toEqual([{ status: "completed", shares: 2 }]);

    writeFileSync(manifestPath, JSON.stringify({ ...manifest, standings: manifest.standings.map((standing: { cash: number }, index: number) => ({ ...standing, cash: standing.cash + index + 1 })) }));
    importTournaments({ database, sources: [source] });
    expect(scored()).toEqual([{ status: "partial", shares: 0 }]);
    expect(rowsOf(database, "SELECT COUNT(*) AS n FROM issues WHERE message LIKE 'Replayed cash differs%'")).toEqual([{ n: 2 }]);

    writeFileSync(manifestPath, JSON.stringify(manifest));
    writeFileSync(eventsPath, events.split("\n").filter((line) => !line.includes('"kind":"end"')).join("\n"));
    importTournaments({ database, sources: [source] });
    expect(scored()).toEqual([{ status: "partial", shares: 0 }]);
    expect(rowsOf(database, "SELECT message FROM issues")).toEqual([{ message: "Finished manifest without end event in snapshot" }]);

    writeFileSync(eventsPath, events);
    importTournaments({ database, sources: [source] });
    expect(scored()).toEqual([{ status: "completed", shares: 2 }]);
    expect(rowsOf(database, "SELECT COUNT(*) AS n FROM issues")).toEqual([{ n: 0 }]);
  } finally { rmSync(root, { recursive: true, force: true }); }
});

test("a truncated but legal move prefix with an end marker and matching current cash is not a finished match", async () => {
  const root = mkdtempSync(join(tmpdir(), "buckshot-analysis-"));

  try {
    const { source, manifestPath } = await probeTournament(root, "medium");
    const database = join(root, "analysis.sqlite");
    const eventsPath = join(source, "a_b_b0_p0", "events.jsonl");
    const manifest = JSON.parse(readFileSync(manifestPath, "utf8"));
    const lines = readFileSync(eventsPath, "utf8").split("\n");
    const lastMove = lines.findLastIndex((line) => line.includes('"kind":"move"'));
    const moves = lines.flatMap((line) => line.includes('"kind":"move"') ? [JSON.parse(line)] : []);
    const prefix = replayOf(replayOf(Option.none(), manifest, []).pipe(Result.getOrThrow, Option.some), manifest, moves.slice(0, -1)).pipe(Result.getOrThrow);
    const cash = prefix.frames.at(-1)?.players ?? [];
    expect(cash.length).toBe(2);
    writeFileSync(eventsPath, lines.filter((_, index) => index !== lastMove).join("\n"));
    writeFileSync(manifestPath, JSON.stringify({ ...manifest, standings: manifest.standings.map((standing: { player: string }) => ({ ...standing, cash: cash.find(({ player }) => player === standing.player)?.cash })) }));
    importTournaments({ database, sources: [source] });
    expect(rowsOf(database, "SELECT status FROM matches")).toEqual([{ status: "partial" }]);
    expect(rowsOf(database, "SELECT COUNT(*) AS n FROM match_seats WHERE win_share IS NOT NULL")).toEqual([{ n: 0 }]);
    expect(rowsOf(database, "SELECT message FROM issues")).toEqual([{ message: "Replay did not reach a finished match" }]);
  } finally { rmSync(root, { recursive: true, force: true }); }
});
