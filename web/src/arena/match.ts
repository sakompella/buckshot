import { createHash } from "node:crypto";
import { existsSync, mkdirSync } from "node:fs";
import { join } from "node:path";

import { BACKGROUND_CONTEXT } from "@earendil-works/chord/context";
import { type AssistantMessage, contentText, type Message, type Models, type ModelThinkingLevel, Type } from "@earendil-works/pi-ai";
import { CompactionTask, type ConversationId, createRegistry, defineDoc, defineExtension, defineTool, GenerationTask, Harness, type HarnessSettings, hook, type ModelRef } from "@earendil-works/pi-durable";
import { openNodeSqliteStorage } from "@earendil-works/pi-durable/storage/sqlite/node";
import { Data, Effect, Option, Result, Schema } from "effect";

import { emptyTable, type HeadlessTable, headlessSession } from "../agent/headless.ts";
import { type AgentCall, AgentReply, replyText, RULES, runTool, tools } from "../agent/tools.ts";
import { type Controller, controllerOf, promptsOf } from "../driver.ts";
import { rosterOf } from "../players.ts";
import { eventText, secretText } from "../text.ts";
import type { AgentId } from "./agent.ts";
import { addTokens, agentTotals, logCall, logEvent, readCalls, type Sitting, writeManifest } from "./runlog.ts";

// One match in one process: the headless table, and one pi-durable conversation
// per Agent player in the run directory's session.sqlite. A conversation's two
// tools read its player from a seat document written when it was created, so no
// call can reach another seat. The arena submits a player's view on its turn,
// plays forced "Grab an item" turns itself, and journals every move in the
// store, so a rerun on the same directory rebuilds the table from the seed and
// the journal and resumes the conversations where they stopped.

const context = BACKGROUND_CONTEXT;

/** The same for every player; the arena adds nothing per model. */
export const INSTRUCTIONS = `${RULES} You are one of the players. On each of your turns you get your view as JSON: you, your player number; turn, to pass to play_move; players, with health (not shown while jammed), items and, while players grab from the briefcase, holding; gun, with sawed when it is; events, the entries of the match log you have not been sent yet; and moves, your legal moves. Play one with play_move, giving its position in moves (from 0) and the turn. get_game shows your view again, without log entries. Log entries say what happened, and what only you learned from the magnifying glass or the phone. Each entry reaches you once, with your turn or in a message between turns, so remember what you need. When your only move is "Grab an item", it is played for you. Your goal is to finish the match with the most cash.`;

const GRAB = "Grab an item";

/**
 * How a player's log reaches it. "on-turn": the entries since its last delivery come with its next turn. "live": each
 * change is written into its context as it happens, with no model call, and its turn brings only the view.
 */
export const DELIVERIES = ["on-turn", "live"] as const;

export type Delivery = (typeof DELIVERIES)[number];

/** One agent: its letter, the model it plays with, and what the manifest says about it. */
export interface Entrant {
  readonly agent: AgentId;
  readonly model: ModelRef;
  readonly thinkingLevel: ModelThinkingLevel | undefined;
  readonly describe: Schema.Json;
}

export interface ArenaMatch {
  readonly dir: string;
  readonly seed: string;
  readonly controllers: ReadonlyArray<Controller>;
  /** The seating: one entrant per Agent player, from the lowest Player number up. */
  readonly entrants: ReadonlyArray<Entrant>;
  readonly models: Models;
  readonly compaction: NonNullable<HarnessSettings["compaction"]>;
  /** How the log reaches players; fixed when the match starts. */
  readonly delivery: Delivery;
}

export class ArenaFault extends Data.TaggedError("ArenaFault")<{ readonly message: string }> {}

const attempt = <A>(step: string, run: () => Promise<A>) => Effect.tryPromise({ try: run, catch: (cause) => new ArenaFault({ message: `${step}: ${String(cause)}` }) });

type MoveLine = { readonly turn: number; readonly player: number; readonly move: number; readonly label: string; readonly by: "agent" | "forced" | "fallback" };

