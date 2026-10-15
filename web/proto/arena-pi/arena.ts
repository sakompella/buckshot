import { appendFileSync, mkdirSync, writeFileSync } from "node:fs";
import { join } from "node:path";
import { BACKGROUND_CONTEXT } from "@earendil-works/chord/context";
import { type AssistantMessage, createModels, fauxAssistantMessage, fauxProvider, fauxText, fauxToolCall, type Message, type TranscriptContext, Type } from "@earendil-works/pi-ai";
import { CompactionTask, createRegistry, defineDoc, defineExtension, defineTool, GenerationTask, Harness, hook } from "@earendil-works/pi-durable";
import { openNodeSqliteStorage } from "@earendil-works/pi-durable/storage/sqlite/node";
import { Option, Result } from "effect";

import { emptyTable, type HeadlessTable, headlessSession } from "../../src/agent/headless.ts";
import { type AgentCall, AgentReply, replyText, runTool, tools } from "../../src/agent/tools.ts";
import { controllerOf, promptsOf } from "../../src/driver.ts";
import { rosterOf } from "../../src/players.ts";
import { eventText, secretText } from "../../src/text.ts";

// Throwaway prototype: one process hosts one headless match and one pi-durable
// conversation per Agent player, all in one SQLite store. Each conversation's
// game tools are locked to its seat by a seat document written when the
// conversation is created. The arena submits a player's view as input on its
// turn, plays forced "Grab an item" turns itself, and journals every move in
// the store, so a restart rebuilds the table from the seed and the moves and
// resumes the conversations. A faux pi-ai model plays from the transcript only.
// Usage: bun proto/arena-pi/arena.ts --dir /tmp/x [--controllers Agent,Agent,DoN] [--seed 42] [--window 6000] [--crash-at-submit N]

const flag = (name: string, fallback: string): string => {
  const index = process.argv.indexOf(`--${name}`);
  return index === -1 ? fallback : (process.argv[index + 1] ?? fallback);
};

const context = BACKGROUND_CONTEXT;
const dir = flag("dir", `/tmp/arena-pi-${Date.now()}`);
const controllers = flag("controllers", "Agent,Agent,DoN").split(",");
const seed = flag("seed", "42");
const contextWindow = Number(flag("window", "6000"));
const crashAtSubmit = Number(flag("crash-at-submit", "0"));
mkdirSync(dir, { recursive: true });

const log = (file: string, line: object) => appendFileSync(join(dir, file), `${JSON.stringify({ t: new Date().toISOString(), ...line })}\n`);

const decode = (name: string, input: unknown): AgentCall => {
  const tool = tools.find((candidate) => candidate.name === name);
  if (tool === undefined) throw new Error(`no tool ${name}`);
  return Result.getOrThrowWith(tool.decodeCall(input), (reason) => new Error(reason));
};

// The match: one headless table, rebuilt from the seed and the journaled moves.
let table: HeadlessTable = emptyTable;
const run = (call: AgentCall): AgentReply => {
  const outcome = runTool(headlessSession, table, call);
  table = outcome.state;
  return outcome.reply;
};
const match = () => Option.getOrThrow(table.maybeMatch);
const isOver = () => match().game.pending.kind === "Finished";

interface MoveLine { readonly turn: number; readonly player: number; readonly move: number; readonly label: string; readonly by: "agent" | "forced" | "fallback" }
interface MatchState { seed: string; controllers: Array<string>; seats: Record<string, string>; moves: Array<MoveLine>; carried: Record<string, Array<string>>; submits: number }

const MatchDoc = defineDoc<MatchState>({ kind: "arena.match", version: 1, scope: "session", initial: () => ({ seed: "", controllers: [], seats: {}, moves: [], carried: {}, submits: 0 }) });
const SeatDoc = defineDoc<{ player: number }>({ kind: "arena.seat", version: 1, scope: "conversation", history: "latest", fork: "initial", initial: () => ({ player: 0 }) });

const startTable = (state: MatchState) => {
  table = emptyTable;
  run(decode("new_match", { players: state.controllers.length, items: true, seed: state.seed, controllers: state.controllers }));
  for (const line of state.moves) {
    const reply = run(decode("play_move", { player: line.player, move: line.move, turn: line.turn }));
    if (AgentReply.guards.Refused(reply)) throw new Error(`journal does not replay at turn ${line.turn}: ${replyText(reply)}`);
  }
};

