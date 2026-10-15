import { Client } from "@modelcontextprotocol/client";
import { StdioClientTransport } from "@modelcontextprotocol/client/stdio";
import { Schema } from "effect";

// Spawns the stdio MCP server, lists its tools, and plays a 3-player match with
// items to the end: two Agent players through the tools, one DoN player in the server, then a rematch.
// Usage: bun run rules, then bun scripts/mcp-check.ts

const CALL_LIMIT = 3_000;

const RAW_SEAT = /seat|Player \d/i;

const View = Schema.Struct({
  status: Schema.Literals(["your turn", "waiting", "over"]),
  turn: Schema.optionalKey(Schema.Number),
  events: Schema.optionalKey(Schema.Array(Schema.String)),
  moves: Schema.optionalKey(Schema.Array(Schema.Struct({ move: Schema.Int, label: Schema.String }))),
});

const parseView = Schema.decodeUnknownSync(Schema.fromJsonString(View));

const Table = Schema.Struct({ players: Schema.Array(Schema.Struct({ player: Schema.String, controller: Schema.String })), seed: Schema.String });

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

  if (RAW_SEAT.test(content[0].text)) throw new Error(`${name} reply names a seat or a numbered player: ${content[0].text}`);

  replySizes.push(content[0].text.length);

  return { ok: isError !== true, text: content[0].text };
};

const getView = async (player: string) => {
  const got = await callTool("get_game", { player });

  if (!got.ok) throw new Error(`get_game(${player}) failed: ${got.text}`);

  if ((await callTool("get_game", { player })).text !== got.text) throw new Error(`a repeated get_game(${player}) differs`);

  return { text: got.text, view: parseView(got.text) };
};

/** By player: the event lines of each view it moved from, then of its final view. */
const heard = new Map<string, ReadonlyArray<string>>();

const hear = (player: string, events: ReadonlyArray<string> = []): void => {
  heard.set(player, [...(heard.get(player) ?? []), ...events]);
};

console.log("get_game with no match:", await callTool("get_game", { player: "A" }));

console.log("new_match with a Human player:", await callTool("new_match", { players: 2, items: true, controllers: ["Agent", "Human"] }));

console.log("play_move with a bad argument type:", await callTool("play_move", { player: "A", move: "zero", turn: 0 }));

console.log("play_move without a turn:", await callTool("play_move", { player: "A", move: 0 }));

const setup = { players: 3, items: true, seed: "42", controllers: ["Agent", "Agent", "DoN"] };

const started = await callTool("new_match", setup);

console.log("new_match:", started.text);

const replaced = await callTool("new_match", setup);

console.log("new_match while the match runs:", replaced);

const agents = parseTable(started.text).players.filter(({ controller }) => controller === "Agent").map(({ player }) => player);

console.log("get_game for the DoN player:", await callTool("get_game", { player: "C" }));

let calls = 0;

let moves = 0;

let sharedTurns = 0;

let longestEvents = 0;

let lastTurn = 0;

let sample = "";

for (; calls < CALL_LIMIT; calls++) {
  const views = await Promise.all(agents.map(async (player) => ({ player, ...(await getView(player)) })));

  if (views.some(({ view }) => view.status === "over")) break;

  const ready = views.filter(({ view }) => view.status === "your turn");
  const mover = ready[moves % ready.length];

  // The DoN player moves inside the server before any reply, so an Agent always has the turn.
  if (mover === undefined) throw new Error("no Agent player has the turn, but the match is not over");

  const { turn, events, moves: legal = [] } = mover.view;

  if (turn === undefined) throw new Error("an agent with the turn has no turn number");

  if (!heard.has(mover.player) && !events?.[0]?.startsWith("Round 1 begins")) throw new Error(`the first view of player ${mover.player} does not start at the match start: ${JSON.stringify(events)}`);

  if (moves === 0) console.log("out-of-range move:", await callTool("play_move", { player: mover.player, move: legal.length, turn }));

  if (sample === "" && legal.some(({ label }) => label.startsWith("Use"))) sample = mover.text;

  longestEvents = Math.max(longestEvents, events?.length ?? 0);
  sharedTurns += ready.length > 1 ? 1 : 0;
  hear(mover.player, events);

  if (legal.length === 0) throw new Error("agent turn with no legal moves");

  const move = (moves * 5 + 1) % legal.length;
  const played = await callTool("play_move", { player: mover.player, move, turn });

  if (!played.ok) throw new Error(`play_move refused: ${played.text}`);

  const repeated = await callTool("play_move", { player: mover.player, move, turn });

  if (repeated.ok) throw new Error(`a repeated play_move was played twice: ${repeated.text}`);

  if (moves === 0) console.log("repeated move:", repeated.text);

  lastTurn = turn;
  moves += 1;
}

console.log("a your-turn reply with items:", sample);

const finals = await Promise.all(agents.map(async (player) => (await getView(player)).view));

agents.forEach((player, position) => hear(player, finals[position]?.events));

const isOver = finals.every((view) => view.status === "over");

const isTailHeard = agents.every((player) => heard.get(player)?.at(-1) === "The match is over.");

const isEachLineOnce = agents.every((player) => (heard.get(player) ?? []).filter((line) => line.startsWith("Round 1 begins")).length === 1);

console.log(`match over: ${isOver}, last event heard by every agent: ${isTailHeard}, match start heard once: ${isEachLineOnce}, agent players: ${agents.join(", ")}, agent moves: ${moves}, turns where both agents could move: ${sharedTurns}, most events in one view: ${longestEvents}, tool rounds: ${calls}`);

const rematch = await callTool("new_match", setup);

console.log("new_match after the end:", rematch.text);

const stale = await callTool("play_move", { player: agents[0] ?? "A", move: 0, turn: lastTurn });

console.log("a turn from the previous match, same seed:", stale.text);

const bySize = replySizes.toSorted((left, right) => left - right);

console.log(`reply characters: median ${bySize[Math.floor(bySize.length / 2)]}, max ${bySize.at(-1)}, over ${bySize.length} replies`);

await client.close();

if (replaced.ok || !isOver || !isTailHeard || !isEachLineOnce || !rematch.ok || stale.ok) process.exit(1);
