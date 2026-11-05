import { mkdirSync } from "node:fs";
import { join } from "node:path";

import { Schema } from "effect";
import { type Browser, chromium, type Page } from "playwright-core";

import { AGGREGATES, selfShotTallies } from "../src/arena-viewer/aggregates.ts";
import { Blunders, CERTAIN_TYPES, CertainMistakes, Decisions, ITEMS, MatchDetail, MatchDetailJson, type MoveRegret, NO_GAP, SeatsResponse } from "../src/arena-viewer/api.ts";
import { baseName, baseOrder, CERTAIN_NAMES, effortLabel, fmtBytes, fmtCount, fmtPct, fmtPoints, blocksOf, groupBy, keyOf, labelOf, MIN_BLOCKS_FOR_INTERVAL, shortName, withPotShares } from "../src/arena-viewer/page/data.ts";
import { GROUPS, MOVED_TARGETS, Section } from "../src/arena-viewer/page/model.ts";
import { pooledRatings } from "../src/arena-viewer/page/ratings.ts";
import { droppedConfigs, droppedText, oddsPanels } from "../src/arena-viewer/page/odds.ts";
import { stepsOf } from "../src/arena-viewer/page/replay.ts";
import { tourOf } from "../src/arena-viewer/page/tour.ts";
import { coverageOfMatch, type RegretCoverage, withoutRegret } from "./arena-viewer-regret-coverage.ts";

// Clicks through the arena viewer's page, its jump menu and replay in headless Chromium at
// desktop, phone and tablet widths and saves screenshots. Pointed at the old viewer too,
// it gives the pictures to compare against.
// Usage: bun scripts/arena-viewer-check.ts <url> [outdir]

const base = (process.argv[2] ?? "http://127.0.0.1:8790").replace(/\/+$/, "");
const outdir = process.argv[3] ?? "/tmp/arena-viewer-shots";
const chrome = process.env["CHROME"] ?? "/etc/profiles/per-user/aditya/bin/chromium";
const servedCertain = Schema.decodeUnknownSync(CertainMistakes)(await (await fetch(`${base}/api/certain-mistakes`)).json());

const hasCertain = servedCertain.rates.length > 0;

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

/** A group's data loads as it nears the screen, so passing the page's end brings in everything below the first paint. */
const showMatches = async (page: Page) => {
  await page.waitForSelector("section.part", { timeout: 120_000 });
  await page.evaluate(() => scrollTo(0, document.documentElement.scrollHeight));
  await page.waitForSelector("#matches tbody tr.row", { timeout: 60_000 });
};

const loadPage = async (page: Page) => {
  await page.goto(`${base}/arena`);
  await page.waitForSelector("table.lbt", { state: "attached", timeout: 120_000 });
  await showMatches(page);
  await page.evaluate(() => scrollTo(0, 0));
  await page.waitForLoadState("networkidle");
};

const tablesFold = (page: Page) => page.locator("#tables details");

const openTables = async (page: Page) => {
  await page.locator("#tables details > summary").click();
  await settled(page);
};

const openPage = async (page: Page) => {
  const started = Date.now();

  await loadPage(page);
  console.log("every section drawn in", Date.now() - started, "ms");
  expectThat((await tablesFold(page).getAttribute("open")) === null, "the tables fold is open on first load");
  await openTables(page);
  console.log("default:", "scatter points", await countOf(page, "#scatter svg g.pt"), "heat rows", await countOf(page, "table.heat tbody tr"), "leaderboard rows", await countOf(page, "table.lbt tbody tr.row"));
  expectThat((await page.getByRole("switch").count()) === 0, "the page still has a switch");
};

// Visible controls smaller than 44px either way (heat cells are left out).
const smallTargets = (page: Page) =>
  page.evaluate(() =>
    [...document.querySelectorAll("nav a, .toggle button, .chip, .cmb, .tablelink, select, input:not([type=checkbox]), .stepper button, .modal .x, .tourstart, .drillclose, .foot .download")].flatMap((element) => {
      const box = element.getBoundingClientRect();

      return box.width > 0 && (box.height < 44 || box.width < 44) ? [`${element.className || element.tagName} ${element.textContent?.slice(0, 20)} ${Math.round(box.width)}x${Math.round(box.height)}`] : [];
    }),
  );

