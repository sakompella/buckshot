import { createHash } from "node:crypto";
import { existsSync, mkdirSync } from "node:fs";
import { join } from "node:path";

import { BACKGROUND_CONTEXT } from "@earendil-works/chord/context";
import { type AssistantMessage, contentText, type Message, type Models, type ModelThinkingLevel, Type } from "@earendil-works/pi-ai";
import { CompactionTask, type ConversationId, createRegistry, defineDoc, defineExtension, defineTool, GenerationTask, Harness, type HarnessSettings, hook, type ModelRef } from "@earendil-works/pi-durable";
import { openNodeSqliteStorage } from "@earendil-works/pi-durable/storage/sqlite/node";
import { Data, Effect, Option, Result, Schema } from "effect";

import { emptyTable, type HeadlessTable, headlessSession } from "../agent/headless.ts";
import { type AgentCall, AgentReply, type MatchSession, replyText, RULES, runTool, tools } from "../agent/tools.ts";
import { SEATS_BY_TABLE, SeatCount } from "../domain.ts";
import { type Controller, controllerOf, promptsOf } from "../driver.ts";
import { Letter, rosterOf } from "../players.ts";
import { eventText, secretText } from "../text.ts";
import { AGENTS, type AgentId } from "./agent.ts";
import { addTokens, agentTotals, logCall, logEvent, readCalls, type Sitting, writeManifest } from "./runlog.ts";

// One match in one process: the headless table, and one pi-durable conversation
// per agent in the run directory's session.sqlite. Agent A plays as Player A
// wherever it sits; bots take the letters left. A conversation's two tools read
// its agent from a seat document written when it was created, so no call can
// reach another seat. The arena submits a player's view on its turn,
// plays forced "Grab an item" turns itself, and journals every move in the
// store, so a rerun on the same directory rebuilds the table from the seed and
// the journal and resumes the conversations where they stopped.

const context = BACKGROUND_CONTEXT;

/**
 * What each item and the reload do, as facts with no advice. Checked line by line against `item.effect` in
 * sim/bend-mp/sm/main.bend and the use and steal checks in sm/items.bend; it must change when they do.
 */
const ITEM_FACTS = [
  "Items: using one empties its slot, everyone sees which item was used, and your turn goes on unless stated below.",
  "Handsaw: your next shot does 2 damage instead of 1. Any shot spends it, a blank too. It is not offered while the gun is sawed.",
  "Magnifying glass: shows only you whether the shell in the chamber is live or blank.",
  'Jammer (the "Jam" moves): that player skips their next turn, once. They cannot be jammed again until they have played a turn.',
  "Cigarettes: you heal 1 if your health is below the round's starting health. Otherwise nothing happens.",
  "Beer: ejects the shell in the chamber without firing it, and everyone sees whether it was live or blank. If it was the last shell, your turn ends.",
  "Burner phone: shows only you whether one later shell is live or blank, and its position, counting the chamber as 1. The position is from 3 to 7. With 2 or fewer shells left it shows nothing.",
  "Inverter: switches the shell in the chamber between live and blank. The others see that you used it, not the shell.",
  'Adrenaline (the "Steal" moves): uses your adrenaline to take that item from another player, alive or dead, and use it at once. Adrenaline cannot be taken.',
  "Remote: reverses the turn order until the round ends.",
  "Reload: when a turn ends with the gun empty and no winner, living players with free slots get more items, a new load is announced, and health stays. The turn passes as it would have.",
  "Rounds: each round starts with fresh health, empty slots and no jams. Prizes are 70,000, 75,000 and 80,000. Round 1 starts with a random player, later rounds with the player who died first in the round before.",
].join("\n");

/** The same for every player; the arena adds nothing per model. */
export const INSTRUCTIONS = `${RULES} You are one of the players. On each of your turns you get your view as JSON: you, your player letter; turn, to pass to play_move; players, with health (not shown while jammed), items and, while players grab from the briefcase, holding; gun, with sawed when it is; events, the entries of the match log you have not been sent yet; and moves, your legal moves. Play one with play_move, giving its position in moves (from 0) and the turn. get_game shows your view again, without log entries. Log entries say what happened, and what only you learned from the magnifying glass or the phone. Each entry reaches you once, with your turn or in a message between turns, so remember what you need. When your only move is "Grab an item", it is played for you. Your goal is to finish the match with the most cash.\n\n${ITEM_FACTS}`;

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
  /** One entrant per Agent seat, in table order. */
  readonly entrants: ReadonlyArray<Entrant>;
  readonly models: Models;
  readonly compaction: NonNullable<HarnessSettings["compaction"]>;
  /** How the log reaches players; fixed when the match starts. */
  readonly delivery: Delivery;
}

