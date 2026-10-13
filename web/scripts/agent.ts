import { Schema } from "effect";
import { chromium, type Page } from "playwright-core";

// Plays one 2-seat match with items through the WebMCP tools only, in headless
// Chrome with the WebMCP testing feature. Chrome 155 has no navigator.modelContextTesting,
// so the tools run through document.modelContext.getTools() and executeTool(), as the spec defines.
// Usage: bun run dev -- --port 5177 (elsewhere), then bun scripts/agent.ts [url] [outdir]

const url = process.argv[2] ?? "http://localhost:5177/";

const outdir = process.argv[3] ?? "/tmp/buckshot-web-shots-5";

const chrome = process.env["CHROME"] ?? "/Applications/Google Chrome.app/Contents/MacOS/Google Chrome";

const CALL_LIMIT = 3_000;

const POLL_MS = 100;

const View = Schema.Struct({
  isYourTurn: Schema.Boolean,
  isMatchOver: Schema.Boolean,
  turn: Schema.Number,
  privateNotes: Schema.Array(Schema.String),
  moves: Schema.Array(Schema.Struct({ index: Schema.Number, label: Schema.String })),
});

const parseView = Schema.decodeUnknownSync(Schema.fromJsonString(View));

const problems: Array<string> = [];

const watch = (page: Page): void => {
  page.on("console", (message) => {
    if (message.type() === "error" || message.type() === "warning") problems.push(message.text());
  });
  page.on("pageerror", (error) => problems.push(error.message));
};

/** Runs one tool through the page's own model context. A refusal comes back as text, not a throw. */
const callTool = (page: Page, name: string, input: Record<string, number | string | boolean>): Promise<{ readonly ok: boolean; readonly text: string }> =>
  page.evaluate(
    async ([toolName, args]) => {
      const context = document.modelContext;
      const tool = (await context?.getTools())?.find((candidate) => candidate.name === toolName);

      if (context === undefined || tool === undefined) return { ok: false, text: `tool ${toolName} is not registered` };

      return context.executeTool(tool, args).then(
        (text) => ({ ok: !text.startsWith('{"error"'), text }),
        (error: Error) => ({ ok: false, text: error.message }),
      );
    },
    [name, input] as const,
  );

const shot = async (page: Page, name: string): Promise<void> => {
  await page.screenshot({ path: `${outdir}/${name}.png`, fullPage: true });
};

const launch = (args: ReadonlyArray<string>) => chromium.launch({ executablePath: chrome, headless: true, args: [...args] });

// Without the feature there is no document.modelContext, and the controls say so.
const plain = await launch([]);

const plainPage = await plain.newPage({ viewport: { width: 1360, height: 900 } });

await plainPage.goto(url);

await plainPage.getByRole("button", { name: "Seat 3: DoN" }).click();

await plainPage.getByRole("button", { name: "Seat 3: Agent" }).waitFor();

await shot(plainPage, "01-no-webmcp-hint");

console.log("without the flag:", await plainPage.getByText("WebMCP is not available").count(), "hint(s)");

await plain.close();

const browser = await launch(["--enable-features=WebMCPTesting"]);

const page = await browser.newPage({ viewport: { width: 1360, height: 900 } });

watch(page);

await page.goto(url);

await page.waitForFunction(async () => ((await document.modelContext?.getTools())?.length ?? 0) === 3);

const tools = await page.evaluate(async () => (await document.modelContext?.getTools())?.map(({ name, description, inputSchema }) => ({ name, description, inputSchema })));

console.log("registered tools:", JSON.stringify(tools, null, 2));

await shot(page, "02-flag-on-empty");

console.log("get_game with no match:", await callTool(page, "get_game", {}));

console.log("play_move with no match:", await callTool(page, "play_move", { index: 0 }));

console.log("new_match with a bad seed:", await callTool(page, "new_match", { players: 2, items: true, seed: "abc" }));

const started = await callTool(page, "new_match", { players: 2, items: true, seed: "42" });

console.log("new_match:", started.ok, started.text.slice(0, 400));

await shot(page, "03-new-match");

let calls = 0;

let moves = 0;

let isShotWaiting = false;

let isShotMid = false;

let notStaleChecked = false;

for (; calls < CALL_LIMIT; calls++) {
  const got = await callTool(page, "get_game", {});

  if (!got.ok) throw new Error(`get_game failed: ${got.text}`);

  const view = parseView(got.text);

  if (view.isMatchOver) break;

  if (!view.isYourTurn) {
    await page.waitForTimeout(POLL_MS);
    continue;
  }

  if (!isShotWaiting) {
    isShotWaiting = true;
    console.log("first agent turn:", got.text.slice(0, 1800));
    console.log("waiting hint:", await page.getByText("Waiting for the agent").count());
    await shot(page, "04-agent-turn");
  }

  if (!notStaleChecked) {
    notStaleChecked = true;
    console.log("out-of-range move:", await callTool(page, "play_move", { index: view.moves.length, turn: view.turn }));
    console.log("stale turn:", await callTool(page, "play_move", { index: 0, turn: view.turn + 1 }));
    console.log("bad argument type:", await callTool(page, "play_move", { index: "zero" }));
  }

  const choice = view.moves[(moves * 5 + 1) % view.moves.length];

  if (choice === undefined) throw new Error("agent turn with no legal moves");

  const played = await callTool(page, "play_move", { index: choice.index, turn: view.turn });

  if (!played.ok) throw new Error(`play_move refused: ${played.text}`);

  moves += 1;

  if (!isShotMid && moves === 12) {
    isShotMid = true;
    await shot(page, "05-mid-match");
  }
}

const finalView = parseView((await callTool(page, "get_game", {})).text);

console.log(`match over: ${finalView.isMatchOver}, agent moves: ${moves}, tool calls: ${calls}`);

console.log("play_move after the end:", await callTool(page, "play_move", { index: 0 }));

await shot(page, "06-match-over");

console.log("results shown:", await page.locator("section.results").count());

console.log("console problems:", problems);

await browser.close();

if (!finalView.isMatchOver) process.exit(1);
