import { Schema } from "effect";
import { chromium, type Page } from "playwright-core";

// Plays three matches with items through the WebMCP tools only, in headless
// Chrome with the WebMCP testing feature: a 2-player match with one Agent player
// against DoN, a 3-player match with two Agent players and one DoN player, and that match again with the same seed, where the first match's last turn must be refused. Chrome 155 has no navigator.modelContextTesting,
// so the tools run through document.modelContext.getTools() and executeTool(), as the spec defines.
// Usage: bun run dev -- --port 5177 (elsewhere), then bun scripts/agent.ts [url] [outdir]

const url = process.argv[2] ?? "http://localhost:5177/";

const outdir = process.argv[3] ?? "/tmp/buckshot-web-shots-5";

const chrome = process.env["CHROME"] ?? "/Applications/Google Chrome.app/Contents/MacOS/Google Chrome";

const CALL_LIMIT = 3_000;

const POLL_MS = 100;

const View = Schema.Struct({
  status: Schema.Literals(["your turn", "waiting", "over"]),
  turn: Schema.optionalKey(Schema.Number),
  events: Schema.optionalKey(Schema.Array(Schema.String)),
  moves: Schema.optionalKey(Schema.Array(Schema.String)),
});

const parseView = Schema.decodeUnknownSync(Schema.fromJsonString(View));

const problems: Array<string> = [];

// Anything that names a seat or a Player 0, where people and agents should only see Player 1 to N.
const leaks: Array<string> = [];

const RAW_SEAT = /seat|Player 0/i;

const watch = (page: Page): void => {
  page.on("console", (message) => {
    if (message.type() === "error" || message.type() === "warning") problems.push(message.text());
  });
  page.on("pageerror", (error) => problems.push(error.message));
};

