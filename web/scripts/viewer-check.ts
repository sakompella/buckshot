import { appendFileSync, copyFileSync, mkdirSync, mkdtempSync, readFileSync, writeFileSync } from "node:fs";
import { tmpdir } from "node:os";
import { join } from "node:path";

import { Schema } from "effect";
import { chromium } from "playwright-core";

import { decodeEventLine, movesOf, readJsonl } from "../src/viewer/runs.ts";
import { playFauxRun } from "../test/faux-run.ts";

// Screenshots the arena viewer over a temp runs dir: two faux runs played
// here, a format-0 run, and "live-copy", faux-live cut to about 30% mid-line
// with its manifest set back to running. The rest of live-copy is appended
// while the page watches, then the finished manifest is written back.
// Usage: bun scripts/viewer-check.ts [outdir]

const outdir = process.argv[2] ?? "/tmp/arena-viewer";

const chrome = process.env["CHROME"] ?? "/Applications/Google Chrome.app/Contents/MacOS/Google Chrome";

const check = (ok: boolean, what: string) => {
  if (!ok) throw new Error(`viewer check failed: ${what}`);

  console.log(`ok: ${what}`);
};

const dir = mkdtempSync(join(tmpdir(), "arena-viewer-"));

const source = join(dir, "faux-live");

await playFauxRun(source, ["Agent", "Agent", "DoN"], "live");

await playFauxRun(join(dir, "faux-onturn"), ["Agent", "Agent"], "on-turn");

mkdirSync(join(dir, "format-0"));

writeFileSync(join(dir, "format-0", "manifest.json"), JSON.stringify({ status: "finished", seed: "42", controllers: ["Agent", "Agent"] }));

const live = join(dir, "live-copy");

const full = { events: readFileSync(join(source, "events.jsonl")), calls: readFileSync(join(source, "calls.jsonl")) };

const moves = movesOf(readJsonl(full.events.toString("utf8"), decodeEventLine));

const expected = { steps: moves.length + 1, calls: full.calls.toString("utf8").split("\n").length - 1, reasoned: moves.filter((move) => move.by === "agent").length };

/** A byte offset near `fraction` of the file that falls inside a line. */
const midLine = (bytes: Buffer, fraction: number) => {
  let cut = Math.floor(bytes.length * fraction);

  while (bytes[cut - 1] === 0x0a || bytes[cut] === 0x0a) cut += 1;

  return cut;
};

const cuts = { events: midLine(full.events, 0.3), calls: midLine(full.calls, 0.3) };

const finished = Schema.decodeUnknownSync(Schema.fromJsonString(Schema.Record(Schema.String, Schema.Json)))(readFileSync(join(source, "manifest.json"), "utf8"));

const running = { ...Object.fromEntries(["format", "seed", "controllers", "letters", "delivery", "seating", "agents"].map((key) => [key, finished[key] ?? null])), status: "running" };

mkdirSync(live);

writeFileSync(join(live, "manifest.json"), JSON.stringify(running, null, 2));

writeFileSync(join(live, "events.jsonl"), full.events.subarray(0, cuts.events));

writeFileSync(join(live, "calls.jsonl"), full.calls.subarray(0, cuts.calls));

const server = Bun.spawn(["bun", "scripts/viewer.ts", "--dir", dir, "--port", "0"], { cwd: new URL("..", import.meta.url).pathname, stdout: "pipe", stderr: "inherit" });

const reader = server.stdout.getReader();

const { value } = await reader.read();

const base = /http:\/\/127\.0\.0\.1:\d+\//.exec(new TextDecoder().decode(value))?.[0];

if (base === undefined) throw new Error("the viewer printed no URL");

const browser = await chromium.launch({ executablePath: chrome, headless: true });

const page = await browser.newPage({ viewport: { width: 1600, height: 1000 } });

const problems: Array<string> = [];

page.on("console", (message) => {
  if (message.type() === "error" || message.type() === "warning") problems.push(message.text());
});

page.on("pageerror", (error) => problems.push(error.message));

const counts = async () => ({ steps: await page.locator(".step").count(), calls: await page.locator(".item.call").count() });

