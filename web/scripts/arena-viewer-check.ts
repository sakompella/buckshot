import { mkdirSync } from "node:fs";
import { join } from "node:path";

import { Schema } from "effect";
import { type Browser, chromium, type Page } from "playwright-core";

import { Blunders, Consistency, Decisions, ITEMS, MatchDetail, type MoveRegret, NO_GAP, SeatsResponse } from "../src/arena-viewer/api.ts";
import { anchorId } from "../src/arena-viewer/page/charts.ts";
import { baseName, fmtCount, fmtPct, keyOf, labelOf, withPotShares } from "../src/arena-viewer/page/data.ts";
import { GROUPS, MOVED_TARGETS, Section } from "../src/arena-viewer/page/model.ts";
import { pooledRatings } from "../src/arena-viewer/page/ratings.ts";
import { stepsOf } from "../src/arena-viewer/page/replay.ts";
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
  await page.waitForSelector("#matches tbody tr.row", { timeout: 60_000 });
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

    const isAtEnd = scrollY + innerHeight >= document.documentElement.scrollHeight - 1;

    return `${id}: ${Math.round(top - (bar?.getBoundingClientRect().bottom ?? 0))}px below the bar, hash ${location.hash}${isAtEnd ? ", at the page end" : ""}`;
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
  const landed = (text: string) => /: -?[01]px below/.test(text) || (text.endsWith(", at the page end") && Number(/: (-?\d+)px below/.exec(text)?.[1]) >= 0);

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

  for (const [old, target] of MOVED_TARGETS) {
    await page.evaluate((id) => {
      location.hash = id;
    }, old);
    await settled(page);
    await settled(page);

    const jumped = await jumpedTo(page, target);

    expectThat(landed(jumped), `${name}: an old link to #${old} lands at ${jumped}`);
  }

  console.log(name, "every section link, old ones included, landed under the bar");
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

