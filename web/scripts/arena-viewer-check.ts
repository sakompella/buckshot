import { mkdirSync } from "node:fs";
import { join } from "node:path";

import { type Browser, chromium, type Page } from "playwright-core";

// Clicks through the arena viewer's tabs and replay in headless Chromium at
// desktop, phone and tablet widths and saves screenshots. Pointed at the old viewer too,
// it gives the pictures to compare against.
// Usage: bun scripts/arena-viewer-check.ts <url> [outdir]

const base = process.argv[2] ?? "http://127.0.0.1:8790";
const outdir = process.argv[3] ?? "/tmp/arena-viewer-shots";
const chrome = process.env["CHROME"] ?? "/etc/profiles/per-user/aditya/bin/chromium";
const errors: Array<string> = [];

const shot = (name: string) => join(outdir, `${name}.png`);

const watch = (page: Page, name: string) => {
  page.on("pageerror", (error) => errors.push(`${name}: ${error.message}`));
  page.on("console", (message) => {
    if (message.type() === "error") errors.push(`${name}: ${message.text().slice(0, 200)}`);
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

const heat = (page: Page) => page.locator("section").filter({ has: page.locator("table.heat") });

const openOverview = async (page: Page) => {
  await page.goto(`${base}/#overview`);
  await page.waitForSelector("table.heat tbody tr", { timeout: 120_000 });
  await page.waitForSelector(".icard svg rect", { timeout: 60_000 });
};

// Visible controls smaller than 44px either way (heat cells and leaderboard squares are left out).
const smallTargets = (page: Page) =>
  page.evaluate(() =>
    [...document.querySelectorAll("nav button, .toggle button, .chip, .switch, select, input:not([type=checkbox]), .stepper button, .modal .x")].flatMap((element) => {
      const box = element.getBoundingClientRect();

      return box.width > 0 && (box.height < 44 || box.width < 44) ? [`${element.className || element.tagName} ${element.textContent?.slice(0, 20)} ${Math.round(box.width)}x${Math.round(box.height)}`] : [];
    }),
  );

const checkDesktop = async (browser: Browser) => {
  const page = await browser.newPage({ viewport: { width: 1500, height: 1000 } });
  const scatter = page.locator(".card").first();

  watch(page, "desktop");
  await openOverview(page);
  console.log("scatter points", await countOf(page, ".card svg g[style*=pointer]"), "labels", await countOf(page, ".card svg g.ptlabel"), "| toggles:", await textOf(page, ".card .ctl"));
  await page.screenshot({ path: shot("overview"), fullPage: true });
  await scatter.screenshot({ path: shot("scatter") });
  await page.locator(".card svg g[style*=pointer]").nth(3).hover();
  console.log("hover point → tip:", await tipOf(page));
  await page.mouse.move(0, 0);
  await page.getByRole("switch", { name: /all efforts/ }).check();
  console.log("all efforts labels", await countOf(page, ".card svg g.ptlabel"));
  await scatter.screenshot({ path: shot("scatter-all") });
  await page.getByRole("switch", { name: /medium only/ }).check();
  console.log("medium only labels", await countOf(page, ".card svg g.ptlabel"), "| all efforts on:", await page.getByRole("switch", { name: /all efforts/ }).isChecked());
  await scatter.screenshot({ path: shot("scatter-medium") });
  await page.getByRole("switch", { name: /medium only/ }).uncheck();

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
  await page.locator(".lb").first().screenshot({ path: shot("leaderboard") });

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

  for (const [tab, selector] of [
    ["matches", "tbody tr.row"],
    ["seats", ".bignum"],
    ["reliability", ".chartrow figure"],
  ] as const) {
    await page.goto(`${base}/#${tab}`);
    await page.waitForSelector(selector, { timeout: 120_000 });
    console.log(tab, selector, await countOf(page, selector));
    await page.screenshot({ path: shot(tab), fullPage: true });
  }

  await page.locator("details.tables > summary").click();
  await page.locator("tbody td[data-label='failed calls']").first().hover();
  console.log("reliability tip:", await tipOf(page));
  await page.goto(`${base}/#matches`);
  await page.locator("tbody tr.row").first().click();
  await page.waitForSelector(".modal .step");
  console.log("matches → modal", await textOf(page, ".mhead h2"));
  await page.close();
};

const checkTouch = async (browser: Browser, name: string, width: number, height: number) => {
  const context = await browser.newContext({ viewport: { width, height }, deviceScaleFactor: 2, isMobile: true, hasTouch: true });
  const page = await context.newPage();
  const stickyModelColumn = () => page.evaluate(() => getComputedStyle(document.querySelector("table.heat td.left") ?? document.body).position);

  watch(page, name);
  await openOverview(page);
  console.log(name, "overflow", await page.evaluate(() => document.documentElement.scrollWidth - innerWidth), "| small targets", await smallTargets(page), "| heat model column", await stickyModelColumn(), "| scatter labels", await countOf(page, ".card svg g.ptlabel"));
  await page.screenshot({ path: shot(`${name}-overview`), fullPage: true });
  await page.locator(".card svg g[style*=pointer]").nth(3).tap();
  console.log(name, "tap point → tip:", await tipOf(page));
  await page.locator(".card").first().screenshot({ path: shot(`${name}-scatter`) });
  await page.locator(".hero").tap();
  console.log(name, "tap outside clears the tip:", (await tipOf(page)) === "none");
  await heat(page).getByRole("button", { name: "Item use when legal" }).tap();
  await settled(page);
  await heat(page).locator(".heatscroll").evaluate((element) => element.scrollTo({ left: 200 }));
  await heat(page).screenshot({ path: shot(`${name}-heat-items`) });
  await page.locator(".icard").first().tap();
  await page.waitForSelector(".modal .step");

  const box = await page.locator(".modal").boundingBox();
  const before = await textOf(page, ".modal .stepper .k");

  await page.locator(".stepper button", { hasText: "Next" }).tap();
  await page.locator(".stepper button", { hasText: "Next" }).tap();
  await settled(page);
  console.log(name, "replay", `${box?.width}x${box?.height}`, "| stepper", before, "→", await textOf(page, ".modal .stepper .k"), "| on:", await textOf(page, ".modal .step.on .h"), "| small targets", await smallTargets(page));
  await page.screenshot({ path: shot(`${name}-replay`) });
  await page.goBack();
  console.log(name, "back closes replay:", (await countOf(page, ".modal")) === 0);

  for (const [tab, selector] of [
    ["matches", "tbody tr"],
    ["seats", ".bignum"],
    ["reliability", ".chartrow figure"],
  ] as const) {
    await page.goto(`${base}/#${tab}`);
    await page.waitForSelector(selector, { timeout: 120_000 });
    console.log(name, tab, "overflow", await page.evaluate(() => document.documentElement.scrollWidth - innerWidth), "| small targets", await smallTargets(page));
    await page.screenshot({ path: shot(`${name}-${tab}`), fullPage: true });
  }

  await page.evaluate(() => scrollTo(0, 3000));
  await page.locator("nav button", { hasText: "Matches" }).tap();
  console.log(name, "a tab opens at its top:", await page.evaluate(() => scrollY) === 0);

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

console.log("errors", errors);

await browser.close();
