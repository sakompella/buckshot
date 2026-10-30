import { mkdirSync } from "node:fs";
import { join } from "node:path";

import { Schema } from "effect";
import { type Browser, chromium, type Page } from "playwright-core";

import { Blunders, MatchDetail } from "../src/arena-viewer/api.ts";
import { anchorId } from "../src/arena-viewer/page/charts.ts";
import { baseName } from "../src/arena-viewer/page/data.ts";
import { GROUPS, Section } from "../src/arena-viewer/page/model.ts";
import { TOUR } from "../src/arena-viewer/page/tour.ts";
import { coverageOfMatch, type RegretCoverage, withoutRegret } from "./arena-viewer-regret-coverage.ts";

// Clicks through the arena viewer's page, its jump menu and replay in headless Chromium at
// desktop, phone and tablet widths and saves screenshots. Pointed at the old viewer too,
// it gives the pictures to compare against.
// Usage: bun scripts/arena-viewer-check.ts <url> [outdir]

const base = (process.argv[2] ?? "http://127.0.0.1:8790").replace(/\/+$/, "");
const outdir = process.argv[3] ?? "/tmp/arena-viewer-shots";
const chrome = process.env["CHROME"] ?? "/etc/profiles/per-user/aditya/bin/chromium";
const errors: Array<string> = [];
const failures: Array<string> = [];

const expectThat = (isOk: boolean, what: string) => {
  if (!isOk) failures.push(what);
};

// A failed check can leave a replay or the tour open over the page, which would make every later click time out. The
// next check starts from the bare page, so one failure is reported once.
const attempt = async (viewport: string, check: string, run: () => Promise<void>, reset: () => Promise<void> = () => Promise.resolve()) => {
  try {
    await run();
  } catch (error) {
    failures.push(`${viewport}: ${check} threw: ${error instanceof Error ? (error.message.split("\n")[0] ?? "") : String(error)}`);

    try {
      await reset();
    } catch {
      failures.push(`${viewport}: could not clear the page after ${check}`);
    }
  }
};

const ACTION_TIMEOUT_MS = 10_000;

const clearOverlays = async (page: Page) => {
  await page.keyboard.press("Escape");
  await page.waitForSelector(".modal, .tour-layer", { state: "detached", timeout: ACTION_TIMEOUT_MS });
};

const VIEWPORTS = [
  { name: "desktop", width: 1500, height: 1000, isTouch: false },
  { name: "phone", width: 390, height: 844, isTouch: true },
  { name: "small", width: 360, height: 800, isTouch: true },
  { name: "tablet", width: 768, height: 1024, isTouch: true },
] as const;

type Viewport = (typeof VIEWPORTS)[number];

const newPage = (browser: Browser, { width, height, isTouch }: Viewport) =>
  browser.newContext(isTouch ? { viewport: { width, height }, deviceScaleFactor: 2, isMobile: true, hasTouch: true } : { viewport: { width, height } }).then((context) => context.newPage());

const shot = (name: string) => join(outdir, `${name}.png`);

// A screenshot of the full page, or of an element taller than the window, shrinks the window to 1x1 for a moment,
// and the charts drawn at that size get negative widths. Those are counted apart from the other errors.
const SCREENSHOT_RESIZE = /attribute width: A negative value is not valid/;

let screenshotResizeErrors = 0;

const watch = (page: Page, name: string) => {
  page.on("pageerror", (error) => errors.push(`${name}: ${error.message}`));
  page.on("console", (message) => {
    if (message.type() !== "error") return;

    if (SCREENSHOT_RESIZE.test(message.text())) screenshotResizeErrors++;
    else errors.push(`${name}: ${message.text().slice(0, 200)}`);
  });
};

// The page renders on the next animation frame after a message, so reads wait two frames.
const settled = (page: Page) => page.evaluate(() => new Promise((resolve) => requestAnimationFrame(() => requestAnimationFrame(resolve))));

const textOf = async (page: Page, selector: string) => (await page.locator(selector).first().innerText()).replaceAll(/\s+/g, " ");

const tipOf = async (page: Page) => {
  await settled(page);

  return (await page.locator(".tip").count()) > 0 ? textOf(page, ".tip") : "none";
};

const countOf = async (page: Page, selector: string) => {
  await settled(page);

  return page.locator(selector).count();
};

const heat = (page: Page) => page.locator("#breakdown details", { has: page.locator("table.heat") });

const loadPage = async (page: Page) => {
  await page.goto(`${base}/`);
  await page.waitForSelector("table.lbt", { timeout: 120_000 });
  await page.waitForSelector(".icard svg rect", { timeout: 60_000 });
};

const openPage = async (page: Page) => {
  const started = Date.now();

  await loadPage(page);
  console.log("every section drawn in", Date.now() - started, "ms");
  console.log("default:", "scatter points", await countOf(page, "#scatter svg g.pt"), "heat rows", await countOf(page, "table.heat tbody tr"), "leaderboard rows", await countOf(page, "table.lbt tbody tr.row"));
  expectThat((await page.getByRole("switch").count()) === 0, "the page still has a switch");
};