const checkFixedAxes = async (page: Page, scatter: ReturnType<Page["locator"]>) => {
  const filters = page.locator(".filters");

  const steps: ReadonlyArray<readonly [string, () => Promise<void>]> = [
    ["max off", () => filters.getByRole("button", { name: "max", exact: true }).click()],
    ["Opus off", () => filters.getByRole("button", { name: /Opus/ }).click()],
    ["Opus on", () => filters.getByRole("button", { name: /Opus/ }).click()],
  ];

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

      console.log(name, label, "| points", await countOf(page, "#scatter svg g.pt"), "| axes unchanged:", isSame);
      expectThat(isSame, `${name} axes moved after ${label}`);

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

const servedDetail = async (id: string) => Schema.decodeUnknownSync(MatchDetail)(await (await fetch(`${base}/api/match?id=${encodeURIComponent(id)}`)).json());

const servedDecisions = async (id: string) => (await servedDetail(id)).decisions;

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

const expectedCandidates = (regret: MoveRegret) =>
  regret.values
    .toSorted((left, right) => right.score - left.score)
    .map(({ label, score }) => ({ label, pct: `${score.toFixed(1)}%`, isChosen: label === regret.chosen, isBest: score === regret.bestScore }));

const expectedVerdict = (regret: MoveRegret) => {
  if (regret.points === 0) return `Best at depth ${regret.depth}`;

  return regret.exact ? `Proven worse · gave up ${regret.points.toFixed(1)} points` : `Gave up ${regret.points.toFixed(1)} points (estimate)`;
};

const checkCandidates = async (page: Page, matchId: string, what: string): Promise<boolean> => {
  await settled(page);

  const detail = await servedDetail(matchId);
  const at = Number(/move (\d+) of/.exec(await textOf(page, ".modal .stepper .k"))?.[1] ?? Number.NaN) - 1;
  const step = stepsOf(detail)[at];
  const list = page.locator(".modal .sel .cands");

  if (step === undefined) throw new Error(`${what}: the replay shows move ${at + 1}, which ${matchId} does not have`);

  if (step.regret === null) {
    expectThat((await list.count()) === 0, `${what}: move ${at + 1} has no regret but shows a candidate list`);

    return false;
  }

  const wasFolded = (await list.getAttribute("open")) === null;

  if (wasFolded) await list.locator("summary").click();

  await settled(page);

  const shown = await list.locator(".cand").evaluateAll((rows) =>
    rows.map((row) => ({
      label: row.querySelector(".label")?.textContent ?? "",
      pct: row.querySelector(".pct")?.textContent ?? "",
      isChosen: row.classList.contains("chosen"),
      isBest: row.classList.contains("best"),
    })),
  );

  const expected = expectedCandidates(step.regret);
  const lines = (await list.locator(":scope > .k").allInnerTexts()).map((line) => line.trim());
  const reloadInReach = step.live + step.blank <= Math.min(3, step.regret.depth);

  expectThat(JSON.stringify(shown) === JSON.stringify(expected), `${what}: move ${at + 1} lists ${JSON.stringify(shown)}, its data has ${JSON.stringify(expected)}`);
  expectThat((await textOf(page, ".modal .sel .cands > summary")).trim() === expectedVerdict(step.regret), `${what}: move ${at + 1} says "${await textOf(page, ".modal .sel .cands > summary")}", not "${expectedVerdict(step.regret)}"`);
  expectThat(lines[0]?.endsWith(`· depth ${step.regret.depth}${step.regret.limited ? " · budget stopped" : ""}`) === true, `${what}: move ${at + 1} has the depth line "${lines[0]}"`);
  expectThat(lines.length === (reloadInReach ? 2 : 1) && (!reloadInReach || /reload is within reach/.test(lines[1] ?? "")), `${what}: move ${at + 1} has ${lines.length} lines under its list with a reload ${reloadInReach ? "" : "not "}in reach`);
  console.log(what, "move", at + 1, "candidates", shown.length, "|", expectedVerdict(step.regret), step.regret.limited ? "| budget stopped" : "", reloadInReach ? "| reload in reach" : "", wasFolded ? "| was folded" : "| was open");

  return wasFolded;
};

const openBudgetStopped = async (page: Page, matchId: string) => {
  const at = stepsOf(await servedDetail(matchId)).findIndex(({ regret }) => regret?.limited === true);

  if (at === -1) return false;

  await page.locator(".modal .step").nth(at).click();

  return true;
};

const regretSteps = (page: Page, kind: "exact" | "not exact") => page.locator(".modal .step").filter({ has: kind === "exact" ? page.locator(".tag.regret.exact") : page.locator(".tag.regret:not(.exact)") });

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
  let budgetStopped = 0;

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
      const step = regretSteps(page, kind).first();

      if ((await step.count()) === 0) continue;

      await step.click();

      const wasFolded = await checkCandidates(page, coverage.matchId, `blunder match ${card} ${kind}`);

      expectThat(!wasFolded, `blunder match ${card}: the candidate list of a ${kind} move came up folded on the desktop`);

      if (card === 0) await page.locator(".modal").screenshot({ path: shot(`replay-regret-${kind.replace(" ", "-")}`) });
    }

    const best = page.locator(".modal .step").filter({ hasNot: page.locator(".tag") }).first();

    await best.click();
    await checkCandidates(page, coverage.matchId, `blunder match ${card} untagged`);

    if (await openBudgetStopped(page, coverage.matchId)) {
      budgetStopped++;
      await checkCandidates(page, coverage.matchId, `blunder match ${card} budget stopped`);

      if (card === 0) await page.locator(".modal").screenshot({ path: shot("replay-regret-budget-stopped") });
    }

    console.log("blunder match", card, "searched moves", coverage.searched, "tags", coverage.tagged, "turning points", coverage.turning);
    await closeReplay(page);
  }

  console.log("regret tags over the covered replays:", exact, "exact,", notExact, "not proven exact");
  expectThat(exact + notExact > 0, "no covered replay shows a regret tag");
  expectThat(budgetStopped > 0, "no covered replay has a move the node budget stopped");
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
    expectThat(!/Gave up \d|Best at depth|Proven worse/.test(detail), "a replay with no regret still words a regret");
    expectThat((await page.locator(".modal .cands").count()) === 0, "a replay with no regret shows a candidate list");

    for (const step of [0, 1, 2]) {
      await page.locator(".modal .step").nth(step).click();
      expectThat((await countOf(page, ".modal .cands")) === 0, `the missing regret fixture's move ${step + 1} shows a candidate list`);
    }

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


