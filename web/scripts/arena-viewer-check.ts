import { mkdirSync } from "node:fs";
import { join } from "node:path";

import { type Browser, chromium, type Page } from "playwright-core";

// Clicks through the arena viewer's page, its jump menu and replay in headless Chromium at
// desktop, phone and tablet widths and saves screenshots. Pointed at the old viewer too,
// it gives the pictures to compare against.
// Usage: bun scripts/arena-viewer-check.ts <url> [outdir]

const base = process.argv[2] ?? "http://127.0.0.1:8790";
const outdir = process.argv[3] ?? "/tmp/arena-viewer-shots";
const chrome = process.env["CHROME"] ?? "/etc/profiles/per-user/aditya/bin/chromium";
const errors: Array<string> = [];
const failures: Array<string> = [];

const expectThat = (isOk: boolean, what: string) => {
  if (!isOk) failures.push(what);
};

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

const fullPageShot = (page: Page, name: string) => page.screenshot({ path: shot(name), fullPage: true });

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

const heat = (page: Page) => page.locator("section").filter({ has: page.locator("table.heat") });

// Prints what the default filter shows (every config), then what switching 'all configs' off hides, and switches it back on.
const openPage = async (page: Page) => {
  const started = Date.now();

  await page.goto(`${base}/`);
  await page.waitForSelector("table.lbt", { timeout: 120_000 });
  console.log("every section drawn in", Date.now() - started, "ms");
  await page.waitForSelector(".icard svg rect", { timeout: 60_000 });

  const counts = async () => ["scatter points", await countOf(page, ".card svg g.pt"), "heat rows", await countOf(page, "table.heat tbody tr"), "leaderboards", await countOf(page, "table.lbt"), "|", await page.locator(".filters .switch").allInnerTexts()];
  const allConfigs = page.getByRole("switch", { name: /all configs/ });

  console.log("default (all configs):", ...(await counts()));

  // The switch is drawn only while some config is hidden, which no config is once every config has cross-model games.
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

const SECTIONS = ["scatter", "interesting", "seats", "rubbers", "reliability", "matches", "leaderboards", "breakdown"] as const;

// How far a section's top sits below the sticky bar after a jump (0 or 1 is right), and whether the URL names it.
const jumpedTo = (page: Page, section: string) =>
  page.evaluate((id) => {
    const bar = [...document.querySelectorAll(".top, nav")].find((element) => getComputedStyle(element).position === "sticky");
    const top = document.getElementById(id)?.getBoundingClientRect().top ?? Number.NaN;

    return `${id}: ${Math.round(top - (bar?.getBoundingClientRect().bottom ?? 0))}px below the bar, hash ${location.hash}`;
  }, section);

const checkJumps = async (page: Page, name: string, isTouch: boolean) => {
  for (const section of SECTIONS) {
    const link = page.locator(`nav a[href="#${section}"]`);

    await (isTouch ? link.tap() : link.click());
    await settled(page);
    console.log(name, "jump", await jumpedTo(page, section));

    if (section === "seats" || section === "rubbers" || section === "reliability" || section === "matches") await page.screenshot({ path: shot(`${name}-${section}`) });
  }
};

// The rating axis's tick labels from the top down.
const yTicks = (page: Page) =>
  page.evaluate(() =>
    [...document.querySelectorAll(".card svg > g:not(.ptlabel) > text[text-anchor=end]")]
      .map((text) => ({ y: Number(text.getAttribute("y")), label: text.textContent ?? "" }))
      .toSorted((left, right) => left.y - right.y)
      .map(({ label }) => label)
      .slice(0, 6)
      .join(" "),
  );

// The scatter's gridlines and tick labels: a filter must leave them where they are.
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

// Turning chips and switches on and off shows and hides points but moves no axis.
const checkFixedAxes = async (page: Page, scatter: ReturnType<Page["locator"]>) => {
  const filters = page.locator(".filters");

  const steps: ReadonlyArray<readonly [string, () => Promise<void>]> = [
    ["max off", () => filters.getByRole("button", { name: "max", exact: true }).click()],
    ["Opus off", () => filters.getByRole("button", { name: /Opus/ }).click()],
    ["medium only", () => scatter.getByRole("switch", { name: /medium only/ }).check()],
    ["back", () => scatter.getByRole("switch", { name: /medium only/ }).uncheck()],
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
  await scatter.screenshot({ path: shot("scatter-rank") });
  await heat(page).screenshot({ path: shot("heat-rank"), style: UNSTICK });
  await page.locator(".lb").screenshot({ path: shot("leaderboard-rank"), style: UNSTICK });
  await page.locator(".lb").getByRole("button", { name: "Elo", exact: true }).click();
  await settled(page);
  console.log("back to Elo from the leaderboard:", await textOf(page, ".card h2"));
};

// Under every cohort choice, either rating basis and either ranking, every config the page draws has an Elo and a
// rank: no dash in the heatmap or the leaderboards, and the same points in the scatter. In Elo the cohort choice
// leaves the axes where they are.
const checkEveryConfigRated = async (page: Page, scatter: ReturnType<Page["locator"]>) => {
  const cohorts = await page.locator(".filters select option").evaluateAll((options) => options.map((option) => option.getAttribute("value") ?? ""));
  const dashes = (selector: string) => page.locator(selector).evaluateAll((cells) => cells.filter((cell) => cell.textContent?.trim() === "–").length);

  for (const basis of ["Wins", "Cash", "Rounds"] as const) {
    const axesByCohort = new Set<string>();

    await scatter.getByRole("button", { name: basis, exact: true }).click();

    for (const cohort of cohorts) {
      await page.locator(".filters select").selectOption(cohort);

      for (const ranking of ["Elo", "Rank"] as const) {
        await scatter.getByRole("button", { name: ranking, exact: true }).click();
        await settled(page);

        const label = ranking === "Rank" ? "rank" : basis === "Wins" ? "Elo" : `${basis} Elo`;
        const rows = await countOf(page, "table.heat tbody tr");
        const missing = (await dashes("table.heat td.total")) + (await dashes(`table.lbt td[data-label="${label}"]`));
        const points = await countOf(page, ".card svg g.pt");
        const unlisted = await page.locator("table.heat td.total").evaluateAll((cells) => cells.filter((cell) => cell.textContent?.trim() === "").length);

        console.log("cohort", cohort, basis, ranking, "| heat rows", rows, "| scatter points", points, "| rows without a rating", missing + unlisted);
        expectThat(missing + unlisted === 0, `${cohort} ${basis} ${ranking}: a config shows a dash instead of a rating`);

        if (ranking === "Elo" && points > 0) axesByCohort.add(await axesOf(page));
      }
    }

    expectThat(axesByCohort.size <= 1, `${basis} scatter axes moved with the cohort choice (${axesByCohort.size} different sets)`);
    await page.locator(".filters select").selectOption("all");
  }

  await scatter.getByRole("button", { name: "Wins", exact: true }).click();
  await scatter.getByRole("button", { name: "Elo", exact: true }).click();
  await settled(page);
};

const ratingViews = async (page: Page) => ({
  scatter: await textOf(page, ".card h2"),
  heat: await textOf(page, "table.heat thead th:nth-last-child(2)"),
  leaderboard: await textOf(page, "table.lbt thead th.rating"),
  firstRow: await textOf(page, "table.lbt tbody tr.row"),
  heatFirstRow: await textOf(page, "table.heat tbody tr"),
  toggles: await page.locator(".toggle button.on", { hasText: /^(Wins|Cash|Rounds)$/ }).allInnerTexts(),
});

// The Wins / Cash choice drives the scatter, the heatmap and the leaderboards together, the leaderboards show every
// config's pot share beside its win share, and the axes stay put under filters on the cash rating too.
const checkCash = async (page: Page, scatter: ReturnType<Page["locator"]>) => {
  const wins = await ratingViews(page);

  console.log("Wins:", wins);
  await scatter.getByRole("button", { name: "Cash", exact: true }).click();
  await settled(page);

  const cash = await ratingViews(page);

  console.log("Cash:", cash);
  expectThat(cash.scatter.includes("Cash Elo") && cash.heat === "Cash Elo" && cash.leaderboard === "Cash Elo", "the Cash choice did not reach the scatter, the heatmap and the leaderboards");
  expectThat(!wins.scatter.includes("Cash") && wins.heat === "Elo" && wins.leaderboard === "Elo", "the page does not start on the win rating");
  expectThat(cash.firstRow !== wins.firstRow && cash.heatFirstRow !== wins.heatFirstRow, "the cash rating left the leaderboard or heatmap rows as they were");
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

  await heat(page).getByRole("button", { name: "Wins", exact: true }).click();
  await settled(page);

  const back = await ratingViews(page);

  expectThat(JSON.stringify(back) === JSON.stringify(wins), "Wins did not bring the page back to how it started");
};

// Rounds is the third rating choice: it reaches the scatter, the heatmap and the leaderboards, every leaderboard row shows
// a round share, and the click that first fits it is timed.
const checkRounds = async (page: Page, scatter: ReturnType<Page["locator"]>) => {
  const wins = await ratingViews(page);
  const clicked = Date.now();

  await scatter.getByRole("button", { name: "Rounds", exact: true }).click();
  await settled(page);
  console.log("Rounds fitted and drawn in", Date.now() - clicked, "ms");

  const rounds = await ratingViews(page);

  console.log("Rounds:", rounds);
  expectThat(rounds.scatter.includes("Rounds Elo") && rounds.heat === "Rounds Elo" && rounds.leaderboard === "Rounds Elo", "the Rounds choice did not reach the scatter, the heatmap and the leaderboards");
  expectThat(rounds.firstRow !== wins.firstRow && rounds.heatFirstRow !== wins.heatFirstRow, "the rounds rating left the leaderboard or heatmap rows as they were");
  expectThat(rounds.toggles.length === 3 && rounds.toggles.every((text) => text === "Rounds"), `Rounds toggles on: ${rounds.toggles.join(" ")}`);

  const shares = await page.locator('table.lbt td[data-label="round share"]').allInnerTexts();
  const rows = await countOf(page, "table.lbt tbody tr.row");

  console.log("round share cells", shares.length, "of", rows, "rows, first", shares.slice(0, 6).join(" "));
  expectThat(shares.length === rows && shares.every((text) => /^\d+%$/.test(text.trim())), "a leaderboard row has no round share");

  await page.locator(".lb").getByRole("button", { name: "Rank", exact: true }).click();
  await settled(page);
  console.log("Rounds rank:", await textOf(page, "table.lbt tbody tr.row"), "| heat header", await textOf(page, "table.heat thead th:nth-last-child(2)"));
  await scatter.screenshot({ path: shot("scatter-rounds-rank") });
  await page.locator(".lb").getByRole("button", { name: "Elo", exact: true }).click();
  await settled(page);
  await scatter.screenshot({ path: shot("scatter-rounds") });
  await heat(page).screenshot({ path: shot("heat-rounds"), style: UNSTICK });
  await page.locator(".lb").screenshot({ path: shot("leaderboard-rounds"), style: UNSTICK });
  await checkFixedAxes(page, scatter);

  await heat(page).getByRole("button", { name: "Wins", exact: true }).click();
  await settled(page);
  expectThat(JSON.stringify(await ratingViews(page)) === JSON.stringify(wins), "Wins did not bring the page back to how it started after Rounds");
};

const REGRET_TAG = /^regret \d+\.\d( · exact)?$/;

const regretTags = (page: Page) => page.locator(".modal .step .tag.regret");

// With a regret database every leaderboard row shows its mean regret, or a dash when none of its moves were searched, and
// the replay marks each searched model move with its regret: a proven exact one apart from the rest, and the open move
// says which it is. Without one the page shows no regret at all.
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

  const means = await page.locator("table.lbt").evaluateAll((tables) =>
    tables.map((table) => Object.fromEntries([...table.querySelectorAll("tr.row")].map((row) => [row.querySelector("td")?.textContent?.trim() ?? "", Number(row.querySelector('td[data-label="regret"]')?.textContent)]))),
  );

  const cross = means.find((table) => "Opus 5.5 [medium]" in table && "Haiku 4.5 [medium]" in table);

  const [opus, haiku] = [cross?.["Opus 5.5 [medium]"] ?? Number.NaN, cross?.["Haiku 4.5 [medium]"] ?? Number.NaN];

  console.log("cross-model medium regret: Opus", opus, "Haiku 4.5", haiku);
  expectThat(Number.isNaN(opus + haiku) || opus < haiku, "Opus does not have less mean regret than Haiku 4.5");
  await page.locator(".lb").first().screenshot({ path: shot("leaderboard-regret"), style: UNSTICK });

  let exact = 0;
  let notExact = 0;

  for (const row of [0, 1, 2, 3, 4]) {
    await page.locator("#matches tbody tr.row").nth(row).click();
    await page.waitForSelector(".modal .step");

    const tags = await regretTags(page).allInnerTexts();
    const steps = await countOf(page, ".modal .step");

    expectThat(tags.every((text) => REGRET_TAG.test(text.trim())), `match ${row}: regret tags ${tags.slice(0, 3).join(" | ")}`);
    expectThat(tags.length <= steps, `match ${row}: more regret tags than moves`);
    exact += tags.filter((text) => text.includes("exact")).length;
    notExact += tags.filter((text) => !text.includes("exact")).length;

    for (const kind of ["exact", "not exact"] as const) {
      const step = page.locator(".modal .step").filter({ has: kind === "exact" ? page.locator(".tag.regret.exact") : page.locator(".tag.regret:not(.exact)") }).first();

      if ((await step.count()) === 0) continue;

      await step.click();
      await settled(page);

      const detail = await textOf(page, ".modal .step.on .sd");
      const says = /not proven exact/.test(detail) ? "not exact" : /proven exact/.test(detail) ? "exact" : "neither";

      expectThat(/Best move .+ chosen [\d.]+% · depth \d/.test(detail) && says === kind, `match ${row}: a ${kind} move's detail says ${says}: ${detail.slice(0, 120)}`);

      if (row === 0) await page.locator(".modal").screenshot({ path: shot(`replay-regret-${kind.replace(" ", "-")}`) });
    }

    console.log("match", row, "regret tags", tags.length, "of", steps, "steps, first", tags.slice(0, 3).join(" | "));
    await page.keyboard.press("Escape");
  }

  console.log("regret tags over those matches:", exact, "exact,", notExact, "not proven exact");
  expectThat(exact + notExact > 0, "no replay shows a regret tag");
};

const checkDesktop = async (browser: Browser) => {
  const page = await browser.newPage({ viewport: { width: 1500, height: 1000 } });
  const scatter = page.locator(".card").first();

  watch(page, "desktop");
  await openPage(page);
  console.log("scatter points", await countOf(page, ".card svg g[style*=pointer]"), "labels", await countOf(page, ".card svg g.ptlabel"), "| toggles:", await textOf(page, ".card .ctl"));
  await fullPageShot(page, "page");
  await scatter.screenshot({ path: shot("scatter") });
  await page.locator(".card svg g[style*=pointer]").nth(3).hover({ force: true });
  console.log("hover point → tip:", await tipOf(page));
  await page.mouse.move(0, 0);
  await page.getByRole("switch", { name: /medium only/ }).check();
  console.log("medium only labels", await countOf(page, ".card svg g.ptlabel"));
  await scatter.screenshot({ path: shot("scatter-medium") });
  await page.getByRole("switch", { name: /medium only/ }).uncheck();

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

  await checkFixedAxes(page, scatter);
  await checkRanking(page, scatter);
  await checkCash(page, scatter);
  await checkRounds(page, scatter);
  await checkEveryConfigRated(page, scatter);
  await checkRegret(page);

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
  await heat(page).getByRole("button", { name: "Choice patterns" }).click();
  await page.locator("table.heat td.click").first().hover();
  console.log("hover cell → tip:", await tipOf(page));
  await page.locator("table.heat td.click").first().click();
  await page.waitForSelector(".flagged tr.row");
  console.log("flagged rows", await countOf(page, ".flagged tr.row"));
  await page.locator(".igrid").screenshot({ path: shot("interesting") });
  console.log("cards", (await page.locator(".icard").allInnerTexts()).map((text) => text.replaceAll(/\s+/g, " ")));
  await page.locator("table.lbt tr.row").first().click();
  await page.locator(".drillin .sq i").first().hover();
  console.log("drill → tip:", await tipOf(page));
  await page.locator(".lb").first().screenshot({ path: shot("leaderboard"), style: UNSTICK });

  for (const [card, name] of [
    [0, "replay"],
    [4, "replay-blunder"],
  ] as const) {
    await page.locator(".icard").nth(card).click();
    await page.waitForSelector(".modal .step");

    for (let step = 0; step < (card === 0 ? 6 : 0); step++) await page.keyboard.press("ArrowRight");

    console.log(name, "steps", await countOf(page, ".modal .step"), "| on:", await textOf(page, ".modal .step.on .h"), "| reasoning blocks", await countOf(page, ".modal .step.on pre"), "| same-seed chips", await countOf(page, ".seedrow .chip"));
    await page.locator(".modal").screenshot({ path: shot(name) });
    await page.keyboard.press("Escape");
  }

  await page.locator(".flagged tr.row").first().click();
  await page.waitForSelector(".modal .step.on");
  console.log("focused move", await textOf(page, ".modal .step.on .h"));
  await page.locator(".seedrow .chip").first().click();
  await page.waitForSelector(".modal .step");
  await settled(page);
  console.log("after same-seed chip:", await textOf(page, ".mhead h2"));
  await page.keyboard.press("Escape");

  console.log("matches", await countOf(page, "#matches tbody tr.row"), "| seats", await countOf(page, "#seats .bignum"), "| reliability charts", await countOf(page, "#reliability .chartrow figure"));
  await checkJumps(page, "desktop", false);
  console.log("the filters stay in view:", await page.evaluate(() => Math.round(document.querySelector(".filters")?.getBoundingClientRect().top ?? -1)), "px from the top at scroll", await page.evaluate(() => Math.round(scrollY)));
  await page.locator("#reliability details.tables > summary").click();
  await page.locator("#reliability tbody td[data-label='failed calls']").first().hover();
  console.log("reliability tip:", await tipOf(page));
  await page.locator("#matches tbody tr.row").first().click();
  await page.waitForSelector(".modal .step");
  console.log("matches → modal", await textOf(page, ".mhead h2"));
  await page.keyboard.press("Escape");

  // An old tab link, or a section link, lands on its section once the data is in.
  await page.goto(`${base}/#reliability`);
  await page.waitForSelector("#reliability .chartrow figure", { timeout: 120_000 });
  await settled(page);
  await settled(page);
  console.log("deep link", await jumpedTo(page, "reliability"));
  await page.close();
};

const checkTouch = async (browser: Browser, name: string, width: number, height: number) => {
  const context = await browser.newContext({ viewport: { width, height }, deviceScaleFactor: 2, isMobile: true, hasTouch: true });
  const page = await context.newPage();
  const stickyModelColumn = () => page.evaluate(() => getComputedStyle(document.querySelector("table.heat td.left") ?? document.body).position);

  watch(page, name);
  await openPage(page);
  console.log(name, "overflow", await page.evaluate(() => document.documentElement.scrollWidth - innerWidth), "| small targets", await smallTargets(page), "| heat model column", await stickyModelColumn(), "| scatter labels", await countOf(page, ".card svg g.ptlabel"));
  await fullPageShot(page, `${name}-page`);
  await page.locator(".card svg g[style*=pointer]").nth(3).tap({ force: true });
  console.log(name, "tap point → tip:", await tipOf(page));
  await page.locator(".card").first().screenshot({ path: shot(`${name}-scatter`) });
  await page.locator(".hero").tap();
  console.log(name, "tap outside clears the tip:", (await tipOf(page)) === "none");
  await heat(page).getByRole("button", { name: "Item use when legal" }).tap();
  await settled(page);
  await heat(page).locator(".heatscroll").evaluate((element) => element.scrollTo({ left: 200 }));
  await heat(page).screenshot({ path: shot(`${name}-heat-items`) });
  await page.locator("table.lbt").first().screenshot({ path: shot(`${name}-leaderboard`) });
  await page.locator(".icard").first().tap();
  await page.waitForSelector(".modal .step");

  const box = await page.locator(".modal").boundingBox();
  const before = await textOf(page, ".modal .stepper .k");

  await page.locator(".stepper button", { hasText: "Next" }).tap();
  await page.locator(".stepper button", { hasText: "Next" }).tap();
  await settled(page);
  console.log(name, "replay", `${box?.width}x${box?.height}`, "| stepper", before, "→", await textOf(page, ".modal .stepper .k"), "| on:", await textOf(page, ".modal .step.on .h"), "| small targets", await smallTargets(page));
  await page.screenshot({ path: shot(`${name}-replay`) });

  const crowded = await page.locator(".modal .step .h").evaluateAll((headers) => headers.filter((header) => header.scrollWidth > header.clientWidth).length);

  console.log(name, "regret tags", await regretTags(page).count(), "| move headers wider than the modal", crowded);
  expectThat(crowded === 0, `${name}: a move header overflows with its regret tag`);
  await page.goBack();
  console.log(name, "back closes replay:", (await countOf(page, ".modal")) === 0);

  await checkJumps(page, name, true);
  console.log(name, "overflow after every section", await page.evaluate(() => document.documentElement.scrollWidth - innerWidth), "| small targets", await smallTargets(page));
  await heat(page).getByRole("button", { name: "Rank", exact: true }).tap();
  await settled(page);
  console.log(name, "rank y ticks", await yTicks(page));
  await page.locator(".card").first().screenshot({ path: shot(`${name}-scatter-rank`) });
  await heat(page).getByRole("button", { name: "Cash", exact: true }).tap();
  await settled(page);
  console.log(name, "cash rank y ticks", await yTicks(page), "| overflow", await page.evaluate(() => document.documentElement.scrollWidth - innerWidth), "| small targets", await smallTargets(page));
  await page.locator(".card").first().screenshot({ path: shot(`${name}-scatter-cash-rank`) });
  await heat(page).getByRole("button", { name: "Rounds", exact: true }).tap();
  await settled(page);
  console.log(name, "rounds rank y ticks", await yTicks(page), "| overflow", await page.evaluate(() => document.documentElement.scrollWidth - innerWidth), "| small targets", await smallTargets(page));
  await page.locator(".card").first().screenshot({ path: shot(`${name}-scatter-rounds-rank`) });

  await context.close();
};

mkdirSync(outdir, { recursive: true });

const browser = await chromium.launch({ executablePath: chrome, args: ["--no-sandbox"] });

await checkDesktop(browser);

for (const [name, width, height] of [
  ["phone", 390, 844],
  ["small", 360, 800],
  ["tablet", 768, 1024],
] as const) {
  await checkTouch(browser, name, width, height);
}

console.log("failed checks", failures);

console.log("errors", errors, "| negative widths while a screenshot resized the window:", screenshotResizeErrors);

await browser.close();

if (failures.length > 0 || errors.length > 0) process.exitCode = 1;