// Visible controls smaller than 44px either way (heat cells and leaderboard squares are left out).
const smallTargets = (page: Page) =>
  page.evaluate(() =>
    [...document.querySelectorAll("nav a, .toggle button, .chip, select, input:not([type=checkbox]), .stepper button, .modal .x")].flatMap((element) => {
      const box = element.getBoundingClientRect();

      return box.width > 0 && (box.height < 44 || box.width < 44) ? [`${element.className || element.tagName} ${element.textContent?.slice(0, 20)} ${Math.round(box.width)}x${Math.round(box.height)}`] : [];
    }),
  );

const SECTIONS = Section.literals;

// How far a group's or a section's top sits below the sticky bar after a jump (0 or 1 is right), and whether the URL names it.
const jumpedTo = (page: Page, section: string) =>
  page.evaluate((id) => {
    const bar = [...document.querySelectorAll(".top, nav")].find((element) => getComputedStyle(element).position === "sticky");
    const top = document.getElementById(id)?.getBoundingClientRect().top ?? Number.NaN;

    return `${id}: ${Math.round(top - (bar?.getBoundingClientRect().bottom ?? 0))}px below the bar, hash ${location.hash}`;
  }, section);

// A missing section is a failed check, not an abort: the other sections and viewports still get their pictures.
const captureBaseline = async (browser: Browser, viewport: Viewport) => {
  const { name } = viewport;
  const page = await newPage(browser, viewport);

  await loadPage(page);
  await settled(page);
  console.log(name, "page height", await page.evaluate(() => document.documentElement.scrollHeight), "| leaderboard starts at", await page.evaluate(() => Math.round((document.querySelector("table.lbt")?.getBoundingClientRect().top ?? Number.NaN) + scrollY)));
  await page.screenshot({ path: shot(`${name}-page`), fullPage: true });

  for (const { group, sections } of GROUPS) {
    for (const section of sections) {
      expectThat((await page.locator(`#${group} #${section}, #${group}#${section}`).count()) === 1, `${name}: #${section} is not in the ${group} group`);
    }
  }

  for (const section of [...GROUPS.map(({ group }) => group), ...SECTIONS]) {
    const target = page.locator(`#${section}`);

    if ((await target.count()) === 0) {
      failures.push(`${name}: #${section} is missing`);
      continue;
    }

    await target.screenshot({ path: shot(`${name}-${section}`), style: UNSTICK });
    expectThat((await target.innerText()).trim() !== "", `${name}: #${section} is empty`);
  }

  await page.context().close();
};

// Each group's link lands its heading just under the sticky bar, and so does a link to any section, old links included.
const checkJumps = async (page: Page, name: string, isTouch: boolean) => {
  // The heading's top rule tucks under the bar's own, so -1 is right too.
  const landed = (text: string) => /: -?[01]px below/.test(text);

  for (const { group } of GROUPS) {
    const link = page.locator(`nav a[href="#${group}"]`);

    if ((await link.count()) === 0) {
      failures.push(`${name}: the jump menu has no link to #${group}`);
      continue;
    }

    await (isTouch ? link.tap() : link.click());
    await settled(page);

    const jumped = await jumpedTo(page, group);

    console.log(name, "jump", jumped, "| menu marks", await textOf(page, "nav a.on").catch(() => "none"));
    expectThat(landed(jumped), `${name}: the ${group} link lands at ${jumped}`);
  }

  for (const section of SECTIONS) {
    await page.evaluate((id) => {
      location.hash = id;
    }, section);
    await settled(page);
    await settled(page);

    const jumped = await jumpedTo(page, section);

    expectThat(landed(jumped), `${name}: a link to #${section} lands at ${jumped}`);
  }

  console.log(name, "every section link landed under the bar");
};

const yTicks = (page: Page) =>
  page.evaluate(() =>
    [...document.querySelectorAll("#scatter .card svg > g:not(.ptlabel) > text[text-anchor=end]")]
      .map((text) => ({ y: Number(text.getAttribute("y")), label: text.textContent ?? "" }))
      .toSorted((left, right) => left.y - right.y)
      .map(({ label }) => label)
      .slice(0, 6)
      .join(" "),
  );

const axesOf = (page: Page) =>
  page.evaluate(() => {
    const chart = document.querySelector("#scatter svg");
    const lines = [...(chart?.querySelectorAll("line") ?? [])].filter((line) => line.getAttribute("stroke") === null);
    const vertical = lines.flatMap((line) => (line.getAttribute("x1") === line.getAttribute("x2") ? [Math.round(Number(line.getAttribute("x1")))] : []));
    const horizontal = lines.flatMap((line) => (line.getAttribute("y1") === line.getAttribute("y2") ? [Math.round(Number(line.getAttribute("y1")))] : []));
    const labels = [...(chart?.querySelectorAll("text") ?? [])].flatMap((text) => (text.closest(".ptlabel") === null ? [text.textContent] : []));

    return `${vertical.length} vertical lines at ${vertical.join(",")} | ${horizontal.length} horizontal | labels ${labels.join(" ")}`;
  });

const reliabilityScales = (page: Page) =>
  page.evaluate(() => [...document.querySelectorAll("#reliability .chartrow svg")].map((chart) => [...chart.querySelectorAll("text[text-anchor=middle]")].map((text) => text.textContent).join(" ")).join(" | "));