const served = async <A, I>(path: string, schema: Schema.Codec<A, I>): Promise<A> => Schema.decodeUnknownSync(schema)(await (await fetch(`${base}${path}`)).json());

const once = <A>(load: () => Promise<A>) => {
  let loaded: Promise<A> | undefined;

  return () => (loaded ??= load());
};

const servedSeats = once(() => served("/api/seats", SeatsResponse));

const servedPageDecisions = once(() => served("/api/decisions", Decisions));

const servedConsistency = once(() => served("/api/consistency", Schema.Array(Consistency)));

type ServedSeat = Awaited<ReturnType<typeof servedSeats>>[number];

const groupedBy = <A>(items: ReadonlyArray<A>, keyOfItem: (item: A) => string): ReadonlyArray<ReadonlyArray<A>> => {
  const groups = new Map<string, Array<A>>();

  for (const item of items) groups.set(keyOfItem(item), [...(groups.get(keyOfItem(item)) ?? []), item]);

  return [...groups.values()];
};

const sum = (values: ReadonlyArray<number>) => values.reduce((total, value) => total + value, 0);

const matchesOf = (seats: ReadonlyArray<ServedSeat>) => groupedBy(seats, ({ matchId }) => matchId);

const completedPairs = (seats: ReadonlyArray<ServedSeat>) => matchesOf(seats).filter((both) => both.length === 2 && both.every(({ status }) => status === "completed"));

const decidedPairs = (seats: ReadonlyArray<ServedSeat>) =>
  completedPairs(seats).flatMap((both) => {
    const winner = both.find(({ winShare }) => (winShare ?? 0) >= 1);
    const loser = both.find((seat) => seat !== winner);

    return winner === undefined || loser === undefined ? [] : [{ winner, loser }];
  });

const configsOf = (seats: ReadonlyArray<ServedSeat>) => groupedBy(seats, keyOf);

const numberIn = (text: string) => Number(text.replaceAll(",", "").match(/-?\d+(?:\.\d+)?/)?.[0] ?? Number.NaN);

const press = (isTouch: boolean, target: ReturnType<Page["locator"]>) => (isTouch ? target.tap() : target.click());

const MATCH_PRESETS = [
  { label: "Comebacks", note: /^from (\d+) behind$/, minimum: 3 },
  { label: "Upsets", note: /^rated (\d+) lower$/, minimum: 100 },
] as const;

