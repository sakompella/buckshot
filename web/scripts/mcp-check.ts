import { Client } from "@modelcontextprotocol/client";
import { StdioClientTransport } from "@modelcontextprotocol/client/stdio";
import { Schema } from "effect";

// Spawns the stdio MCP server, lists its tools, and plays a 3-seat match with
// items to the end: two Agent seats through the tools, one DoN seat in the server.
// Usage: bun run rules, then bun scripts/mcp-check.ts

const CALL_LIMIT = 3_000;

const View = Schema.Struct({
  isYourTurn: Schema.Boolean,
  isMatchOver: Schema.Boolean,
  turn: Schema.Number,
  privateNotes: Schema.Array(Schema.String),
  moves: Schema.Array(Schema.Struct({ index: Schema.Number, label: Schema.String })),
});

const parseView = Schema.decodeUnknownSync(Schema.fromJsonString(View));

const Table = Schema.Struct({ seats: Schema.Array(Schema.Struct({ seat: Schema.Number, controller: Schema.String })), seed: Schema.String });

const parseTable = Schema.decodeUnknownSync(Schema.fromJsonString(Table));

const ToolText = Schema.Struct({ content: Schema.Tuple([Schema.Struct({ type: Schema.Literal("text"), text: Schema.String })]), isError: Schema.optionalKey(Schema.Boolean) });

const parseToolText = Schema.decodeUnknownSync(ToolText);

const client = new Client({ name: "buckshot-mcp-check", version: "1.0.0" });

await client.connect(new StdioClientTransport({ command: "bun", args: ["scripts/mcp.ts"], stderr: "inherit" }));

const { tools } = await client.listTools();

console.log("tools:", JSON.stringify(tools, null, 2));

const callTool = async (name: string, input: Record<string, number | string | boolean | ReadonlyArray<string>>): Promise<{ readonly ok: boolean; readonly text: string }> => {
  const { content, isError } = parseToolText(await client.callTool({ name, arguments: input }));

  return { ok: isError !== true, text: content[0].text };
};

const getView = async (seat: number) => {
  const got = await callTool("get_game", { seat });

  if (!got.ok) throw new Error(`get_game(${seat}) failed: ${got.text}`);

  return parseView(got.text);
};

console.log("get_game with no match:", await callTool("get_game", { seat: 0 }));

console.log("new_match with a Human seat:", await callTool("new_match", { players: 2, items: true, controllers: ["Agent", "Human"] }));

console.log("play_move with a bad argument type:", await callTool("play_move", { seat: 0, index: "zero" }));

const started = await callTool("new_match", { players: 3, items: true, seed: "42", controllers: ["Agent", "Agent", "DoN"] });

console.log("new_match:", started.text);

const agents = parseTable(started.text).seats.filter(({ controller }) => controller === "Agent").map(({ seat }) => seat);

console.log("get_game for the DoN seat:", await callTool("get_game", { seat: 2 }));

let calls = 0;

let moves = 0;

let sharedTurns = 0;

let isStaleChecked = false;

let notesSeen = 0;

for (; calls < CALL_LIMIT; calls++) {
  const views = await Promise.all(agents.map(async (seat) => ({ seat, view: await getView(seat) })));

  if (views.some(({ view }) => view.isMatchOver)) break;

  const ready = views.filter(({ view }) => view.isYourTurn);
  const mover = ready[moves % ready.length];

  // The DoN seat moves inside the server before any reply, so an Agent always has the turn.
  if (mover === undefined) throw new Error("no Agent seat has the turn, but the match is not over");

  notesSeen = Math.max(notesSeen, ...views.map(({ view }) => view.privateNotes.length));

  if (!isStaleChecked) {
    isStaleChecked = true;
    console.log("stale turn:", await callTool("play_move", { seat: mover.seat, index: 0, turn: mover.view.turn + 1 }));
    console.log("out-of-range move:", await callTool("play_move", { seat: mover.seat, index: mover.view.moves.length, turn: mover.view.turn }));
  }

  sharedTurns += ready.length > 1 ? 1 : 0;

  const choice = mover.view.moves[(moves * 5 + 1) % mover.view.moves.length];

  if (choice === undefined) throw new Error("agent turn with no legal moves");

  const played = await callTool("play_move", { seat: mover.seat, index: choice.index, turn: mover.view.turn });

  if (!played.ok) throw new Error(`play_move refused: ${played.text}`);

  moves += 1;
}

const finals = await Promise.all(agents.map(getView));

const isOver = finals.every((view) => view.isMatchOver);

console.log(`match over: ${isOver}, agent seats: ${agents.join(", ")}, agent moves: ${moves}, turns where both agents could move: ${sharedTurns}, most private notes one seat held: ${notesSeen}, tool rounds: ${calls}`);

await client.close();

if (!isOver) process.exit(1);