const checkFixedAxes = async (page: Page, scatter: ReturnType<Page["locator"]>) => {
  const filters = page.locator(".filters");

  const steps: ReadonlyArray<readonly [string, () => Promise<void>]> = [
    ["max off", () => filters.getByRole("button", { name: "max", exact: true }).click()],
    ["Opus off", () => filters.getByRole("button", { name: /Opus/ }).click()],
    ["Opus on", () => filters.getByRole("button", { name: /Opus/ }).click()],
  ];

  const scales = await reliabilityScales(page);

  console.log("reliability scales:", scales);

  for (const [axis, name] of [
    ["Cost", "cost"],
    ["Moves", "moves"],
  ] as const) {
    await scatter.getByRole("button", { name: axis, exact: true }).click();
    await settled(page);

    const before = await axesOf(page);

    console.log(name, "axes:", before);
    await scatter.screenshot({ path: shot(`scatter-${name}-max-on`) });

    for (const [label, step] of steps) {
      await step();
      await settled(page);
      const isSame = (await axesOf(page)) === before;
      const isScaleSame = (await reliabilityScales(page)) === scales;

      console.log(name, label, "| points", await countOf(page, "#scatter svg g.pt"), "| axes unchanged:", isSame, "| reliability scales unchanged:", isScaleSame);
      expectThat(isSame && isScaleSame, `${name} axes moved after ${label}`);

      if (label === "max off") await scatter.screenshot({ path: shot(`scatter-${name}-max-off`) });
    }

    await filters.getByRole("button", { name: "max", exact: true }).click();
    await settled(page);
    console.log(name, "max on again | axes unchanged:", (await axesOf(page)) === before);
    expectThat((await axesOf(page)) === before, `${name} axes moved after max came back on`);
  }
};

// A screenshot of an element taller than the window is stitched while scrolling, so the sticky bar would cover part of it.
const UNSTICK = ".top, nav { position: static !important; }";

const checkRatings = async (page: Page) => {
  await openBreakdown(page);

  const heading = { scatter: await textOf(page, "#scatter h2"), leaderboard: await textOf(page, "table.lbt thead th.rating"), heat: await textOf(page, "table.heat thead th:nth-last-child(2)") };
  const choices = await page.locator(".toggle button, select option").evaluateAll((controls) => controls.map((control) => control.textContent?.trim() ?? "").filter((text) => /^(Elo|Rank|Round wins|Match wins|Cash)$/.test(text)));

  console.log("rating headings", heading, "| rating choices", choices);
  expectThat(heading.scatter.includes("Round Elo") && heading.leaderboard === "Round Elo" && heading.heat === "Round Elo", `a section does not show Round Elo: ${JSON.stringify(heading)}`);
  expectThat(choices.length === 0, `the page still offers a rating choice: ${choices.join(" ")}`);

  const rows = await countOf(page, "table.lbt tbody tr.row");
  const cells = (label: string) => page.locator(`table.lbt td[data-label="${label}"]`).allInnerTexts();
  const elos = await cells("round elo");

  for (const label of ["match wins", "round wins", "cash share"]) {
    const shares = await cells(label);

    console.log(label, "cells", shares.length, "of", rows, "rows, first", shares.slice(0, 4).join(" | "));
    expectThat(shares.length === rows && shares.every((text) => /^\d+%/.test(text.trim())), `a leaderboard row has no ${label}`);
  }

  const ratings = elos.map((text) => Number(text.trim().split(" ")[0]?.replace("+", "").replace("−", "-")));

  console.log("round elo cells", elos.length, "of", rows, "rows, first", elos.slice(0, 4).join(" | "));
  expectThat(elos.length === rows && ratings.every(Number.isFinite), "a leaderboard row shows no Round Elo");
  expectThat(ratings.every((rating, index) => index === 0 || rating <= (ratings[index - 1] ?? rating)), "the leaderboard is not best Round Elo first");

  const totals = await page.locator("table.heat td.total").allInnerTexts();

  expectThat(totals.length > 0 && totals.every((text) => text.trim() !== "" && text.trim() !== "–"), "a heatmap row shows no Round Elo");
};

const openBreakdown = async (page: Page) => {
  if ((await heat(page).getAttribute("open")) === null) await heat(page).locator("summary").click();

  await settled(page);
};

const servedDecisions = async (id: string) => Schema.decodeUnknownSync(MatchDetail)(await (await fetch(`${base}/api/match?id=${encodeURIComponent(id)}`)).json()).decisions;

const openedMatchId = async (page: Page) => {
  await page.waitForSelector(".modal .step");

  const matchId = await page.locator(".modal .mhead").getAttribute("data-match");

  if (matchId === null) throw new Error("the replay's header names no match");

  return matchId;
};

const openReplay = async (page: Page, open: () => Promise<void>) => {
  await open();

  const matchId = await openedMatchId(page);

  return { matchId, ...(await coverageOfMatch(matchId, servedDecisions)) };
};

const closeReplay = async (page: Page) => {
  await page.keyboard.press("Escape");
  await page.waitForSelector(".modal", { state: "detached" });
};

