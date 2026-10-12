import { chromium, type Page } from "playwright-core";

// Drives the running dev server in a headless browser: one human-vs-bot match
// played by clicking move buttons, then one all-bot match on autoplay.
// Usage: bun run dev (elsewhere), then bun scripts/play.ts [url] [outdir]

const url = process.argv[2] ?? "http://localhost:5173/";

const outdir = process.argv[3] ?? "/tmp/buckshot-web-shots";

const chrome = process.env["CHROME"] ?? "/Applications/Google Chrome.app/Contents/MacOS/Google Chrome";

const CLICK_LIMIT = 2_000;

const browser = await chromium.launch({ executablePath: chrome, headless: true });

const page = await browser.newPage({ viewport: { width: 1360, height: 900 } });

const problems: Array<string> = [];

page.on("console", (message) => {
  if (message.type() === "error" || message.type() === "warning") problems.push(message.text());
});

page.on("pageerror", (error) => problems.push(error.message));

const shot = async (name: string): Promise<void> => {
  await page.screenshot({ path: `${outdir}/${name}.png`, fullPage: true });
};

const isOver = async (current: Page): Promise<boolean> => (await current.locator("section.results").count()) > 0;

await page.goto(url);

await shot("01-empty");

await page.getByRole("button", { name: "Start match" }).click();

await shot("02-human-vs-bot-start");

// One synchronous DOM action per frame, so a click never lands on a view
// that Foldkit is about to replace.
const act = (current: Page): Promise<string> =>
  current.evaluate(async () => {
    await new Promise((resolve) => requestAnimationFrame(() => requestAnimationFrame(resolve)));

    if (document.querySelector("section.results") !== null) return "over";

    const moves = [...document.querySelectorAll<HTMLButtonElement>(".move-list button")];
    const step = document.querySelector<HTMLButtonElement>(".bot-controls button");
    const move = moves[Math.floor(Math.random() * moves.length)];

    if (move !== undefined) {
      move.click();

      return "move";
    }

    if (step !== null && !step.disabled) {
      step.click();

      return "step";
    }

    return "idle";
  });

let clicks = 0;

for (; clicks < CLICK_LIMIT; clicks++) {
  const action = await act(page);

  if (action === "over") break;

  if (action === "idle") {
    await shot("xx-no-action");
    throw new Error(`no move and no bot step after ${clicks} clicks`);
  }

  if (clicks === 6) await shot("03-human-vs-bot-mid");
}

await shot("04-human-vs-bot-end");

console.log(`human vs bot: ${clicks} clicks, over: ${await isOver(page)}`);

await page.getByRole("button", { name: "4" }).click();

await page.locator(".controllers button").nth(3).waitFor();

for (const seat of [0, 1, 2, 3]) {
  const toggle = page.locator(".controllers button").nth(seat);

  if ((await toggle.textContent())?.includes("Human") === true) {
    await toggle.click();
    await toggle.filter({ hasText: "Bot" }).waitFor();
  }
}

await page.getByRole("button", { name: "Restart match" }).click();

await page.getByRole("button", { name: "Spectator" }).click();

await page.getByRole("button", { name: "Autoplay bots" }).click();

await page.waitForTimeout(3_000);

await shot("05-bots-autoplay");

await page.locator("section.results").waitFor({ timeout: 600_000 });

await shot("06-bots-end");

console.log("bots: over");

console.log(problems.length === 0 ? "no console errors" : `console problems:\n${problems.join("\n")}`);

await browser.close();
