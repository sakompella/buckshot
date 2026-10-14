import { chromium, firefox } from "playwright-core";

// Screenshots of each stage of a human-vs-DoN match with items, for judging the
// look: setup, load reveal, grabbing, your turn, aiming, a shot, round over and
// match over. The human picks up the shotgun and shoots the other seat when it
// can, so every stage shows up.
// Usage: bun run dev (elsewhere), then bun scripts/shots.ts [url] [outdir] [WIDTHxHEIGHT ...]
// MOTION=reduce emulates prefers-reduced-motion. BROWSER=firefox uses Playwright's
// Firefox (FIREFOX=path to its binary if it is not the installed revision).

const url = process.argv[2] ?? "http://localhost:5173/";

const outdir = process.argv[3] ?? "/tmp/buckshot-web-game-shots";

const sizes = process.argv.length > 4 ? process.argv.slice(4) : ["1440x900", "390x844"];

const chrome = process.env["CHROME"] ?? "/Applications/Google Chrome.app/Contents/MacOS/Google Chrome";

const STEP_LIMIT = 3_000;

const browser =
  process.env["BROWSER"] === "firefox"
    ? await firefox.launch({ executablePath: process.env["FIREFOX"] ?? firefox.executablePath(), headless: true })
    : await chromium.launch({ executablePath: chrome, headless: true });

const run = async (size: string): Promise<void> => {
  const [width = 1440, height = 900] = size.split("x").map(Number);
  const page = await browser.newPage({ viewport: { width, height }, reducedMotion: process.env["MOTION"] === "reduce" ? "reduce" : "no-preference" });
  const taken = new Set<string>();

  const shot = async (name: string): Promise<void> => {
    if (taken.has(name)) return;

    taken.add(name);
    await page.screenshot({ path: `${outdir}/${size}-${name}.png` });
  };

  page.on("pageerror", (error) => console.log(`${size} page error: ${error.message}`));

  await page.goto(url);
  await page.waitForTimeout(300);
  await shot("1-setup");
  await page.getByRole("button", { name: "Start match" }).click();

  const onTable = (label: string) => page.locator(`.stage button.hot[aria-label="${label}"]`).first();

  const isShowing = (selector: string): Promise<boolean> =>
    page.evaluate((query) => [...document.querySelectorAll(query)].some((element) => Number(getComputedStyle(element).opacity) > 0.6), selector);

  for (let step = 0; step < STEP_LIMIT; step++) {
    await page.waitForTimeout(60);

    if ((await page.locator("section.results").count()) > 0) {
      await page.waitForTimeout(600);
      await shot("8-match-over");
      break;
    }

    // The banner waits for the last shot's labels, and goes when the next move is played.
    if (!taken.has("7-round-over") && (await page.locator(".round-over").count()) > 0) {
      await page.waitForTimeout(2000);
      await shot("7-round-over");
    }

    if (!taken.has("2-load-reveal") && (await isShowing(".reveal"))) {
      await page.waitForTimeout(400);
      await shot("2-load-reveal");
    }

    const labels = await page.locator(".stage button.hot").evaluateAll((buttons) => buttons.map((button) => button.getAttribute("aria-label") ?? ""));

    if (labels.length === 0) continue;

    const has = (prefix: string): string | undefined => labels.find((label) => label.startsWith(prefix));
    const grab = has("Grab");
    const place = has("Place");
    const pickUp = has("Pick up");
    const shoot = labels.find((label) => label.startsWith("Shoot Seat"));
    const choice = grab ?? place ?? (pickUp !== undefined && Math.random() < 0.7 ? pickUp : undefined) ?? shoot ?? labels[Math.floor(Math.random() * labels.length)] ?? "";

    if (place !== undefined) await shot("3-grabbing");

    if (pickUp !== undefined) await shot("4-your-turn");

    if (shoot !== undefined && !taken.has("5-aiming")) {
      await onTable(shoot).hover();
      await page.waitForTimeout(500);
      await shot("5-aiming");
    }

    // A move can vanish between reading the labels and clicking; the next pass reads them again.
    await onTable(choice).click({ timeout: 2_000 }).catch(() => undefined);

    if (choice === shoot && !taken.has("6-shot")) {
      await page.waitForTimeout(420);
      await shot("6-shot");
    }
  }

  console.log(`${size}: ${[...taken].toSorted().join(", ")}`);
  await page.close();
};

for (const size of sizes) await run(size);

await browser.close();