const expectRegretShown = async (page: Page, coverage: RegretCoverage, what: string) => {
  const shown = { tagged: await regretTags(page).count(), rings: await countOf(page, ".modal .chart circle"), turning: await countOf(page, ".modal .turning .chip") };

  expectThat(shown.tagged === coverage.tagged && shown.rings === coverage.rings && shown.turning === coverage.turning, `${what}: replay shows ${JSON.stringify(shown)}, its data has ${JSON.stringify({ tagged: coverage.tagged, rings: coverage.rings, turning: coverage.turning })}`);
};

const FixtureSeats = Schema.Array(Schema.Struct({ matchId: Schema.String, model: Schema.String, effort: Schema.String, status: Schema.String }));

interface RegretFixture {
  readonly matchId: string;
  readonly model: string;
  readonly effort: string;
}

const regretFixtures = async (count: number): Promise<ReadonlyArray<RegretFixture>> => {
  const seats = Schema.decodeUnknownSync(FixtureSeats)(await (await fetch(`${base}/api/seats`)).json());
  const blunders = Schema.decodeUnknownSync(Blunders)(await (await fetch(`${base}/api/blunders`)).json());
  const costliest = blunders.seat.map((_seat, at) => at).toSorted((left, right) => (blunders.exact[right] ?? 0) - (blunders.exact[left] ?? 0) || (blunders.points[right] ?? 0) - (blunders.points[left] ?? 0));
  const picked = new Map<string, RegretFixture>();

  for (const at of costliest) {
    const seat = seats[blunders.seat[at] ?? -1];

    if (seat !== undefined && seat.status === "completed" && !picked.has(seat.matchId) && picked.size < count) picked.set(seat.matchId, seat);
  }

  return [...picked.values()];
};

const openFromLeaderboard = async (page: Page, { matchId, model, effort }: RegretFixture) => {
  const row = page.locator("table.lbt tr.row", { hasText: `${baseName(model)} [${effort}]` }).first();

  if ((await row.getAttribute("aria-expanded")) !== "true") await row.click();

  await page.locator(`#${anchorId("sq", matchId)}`).click();
};

const coveredMatchIds: Array<string> = [];

const REGRET_TAG = /^−\d+\.\d$/;

const regretTags = (page: Page) => page.locator(".modal .step .tag.regret");

// With a regret database every leaderboard row shows its mean regret, or a dash when none of its moves were searched, and
// the replay's move list tags each searched model move that gave up a real share of the win chance: a proven exact one
// apart from the rest, and the chosen move's folded evaluator line says which it is. Without one the page shows no regret.
const checkRegret = async (page: Page) => {
  const hasRegret = (await page.locator("table.lbt thead th", { hasText: /^Regret$/ }).count()) > 0;
  const cells = page.locator('table.lbt td[data-label="regret"]');

  if (!hasRegret) {
    expectThat((await cells.count()) === 0, "a viewer without regret shows a regret cell");
    console.log("no regret database: no regret column");

    return;
  }

  const texts = await cells.allInnerTexts();
  const rows = await countOf(page, "table.lbt tbody tr.row");

  console.log("regret cells", texts.length, "of", rows, "rows, first", texts.slice(0, 6).join(" "), "| title", await cells.first().getAttribute("title"));
  const scored = texts.filter((text) => text.trim() !== "–");

  expectThat(texts.length === rows && scored.length > 0 && scored.every((text) => /^\d+\.\d$/.test(text.trim())), "a leaderboard row has neither a mean regret nor a dash");

  const titles = await page.locator('table.lbt td[data-label="regret"][title]:not([title=""])').evaluateAll((titled) => titled.map((cell) => cell.getAttribute("title") ?? ""));

  expectThat(titles.length === scored.length && titles.every((title) => /^[\d,]+ moves · \d+% proven exact$/.test(title)), "a regret cell does not say how many moves and how many are proven exact");

  await page.locator(".lb").first().screenshot({ path: shot("leaderboard-regret"), style: UNSTICK });

  for (const row of [0, 1, 2, 3, 4]) {
    const coverage = await openReplay(page, () => page.locator("#matches tbody tr.row").nth(row).click());

    await expectRegretShown(page, coverage, `match ${row}`);
    console.log("match", row, "searched moves", coverage.searched, "tags", coverage.tagged);
    await closeReplay(page);
  }

  const fixtures = await regretFixtures(5);
  let exact = 0;
  let notExact = 0;

  expectThat(fixtures.length > 0, "no regret blunder to open a regret-covered replay from");

  for (const [card, fixture] of fixtures.entries()) {
    const coverage = await openReplay(page, () => openFromLeaderboard(page, fixture));

    coveredMatchIds.push(coverage.matchId);
    expectThat(coverage.matchId === fixture.matchId, `blunder match ${card}: the leaderboard opened ${coverage.matchId}, not ${fixture.matchId}`);
    expectThat(coverage.searched > 0 && coverage.tagged > 0 && coverage.turning > 0, `blunder match ${card}: its replay has ${coverage.searched} searched, ${coverage.tagged} tagged, ${coverage.turning} turning`);
    await expectRegretShown(page, coverage, `blunder match ${card}`);

    const tags = await regretTags(page).evaluateAll((found) => found.map((tag) => ({ text: tag.textContent ?? "", isExact: tag.classList.contains("exact") })));

    expectThat(tags.every(({ text }) => REGRET_TAG.test(text.trim())), `blunder match ${card}: regret tags ${tags.slice(0, 3).map(({ text }) => text).join(" | ")}`);
    exact += tags.filter(({ isExact }) => isExact).length;
    notExact += tags.filter(({ isExact }) => !isExact).length;

    for (const kind of ["exact", "not exact"] as const) {
      const step = page.locator(".modal .step").filter({ has: kind === "exact" ? page.locator(".tag.regret.exact") : page.locator(".tag.regret:not(.exact)") }).first();

      if ((await step.count()) === 0) continue;

      await step.click();
      await settled(page);

      const detail = ((await page.locator(".modal .sel").textContent()) ?? "").replaceAll(/\s+/g, " ");
      const says = /not proven exact/.test(detail) ? "not exact" : /proven exact/.test(detail) ? "exact" : "neither";

      expectThat(/Best move .+ chosen [\d.]+% · depth \d/.test(detail) && says === kind, `blunder match ${card}: a ${kind} move's detail says ${says}: ${detail.slice(0, 120)}`);

      if (card === 0) await page.locator(".modal").screenshot({ path: shot(`replay-regret-${kind.replace(" ", "-")}`) });
    }

    console.log("blunder match", card, "searched moves", coverage.searched, "tags", coverage.tagged, "turning points", coverage.turning);
    await closeReplay(page);
  }

  console.log("regret tags over the covered replays:", exact, "exact,", notExact, "not proven exact");
  expectThat(exact + notExact > 0, "no covered replay shows a regret tag");
};