const checkMatchList = async (page: Page, name: string, isTouch: boolean) => {
  const seats = await servedSeats();
  const started = matchesOf(seats).length;
  const decided = decidedPairs(seats);
  const ratings = pooledRatings(withPotShares(seats));
  const ratingOf = (seat: ServedSeat) => ratings.get(keyOf(seat))?.rating ?? 0;

  const expected = [
    decided.filter(({ winner }) => winner.low !== null && winner.low[1] - winner.low[0] >= MATCH_PRESETS[0].minimum).length,
    decided.filter(({ winner, loser }) => ratingOf(loser) - ratingOf(winner) >= MATCH_PRESETS[1].minimum).length,
  ];

  const listed = async () => ({ rows: await countOf(page, "#matches tbody tr.row"), count: numberIn(await textOf(page, "#matches .bar .k")) });
  const first = await listed();
  const section = await textOf(page, "#matches");

  console.log(name, "matches listed", first, "| started", started, "| comebacks", expected[0], "| upsets", expected[1]);
  expectThat(first.rows === 25 && first.count === started, `${name}: the match list starts with ${first.rows} rows of ${first.count}, not 25 of ${started}`);
  expectThat((await page.locator("#matches .more").count()) === 1, `${name}: the match list has no Show more`);
  expectThat((await page.locator(".icard").count()) === 0 && !/Longest match|Most expensive|Known-blank|Interesting matches/.test(section), `${name}: the matches section still shows an interesting-match card`);
  expectThat((await page.locator("#matches .chip").allInnerTexts()).join("|") === "Comebacks|Upsets", `${name}: the match presets are not Comebacks and Upsets`);

  for (const [index, { label, note, minimum }] of MATCH_PRESETS.entries()) {
    const chip = page.locator("#matches .chip", { hasText: label });

    await press(isTouch, chip);
    await settled(page);

    const on = await listed();
    const sizes = (await page.locator("#matches td.res .pm").allInnerTexts()).map((text) => Number(note.exec(text.trim())?.[1]));

    expectThat((await chip.getAttribute("aria-pressed")) === "true", `${name}: the ${label} chip is not pressed after a click`);
    expectThat(on.count === expected[index] && on.rows === Math.min(25, expected[index] ?? 0), `${name}: ${label} lists ${on.rows} rows of ${on.count}, the data has ${expected[index]}`);
    expectThat(sizes.length === on.rows && sizes.every((size) => size >= minimum) && sizes.every((size, at) => at === 0 || size <= (sizes[at - 1] ?? size)), `${name}: ${label} rows are not each at least ${minimum}, the biggest first: ${sizes.slice(0, 8).join(" ")}`);
    await page.locator("#matches").screenshot({ path: shot(`${name}-matches-${label.toLowerCase()}`), style: UNSTICK });
    await press(isTouch, chip);
    await settled(page);
    expectThat((await listed()).count === started && (await chip.getAttribute("aria-pressed")) === "false", `${name}: a second click on ${label} does not bring every match back`);
  }

  const [one] = matchesOf(seats).toSorted((left, right) => (right[0]?.startedAt ?? "").localeCompare(left[0]?.startedAt ?? ""));
  const needle = String(one?.[0]?.seed ?? "");
  const search = page.locator("#matches .bar input");

  await search.fill(needle);
  await settled(page);

  const found = matchesOf(seats).filter((both) => both.some((seat) => String(seat.seed).includes(needle) || labelOf(keyOf(seat)).toLowerCase().includes(needle))).length;

  expectThat((await listed()).count === found, `${name}: searching ${needle} lists ${(await listed()).count} matches, the data has ${found}`);
  await search.fill("");
  await settled(page);

  await page.locator("#matches .more").click();
  await settled(page);
  expectThat((await listed()).rows > 25, `${name}: Show more did not add rows`);
  await press(isTouch, page.locator("#matches .chip", { hasText: "Comebacks" }));
  await press(isTouch, page.locator("#matches .chip", { hasText: "Comebacks" }));
  await settled(page);
  expectThat((await listed()).rows === 25, `${name}: choosing a preset did not bring the list back to 25 rows`);

  if (isTouch) {
    const chips = await page.locator("#matches .chip").evaluateAll((found) => found.map((chip) => chip.getBoundingClientRect().height));

    expectThat(chips.every((height) => height >= 44), `${name}: a match preset is ${chips.join(", ")} px tall`);
  }
};

const GAP_NAMES = ["behind 2+", "behind 1", "level", "ahead 1", "ahead 2+"];

const MIN_GAP_MOVES = 30;