export class ArenaFault extends Data.TaggedError("ArenaFault")<{ readonly message: string }> {}

const attempt = <A>(step: string, run: () => Promise<A>) => Effect.tryPromise({ try: run, catch: (cause) => new ArenaFault({ message: `${step}: ${String(cause)}` }) });

type MoveLine = { readonly turn: number; readonly player: Letter; readonly move: number; readonly label: string; readonly by: "agent" | "forced" | "fallback" };

type MatchState = {
  seed: string;
  controllers: Array<Controller>;
  /** By seat, in table order: the player's letter. */
  letters: Array<Letter>;
  delivery: Delivery;
  conversations: Record<string, ConversationId>;
  moves: Array<MoveLine>;
  /** By agent: how many entries of its log it has been sent. */
  delivered: Record<string, number>;
  retries: Record<string, number>;
};

const emptyMatch = (): MatchState => ({ seed: "", controllers: [], letters: [], delivery: "on-turn", conversations: {}, moves: [], delivered: {}, retries: {} });

/** The letter at each seat: the entrants' own at the Agent seats, in order, and the letters left, in order, at the others. */
const lettersOf = (controllers: ReadonlyArray<Controller>, agents: ReadonlyArray<AgentId>): Option.Option<Array<Letter>> => {
  const spare = AGENTS.filter((letter) => !agents.includes(letter));
  const isAgent = (controller: Controller) => controller === "Agent";

  if (controllers.filter(isAgent).length !== agents.length) return Option.none();

  return Option.all(controllers.map((controller, seat) => Option.fromUndefinedOr((isAgent(controller) ? agents : spare)[controllers.slice(0, seat).filter((other) => isAgent(other) === isAgent(controller)).length])));
};

const MatchDoc = defineDoc<MatchState>({ kind: "arena.match", version: 1, scope: "session", initial: emptyMatch });

/** Written when the conversation is created, so its agent is set before any tool runs. */
const SeatDoc = defineDoc<{ agent: AgentId | null; position: number }>({ kind: "arena.seat", version: 1, scope: "conversation", history: "latest", fork: "initial", initial: () => ({ agent: null, position: 0 }) });