const checkMissingRegret = async (browser: Browser, viewport: Viewport) => {
  const [missingId, coveredId] = coveredMatchIds;

  if (missingId === undefined || coveredId === undefined) throw new Error("the regret check found fewer than two regret-covered replays to build the fixture from");

  const page = await newPage(browser, viewport);
  const fixtures = await regretFixtures(5);
  let incomingRegrets = 0;

  const openFixtureOf = async (matchId: string) => {
    const fixture = fixtures.find((candidate) => candidate.matchId === matchId);

    if (fixture === undefined) throw new Error(`no regret blunder opens match ${matchId}`);

    await openFromLeaderboard(page, fixture);
    await openedMatchId(page);
  };

  try {
    page.setDefaultTimeout(ACTION_TIMEOUT_MS);
    watch(page, `${viewport.name} missing regret`);

    await page.route(/\/api\/match\?id=/, async (route) => {
      if (new URL(route.request().url()).searchParams.get("id") !== missingId) return route.fallback();

      const response = await route.fetch();
      const detail = Schema.decodeUnknownSync(MatchDetail)(await response.json());

      incomingRegrets = Math.max(incomingRegrets, detail.decisions.filter(({ regret }) => regret !== null).length);

      return route.fulfill({ response, json: { ...detail, decisions: withoutRegret(detail.decisions) } });
    });
    await loadPage(page);

    await openFixtureOf(missingId);

    const shown = { tagged: await regretTags(page).count(), rings: await countOf(page, ".modal .chart circle"), turning: await countOf(page, ".modal .turning .chip") };
    const detail = (await page.locator(".modal").innerText()).replaceAll(/\s+/g, " ");

    expectThat(incomingRegrets > 0, "the fixture route did not fire on a match that came with regret, so it proves nothing");
    expectThat(shown.tagged === 0 && shown.rings === 0 && shown.turning === 0, `a replay with no regret shows ${JSON.stringify(shown)}`);
    expectThat(!/Gave up \d|Best move .+ chosen/.test(detail), "a replay with no regret still words a regret");
    await page.locator(".modal").screenshot({ path: shot("replay-missing-regret") });
    await closeReplay(page);

    await openFixtureOf(coveredId);
    await expectRegretShown(page, await coverageOfMatch(coveredId, servedDecisions), "the covered replay beside the fixture");

    await clearOverlays(page);
    expectThat((await page.locator(".modal").count()) === 0, "clearing the overlays left the replay open");
    console.log("missing regret fixture: 0 tags, 0 rings, 0 turning points; the covered replay beside it keeps its own");
  } finally {
    await page.context().close();
  }
};