type MatchState = {
  seed: string;
  controllers: Array<string>;
  delivery: Delivery;
  seating: Record<string, AgentId>;
  seats: Record<string, ConversationId>;
  moves: Array<MoveLine>;
  /** By player: how many entries of its log it has been sent. */
  delivered: Record<string, number>;
  retries: Record<string, number>;
};

const emptyMatch = (): MatchState => ({ seed: "", controllers: [], delivery: "on-turn", seating: {}, seats: {}, moves: [], delivered: {}, retries: {} });

const MatchDoc = defineDoc<MatchState>({ kind: "arena.match", version: 1, scope: "session", initial: emptyMatch });

const SeatDoc = defineDoc<{ player: number; agent: AgentId }>({ kind: "arena.seat", version: 1, scope: "conversation", history: "latest", fork: "initial", initial: () => ({ player: 0, agent: "A" }) });

const View = Schema.Struct({
  you: Schema.Int,
  status: Schema.String,
  turn: Schema.optional(Schema.Int),
  players: Schema.optional(Schema.Array(Schema.Struct({ player: Schema.Int, health: Schema.optional(Schema.Int), items: Schema.optional(Schema.Array(Schema.String)), holding: Schema.optional(Schema.String) }))),
  gun: Schema.optional(Schema.Struct({ sawed: Schema.Boolean })),
  events: Schema.optional(Schema.Array(Schema.String)),
  moves: Schema.optional(Schema.Array(Schema.String)),
  standings: Schema.optional(Schema.Array(Schema.Struct({ player: Schema.Int, cash: Schema.Number }))),
});

type View = typeof View.Type;

const decodeView = Schema.decodeUnknownSync(Schema.fromJsonString(View));

/** A view as the agent tools write it. A field this schema lacks is an error, so no part of a view is dropped on the way to a player. */
const parseView = (text: string): View => decodeView(text, { onExcessProperty: "error" });

const Delivered = Schema.Struct({ events: Schema.optional(Schema.Array(Schema.String)) });

/** The log entries a user message carried: a turn input, a live write or the end notice. */
const parseDelivery = (text: string) => (text.includes("{") ? Schema.decodeUnknownSync(Schema.fromJsonString(Delivered))(text.slice(text.indexOf("{"))) : { events: undefined });

/** The view in a message that carries one: a turn input ("Your turn.\n{...}") or a tool result. */
const viewIn = (text: string): Option.Option<View> => (text.includes('"you"') ? Option.some(parseView(text.slice(text.indexOf("{")))) : Option.none());

const decode = (name: string, input: Schema.Json): AgentCall => {
  const tool = tools.find((candidate) => candidate.name === name);

  if (tool === undefined) throw new Error(`no tool ${name}`);

  return Result.getOrThrowWith(tool.decodeCall(input), (reason) => new Error(reason));
};

type Played = { readonly ok: true; readonly text: string; readonly line: MoveLine } | { readonly ok: false; readonly text: string };

/** The match's headless table. The seat tools and the turn loop share it, in one process. */
class Table {
  private state: HeadlessTable = emptyTable;

  /** Starts the match from the journal's seed and replays its moves. */
  constructor(journal: MatchState) {
    this.run(decode("new_match", { players: journal.controllers.length, items: true, seed: journal.seed, controllers: journal.controllers }));

    for (const line of journal.moves) {
      const reply = this.run(decode("play_move", { player: line.player, move: line.move, turn: line.turn }));

      if (AgentReply.guards.Refused(reply)) throw new Error(`the journal does not replay at turn ${line.turn}: ${replyText(reply)}`);
    }
  }

  private run(call: AgentCall): AgentReply {
    const outcome = runTool(headlessSession, this.state, call);

    this.state = outcome.state;

    return outcome.reply;
  }

  private match() {
    return Option.getOrThrow(this.state.maybeMatch);
  }

  get turn(): number {
    return this.state.turn;
  }

  get isOver(): boolean {
    return this.match().game.pending.kind === "Finished";
  }

  get events(): number {
    return this.match().events.length;
  }

  private roster() {
    return rosterOf(this.match().game.seats);
  }

  agentPlayers(): ReadonlyArray<number> {
    const roster = this.roster();

    return roster.players.filter((player) => controllerOf(this.match().controllers, Option.getOrThrow(roster.seatOf(player))) === "Agent");
  }

