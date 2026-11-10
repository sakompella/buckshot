import { afterAll, beforeAll, expect, setDefaultTimeout, test } from "bun:test";
import { appendFileSync, cpSync, mkdtempSync, mkdirSync, readFileSync, rmSync, writeFileSync } from "node:fs";
import { tmpdir } from "node:os";
import { join } from "node:path";

import { Option, Result } from "effect";

import { importTournaments, openAnalysis } from "../src/analysis/import.ts";
import { assertCurrentImport } from "../src/analysis/importer-hash.ts";
import { replayOf } from "../src/arena/replay.ts";
import { playFauxRun } from "./faux-run.ts";

const played = mkdtempSync(join(tmpdir(), "buckshot-analysis-faux-"));

// Each test imports and replays a match, several times over in the longest.
setDefaultTimeout(30_000);

beforeAll(() => playFauxRun(played, ["Agent", "Agent"], "on-turn"), 30_000);

afterAll(() => rmSync(played, { recursive: true, force: true }));

/** Every test reads the same finished match, so it is played once and copied, with both agents at medium effort as the tests' configs say. */
const fauxMatchInto = (dir: string) => {
  cpSync(played, dir, { recursive: true });
  const manifestPath = join(dir, "manifest.json");
  const manifest = JSON.parse(readFileSync(manifestPath, "utf8"));

  for (const agent of Object.values<{ effort: string | null }>(manifest.provenance.agents)) agent.effort = "medium";
  // Without recorded labels each seat is labelled by its entrant's config, as a match from before labels.
  delete manifest.labels;

  writeFileSync(manifestPath, JSON.stringify(manifest, null, 2));
};

