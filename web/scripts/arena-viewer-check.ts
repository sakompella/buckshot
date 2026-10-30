import { mkdirSync } from "node:fs";
import { join } from "node:path";

import { Schema } from "effect";
import { type Browser, chromium, type Page } from "playwright-core";

import { MatchDetail } from "../src/arena-viewer/api.ts";
import { GROUPS, Section } from "../src/arena-viewer/page/model.ts";
import { TOUR } from "../src/arena-viewer/page/tour.ts";
import { type RegretCoverage, regretCoverageOf } from "./arena-viewer-regret-coverage.ts";

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

const heat = (page: Page) => page.locator("#breakdown");

const loadPage = async (page: Page) => {
  await page.goto(`${base}/`);
  await page.waitForSelector("table.lbt", { timeout: 120_000 });
  await page.waitForSelector(".icard svg rect", { timeout: 60_000 });
};

const openPage = async (page: Page) => {
  const started = Date.now();

  await loadPage(page);
  console.log("every section drawn in", Date.now() - started, "ms");

  const counts = async () => ["scatter points", await countOf(page, ".card svg g.pt"), "heat rows", await countOf(page, "table.heat tbody tr"), "leaderboards", await countOf(page, "table.lbt"), "|", await page.locator(".filters .switch").allInnerTexts()];
  const allConfigs = page.getByRole("switch", { name: /all configs/ });

  console.log("default (all configs):", ...(await counts()));

  if ((await allConfigs.count()) === 0) return;

  await allConfigs.uncheck();
  console.log("main configs only:", ...(await counts()));
  await allConfigs.check();
};