const View = Schema.Struct({
  you: Letter,
  status: Schema.String,
  turn: Schema.optional(Schema.Int),
  players: Schema.optional(Schema.Array(Schema.Struct({ player: Letter, health: Schema.optional(Schema.Int), items: Schema.optional(Schema.Array(Schema.String)), holding: Schema.optional(Schema.String) }))),
  gun: Schema.optional(Schema.Struct({ sawed: Schema.Boolean })),
  events: Schema.optional(Schema.Array(Schema.String)),
  moves: Schema.optional(Schema.Array(Schema.String)),
  standings: Schema.optional(Schema.Array(Schema.Struct({ player: Letter, cash: Schema.Number }))),
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

/** The headless tools, with each seat named by the journal's letters instead of table order. */
const letteredSession = (letters: ReadonlyArray<Letter>): MatchSession<HeadlessTable> => {
  const seats = SEATS_BY_TABLE[Schema.decodeUnknownSync(SeatCount)(letters.length)];
  const assignment = new Map(seats.flatMap((seat, index) => Option.toArray(Option.map(Option.fromUndefinedOr(letters[index]), (letter) => [seat, letter] as const))));

  return { ...headlessSession, current: (table) => Option.map(headlessSession.current(table), (match) => ({ ...match, letters: assignment })) };
};

/** The match's headless table. The seat tools and the turn loop share it, in one process. */
class Table {
  private state: HeadlessTable = emptyTable;
  private readonly session: MatchSession<HeadlessTable>;

  /** Starts the match from the journal's seed and replays its moves. */
  constructor(journal: MatchState) {
    this.session = letteredSession(journal.letters);
    this.run(decode("new_match", { players: journal.controllers.length, items: true, seed: journal.seed, controllers: journal.controllers }));

    for (const line of journal.moves) {
      const reply = this.run(decode("play_move", { player: line.player, move: line.move, turn: line.turn }));

      if (AgentReply.guards.Refused(reply)) throw new Error(`the journal does not replay at turn ${line.turn}: ${replyText(reply)}`);
    }
  }

  private run(call: AgentCall): AgentReply {
    const outcome = runTool(this.session, this.state, call);

    this.state = outcome.state;

    return outcome.reply;
  }

  private match() {
    return Option.getOrThrow(this.session.current(this.state));
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
    const match = this.match();

    return rosterOf(match.game.seats, match.letters);
  }

  private seatOf(letter: Letter) {
    return Option.getOrThrow(this.roster().find(letter)).seat;
  }

  /** The Agent players, in table order. */
  agentPlayers(): ReadonlyArray<Letter> {
    return this.roster().players.filter(({ seat }) => controllerOf(this.match().controllers, seat) === "Agent").map(({ letter }) => letter);
  }

  /** A player's position in table order, from 1. */
  positionOf(player: Letter): number {
    return this.match().game.seats.indexOf(this.seatOf(player)) + 1;
  }

  /** The one Agent player that may move: the first in table order the machine waits on, as driver.bend picks among bots. */
  onTurn(): Letter | undefined {
    const waiting = new Set(promptsOf(this.match().game).map((prompt) => prompt.seat));

    return this.agentPlayers().find((player) => waiting.has(this.seatOf(player)));
  }

  /** A player's view; "waiting" while another Agent player has the turn first. */
  viewText(player: Letter): string {
    const text = replyText(this.run(decode("get_game", { player })));

    return !this.isOver && text.includes('"status":"your turn"') && this.onTurn() !== player ? JSON.stringify({ you: player, status: "waiting" }) : text;
  }

  view(player: Letter): View {
    return parseView(this.viewText(player));
  }

  /** The view without log entries: what the tools show, since entries reach a player only through delivery. */
  stateText(player: Letter): string {
    return JSON.stringify({ ...this.view(player), events: undefined });
  }

  /** Plays a move for a player if it has the turn; the caller journals the line. */
  tryMove(player: Letter, move: number, turn: number, by: MoveLine["by"]): Played {
    if (this.onTurn() !== player) return { ok: false, text: JSON.stringify({ error: "It is not your turn." }) };

    const label = this.view(player).moves?.[move] ?? "";
    const reply = this.run(decode("play_move", { player, move, turn }));

    if (AgentReply.guards.Refused(reply)) return { ok: false, text: replyText(reply) };

    return { ok: true, text: replyText(reply), line: { turn, player, move, label, by } };
  }

  /** What a seat has been shown, verbatim: its secrets and the public events, in order, up to now. */
  heard(player: Letter): ReadonlyArray<string> {
    const { events, learned } = this.match();
    const roster = this.roster();
    const seat = this.seatOf(player);
    const heardAt = (at: number) => learned.flatMap((note) => (note.seat === seat && note.at === at ? [secretText(note.secret)] : []));

    return [...heardAt(0), ...events.flatMap((event, index) => [eventText(roster, event), ...heardAt(index + 1)])];
  }
}

/** Text blocks only: thinking stays out, so a view can only come from what the arena or a tool wrote. */
const textOf = (message: Message): string => contentText(message.role === "assistant" ? [] : message.content, "");

const seatTools = (dir: string, table: () => Table, onReply: (agent: AgentId, message: AssistantMessage) => void) => {
  const sittingOf = async (snapshot: Harness["snapshot"], conversationId: ConversationId): Promise<Sitting> => {
    const doc = await snapshot(SeatDoc, conversationId, context);

    if (doc?.agent == null) throw new Error(`conversation ${conversationId} has no seat`);

    return { agent: doc.agent, position: doc.position };
  };

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

          return { content: [{ type: "text", text: table().stateText(sitting.agent) }] };
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
          const journal = await api.snapshot(MatchDoc, context);
          const recorded = journal?.moves.find((line) => line.turn === args.turn && line.player === sitting.agent && line.by === "agent");

          // A rerun after a crash finds its own move already journaled.
          if (recorded !== undefined) return { content: [{ type: "text", text: JSON.stringify({ played: recorded.label }) }], control: { terminate: true } };

          const played = table().tryMove(sitting.agent, args.move, args.turn, "agent");

          logEvent(dir, "tool", { ...sitting, name: "play_move", call_id: api.callId, ok: played.ok });

          if (!played.ok) return { content: [{ type: "text", text: played.text }], isError: true };

          await api.commit(async (tx) => void (await tx.doc(MatchDoc)).moves.push(played.line), context);
          logEvent(dir, "move", { ...sitting, ...played.line });

          return { content: [{ type: "text", text: JSON.stringify({ played: played.line.label }) }], control: { terminate: true } };
        },
      }),
    ],
    hooks: [
      hook(GenerationTask, {
        afterResponse: async (message: AssistantMessage, api) => {
          const sitting = await sittingOf(api.snapshot, api.conversationId);

          logCall(dir, sitting, message);
          onReply(sitting.agent, message);
        },
      }),
      hook(CompactionTask, {
        beforeCompact: async (_compaction, api) => {
          const sitting = await sittingOf(api.snapshot, api.conversationId);
          const sent = (await api.snapshot(MatchDoc, context))?.delivered[sitting.agent] ?? 0;
          const lines = table().heard(sitting.agent).slice(0, sent);
          const roundStart = Math.max(0, lines.findLastIndex((line) => line.startsWith("Round ")));

          logEvent(dir, "compaction", { ...sitting });

          return { summary: `[Summary] You are Player ${sitting.agent}. Everything you have been sent this round, in order:\n${lines.slice(roundStart).join("\n")}` };
        },
      }),
    ],
  });
};

