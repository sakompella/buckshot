import { Schema } from "effect";
import { chromium, type Page } from "playwright-core";

// Plays two matches with items through the WebMCP tools only, in headless
// Chrome with the WebMCP testing feature: a 2-seat match with one Agent seat
// against DoN, and a 3-seat match with two Agent seats and one DoN seat. Chrome 155 has no navigator.modelContextTesting,
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
const callTool = (page: Page, name: string, input: Record<string, number | string | boolean | ReadonlyArray<string>>): Promise<{ readonly ok: boolean; readonly text: string }> =>
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

console.log("get_game with no match:", await callTool(page, "get_game", { seat: 0 }));

console.log("play_move with no match:", await callTool(page, "play_move", { seat: 0, index: 0 }));

console.log("new_match with a bad seed:", await callTool(page, "new_match", { players: 2, items: true, seed: "abc" }));

console.log("new_match with too few controllers:", await callTool(page, "new_match", { players: 3, items: true, controllers: ["Agent"] }));

const Table = Schema.Struct({ seats: Schema.Array(Schema.Struct({ seat: Schema.Number, controller: Schema.String })) });

const parseTable = Schema.decodeUnknownSync(Schema.fromJsonString(Table));

const getView = async (seat: number) => {
  const got = await callTool(page, "get_game", { seat });

  if (!got.ok) throw new Error(`get_game(${seat}) failed: ${got.text}`);

  return parseView(got.text);
};

/** Starts a match and plays every Agent seat through the tools until the match is over. */
const playMatch = async (name: string, input: Record<string, number | string | boolean | ReadonlyArray<string>>): Promise<boolean> => {
  const started = await callTool(page, "new_match", input);

  console.log(`${name} new_match:`, started.text);

  if (!started.ok) throw new Error(`new_match refused: ${started.text}`);

  const table = parseTable(started.text).seats;
  const agents = table.filter(({ controller }) => controller === "Agent").map(({ seat }) => seat);
  const other = table.find(({ controller }) => controller !== "Agent");

  if (other !== undefined) console.log(`${name} get_game for a non-Agent seat:`, await callTool(page, "get_game", { seat: other.seat }));

  await shot(page, `${name}-1-new-match`);

  let calls = 0;
  let moves = 0;
  let sharedTurns = 0;
  let staleRetries = 0;
  let isFirstTurnShown = false;
  let isStaleChecked = false;

  for (; calls < CALL_LIMIT; calls++) {
    const views = await Promise.all(agents.map(async (seat) => ({ seat, view: await getView(seat) })));

    if (views.some(({ view }) => view.isMatchOver)) break;

    const ready = views.filter(({ view }) => view.isYourTurn);

    if (ready.length === 0) {
      await page.waitForTimeout(POLL_MS);
      continue;
    }

    const mover = ready[moves % ready.length];

    if (mover === undefined) throw new Error("no ready agent to move");

    if (!isFirstTurnShown) {
      isFirstTurnShown = true;
      console.log(`${name} first agent turn:`, JSON.stringify(mover.view).slice(0, 1200));
      console.log(`${name} waiting hints:`, await page.getByText("Waiting for the agent").count());
      await shot(page, `${name}-2-agent-turn`);
    }

    if (!isStaleChecked) {
      isStaleChecked = true;
      console.log(`${name} out-of-range move:`, await callTool(page, "play_move", { seat: mover.seat, index: mover.view.moves.length, turn: mover.view.turn }));
      console.log(`${name} stale turn:`, await callTool(page, "play_move", { seat: mover.seat, index: 0, turn: mover.view.turn + 1 }));
      console.log(`${name} bad argument type:`, await callTool(page, "play_move", { seat: mover.seat, index: "zero" }));
    }

    sharedTurns += ready.length > 1 ? 1 : 0;

    const choice = mover.view.moves[(moves * 5 + 1) % mover.view.moves.length];

    if (choice === undefined) throw new Error("agent turn with no legal moves");

    const played = await callTool(page, "play_move", { seat: mover.seat, index: choice.index, turn: mover.view.turn });

    // Another seat can move between get_game and play_move while several seats grab at once; read again.
    if (played.text.includes("Stale move")) {
      staleRetries += 1;
      continue;
    }

    if (!played.ok) throw new Error(`play_move refused: ${played.text}`);

    moves += 1;

    if (moves === 12) await shot(page, `${name}-3-mid-match`);
  }

  const finals = await Promise.all(agents.map(getView));
  const isOver = finals.every((view) => view.isMatchOver);

  console.log(`${name}: match over: ${isOver}, agent seats: ${agents.join(", ")}, agent moves: ${moves}, turns where several agents could move: ${sharedTurns}, stale retries: ${staleRetries}, tool rounds: ${calls}`);

  console.log(`${name} play_move after the end:`, await callTool(page, "play_move", { seat: agents[0] ?? 0, index: 0 }));

  await shot(page, `${name}-4-match-over`);

  console.log(`${name} results shown:`, await page.locator("section.results").count());

  return isOver;
};

const isDuelOver = await playMatch("duel", { players: 2, items: true, seed: "42" });

const isTrioOver = await playMatch("trio", { players: 3, items: true, seed: "42", controllers: ["Agent", "Agent", "DoN"] });

console.log("console problems:", problems);

await browser.close();

if (!isDuelOver || !isTrioOver) process.exit(1);