  /** The one Agent player that may move: the lowest-numbered one the machine waits on, as driver.bend picks among bots. */
  onTurn(): number | undefined {
    const roster = this.roster();
    const agents = this.agentPlayers();

    return promptsOf(this.match().game)
      .map((prompt) => roster.playerOf(prompt.seat))
      .filter((player) => agents.includes(player))
      .toSorted((left, right) => left - right)[0];
  }

  /** A player's view; "waiting" while another Agent player has the turn first. */
  viewText(player: number): string {
    const text = replyText(this.run(decode("get_game", { player })));

    return !this.isOver && text.includes('"status":"your turn"') && this.onTurn() !== player ? JSON.stringify({ you: player, status: "waiting" }) : text;
  }

  view(player: number): View {
    return parseView(this.viewText(player));
  }

  /** The view without log entries: what the tools show, since entries reach a player only through delivery. */
  stateText(player: number): string {
    return JSON.stringify({ ...this.view(player), events: undefined });
  }

  /** Plays a move for a player if it has the turn; the caller journals the line. */
  tryMove(player: number, move: number, turn: number, by: MoveLine["by"]): Played {
    if (this.onTurn() !== player) return { ok: false, text: JSON.stringify({ error: "It is not your turn." }) };

    const label = this.view(player).moves?.[move] ?? "";
    const reply = this.run(decode("play_move", { player, move, turn }));

    if (AgentReply.guards.Refused(reply)) return { ok: false, text: replyText(reply) };

    return { ok: true, text: replyText(reply), line: { turn, player, move, label, by } };
  }

  /** What a seat has been shown, verbatim: its secrets and the public events, in order, up to now. */
  heard(player: number): ReadonlyArray<string> {
    const { events, learned } = this.match();
    const roster = this.roster();
    const seat = Option.getOrThrow(roster.seatOf(player));
    const heardAt = (at: number) => learned.flatMap((note) => (note.seat === seat && note.at === at ? [secretText(note.secret)] : []));

    return [...heardAt(0), ...events.flatMap((event, index) => [eventText(roster, event), ...heardAt(index + 1)])];
  }
}

/** Text blocks only: thinking stays out, so a view can only come from what the arena or a tool wrote. */
const textOf = (message: Message): string => contentText(message.role === "assistant" ? [] : message.content, "");

const seatTools = (dir: string, table: () => Table, onReply: (player: number, message: AssistantMessage) => void) => {
  const sittingOf = async (snapshot: Harness["snapshot"], conversationId: ConversationId): Promise<Sitting> => (await snapshot(SeatDoc, conversationId, context)) ?? { player: 0, agent: "A" };

  return defineExtension({
    name: "buckshot-seat",
    tools: [
      defineTool({
        name: "get_game",
        description: "Your current view, as JSON, without log entries: those reach you once, as messages.",
        parameters: Type.Object({}),
        execute: async (_args, api) => {
          const sitting = await sittingOf(api.snapshot, api.conversationId);

          logEvent(dir, "tool", { ...sitting, name: "get_game", call_id: api.callId, ok: true });

          return { content: [{ type: "text", text: table().stateText(sitting.player) }] };
        },
      }),
      defineTool({
        name: "play_move",
        description: "Play one of your legal moves. Returns the move played; your next turn comes as a new message.",
        parameters: Type.Object({
          move: Type.Integer({ minimum: 0, description: "The position of the move in your view's moves list, from 0." }),
          turn: Type.Integer({ minimum: 0, description: "The turn of the view you chose the move from." }),
        }),
        replay: "safe",
        execute: async (args, api) => {
          const sitting = await sittingOf(api.snapshot, api.conversationId);
          const { player } = sitting;
          const journal = await api.snapshot(MatchDoc, context);
          const recorded = journal?.moves.find((line) => line.turn === args.turn && line.player === player && line.by === "agent");

          // A rerun after a crash finds its own move already journaled.
          if (recorded !== undefined) return { content: [{ type: "text", text: JSON.stringify({ played: recorded.label }) }], control: { terminate: true } };

          const played = table().tryMove(player, args.move, args.turn, "agent");

          logEvent(dir, "tool", { ...sitting, name: "play_move", call_id: api.callId, ok: played.ok });

          if (!played.ok) return { content: [{ type: "text", text: played.text }], isError: true };

          await api.commit(async (tx) => void (await tx.doc(MatchDoc)).moves.push(played.line), context);
          logEvent(dir, "move", { agent: sitting.agent, ...played.line });

          return { content: [{ type: "text", text: JSON.stringify({ played: played.line.label }) }], control: { terminate: true } };
        },
      }),
    ],
    hooks: [
      hook(GenerationTask, {
        afterResponse: async (message: AssistantMessage, api) => {
          const sitting = await sittingOf(api.snapshot, api.conversationId);

          logCall(dir, sitting, message);
          onReply(sitting.player, message);
        },
      }),
      hook(CompactionTask, {
        beforeCompact: async (_compaction, api) => {
          const { player, agent } = await sittingOf(api.snapshot, api.conversationId);
          const sent = (await api.snapshot(MatchDoc, context))?.delivered[String(player)] ?? 0;
          const lines = table().heard(player).slice(0, sent);
          const roundStart = Math.max(0, lines.findLastIndex((line) => line.startsWith("Round ")));

          logEvent(dir, "compaction", { agent, player });

          return { summary: `[Summary] You are Player ${player}. Everything you have been sent this round, in order:\n${lines.slice(roundStart).join("\n")}` };
        },
      }),
    ],
  });
};