const checkDesktop = async (browser: Browser, viewport: Viewport) => {
  const page = await newPage(browser, viewport);
  const scatter = page.locator("#scatter .card");
  const check = (name: string, run: () => Promise<void>) => attempt(viewport.name, name, run, () => clearOverlays(page));

  page.setDefaultTimeout(ACTION_TIMEOUT_MS);
  watch(page, viewport.name);
  await check("open page", () => openPage(page));
  await check("scatter", async () => {
    console.log("scatter points", await countOf(page, "#scatter svg g[style*=pointer]"), "labels", await countOf(page, "#scatter svg g.ptlabel"), "| toggles:", await textOf(page, "#scatter .ctl"));
    await scatter.screenshot({ path: shot("scatter") });
    await page.locator("#scatter svg g[style*=pointer]").nth(3).hover({ force: true });
    console.log("hover point → tip:", await tipOf(page));
    await page.mouse.move(0, 0);
  });
  await check("scatter axes", async () => {
    for (const [axis, name] of [
      ["Moves", "moves"],
      ["Tokens", "tokens"],
      ["Cost", "cost"],
    ] as const) {
      await scatter.getByRole("button", { name: axis, exact: true }).click();
      await settled(page);
      console.log("axis", name, "|", await textOf(page, "#scatter h2"), "| points", await countOf(page, "#scatter svg g.pt"));
      await scatter.screenshot({ path: shot(`scatter-${name}`) });
    }
  });
  await check("fixed axes", () => checkFixedAxes(page, scatter));
  await check("ratings", () => checkRatings(page));
  await check("regret", () => checkRegret(page));
  await check("missing regret", () => checkMissingRegret(browser, viewport));
  await check("heatmap", async () => {
    await openBreakdown(page);
    console.log("heat rows", await countOf(page, "table.heat tbody tr"), "cols", await countOf(page, "table.heat thead th"), "| first row:", await textOf(page, "table.heat tbody tr"));
    await heat(page).screenshot({ path: shot("heat-opp"), style: UNSTICK });
  });
  await check("interesting and drill", async () => {
    await page.locator(".igrid").screenshot({ path: shot("interesting") });
    console.log("cards", (await page.locator(".icard").allInnerTexts()).map((text) => text.replaceAll(/\s+/g, " ")));
    await page.locator("table.lbt tr.row").first().click();
    await page.locator(".drillin .sq i").first().hover();
    console.log("drill → tip:", await tipOf(page));
    await page.locator(".lb").first().screenshot({ path: shot("leaderboard"), style: UNSTICK });
  });
  await check("replays", async () => {
    for (const [card, name] of [
      [0, "replay"],
      [4, "replay-blunder"],
    ] as const) {
      await page.locator(".icard").nth(card).click();
      await page.waitForSelector(".modal .step");

      for (let step = 0; step < (card === 0 ? 6 : 0); step++) await page.keyboard.press("ArrowRight");

      console.log(name, "steps", await countOf(page, ".modal .step"), "| on:", await textOf(page, ".modal .step.on"), "| reasoning blocks", await countOf(page, ".modal .sel pre"), "| same-seed chips", await countOf(page, ".seedrow .chip"));
      await page.locator(".modal").screenshot({ path: shot(name) });
      await page.keyboard.press("Escape");
    }
  });
  await check("focused move", async () => {
    const coverage = await openReplay(page, () => page.locator(".icard", { hasText: "Known-blank blunder" }).click());

    await page.waitForSelector(".modal .step.on");
    console.log("focused move", await textOf(page, ".modal .step.on"), "| searched moves", coverage.searched);
    await expectRegretShown(page, coverage, "the known-blank blunder's replay");
    await page.locator(".modal details.seeds > summary").click();
    await page.locator(".seedrow .chip").first().click();
    await page.waitForSelector(".modal .step");
    await settled(page);
    console.log("after same-seed chip:", await textOf(page, ".mhead h2"));
    await closeReplay(page);
  });
  await check("turning points", async () => {
    const [fixture] = await regretFixtures(1);

    if (fixture === undefined) throw new Error("no regret blunder to open turning points from");

    const coverage = await openReplay(page, () => openFromLeaderboard(page, fixture));
    const turning = page.locator(".modal .turning .chip");
    const listed = await turning.count();
    const rings = await countOf(page, ".modal .chart circle");

    console.log("turning points", listed, "| blunder rings", rings);
    expectThat(coverage.turning > 0 && listed === coverage.turning && rings === coverage.rings, `the replay of a regret blunder lists ${listed} turning points and ${rings} rings, its data has ${coverage.turning} and ${coverage.rings}`);

    const [, label = "", points = ""] = (await turning.first().innerText()).replaceAll(/\s+/g, " ").split(" · ");

    await turning.first().click();
    await settled(page);

    const opened = await textOf(page, ".modal .step.on");

    console.log("turning point opens", opened);
    expectThat(opened.includes(label) && opened.includes(points), `a turning point "${label} · ${points}" opened "${opened}"`);
    await page.locator(".modal").screenshot({ path: shot("replay-turning-points") });
    await closeReplay(page);
  });
  await check("mark tip by keyboard", async () => {
    const mark = page.locator("#odds svg g[role=button]").first();

    await mark.focus();
    console.log("focus a mark → tip:", await tipOf(page));
    await page.keyboard.press("Enter");
    await mark.blur();

    const pinned = await tipOf(page);

    console.log("Enter pins it, and it stays after the focus leaves → tip:", pinned);
    expectThat(pinned === (await mark.getAttribute("aria-label")), "a mark pinned by Enter left no tip of its own");
    await page.locator(".hero .title").click();
    expectThat((await tipOf(page)) === "none", "a click outside left the pinned tip");
  });
  await check("section counts", async () => console.log("matches", await countOf(page, "#matches tbody tr.row"), "| seats", await countOf(page, "#seats .bignum"), "| item fate rows", await countOf(page, "#items .fate"), "| reliability charts", await countOf(page, "#reliability .chartrow figure")));
  await check("jump menu", () => checkJumps(page, viewport.name, false));
  await check("sticky filters", async () => console.log("the filters stay in view:", await page.evaluate(() => Math.round(document.querySelector(".filters")?.getBoundingClientRect().top ?? -1)), "px from the top at scroll", await page.evaluate(() => Math.round(scrollY))));
  await check("reliability and matches", async () => {
    await page.locator("#breakdown details.tables > summary", { hasText: "Failures as tables" }).click();
    await page.locator("#breakdown tbody td[data-label='failed calls']").first().hover();
    console.log("reliability tip:", await tipOf(page));
    await page.locator("#matches tbody tr.row").first().click();
    await page.waitForSelector(".modal .step");
    console.log("matches → modal", await textOf(page, ".mhead h2"));
    await page.keyboard.press("Escape");
  });
  await check("deep link", async () => {
    await page.goto(`${base}/#reliability`);
    await page.waitForSelector("#reliability .chartrow figure", { timeout: 120_000 });
    await settled(page);
    await settled(page);
    console.log("deep link", await jumpedTo(page, "reliability"));
  });
  await check("tour", () => checkTour(page, viewport.name));
  await page.close();
};