const roster = () => rosterOf(match().game.seats);
const agentPlayers = () => roster().players.filter((player) => controllerOf(match().controllers, Option.getOrThrow(roster().seatOf(player))) === "Agent");

/** The one Agent player that may move: the lowest-numbered one the machine waits on. */
const onTurn = (): number | undefined => promptsOf(match().game).map((prompt) => roster().playerOf(prompt.seat)).filter((player) => agentPlayers().includes(player)).toSorted((a, b) => a - b)[0];

const viewText = (player: number): string => {
  const text = replyText(run(decode("get_game", { player })));
  return !isOver() && text.includes('"status":"your turn"') && onTurn() !== player ? JSON.stringify({ you: player, status: "waiting" }) : text;
};

interface View { you: number; status: string; turn?: number; events?: Array<string>; moves?: Array<string> }

/** Applies a move for a player if it is that player's turn; the caller journals the line. */
const tryMove = (player: number, move: number, turn: number, by: MoveLine["by"]): { ok: true; text: string; line: MoveLine } | { ok: false; text: string } => {
  if (onTurn() !== player) return { ok: false, text: JSON.stringify({ error: 'It is not your turn. Call get_game and wait until status is "your turn".' }) };
  const label = (JSON.parse(viewText(player)) as View).moves?.[move] ?? "";
  const reply = run(decode("play_move", { player, move, turn }));
  if (AgentReply.guards.Refused(reply)) return { ok: false, text: replyText(reply) };
  return { ok: true, text: replyText(reply), line: { turn, player, move, label, by } };
};

const seatOf = async (api: { conversationId: string; snapshot: Harness["snapshot"] }): Promise<number> =>
  (await api.snapshot(SeatDoc, api.conversationId as never, context))?.player ?? 0;

/** What a seat has been shown, verbatim: its secrets and the public events, in order, up to now. */
const heardSoFar = (player: number): Array<string> => {
  const { events, learned } = match();
  const seat = Option.getOrThrow(roster().seatOf(player));
  const heardAt = (at: number) => learned.filter((note) => note.seat === seat && note.at === at).map((note) => secretText(note.secret));
  return [...heardAt(0), ...events.flatMap((event, index) => [eventText(roster(), event), ...heardAt(index + 1)])];
};

let harness: Harness | undefined;

const SeatTools = defineExtension({
  name: "buckshot-seat",
  tools: [
    defineTool({
      name: "get_game",
      description: "Your view of the match as JSON. Your turn's view lists your legal moves and the turn number to pass to play_move.",
      parameters: Type.Object({}),
      execute: async (_args, api) => ({ content: [{ type: "text", text: viewText(await seatOf(api)) }] }),
    }),
    defineTool({
      name: "play_move",
      description: "Play move number `move` (its position in the view's moves list, from 0), with the `turn` of the view you chose it from.",
      parameters: Type.Object({ move: Type.Integer({ minimum: 0 }), turn: Type.Integer({ minimum: 0 }) }),
      execute: async (args, api) => {
        const played = tryMove(await seatOf(api), args.move, args.turn, "agent");
        if (!played.ok) return { content: [{ type: "text", text: played.text }], isError: true };
        await api.commit(async (tx) => void (await tx.doc(MatchDoc)).moves.push(played.line), context);
        log("events.jsonl", { kind: "move", ...played.line });
        return { content: [{ type: "text", text: played.text }], control: { terminate: true } };
      },
    }),
  ],
  hooks: [
    hook(GenerationTask, {
      afterResponse: async (message: AssistantMessage, api) => {
        const tools = message.content.flatMap((block) => (block.type === "toolCall" ? [{ name: block.name, arguments: block.arguments }] : []));
        log("calls.jsonl", { player: await seatOf(api), model: message.model, stop_reason: message.stopReason, usage: message.usage, tool_calls: tools });
        return undefined;
      },
    }),
    hook(CompactionTask, {
      beforeCompact: async (_compaction, api) => {
        const player = await seatOf(api);
        const lines = heardSoFar(player);
        const roundStart = lines.findLastIndex((line) => line.startsWith("Round "));
        log("events.jsonl", { kind: "compaction", player });
        return { summary: `[Summary] You are Player ${player}. Everything you have seen this round, in order:\n${lines.slice(roundStart).join("\n")}` };
      },
    }),
  ],
});