const sha = (text: string) => createHash("sha256").update(text).digest("hex").slice(0, 12);

/** Plays the match in `dir` to game over, starting it or resuming it from its store. */
export const playMatch = (match: ArenaMatch) =>
  Effect.gen(function* () {
    const { dir } = match;

    mkdirSync(dir, { recursive: true });

    const isFresh = !existsSync(join(dir, "session.sqlite"));
    let table: Table | undefined;

    const currentTable = () => {
      if (table === undefined) throw new Error("the table is not set up yet");

      return table;
    };

    const lastReplies = new Map<number, AssistantMessage>();
    const extension = seatTools(dir, currentTable, (player, message) => lastReplies.set(player, message));
    const registry = createRegistry();

    registry.install(extension);

    const storage = yield* attempt("open the store", () => openNodeSqliteStorage(join(dir, "session.sqlite")));
    const harness = yield* attempt("open the harness", () => Harness.open(storage, { models: match.models, registry, settings: { compaction: match.compaction } }, context));
    const journal = () => attempt("read the journal", async () => (await harness.snapshot(MatchDoc, context)) ?? emptyMatch());
    const record = (change: (state: MatchState) => void) => attempt("write the journal", () => harness.commit(async (tx) => void change(await tx.doc(MatchDoc)), context));

    if (isFresh) {
      const state: MatchState = { seed: match.seed, controllers: [...match.controllers], delivery: match.delivery, seating: {}, seats: {}, moves: [], delivered: {}, retries: {} };

      table = new Table(state);

      const players = table.agentPlayers();

      if (players.length !== match.entrants.length) return yield* new ArenaFault({ message: `${players.length} Agent players but ${match.entrants.length} entrants` });

      for (const [index, player] of players.entries()) {
        const entrant = match.entrants[index];

        if (entrant === undefined) continue;

        state.seating[String(player)] = entrant.agent;

        const created = yield* attempt("create a conversation", () =>
          harness.createConversation(
            {
              ownership: { kind: "ownerless" },
              agent: { model: entrant.model, thinkingLevel: entrant.thinkingLevel ?? null, instructions: INSTRUCTIONS, extensions: [extension] },
              init: async (tx, id) => void Object.assign(await tx.doc(SeatDoc, id), { player, agent: entrant.agent }),
            },
            context,
          ),
        );

        state.seats[String(player)] = created.id;
      }

      yield* record((next) => void Object.assign(next, state));
      logEvent(dir, "seating", { seating: state.seating });
      writeManifest(dir, {
        status: "running",
        seed: match.seed,
        controllers: [...match.controllers],
        delivery: match.delivery,
        seating: state.seating,
        agents: Object.fromEntries(match.entrants.map((entrant) => [entrant.agent, entrant.describe])),
        instructions_sha: sha(INSTRUCTIONS),
      });
    } else {
      const state = yield* journal();

      table = new Table(state);
      logEvent(dir, "resumed", { moves: state.moves.length });
    }

    harness.resume();

    const playing = currentTable();

    const conversationOf = (state: MatchState, player: number) =>
      Effect.flatMap(
        attempt("find a conversation", async () => {
          const id = state.seats[String(player)];

          return id === undefined ? undefined : harness.conversation(id, context);
        }),
        (conversation) => (conversation === undefined ? Effect.fail(new ArenaFault({ message: `Player ${player} has no conversation` })) : Effect.succeed(conversation)),
      );

    const sittingOf = (state: MatchState, player: number): Sitting => ({ agent: state.seating[String(player)] ?? "A", player });

    /** Writes the log entries a player has not been sent into its context, with no model call; at the end, with the final view. */
    const sendPending = (player: number, via: "live" | "end") =>
      Effect.gen(function* () {
        const state = yield* journal();
        const from = state.delivered[String(player)] ?? 0;
        const entries = playing.heard(player).slice(from);

        if (via === "live" && entries.length === 0) return;

        const content = via === "end" ? `The match is over.\n${JSON.stringify({ ...playing.view(player), events: entries })}` : JSON.stringify({ events: entries });
        const conversation = yield* conversationOf(state, player);

        const written = yield* attempt("write events", () =>
          conversation.submit({ type: "write", requestId: `${via}-${from}`, entry: { kind: "arena.events", model: [{ role: "user", content, timestamp: Date.now() }], data: { from, count: entries.length } } }, context),
        );

        yield* attempt("place events", () => written.wait(context));
        yield* record((next) => void (next.delivered[String(player)] = from + entries.length));
        logEvent(dir, "delivered", { ...sittingOf(state, player), via, turn: playing.turn, from, entries });
      });

    while (!playing.isOver) {
      if ((yield* journal()).delivery === "live") {
        for (const player of playing.agentPlayers()) yield* sendPending(player, "live");
      }

      const player = playing.onTurn();

      if (player === undefined) return yield* new ArenaFault({ message: "no Agent player has the turn, but the match is not over" });

      const view = playing.view(player);
      const turn = view.turn ?? -1;
      const state = yield* journal();
      const sitting = sittingOf(state, player);

      if (view.moves?.length === 1 && view.moves[0] === GRAB) {
        const played = playing.tryMove(player, 0, turn, "forced");

        if (!played.ok) return yield* new ArenaFault({ message: played.text });

        yield* record((next) => void next.moves.push(played.line));
        logEvent(dir, "move", { agent: sitting.agent, ...played.line });
        continue;
      }

      const conversation = yield* conversationOf(state, player);
      const from = state.delivered[String(player)] ?? 0;
      const entries = playing.heard(player).slice(from);
      const input = { ...view, events: entries.length > 0 ? entries : undefined };
      // The same request id after a crash finds the same submission; a retry after a model failure needs a new one.
      const retry = state.retries[String(turn)] ?? 0;
      const requestId = retry === 0 ? `turn-${turn}` : `turn-${turn}-retry-${retry}`;
      const submittedAt = performance.now();
      const submission = yield* attempt("submit a turn", () => conversation.submit({ type: "input", content: `Your turn.\n${JSON.stringify(input)}`, requestId }, context));

      yield* record((next) => void (next.delivered[String(player)] = from + entries.length));
      logEvent(dir, "delivered", { ...sitting, via: "input", turn, from, entries });
      yield* attempt("wait for the turn", () => submission.wait(context));

      const moved = playing.turn !== turn;

      logEvent(dir, "turn", { ...sitting, turn, wall_ms: Math.round(performance.now() - submittedAt), moved });

      const reply = lastReplies.get(player);

      if (!moved && reply?.stopReason === "error") {
        yield* record((next) => void (next.retries[String(turn)] = retry + 1));
        logEvent(dir, "fault", { ...sitting, turn, error: reply.errorMessage ?? "" });

        return yield* new ArenaFault({ message: `Agent ${sitting.agent} (Player ${player}) failed at turn ${turn}: ${reply.errorMessage ?? "no message"}. Run again with the same --dir to resume.` });
      }

      if (!moved) {
        const fallback = playing.tryMove(player, 0, turn, "fallback");

        if (!fallback.ok) return yield* new ArenaFault({ message: fallback.text });

        yield* record((next) => void next.moves.push(fallback.line));
        logEvent(dir, "fallback", { agent: sitting.agent, ...fallback.line });
      }
    }

    for (const player of playing.agentPlayers()) yield* sendPending(player, "end");

    const final = yield* journal();
    const audit = yield* auditOf(harness, final, playing);
    const storeUsage = yield* attempt("read usage", () => harness.usage(context));
    const standings = (playing.view(playing.agentPlayers()[0] ?? 1).standings ?? []).map((standing) => ({ agent: final.seating[String(standing.player)] ?? null, ...standing }));
    const moves = { agent: final.moves.filter((line) => line.by === "agent").length, forced: final.moves.filter((line) => line.by === "forced").length, fallback: final.moves.filter((line) => line.by === "fallback").length };

    const agents = Object.fromEntries(
      Object.entries(final.seating).map(([player, agent]) => [agent, { player: Number(player), endpoint: match.entrants.find((entrant) => entrant.agent === agent)?.describe ?? null, ...agentTotals(dir, agent) }]),
    );

    const result = { audit, moves, standings, agents, move_log_sha: sha(JSON.stringify(final.moves)) };

    logEvent(dir, "end", { standings });
    writeManifest(dir, { status: "finished", seed: final.seed, controllers: final.controllers, delivery: final.delivery, seating: final.seating, instructions_sha: sha(INSTRUCTIONS), ...result });
    yield* attempt("close the harness", () => harness.close(context));

    return { ...result, storeUsage: Object.fromEntries(Object.entries(storeUsage.models).map(([model, spent]) => [model, { input: spent.input, output: spent.output }])), loggedUsage: addTokens(readCalls(dir)) };
  });