// Steps through the whole tour by keyboard: every step must highlight an element the page draws, inside the page's
// width, and Escape must close it.
const checkTour = async (page: Page, name: string) => {
  await page.locator(".tourstart").click();

  for (const [index, step] of TOUR.entries()) {
    if (index > 0) await page.keyboard.press("ArrowRight");

    await settled(page);

    const drawn = await page.evaluate((focus) => [...document.querySelectorAll(focus)].some((element) => element.getBoundingClientRect().height > 0), step.focus);
    const box = await page.locator(".tour-focus").boundingBox();
    const width = await page.evaluate(() => document.documentElement.clientWidth);

    expectThat(drawn, `${name}: tour step "${step.title}" finds nothing drawn at ${step.focus}`);
    expectThat(box !== null && box.x + box.width <= width + 8, `${name}: tour step "${step.title}" highlights outside the page`);
    await page.screenshot({ path: shot(`${name}-tour-${String(index + 1).padStart(2, "0")}`) });
  }

  await page.keyboard.press("Escape");
  console.log(name, "tour steps", TOUR.length, "| closed by Escape:", (await countOf(page, ".tour-layer")) === 0);
};

const checkTouch = async (browser: Browser, viewport: Viewport) => {
  const { name, width, height } = viewport;
  const page = await newPage(browser, viewport);
  const check = (what: string, run: () => Promise<void>) => attempt(name, what, run, () => clearOverlays(page));
  const stickyModelColumn = () => page.evaluate(() => getComputedStyle(document.querySelector("table.heat td.left") ?? document.body).position);

  page.setDefaultTimeout(ACTION_TIMEOUT_MS);
  watch(page, name);
  await check("open page", () => openPage(page));
  await check("overview", async () => console.log(name, "overflow", await page.evaluate(() => document.documentElement.scrollWidth - innerWidth), "| small targets", await smallTargets(page), "| heat model column", await stickyModelColumn(), "| scatter labels", await countOf(page, "#scatter svg g.ptlabel")));
  await check("first screen and filters", async () => {
    await page.screenshot({ path: shot(`${name}-first-screen`) });

    const tableTop = await page.evaluate(() => document.querySelector("table.lbt")?.getBoundingClientRect().top ?? Number.POSITIVE_INFINITY);

    console.log(name, "the leaderboard starts at", Math.round(tableTop), "px of", height);
    expectThat(tableTop < height * 0.6, `${name}: the leaderboard starts below the first screen's upper 60%`);

    if (width <= 1024) {
      console.log(name, "filters line:", await textOf(page, ".filtersum"), "| chips shown", await page.locator(".filters .chip").first().isVisible());
      await page.locator(".filtersum").tap();
      await settled(page);
      expectThat(await page.locator(".filters .chip").first().isVisible(), `${name}: tapping the filters line does not show the chips`);
      await page.locator(".filters .chip", { hasText: "Opus 5.5" }).tap();
      console.log(name, "filters line after Opus off:", await textOf(page, ".filtersum"));
      await page.locator(".filters .chip", { hasText: "Opus 5.5" }).tap();
      await page.locator(".filtersum").tap();
    }
  });
  await check("mark tap", async () => {
    for (const selector of ["#odds svg g[role=button]", "#items .fate-bar[role=button]", "#seats svg g[role=button]"]) {
      await page.locator(selector).first().scrollIntoViewIfNeeded();
      await page.locator(selector).first().tap({ force: true });

      const tip = await tipOf(page);

      console.log(name, "tap", selector, "→", tip);
      expectThat(tip !== "none" && /\d/.test(tip), `${name}: tapping ${selector} shows no tip with a count`);

      await page.mouse.wheel(0, 120);
      await settled(page);

      const gap = await page.evaluate((mark) => {
        const [anchor, tip] = [document.querySelector(mark)?.getBoundingClientRect(), document.querySelector(".tip")?.getBoundingClientRect()];

        return anchor === undefined || tip === undefined ? Number.NaN : Math.abs(tip.top - (anchor.top + anchor.height / 2));
      }, selector);

      expectThat(gap < 200, `${name}: the tip of ${selector} stayed put while the page scrolled (${gap}px from its mark)`);
      await page.locator(".hero .title").tap();
      expectThat((await tipOf(page)) === "none", `${name}: a tap outside leaves the tip of ${selector}`);
    }
  });
  await check("scatter tap", async () => {
    await page.locator("#scatter svg g[style*=pointer]").nth(3).tap({ force: true });
    console.log(name, "tap point → tip:", await tipOf(page));
    await page.locator("#odds svg g[role=button]").first().tap({ force: true });
    expectThat((await page.locator(".tip").count()) === 1, `${name}: pinning a mark left the scatter's pin up too`);
    await page.locator(".hero .title").tap();
    await page.locator("#scatter svg g[style*=pointer]").nth(3).scrollIntoViewIfNeeded();
    await page.locator("#scatter svg g[style*=pointer]").nth(3).tap({ force: true });
    await page.locator("#scatter .card").screenshot({ path: shot(`${name}-scatter`) });
    await page.locator(".hero .title").tap();
    console.log(name, "tap outside clears the tip:", (await tipOf(page)) === "none");
  });
  await check("heat and leaderboard", async () => {
    await openBreakdown(page);
    await heat(page).locator(".heatscroll").evaluate((element) => element.scrollTo({ left: 200 }));
    await heat(page).screenshot({ path: shot(`${name}-heat`) });
    await page.locator("table.lbt").first().screenshot({ path: shot(`${name}-leaderboard`) });
  });
  await check("replay", async () => {
    await page.locator(".icard").first().tap();
    await page.waitForSelector(".modal .step");

    const box = await page.locator(".modal").boundingBox();
    const before = await textOf(page, ".modal .stepper .k");

    await page.locator(".stepper button", { hasText: "Next" }).tap();
    await page.locator(".stepper button", { hasText: "Next" }).tap();
    await settled(page);
    console.log(name, "replay", `${box?.width}x${box?.height}`, "| stepper", before, "→", await textOf(page, ".modal .stepper .k"), "| on:", await textOf(page, ".modal .step.on"), "| small targets", await smallTargets(page));
    await page.screenshot({ path: shot(`${name}-replay`) });

    const crowded = await page.locator(".modal .step").evaluateAll((headers) => headers.filter((header) => header.scrollWidth > header.clientWidth).length);

    console.log(name, "regret tags", await regretTags(page).count(), "| move rows wider than the list", crowded);
    expectThat(crowded === 0, `${name}: a move row overflows with its regret tag`);
    await page.goBack();
    console.log(name, "back closes replay:", (await countOf(page, ".modal")) === 0);
  });
  await check("jump menu", async () => {
    await checkJumps(page, name, true);
    console.log(name, "overflow after every section", await page.evaluate(() => document.documentElement.scrollWidth - innerWidth), "| small targets", await smallTargets(page));
  });
  await check("scatter axis menu", async () => {
    const chooseAxis = (axis: string, label: string) => (width < 640 ? page.locator("#scatter select").selectOption(axis) : page.locator("#scatter").getByRole("button", { name: label, exact: true }).tap());

    await chooseAxis("tokens", "Tokens");
    await settled(page);
    console.log(name, "tokens axis:", await textOf(page, "#scatter h2"), "| y ticks", await yTicks(page), "| overflow", await page.evaluate(() => document.documentElement.scrollWidth - innerWidth), "| small targets", await smallTargets(page));
    await page.locator("#scatter .card").screenshot({ path: shot(`${name}-scatter-tokens`) });
    await chooseAxis("cost", "Cost");
  });
  await check("tour", () => checkTour(page, name));

  await page.context().close();
};

