import { fromJsonSchema, McpServer, createMcpHandler } from "@modelcontextprotocol/server";
import { Option, Result, Schema } from "effect";
import { randomBytes } from "node:crypto";

import { emptyTable, type HeadlessTable, headlessSession } from "../../src/agent/headless.ts";
import { type AgentCall, AgentReply, replyText, runTool, tools } from "../../src/agent/tools.ts";
import { controllerOf, promptsOf } from "../../src/driver.ts";
import { rosterOf } from "../../src/players.ts";
import { eventText, secretText } from "../../src/text.ts";

// Throwaway prototype: one referee process hosts one headless match and serves
// each Agent player at its own capability URL, over streamable HTTP MCP or plain
// JSON. It launches one separate scripted agent process per Agent seat, plays
// the match to the end, then checks privacy, the move log and a replay.
// Usage: bun proto/arena/referee.ts --controllers Agent,Agent,DoN --seed 42 --gate on --out /tmp/x

const flag = (name: string, fallback: string): string => {
  const index = process.argv.indexOf(`--${name}`);
  return index === -1 ? fallback : (process.argv[index + 1] ?? fallback);
};

const controllers = flag("controllers", "Agent,Agent,DoN").split(",");
const seed = flag("seed", "42");
const isGated = flag("gate", "on") === "on";
const items = flag("items", "on") === "on";
const outDir = flag("out", `/tmp/arena-proto-${Date.now()}`);
const transports = flag("transports", "mcp,json").split(",");
const WAIT_CAP_MS = Number(flag("wait-ms", "20000"));

const decode = (name: string, input: unknown): AgentCall => {
  const tool = tools.find((candidate) => candidate.name === name);
  if (tool === undefined) throw new Error(`no tool ${name}`);
  return Result.getOrThrowWith(tool.decodeCall(input), (reason) => new Error(reason));
};

let table: HeadlessTable = emptyTable;
const run = (call: AgentCall): AgentReply => {
  const outcome = runTool(headlessSession, table, call);
  table = outcome.state;
  return outcome.reply;
};

const started = run(decode("new_match", { players: controllers.length, items, seed, controllers }));
if (AgentReply.guards.Refused(started)) throw new Error(replyText(started));

const match = () => Option.getOrThrow(table.maybeMatch);
const roster = rosterOf(match().game.seats);
const agentPlayers = roster.players.filter((player) => controllerOf(match().controllers, Option.getOrThrow(roster.seatOf(player))) === "Agent");

/** Agent players the machine is waiting on, lowest first. */
const agentsToMove = (): ReadonlyArray<number> =>
  promptsOf(match().game)
    .map((prompt) => roster.playerOf(prompt.seat))
    .filter((player) => agentPlayers.includes(player))
    .toSorted((left, right) => left - right);

const mayMove = (player: number): boolean => {
  const waiting = agentsToMove();
  return isGated ? waiting[0] === player : waiting.includes(player);
};

const isOver = (): boolean => match().game.pending.kind === "Finished";

// One shared table, changed only by accepted moves; every change wakes the blocked get_game calls.
let wake: Array<() => void> = [];
const changed = () => {
  const woken = wake;
  wake = [];
  woken.forEach((resolve) => resolve());
};
const nextChange = (ms: number) => new Promise<void>((resolve) => { wake.push(resolve); setTimeout(resolve, ms); });

const log: Array<Record<string, unknown>> = [{ type: "match", seed, controllers, items, gated: isGated }];
const stats = { blockedWaits: 0, refusals: 0 };

const viewText = (player: number): string => {
  const text = replyText(run(decode("get_game", { player })));
  return !isOver() && text.includes('"status":"your turn"') && !mayMove(player) ? JSON.stringify({ you: player, status: "waiting" }) : text;
};

interface SeatReply { readonly text: string; readonly isError: boolean }

const getGame = async (player: number): Promise<SeatReply> => {
  const deadline = Date.now() + WAIT_CAP_MS;
  let text = viewText(player);
  while (text.includes('"status":"waiting"') && Date.now() < deadline) {
    stats.blockedWaits += 1;
    await nextChange(deadline - Date.now());
    text = viewText(player);
  }
  return { text, isError: false };
};