/**
 * Checks the match from the store, not from arena memory: every view a seat was given is its own, the entries it was sent
 * add up to its own log exactly, with no gaps or repeats, and the seed and journal replay to the same end.
 */
const auditOf = (harness: Harness, final: MatchState, table: Table) =>
  Effect.gen(function* () {
    const transcripts: Array<{ readonly player: number; readonly messages: ReadonlyArray<Message> }> = [];

    for (const [player, id] of Object.entries(final.seats)) {
      const conversation = yield* attempt("open a transcript", () => harness.conversation(id, context));
      const messages: Array<Message> = [];
      let cursor: Parameters<NonNullable<typeof conversation>["entries"]>[2] = undefined;

      do {
        const page = yield* attempt("read a transcript", () => conversation!.entries({ order: "ascending" }, 500, cursor, context));

        messages.push(...page.items.flatMap((entry) => (entry.kind === "pi.compaction" ? [] : (entry.model ?? []))));
        cursor = page.next;
      } while (cursor !== undefined);

      transcripts.push({ player: Number(player), messages });
    }

    const viewsOf = (messages: ReadonlyArray<Message>) => messages.flatMap((message) => (message.role === "user" || message.role === "toolResult" ? Option.toArray(viewIn(textOf(message))) : []));
    const deliveredOf = (messages: ReadonlyArray<Message>) => messages.flatMap((message) => (message.role === "user" ? (parseDelivery(textOf(message)).events ?? []) : []));
    const replayed = new Table(final);
    const someAgent = table.agentPlayers()[0] ?? 1;

    return {
      over: table.isOver,
      every_view_is_own_player: transcripts.every(({ player, messages }) => viewsOf(messages).every((view) => view.you === player)),
      delivered_is_own_log_exactly: transcripts.every(({ player, messages }) => JSON.stringify(deliveredOf(messages)) === JSON.stringify(table.heard(player))),
      replay_matches: replayed.events === table.events && replayed.viewText(someAgent) === table.viewText(someAgent),
    };
  });
