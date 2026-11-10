import { Database } from "bun:sqlite";
import { afterAll, beforeAll, expect, test } from "bun:test";
import { cpSync, existsSync, mkdirSync, mkdtempSync, readdirSync, readFileSync, rmSync, writeFileSync } from "node:fs";
import { tmpdir } from "node:os";
import { join } from "node:path";

import { importTournaments } from "../src/analysis/import.ts";
import { privacyViolations } from "../src/arena-viewer/privacy.ts";
import { playFauxRun } from "./faux-run.ts";

const WEB = join(import.meta.dir, "..");

const SEED = 913_377;

const root = mkdtempSync(join(tmpdir(), "buckshot-export-"));

const database = join(root, "analysis.sqlite");


/** Text the database holds per call or match, planted so the export can be shown to leave it behind. */
const POISON = {
  error: "quota exceeded for someone@example.com",
  reasoning: "I will shoot myself because the shell is blank",
  response: "shoot opponent please",
  reason: "stopped by operator xyz",
};

/** One played match between two configs, imported as the arena database has it, provenance and all. */
beforeAll(async () => {
  const source = join(root, "tournament");
  const played = join(root, "played");

  mkdirSync(source);
  await playFauxRun(played, ["Agent", "Agent"], "on-turn", String(SEED));
  cpSync(played, join(source, "a_b_b0_p0"), { recursive: true });

  // The faux agents play as the configs the tournament below names.
  const manifest = join(source, "a_b_b0_p0", "manifest.json");

  const manifestJson = JSON.parse(readFileSync(manifest, "utf8"));

  manifestJson.provenance.agents.A.effort = "medium";
  manifestJson.provenance.agents.B.effort = "high";
  writeFileSync(manifest, JSON.stringify({ ...manifestJson, labels: ["faux-a-medium", "faux-b-high"] }));

  const config = {
    name: "test",
    seed: SEED,
    cohort: "test",
    delivery: "on-turn",
    endpoints: { fake: { api: "anthropic", url: "http://invalid", keyEnv: "UNUSED" } },
    entrants: { a: { endpoint: "fake", model: "faux-a", effort: "medium" }, b: { endpoint: "fake", model: "faux-b", effort: "high" } },
    pairings: [["a", "b"]],
    blocksPerPairing: 1,
  };

  const schedule = [{ name: "a_b_b0_p0", pairing: 0, block: 0, seed: SEED, seats: ["A", "B"], entrants: ["a", "b"] }];

  writeFileSync(join(source, "tournament.json"), JSON.stringify({ format: 1, created_at: "2026-01-01T00:00:00Z", git_commit: "test", config, schedule }));
  importTournaments({ database, sources: [source] });
});

afterAll(() => rmSync(root, { recursive: true, force: true }));

const exportTo = async (out: string) => {
  const child = Bun.spawn(["nice", "-n", "10", "bun", "scripts/arena-export.ts", database, "--out", out], { cwd: WEB, stdout: "pipe", stderr: "pipe" });

  return { code: await child.exited, stderr: await new Response(child.stderr).text() };
};

const readExport = (out: string): ReadonlyMap<string, string> => new Map(readdirSync(out).map((file) => [file.replace(/\.json$/, ""), readFileSync(join(out, file), "utf8")]));

test("a database that keeps its provenance is refused and nothing is written", async () => {
  const out = join(root, "refused");
  const { code, stderr } = await exportTo(out);

  expect(code).toBe(1);
  expect(stderr).toContain("not a public database");
  expect(existsSync(out)).toBe(false);
});

test("a public database exports aggregate files that pass the privacy check and hold no seed or seed block", async () => {
  const db = new Database(database);

  db.run("update match_seats set provenance_json = null");

  const planted = [
    db.run(`update calls set error = '${POISON.error}', reasoning_text = '${POISON.reasoning}', response_text = '${POISON.response}'`),
    db.run(`update matches set status_reason = '${POISON.reason}'`),
  ];

  expect(planted.every(({ changes }) => changes > 0)).toBe(true);

  const blocks = db.query<{ readonly id: string }, []>("select distinct seed_block_id id from matches").all();

  db.close();

  const out = join(root, "public");
  const { code, stderr } = await exportTo(out);

  expect([code, stderr]).toEqual([0, ""]);

  const files = readExport(out);
  const everything = [...files.values()].join("\n");

  expect(privacyViolations(files)).toEqual([]);
  expect(JSON.parse(files.get("summary") ?? "")).toMatchObject({ configs: [{ model: "faux-a", effort: "medium", scored: 1 }, { model: "faux-b", effort: "high", scored: 1 }] });
  expect(everything).not.toContain(String(SEED));

  for (const { id } of blocks) expect(everything).not.toContain(id);

  for (const poison of Object.values(POISON)) expect(everything).not.toContain(poison);
});

test("the privacy check names each kind of leak in the exported files", () => {
  const files = readExport(join(root, "public"));
  const poisoned = (name: string, edit: (json: string) => string) => new Map([...files].map(([file, json]) => [file, file === name ? edit(json) : json]));

  const cases: ReadonlyArray<readonly [string, ReadonlyMap<string, string>, string]> = [
    ["a per-match key", poisoned("pairs", (json) => json.replace('{"first"', '{"matchId":"m1","first"')), "forbidden key"],
    ["an id", poisoned("summary", (json) => json.replace('"faux-a"', '"faux-a-0123456789abcdef"')), "12 or more hex digits"],
    ["an email", poisoned("consistency", () => '[{"model":"someone@example.com","effort":"medium","positions":1,"agree":1,"lo":1,"hi":1}]'), "looks like an email"],
    ["a stray string", poisoned("odds", () => '[{"config":"seat B of match 4","bins":[]}]'), "unexpected string"],
    ["a timestamp", poisoned("manifest", (json) => json.replace(/"generated":"[^"]*"/, '"generated":"2026-11-04T07:00:00Z"')), "manifest"],
    ["an extra file", new Map([...files, ["matches", "[]"]]), "not an export file"],
  ];

  expect(files.size).toBe(7);

  for (const [, leaky, expected] of cases) expect(privacyViolations(leaky).join("\n")).toContain(expected);
});