// An optional section's data failing to load leaves the rest of the page drawn and says, in that section, what failed.
const checkOptionalFailure = async (browser: Browser) => {
  const page = await newPage(browser, VIEWPORTS[0]);
  const asked: Array<string> = [];

  page.on("request", (request) => asked.push(new URL(request.url()).pathname));
  await page.route("**/api/consistency", (route) => route.abort());
  await loadPage(page);
  await settled(page);

  const notes = await page.getByText(/^Could not load the /).allInnerTexts();

  console.log("with consistency failing:", notes, "| leaderboards", await countOf(page, "table.lbt"));
  expectThat(notes.length === 1 && (await page.locator("#items").getByText(/^Could not load/).count()) === 1, "a failed optional endpoint did not leave a note in its own section");
  expectThat(!asked.some((path) => path === "/api/blunders" || path === "/api/mistakes"), "the page still loads the blunders or the regret by shells left");
  await page.context().close();
};

mkdirSync(outdir, { recursive: true });

const browser = await chromium.launch({ executablePath: chrome, args: ["--no-sandbox"] });

for (const viewport of VIEWPORTS) await attempt(viewport.name, "baseline capture", () => captureBaseline(browser, viewport));

for (const viewport of VIEWPORTS) await (viewport.isTouch ? checkTouch(browser, viewport) : checkDesktop(browser, viewport));

await attempt("desktop", "optional data failing", () => checkOptionalFailure(browser));

console.log("failed checks", failures);

console.log("errors", errors, "| negative widths while a screenshot resized the window:", screenshotResizeErrors);

await browser.close();

if (failures.length > 0 || errors.length > 0) process.exitCode = 1;