const playMove = (player: number, move: number, turn: number): SeatReply => {
  if (!isOver() && !mayMove(player)) {
    stats.refusals += 1;
    return { text: JSON.stringify({ error: 'It is not your turn. Call get_game and wait until status is "your turn".' }), isError: true };
  }
  const before = replyText(run(decode("get_game", { player })));
  const startedAt = performance.now();
  const reply = run(decode("play_move", { player, move, turn }));
  if (AgentReply.guards.Refused(reply)) {
    stats.refusals += 1;
    return { text: replyText(reply), isError: true };
  }
  const label = (JSON.parse(before) as { moves?: ReadonlyArray<string> }).moves?.[move];
  log.push({ type: "move", turn, player, move, label, ms: Math.round(performance.now() - startedAt) });
  changed();
  return { text: replyText(reply), isError: false };
};

const SeatArgs = { get_game: Schema.Struct({}), play_move: Schema.Struct({ move: Schema.Int, turn: Schema.Int }) };

const callSeat = async (player: number, name: string, input: unknown): Promise<SeatReply> => {
  if (name === "get_game") return getGame(player);
  if (name === "play_move") {
    const args = Schema.decodeUnknownResult(SeatArgs.play_move)(input);
    return Result.isSuccess(args) ? playMove(player, args.success.move, args.success.turn) : { text: JSON.stringify({ error: `Invalid arguments for play_move: ${args.failure.message}` }), isError: true };
  }
  return { text: JSON.stringify({ error: `No tool ${name}.` }), isError: true };
};

const seatServer = (player: number) => () => {
  const server = new McpServer({ name: "buckshot-seat", version: "0.0.0" });
  const toResult = ({ text, isError }: SeatReply) => ({ content: [{ type: "text" as const, text }], isError });
  server.registerTool("get_game", { description: "Your view. Blocks while it is not your turn.", inputSchema: fromJsonSchema(Schema.toJsonSchemaDocument(SeatArgs.get_game).schema), annotations: { readOnlyHint: true } }, async () => toResult(await getGame(player)));
  server.registerTool("play_move", { description: "Play move number `move` from the view with that `turn`.", inputSchema: fromJsonSchema(Schema.toJsonSchemaDocument(SeatArgs.play_move).schema) }, async (input) => toResult(await callSeat(player, "play_move", input)));
  return server;
};

const tokens = new Map(agentPlayers.map((player) => [randomBytes(16).toString("hex"), player] as const));
const handlers = new Map([...tokens].map(([token, player]) => [token, createMcpHandler(seatServer(player))]));
const requestsByToken = new Map<string, number>();
const protocolVersions = new Set<string>();

const http = Bun.serve({
  hostname: "127.0.0.1",
  port: 0,
  fetch: async (request, server) => {
    const [, root, token = "", kind, tool] = new URL(request.url).pathname.split("/");
    const player = tokens.get(token);
    if (root !== "seat" || player === undefined) return new Response("not found", { status: 404 });
    server.timeout(request, 0);
    requestsByToken.set(token, (requestsByToken.get(token) ?? 0) + 1);
    if (kind === "mcp") protocolVersions.add(request.headers.get("mcp-protocol-version") ?? "none");
    if (kind === "mcp") return handlers.get(token)!.fetch(request);
    if (kind === "call" && tool !== undefined && request.method === "POST") return Response.json(await callSeat(player, tool, await request.json()));
    return new Response("not found", { status: 404 });
  },
});

await Bun.write(`${outDir}/.keep`, "");
const base = `http://127.0.0.1:${http.port}`;
const seatUrls = [...tokens].map(([token, player], index) => ({ player, url: `${base}/seat/${token}`, transport: transports[index % transports.length] ?? "mcp" }));

const holdMs = Number(flag("hold-ms", "0"));
if (holdMs > 0) {
  console.error(JSON.stringify({ referee: process.pid, seats: seatUrls }));
  await Bun.sleep(holdMs);
  http.stop(true);
  process.exit(0);
}

const agents = seatUrls.map(({ player, url, transport }) => {
  const command = ["nice", "-n", "10", "bun", new URL("agent.ts", import.meta.url).pathname, "--url", url, "--transport", transport, "--base", base];
  const otherTokens = [...tokens.keys()].filter((token) => !url.endsWith(token));
  if (otherTokens.some((token) => command.join(" ").includes(token))) throw new Error("an agent command names another seat's token");
  const child = Bun.spawn(command, { stdout: "pipe", stderr: "inherit", env: { PATH: process.env["PATH"] ?? "" } });
  return { player, transport, child };
});
console.error(`referee ${process.pid} on ${base}; agent pids ${agents.map(({ child }) => child.pid).join(", ")}`);

