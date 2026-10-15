import { Client } from "@modelcontextprotocol/client";
import { StdioClientTransport } from "@modelcontextprotocol/client/stdio";
import { Schema } from "effect";

// Spawns the stdio MCP server, lists its tools, and plays a 3-player match with
// items to the end: two Agent players through the tools, one DoN player in the server.
// Usage: bun run rules, then bun scripts/mcp-check.ts

const CALL_LIMIT = 3_000;

const RAW_SEAT = /seat|Player 0/i;

const View = Schema.Struct({
  status: Schema.Literals(["your turn", "waiting", "over"]),
  turn: Schema.optionalKey(Schema.Number),
  events: Schema.optionalKey(Schema.Array(Schema.String)),
  moves: Schema.optionalKey(Schema.Array(Schema.String)),
});

const parseView = Schema.decodeUnknownSync(Schema.fromJsonString(View));

const Table = Schema.Struct({ players: Schema.Array(Schema.Struct({ player: Schema.Number, controller: Schema.String })), seed: Schema.String });

const parseTable = Schema.decodeUnknownSync(Schema.fromJsonString(Table));

const ToolText = Schema.Struct({ content: Schema.Tuple([Schema.Struct({ type: Schema.Literal("text"), text: Schema.String })]), isError: Schema.optionalKey(Schema.Boolean) });

const parseToolText = Schema.decodeUnknownSync(ToolText);

const client = new Client({ name: "buckshot-mcp-check", version: "1.0.0" });

await client.connect(new StdioClientTransport({ command: "bun", args: ["scripts/mcp.ts"], stderr: "inherit" }));

const { tools } = await client.listTools();

console.log("tools:", JSON.stringify(tools, null, 2));

const replySizes: Array<number> = [];

const callTool = async (name: string, input: Record<string, number | string | boolean | ReadonlyArray<string>>): Promise<{ readonly ok: boolean; readonly text: string }> => {
  const { content, isError } = parseToolText(await client.callTool({ name, arguments: input }));

  if (RAW_SEAT.test(content[0].text)) throw new Error(`${name} reply names a seat or a Player 0: ${content[0].text}`);

  replySizes.push(content[0].text.length);

  return { ok: isError !== true, text: content[0].text };
};

const getView = async (player: number) => {
  const got = await callTool("get_game", { player });

  if (!got.ok) throw new Error(`get_game(${player}) failed: ${got.text}`);

  return parseView(got.text);
};

console.log("get_game with no match:", await callTool("get_game", { player: 1 }));

console.log("new_match with a Human player:", await callTool("new_match", { players: 2, items: true, controllers: ["Agent", "Human"] }));

console.log("play_move with a bad argument type:", await callTool("play_move", { player: 1, index: "zero" }));

const started = await callTool("new_match", { players: 3, items: true, seed: "42", controllers: ["Agent", "Agent", "DoN"] });

console.log("new_match:", started.text);

const agents = parseTable(started.text).players.filter(({ controller }) => controller === "Agent").map(({ player }) => player);

console.log("get_game for the DoN player:", await callTool("get_game", { player: 3 }));

let calls = 0;

let moves = 0;

let sharedTurns = 0;

let isStaleChecked = false;

let longestRound = 0;

for (; calls < CALL_LIMIT; calls++) {
  const views = await Promise.all(agents.map(async (player) => ({ player, view: await getView(player) })));

  if (views.some(({ view }) => view.status === "over")) break;

  const ready = views.filter(({ view }) => view.status === "your turn");
  const mover = ready[moves % ready.length];

  // The DoN player moves inside the server before any reply, so an Agent always has the turn.
  if (mover === undefined) throw new Error("no Agent player has the turn, but the match is not over");

  const { turn, moves: legal = [] } = mover.view;

  if (turn === undefined) throw new Error("an agent with the turn has no turn number");

  // A view's events start at its round's start, so each holds exactly one "Round n begins".
  for (const { view } of ready) {
    const roundStarts = (view.events ?? []).filter((line) => /^Round \d begins/.test(line));

    if (roundStarts.length !== 1) throw new Error(`events hold ${roundStarts.length} round starts: ${JSON.stringify(view.events)}`);

    longestRound = Math.max(longestRound, view.events?.length ?? 0);
  }

  if (!isStaleChecked) {
    isStaleChecked = true;
    console.log("stale turn:", await callTool("play_move", { player: mover.player, index: 0, turn: turn + 1 }));
    console.log("out-of-range move:", await callTool("play_move", { player: mover.player, index: legal.length, turn }));
  }

  sharedTurns += ready.length > 1 ? 1 : 0;

  if (legal.length === 0) throw new Error("agent turn with no legal moves");

  const played = await callTool("play_move", { player: mover.player, index: (moves * 5 + 1) % legal.length, turn });

  if (!played.ok) throw new Error(`play_move refused: ${played.text}`);

  moves += 1;
}

const finals = await Promise.all(agents.map(getView));

const isOver = finals.every((view) => view.status === "over");

console.log(`match over: ${isOver}, agent players: ${agents.join(", ")}, agent moves: ${moves}, turns where both agents could move: ${sharedTurns}, most events in one view: ${longestRound}, tool rounds: ${calls}`);

const bySize = replySizes.toSorted((left, right) => left - right);

console.log(`reply characters: median ${bySize[Math.floor(bySize.length / 2)]}, max ${bySize.at(-1)}, over ${bySize.length} replies`);

await client.close();

if (!isOver) process.exit(1);