const SECTIONS = Section.literals.filter((section) => hasCertain || section !== "certain-mistakes");

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
  console.log(name, "page height", await page.evaluate(() => document.documentElement.scrollHeight), "| scatter starts at", await page.evaluate(() => Math.round((document.querySelector("#scatter .card")?.getBoundingClientRect().top ?? Number.NaN) + scrollY)));
  await page.screenshot({ path: shot(`${name}-page`), fullPage: true });

  const order = await page.evaluate(() => [...document.querySelectorAll("section.part")].map((part) => part.id).join(" "));

  expectThat(order === GROUPS.map(({ group }) => group).join(" "), `${name}: the page's groups run ${order}`);
  expectThat((await page.locator("#scatter .card").evaluate((card) => card.getBoundingClientRect().top)) < (await page.locator("#breakdown").evaluate((fold) => fold.getBoundingClientRect().top)), `${name}: the scatter does not come before the win-share matrix`);
  await openTables(page);

  for (const { group, sections } of GROUPS) {
    for (const section of sections.filter((candidate) => SECTIONS.includes(candidate))) {
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
  const groupOf = (target: string) => GROUPS.find(({ group, sections }) => group === target || sections.some((section) => section === target));

  const fromTop = (hash: string) =>
    page.evaluate((id) => {
      scrollTo(0, 0);
      history.replaceState(null, "", location.pathname + location.search);
      location.hash = id;
    }, hash);

  const markedGroup = async (target: string, label: string) => {
    const group = groupOf(target);
    const marked = await textOf(page, "nav a.on").catch(() => "none");

    expectThat(group !== undefined && marked.trim() === group.label, `${name}: ${label} lands in ${group?.label}, but the menu marks ${marked}`);
  };

  for (const { group } of GROUPS) {
    const link = page.locator(`nav a[href="#${group}"]`);

    if ((await link.count()) === 0) {
      failures.push(`${name}: the jump menu has no link to #${group}`);
      continue;
    }

    await page.evaluate(() => scrollTo(0, 0));
    await settled(page);
    await (isTouch ? link.tap() : link.click());
    await settled(page);

    const jumped = await jumpedTo(page, group);

    console.log(name, "jump", jumped, "| menu marks", await textOf(page, "nav a.on").catch(() => "none"));
    expectThat(landed(jumped), `${name}: the ${group} link lands at ${jumped}`);
    await markedGroup(group, `the ${group} link`);
  }

  for (const section of SECTIONS) {
    await fromTop(section);
    await settled(page);
    await settled(page);

    const jumped = await jumpedTo(page, section);

    expectThat(landed(jumped), `${name}: a link to #${section} lands at ${jumped}`);
    await markedGroup(section, `a link to #${section}`);
  }

  for (const [old, target] of MOVED_TARGETS) {
    await fromTop(old);
    await settled(page);
    await settled(page);

    const jumped = await jumpedTo(page, target);

    expectThat(landed(jumped), `${name}: an old link to #${old} lands at ${jumped}`);
    await markedGroup(target, `an old link to #${old}`);
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

  for (const label of ["wins vs own opponents", "round wins", "cash share"]) {
    const shares = await cells(label);

    console.log(label, "cells", shares.length, "of", rows, "rows, first", shares.slice(0, 4).join(" | "));
    expectThat(shares.length === rows && shares.every((text) => /^\d+%/.test(text.trim())), `a leaderboard row has no ${label}`);
  }

  const ratings = elos.map((text) => Number(text.trim().split(" ")[0]?.replace("+", "").replace("−", "-")));

  console.log("round elo cells", elos.length, "of", rows, "rows, first", elos.slice(0, 4).join(" | "));
  expectThat(elos.length === rows && ratings.every(Number.isFinite), "a leaderboard row shows no Round Elo");

  const listed = await page.locator("table.lbt tbody tr.row").evaluateAll((trs) =>
    trs.map((tr) => ({
      name: (tr.querySelector("td")?.textContent ?? "").replace(/^\d+/, ""),
      rank: Number(tr.querySelector(".rk")?.textContent || Number.NaN),
      isProvisional: tr.classList.contains("provisional"),
      hasEloInterval: tr.querySelector('td[data-label="round elo"] .pm') !== null,
    })),
  );

  const seats = (await servedSeats()).filter(({ status }) => status === "completed");
  const played = configsOf(seats).flatMap(([first, ...rest]) => (first === undefined ? [] : [[`${baseName(first.model)} [${effortLabel(first.model, first.effort)}]`, [first, ...rest]] as const]));
  const playedBy = (name: string) => played.flatMap(([label, configSeats]) => (label === name.trim() ? configSeats : []));
  const provisionalRows = listed.filter(({ isProvisional }) => isProvisional);
  const rankedRows = listed.filter(({ isProvisional }) => !isProvisional);

  console.log("leaderboard ranked", rankedRows.length, "| provisional", provisionalRows.length, "| rows with an Elo interval", listed.filter(({ hasEloInterval }) => hasEloInterval).length);
  expectThat(listed.every(({ name, isProvisional }) => isProvisional === (playedBy(name).length < 20)), "a leaderboard row is provisional other than at under 20 completed matches");
  expectThat(rankedRows.every(({ rank }, index) => rank === index + 1) && provisionalRows.every(({ rank }) => Number.isNaN(rank)), "ranked rows are not numbered 1, 2, 3 in order, or a provisional row has a rank");
  expectThat(listed.slice(0, rankedRows.length).every(({ isProvisional }) => !isProvisional), "a provisional row sits among the ranked rows");

  const rankedElos = ratings.slice(0, rankedRows.length);

  expectThat(rankedElos.every((rating, index) => index === 0 || rating <= (rankedElos[index - 1] ?? rating)), "the ranked rows are not best Round Elo first");
  expectThat(listed.every(({ name, hasEloInterval }) => !hasEloInterval || blocksOf(playedBy(name)) >= 4), "a config over fewer than 4 seed blocks shows a Round Elo interval");
  expectThat(listed.some(({ hasEloInterval }) => hasEloInterval), "no leaderboard row shows a Round Elo interval");

  const bars = await page.locator("table.lbt tbody tr.row").evaluateAll((trs) =>
    trs.map((tr) => {
      const box = (selector: string) => tr.querySelector(selector)?.getBoundingClientRect() ?? null;
      const [track, fill, zero, whisk] = [box(".track"), box(".track .fill"), box(".track .zero"), box(".track .whisk")];

      return track === null || fill === null || zero === null ? null : { end: Math.abs(fill.left - zero.left) > Math.abs(fill.right - zero.left) ? fill.left : fill.right, zero: zero.left, whisk: whisk === null ? null : { left: whisk.left, right: whisk.right } };
    }),
  );

  const drawn = bars.flatMap((bar, index) => (bar === null ? [] : [{ ...bar, rating: ratings[index] ?? Number.NaN, hasInterval: listed[index]?.hasEloInterval === true }]));
  const byRating = drawn.toSorted((left, right) => right.rating - left.rating);

  console.log("round elo bars", drawn.length, "of", rows, "rows | whiskers", drawn.filter(({ whisk }) => whisk !== null).length);
  expectThat(drawn.length === rows, `${drawn.length} of ${rows} leaderboard rows draw a Round Elo bar`);
  expectThat(drawn.every(({ end, zero, rating }) => Math.sign(Math.round(end - zero)) === Math.sign(Math.round(rating)) || Math.abs(end - zero) < 1.5), "a Round Elo bar runs the wrong side of zero");
  expectThat(byRating.every(({ end }, index) => index === 0 || end <= (byRating[index - 1]?.end ?? end) + 0.5), "the Round Elo bars do not grow with Round Elo");
  expectThat(drawn.every(({ whisk, hasInterval, end }) => (whisk !== null) === hasInterval && (whisk === null || (whisk.left - 1.5 <= end && end <= whisk.right + 1.5))), "a Round Elo interval is missing, drawn without its numbers, or does not hold its bar's end");

  const faded = await page.locator("#scatter g.pt").evaluateAll((points) => points.filter((point) => point instanceof SVGElement && point.style.opacity === "0.4").length);

  console.log("scatter faded points", faded);
  expectThat(faded === provisionalRows.length, `the scatter fades ${faded} points, the leaderboard has ${provisionalRows.length} provisional rows`);

  const totals = await page.locator("table.heat td.total").allInnerTexts();

  expectThat(totals.length > 0 && totals.every((text) => text.trim() !== "" && text.trim() !== "–"), "a heatmap row shows no Round Elo");
};

const checkHeat = async (page: Page, name: string) => {
  await openBreakdown(page);

  const seats = await servedSeats();
  const columns = (await page.locator("table.heat thead th").allInnerTexts()).map((text) => text.trim()).slice(1, -2);
  const models = [...new Set(seats.map(({ model }) => model))].toSorted((left, right) => baseOrder(left) - baseOrder(right));

  const cells = await page.locator("table.heat td.cellv:not(.none)").evaluateAll((tds) =>
    tds.map((td) => ({
      share: Number.parseFloat(td.firstChild?.textContent ?? "") / 100,
      n: Number((td.querySelector(".n")?.textContent ?? "").replaceAll(",", "")),
      level: Number(/rgb\((\d+)/.exec(getComputedStyle(td).backgroundColor)?.[1]),
      tip: td.getAttribute("data-tip") ?? "",
    })),
  );

  const expectedLevel = ({ share, n }: { share: number; n: number }) => Math.round(16 + (38 + share * 194 - 16) * Math.min(1, n / 10));

  console.log(name, "heat columns", columns.join(" | "), "| cells", cells.length);
  expectThat(JSON.stringify(columns) === JSON.stringify(models.map(shortName)) && new Set(columns).size === columns.length, `${name}: the heatmap columns read ${columns.join(", ")}, the short names are ${models.map(shortName).join(", ")}`);
  expectThat(cells.length > 0 && cells.every((cell) => Math.abs(cell.level - expectedLevel(cell)) <= 2), `${name}: a heat cell is not shaded by its win share and matches`);
  expectThat(cells.some((cell) => cell.n < 10) && cells.some((cell) => cell.n >= 10), `${name}: the heatmap has no cell on each side of full strength`);
  expectThat(cells.every(({ tip, n }) => tip.includes(`of ${n} matches`) && tip.includes("Full strength from 10 matches")), `${name}: a heat cell's tooltip does not say what n gives full strength`);
  expectThat(!(await textOf(page, "#breakdown")).includes("ull strength"), `${name}: the page explains full strength outside the cell tooltips`);
};

const openBreakdown = async (page: Page) => {
  if ((await heat(page).getAttribute("open")) === null) await heat(page).locator("summary").click();

  await settled(page);
};

const servedDetail = async (id: string) => Schema.decodeUnknownSync(MatchDetailJson)(await (await fetch(`${base}/api/match?id=${encodeURIComponent(id)}`)).json());

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
  if (regret.points === 0) return `Best move, looking ${regret.depth} moves ahead`;

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
  expectThat(lines[0]?.endsWith(`· looking ${step.regret.depth} moves ahead${step.regret.limited ? " · stopped early" : ""}`) === true, `${what}: move ${at + 1} has the depth line "${lines[0]}"`);
  expectThat(lines.length === (reloadInReach ? 2 : 1) && (!reloadInReach || /reload is within reach/.test(lines[1] ?? "")) && !/static leaf|budget|depth/i.test(lines.join(" ")), `${what}: move ${at + 1} has ${lines.length} lines under its list with a reload ${reloadInReach ? "" : "not "}in reach`);
  console.log(what, "move", at + 1, "candidates", shown.length, "|", expectedVerdict(step.regret), step.regret.limited ? "| stopped early" : "", reloadInReach ? "| reload in reach" : "", wasFolded ? "| was folded" : "| was open");

  return wasFolded;
};

const openBudgetStopped = async (page: Page, matchId: string) => {
  const at = stepsOf(await servedDetail(matchId)).findIndex(({ regret }) => regret?.limited === true);

  if (at === -1) return false;

  await page.locator(".modal .step").nth(at).click();

  return true;
};

const regretSteps = (page: Page, kind: "exact" | "not exact") => page.locator(".modal .step").filter({ has: kind === "exact" ? page.locator(".tag.regret.exact") : page.locator(".tag.regret:not(.exact)") });

const FixtureSeats = Schema.Array(Schema.Struct({ matchId: Schema.String, seed: Schema.Number, startedAt: Schema.String, model: Schema.String, effort: Schema.String, status: Schema.String }));

interface RegretFixture {
  readonly matchId: string;
  readonly seed: number;
  readonly listQuery: string;
  readonly listRow: number;
  readonly model: string;
  readonly effort: string;
}

type FixtureSeat = typeof FixtureSeats.Type[number];

const labelsOf = (both: ReadonlyArray<FixtureSeat>) => both.map((seat) => labelOf(keyOf(seat))).toSorted();

const listQueryOf = (seed: number, both: ReadonlyArray<FixtureSeat>) => [String(seed), ...labelsOf(both)].join(" ");

const listRowOf = (matches: ReadonlyArray<ReadonlyArray<FixtureSeat>>, target: ReadonlyArray<FixtureSeat>) => {
  const words = listQueryOf(target[0]?.seed ?? 0, target).toLowerCase().split(" ");

  const listed = matches.filter(
    (both) => both[0]?.seed === target[0]?.seed && words.every((word) => [...labelsOf(both), String(both[0]?.seed)].some((text) => text.toLowerCase().includes(word))),
  );

  return listed.toSorted((left, right) => (right[0]?.startedAt ?? "").localeCompare(left[0]?.startedAt ?? "")).findIndex((both) => both[0]?.matchId === target[0]?.matchId);
};

const listOf = (seats: ReadonlyArray<FixtureSeat>, seat: FixtureSeat) => {
  const matches = [...groupBy(seats, ({ matchId }) => matchId).values()];
  const both = matches.find(([first]) => first?.matchId === seat.matchId) ?? [];

  return { listQuery: listQueryOf(seat.seed, both), listRow: listRowOf(matches, both) };
};

const regretFixtures = async (count: number): Promise<ReadonlyArray<RegretFixture>> => {
  const seats = Schema.decodeUnknownSync(FixtureSeats)(await (await fetch(`${base}/api/seats`)).json());
  const blunders = Schema.decodeUnknownSync(Blunders)(await (await fetch(`${base}/api/blunders`)).json());
  const costliest = blunders.seat.map((_seat, at) => at).toSorted((left, right) => (blunders.exact[right] ?? 0) - (blunders.exact[left] ?? 0) || (blunders.points[right] ?? 0) - (blunders.points[left] ?? 0));
  const picked = new Map<string, RegretFixture>();

  for (const at of costliest) {
    const seat = seats[blunders.seat[at] ?? -1];

    if (seat !== undefined && seat.status === "completed" && !picked.has(seat.matchId) && picked.size < count) picked.set(seat.matchId, { ...seat, ...listOf(seats, seat) });
  }

  return [...picked.values()];
};

const openFromMatchList = async (page: Page, fixture: RegretFixture) => {
  const filter = page.locator("#matches .bar input");

  await filter.fill(fixture.listQuery);
  await page.locator("#matches tbody tr.row").filter({ has: page.locator('td[data-label="seed"]', { hasText: new RegExp(`^${fixture.seed}$`) }) }).nth(fixture.listRow).click();
  await filter.fill("");
};

const coveredMatchIds: Array<string> = [];

const REGRET_TAG = /^−\d+\.\d$/;

const SHOT_FIXTURE = "0b1ca8ab272b8e3c56bd1d0bfbd552aadfa430ef886ee5047eef9f3275b61624";

const checkShotTags = async (page: Page, matchId: string, what: string) => {
  const detail = await servedDetail(matchId);
  const steps = stepsOf(detail);
  const lastId = detail.decisions.at(-1)?.id;
  const shown = await page.locator(".modal .moves .step").evaluateAll((rows) => rows.map((row) => ({ label: row.querySelector(".label")?.textContent ?? "", shot: row.querySelector(".shot")?.textContent ?? "" })));

  const expected = steps.map((step) => {
    const logged = / shot [^:]*: (live|blank)/.exec(step.outcome.join(" "))?.[1];

    return logged ?? (step.label.startsWith("Shoot") && step.id === lastId && detail.match.status === "completed" ? "live" : "");
  });

  expectThat(shown.length === steps.length && shown.every((row, index) => row.shot === expected[index]), `${what}: the move list tags ${shown.filter((row, index) => row.shot !== expected[index]).length} shots other than the log or the final death gives`);
  expectThat(steps.every((step, index) => !step.label.startsWith("Shoot") || expected[index] !== "" || detail.match.status !== "completed"), `${what}: a shot in a completed match has no live or blank tag`);
  console.log(what, "shots tagged", shown.filter((row) => row.shot !== "").length, "of", steps.filter((step) => step.label.startsWith("Shoot")).length);
};

const checkShotFixture = async (page: Page) => {
  await page.locator("#matches .bar input").fill("4006");
  await settled(page);

  for (const row of Array.from({ length: 25 }, (_, index) => index)) {
    if ((await page.locator("#matches tbody tr.row").count()) <= row) break;

    await page.locator("#matches tbody tr.row").nth(row).click();

    const matchId = await openedMatchId(page);

    if (matchId === SHOT_FIXTURE) {
      const steps = stepsOf(await servedDetail(matchId));

      await checkShotTags(page, matchId, "seed 4006");
      expectThat([37, 43].every((at) => steps[at]?.label.startsWith("Shoot") === true), "seed 4006 moves 38 and 44 are no longer shots");
      expectThat((await page.locator(".modal .moves .step").nth(37).locator(".shot").innerText()) === "live" && (await page.locator(".modal .moves .step").nth(43).locator(".shot").innerText()) === "live", "seed 4006 moves 38 and 44 are not tagged live");
      expectThat((steps[37]?.outcome.length ?? 0) > 0 && (steps[43]?.outcome.length ?? 1) === 0, "seed 4006 move 38 has no logged shot, or move 44 has one");
      await closeReplay(page);
      await page.locator("#matches .bar input").fill("");
      await settled(page);

      return;
    }

    await closeReplay(page);
  }

  throw new Error("seed 4006's Opus max match is not in the match list");
};

const regretTags = (page: Page) => page.locator(".modal .step .tag.regret");

// With a regret database every leaderboard row shows its mean regret, or a dash when none of its moves were searched, and
// the replay's move list tags each searched model move that gave up a real share of the win chance: a proven exact one
// apart from the rest, and the chosen move's folded evaluator line says which it is. Without one the page shows no regret.
const checkRegret = async (page: Page) => {
  const hasRegret = (await page.locator("table.lbt thead th", { hasText: /^Accuracy$/ }).count()) > 0;
  const cells = page.locator('table.lbt td[data-label="accuracy"]');

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

  const titles = await page.locator('table.lbt td[data-label="accuracy"][title]:not([title=""])').evaluateAll((titled) => titled.map((cell) => cell.getAttribute("title") ?? ""));

  expectThat(titles.length === scored.length && titles.every((title) => /^[\d,]+ moves · \d+% proven exact$/.test(title)), "a regret cell does not say how many moves and how many are proven exact");

  await page.locator(".lb").first().screenshot({ path: shot("leaderboard-regret"), style: UNSTICK });

  for (const row of [0, 1, 2, 3, 4]) {
    const coverage = await openReplay(page, () => page.locator("#matches tbody tr.row").nth(row).click());

    await expectRegretShown(page, coverage, `match ${row}`);
    await checkShotTags(page, coverage.matchId, `match ${row}`);
    console.log("match", row, "searched moves", coverage.searched, "tags", coverage.tagged);
    await closeReplay(page);
  }

  await checkShotFixture(page);

  const fixtures = await regretFixtures(5);
  let exact = 0;
  let notExact = 0;
  let budgetStopped = 0;

  expectThat(fixtures.length > 0, "no regret blunder to open a regret-covered replay from");

  for (const [card, fixture] of fixtures.entries()) {
    const coverage = await openReplay(page, () => openFromMatchList(page, fixture));

    coveredMatchIds.push(coverage.matchId);
    expectThat(coverage.matchId === fixture.matchId, `blunder match ${card}: the match list opened ${coverage.matchId}, not ${fixture.matchId}`);
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

    await openFromMatchList(page, fixture);
    await openedMatchId(page);
  };

  try {
    page.setDefaultTimeout(ACTION_TIMEOUT_MS);
    watch(page, `${viewport.name} missing regret`);

    await page.route(/\/api\/match\?id=/, async (route) => {
      if (new URL(route.request().url()).searchParams.get("id") !== missingId) return route.fallback();

      const response = await route.fetch();
      const detail = Schema.decodeUnknownSync(MatchDetailJson)(await response.json());

      incomingRegrets = Math.max(incomingRegrets, detail.decisions.filter(({ regret }) => regret !== null).length);

      return route.fulfill({ response, json: { ...detail, decisions: withoutRegret(detail.decisions) } });
    });
    await loadPage(page);

    await openFixtureOf(missingId);

    const shown = { tagged: await regretTags(page).count(), rings: await countOf(page, ".modal .chart circle"), turning: await countOf(page, ".modal .turning .chip") };
    const detail = (await page.locator(".modal").innerText()).replaceAll(/\s+/g, " ");

    expectThat(incomingRegrets > 0, "the fixture route did not fire on a match that came with regret, so it proves nothing");
    expectThat(shown.tagged === 0 && shown.rings === 0 && shown.turning === 0, `a replay with no regret shows ${JSON.stringify(shown)}`);
    expectThat(!/Gave up \d|Best move, looking|Proven worse/.test(detail), "a replay with no regret still words a regret");
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

const servedConsistency = once(() => served("/api/agg/consistency", AGGREGATES.consistency));

type ServedSeat = Awaited<ReturnType<typeof servedSeats>>[number];

const certainSeats = hasCertain ? await servedSeats() : [];

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

const comebackSize = (winner: ServedSeat) =>
  Math.max(0, ...(winner.story?.ok === true ? winner.story.rounds.flatMap((round, index) => (round.winner === winner.player ? [winner.deficits[index] ?? 0] : [])) : []));

const worstGapInWonRounds = (detail: MatchDetail, player: string) =>
  Math.max(
    0,
    ...detail.decisions.flatMap(({ players, round }) => {
      const own = players.find((state) => state.player === player)?.health;
      const other = players.find((state) => state.player !== player)?.health;

      return detail.story.ok && detail.story.rounds[round - 1]?.winner === player && own !== undefined && other !== undefined ? [other - own] : [];
    }),
  );

const checkComebacksAgainstReplays = async (name: string) => {
  const decided = decidedPairs(await servedSeats());
  const comebacks = decided.filter(({ winner }) => comebackSize(winner) >= MATCH_PRESETS[0].minimum);
  const others = decided.filter(({ winner }) => comebackSize(winner) < MATCH_PRESETS[0].minimum);
  const sampled = others.filter((_pair, at) => at % Math.ceil(others.length / 60) === 0);
  const fromReplay = async ({ winner }: (typeof decided)[number]) => worstGapInWonRounds(await servedDetail(winner.matchId), winner.player);
  const listed = await Promise.all(comebacks.map(fromReplay));
  const unlisted = await Promise.all(sampled.map(fromReplay));

  console.log(name, "comebacks read from replays", comebacks.length, "| smallest", Math.min(...listed), "| unlisted sample", sampled.length, "| biggest", Math.max(...unlisted));
  expectThat(listed.every((gap) => gap >= MATCH_PRESETS[0].minimum), `${name}: a listed comeback's winner never trailed by ${MATCH_PRESETS[0].minimum} in a round it won, by its replay`);
  expectThat(unlisted.every((gap) => gap < MATCH_PRESETS[0].minimum), `${name}: a match left out of Comebacks has a winner who trailed by ${MATCH_PRESETS[0].minimum} in a round it won, by its replay`);
};

const MATCH_PRESETS = [
  { label: "Comebacks", note: /^from (\d+) health behind in round [123]$/, minimum: 3 },
  { label: "Upsets", note: /^rated (\d+) lower$/, minimum: 100 },
] as const;

const checkMatchList = async (page: Page, name: string, isTouch: boolean) => {
  const seats = await servedSeats();
  const started = matchesOf(seats).length;
  const decided = decidedPairs(seats);
  const ratings = pooledRatings(withPotShares(seats));
  const ratingOf = (seat: ServedSeat) => ratings.get(keyOf(seat))?.rating ?? 0;

  const expected = [
    decided.filter(({ winner }) => comebackSize(winner) >= MATCH_PRESETS[0].minimum).length,
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

  const [newest] = one ?? [];

  if (newest === undefined) throw new Error(`${name}: no match to search for`);

  const words = labelOf(keyOf(newest))
    .toLowerCase()
    .split(" ")
    .filter((_, index, all) => index === 0 || index === all.length - 1);

  const wordsFound = matchesOf(seats).filter((both) => words.every((word) => both.some((seat) => labelOf(keyOf(seat)).toLowerCase().includes(word)))).length;

  await search.fill(words.join(" "));
  await settled(page);
  console.log(name, "search", JSON.stringify(words.join(" ")), "lists", (await listed()).count, "| data", wordsFound);
  expectThat(words.length === 2 && wordsFound > 0 && (await listed()).count === wordsFound, `${name}: searching "${words.join(" ")}" lists ${(await listed()).count} matches, the data has ${wordsFound}`);
  await search.fill(`  ${words.join("   ")}  zzzz`);
  await settled(page);
  expectThat((await listed()).count === 0, `${name}: a word that matches nothing still lists matches`);
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

  const [, model = "", effort = ""] = /^(.*) \[(.*)\]$/.exec((await row.locator("td").first().innerText()).replace(/^\d+/, "").replaceAll(/\s+/g, " ").trim()) ?? [];
  const seats = await servedSeats();
  const own = seats.find((seat) => baseName(seat.model) === model && effortLabel(seat.model, seat.effort) === effort);

  if (own === undefined) throw new Error(`${name}: no served seat for the first leaderboard row "${model} [${effort}]"`);

  const key = keyOf(own);
  const mine = seats.filter((seat) => keyOf(seat) === key);
  const pairs = completedPairs(seats).filter((both) => both.some((seat) => keyOf(seat) === key));
  const decisions = await servedPageDecisions();
  const lines = await page.locator(".drillin .dline").allInnerTexts();

  if (isTouch) {
    const bars = await page.locator(".drillin .fate-bar").evaluateAll((found) => found.map((bar) => Math.round(bar.getBoundingClientRect().height)));

    expectThat(bars.length > 0 && bars.every((height) => height >= 44), `${name}: the drill-down's item bars are ${bars.join(", ")} px tall`);
  }

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

  const received = [0, 1, 2, 3, 4, 5, 6, 7].map((item) => sum(pairs.flatMap((both) => both.filter((seat) => keyOf(seat) === key).map((seat) => seat.acquired[item] ?? 0))));
  const unused = sum(pairs.flatMap((both) => both.filter((seat) => keyOf(seat) === key).flatMap((seat) => seat.acquired.map((acquired, item) => acquired - (seat.used[item] ?? 0) - (both.find((other) => other !== seat)?.stolen[item] ?? 0)))));
  const barRows = await page.locator(".drillin .fate").evaluateAll((fates) => fates.map((fate) => ({ name: fate.querySelector(".fate-name")?.textContent ?? "", value: fate.querySelector(".fate-val")?.textContent ?? "" })));

  console.log(name, "drill", key, "| item bars", barRows.length, "| all items unused", barRows[0]?.value, "| health gap:", gapText, "| steady:", steadyLine);
  expectThat(barRows[0]?.name === "All items" && barRows[0]?.value === `${Math.round((unused / sum(received)) * 100)}% unused`, `${name}: the first item bar is ${JSON.stringify(barRows[0])}, the data gives ${Math.round((unused / sum(received)) * 100)}% unused`);
  expectThat(barRows.every(({ value }) => value.endsWith(" unused")), `${name}: an item bar's percentage is not labelled unused: ${JSON.stringify(barRows.map(({ value }) => value))}`);

  const config = (await row.locator("td .dot").first().evaluate((dot) => getComputedStyle(dot).backgroundColor));
  const swatches = await page.locator(".drillin .fate-legend i").evaluateAll((marks) => marks.map((mark) => getComputedStyle(mark).backgroundColor));

  expectThat(swatches.length === 3 && swatches.every((swatch) => swatch === config), `${name}: the drill-down legend swatches ${swatches.join(" ")} are not the config colour ${config}`);
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
  const unusedValues = await page.locator("#items figure:nth-child(2) .fate-val").allInnerTexts();

  const rates = [...models].map((model) => {
    const available = decisions.seat.flatMap((seatIndex, move) => (seats[seatIndex]?.model === model && (decisions.legalUse[move] ?? 0) !== 0 ? [move] : []));

    return { name: baseName(model), value: `${Math.round((available.filter((move) => (decisions.useItem[move] ?? -1) >= 0).length / available.length) * 100)}%` };
  });

  const text = await textOf(page, "#items");

  console.log(name, "item usage by model", shown.map(({ name: model, value }) => `${model} ${value}`).join(", "), "| by item", kinds);
  expectThat(shown.length === models.size && rates.every((rate) => shown.some((row) => row.name === rate.name && row.value === rate.value)), `${name}: the item usage rows ${JSON.stringify(shown)} differ from the data ${JSON.stringify(rates)}`);
  expectThat(unusedValues.length > 0 && unusedValues.every((value) => /^\d+% unused$/.test(value)), `${name}: the item bars' percentages are not labelled unused: ${unusedValues.slice(0, 3).join(" | ")}`);
  expectThat(kinds === ITEMS.length, `${name}: the item usage figure by item has ${kinds} rows, not ${ITEMS.length}`);
  expectThat(!/Item fates|By config|Same position, same move/.test(text), `${name}: the item usage section still carries a retired figure`);
};

const count = (value: number) => value.toLocaleString("en-US");

const servedCertainByConfig = () => {
  const label = (seatAt: number) => {
    const seat = certainSeats[seatAt];

    return seat === undefined ? "" : `${baseName(seat.model)} [${effortLabel(seat.model, seat.effort)}]`;
  };

  const cells = new Map<string, Array<{ mistakes: number; opportunities: number; bounds: { lo: number; hi: number } | null; hasRate: boolean }>>();

  for (const { scope, model, effort, type, chose, opportunities, bounds } of servedCertain.rates) {
    const index = CERTAIN_TYPES.findIndex((certainType) => certainType === type);

    if (scope !== "config") continue;

    const own = cells.get(`${baseName(model)} [${effortLabel(model, effort)}]`) ?? CERTAIN_TYPES.map(() => ({ mistakes: 0, opportunities: 0, bounds: null, hasRate: false }));

    const spans = blocksOf(certainSeats.filter((seat) => seat.model === model && seat.effort === effort && seat.status === "completed"));

    if (index >= 0) own[index] = { mistakes: chose, opportunities, bounds: spans < MIN_BLOCKS_FOR_INTERVAL ? null : bounds, hasRate: bounds !== null };

    cells.set(`${baseName(model)} [${effortLabel(model, effort)}]`, own);
  }

  const mistakes = servedCertain.moveSeat.map((seatAt, move) => ({ label: label(seatAt), matchId: certainSeats[seatAt]?.matchId ?? "", type: servedCertain.moveType[move] ?? -1, ordinal: servedCertain.moveOrd[move] ?? -1 }));

  return { cells, mistakes };
};

const writtenRate = (scope: "model" | "all", model: string, type: (typeof CERTAIN_TYPES)[number]) => servedCertain.rates.find((rate) => rate.scope === scope && rate.model === model && rate.type === type);

const shownInterval = (bounds: { lo: number; hi: number } | null | undefined): string => (bounds === null || bounds === undefined ? "" : `[${(bounds.lo * 100).toFixed(1)}%, ${(bounds.hi * 100).toFixed(1)}%]`);

const expectCertainMarks = async (page: Page, matchId: string, what: string) => {
  const detail = await servedDetail(matchId);
  const marked = stepsOf(detail).filter(({ certain }) => certain !== null);
  const listed = servedCertain.moveOrd.filter((_ordinal, move) => certainSeats[servedCertain.moveSeat[move] ?? -1]?.matchId === matchId).length;

  expectThat(marked.length === listed, `${what}: the match serves ${marked.length} certain mistakes, the opportunities list ${listed}`);
  expectThat((await page.locator(".modal .moves .step .tag.certain").count()) === marked.length, `${what}: the replay marks ${await page.locator(".modal .moves .step .tag.certain").count()} moves, its data has ${marked.length}`);

  const on = page.locator(".modal .moves .step.on");
  const at = Number(/move (\d+) of/.exec(await textOf(page, ".modal .stepper .k"))?.[1] ?? Number.NaN) - 1;
  const isMarked = stepsOf(detail)[at]?.certain !== null;

  expectThat((await on.locator(".tag.certain").count()) === (isMarked ? 1 : 0) && (await page.locator(".modal .sel .selh .tag.certain").count()) === (isMarked ? 1 : 0), `${what}: move ${at + 1} is ${isMarked ? "" : "not "}a certain mistake and the replay disagrees`);

  return { marked: marked.length, at };
};

const checkCertain = async (page: Page, name: string, press: (target: ReturnType<Page["locator"]>) => Promise<void>, isTouch: boolean) => {
  if (!hasCertain) {
    expectThat((await page.locator("#certain-mistakes, #certain-table").count()) === 0, `${name}: a viewer without certain mistakes draws their section`);
    console.log(name, "no certain-mistakes database: no section");

    return;
  }

  const { cells, mistakes } = servedCertainByConfig();
  const chart = page.locator("#certain-mistakes");

  await chart.scrollIntoViewIfNeeded();

  const models = [...new Set(servedCertain.rates.filter(({ scope }) => scope === "model").map(({ model }) => model))].toSorted((left, right) => baseOrder(left) - baseOrder(right));

  const panels = chart.locator(".chartrow figure");

  expectThat((await panels.count()) === CERTAIN_TYPES.length, `${name}: the certain-mistakes chart has ${await panels.count()} panels, not ${CERTAIN_TYPES.length}`);

  for (const [index, type] of CERTAIN_TYPES.entries()) {
    const panel = panels.nth(index);

    const expectedCounts = models.map((model) => {
      const own = writtenRate("model", model, type);

      return own === undefined || own.opportunities === 0 ? "–" : `${count(own.chose)} / ${count(own.opportunities)}`;
    });

    const shownCounts = await panel.locator("svg text").evaluateAll((texts) => texts.map((text) => text.textContent ?? "").filter((text) => /^[\d,]+ \/ [\d,]+$|^–$/.test(text)));
    const dots = models.filter((model) => writtenRate("model", model, type)?.bounds != null).length;
    const pooled = writtenRate("all", "", type);
    const pooledText = `${count(pooled?.chose ?? 0)} of ${count(pooled?.opportunities ?? 0)}, ${(((pooled?.chose ?? 0) / (pooled?.opportunities ?? 1)) * 100).toFixed(1)}% ${shownInterval(pooled?.bounds)}`;

    expectThat(JSON.stringify(shownCounts) === JSON.stringify(expectedCounts), `${name}: "${CERTAIN_NAMES[type]}" shows ${shownCounts.join(" ")}, the data has ${expectedCounts.join(" ")}`);
    expectThat((await panel.locator("svg g[role=button]").count()) === dots, `${name}: "${CERTAIN_NAMES[type]}" draws ${await panel.locator("svg g[role=button]").count()} dots, ${dots} models have a written interval`);
    expectThat((await panel.locator("h3").innerText()).trim() === CERTAIN_NAMES[type] && (await panel.locator(".sub").innerText()).includes(pooledText), `${name}: "${CERTAIN_NAMES[type]}" lacks its name or the pooled "${pooledText}"`);
  }

  expectThat((await chart.innerText()).includes("legal move"), `${name}: the certain-mistakes chart lacks the line on opportunities`);
  await chart.screenshot({ path: shot(`${name}-certain-mistakes`), style: UNSTICK });

  const fold = page.locator("#certain-table");

  if ((await tablesFold(page).getAttribute("open")) !== null) await page.locator("#tables details > summary").click();

  expectThat(!(await fold.locator("table").isVisible()), `${name}: the certain-mistakes table shows while the tables fold is shut`);
  await press(chart.locator(".tablelink"));
  await settled(page);
  expectThat((await tablesFold(page).getAttribute("open")) !== null && (await fold.locator("table").isVisible()), `${name}: the link under the chart did not open the table`);

  if (isTouch) {
    const small = (await smallTargets(page)).filter((target) => target.startsWith("cmb") || target.startsWith("tablelink"));

    console.log(name, "certain-mistake targets under 44px:", small);
    expectThat(small.length === 0, `${name}: a certain-mistakes count or link is under 44px: ${small.slice(0, 3).join(", ")}`);
  }

  const rows = await fold.locator("tbody tr:not(.drill):not(.pooled)").evaluateAll((trs) =>
    trs.map((tr) => ({
      label: tr.querySelector("td")?.textContent?.trim() ?? "",
      cells: [...tr.querySelectorAll("td:not(:first-child)")].map((td) => ({ counts: (td.firstElementChild ?? td).textContent?.trim() ?? "", rate: td.querySelector(".cmr")?.textContent?.trim() ?? "" })),
    })),
  );

  expectThat(rows.length === cells.size, `${name}: ${rows.length} certain-mistake rows, ${cells.size} configs served`);

  for (const { label, cells: shown } of rows) {
    const served = cells.get(label);

    for (const [index, type] of CERTAIN_TYPES.entries()) {
      const want = served?.[index];
      const cell = shown[index];
      const expected = want === undefined || want.opportunities === 0 ? "–" : `${count(want.mistakes)} / ${count(want.opportunities)}`;

      expectThat(cell?.counts === expected, `${name}: ${label} shows "${cell?.counts}" for "${CERTAIN_NAMES[type]}", the data has "${expected}"`);

      const expectedShare = want === undefined ? "" : `${((want.mistakes / want.opportunities) * 100).toFixed(1)}%`;
      const expectedRate = want === undefined || !want.hasRate ? "" : want.bounds === null ? expectedShare : `${expectedShare} ${shownInterval(want.bounds)}`;

      expectThat(cell?.rate === expectedRate, `${name}: ${label} shows the rate "${cell?.rate}" for "${CERTAIN_NAMES[type]}", the written one is "${expectedRate}"`);
    }
  }

  const pooledRow = await fold.locator("tbody tr.pooled td:not(:first-child)").evaluateAll((tds) => tds.map((td) => td.textContent?.trim() ?? ""));

  const pooledWant = CERTAIN_TYPES.map((type) => {
    const written = writtenRate("all", "", type);

    return `${count(written?.chose ?? 0)} / ${count(written?.opportunities ?? 0)}${written?.bounds == null ? "" : `${(((written?.chose ?? 0) / (written?.opportunities ?? 1)) * 100).toFixed(1)}% ${shownInterval(written.bounds)}`}`;
  });

  expectThat(JSON.stringify(pooledRow) === JSON.stringify(pooledWant), `${name}: the pooled row shows ${pooledRow.join(" | ")}, the written rates are ${pooledWant.join(" | ")}`);

  const headers = await fold.locator("thead th").allInnerTexts();

  expectThat(CERTAIN_TYPES.every((type, index) => headers[index + 1]?.trim() === CERTAIN_NAMES[type]), `${name}: the certain-mistakes table lacks its type names: ${headers.join(" | ")}`);
  await fold.screenshot({ path: shot(`${name}-certain-mistakes-table`), style: UNSTICK });
  expectThat((await fold.locator(".card").evaluate((card) => card.scrollWidth - card.clientWidth)) <= 0, `${name}: the certain-mistakes table scrolls sideways in its card`);

  const openMistake = async (label: string, typeIndex: number, picture: string) => {
    const own = mistakes.filter((mistake) => mistake.label === label && mistake.type === typeIndex);
    const row = fold.locator("tbody tr:not(.drill)", { has: page.locator("td:first-child", { hasText: label }) }).first();
    const button = row.locator(`td:nth-child(${typeIndex + 2}) .cmb`);
    const chips = fold.locator(".cmmatches .chip");
    const matchIds = new Set(own.map(({ matchId }) => matchId));

    await press(button);
    await settled(page);
    expectThat((await chips.count()) === matchIds.size, `${name}: ${label} lists ${await chips.count()} matches of "${CERTAIN_NAMES[CERTAIN_TYPES[typeIndex] ?? "self_on_live"]}", ${matchIds.size} have its mistakes`);
    expectThat((await page.evaluate(() => document.documentElement.scrollWidth - innerWidth)) <= 0, `${name}: opening the matches of ${label} overflows the page`);

    if (picture !== "") await fold.screenshot({ path: shot(`${name}-certain-mistakes-${picture}`), style: UNSTICK });

    await press(chips.first());

    const matchId = await openedMatchId(page);
    const { marked, at } = await expectCertainMarks(page, matchId, `${name} ${label}`);
    const opened = stepsOf(await servedDetail(matchId))[at];
    const first = Math.min(...own.filter((mistake) => mistake.matchId === matchId).map(({ ordinal }) => ordinal));

    expectThat(opened !== undefined && opened.certain === CERTAIN_TYPES[typeIndex] && opened.ordinal === first, `${name}: ${label} opened at ordinal ${opened?.ordinal} marked ${opened?.certain}, its first mistake of that type is ${first}`);
    console.log(name, label, "opens", matchIds.size, "matches | replay at move", at + 1, "| marked moves", marked, "|", await textOf(page, ".modal .sel .selh"));

    if (picture !== "") await page.locator(".modal").screenshot({ path: shot(`${name}-certain-mistakes-replay-${picture}`) });

    await closeReplay(page);
    await press(button);
    await settled(page);
    expectThat((await fold.locator(".cmmatches").count()) === 0, `${name}: a second press on the count of ${label} left its matches open`);
  };

  const mostOf = (typeIndex: number) => mistakes.filter((mistake) => mistake.type === typeIndex).map(({ label }) => label);
  const [busiest] = mostOf(0).toSorted((left, right) => mostOf(0).filter((label) => label === right).length - mostOf(0).filter((label) => label === left).length);
  const [guaranteed] = mostOf(1);

  if (busiest === undefined || guaranteed === undefined) throw new Error("the served data holds no certain mistake of one of the types");

  await openMistake(busiest, 0, "self");
  await openMistake(guaranteed, 1, "");

  for (const row of [0, 1, 2]) {
    const sample = await openReplay(page, () => press(page.locator("#matches tbody tr.row").nth(row)));

    await expectCertainMarks(page, sample.matchId, `${name} match ${row}`);
    await closeReplay(page);
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
  await check("odds dropped", () => checkOddsDropped(page, viewport.name));
  await check("database link", () => checkDatabaseLink(page, viewport.name));
  await check("scatter drill-down", () => checkScatterDrill(page, viewport.name, false));
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
  await check("certain mistakes", () => checkCertain(page, viewport.name, (target) => target.click(), false));
  await check("heatmap", async () => {
    await checkHeat(page, viewport.name);
    console.log("heat rows", await countOf(page, "table.heat tbody tr"), "cols", await countOf(page, "table.heat thead th"), "| first row:", await textOf(page, "table.heat tbody tr"));
    await heat(page).screenshot({ path: shot("heat-opp"), style: UNSTICK });
  });
  await check("match list", () => checkMatchList(page, viewport.name, false));
  await check("comebacks by replay", () => checkComebacksAgainstReplays(viewport.name));
  await check("drill-down", async () => {
    await page.locator("table.lbt tr.row").first().click();
    await page.locator(".lb").first().screenshot({ path: shot("leaderboard"), style: UNSTICK });
    await page.locator("table.lbt tr.row").first().click();
    await checkDrill(page, viewport.name, false);
  });
  await check("item usage", () => checkItemUsage(page, viewport.name));
  await check("replays", async () => {
    for (const [row, name] of [
      [0, "replay"],
      [4, "replay-fifth"],
    ] as const) {
      await page.locator("#matches tbody tr.row").nth(row).click();
      await page.waitForSelector(".modal .step");

      for (let step = 0; step < (row === 0 ? 6 : 0); step++) await page.keyboard.press("ArrowRight");

      expectThat((await countOf(page, ".modal .board .stage")) === 1 && (await countOf(page, ".modal .board .chosen")) > 0, `${name}: the replay's table is missing or marks no chosen move`);
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

    const coverage = await openReplay(page, () => openFromMatchList(page, fixture));
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
  await check("section counts", async () => console.log("matches", await countOf(page, "#matches tbody tr.row"), "| item usage rows", await countOf(page, "#items .fate")));
  await check("jump menu", () => checkJumps(page, viewport.name, false));
  await check("sticky filters", async () => console.log("the filters stay in view:", await page.evaluate(() => Math.round(document.querySelector(".filters")?.getBoundingClientRect().top ?? -1)), "px from the top at scroll", await page.evaluate(() => Math.round(scrollY))));
  await check("matches", async () => {
    await page.locator("#matches tbody tr.row").first().click();
    await page.waitForSelector(".modal .step");
    console.log("matches → modal", await textOf(page, ".mhead h2"));
    await page.keyboard.press("Escape");
  });
  await check("deep link", async () => {
    await page.goto(`${base}/#luck`);
    await page.waitForSelector("#odds", { timeout: 120_000 });
    await settled(page);
    await settled(page);

    const landing = await jumpedTo(page, "odds");

    console.log("deep link", landing, "at", new URL(page.url()).pathname);
    expectThat(/: -?[01]px below/.test(landing), `the #luck link lands at ${landing}`);
    expectThat(new URL(page.url()).pathname === "/arena", `the arena's old /#luck link stays at ${page.url()}`);
  });
  await check("tour", () => checkTour(page, viewport.name));
  await check("site routes", () => checkSiteRoutes(page));
  await page.close();
};

const pathOf = (page: Page) => {
  const url = new URL(page.url());

  return url.pathname + url.search;
};

// The site's URLs: Play and Arena from the bar, and the arena's filter, open leaderboard row and replay move, each kept by a reload.
const checkSiteRoutes = async (page: Page) => {
  await page.goto(`${base}/`);
  await page.getByRole("link", { name: "Arena", exact: true }).click();
  await showMatches(page);
  expectThat(pathOf(page) === "/arena", `the bar's Arena link leads to ${pathOf(page)}`);

  await page.getByRole("button", { name: "minimal", exact: true }).first().click();
  await settled(page);

  const filtered = pathOf(page);
  const scatterPoints = await countOf(page, "#scatter svg g.pt");

  await page.reload();
  await showMatches(page);
  console.log("filter", filtered, "| points", scatterPoints, "→ after reload", await countOf(page, "#scatter svg g.pt"));
  expectThat(filtered === "/arena?offEfforts=minimal" && pathOf(page) === filtered, `switching off an effort gives ${filtered}, a reload ${pathOf(page)}`);
  expectThat((await countOf(page, "#scatter svg g.pt")) === scatterPoints, "a reload of a filtered arena shows a different scatter");

  await page.locator("#matches tbody tr.row").first().click();
  await page.waitForSelector(".modal .stepper");
  await page.keyboard.press("ArrowRight");
  await page.keyboard.press("ArrowRight");
  await settled(page);

  const replayed = pathOf(page);
  const move = await textOf(page, ".modal .stepper .k");

  await page.reload();
  await page.waitForSelector(".modal .stepper", { timeout: 120_000 });
  await settled(page);
  console.log("replay", replayed, move, "→ after reload", pathOf(page), await textOf(page, ".modal .stepper .k"));
  expectThat(/^\/replay\/[0-9a-f]+\?at=\d+$/.test(replayed) && pathOf(page) === replayed, `a stepped replay is at ${replayed}, a reload at ${pathOf(page)}`);
  expectThat((await textOf(page, ".modal .stepper .k")) === move, `a reload moves the replay from ${move} to ${await textOf(page, ".modal .stepper .k")}`);

  await page.keyboard.press("Escape");
  await settled(page);
  expectThat(pathOf(page) === "/arena" && (await countOf(page, ".modal")) === 0, `closing a reloaded replay leaves ${pathOf(page)}`);

  await openTables(page);
  await page.locator("table.lbt tr.row").first().click();
  await settled(page);

  const opened = pathOf(page);

  await page.reload();
  await page.waitForSelector("table.lbt", { state: "attached", timeout: 120_000 });
  await openTables(page);
  console.log("leaderboard row", opened, "| open after reload", await countOf(page, "table.lbt tr.row[aria-expanded=true]"));
  expectThat(opened.startsWith("/arena?row=") && (await countOf(page, "table.lbt tr.row[aria-expanded=true]")) === 1, `an open leaderboard row is at ${opened} and does not survive a reload`);

  await page.getByRole("link", { name: "Play", exact: true }).click();
  await settled(page);
  expectThat(pathOf(page) === "/" && (await countOf(page, ".setup")) === 1, `the bar's Play link shows ${pathOf(page)} without the game's setup`);
  await page.goBack();
  await page.waitForSelector("table.lbt", { state: "attached", timeout: 120_000 });
  expectThat(pathOf(page) === opened, `back from Play returns to ${pathOf(page)}, not ${opened}`);
};

const checkOddsDropped = async (page: Page, name: string) => {
  const seats = await servedSeats();
  const panels = oddsPanels(selfShotTallies(await servedPageDecisions(), seats, seats.map(() => true)));
  const dropped = droppedConfigs(new Set(seats.map(keyOf)), panels);
  const lines = sum(panels.map((panel) => panel.lines.length));
  const note = (await page.locator("#odds .dropped").allInnerTexts()).map((text) => text.trim());

  console.log(name, "odds panels", await countOf(page, "#odds figure"), "| lines", lines, "| dropped", dropped.length, "|", note.join(" ").slice(0, 120));
  expectThat((await countOf(page, "#odds figure")) === panels.length && (await countOf(page, "#odds figure svg > path[stroke-width='1.6']")) === lines, `${name}: the odds chart draws ${await countOf(page, "#odds figure")} panels and ${await countOf(page, "#odds figure svg > path[stroke-width='1.6']")} lines, the data has ${panels.length} and ${lines}`);
  expectThat(dropped.length > 0 ? note.length === 1 && note[0] === `Left out for too few shots: ${droppedText(dropped)}.` : note.length === 0, `${name}: the line under the odds chart reads "${note.join(" ")}", the data drops ${dropped.length} configs`);
  expectThat(sum(panels.map((panel) => panel.lines.length)) + dropped.length === configsOf(seats).length, `${name}: configs drawn and dropped do not add up to every config`);
};

const checkDatabaseLink = async (page: Page, name: string) => {
  const served = await fetch(`${base}/api/download`);
  const link = page.locator("footer .download");

  if (!served.ok) {
    expectThat((await link.count()) === 0 && (await page.locator("nav .download").count()) === 0, `${name}: the viewer has no download, yet the page links a database`);

    return;
  }

  const { bytes } = Schema.decodeUnknownSync(Schema.Struct({ bytes: Schema.Number }))(await served.json());
  const size = fmtBytes(bytes);

  await link.scrollIntoViewIfNeeded();

  const box = await link.evaluate((anchor) => {
    const { left, right, height } = anchor.getBoundingClientRect();

    return { left, right, height, width: innerWidth, text: (anchor.textContent ?? "").trim(), scroll: document.documentElement.scrollWidth - innerWidth };
  });

  console.log(name, "database link", JSON.stringify(box));
  expectThat(box.text === `Database (SQLite, ${size})`, `${name}: the database link reads "${box.text}", the file is ${size}`);
  expectThat(box.left >= 0 && box.right <= box.width && box.scroll <= 0, `${name}: the database link runs off the screen: ${box.left} to ${box.right} of ${box.width}`);
  expectThat(box.height >= 44, `${name}: the database link is ${box.height}px tall`);
  expectThat((await page.locator("nav .download").count()) === 0, `${name}: the database link is also in the jump menu, where a phone cuts it off`);

  const download = await fetch(`${base}/api/db`, { method: "HEAD" });

  expectThat(download.ok && Number(download.headers.get("content-length")) === bytes, `${name}: the database link serves ${download.headers.get("content-length")} bytes, not ${bytes}`);
};

// The config panel's largest gap opens its match's replay at that move, and no other move of that player gave up more.
const checkLargestMiss = async (page: Page, name: string, panel: ReturnType<Page["locator"]>, isTouch: boolean) => {
  const link = panel.locator(".miss button");

  expectThat((await link.count()) === 1, `${name}: the config panel shows no largest gap`);
  await (isTouch ? link.tap() : link.click());

  const matchId = await openedMatchId(page);
  const steps = stepsOf(await servedDetail(matchId));
  const at = Number(/move (\d+) of/.exec(await textOf(page, ".modal .stepper .k"))?.[1] ?? Number.NaN) - 1;
  const opened = steps[at];
  const most = Math.max(...steps.filter(({ player }) => player === opened?.player).map(({ regret }) => regret?.points ?? 0));

  console.log(name, "largest gap:", await link.textContent(), "| opens", matchId, "at move", at + 1, "giving up", opened?.regret?.points);
  expectThat(opened?.regret !== null && opened?.regret !== undefined && opened.regret.points === most && (await link.textContent())?.startsWith(fmtPoints(most)) === true, `${name}: the largest gap opened move ${at + 1} (${opened?.regret?.points ?? "no"} points), its player's most is ${most}`);
  await closeReplay(page);
};

const checkScatterDrill = async (page: Page, name: string, isTouch: boolean) => {
  const point = page.locator("#scatter svg g[style*=pointer]").nth(3);

  await point.scrollIntoViewIfNeeded();
  await (isTouch ? point.tap({ force: true }) : point.click({ force: true }));
  await settled(page);

  const panel = page.locator("#scatter .configpanel");

  expectThat((await panel.count()) === 1 && (await panel.locator(".drillin").count()) === 1, `${name}: a click on a scatter point opened no drill-down`);
  expectThat((await page.locator("table.lbt tr.drill").count()) === 0, `${name}: the scatter's drill-down also opened a leaderboard row`);
  await panel.screenshot({ path: shot(`${name}-scatter-drill`), style: UNSTICK });
  await checkLargestMiss(page, name, panel, isTouch);
  await (isTouch ? panel.locator(".drillclose").tap() : panel.locator(".drillclose").click());
  await settled(page);
  expectThat((await page.locator("#scatter .configpanel").count()) === 0, `${name}: the drill-down's close button left it open`);

  if (!isTouch) {
    await point.focus();
    await page.keyboard.press("Enter");
    await settled(page);
    expectThat((await panel.count()) === 1, `${name}: Enter on a focused scatter point opened no drill-down`);
    await panel.locator(".drillclose").click();
    await settled(page);
  }

  await page.locator(".hero .title").click({ force: true });
};

// Steps through the whole tour by keyboard: every step must highlight an element the page draws, inside the page's
// width, and Escape must close it.
const checkTour = async (page: Page, name: string) => {
  await page.locator(".tourstart").click();

  const steps = tourOf(hasCertain);

  for (const [index, step] of steps.entries()) {
    if (index > 0) await page.keyboard.press("ArrowRight");

    // A match the server has not sent lately is replayed through the rules first, which takes up to seconds.
    if (step.isReplay) await page.waitForSelector(".modal .step", { timeout: ACTION_TIMEOUT_MS });

    await settled(page);

    const drawn = await page.evaluate((focus) => [...document.querySelectorAll(focus)].some((element) => element.getBoundingClientRect().height > 0), step.focus);
    const counter = (await page.locator(".tour-head .k").innerText()).trim();
    const box = await page.locator(".tour-focus").boundingBox();
    const width = await page.evaluate(() => document.documentElement.clientWidth);

    expectThat(drawn, `${name}: tour step "${step.title}" finds nothing drawn at ${step.focus}`);
    expectThat(box !== null && box.x + box.width <= width + 8, `${name}: tour step "${step.title}" highlights outside the page`);
    expectThat(counter === `${index + 1} / ${steps.length}` && (await page.locator(".tour-card").innerText()).includes(step.title), `${name}: tour card ${index + 1} reads "${counter}", the page's tour has ${steps.length} steps`);
    expectThat(hasCertain || !/certain/i.test(await page.locator(".tour-card").innerText()), `${name}: a page without certain mistakes tours them at "${step.title}"`);
    expectThat(step.isReplay === ((await page.locator(".modal .step").count()) > 0), `${name}: tour step "${step.title}" ${step.isReplay ? "has no replay open" : "leaves a replay open"}`);
    await page.screenshot({ path: shot(`${name}-tour-${String(index + 1).padStart(2, "0")}`) });
  }

  await page.keyboard.press("Escape");
  console.log(name, "tour steps", steps.length, "| closed by Escape:", (await countOf(page, ".tour-layer")) === 0);
  expectThat((await countOf(page, ".modal")) === 0, `${name}: closing the tour left a replay open`);
};

const checkTouch = async (browser: Browser, viewport: Viewport) => {
  const { name, width, height } = viewport;
  const page = await newPage(browser, viewport);
  const check = (what: string, run: () => Promise<void>) => attempt(name, what, run, () => clearOverlays(page));
  const stickyModelColumn = () => page.evaluate(() => getComputedStyle(document.querySelector("table.heat td.left") ?? document.body).position);

  page.setDefaultTimeout(ACTION_TIMEOUT_MS);
  watch(page, name);
  await check("open page", () => openPage(page));
  await check("tour button", async () => {
    const box = await page.locator(".tourstart").evaluate((button) => {
      const { width, height } = button.getBoundingClientRect();

      return { width, height };
    });

    console.log(name, "Take the tour button", JSON.stringify(box));
    expectThat(box.width >= 44 && box.height >= 44, `${name}: Take the tour is ${Math.round(box.width)}x${Math.round(box.height)}px, under 44`);
  });
  await check("overview", async () => console.log(name, "overflow", await page.evaluate(() => document.documentElement.scrollWidth - innerWidth), "| small targets", await smallTargets(page), "| heat model column", await stickyModelColumn(), "| scatter labels", await countOf(page, "#scatter svg g.ptlabel")));
  await check("first screen and filters", async () => {
    await page.screenshot({ path: shot(`${name}-first-screen`) });

    const scatterTop = await page.evaluate(() => document.querySelector("#scatter .card")?.getBoundingClientRect().top ?? Number.POSITIVE_INFINITY);

    console.log(name, "the scatter starts at", Math.round(scatterTop), "px of", height);
    expectThat(scatterTop < height * 0.6, `${name}: the scatter starts below the first screen's upper 60%`);

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
    for (const selector of ["#odds svg g[role=button]", "#items .fate-bar[role=button]", ...(hasCertain ? ["#certain-mistakes svg g[role=button]"] : [])]) {
      await page.locator(selector).first().evaluate((mark) => mark.scrollIntoView({ block: "center" }));
      await page.locator(selector).first().tap({ force: true });

      const tip = await tipOf(page);

      console.log(name, "tap", selector, "→", tip);
      expectThat(tip !== "none" && /\d/.test(tip), `${name}: tapping ${selector} shows no tip with a count`);

      await page.mouse.move(0, 0);
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
  await check("odds dropped", () => checkOddsDropped(page, name));
  await check("database link", () => checkDatabaseLink(page, name));
  await check("scatter drill-down", () => checkScatterDrill(page, name, true));
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
    await checkHeat(page, name);
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
      expectThat(["wins vs own opponents", "round wins", "cash share", "cost / move", "time / move", "output tok / match", "fav"].every((label) => details.includes(label)), `${name}: the drill-down lacks a leaderboard detail: ${details.join(", ")}`);
      await page.locator("table.lbt").first().screenshot({ path: shot(`${name}-leaderboard-open`) });
      await row.tap();
    }
  });
  await check("match list", () => checkMatchList(page, name, true));
  await check("drill-down", () => checkDrill(page, name, true));
  await check("item usage", () => checkItemUsage(page, name));
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
  await check("certain mistakes", () => checkCertain(page, name, (target) => target.tap(), true));
  await check("candidate list", async () => {
    const [fixture] = await regretFixtures(1);

    if (fixture === undefined) throw new Error("no regret blunder to open a candidate list from");

    await openFromMatchList(page, fixture);

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
  await page.route("**/api/agg/consistency", (route) => route.abort());
  await loadPage(page);
  await settled(page);

  expectThat((await page.getByText(/^Could not load the /).count()) === 0, "a failed optional endpoint left a note before any row was open");
  await openTables(page);
  await page.locator("table.lbt tr.row").first().click();
  await settled(page);

  const notes = await page.getByText(/^Could not load the /).allInnerTexts();

  console.log("with consistency failing:", notes, "| leaderboards", await countOf(page, "table.lbt"));
  expectThat(notes.length === 1 && (await page.locator(".drillin").getByText(/^Could not load the consistency/).count()) === 1, "a failed optional endpoint did not leave a note in the drill-down that reads it");
  expectThat(!asked.includes("/api/blunders"), "the page still loads the blunders");
  await page.context().close();
};

const checkCertainFailure = async (browser: Browser) => {
  const page = await newPage(browser, VIEWPORTS[0]);

  await page.route("**/api/agg/certain", (route) => route.abort());
  await loadPage(page);
  await settled(page);

  const notes = await page.getByText(/^Could not load the /).allInnerTexts();

  console.log("with certain-mistakes failing:", notes, "| leaderboards", await countOf(page, "table.lbt"));
  expectThat(notes.length === 1 && (await page.locator("#certain-mistakes").getByText(/^Could not load the certain mistakes/).count()) === 1, "a failed certain-mistakes endpoint did not leave a note in its own section");
  expectThat((await countOf(page, "table.lbt")) > 0, "a failed certain-mistakes endpoint took the leaderboard down");
  await page.context().close();
};

mkdirSync(outdir, { recursive: true });

const browser = await chromium.launch({ executablePath: chrome, args: ["--no-sandbox"] });

const only = VIEWPORTS.filter(({ name }) => process.env["ONLY"] === undefined || process.env["ONLY"].split(",").includes(name));

for (const viewport of only) await attempt(viewport.name, "baseline capture", () => captureBaseline(browser, viewport));

for (const viewport of only) await (viewport.isTouch ? checkTouch(browser, viewport) : checkDesktop(browser, viewport));

await attempt("desktop", "optional data failing", () => checkOptionalFailure(browser));

await attempt("desktop", "certain mistakes failing", () => checkCertainFailure(browser));

// The server fits the ratings; they must be the numbers the page's own fit gives over the same served seats.
const servedRatings = (await served("/api/agg/summary", AGGREGATES.summary)).configs.flatMap((config) => (config.rating === null ? [] : [{ key: keyOf(config), rating: config.rating }]));
const fitted = pooledRatings(withPotShares(await servedSeats()));

console.log("served ratings", servedRatings.length, "| fitted here", fitted.size);

expectThat(servedRatings.length === fitted.size, "served ratings and the page's fit rate different configs");

for (const { key, rating } of servedRatings) expectThat(JSON.stringify(rating) === JSON.stringify(fitted.get(key)), `served rating of ${key} differs from the page's fit`);

console.log("failed checks", failures);

console.log("errors", errors, "| negative widths while a screenshot resized the window:", screenshotResizeErrors);

await browser.close();

if (failures.length > 0 || errors.length > 0) process.exitCode = 1;