// The faux model decides from its transcript alone, so it behaves the same after a restart.
const textOf = (message: Message): string =>
  typeof message.content === "string" ? message.content : message.content.map((block) => ("text" in block ? block.text : "")).join("");
const viewIn = (text: string): View => JSON.parse(text.slice(text.indexOf("{"))) as View;
const play = (view: View): AssistantMessage =>
  fauxAssistantMessage([fauxText("Playing."), fauxToolCall("play_move", { move: ((view.turn ?? 0) * 7 + 3) % (view.moves?.length ?? 1), turn: view.turn ?? 0 })], { stopReason: "toolUse" });
const decide = (transcript: TranscriptContext): AssistantMessage => {
  const last = transcript.messages.filter((message) => message.role !== "system").at(-1);
  if (last === undefined) return fauxAssistantMessage(fauxText("Nothing to do."));
  if (last.role === "user") {
    const isFirst = transcript.messages.filter((message) => message.role === "user").length === 1;
    const view = viewIn(textOf(last));
    return isFirst ? fauxAssistantMessage([fauxToolCall("get_game", { player: view.you === 1 ? 2 : 1 })], { stopReason: "toolUse" }) : play(view);
  }
  if (last.role === "toolResult") return last.isError ? fauxAssistantMessage([fauxToolCall("get_game", {})], { stopReason: "toolUse" }) : play(viewIn(textOf(last)));
  return fauxAssistantMessage(fauxText("Done."));
};

const faux = fauxProvider({ provider: "faux-arena", models: [{ id: "faux-player", contextWindow, maxTokens: 512 }] });
faux.setResponses(Array.from({ length: 20_000 }, () => decide));
const models = createModels();
models.setProvider(faux.provider);

const registry = createRegistry();
registry.install(SeatTools);

const isFresh = !(await Bun.file(join(dir, "session.sqlite")).exists());
harness = await Harness.open(await openNodeSqliteStorage(join(dir, "session.sqlite")), {
  models,
  registry,
  settings: { compaction: { enabled: true, reserveTokens: 1500, keepRecentTokens: 1500, backgroundTokens: 0 }, retry: { maxRetries: 2 } },
}, context);

const PROMPT = "You are playing Buckshot. Call play_move with a move from your view. Your goal is to finish the match with the most cash.";

if (isFresh) {
  const state: MatchState = { seed, controllers, seats: {}, moves: [], carried: {}, submits: 0 };
  startTable(state);
  for (const player of agentPlayers()) {
    const created = await harness.createConversation({
      ownership: { kind: "ownerless" },
      agent: { model: { provider: "faux-arena", modelId: "faux-player" }, instructions: PROMPT, extensions: [SeatTools] },
      init: async (tx, id) => void ((await tx.doc(SeatDoc, id)).player = player),
    }, context);
    state.seats[String(player)] = created.id;
  }
  await harness.commit(async (tx) => void Object.assign(await tx.doc(MatchDoc), state), context);
  writeFileSync(join(dir, "manifest.json"), `${JSON.stringify({ status: "running", seed, controllers, model: "faux-arena/faux-player", context_window: contextWindow })}\n`);
} else {
  const state = (await harness.snapshot(MatchDoc, context))!;
  startTable(state as MatchState);
  log("events.jsonl", { kind: "resumed", moves: state.moves.length });
}
harness.resume();

const journal = async (change: (state: MatchState) => void) => harness!.commit(async (tx) => void change((await tx.doc(MatchDoc)) as MatchState), context);

