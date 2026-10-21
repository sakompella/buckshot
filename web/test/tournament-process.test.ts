import { afterEach, expect, test } from "bun:test";
import { existsSync, mkdirSync, mkdtempSync, readFileSync, unlinkSync, writeFileSync } from "node:fs";
import { tmpdir } from "node:os";
import { join } from "node:path";

import { Result } from "effect";

import { parseConfig, scheduleOf } from "../src/arena/tournament.ts";

const WEB = join(import.meta.dir, "..");

const OLD = "abc123";

const runners = new Set<ReturnType<typeof Bun.spawn>>();

afterEach(async () => {
  for (const child of runners) if (child.exitCode === null) child.kill("SIGTERM");
  await Promise.all([...runners].map((child) => child.exited));
  runners.clear();
});

const setup = () => {
  const root = mkdtempSync(join(tmpdir(), "tournament-process-"));
  const dir = join(root, "runs");
  const checkout = join(root, "checkout");
  const config = join(root, "config.json");

  const text = JSON.stringify({ name: "restart", seed: 5, delivery: "on-turn", blocksPerPairing: 1,
    endpoints: { faux: { api: "openai-responses", url: "http://127.0.0.1:1", keyEnv: "FAUX_TEST_KEY" } },
    entrants: { faux: { endpoint: "faux", model: "gpt-6-luna", effort: "high" }, don: { bot: "DoN" } }, pairings: [["faux", "don"]] });

  const tournament = Result.getOrThrow(parseConfig(text));
  const schedule = scheduleOf(tournament);

  mkdirSync(join(checkout, "scripts"), { recursive: true });
  writeFileSync(join(checkout, "scripts/arena.ts"), `import ${JSON.stringify(join(import.meta.dir, "tournament-child.ts"))};\n`);
  writeFileSync(config, text);

  for (const match of schedule) {
    mkdirSync(join(dir, match.name), { recursive: true });
    writeFileSync(join(dir, match.name, "manifest.json"), JSON.stringify({ status: "running", provenance: { code_sha: OLD, agents: {} } }));
  }

  const run = (flags: ReadonlyArray<string> = []) => {
    const child = Bun.spawn(["nice", "-n", "10", "bun", "--no-env-file", "scripts/arena-tournament.ts", config, "--dir", dir, "--parallel", "1", ...flags], {
      cwd: WEB, env: { ...process.env, FAUX_TEST_KEY: "unused-test-key" }, stdout: "pipe", stderr: "pipe",
    });

    runners.add(child);

    return child;
  };

  return { dir, checkout, schedule, run };
};

const waitFor = async (file: string) => {
  const end = Date.now() + 10_000;

  while (!existsSync(file)) {
    if (Date.now() >= end) throw new Error(`waiting for ${file}`);
    await Bun.sleep(10);
  }
};

const starts = (dir: string, name: string) => {
  const file = join(dir, name, "starts.jsonl");

  return existsSync(file) ? readFileSync(file, "utf8").trim().split("\n").length : 0;
};

test("SIGTERM stops the runner's child; restart resumes unfinished matches once and finished matches never run again", async () => {
  const { dir, checkout, schedule, run } = setup();
  const first = schedule[0];

  if (first === undefined) throw new Error("empty schedule");

  writeFileSync(join(dir, first.name, "hold"), "");
  const child = run(["--code", `${OLD}=${checkout}`]);

  try {
    await waitFor(join(dir, first.name, "starts.jsonl"));
    child.kill("SIGTERM");
    expect(await child.exited).toBe(1);
    expect(readFileSync(join(dir, first.name, "stopped"), "utf8")).toBe("SIGTERM");
    expect(schedule.map(({ name }) => starts(dir, name))).toEqual([1, 0]);
    unlinkSync(join(dir, first.name, "hold"));
    const resumed = run(["--code", `${OLD}=${checkout}`]);

    expect(await resumed.exited).toBe(0);
    expect(schedule.map(({ name }) => starts(dir, name))).toEqual([2, 1]);

    for (const { name } of schedule) expect(JSON.parse(readFileSync(join(dir, name, "manifest.json"), "utf8")).status).toBe("finished");
    expect(await run(["--code", `${OLD}=${checkout}`]).exited).toBe(0);
    expect(schedule.map(({ name }) => starts(dir, name))).toEqual([2, 1]);
  } finally {
    if (child.exitCode === null) child.kill("SIGTERM");
  }
}, 30_000);

test("missing code checkouts wait, skip leaves matches untouched, and --limit resumes only the remaining match", async () => {
  const { dir, checkout, schedule, run } = setup();
  const waiting = run();

  expect(await waiting.exited).toBe(1);
  expect(await new Response(waiting.stdout).text()).toContain("wait for a checkout");
  expect(schedule.map(({ name }) => starts(dir, name))).toEqual([0, 0]);
  expect(await run(["--code", `${OLD}=${checkout}`, "--skip", "faux"]).exited).toBe(0);
  expect(schedule.map(({ name }) => starts(dir, name))).toEqual([0, 0]);
  expect(await run(["--code", `${OLD}=${checkout}`, "--limit", "1"]).exited).toBe(1);
  expect(schedule.map(({ name }) => starts(dir, name))).toEqual([1, 0]);
  expect(await run(["--code", `${OLD}=${checkout}`, "--limit", "1"]).exited).toBe(0);
  expect(schedule.map(({ name }) => starts(dir, name))).toEqual([1, 1]);
}, 30_000);