const checkDrill = async (page: Page, name: string, isTouch: boolean) => {
  const row = page.locator("table.lbt tbody tr.row").first();

  await press(isTouch, row);
  await settled(page);

  const [, model = "", effort = ""] = /^(.*) \[(.*)\]$/.exec((await row.locator("td").first().innerText()).replaceAll(/\s+/g, " ").trim()) ?? [];
  const seats = await servedSeats();
  const own = seats.find((seat) => baseName(seat.model) === model && seat.effort === effort);

  if (own === undefined) throw new Error(`${name}: no served seat for the first leaderboard row "${model} [${effort}]"`);

  const key = keyOf(own);
  const mine = seats.filter((seat) => keyOf(seat) === key);
  const pairs = completedPairs(seats).filter((both) => both.some((seat) => keyOf(seat) === key));
  const decisions = await servedPageDecisions();
  const lines = await page.locator(".drillin .dline").allInnerTexts();
  const lineOf = (title: string) => lines.map((line) => line.replaceAll(/\s+/g, " ").trim()).find((line) => line.startsWith(title));
  const tallies = GAP_NAMES.map(() => ({ moves: 0, out: 0 }));

  decisions.seat.forEach((seatIndex, move) => {
    const gap = decisions.gap[move] ?? NO_GAP;
    const seat = seats[seatIndex];
    const tally = tallies[Math.max(-2, Math.min(2, gap)) + 2];

    if (seat === undefined || tally === undefined || gap === NO_GAP || keyOf(seat) !== key) return;

    tally.moves++;
    tally.out += decisions.out[move] ?? 0;
  });

  const gapText = `Output tokens per move by health gap ${tallies.map(({ moves, out }, at) => `${GAP_NAMES[at]} ${moves < MIN_GAP_MOVES ? "–" : fmtCount(out / moves)}`).join(" ")}`;

  expectThat(lineOf("Output tokens per move by health gap") === gapText, `${name}: the health gap line reads "${lineOf("Output tokens per move by health gap")}", the data gives "${gapText}"`);

  const consistency = await servedConsistency();
  const steady = consistency.find((candidate) => keyOf(candidate) === key);
  const steadyLine = lineOf("Same position, same move");

  if (consistency.length === 0) expectThat(steadyLine === undefined, `${name}: a viewer without a knowledge database shows a same-position line`);
  else
    expectThat(
      steady === undefined ? steadyLine === "Same position, same move –" : steadyLine?.includes(`${fmtPct(steady.agree)} [${fmtPct(steady.lo)}, ${fmtPct(steady.hi)}] over ${steady.positions.toLocaleString()} positions`) === true,
      `${name}: the same-position line reads "${steadyLine}"`,
    );

  const opponents = new Set(pairs.flatMap((both) => both.filter((seat) => keyOf(seat) !== key).map(keyOf)));
  const gamesShown = sum((await page.locator(".drillin .opp .ow .pm").allInnerTexts()).map(numberIn));

  expectThat((await countOf(page, ".drillin .opp")) === opponents.size && gamesShown === pairs.length, `${name}: the head-to-head shows ${await countOf(page, ".drillin .opp")} opponents and ${gamesShown} games, the data has ${opponents.size} and ${pairs.length}`);

  const received = [0, 1, 2, 3, 4, 5, 6, 7].map((item) => sum(pairs.flatMap((both) => both.filter((seat) => keyOf(seat) === key).map((seat) => seat.acquired[item] ?? 0))));
  const unused = sum(pairs.flatMap((both) => both.filter((seat) => keyOf(seat) === key).flatMap((seat) => seat.acquired.map((acquired, item) => acquired - (seat.used[item] ?? 0) - (both.find((other) => other !== seat)?.stolen[item] ?? 0)))));
  const barRows = await page.locator(".drillin .fate").evaluateAll((fates) => fates.map((fate) => ({ name: fate.querySelector(".fate-name")?.textContent ?? "", value: fate.querySelector(".fate-val")?.textContent ?? "" })));

  console.log(name, "drill", key, "| opponents", opponents.size, "| item bars", barRows.length, "| all items unused", barRows[0]?.value, "| health gap:", gapText, "| steady:", steadyLine);
  expectThat(barRows[0]?.name === "All items" && barRows[0]?.value === `${Math.round((unused / sum(received)) * 100)}%`, `${name}: the first item bar is ${JSON.stringify(barRows[0])}, the data gives ${Math.round((unused / sum(received)) * 100)}% unused`);
  expectThat(barRows.length === 1 + received.filter((count) => count > 0).length, `${name}: the drill-down has ${barRows.length} item bars for ${received.filter((count) => count > 0).length} items received`);
  expectThat(mine.length > 0 && (await page.locator(".drillin").count()) === 1, `${name}: the first row opened ${await page.locator(".drillin").count()} drill-downs`);
  await page.locator(".lb").first().screenshot({ path: shot(`${name}-drill`), style: UNSTICK });
  await press(isTouch, row);
};