const startedAt = performance.now();
const summaries = await Promise.all(agents.map(async ({ player, transport, child }) => {
  const text = await new Response(child.stdout).text();
  const code = await child.exited;
  return { player, transport, code, summary: JSON.parse(text.trim().split("\n").at(-1) ?? "{}") as { you: number; moves: number; stale: number; forced: number; forcedLabels: Record<string, number>; views: number; heard: ReadonlyArray<string>; probes: Record<string, boolean> } };
}));
const wallMs = Math.round(performance.now() - startedAt);

for (const { child } of agents) if (child.exitCode === null) child.kill();
http.stop(true);

const final = match();
const finalRoster = rosterOf(final.game.seats);
const expectedHeard = (player: number): ReadonlyArray<string> => {
  const seat = Option.getOrThrow(finalRoster.seatOf(player));
  const heardAt = (at: number) => final.learned.filter((note) => note.seat === seat && note.at === at).map((note) => secretText(note.secret));
  return [...heardAt(0), ...final.events.flatMap((event, index) => [eventText(finalRoster, event), ...heardAt(index + 1)])];
};

const standings = (JSON.parse(viewText(agentPlayers[0] ?? 1)) as { standings: unknown }).standings;
log.push({ type: "end", standings, events: final.events.length });

// Replay: a fresh session, the same setup and seed, the logged moves in order.
const live = { events: final.events.length, standings: JSON.stringify(standings) };
table = emptyTable;
run(decode("new_match", { players: controllers.length, items, seed, controllers }));
const replayRefusals = log.filter((line) => line["type"] === "move").map((line) => run(decode("play_move", { player: line["player"], move: line["move"], turn: line["turn"] }))).filter(AgentReply.guards.Refused).length;
const replayed = { events: match().game.pending.kind === "Finished" ? match().events.length : -1, standings: JSON.stringify((JSON.parse(viewText(agentPlayers[0] ?? 1)) as { standings: unknown }).standings) };

const checks = {
  over: final.game.pending.kind === "Finished",
  agentsExitedZero: summaries.every(({ code }) => code === 0),
  everyViewIsOwnPlayer: summaries.every(({ player, summary }) => summary.you === player && summary.probes["allViewsOwn"] === true),
  heardIsOwnLogExactly: summaries.every(({ player, summary }) => JSON.stringify(summary.heard) === JSON.stringify(expectedHeard(player))),
  foreignPlayerArgumentIgnored: summaries.every(({ summary }) => summary.probes["foreignPlayerArgGivesOwnView"] === true),
  unknownTokenRefused: summaries.every(({ summary }) => summary.probes["unknownToken404"] === true),
  newMatchNotOffered: summaries.every(({ summary }) => summary.probes["newMatchRefused"] === true),
  replayMatches: replayRefusals === 0 && JSON.stringify(live) === JSON.stringify(replayed),
};

const moveLines = log.filter((line) => line["type"] === "move");
const report = {
  checks,
  gated: isGated,
  controllers,
  seed,
  wallMs,
  agentMoves: moveLines.length,
  movesBySeat: Object.fromEntries(summaries.map(({ player, transport, summary }) => [`P${player}/${transport}`, { moves: summary.moves, forced: summary.forced, forcedLabels: summary.forcedLabels, stale: summary.stale, views: summary.views }])),
  referee: stats,
  requestsByToken: [...requestsByToken.values()],
  mcpProtocolVersions: [...protocolVersions],
  moveLogSha: new Bun.CryptoHasher("sha256").update(JSON.stringify(moveLines.map(({ ms: _ms, ...rest }) => rest))).digest("hex").slice(0, 12),
  maxMoveMs: Math.max(...moveLines.map((line) => Number(line["ms"]))),
};
await Bun.write(`${outDir}/match.jsonl`, log.map((line) => JSON.stringify(line)).join("\n") + "\n");
await Bun.write(`${outDir}/report.json`, JSON.stringify(report, null, 2));
console.log(JSON.stringify(report));
process.exit(Object.values(checks).every(Boolean) ? 0 : 1);