// Visible controls smaller than 44px either way (heat cells and leaderboard squares are left out).
const smallTargets = (page: Page) =>
  page.evaluate(() =>
    [...document.querySelectorAll("nav a, .toggle button, .chip, .switch, select, input:not([type=checkbox]), .stepper button, .modal .x")].flatMap((element) => {
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
    [...document.querySelectorAll("#scatter .card:first-child svg > g:not(.ptlabel) > text[text-anchor=end]")]
      .map((text) => ({ y: Number(text.getAttribute("y")), label: text.textContent ?? "" }))
      .toSorted((left, right) => left.y - right.y)
      .map(({ label }) => label)
      .slice(0, 6)
      .join(" "),
  );

const axesOf = (page: Page) =>
  page.evaluate(() => {
    const chart = document.querySelector(".card svg");
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

      console.log(name, label, "| points", await countOf(page, ".card svg g.pt"), "| axes unchanged:", isSame, "| reliability scales unchanged:", isScaleSame);
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

// One choice drives the scatter, the heatmap and the leaderboards: each section's toggle shows it.
const checkRanking = async (page: Page, scatter: ReturnType<Page["locator"]>) => {
  const ranking = async () => [await textOf(page, ".card h2"), "| y ticks", await yTicks(page), "| heat header", await textOf(page, "table.heat thead th:nth-last-child(2)"), "| heat first row", await textOf(page, "table.heat tbody tr"), "| unranked heat rows", (await page.locator("table.heat td.total").allInnerTexts()).filter((text) => text === "–").length, "| leaderboard first row", await textOf(page, "table.lbt tbody tr.row"), "| toggles on", (await page.locator(".toggle button.on", { hasText: /^(Elo|Rank)$/ }).allInnerTexts()).join(" ")];

  console.log("Elo:", ...(await ranking()));
  await scatter.getByRole("button", { name: "Rank", exact: true }).click();
  await settled(page);
  console.log("Rank:", ...(await ranking()));

  const places = (await yTicks(page)).split(" ").map(Number);

  expectThat(places.length > 1 && places.every((place, index) => index === 0 || place - (places[index - 1] ?? 0) === (places[1] ?? 0) - (places[0] ?? 0)), `rank ticks are not evenly spaced: ${places.join(" ")}`);
  await scatter.screenshot({ path: shot("scatter-rank") });
  await heat(page).screenshot({ path: shot("heat-rank"), style: UNSTICK });
  await page.locator(".lb").screenshot({ path: shot("leaderboard-rank"), style: UNSTICK });
  await page.locator(".lb").getByRole("button", { name: "Elo", exact: true }).click();
  await settled(page);
  console.log("back to Elo from the leaderboard:", await textOf(page, ".card h2"));
};

// Under either rating basis and either ranking, every config the page draws has an Elo and a rank: no dash in the
// heatmap or the leaderboards.
const checkEveryConfigRated = async (page: Page, scatter: ReturnType<Page["locator"]>) => {
  const dashes = (selector: string) => page.locator(selector).evaluateAll((cells) => cells.filter((cell) => cell.textContent?.trim() === "–").length);

  for (const basis of ["Round wins", "Match wins", "Cash"] as const) {
    await scatter.getByRole("button", { name: basis, exact: true }).click();

    for (const ranking of ["Elo", "Rank"] as const) {
      await scatter.getByRole("button", { name: ranking, exact: true }).click();
      await settled(page);

      const label = ranking === "Rank" ? "rank" : ELO_NAMES[basis];
      const rows = await countOf(page, "table.heat tbody tr");
      const missing = (await dashes("table.heat td.total")) + (await dashes(`table.lbt td[data-label="${label}"]`));
      const points = await countOf(page, ".card svg g.pt");
      const unlisted = await page.locator("table.heat td.total").evaluateAll((cells) => cells.filter((cell) => cell.textContent?.trim() === "").length);

      console.log(basis, ranking, "| heat rows", rows, "| scatter points", points, "| rows without a rating", missing + unlisted);
      expectThat(missing + unlisted === 0, `${basis} ${ranking}: a config shows a dash instead of a rating`);
    }
  }

  await scatter.getByRole("button", { name: "Round wins", exact: true }).click();
  await scatter.getByRole("button", { name: "Elo", exact: true }).click();
  await settled(page);
};

const ELO_NAMES = { "Round wins": "Round Elo", "Match wins": "Match Elo", Cash: "Cash Elo" } as const;

const ratingViews = async (page: Page) => ({
  scatter: await textOf(page, ".card h2"),
  heat: await textOf(page, "table.heat thead th:nth-last-child(2)"),
  leaderboard: await textOf(page, "table.lbt thead th.rating"),
  firstRow: await textOf(page, "table.lbt tbody tr.row"),
  heatFirstRow: await textOf(page, "table.heat tbody tr"),
  toggles: await page.locator(".toggle button.on", { hasText: /^(Round wins|Match wins|Cash)$/ }).allInnerTexts(),
});

// The Round wins / Cash choice drives the scatter, the heatmap and the leaderboards together, the leaderboards show every
// config's pot share beside its match win share, and the axes stay put under filters on the cash rating too.
const checkCash = async (page: Page, scatter: ReturnType<Page["locator"]>) => {
  const rounds = await ratingViews(page);

  console.log("Round wins:", rounds);
  await scatter.getByRole("button", { name: "Cash", exact: true }).click();
  await settled(page);

  const cash = await ratingViews(page);

  console.log("Cash:", cash);
  expectThat(cash.scatter.includes("Cash Elo") && cash.heat === "Cash Elo" && cash.leaderboard === "Cash Elo", "the Cash choice did not reach the scatter, the heatmap and the leaderboards");
  expectThat(rounds.scatter.includes("Round Elo") && rounds.heat === "Round Elo" && rounds.leaderboard === "Round Elo", "the page does not start on the round rating");
  expectThat(cash.firstRow !== rounds.firstRow && cash.heatFirstRow !== rounds.heatFirstRow, "the cash rating left the leaderboard or heatmap rows as they were");
  expectThat(cash.toggles.length === 3 && cash.toggles.every((text) => text === "Cash"), `Cash toggles on: ${cash.toggles.join(" ")}`);

  const pots = await page.locator('table.lbt td[data-label="pot share"]').allInnerTexts();
  const rows = await countOf(page, "table.lbt tbody tr.row");

  console.log("pot share cells", pots.length, "of", rows, "rows, first", pots.slice(0, 6).join(" "));
  expectThat(pots.length === rows && pots.every((text) => /^\d+%$/.test(text.trim())), "a leaderboard row has no pot share");

  await page.locator(".lb").getByRole("button", { name: "Rank", exact: true }).click();
  await settled(page);
  console.log("Cash rank:", await textOf(page, "table.lbt tbody tr.row"), "| heat header", await textOf(page, "table.heat thead th:nth-last-child(2)"));
  await scatter.screenshot({ path: shot("scatter-cash-rank") });
  await page.locator(".lb").getByRole("button", { name: "Elo", exact: true }).click();
  await settled(page);
  await scatter.screenshot({ path: shot("scatter-cash") });
  await heat(page).screenshot({ path: shot("heat-cash"), style: UNSTICK });
  await page.locator(".lb").screenshot({ path: shot("leaderboard-cash"), style: UNSTICK });
  await checkFixedAxes(page, scatter);

  await heat(page).getByRole("button", { name: "Round wins", exact: true }).click();
  await settled(page);

  const back = await ratingViews(page);

  expectThat(JSON.stringify(back) === JSON.stringify(rounds), "Round wins did not bring the page back to how it started");
};

// The page starts on round wins, with every leaderboard row's round wins. Match wins is fitted on its first click, which
// is timed, and reaches the scatter, the heatmap and the leaderboards.
const checkMatchWins = async (page: Page, scatter: ReturnType<Page["locator"]>) => {
  const rounds = await ratingViews(page);
  const shares = await page.locator('table.lbt td[data-label="round wins"]').allInnerTexts();
  const rows = await countOf(page, "table.lbt tbody tr.row");

  console.log("round wins cells", shares.length, "of", rows, "rows, first", shares.slice(0, 6).join(" "));
  expectThat(shares.length === rows && shares.every((text) => /^\d+%$/.test(text.trim())), "a leaderboard row has no round wins");

  const clicked = Date.now();

  await scatter.getByRole("button", { name: "Match wins", exact: true }).click();
  await settled(page);
  console.log("Match wins fitted and drawn in", Date.now() - clicked, "ms");

  const matches = await ratingViews(page);

  console.log("Match wins:", matches);
  expectThat(matches.scatter.includes("Match Elo") && matches.heat === "Match Elo" && matches.leaderboard === "Match Elo", "the Match wins choice did not reach the scatter, the heatmap and the leaderboards");
  expectThat(matches.firstRow !== rounds.firstRow && matches.heatFirstRow !== rounds.heatFirstRow, "the match rating left the leaderboard or heatmap rows as they were");
  expectThat(matches.toggles.length === 3 && matches.toggles.every((text) => text === "Match wins"), `Match wins toggles on: ${matches.toggles.join(" ")}`);

  await page.locator(".lb").getByRole("button", { name: "Rank", exact: true }).click();
  await settled(page);
  console.log("Match wins rank:", await textOf(page, "table.lbt tbody tr.row"), "| heat header", await textOf(page, "table.heat thead th:nth-last-child(2)"));
  await scatter.screenshot({ path: shot("scatter-matches-rank") });
  await page.locator(".lb").getByRole("button", { name: "Elo", exact: true }).click();
  await settled(page);
  await scatter.screenshot({ path: shot("scatter-matches") });
  await heat(page).screenshot({ path: shot("heat-matches"), style: UNSTICK });
  await page.locator(".lb").screenshot({ path: shot("leaderboard-matches"), style: UNSTICK });
  await checkFixedAxes(page, scatter);

  await heat(page).getByRole("button", { name: "Round wins", exact: true }).click();
  await settled(page);
  expectThat(JSON.stringify(await ratingViews(page)) === JSON.stringify(rounds), "Round wins did not bring the page back to how it started after Match wins");
};

const MATCH_RESPONSE = /\/api\/match\?id=/;

// Runs the click that opens a replay and reads what the match's own response says about regret there.
const openReplay = async (page: Page, open: () => Promise<void>): Promise<RegretCoverage> => {
  const [response] = await Promise.all([page.waitForResponse(MATCH_RESPONSE), open()]);
  const coverage = regretCoverageOf(Schema.decodeUnknownSync(MatchDetail)(await response.json()).decisions);

  await page.waitForSelector(".modal .step");

  return coverage;
};

const closeReplay = async (page: Page) => {
  await page.keyboard.press("Escape");
  await page.waitForSelector(".modal", { state: "detached" });
};

// The replay open on the page shows exactly the regret its match has: tags, rings and turning points, none when there is none.
const expectRegretShown = async (page: Page, coverage: RegretCoverage, what: string) => {
  const shown = { tagged: await regretTags(page).count(), rings: await countOf(page, ".modal .chart circle"), turning: await countOf(page, ".modal .turning .chip") };

  expectThat(shown.tagged === coverage.tagged && shown.rings === coverage.rings && shown.turning === coverage.turning, `${what}: replay shows ${JSON.stringify(shown)}, its data has ${JSON.stringify({ tagged: coverage.tagged, rings: coverage.rings, turning: coverage.turning })}`);
};

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

  // Matches the derived database has not reached show no regret at all: no tag, no ring, no turning points.
  for (const row of [0, 1, 2, 3, 4]) {
    const coverage = await openReplay(page, () => page.locator("#matches tbody tr.row").nth(row).click());

    await expectRegretShown(page, coverage, `match ${row}`);
    console.log("match", row, "searched moves", coverage.searched, "tags", coverage.tagged);
    await closeReplay(page);
  }

  // The regret blunder cards are built from regret rows, so their replays are the covered fixture.
  const blunderCards = page.locator(".icard", { hasText: "Round win chance" });
  const fixtures = Math.min(await blunderCards.count(), 5);
  let exact = 0;
  let notExact = 0;

  expectThat(fixtures > 0, "no regret blunder card to open a regret-covered replay from");

  for (const card of Array.from({ length: fixtures }, (_, index) => index)) {
    const coverage = await openReplay(page, () => blunderCards.nth(card).click());

    expectThat(coverage.searched > 0 && coverage.tagged > 0 && coverage.turning > 0, `regret blunder card ${card}: its replay has ${coverage.searched} searched, ${coverage.tagged} tagged, ${coverage.turning} turning`);
    await expectRegretShown(page, coverage, `blunder card ${card}`);

    const tags = await regretTags(page).evaluateAll((found) => found.map((tag) => ({ text: tag.textContent ?? "", isExact: tag.classList.contains("exact") })));

    expectThat(tags.every(({ text }) => REGRET_TAG.test(text.trim())), `blunder card ${card}: regret tags ${tags.slice(0, 3).map(({ text }) => text).join(" | ")}`);
    exact += tags.filter(({ isExact }) => isExact).length;
    notExact += tags.filter(({ isExact }) => !isExact).length;

    for (const kind of ["exact", "not exact"] as const) {
      const step = page.locator(".modal .step").filter({ has: kind === "exact" ? page.locator(".tag.regret.exact") : page.locator(".tag.regret:not(.exact)") }).first();

      if ((await step.count()) === 0) continue;

      await step.click();
      await settled(page);

      const detail = ((await page.locator(".modal .sel").textContent()) ?? "").replaceAll(/\s+/g, " ");
      const says = /not proven exact/.test(detail) ? "not exact" : /proven exact/.test(detail) ? "exact" : "neither";

      expectThat(/Best move .+ chosen [\d.]+% · depth \d/.test(detail) && says === kind, `blunder card ${card}: a ${kind} move's detail says ${says}: ${detail.slice(0, 120)}`);

      if (card === 0) await page.locator(".modal").screenshot({ path: shot(`replay-regret-${kind.replace(" ", "-")}`) });
    }

    console.log("blunder card", card, "searched moves", coverage.searched, "tags", coverage.tagged, "turning points", coverage.turning);
    await closeReplay(page);
  }

  console.log("regret tags over the covered replays:", exact, "exact,", notExact, "not proven exact");
  expectThat(exact + notExact > 0, "no covered replay shows a regret tag");
};

const checkDesktop = async (browser: Browser, viewport: Viewport) => {
  const page = await newPage(browser, viewport);
  const scatter = page.locator(".card").first();
  const check = (name: string, run: () => Promise<void>) => attempt(viewport.name, name, run, () => clearOverlays(page));

  page.setDefaultTimeout(ACTION_TIMEOUT_MS);
  watch(page, viewport.name);
  await check("open page", () => openPage(page));
  await check("scatter", async () => {
    console.log("scatter points", await countOf(page, ".card svg g[style*=pointer]"), "labels", await countOf(page, ".card svg g.ptlabel"), "| toggles:", await textOf(page, ".card .ctl"));
    await scatter.screenshot({ path: shot("scatter") });
    await page.locator(".card svg g[style*=pointer]").nth(3).hover({ force: true });
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
      console.log("axis", name, "|", await textOf(page, ".card h2"), "| points", await countOf(page, ".card svg g.pt"));
      await scatter.screenshot({ path: shot(`scatter-${name}`) });
    }
  });
  await check("fixed axes", () => checkFixedAxes(page, scatter));
  await check("ranking", () => checkRanking(page, scatter));
  await check("cash", () => checkCash(page, scatter));
  await check("match wins", () => checkMatchWins(page, scatter));
  await check("every config rated", () => checkEveryConfigRated(page, scatter));
  await check("regret", () => checkRegret(page));
  await check("heatmap modes", async () => {
    for (const [mode, name] of [
      ["Win share vs opponent", "opp"],
      ["Item use when legal", "items"],
      ["Choice patterns", "choices"],
      ["Play style", "style"],
    ] as const) {
      await heat(page).getByRole("button", { name: mode }).click();
      console.log("heat", name, "rows", await countOf(page, "table.heat tbody tr"), "cols", await countOf(page, "table.heat thead th"), "| first row:", await textOf(page, "table.heat tbody tr"));
      await heat(page).screenshot({ path: shot(`heat-${name}`) });
    }

    await heat(page).getByRole("switch", { name: /best row/ }).check();
    console.log("best row per model", await countOf(page, "table.heat tbody tr"), "rows");
    await heat(page).screenshot({ path: shot("heat-style-best") });
    await heat(page).getByRole("switch", { name: /best row/ }).uncheck();
  });
  await check("flagged moves", async () => {
    await heat(page).getByRole("button", { name: "Choice patterns" }).click();
    await page.locator("table.heat td.click").first().hover();
    console.log("hover cell → tip:", await tipOf(page));
    await page.locator("table.heat td.click").first().click();
    await page.waitForSelector(".flagged tr.row");
    console.log("flagged rows", await countOf(page, ".flagged tr.row"));
    await page.locator(".igrid").screenshot({ path: shot("interesting") });
    await page.locator("#blunders").screenshot({ path: shot("blunders"), style: UNSTICK });
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
    const coverage = await openReplay(page, () => page.locator(".flagged tr.row").first().click());

    await page.waitForSelector(".modal .step.on");
    console.log("focused move", await textOf(page, ".modal .step.on"), "| searched moves", coverage.searched);
    await expectRegretShown(page, coverage, "the flagged move's replay");
    await page.locator(".modal details.seeds > summary").click();
    await page.locator(".seedrow .chip").first().click();
    await page.waitForSelector(".modal .step");
    await settled(page);
    console.log("after same-seed chip:", await textOf(page, ".mhead h2"));
    await closeReplay(page);
  });
  // The page keeps the matches it has already loaded, so a card opened before sends no new request; the regret check
  // has compared this match's tags and rings with its data already.
  await check("turning points", async () => {
    await page.locator(".icard", { hasText: "Round win chance" }).first().click();
    await page.waitForSelector(".modal .step");

    const turning = page.locator(".modal .turning .chip");
    const listed = await turning.count();
    const rings = await countOf(page, ".modal .chart circle");

    console.log("turning points", listed, "| blunder rings", rings);
    expectThat(listed > 0 && rings >= listed, "the replay of a regret blunder has no turning points on its health chart");

    const [, label = "", points = ""] = (await turning.first().innerText()).replaceAll(/\s+/g, " ").split(" · ");

    await turning.first().click();

    const opened = await textOf(page, ".modal .step.on");

    console.log("turning point opens", opened);
    expectThat(opened.includes(label) && opened.includes(points), `a turning point "${label} · ${points}" opened "${opened}"`);
    await page.locator(".modal").screenshot({ path: shot("replay-turning-points") });
    await closeReplay(page);
  });
  await check("mark tip by keyboard", async () => {
    const mark = page.locator("#rubbers svg g[role=button]").first();

    await mark.focus();
    console.log("focus a mark → tip:", await tipOf(page));
    await page.keyboard.press("Enter");
    await mark.blur();

    const pinned = await tipOf(page);

    console.log("Enter pins it, and it stays after the focus leaves → tip:", pinned);
    expectThat(pinned === (await mark.getAttribute("aria-label")), "a mark pinned by Enter left no tip of its own");
    await page.locator(".hero").click();
    expectThat((await tipOf(page)) === "none", "a click outside left the pinned tip");
  });
  await check("section counts", async () => console.log("matches", await countOf(page, "#matches tbody tr.row"), "| seats", await countOf(page, "#seats .bignum"), "| item fate rows", await countOf(page, "#items .fate"), "| reliability charts", await countOf(page, "#reliability .chartrow figure")));
  await check("jump menu", () => checkJumps(page, viewport.name, false));
  await check("sticky filters", async () => console.log("the filters stay in view:", await page.evaluate(() => Math.round(document.querySelector(".filters")?.getBoundingClientRect().top ?? -1)), "px from the top at scroll", await page.evaluate(() => Math.round(scrollY))));
  await check("reliability and matches", async () => {
    await page.locator("#reliability details.tables > summary").click();
    await page.locator("#reliability tbody td[data-label='failed calls']").first().hover();
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
  await page.locator("nav .tourstart").click();

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
  await check("overview", async () => console.log(name, "overflow", await page.evaluate(() => document.documentElement.scrollWidth - innerWidth), "| small targets", await smallTargets(page), "| heat model column", await stickyModelColumn(), "| scatter labels", await countOf(page, ".card svg g.ptlabel")));
  await check("first screen and filters", async () => {
    await page.screenshot({ path: shot(`${name}-first-screen`) });

    const chartTop = await page.evaluate(() => document.querySelector(".card svg")?.getBoundingClientRect().top ?? Number.POSITIVE_INFINITY);

    console.log(name, "first chart starts at", Math.round(chartTop), "px of", height);
    expectThat(chartTop < height * 0.6, `${name}: the first chart starts below the first screen's upper 60%`);

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
    for (const selector of ["#luck svg rect[role=button]", "#rubbers svg g[role=button]", "#deals svg g[role=button]"]) {
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
      await page.locator(".hero").tap();
      expectThat((await tipOf(page)) === "none", `${name}: a tap outside leaves the tip of ${selector}`);
    }
  });
  await check("scatter tap", async () => {
    await page.locator(".card svg g[style*=pointer]").nth(3).tap({ force: true });
    console.log(name, "tap point → tip:", await tipOf(page));
    await page.locator("#luck svg rect[role=button]").first().tap({ force: true });
    expectThat((await page.locator(".tip").count()) === 1, `${name}: pinning a mark left the scatter's pin up too`);
    await page.locator(".hero").tap();
    await page.locator(".card svg g[style*=pointer]").nth(3).scrollIntoViewIfNeeded();
    await page.locator(".card svg g[style*=pointer]").nth(3).tap({ force: true });
    await page.locator(".card").first().screenshot({ path: shot(`${name}-scatter`) });
    await page.locator(".hero").tap();
    console.log(name, "tap outside clears the tip:", (await tipOf(page)) === "none");
  });
  await check("heat and leaderboard", async () => {
    await heat(page).getByRole("button", { name: "Item use when legal" }).tap();
    await settled(page);
    await heat(page).locator(".heatscroll").evaluate((element) => element.scrollTo({ left: 200 }));
    await heat(page).screenshot({ path: shot(`${name}-heat-items`) });
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
  await check("rank toggles", async () => {
    await heat(page).getByRole("button", { name: "Rank", exact: true }).tap();
    await settled(page);
    console.log(name, "rank y ticks", await yTicks(page));
    await page.locator(".card").first().screenshot({ path: shot(`${name}-scatter-rank`) });
    await heat(page).getByRole("button", { name: "Cash", exact: true }).tap();
    await settled(page);
    console.log(name, "cash rank y ticks", await yTicks(page), "| overflow", await page.evaluate(() => document.documentElement.scrollWidth - innerWidth), "| small targets", await smallTargets(page));
    await page.locator(".card").first().screenshot({ path: shot(`${name}-scatter-cash-rank`) });
    await heat(page).getByRole("button", { name: "Match wins", exact: true }).tap();
    await settled(page);
    console.log(name, "match rank y ticks", await yTicks(page), "| overflow", await page.evaluate(() => document.documentElement.scrollWidth - innerWidth), "| small targets", await smallTargets(page));
    await page.locator(".card").first().screenshot({ path: shot(`${name}-scatter-matches-rank`) });
  });
  await check("tour", () => checkTour(page, name));

  await page.context().close();
};

// An optional section's data failing to load leaves the rest of the page drawn and says, in that section, what failed.
const checkOptionalFailure = async (browser: Browser) => {
  const page = await newPage(browser, VIEWPORTS[0]);

  await page.route("**/api/consistency", (route) => route.abort());
  await page.route("**/api/blunders", (route) => route.fulfill({ status: 500, body: "" }));
  await loadPage(page);
  await settled(page);

  const notes = await page.getByText(/^Could not load the /).allInnerTexts();

  console.log("with blunders and consistency failing:", notes, "| leaderboards", await countOf(page, "table.lbt"));
  expectThat(notes.length === 3 && (await page.locator("#blunders").getByText(/^Could not load/).count()) === 1 && (await page.locator("#mistakes").getByText(/^Could not load/).count()) === 1, "a failed optional endpoint did not leave a note in its own section");
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
