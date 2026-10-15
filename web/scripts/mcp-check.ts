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
  token: Schema.optionalKey(Schema.String),
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

/** By player: the token of the last view read, acknowledged by the next call, and every event line read so far. */
const tokens = new Map<number, string>();

const heard = new Map<number, ReadonlyArray<string>>();

const getView = async (player: number) => {
  const token = tokens.get(player);
  const got = await callTool("get_game", token === undefined ? { player } : { player, token });

  if (!got.ok) throw new Error(`get_game(${player}) failed: ${got.text}`);

  return read(player, got.text);
};

const read = (player: number, text: string) => {
  const view = parseView(text);

  heard.set(player, [...(heard.get(player) ?? []), ...(view.events ?? [])]);

  if (view.token !== undefined) tokens.set(player, view.token);

  return view;
};

console.log("get_game with no match:", await callTool("get_game", { player: 1 }));

console.log("new_match with a Human player:", await callTool("new_match", { players: 2, items: true, controllers: ["Agent", "Human"] }));

console.log("play_move with a bad argument type:", await callTool("play_move", { player: 1, index: "zero", token: "m1t0p1e0" }));

console.log("play_move without a token:", await callTool("play_move", { player: 1, index: 0 }));

const started = await callTool("new_match", { players: 3, items: true, seed: "42", controllers: ["Agent", "Agent", "DoN"] });

console.log("new_match:", started.text);

const agents = parseTable(started.text).players.filter(({ controller }) => controller === "Agent").map(({ player }) => player);

console.log("get_game for the DoN player:", await callTool("get_game", { player: 3 }));

let calls = 0;

let moves = 0;

let sharedTurns = 0;

let isStaleChecked = false;

let longestEvents = 0;

const firstViewSeen = new Set<number>();

for (; calls < CALL_LIMIT; calls++) {
  const views = await Promise.all(agents.map(async (player) => ({ player, view: await getView(player) })));

  if (views.some(({ view }) => view.status === "over")) break;

  const ready = views.filter(({ view }) => view.status === "your turn");
  const mover = ready[moves % ready.length];

  // The DoN player moves inside the server before any reply, so an Agent always has the turn.
  if (mover === undefined) throw new Error("no Agent player has the turn, but the match is not over");

  const { token, moves: legal = [] } = mover.view;

  if (token === undefined) throw new Error("an agent with the turn has no token");

  for (const { player, view } of ready) {
    const isFirstView = !firstViewSeen.has(player);

    firstViewSeen.add(player);

    // A player's first view on its turn starts from the match start.
    if (isFirstView && !view.events?.[0]?.startsWith("Round 1 begins")) throw new Error(`the first view of player ${player} does not start at the match start: ${JSON.stringify(view.events)}`);

    longestEvents = Math.max(longestEvents, view.events?.length ?? 0);
  }

  if (!isStaleChecked) {
    isStaleChecked = true;

    const retried = await callTool("get_game", { player: mover.player });

    if (retried.text !== (await callTool("get_game", { player: mover.player })).text) throw new Error("a repeated get_game reply differs");

    console.log("lost reply, retried:", retried.text.slice(0, 200));
    console.log("out-of-range move:", await callTool("play_move", { player: mover.player, index: legal.length, token }));
  }

  sharedTurns += ready.length > 1 ? 1 : 0;

  if (legal.length === 0) throw new Error("agent turn with no legal moves");

  const index = (moves * 5 + 1) % legal.length;
  const played = await callTool("play_move", { player: mover.player, index, token });

  if (!played.ok) throw new Error(`play_move refused: ${played.text}`);

  const repeated = await callTool("play_move", { player: mover.player, index, token });

  if (repeated.ok) throw new Error(`a repeated play_move was played twice: ${repeated.text}`);

  if (moves === 0) console.log("repeated move:", repeated.text);

  read(mover.player, played.text);
  moves += 1;
}

const finals = await Promise.all(agents.map(getView));

const isOver = finals.every((view) => view.status === "over");

const isTailHeard = agents.every((player) => heard.get(player)?.at(-1) === "The match is over.");

const acknowledged = await Promise.all(agents.map(getView));

const isTailAcknowledged = acknowledged.every((view) => view.status === "over" && view.events === undefined && view.token === undefined);

console.log(`match over: ${isOver}, last event heard by every agent: ${isTailHeard}, nothing left after acknowledging: ${isTailAcknowledged}, agent players: ${agents.join(", ")}, agent moves: ${moves}, turns where both agents could move: ${sharedTurns}, most events in one view: ${longestEvents}, tool rounds: ${calls}`);

const earlierToken = tokens.get(agents[0] ?? 1) ?? "";

await callTool("new_match", { players: 3, items: true, seed: "42", controllers: ["Agent", "Agent", "DoN"] });

const replayed = await callTool("get_game", { player: agents[0] ?? 1, token: earlierToken });

console.log("a token from the previous match, same seed:", replayed.text);

const bySize = replySizes.toSorted((left, right) => left - right);

console.log(`reply characters: median ${bySize[Math.floor(bySize.length / 2)]}, max ${bySize.at(-1)}, over ${bySize.length} replies`);

await client.close();

if (!isOver || !isTailHeard || !isTailAcknowledged || replayed.ok) process.exit(1);