const checkItemUsage = async (page: Page, name: string) => {
  const seats = await servedSeats();
  const decisions = await servedPageDecisions();
  const models = new Set(seats.map(({ model }) => model));
  const shown = await page.locator("#items figure").first().locator(".fate").evaluateAll((fates) => fates.map((fate) => ({ name: fate.querySelector(".fate-name")?.textContent ?? "", value: fate.querySelector(".fate-val")?.textContent ?? "" })));
  const kinds = await countOf(page, "#items figure:nth-child(2) .fate");

  const rates = [...models].map((model) => {
    const available = decisions.seat.flatMap((seatIndex, move) => (seats[seatIndex]?.model === model && (decisions.legalUse[move] ?? 0) !== 0 ? [move] : []));

    return { name: baseName(model), value: `${Math.round((available.filter((move) => (decisions.useItem[move] ?? -1) >= 0).length / available.length) * 100)}%` };
  });

  const text = await textOf(page, "#items");

  console.log(name, "item usage by model", shown.map(({ name: model, value }) => `${model} ${value}`).join(", "), "| by item", kinds);
  expectThat(shown.length === models.size && rates.every((rate) => shown.some((row) => row.name === rate.name && row.value === rate.value)), `${name}: the item usage rows ${JSON.stringify(shown)} differ from the data ${JSON.stringify(rates)}`);
  expectThat(kinds === ITEMS.length, `${name}: the item usage figure by item has ${kinds} rows, not ${ITEMS.length}`);
  expectThat(!/Item fates|By config|Same position, same move/.test(text), `${name}: the item usage section still carries a retired figure`);
};

