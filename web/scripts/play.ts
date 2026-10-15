import { chromium, firefox, type Page } from "playwright-core";

// Drives the running dev server in headless Chrome: one human-vs-DoN match
// with items, played by clicking the things on the table (the shotgun, the
// seats, the item slots, the briefcase), then one 4-seat all-bot match with
// items on fast autoplay.
// Usage: bun run dev (elsewhere), then bun scripts/play.ts [url] [outdir]
// BROWSER=firefox uses Playwright's Firefox (FIREFOX=path to its binary if it is not the installed revision).

const url = process.argv[2] ?? "http://localhost:5173/";

const outdir = process.argv[3] ?? "/tmp/buckshot-web-shots";

const chrome = process.env["CHROME"] ?? "/Applications/Google Chrome.app/Contents/MacOS/Google Chrome";

const CLICK_LIMIT = 2_000;

/** Polls without a click before the script gives up: the bots should move well within this. */
const IDLE_LIMIT = 400;

const browser =
  process.env["BROWSER"] === "firefox"
    ? await firefox.launch({ executablePath: process.env["FIREFOX"] ?? firefox.executablePath(), headless: true })
    : await chromium.launch({ executablePath: chrome, headless: true });

const page = await browser.newPage({ viewport: { width: 1360, height: 900 } });

const problems: Array<string> = [];

page.on("console", (message) => {
  if (message.type() === "error" || (message.type() === "warning" && !message.text().includes("[foldkit] Slow"))) problems.push(message.text());
});

page.on("pageerror", (error) => problems.push(error.message));

const shot = async (name: string): Promise<void> => {
  await page.screenshot({ path: `${outdir}/${name}.png` });
};

const setSpeed = async (speed: string): Promise<void> => {
  await page.locator("details.menu summary").click();
  await page.getByRole("group", { name: "Speed" }).getByRole("button", { name: speed }).click();
  await page.locator("details.menu summary").click();
};

await page.goto(url);

await shot("01-setup");

await page.getByRole("button", { name: "Start match" }).click();

await setSpeed("Fast");

// One synchronous DOM action per frame, so a click never lands on a view
// that Foldkit is about to replace. The moves are the buttons on the table,
// plus any plain buttons for moves that share a target.
const act = (current: Page): Promise<string> =>
  current.evaluate(async () => {
    await new Promise((resolve) => requestAnimationFrame(() => requestAnimationFrame(resolve)));

    if (document.querySelector("section.results") !== null) return "over";

    const moves = [...document.querySelectorAll<HTMLButtonElement>(".stage button.hot, .loose-moves button")];
    const move = moves[Math.floor(Math.random() * moves.length)];

    if (move === undefined) return "idle";

    move.click();

    return "move";
  });

let clicks = 0;

for (let idle = 0; clicks < CLICK_LIMIT && idle < IDLE_LIMIT; ) {
  const action = await act(page);

  if (action === "over") break;

  if (action === "idle") {
    idle += 1;
    await page.waitForTimeout(25);
  } else {
    idle = 0;
    clicks += 1;
  }

  if (clicks === 6) await shot("02-human-vs-bot-mid");
}

const isOver = (await page.locator("section.results").count()) > 0;

await shot("03-human-vs-bot-end");

console.log(`human vs DoN: ${clicks} clicks, over: ${isOver}`);

if (!isOver) throw new Error(`the human-vs-bot match did not finish after ${clicks} clicks`);

await page.getByRole("button", { name: "Change seats" }).click();

await page.getByRole("button", { name: "4", exact: true }).click();

await page.locator(".controllers button").nth(3).waitFor();

for (const seat of [0, 1, 2, 3]) {
  const toggle = page.locator(".controllers button").nth(seat);

  if ((await toggle.textContent())?.includes("Human") === true) {
    await toggle.click();
    await toggle.filter({ hasText: "Story" }).waitFor();
  }
}

await page.getByRole("button", { name: "Start match" }).click();

await setSpeed("Fast");

await page.waitForTimeout(3_000);

await shot("04-bots-autoplay");

await page.locator("section.results").waitFor({ timeout: 600_000 });

await shot("05-bots-end");

console.log("bots: over");

console.log(problems.length === 0 ? "no console errors" : `console problems:\n${problems.join("\n")}`);

await browser.close();