test("refreshes resumed logs without duplicating calls or repeated moves, stops at a bad line, and rebuilds the same projections", async () => {
  const root = mkdtempSync(join(tmpdir(), "buckshot-analysis-"));
  const source = join(root, "tournament");
  const database = join(root, "analysis.sqlite");
  const match = join(source, "a_b_b0_p0");
  mkdirSync(source);

  try {
    fauxMatchInto(match);
    const schedule = [{ name: "a_b_b0_p0", pairing: 0, block: 0, seed: 42, seats: ["A", "B"], entrants: ["a", "b"] }, { name: "b_a_b0_p1", pairing: 0, block: 0, seed: 42, seats: ["B", "A"], entrants: ["b", "a"] }];
    writeFileSync(join(source, "tournament.json"), JSON.stringify({ format: 1, created_at: "2026-01-01T00:00:00Z", git_commit: "test", config: { name: "test", seed: 42, cohort: "test", delivery: "on-turn", endpoints: { fake: { api: "anthropic", url: "http://invalid", keyEnv: "UNUSED" } }, entrants: { a: { endpoint: "fake", model: "faux-a", effort: "medium" }, b: { endpoint: "fake", model: "faux-b", effort: "medium" } }, pairings: [["a", "b"]], blocksPerPairing: 1 }, schedule }));
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
    const manifestPath = join(match, "manifest.json");
    const manifest = readFileSync(manifestPath, "utf8");
    writeFileSync(manifestPath, manifest.replace('"status": "finished"', '"status": "running"'));
    // Read all prefixes of a live match's last call. Neither valid-but-unterminated JSON nor fragments count as calls.
    const lastNewline = calls.lastIndexOf("\n", calls.length - 2);
    const last = calls.slice(lastNewline + 1, -1);

    for (const length of [1, Math.floor(last.length / 2), last.length]) {
      writeFileSync(callsPath, calls.slice(0, lastNewline + 1) + last.slice(0, length));
      refresh();
      expect(snapshot().calls.length).toBe(complete.calls.length - 1);
    }

    writeFileSync(callsPath, calls);
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
    appendFileSync(eventsPath, `${moveLine}\n`);
    refresh();
    expect(snapshot()).toEqual(complete);
    appendFileSync(eventsPath, "not json\n");
    expect(refresh).toThrow(/events.jsonl line \d+ does not decode/);
    expect(snapshot()).toEqual(complete);
    const db = openAnalysis(database);
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
    fauxMatchInto(join(source, "a_b_b0_p0"));
    const schedule = [{ name: "a_b_b0_p0", pairing: 0, block: 0, seed: 42, seats: ["A", "B"], entrants: ["a", "b"] }, { name: "b_a_b0_p1", pairing: 0, block: 0, seed: 42, seats: ["B", "A"], entrants: ["b", "a"] }];
    writeFileSync(join(source, "tournament.json"), JSON.stringify({ format: 1, created_at: "2026-01-01T00:00:00Z", git_commit: "test", config: { name: "test", seed: 42, cohort: "test", delivery: "on-turn", endpoints: { fake: { api: "anthropic", url: "http://invalid", keyEnv: "UNUSED" } }, entrants: { a: { endpoint: "fake", model: "faux-a", effort: "medium" }, b: { endpoint: "fake", model: "faux-b", effort: "medium" } }, pairings: [["a", "b"]], blocksPerPairing: 1 }, schedule }));
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

const probeTournament = (root: string, effort: string) => {
  const source = join(root, "source");
  const name = "a_b_b0_p0";
  mkdirSync(source);
  fauxMatchInto(join(source, name));
  const manifestPath = join(source, name, "manifest.json");
  const configured = (aEffort: string) => ({ format: 1, created_at: "2026-01-01T00:00:00Z", git_commit: "test", config: { name: "probe", seed: 42, cohort: "test", delivery: "on-turn", endpoints: { fake: { api: "anthropic", url: "http://invalid", keyEnv: "UNUSED" } }, entrants: { a: { endpoint: "fake", model: "faux-a", effort: aEffort }, b: { endpoint: "fake", model: "faux-b", effort: "medium" } }, pairings: [["a", "b"]], blocksPerPairing: 1 }, schedule: [{ name, pairing: 0, block: 0, seed: 42, seats: ["A", "B"], entrants: ["a", "b"] }] });
  const configure = (aEffort: string) => writeFileSync(join(source, "tournament.json"), JSON.stringify(configured(aEffort)));
  configure(effort);

  return { source, manifestPath, configure };
};

const rowsOf = (database: string, sql: string) => {
  const db = openAnalysis(database);

  try { return db.query(sql).all(); } finally { db.close(); }
};

test("calls join on the turn they were made on: logged where the log has it, taken from the events where not, and unlinked when no move was made then", async () => {
  const root = mkdtempSync(join(tmpdir(), "buckshot-analysis-"));

  try {
    const { source, manifestPath } = probeTournament(root, "medium");
    const callsPath = join(manifestPath, "..", "calls.jsonl");
    const logged = readFileSync(callsPath, "utf8").trimEnd().split("\n").map((line) => JSON.parse(line));
    const links = "SELECT link_method, decision_id IS NULL AS unlinked, COUNT(*) AS n FROM calls GROUP BY 1, 2";
    const write = (lines: ReadonlyArray<object>) => writeFileSync(callsPath, `${lines.map((line) => JSON.stringify(line)).join("\n")}\n`);

    const import_ = (name: string) => {
      const database = join(root, `${name}.sqlite`);

      importTournaments({ database, sources: [source] });

      return database;
    };

    expect(logged.every(({ turn }) => Number.isInteger(turn))).toBe(true);

    const exact = import_("exact");
    expect(rowsOf(exact, links)).toEqual([{ link_method: "logged turn", unlinked: 0, n: logged.length }]);

    write(logged.map(({ turn: _turn, ...line }) => line));

    const older = import_("older");
    expect(rowsOf(older, links)).toEqual([{ link_method: "events turn", unlinked: 0, n: logged.length }]);
    expect(rowsOf(older, "SELECT decision_id FROM calls ORDER BY ordinal")).toEqual(rowsOf(exact, "SELECT decision_id FROM calls ORDER BY ordinal"));

    write(logged.map((line, index) => (index === logged.length - 1 ? { ...line, t: "2099-01-01T00:00:00Z", turn: 9999 } : line)));
    expect(rowsOf(import_("unlinked"), links)).toContainEqual({ link_method: "unlinked", unlinked: 1, n: 1 });

    write(logged.map((line, index) => (index === 0 ? { ...line, turn: line.turn + 2 } : line)));
    expect(() => import_("disagree")).toThrow("a call's logged turn is not the turn of its player's next event");
  } finally { rmSync(root, { recursive: true, force: true }); }
});

test("a database validated by other replay or rules code is refused, by the TypeScript readers and the Python analysis alike", async () => {
  const root = mkdtempSync(join(tmpdir(), "buckshot-analysis-"));

  try {
    const { source } = probeTournament(root, "medium");
    const database = join(root, "analysis.sqlite");
    importTournaments({ database, sources: [source] });
    const python = () => Bun.spawnSync(["python3", "-c", `import sys; sys.path.insert(0, "${join(import.meta.dir, "../../tools/arena/analysis")}"); import load; load.require_current("${database}")`], { stderr: "pipe" });
    const db = openAnalysis(database);

    assertCurrentImport(db);
    expect(python().exitCode).toBe(0);
    db.run("UPDATE matches SET validated_with = 'older rules'");
    expect(() => assertCurrentImport(db)).toThrow("validated by other replay or rules code");
    expect(python().stderr.toString()).toContain("validated by other replay or rules code");
    db.close();
  } finally { rmSync(root, { recursive: true, force: true }); }
});

test("a changed tournament config is checked on unchanged matches, as a fresh rebuild does", async () => {
  const root = mkdtempSync(join(tmpdir(), "buckshot-analysis-"));

  try {
    const { source, configure } = probeTournament(root, "medium");
    const database = join(root, "analysis.sqlite");
    const fresh = join(root, "fresh.sqlite");
    importTournaments({ database, sources: [source] });
    configure("high");
    expect(() => importTournaments({ database, sources: [source] })).toThrow("agent A played at effort medium, the schedule says high");
    expect(() => importTournaments({ database: fresh, sources: [source] })).toThrow("agent A played at effort medium, the schedule says high");
    configure("medium");
    importTournaments({ database, sources: [source] });
  } finally { rmSync(root, { recursive: true, force: true }); }
});

test("a match's cohort is its tournament config's, and a config without one stops the import", async () => {
  const root = mkdtempSync(join(tmpdir(), "buckshot-analysis-"));

  try {
    const { source } = probeTournament(root, "medium");
    const database = join(root, "analysis.sqlite");
    importTournaments({ database, sources: [source] });
    expect(rowsOf(database, "SELECT cohort FROM matches")).toEqual([{ cohort: "test" }]);
    const file = JSON.parse(readFileSync(join(source, "tournament.json"), "utf8"));
    delete file.config.cohort;
    writeFileSync(join(source, "tournament.json"), JSON.stringify(file));
    expect(() => importTournaments({ database, sources: [source] })).toThrow("the tournament config names no cohort");
  } finally { rmSync(root, { recursive: true, force: true }); }
});

test("an entrant with an effort label is filed under it, and the others under their effort", async () => {
  const root = mkdtempSync(join(tmpdir(), "buckshot-analysis-"));

  try {
    const { source } = probeTournament(root, "medium");
    const database = join(root, "analysis.sqlite");
    const file = JSON.parse(readFileSync(join(source, "tournament.json"), "utf8"));

    file.config.entrants.a.effortLabel = "off";
    writeFileSync(join(source, "tournament.json"), JSON.stringify(file));
    importTournaments({ database, sources: [source] });
    expect(rowsOf(database, "SELECT name, effort FROM entrants ORDER BY name")).toEqual([{ name: "a", effort: "off" }, { name: "b", effort: "medium" }]);
  } finally { rmSync(root, { recursive: true, force: true }); }
});

test("a match whose agent played its entrant's instructions addendum imports", async () => {
  const root = mkdtempSync(join(tmpdir(), "buckshot-analysis-"));

  try {
    const { source } = probeTournament(root, "medium");
    const database = join(root, "analysis.sqlite");
    const tournamentPath = join(source, "tournament.json");
    const manifestPath = join(source, "a_b_b0_p0", "manifest.json");
    const file = JSON.parse(readFileSync(tournamentPath, "utf8"));
    const manifest = JSON.parse(readFileSync(manifestPath, "utf8"));

    file.config.entrants.a.instructionsAddendum = "Answer at once.";
    manifest.provenance.agents[manifest.letters[0]].instructions_addendum = "Answer at once.";
    writeFileSync(tournamentPath, JSON.stringify(file));
    writeFileSync(manifestPath, JSON.stringify(manifest));
    importTournaments({ database, sources: [source] });
    expect(rowsOf(database, "SELECT status FROM matches")).toEqual([{ status: "completed" }]);
  } finally { rmSync(root, { recursive: true, force: true }); }
});

test("importing the same tournament from a new directory leaves every row and source observation pointing at the new one", async () => {
  const root = mkdtempSync(join(tmpdir(), "buckshot-analysis-"));

  try {
    const { source } = probeTournament(root, "medium");
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
    expect(rowsOf(database, "PRAGMA foreign_key_check")).toEqual([]);
  } finally { rmSync(root, { recursive: true, force: true }); }
});

test("a finished match whose standings do not cover every player stops the import", async () => {
  const root = mkdtempSync(join(tmpdir(), "buckshot-analysis-"));

  try {
    const { source, manifestPath } = probeTournament(root, "medium");
    const database = join(root, "analysis.sqlite");
    const manifest = JSON.parse(readFileSync(manifestPath, "utf8"));
    const standings = manifest.standings;

    for (const [label, broken] of [["no standings", undefined], ["one player", standings.slice(0, 1)], ["a repeated player", [standings[0], standings[0]]], ["an unscheduled player", [standings[0], { ...standings[1], player: "C" }]]] as const) {
      writeFileSync(manifestPath, JSON.stringify({ ...manifest, standings: broken }));
      expect(() => importTournaments({ database, sources: [source] }), label).toThrow(/Finished manifest (has no standings|standings do not cover)/);
    }

    writeFileSync(manifestPath, JSON.stringify(manifest));
    importTournaments({ database, sources: [source] });
    expect(rowsOf(database, "SELECT status FROM matches")).toEqual([{ status: "completed" }]);
    expect(rowsOf(database, "SELECT COUNT(*) AS n FROM match_seats WHERE win_share IS NOT NULL")).toEqual([{ n: 2 }]);
  } finally { rmSync(root, { recursive: true, force: true }); }
});

test("a finished match whose replay or end event disagrees with the manifest stops the import", async () => {
  const root = mkdtempSync(join(tmpdir(), "buckshot-analysis-"));

  try {
    const { source, manifestPath } = probeTournament(root, "medium");
    const database = join(root, "analysis.sqlite");
    const eventsPath = join(source, "a_b_b0_p0", "events.jsonl");
    const manifest = JSON.parse(readFileSync(manifestPath, "utf8"));
    const events = readFileSync(eventsPath, "utf8");
    const scored = () => rowsOf(database, "SELECT m.status, COUNT(s.win_share) AS shares FROM matches m JOIN match_seats s ON s.match_id = m.id GROUP BY m.id");
    importTournaments({ database, sources: [source] });
    expect(scored()).toEqual([{ status: "completed", shares: 2 }]);

    writeFileSync(manifestPath, JSON.stringify({ ...manifest, standings: manifest.standings.map((standing: { cash: number }, index: number) => ({ ...standing, cash: standing.cash + index + 1 })) }));
    expect(() => importTournaments({ database, sources: [source] })).toThrow("the replayed cash of");

    writeFileSync(manifestPath, JSON.stringify(manifest));
    writeFileSync(eventsPath, events.split("\n").filter((line) => !line.includes('"kind":"end"')).join("\n"));
    expect(() => importTournaments({ database, sources: [source] })).toThrow("the manifest says finished, the events have no end event");

    writeFileSync(eventsPath, events);
    importTournaments({ database, sources: [source] });
    expect(scored()).toEqual([{ status: "completed", shares: 2 }]);
  } finally { rmSync(root, { recursive: true, force: true }); }
});

test("a truncated but legal move prefix with an end marker and matching current cash stops the import", async () => {
  const root = mkdtempSync(join(tmpdir(), "buckshot-analysis-"));

  try {
    const { source, manifestPath } = probeTournament(root, "medium");
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
    expect(() => importTournaments({ database, sources: [source] })).toThrow("the replay did not reach the end");
  } finally { rmSync(root, { recursive: true, force: true }); }
});

test("importing a tournament from a directory that contains its earlier source retires the earlier source files and observations", async () => {
  const root = mkdtempSync(join(tmpdir(), "buckshot-analysis-"));

  try {
    const { source } = probeTournament(root, "medium");
    const database = join(root, "analysis.sqlite");
    importTournaments({ database, sources: [source] });
    cpSync(join(source, "tournament.json"), join(root, "tournament.json"));
    cpSync(join(source, "a_b_b0_p0"), join(root, "a_b_b0_p0"), { recursive: true });
    importTournaments({ database, sources: [root] });
    expect(rowsOf(database, "SELECT t.source_dir AS tournament, m.source_dir AS match FROM matches m JOIN tournaments t ON t.id = m.tournament_id")).toEqual([{ tournament: root, match: join(root, "a_b_b0_p0") }]);
    expect(rowsOf(database, "SELECT path FROM source_files ORDER BY path")).toEqual(["a_b_b0_p0/calls.jsonl", "a_b_b0_p0/events.jsonl", "a_b_b0_p0/manifest.json", "tournament.json"].map((leaf) => ({ path: join(root, leaf) })));
    expect(rowsOf(database, "SELECT COUNT(*) AS n FROM source_records WHERE current = 1 AND path LIKE '" + source + "/%'")).toEqual([{ n: 0 }]);
    expect(rowsOf(database, "SELECT COUNT(*) AS n FROM source_records WHERE current = 0 AND path LIKE '" + source + "/%'")).not.toEqual([{ n: 0 }]);
    expect(rowsOf(database, "PRAGMA foreign_key_check")).toEqual([]);
  } finally { rmSync(root, { recursive: true, force: true }); }
});