try {
  await page.goto(base);
  await page.locator(".runs tbody tr").first().waitFor();
  check((await page.locator(".runs tr.unreadable").count()) === 1, "the format-0 run is listed as unreadable");
  check((await page.locator(".runs .badge-live").count()) === 1, "live-copy is LIVE");
  check((await page.locator(".runs tbody tr").first().locator(".badge-live").count()) === 1, "with no sort, the live run is listed first");
  await page.screenshot({ path: `${outdir}/list.png` });

  await page.getByRole("button", { name: "Status" }).click();
  check(page.url().endsWith("?sort=status&dir=asc"), "clicking Status puts the sort in the query string");
  check((await page.locator(".runs tbody tr").first().locator(".badge-live").count()) === 1 && (await page.locator(".runs tbody tr").last().getAttribute("class")) === "unreadable", "sorted by status, live is first and the unreadable run last");
  check((await page.locator('th[aria-sort="ascending"]').textContent())?.includes("Status") === true, "the sorted column's header says so");
  await page.getByRole("button", { name: "Cost" }).click();
  check(page.url().endsWith("?sort=cost&dir=desc"), "clicking Cost sorts it most expensive first");
  await page.getByRole("button", { name: "Cost" }).click();
  await page.getByRole("button", { name: "Cost" }).click();
  check(!page.url().includes("sort="), "a third click on a header goes back to live first");
  await page.goto(`${base}?sort=started&dir=asc`);
  await page.locator(".runs tbody tr").first().waitFor();
  check((await page.locator(".runs tbody tr").first().textContent())?.includes("faux-") === true && (await page.locator('th[aria-sort="ascending"]').textContent())?.includes("Started") === true, "a sort in the query string is applied on load");

  await page.goto(base);
  await page.locator(".runs tbody tr").first().waitFor();
  await page.locator('select[data-field="model"]').selectOption("faux-a");
  check(page.url().endsWith("?model=faux-a"), "picking a model puts it in the query string");
  await page.locator('select[data-field="vs"]').selectOption("faux-b");
  check(page.url().endsWith("?model=faux-a&vs=faux-b") && (await page.locator(".runs tbody tr").count()) === 3, "a head to head keeps the runs where both models played, and drops the unreadable one");
  await page.goto(`${base}?model=faux-a&vs=faux-a`);
  await page.locator(".runs").waitFor();
  check((await page.locator(".runs tbody tr").count()) === 0, "a head to head of one model needs two agents of it");
  await page.goto(`${base}?family=faux-b&effort=high`);
  await page.locator(".runs").waitFor();
  check((await page.locator(".runs tbody tr").count()) === 0 && (await page.locator('select[data-field="effort"]').inputValue()) === "high", "a filter on an effort no run has shows nothing, and its picker still says which");
  await page.goto(base);
  await page.locator(".runs tbody tr").first().waitFor();
  check((await page.locator(".runs tbody tr").first().locator(".model").first().textContent()) === "faux-a" && (await page.locator(".runs tbody tr .effort.unset").count()) > 0, "each agent shows its model and an effort of its own, unset when the manifest has none");
  check((await page.locator("nav a").count()) === 1, "with no tournament.json there is no leaderboard link");

  await page.goto(`${base}match/faux-live`);
  await page.locator("body[data-polling=stopped]").waitFor();
  const shown = await counts();

  check(shown.steps === expected.steps && shown.calls === expected.calls, `the finished match shows all ${expected.steps} steps and ${expected.calls} calls, and stops polling`);
  check((await page.locator(".step .reasoning .cot.thinking").count()) === expected.reasoned, `each of the ${expected.reasoned} agent moves shows its thinking under it`);
  check((await page.locator(".step .reasoning .cot-label").first().textContent()) === "thinking", "a faux agent's reasoning is labelled thinking");
  await page.locator('.step[data-index="60"]').click();
  check((await page.locator(".position").textContent()) === `60 / ${expected.steps - 1}`, "clicking a step selects it");
  await page.screenshot({ path: `${outdir}/finished.png` });

  await page.goto(`${base}match/live-copy`);
  await page.locator(".step").first().waitFor();
  await page.locator(".badge-live").waitFor();

  const before = await counts();

  await page.screenshot({ path: `${outdir}/live-before.png` });

  const chunks = 4;

  for (let chunk = 1; chunk <= chunks; chunk++) {
    for (const file of ["events", "calls"] as const) {
      const from = cuts[file] + Math.floor(((full[file].length - cuts[file]) * (chunk - 1)) / chunks);
      const to = chunk === chunks ? full[file].length : cuts[file] + Math.floor(((full[file].length - cuts[file]) * chunk) / chunks);

      appendFileSync(join(live, `${file}.jsonl`), full[file].subarray(from, to));
    }

    await Bun.sleep(800);
  }

  await page.waitForFunction(({ steps, calls }) => document.querySelectorAll(".step").length === steps && document.querySelectorAll(".item.call").length === calls, expected);

  const after = await counts();

  check(after.steps > before.steps && after.calls > before.calls, `steps ${before.steps} -> ${after.steps}, calls ${before.calls} -> ${after.calls}`);
  check(after.steps === expected.steps && after.calls === expected.calls, "the live page followed to the last step and call");
  check((await page.locator(".step .reasoning .cot.thinking").count()) === expected.reasoned, "every agent move of the live page got its reasoning as the calls arrived");
  check((await page.locator(".step.selected").getAttribute("data-index")) === String(expected.steps - 1), "the scrubber followed the new steps");
  check(await page.evaluate(() => [...document.querySelectorAll<HTMLElement>(".column-body")].every((body) => body.scrollHeight - body.scrollTop - body.clientHeight < 40)), "each agent column stayed pinned to its newest entry");
  await page.screenshot({ path: `${outdir}/live-after.png` });

  copyFileSync(join(source, "manifest.json"), join(live, "manifest.json"));
  await page.locator("body[data-polling=stopped]").waitFor();
  check((await page.locator(".match-header").textContent())?.includes("finished") === true, "the page shows finished and stops polling");
  check(problems.length === 0, `no console errors${problems.length === 0 ? "" : `: ${problems.join("; ")}`}`);
} finally {
  await browser.close();
  server.kill();
}