/** Runs one tool through the page's own model context. A refusal comes back as text, not a throw. */
const callTool = async (page: Page, name: string, input: Record<string, number | string | boolean | ReadonlyArray<string>>): Promise<{ readonly ok: boolean; readonly text: string }> => {
  const reply = await page.evaluate(
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

  if (RAW_SEAT.test(reply.text)) leaks.push(`${name}: ${reply.text.slice(0, 200)}`);

  return reply;
};

const shot = async (page: Page, name: string): Promise<void> => {
  const shown = await page.locator("body").innerText();

  if (RAW_SEAT.test(shown)) leaks.push(`${name}: ${shown.match(/.*(?:seat|Player 0).*/i)?.[0]}`);

  await page.screenshot({ path: `${outdir}/${name}.png`, fullPage: true });
};

const launch = (args: ReadonlyArray<string>) => chromium.launch({ executablePath: chrome, headless: true, args: [...args] });

// Without the feature there is no document.modelContext, and the controls say so.
const plain = await launch([]);

const plainPage = await plain.newPage({ viewport: { width: 1360, height: 900 } });

await plainPage.goto(url);

await plainPage.getByRole("button", { name: "Player 2: DoN" }).click();

await plainPage.getByRole("button", { name: "Player 2: Agent" }).waitFor();

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

console.log("get_game with no match:", await callTool(page, "get_game", { player: 1 }));

console.log("play_move with no match:", await callTool(page, "play_move", { player: 1, move: 0, turn: 0 }));

console.log("play_move without a turn:", await callTool(page, "play_move", { player: 1, move: 0 }));

console.log("new_match with a bad seed:", await callTool(page, "new_match", { players: 2, items: true, seed: "abc" }));

console.log("new_match with too few controllers:", await callTool(page, "new_match", { players: 3, items: true, controllers: ["Agent"] }));

const Table = Schema.Struct({ players: Schema.Array(Schema.Struct({ player: Schema.Number, controller: Schema.String })) });

const parseTable = Schema.decodeUnknownSync(Schema.fromJsonString(Table));

/** By player: the event lines of each view it moved from, then of its final view. */
const heard = new Map<number, ReadonlyArray<string>>();

const hear = (player: number, events: ReadonlyArray<string> = []): void => {
  heard.set(player, [...(heard.get(player) ?? []), ...events]);
};

const getView = async (player: number) => {
  const got = await callTool(page, "get_game", { player });

  if (!got.ok) throw new Error(`get_game(${player}) failed: ${got.text}`);

  return parseView(got.text);
};

/** The last turn an agent moved at, kept across matches to check that a rematch refuses it. */
let lastTurn = -1;

/** Starts a match and plays every Agent player through the tools until the match is over. */
const playMatch = async (name: string, input: Record<string, number | string | boolean | ReadonlyArray<string>>): Promise<boolean> => {
  const started = await callTool(page, "new_match", input);

  console.log(`${name} new_match:`, started.text);

  if (!started.ok) throw new Error(`new_match refused: ${started.text}`);

  const earlierTurn = lastTurn;

  heard.clear();

  const table = parseTable(started.text).players;
  const agents = table.filter(({ controller }) => controller === "Agent").map(({ player }) => player);
  const other = table.find(({ controller }) => controller !== "Agent");

  if (other !== undefined) console.log(`${name} get_game for a non-Agent player:`, await callTool(page, "get_game", { player: other.player }));

  await shot(page, `${name}-1-new-match`);

  let calls = 0;
  let moves = 0;
  let sharedTurns = 0;
  let staleRetries = 0;
  let isFirstTurnShown = false;
  let isStaleChecked = false;

  for (; calls < CALL_LIMIT; calls++) {
    const views = await Promise.all(agents.map(async (player) => ({ player, view: await getView(player) })));

    if (views.some(({ view }) => view.status === "over")) break;

    const ready = views.filter(({ view }) => view.status === "your turn");

    if (ready.length === 0) {
      await page.waitForTimeout(POLL_MS);
      continue;
    }

    const mover = ready[moves % ready.length];

    if (mover === undefined) throw new Error("no ready agent to move");

    const { turn, moves: legal = [] } = mover.view;

    if (turn === undefined) throw new Error("an agent with the turn has no turn number");

    if (!isFirstTurnShown) {
      isFirstTurnShown = true;
      console.log(`${name} first agent turn:`, JSON.stringify(mover.view).slice(0, 1200));
      console.log(`${name} waiting hints:`, await page.getByText("Waiting for the agent").count());
      await shot(page, `${name}-2-agent-turn`);
    }

    if (!isStaleChecked) {
      isStaleChecked = true;

      const refusedRestart = await callTool(page, "new_match", input);

      console.log(`${name} new_match while the match runs:`, refusedRestart);

      if (refusedRestart.ok) throw new Error("new_match replaced a running match");

      console.log(`${name} out-of-range move:`, await callTool(page, "play_move", { player: mover.player, move: legal.length, turn }));
      console.log(`${name} bad argument type:`, await callTool(page, "play_move", { player: mover.player, move: "zero", turn }));

      if (earlierTurn >= 0) {
        const crossMatch = await callTool(page, "play_move", { player: mover.player, move: 0, turn: earlierTurn });

        console.log(`${name} turn from the previous match:`, crossMatch);

        if (crossMatch.ok) throw new Error("a turn from the previous match was played");
      }
    }

    sharedTurns += ready.length > 1 ? 1 : 0;

    if (legal.length === 0) throw new Error("agent turn with no legal moves");

    const move = (moves * 5 + 1) % legal.length;
    const played = await callTool(page, "play_move", { player: mover.player, move, turn });

    // The bots move between get_game and play_move while several players grab at once; read again.
    if (played.text.includes("Stale move")) {
      staleRetries += 1;
      continue;
    }

    if (!played.ok) throw new Error(`play_move refused: ${played.text}`);

    const repeated = await callTool(page, "play_move", { player: mover.player, move, turn });

    if (repeated.ok) throw new Error(`a repeated play_move was played twice: ${repeated.text}`);

    hear(mover.player, mover.view.events);
    lastTurn = turn;
    moves += 1;

    if (moves === 12) await shot(page, `${name}-3-mid-match`);
  }

  const finals = await Promise.all(agents.map(getView));

  finals.forEach((view, position) => hear(agents[position] ?? 0, view.events));

  const isOver = finals.every((view) => view.status === "over");
  const isTailHeard = agents.every((player) => heard.get(player)?.at(-1) === "The match is over.");
  const isStartHeardOnce = agents.every((player) => (heard.get(player) ?? []).filter((line) => line.startsWith("Round 1 begins")).length === 1);

  console.log(
    `${name}: match over: ${isOver}, last event heard by every agent: ${isTailHeard}, match start heard once: ${isStartHeardOnce}, agent players: ${agents.join(", ")}, agent moves: ${moves}, turns where several agents could move: ${sharedTurns}, stale retries: ${staleRetries}, tool rounds: ${calls}`,
  );

  console.log(`${name} play_move after the end:`, await callTool(page, "play_move", { player: agents[0] ?? 1, move: 0, turn: lastTurn }));

  await shot(page, `${name}-4-match-over`);

  console.log(`${name} results shown:`, await page.locator("section.results").count());

  return isOver && isTailHeard && isStartHeardOnce;
};

const isDuelOver = await playMatch("duel", { players: 2, items: true, seed: "42" });

const isTrioOver = await playMatch("trio", { players: 3, items: true, seed: "42", controllers: ["Agent", "Agent", "DoN"] });

const isRematchOver = await playMatch("rematch", { players: 3, items: true, seed: "42", controllers: ["Agent", "Agent", "DoN"] });

console.log("console problems:", problems);

console.log("seat or Player 0 shown:", leaks);

await browser.close();

if (!isDuelOver || !isTrioOver || !isRematchOver || leaks.length > 0) process.exit(1);