const checkRunHealth = async (page: Page, name: string) => {
  const seats = await servedSeats();
  const spendKeys = configsOf(seats).flatMap(([seat]) => (seat === undefined ? [] : [seat])).filter((first) => sum(seats.filter((seat) => keyOf(seat) === keyOf(first)).map((seat) => seat.cost ?? 0)) > 0);
  const spendModels = new Set(spendKeys.map(({ model }) => model));
  const health = await textOf(page, "#spend");
  const balance = (await page.locator("#spend .seatline .dv").allInnerTexts()).map((text) => text.replaceAll(/\s+/g, " ").trim());
  const segments = await countOf(page, "#spend .spendbar .seg");
  const labels = await countOf(page, "#spend .spend .legend span");

  console.log(name, "spend segments", segments, "| model labels", labels, "| seat balance", balance);
  expectThat((await countOf(page, "#spend .spendbar")) === 1 && (await countOf(page, "#spend .seatline")) === 1, `${name}: run health lacks the spend bar or the seat balance line`);
  expectThat((await countOf(page, "#spend table")) === 0 && (await countOf(page, "#spend .chartrow")) === 0 && (await countOf(page, "#spend details")) === 0 && !/fail|reminder|fallback|by the hour|extra repl/i.test(health), `${name}: run health still shows a failure figure or a table`);
  expectThat((await countOf(page, "#reliability")) === 0 && (await countOf(page, "#seats")) === 0, `${name}: an old section id is still on the page`);
  expectThat(segments === spendKeys.length && labels === spendModels.size, `${name}: the spend bar has ${segments} segments and ${labels} model labels, the data has ${spendKeys.length} and ${spendModels.size}`);

  const blocks = groupedBy(completedPairs(seats), ([first]) => first?.seedBlock ?? "").filter((block) => block.length === 2);
  const ordered = blocks.flatMap((block) => block.map((both) => both.toSorted((left, right) => left.position - right.position)));
  const firstWon = ordered.map(([first]) => first?.winShare ?? 0);
  const roundOne = decidedPairs(seats).flatMap(({ winner }) => (winner.story?.ok === true ? [winner.story.rounds[0]?.winner === winner.player] : []));
  const expectedBalance = [`position 1 ${(100 * (sum(firstWon) / firstWon.length)).toFixed(1)}%`, `round-1 winner ${((100 * roundOne.filter(Boolean).length) / roundOne.length).toFixed(1)}%`];

  expectThat(balance.length === 3 && balance[0]?.startsWith(expectedBalance[0] ?? "") === true && balance[2]?.startsWith(expectedBalance[1] ?? "") === true && balance.every((item) => /n [\d,]+$/.test(item)), `${name}: the seat balance line ${JSON.stringify(balance)} differs from ${JSON.stringify(expectedBalance)}`);
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
  await check("match list", () => checkMatchList(page, viewport.name, false));
  await check("drill-down", async () => {
    await page.locator("table.lbt tr.row").first().click();
    await page.locator(".drillin .sq i").first().hover();
    console.log("drill → tip:", await tipOf(page));
    await page.locator(".lb").first().screenshot({ path: shot("leaderboard"), style: UNSTICK });
    await page.locator("table.lbt tr.row").first().click();
    await checkDrill(page, viewport.name, false);
  });
  await check("item usage", () => checkItemUsage(page, viewport.name));
  await check("run health", () => checkRunHealth(page, viewport.name));
  await check("replays", async () => {
    for (const [row, name] of [
      [0, "replay"],
      [4, "replay-fifth"],
    ] as const) {
      await page.locator("#matches tbody tr.row").nth(row).click();
      await page.waitForSelector(".modal .step");

      for (let step = 0; step < (row === 0 ? 6 : 0); step++) await page.keyboard.press("ArrowRight");

      console.log(name, "steps", await countOf(page, ".modal .step"), "| on:", await textOf(page, ".modal .step.on"), "| reasoning blocks", await countOf(page, ".modal .sel pre"), "| same-seed chips", await countOf(page, ".seedrow .chip"));
      await page.locator(".modal").screenshot({ path: shot(name) });
      await page.keyboard.press("Escape");
    }
  });
  await check("same-seed link", async () => {
    const seats = await servedSeats();
    const shared = matchesOf(seats).find(([seat]) => matchesOf(seats).filter(([other]) => other?.seed === seat?.seed).length > 1);

    if (shared?.[0] === undefined) throw new Error("no two served matches share a seed");

    await page.locator("#matches .bar input").fill(String(shared[0].seed));
    await settled(page);

    const coverage = await openReplay(page, () => page.locator("#matches tbody tr.row").first().click());

    await page.waitForSelector(".modal .step.on");
    await expectRegretShown(page, coverage, "a listed match's replay");
    await page.locator(".modal details.seeds > summary").click();
    expectThat((await countOf(page, ".seedrow .chip")) > 0, "a replay's same-seed link lists no other match");
    await page.locator(".seedrow .chip").first().click();
    await page.waitForSelector(".modal .step");
    await settled(page);
    expectThat((await openedMatchId(page)) !== coverage.matchId, "the same-seed chip reopened the same match");
    console.log("after same-seed chip:", await textOf(page, ".mhead h2"));
    await closeReplay(page);
    await page.locator("#matches .bar input").fill("");
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
  await check("section counts", async () => console.log("matches", await countOf(page, "#matches tbody tr.row"), "| item usage rows", await countOf(page, "#items .fate"), "| spend segments", await countOf(page, "#spend .spendbar .seg")));
  await check("jump menu", () => checkJumps(page, viewport.name, false));
  await check("sticky filters", async () => console.log("the filters stay in view:", await page.evaluate(() => Math.round(document.querySelector(".filters")?.getBoundingClientRect().top ?? -1)), "px from the top at scroll", await page.evaluate(() => Math.round(scrollY))));
  await check("matches", async () => {
    await page.locator("#matches tbody tr.row").first().click();
    await page.waitForSelector(".modal .step");
    console.log("matches → modal", await textOf(page, ".mhead h2"));
    await page.keyboard.press("Escape");
  });
  await check("deep link", async () => {
    await page.goto(`${base}/#reliability`);
    await page.waitForSelector("#spend .spendbar", { timeout: 120_000 });
    await settled(page);
    await settled(page);
    console.log("deep link", await jumpedTo(page, "spend"));
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
    for (const selector of ["#odds svg g[role=button]", "#items .fate-bar[role=button]", "#spend .spendbar .seg[role=button]"]) {
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

    if (width < 640) {
      const tallest = await page.locator("table.lbt tbody tr.row").evaluateAll((rows) => Math.max(...rows.map((row) => row.getBoundingClientRect().height)));
      const row = page.locator("table.lbt tbody tr.row").first();

      await row.tap();
      await settled(page);

      const details = await page.locator("table.lbt .drillstats dt").allInnerTexts();

      console.log(name, "tallest leaderboard row", Math.round(tallest), "px | drill-down details", details.join(", "));
      expectThat(tallest <= 80, `${name}: a leaderboard row is ${Math.round(tallest)}px tall`);
      expectThat(["match wins", "round wins", "cash share", "per move", "time", "out tok", "fav"].every((label) => details.includes(label)), `${name}: the drill-down lacks a leaderboard detail: ${details.join(", ")}`);
      await page.locator("table.lbt").first().screenshot({ path: shot(`${name}-leaderboard-open`) });
      await row.tap();
    }
  });
  await check("match list", () => checkMatchList(page, name, true));
  await check("drill-down", () => checkDrill(page, name, true));
  await check("item usage", () => checkItemUsage(page, name));
  await check("run health", () => checkRunHealth(page, name));
  await check("replay", async () => {
    await page.locator("#matches tbody tr.row").first().tap();
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
  await check("candidate list", async () => {
    const [fixture] = await regretFixtures(1);

    if (fixture === undefined) throw new Error("no regret blunder to open a candidate list from");

    await openFromLeaderboard(page, fixture);

    const matchId = await openedMatchId(page);

    if (!(await openBudgetStopped(page, matchId))) throw new Error(`${name}: ${matchId} has no move the node budget stopped`);

    const wasFolded = await checkCandidates(page, matchId, `${name} candidates`);
    const summary = await page.locator(".modal .sel .cands > summary").boundingBox();
    const overflow = await page.evaluate(() => Math.max(document.documentElement.scrollWidth - innerWidth, ...[...document.querySelectorAll(".modal, .modal .cands")].map((element) => element.scrollWidth - element.clientWidth)));

    expectThat(wasFolded === width < 640, `${name}: the candidate list came up ${wasFolded ? "folded" : "open"}`);
    expectThat(summary !== null && summary.height >= 44, `${name}: the candidate list's summary is ${summary?.height ?? 0}px tall`);
    expectThat(overflow <= 0, `${name}: the replay with its candidate list overflows by ${overflow}px`);
    await page.locator(".modal .sel").screenshot({ path: shot(`${name}-candidates`) });
    await closeReplay(page);
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

  expectThat((await page.getByText(/^Could not load the /).count()) === 0, "a failed optional endpoint left a note before any row was open");
  await page.locator("table.lbt tr.row").first().click();
  await settled(page);

  const notes = await page.getByText(/^Could not load the /).allInnerTexts();

  console.log("with consistency failing:", notes, "| leaderboards", await countOf(page, "table.lbt"));
  expectThat(notes.length === 1 && (await page.locator(".drillin").getByText(/^Could not load the consistency/).count()) === 1, "a failed optional endpoint did not leave a note in the drill-down that reads it");
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