while (!isOver()) {
  const player = onTurn();
  if (player === undefined) throw new Error("no Agent player has the turn, but the match is not over");
  const view = JSON.parse(viewText(player)) as View;
  const turn = view.turn ?? -1;
  if (view.moves?.length === 1 && view.moves[0] === "Grab an item") {
    const played = tryMove(player, 0, turn, "forced");
    if (!played.ok) throw new Error(played.text);
    await journal((state) => {
      state.moves.push(played.line);
      state.carried[String(player)] = [...(state.carried[String(player)] ?? []), ...(view.events ?? [])];
    });
    continue;
  }
  const state = (await harness.snapshot(MatchDoc, context)) as MatchState;
  const conversation = (await harness.conversation(state.seats[String(player)] as never, context))!;
  const input = { ...view, events: [...(state.carried[String(player)] ?? []), ...(view.events ?? [])] };
  const submission = await conversation.submit({ type: "input", content: `Your turn.\n${JSON.stringify(input)}`, requestId: `turn-${turn}` }, context);
  await journal((next) => {
    next.carried[String(player)] = [];
    next.submits += 1;
  });
  if (crashAtSubmit > 0 && state.submits + 1 === crashAtSubmit) {
    log("events.jsonl", { kind: "crash", turn, player });
    process.exit(3);
  }
  await submission.wait(context);
  if (table.turn === turn) {
    const fallback = tryMove(player, 0, turn, "fallback");
    if (!fallback.ok) throw new Error(fallback.text);
    await journal((next) => void next.moves.push(fallback.line));
  }
}

// Checks, from the store, not from arena memory.
const final = (await harness.snapshot(MatchDoc, context)) as MatchState;
const transcripts: Record<string, Array<Message>> = {};
const compactions: Record<string, number> = {};
for (const [player, id] of Object.entries(final.seats)) {
  const conversation = (await harness.conversation(id as never, context))!;
  const messages: Array<Message> = [];
  let cursor: Parameters<typeof conversation.entries>[2] = undefined;
  do {
    const page = await conversation.entries({ order: "ascending" }, 500, cursor, context);
    messages.push(...page.items.flatMap((entry) => (entry.kind === "pi.compaction" ? [] : (entry.model ?? []))));
    compactions[player] = (compactions[player] ?? 0) + page.items.filter((entry) => entry.kind === "pi.compaction").length;
    cursor = page.next;
  } while (cursor !== undefined);
  transcripts[player] = messages;
}

const viewsIn = (messages: Array<Message>) => messages.filter((message) => message.role === "user" || message.role === "toolResult").map(textOf).filter((text) => text.includes('"you"')).map(viewIn);
const inputsIn = (messages: Array<Message>) => messages.filter((message) => message.role === "user" && textOf(message).startsWith("Your turn.")).map((message) => viewIn(textOf(message)));
const finalEvents = (player: number) => (JSON.parse(viewText(player)) as View).events ?? [];

const live = { events: match().events.length, standings: viewText(agentPlayers()[0] ?? 1) };
startTable(final);
const replayed = { events: match().events.length, standings: viewText(agentPlayers()[0] ?? 1) };

const usage = await harness.usage(context);
const checks = {
  over: isOver(),
  everyViewIsOwnPlayer: Object.entries(transcripts).every(([player, messages]) => viewsIn(messages).every((view) => view.you === Number(player))),
  heardIsOwnLogExactly: Object.entries(transcripts).every(([player, messages]) => JSON.stringify([...inputsIn(messages).flatMap((view) => view.events ?? []), ...(final.carried[player] ?? []), ...finalEvents(Number(player))]) === JSON.stringify(heardSoFar(Number(player)))),
  replayMatches: JSON.stringify(live) === JSON.stringify(replayed),
};
const byWho = (by: MoveLine["by"]) => final.moves.filter((line) => line.by === by).length;
const report = {
  checks,
  seed,
  controllers,
  moves: { agent: byWho("agent"), forced: byWho("forced"), fallback: byWho("fallback") },
  modelCalls: faux.state.callCount,
  compactions,
  usage: Object.fromEntries(Object.entries(usage.models).map(([model, spent]) => [model, { input: spent.input, output: spent.output, cost: spent.cost.total }])),
  moveLogSha: new Bun.CryptoHasher("sha256").update(JSON.stringify(final.moves)).digest("hex").slice(0, 12),
  standings: JSON.parse(live.standings).standings,
};
writeFileSync(join(dir, "manifest.json"), `${JSON.stringify({ status: "finished", seed, controllers, model: "faux-arena/faux-player", context_window: contextWindow, report })}\n`);
await harness.close(context);
console.log(JSON.stringify(report));
process.exit(Object.values(checks).every(Boolean) ? 0 : 1);