/** The version of the run directory's files, which .audit/agent-arena-design.md describes; it changes when a field changes meaning or goes away. */
const RUN_FORMAT = 1;

const sha = (text: string) => createHash("sha256").update(text).digest("hex").slice(0, 12);

/** For people reading a run: the agent at each Agent position, from 1. */
const seatingIn = (state: MatchState) => Object.fromEntries(state.letters.flatMap((letter, index) => (state.controllers[index] === "Agent" ? [[String(index + 1), letter]] : [])));

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

    const lastReplies = new Map<AgentId, AssistantMessage>();
    const extension = seatTools(dir, currentTable, (agent, message) => lastReplies.set(agent, message));
    const registry = createRegistry();

    registry.install(extension);

    const storage = yield* attempt("open the store", () => openNodeSqliteStorage(join(dir, "session.sqlite")));
    const harness = yield* attempt("open the harness", () => Harness.open(storage, { models: match.models, registry, settings: { compaction: match.compaction } }, context));
    const journal = () => attempt("read the journal", async () => (await harness.snapshot(MatchDoc, context)) ?? emptyMatch());
    const record = (change: (state: MatchState) => void) => attempt("write the journal", () => harness.commit(async (tx) => void change(await tx.doc(MatchDoc)), context));

    if (isFresh) {
      const letters = lettersOf(match.controllers, match.entrants.map((entrant) => entrant.agent));

      if (Option.isNone(letters)) return yield* new ArenaFault({ message: `${match.controllers.filter((controller) => controller === "Agent").length} Agent seats but ${match.entrants.length} entrants` });

      const state: MatchState = { seed: match.seed, controllers: [...match.controllers], letters: letters.value, delivery: match.delivery, conversations: {}, moves: [], delivered: {}, retries: {} };

      table = new Table(state);

      for (const entrant of match.entrants) {
        const sitting: Sitting = { agent: entrant.agent, position: table.positionOf(entrant.agent) };

        const created = yield* attempt("create a conversation", () =>
          harness.createConversation(
            {
              ownership: { kind: "ownerless" },
              agent: { model: entrant.model, thinkingLevel: entrant.thinkingLevel ?? null, instructions: INSTRUCTIONS, extensions: [extension] },
              init: async (tx, id) => void Object.assign(await tx.doc(SeatDoc, id), sitting),
            },
            context,
          ),
        );

        state.conversations[entrant.agent] = created.id;
      }

      yield* record((next) => void Object.assign(next, state));
      logEvent(dir, "seating", { seating: seatingIn(state) });
      writeManifest(dir, {
        format: RUN_FORMAT,
        status: "running",
        seed: match.seed,
        controllers: [...match.controllers],
        letters: state.letters,
        delivery: match.delivery,
        seating: seatingIn(state),
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

    const conversationOf = (state: MatchState, agent: AgentId) =>
      Effect.flatMap(
        attempt("find a conversation", async () => {
          const id = state.conversations[agent];

          return id === undefined ? undefined : harness.conversation(id, context);
        }),
        (conversation) => (conversation === undefined ? Effect.fail(new ArenaFault({ message: `agent ${agent} has no conversation` })) : Effect.succeed(conversation)),
      );

    const sittingOf = (agent: AgentId): Sitting => ({ agent, position: playing.positionOf(agent) });

    /** Writes the log entries an agent has not been sent into its context, with no model call; at the end, with the final view. */
    const sendPending = (agent: AgentId, via: "live" | "end") =>
      Effect.gen(function* () {
        const state = yield* journal();
        const from = state.delivered[agent] ?? 0;
        const entries = playing.heard(agent).slice(from);

        if (via === "live" && entries.length === 0) return;

        const content = via === "end" ? `The match is over.\n${JSON.stringify({ ...playing.view(agent), events: entries })}` : JSON.stringify({ events: entries });
        const conversation = yield* conversationOf(state, agent);

        const written = yield* attempt("write events", () =>
          conversation.submit({ type: "write", requestId: `${via}-${from}`, entry: { kind: "arena.events", model: [{ role: "user", content, timestamp: Date.now() }], data: { from, count: entries.length } } }, context),
        );

        yield* attempt("place events", () => written.wait(context));
        yield* record((next) => void (next.delivered[agent] = from + entries.length));
        logEvent(dir, "delivered", { ...sittingOf(agent), via, turn: playing.turn, from, entries });
      });

    while (!playing.isOver) {
      if ((yield* journal()).delivery === "live") {
        for (const agent of playing.agentPlayers()) yield* sendPending(agent, "live");
      }

      const agent = playing.onTurn();

      if (agent === undefined) return yield* new ArenaFault({ message: "no Agent player has the turn, but the match is not over" });

      const view = playing.view(agent);
      const turn = view.turn ?? -1;
      const state = yield* journal();
      const sitting = sittingOf(agent);

      if (view.moves?.length === 1 && view.moves[0] === GRAB) {
        const played = playing.tryMove(agent, 0, turn, "forced");

        if (!played.ok) return yield* new ArenaFault({ message: played.text });

        yield* record((next) => void next.moves.push(played.line));
        logEvent(dir, "move", { ...sitting, ...played.line });
        continue;
      }

      const conversation = yield* conversationOf(state, agent);
      const from = state.delivered[agent] ?? 0;
      const entries = playing.heard(agent).slice(from);
      const input = { ...view, events: entries.length > 0 ? entries : undefined };
      // The same request id after a crash finds the same submission; a retry after a model failure needs a new one.
      const retry = state.retries[String(turn)] ?? 0;
      const requestId = retry === 0 ? `turn-${turn}` : `turn-${turn}-retry-${retry}`;
      const submittedAt = performance.now();
      const submission = yield* attempt("submit a turn", () => conversation.submit({ type: "input", content: `Your turn.\n${JSON.stringify(input)}`, requestId }, context));

      yield* record((next) => void (next.delivered[agent] = from + entries.length));
      logEvent(dir, "delivered", { ...sitting, via: "input", turn, from, entries });
      yield* attempt("wait for the turn", () => submission.wait(context));

      const moved = playing.turn !== turn;

      logEvent(dir, "turn", { ...sitting, turn, wall_ms: Math.round(performance.now() - submittedAt), moved });

      const reply = lastReplies.get(agent);

      if (!moved && reply?.stopReason === "error") {
        yield* record((next) => void (next.retries[String(turn)] = retry + 1));
        logEvent(dir, "fault", { ...sitting, turn, error: reply.errorMessage ?? "" });

        return yield* new ArenaFault({ message: `Agent ${agent} (position ${sitting.position}) failed at turn ${turn}: ${reply.errorMessage ?? "no message"}. Run again with the same --dir to resume.` });
      }

      if (!moved) {
        const fallback = playing.tryMove(agent, 0, turn, "fallback");

        if (!fallback.ok) return yield* new ArenaFault({ message: fallback.text });

        yield* record((next) => void next.moves.push(fallback.line));
        logEvent(dir, "fallback", { ...sitting, ...fallback.line });
      }
    }

    for (const agent of playing.agentPlayers()) yield* sendPending(agent, "end");

    const final = yield* journal();
    const audit = yield* auditOf(harness, final, playing);
    const storeUsage = yield* attempt("read usage", () => harness.usage(context));
    const someAgent = Option.getOrThrow(Option.fromUndefinedOr(playing.agentPlayers()[0]));
    const standings = (playing.view(someAgent).standings ?? []).map((standing) => ({ ...standing, controller: final.controllers[final.letters.indexOf(standing.player)] ?? null }));
    const moves = { agent: final.moves.filter((line) => line.by === "agent").length, forced: final.moves.filter((line) => line.by === "forced").length, fallback: final.moves.filter((line) => line.by === "fallback").length };

    const agents = Object.fromEntries(
      playing.agentPlayers().map((agent) => [agent, { position: playing.positionOf(agent), endpoint: match.entrants.find((entrant) => entrant.agent === agent)?.describe ?? null, ...agentTotals(dir, agent) }]),
    );

    const result = { audit, moves, standings, agents, move_log_sha: sha(JSON.stringify(final.moves)) };

    logEvent(dir, "end", { standings });
    writeManifest(dir, { format: RUN_FORMAT, status: "finished", seed: final.seed, controllers: final.controllers, letters: final.letters, delivery: final.delivery, seating: seatingIn(final), instructions_sha: sha(INSTRUCTIONS), ...result });
    yield* attempt("close the harness", () => harness.close(context));

    return { ...result, storeUsage: Object.fromEntries(Object.entries(storeUsage.models).map(([model, spent]) => [model, { input: spent.input, output: spent.output }])), loggedUsage: addTokens(readCalls(dir)) };
  });

/**
 * Checks the match from the store, not from arena memory: every view a seat was given is its own, the entries it was sent
 * add up to its own log exactly, with no gaps or repeats, and the seed and journal replay to the same end.
 */
const auditOf = (harness: Harness, final: MatchState, table: Table) =>
  Effect.gen(function* () {
    const transcripts: Array<{ readonly agent: AgentId; readonly messages: ReadonlyArray<Message> }> = [];

    for (const agent of table.agentPlayers()) {
      const id = final.conversations[agent];

      if (id === undefined) return yield* new ArenaFault({ message: `agent ${agent} has no conversation` });

      const conversation = yield* attempt("open a transcript", () => harness.conversation(id, context));
      const messages: Array<Message> = [];
      let cursor: Parameters<NonNullable<typeof conversation>["entries"]>[2] = undefined;

      do {
        const page = yield* attempt("read a transcript", () => conversation!.entries({ order: "ascending" }, 500, cursor, context));

        messages.push(...page.items.flatMap((entry) => (entry.kind === "pi.compaction" ? [] : (entry.model ?? []))));
        cursor = page.next;
      } while (cursor !== undefined);

      transcripts.push({ agent, messages });
    }

    const viewsOf = (messages: ReadonlyArray<Message>) => messages.flatMap((message) => (message.role === "user" || message.role === "toolResult" ? Option.toArray(viewIn(textOf(message))) : []));
    const deliveredOf = (messages: ReadonlyArray<Message>) => messages.flatMap((message) => (message.role === "user" ? (parseDelivery(textOf(message)).events ?? []) : []));
    const replayed = new Table(final);

    return {
      over: table.isOver,
      every_view_is_own_player: transcripts.every(({ agent, messages }) => viewsOf(messages).every((view) => view.you === agent)),
      delivered_is_own_log_exactly: transcripts.every(({ agent, messages }) => JSON.stringify(deliveredOf(messages)) === JSON.stringify(table.heard(agent))),
      replay_matches: replayed.events === table.events && transcripts.every(({ agent }) => replayed.viewText(agent) === table.viewText(agent)),
    };
  });
