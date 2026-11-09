import { createHash } from "node:crypto";
import { mkdirSync, readdirSync, readFileSync, statSync } from "node:fs";
import { join, relative } from "node:path";

import { BACKGROUND_CONTEXT } from "@earendil-works/chord/context";
import { type AssistantMessage, contentText, type Message, type Models, type ModelThinkingLevel, Type } from "@earendil-works/pi-ai";
import { type ConversationId, createRegistry, defineDoc, defineExtension, defineTool, GenerationTask, Harness, hook, type ModelRef } from "@earendil-works/pi-durable";
import { openNodeSqliteStorage } from "@earendil-works/pi-durable/storage/sqlite/node";
import { Data, Effect, Option, Result, Schema } from "effect";

import { emptyTable, type HeadlessTable, headlessSession } from "../agent/headless.ts";
import { type AgentCall, AgentReply, type MatchSession, replyText, RULES, runTool, tools } from "../agent/tools.ts";
import { SEATS_BY_TABLE, SeatCount } from "../domain.ts";
import { nextPrompt, PRIZES } from "../bend.ts";
import { Controller, controllerOf, promptsOf } from "../driver.ts";
import { Letter, rosterOf } from "../players.ts";
import { eventText, secretText } from "../text.ts";
import { AGENTS, type AgentId, EngineSeat, isEngine } from "./agent.ts";
import { type Engine, openEngine } from "./engine.ts";
import { AgentProvenance } from "./endpoints.ts";
import type { HumanLink } from "./human.ts";
import { addTokens, agentTotals, dropPartialLine, entriesSentTo, exportedSeqs, logCall, logEvent, readCalls, RUN_FORMAT, type Sitting, Standing, writeManifest } from "./runlog.ts";

// One match in one process: the headless table, one pi-durable conversation per
// agent in the run directory's session.sqlite, and one terminal per human. The
// table plays the DoN and Story seats itself; every other seat is a Player the
// turn loop asks for its move: an agent, a human, or the Rust search (engine.ts).
// Agent A plays as Player A wherever it sits; bots, humans and engines take the
// letters left. A conversation's two tools
// read its agent from a seat document written when it was created, so no call
// can reach another seat. The arena sends a player its view on its turn, plays
// forced "Grab an item" turns itself, and journals every move and delivery in
// the store, so a rerun on the same directory rebuilds the table from the seed
// and the journal, writes any log lines a crash left out, and resumes the
// conversations where they stopped. Compaction is off: a match's context fits
// in every model's window, and a summary could drop or repeat log entries.

const context = BACKGROUND_CONTEXT;

/**
 * What each item and the reload do, as facts with no advice. Checked line by line against `item.effect` in
 * sim/bend-mp/sm/main.bend and the use and steal checks in sm/items.bend; it must change when they do. The prizes
 * come from Bend; test/rules-constants.test.ts checks the handsaw damage and the phone range.
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
  `Rounds: every player starts each round with fresh health, empty slots and no jams. Prizes are ${new Intl.ListFormat("en-GB").format(PRIZES.map((prize) => prize.toLocaleString("en-US")))}. Round 1 starts with a random player, later rounds with the player who died first in the round before.`,
].join("\n");

/** The shared instructions every player gets. An agent may get an addendum after them (agentInstructions); no one gets a different version. */
export const INSTRUCTIONS = `${RULES} You are one of the players. On each of your turns you get your view as JSON: you, your player letter; turn, to pass to play_move; players, with health (not shown while jammed), items and, while players grab from the briefcase, holding; gun, with sawed when it is; events, the entries of the match log you have not been sent yet; and moves, your legal moves, each with its number. Play one with play_move, giving its number and the turn. Make exactly one play_move call per reply. get_game shows your view again, without log entries. Log entries say what happened, and what only you learned from the magnifying glass or the phone. Each entry reaches you once, with your turn or in a message between turns, so remember what you need. When your only move is "Grab an item", it is played for you. Your goal is to finish the match with the most cash.\n\n${ITEM_FACTS}`;

/**
 * How a player's log reaches it. "on-turn": the entries since its last delivery come with its next turn. "live": each
 * change is written into its context as it happens, with no model call, and its turn brings only the view.
 */
export const DELIVERIES = ["on-turn", "live"] as const;

export type Delivery = (typeof DELIVERIES)[number];

/** The instructions one agent's conversation starts with: the shared ones, then its addendum if its entrant has one. */
const agentInstructions = ({ provenance }: Entrant): string => (provenance.instructions_addendum === undefined ? INSTRUCTIONS : `${INSTRUCTIONS}\n\n${provenance.instructions_addendum}`);

/** Who plays one position, as the arena sees it: a controller, or an engine with its depth and budget. */
export const ArenaController = Schema.Union([Controller, EngineSeat]);

export type ArenaController = typeof ArenaController.Type;

/** The controllers the rules machine is given: it plays the bots, and the arena plays every other seat through the tools, as an Agent. */
export const machineControllers = (controllers: ReadonlyArray<ArenaController>): Array<Controller> => controllers.map((controller) => (controller === "DoN" || controller === "Story" ? controller : "Agent"));

/** One agent: its letter, its config's label, the model it plays with, and its provenance, which the match fixes when it starts. */
export interface Entrant {
  readonly agent: AgentId;
  readonly label: string;
  readonly model: ModelRef;
  readonly thinkingLevel: ModelThinkingLevel | undefined;
  readonly provenance: AgentProvenance;
}

export interface ArenaMatch {
  readonly dir: string;
  readonly seed: string;
  /** Who plays each position, in table order. The table plays DoN and Story; the arena plays Agent, Human and Engine seats. */
  readonly controllers: ReadonlyArray<ArenaController>;
  /** One entrant per Agent seat, in table order. */
  readonly entrants: ReadonlyArray<Entrant>;
  /** Reaches the human at a Human seat, each time the match starts or resumes. Only needed when there is one. */
  readonly connectHuman?: (player: Letter) => Promise<HumanLink>;
  readonly models: Models;
  /** How the log reaches players; fixed when the match starts. */
  readonly delivery: Delivery;
  /** Called at each journal commit and log export, by a name such as "move:after-commit"; crash tests end the process there. */
  readonly crashAt?: (point: string) => void;
}

export class ArenaFault extends Data.TaggedError("ArenaFault")<{ readonly message: string }> {}

const attempt = <A>(step: string, run: () => Promise<A>) => Effect.tryPromise({ try: run, catch: (cause) => new ArenaFault({ message: `${step}: ${String(cause)}` }) });

type MoveLine = { readonly turn: number; readonly player: Letter; readonly move: number; readonly label: string; readonly by: "agent" | "human" | "engine" | "forced" | "fallback" };

/** Log entries sent to a player: `count` entries of its log from `from`. */
type DeliveryLine = { readonly player: Letter; readonly via: "input" | "live" | "end"; readonly turn: number; readonly from: number; readonly count: number };

/**
 * What decides how a match plays, fixed when it starts; a resume with anything else is refused. `instructions_sha` covers
 * the shared instructions only; an agent's addendum is in its own provenance entry.
 */
type MatchProvenance = { code_sha: string; instructions_sha: string; compaction: "off"; agents: Record<string, AgentProvenance> };

type MatchState = {
  seed: string;
  controllers: Array<ArenaController>;
  /** By seat, in table order: the player's letter. */
  letters: Array<Letter>;
  /** By seat, in table order: who plays it, as results name it. An agent is its entrant's label, any other controller its own name. */
  labels: Array<string>;
  delivery: Delivery;
  conversations: Record<string, ConversationId>;
  moves: Array<MoveLine>;
  deliveries: Array<DeliveryLine>;
  retries: Record<string, number>;
  provenance: MatchProvenance | null;
};

const emptyMatch = (): MatchState => ({ seed: "", controllers: [], letters: [], labels: [], delivery: "on-turn", conversations: {}, moves: [], deliveries: [], retries: {}, provenance: null });

/** How many entries of its log a player has been sent. */
const sentCount = (state: MatchState, player: Letter): number => state.deliveries.reduce((sent, line) => (line.player === player ? line.from + line.count : sent), 0);

/** The letter at each position: the entrants' own at the Agent seats, in order, and the letters left, in order, at the others. */
const lettersOf = (controllers: ReadonlyArray<ArenaController>, agents: ReadonlyArray<AgentId>): Option.Option<Array<Letter>> => {
  const spare = AGENTS.filter((letter) => !agents.includes(letter));
  const isAgent = (controller: ArenaController) => controller === "Agent";

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
  moves: Schema.optional(Schema.Array(Schema.Struct({ move: Schema.Int, label: Schema.String }))),
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
export const letteredSession = (letters: ReadonlyArray<Letter>): MatchSession<HeadlessTable> => {
  const seats = SEATS_BY_TABLE[Schema.decodeUnknownSync(SeatCount)(letters.length)];
  const assignment = new Map(seats.flatMap((seat, index) => Option.toArray(Option.map(Option.fromUndefinedOr(letters[index]), (letter) => [seat, letter] as const))));

  return { ...headlessSession, current: (table) => Option.map(headlessSession.current(table), (match) => ({ ...match, letters: assignment })) };
};

/** The match's headless table. The seat tools and the turn loop share it, in one process. */
class Table {
  private state: HeadlessTable = emptyTable;
  private readonly session: MatchSession<HeadlessTable>;

  /** By position: who plays it, as the arena sees it. */
  private readonly controllers: ReadonlyArray<ArenaController>;

  /** Starts the match from the journal's seed and replays its moves. The table moves Human and Engine seats only through the tools, as it does Agent seats. */
  constructor(journal: MatchState) {
    this.session = letteredSession(journal.letters);
    this.controllers = journal.controllers;
    this.run(decode("new_match", { players: journal.controllers.length, items: true, seed: journal.seed, controllers: machineControllers(journal.controllers) }));

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

  /** The whole table, for the engine, which reads only its player's own log and the public board from it. */
  match() {
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

  /** The players the arena plays, Agent, Human and Engine, in table order. */
  arenaPlayers(): ReadonlyArray<Letter> {
    return this.roster().players.filter(({ seat }) => controllerOf(this.match().controllers, seat) === "Agent").map(({ letter }) => letter);
  }

  controllerOf(player: Letter): ArenaController {
    return Option.getOrThrow(Option.fromUndefinedOr(this.controllers[this.positionOf(player) - 1]));
  }

  /** A player's position in table order, from 1. */
  positionOf(player: Letter): number {
    return this.match().game.seats.indexOf(this.seatOf(player)) + 1;
  }

  /** The one arena player that may move: among those the machine waits on, the one driver.bend serves first, so a distribution goes one grab per seat in turn. */
  onTurn(): Letter | undefined {
    const players = new Map(this.arenaPlayers().map((player) => [this.seatOf(player), player]));
    const { game } = this.match();

    return Option.getOrUndefined(Option.flatMap(nextPrompt(game, promptsOf(game).filter((prompt) => players.has(prompt.seat))), (prompt) => Option.fromUndefinedOr(players.get(prompt.seat))));
  }

  /** A player's view; "waiting" while another arena player has the turn first. */
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

  /** Plays a move for a player if it has the turn; the caller journals the line. A menu's only move is "forced", whoever plays it. */
  tryMove(player: Letter, move: number, turn: number, by: MoveLine["by"]): Played {
    if (this.onTurn() !== player) return { ok: false, text: JSON.stringify({ error: "It is not your turn." }) };

    const moves = this.view(player).moves ?? [];
    const label = moves[move]?.label ?? "";
    const reply = this.run(decode("play_move", { player, move, turn }));

    if (AgentReply.guards.Refused(reply)) return { ok: false, text: replyText(reply) };

    return { ok: true, text: replyText(reply), line: { turn, player, move, label, by: moves.length === 1 ? "forced" : by } };
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

/** What an event line says about the agent it is about; its player has its letter. */
const lineOf = ({ agent, position }: Sitting) => ({ agent, player: agent, position });

/** What the seat tools need from the match around them. */
interface SeatHost {
  readonly table: () => Table;
  readonly onReply: (agent: AgentId, message: AssistantMessage) => void;
  /** Writes the journal's records that events.jsonl lacks. */
  readonly exportJournal: (state: MatchState) => void;
  readonly crashAt: (point: string) => void;
}

const seatTools = (dir: string, { table, onReply, exportJournal, crashAt }: SeatHost) => {
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

          logEvent(dir, "tool", { ...lineOf(sitting), name: "get_game", call_id: api.callId, ok: true });

          return { content: [{ type: "text", text: table().stateText(sitting.agent) }] };
        },
      }),
      defineTool({
        name: "play_move",
        description: "Play one of your legal moves. Returns the move played; your next turn comes as a new message.",
        parameters: Type.Object({
          move: Type.Integer({ minimum: 0, description: "The number of the move, from your view's moves." }),
          turn: Type.Integer({ minimum: 0, description: "The turn of the view you chose the move from." }),
        }),
        replay: "safe",
        execute: async (args, api) => {
          const sitting = await sittingOf(api.snapshot, api.conversationId);
          const journal = await api.snapshot(MatchDoc, context);
          const recorded = journal?.moves.find((line) => line.turn === args.turn && line.player === sitting.agent);

          // A rerun after a crash finds its own move already journaled.
          if (recorded !== undefined) return { content: [{ type: "text", text: JSON.stringify({ played: recorded.label }) }], control: { terminate: true } };

          const played = table().tryMove(sitting.agent, args.move, args.turn, "agent");

          logEvent(dir, "tool", { ...lineOf(sitting), name: "play_move", call_id: api.callId, ok: played.ok });

          if (!played.ok) return { content: [{ type: "text", text: played.text }], isError: true };

          crashAt("move:before-commit");
          await api.commit(async (tx) => void (await tx.doc(MatchDoc)).moves.push(played.line), context);
          crashAt("move:after-commit");
          exportJournal((await api.snapshot(MatchDoc, context)) ?? emptyMatch());
          crashAt("move:after-export");

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
    ],
  });
};

/** The fields of manifest.json that readers of a run, such as the viewer, decode. */
export const RunManifest = Schema.Struct({
  format: Schema.Literal(RUN_FORMAT),
  status: Schema.Literals(["running", "finished"]),
  seed: Schema.String,
  /** By position, in table order. */
  controllers: Schema.Array(ArenaController),
  letters: Schema.Array(Letter),
  /** By position; absent in matches from before labels were recorded. */
  labels: Schema.optional(Schema.Array(Schema.String)),
  delivery: Schema.Literals(DELIVERIES),
  /** By agent: its position, endpoint and totals, the same shape while running and once finished. The totals are zero at start. */
  agents: Schema.Record(
    Schema.String,
    Schema.Struct({
      position: Schema.Int,
      endpoint: Schema.Json,
      models: Schema.Array(Schema.String),
      model_calls: Schema.Int,
      tool_calls: Schema.Int,
      moves: Schema.optionalKey(Schema.Int),
      reminders: Schema.optionalKey(Schema.Int),
      interventions: Schema.optionalKey(Schema.Int),
      usage: Schema.Record(Schema.String, Schema.Number),
      latency_ms: Schema.Struct({ total: Schema.Number, max: Schema.Number }),
      wall_ms: Schema.Number,
    }),
  ),
  provenance: Schema.optional(Schema.Json),
  standings: Schema.optional(Schema.Array(Standing)),
});

export type RunManifest = typeof RunManifest.Type;

const sha = (text: string | Buffer) => createHash("sha256").update(text).digest("hex").slice(0, 12);

/** For people reading a run: the agent at each Agent position, from 1. */
const seatingIn = (state: MatchState) => Object.fromEntries(state.letters.flatMap((letter, index) => (state.controllers[index] === "Agent" ? [[String(index + 1), letter]] : [])));

const WEB = new URL("../..", import.meta.url).pathname;

/** The files that decide how a match plays, under web/: the generated rules, the game and agent core, this match loop, the requests each model is sent and the pinned dependencies. */
const PLAY_FILES = ["generated", "src/agent", "src/bend.ts", "src/domain.ts", "src/driver.ts", "src/players.ts", "src/rng.ts", "src/text.ts", "src/analysis/native-input.ts", "src/analysis/player.ts", "src/arena/agent.ts", "src/arena/endpoints.ts", "src/arena/engine.ts", "src/arena/match.ts", "package.json", "bun.lock"];

const filesUnder = (path: string): ReadonlyArray<string> => (statSync(path).isDirectory() ? readdirSync(path).flatMap((name) => filesUnder(join(path, name))) : [path]);

/** The code version a match started now records, and must find again to resume. */
export const codeSha = (): string => sha(Buffer.concat(PLAY_FILES.flatMap((path) => filesUnder(join(WEB, path))).toSorted().flatMap((file) => [Buffer.from(`${relative(WEB, file)}\0`), readFileSync(file), Buffer.from("\0")])));

const provenanceOf = (match: ArenaMatch): MatchProvenance => ({
  code_sha: codeSha(),
  instructions_sha: sha(INSTRUCTIONS),
  compaction: "off",
  agents: Object.fromEntries(match.entrants.map((entrant) => [entrant.agent, entrant.provenance])),
});

const sameAgent = Schema.toEquivalence(Schema.NullOr(AgentProvenance));

/** Where the configuration a resume brings differs from the one the match started with. */
const changesFrom = (started: MatchProvenance, now: MatchProvenance): ReadonlyArray<string> => [
  ...(["code_sha", "instructions_sha", "compaction"] as const).flatMap((key) => (started[key] === now[key] ? [] : [`${key} was ${started[key]}, now ${now[key]}`])),
  ...[...new Set([...Object.keys(started.agents), ...Object.keys(now.agents)])].flatMap((agent) => {
    const [before, after] = [started.agents[agent] ?? null, now.agents[agent] ?? null];

    return sameAgent(before, after) ? [] : [`agent ${agent} was ${JSON.stringify(before)}, now ${JSON.stringify(after)}`];
  }),
];

/** The same for every model, when a turn ends without a move. */
export const REMINDER = "It is still your turn; call play_move with one of the listed moves.";

/** The move the arena plays for a player that did not choose one: a pick seeded by the match seed, turn and player, among its moves sorted by label, so table order does not change it. */
const interventionMove = (seed: string, turn: number, player: Letter, moves: ReadonlyArray<{ readonly move: number; readonly label: string }>): Option.Option<number> => {
  const byLabel = moves.toSorted((a, b) => (a.label < b.label ? -1 : a.label > b.label ? 1 : 0));
  const pick = Number.parseInt(sha(`${seed}:${turn}:${player}`).slice(0, 8), 16) % Math.max(1, byLabel.length);

  return Option.map(Option.fromUndefinedOr(byLabel[pick]), ({ move }) => move);
};

/** Adds a message to a player's context and asks for nothing. */
type Write = (state: MatchState, text: string, requestId: string, data: { readonly from: number; readonly count: number }) => Effect.Effect<void, ArenaFault>;

/** How the arena plays one seat: its turn, and, for a player that is sent its log, how a message reaches it. */
interface Player {
  readonly write?: Write;
  readonly turn: (state: MatchState, view: View, turn: number) => Effect.Effect<void, ArenaFault>;
}

/** Plays the match in `dir` to game over, starting it or resuming it from its store. */
export const playMatch = (match: ArenaMatch) =>
  Effect.gen(function* () {
    const { dir } = match;
    const crashAt = match.crashAt ?? (() => undefined);

    mkdirSync(dir, { recursive: true });

    for (const file of ["events.jsonl", "calls.jsonl"]) dropPartialLine(join(dir, file));

    let table: Table | undefined;

    const currentTable = () => {
      if (table === undefined) throw new Error("the table is not set up yet");

      return table;
    };

    /** What every log line about one player says about it; agent lines also name the agent. */
    const whereIs = (player: Letter) => {
      const where = { player, position: currentTable().positionOf(player) };

      return currentTable().controllerOf(player) === "Agent" ? { agent: player, ...where } : where;
    };

    const exported = exportedSeqs(dir);

    /** Writes the journal's deliveries and moves that events.jsonl lacks, each with its index in the journal as seq. Each commit is exported before the next, so a crash leaves out at most one. */
    const exportFrom = (state: MatchState) => {
      state.deliveries.forEach((line, seq) => {
        if (exported.deliveries.has(seq)) return;

        logEvent(dir, "delivered", { ...whereIs(line.player), via: line.via, turn: line.turn, from: line.from, entries: currentTable().heard(line.player).slice(line.from, line.from + line.count), seq });
        exported.deliveries.add(seq);
      });

      state.moves.forEach((line, seq) => {
        if (exported.moves.has(seq)) return;

        logEvent(dir, line.by === "fallback" ? "fallback" : "move", { ...whereIs(line.player), ...line, seq });
        exported.moves.add(seq);
      });
    };

    const lastReplies = new Map<AgentId, AssistantMessage>();
    const extension = seatTools(dir, { table: currentTable, onReply: (agent, message) => lastReplies.set(agent, message), exportJournal: exportFrom, crashAt });
    const registry = createRegistry();

    registry.install(extension);

    const storage = yield* attempt("open the store", () => openNodeSqliteStorage(join(dir, "session.sqlite")));
    const store = yield* attempt("open the harness", () => Harness.open(storage, { models: match.models, registry, settings: { compaction: { enabled: false } } }, context));
    const journal = () => attempt("read the journal", async () => (await store.snapshot(MatchDoc, context)) ?? emptyMatch());
    const record = (change: (state: MatchState) => void) => attempt("write the journal", () => store.commit(async (tx) => void change(await tx.doc(MatchDoc)), context));
    // A store with no match in its journal is a fresh start, also after a crash before the first commit.
    const isFresh = (yield* journal()).controllers.length === 0;

    /** Commits a change to the journal and writes its log line; `what` names the crash points around both. */
    const commit = (what: string, change: (state: MatchState) => void) =>
      Effect.gen(function* () {
        crashAt(`${what}:before-commit`);
        yield* record(change);
        crashAt(`${what}:after-commit`);
        exportFrom(yield* journal());
        crashAt(`${what}:after-export`);
      });

    /** The manifest's agents, the same shape while the match runs and after it ends, with each endpoint as the match started with it. */
    const agentsIn = (playing: Table, provenance: MatchProvenance) =>
      Object.fromEntries(
        playing.arenaPlayers().flatMap((player) => (playing.controllerOf(player) === "Agent" ? [[player, { position: playing.positionOf(player), endpoint: provenance.agents[player] ?? null, ...agentTotals(dir, player) }]] : [])),
      );

    const writeRunningManifest = (state: MatchState, provenance: MatchProvenance) => {
      writeManifest(dir, {
        format: RUN_FORMAT,
        status: "running",
        seed: state.seed,
        controllers: state.controllers,
        letters: state.letters,
        labels: state.labels,
        delivery: state.delivery,
        seating: seatingIn(state),
        agents: agentsIn(currentTable(), provenance),
        instructions_sha: provenance.instructions_sha,
        provenance,
      });
    };

    if (isFresh) {
      if (!machineControllers(match.controllers).includes("Agent")) return yield* new ArenaFault({ message: "The arena plays Agent, Human and Engine seats; a match needs at least one." });

      const letters = lettersOf(match.controllers, match.entrants.map((entrant) => entrant.agent));

      if (Option.isNone(letters)) return yield* new ArenaFault({ message: `${match.controllers.filter((controller) => controller === "Agent").length} Agent seats but ${match.entrants.length} entrants` });

      const provenance = provenanceOf(match);
      const labels = match.controllers.map((controller, seat) => (controller === "Agent" ? (match.entrants.find(({ agent }) => agent === letters.value[seat])?.label ?? "") : controller));
      const state: MatchState = { seed: match.seed, controllers: [...match.controllers], letters: letters.value, labels, delivery: match.delivery, conversations: {}, moves: [], deliveries: [], retries: {}, provenance };

      table = new Table(state);

      for (const entrant of match.entrants) {
        const sitting: Sitting = { agent: entrant.agent, position: table.positionOf(entrant.agent) };

        const created = yield* attempt("create a conversation", () =>
          store.createConversation(
            {
              ownership: { kind: "ownerless" },
              agent: { model: entrant.model, thinkingLevel: entrant.thinkingLevel ?? null, instructions: agentInstructions(entrant), extensions: [extension] },
              init: async (tx, id) => void Object.assign(await tx.doc(SeatDoc, id), sitting),
            },
            context,
          ),
        );

        state.conversations[entrant.agent] = created.id;
      }

      // Publish the pin before committing it, so a restart cannot choose a new account for an existing journal.
      writeRunningManifest(state, provenance);
      yield* commit("start", (next) => void Object.assign(next, state));
      logEvent(dir, "seating", { seating: seatingIn(state) });
    } else {
      const state = yield* journal();

      if (state.provenance === null) return yield* new ArenaFault({ message: "This match was started before the arena recorded its configuration, so it cannot be resumed; start a new one." });

      const changes = changesFrom(state.provenance, provenanceOf(match));

      if (changes.length > 0) return yield* new ArenaFault({ message: `This match started with another configuration, so it cannot resume with this one (a key may change, nothing else): ${changes.join("; ")}` });

      table = new Table(state);
      logEvent(dir, "resumed", { moves: state.moves.length });
      exportFrom(state);
    }

    const started = yield* journal();
    const provenance = Option.getOrThrow(Option.fromNullOr(started.provenance));

    writeRunningManifest(started, provenance);

    store.resume();

    const playing = currentTable();
    const humans = new Map<Letter, HumanLink>();

    const conversationOf = (state: MatchState, agent: AgentId) =>
      Effect.flatMap(
        attempt("find a conversation", async () => {
          const id = state.conversations[agent];

          return id === undefined ? undefined : store.conversation(id, context);
        }),
        (conversation) => (conversation === undefined ? Effect.fail(new ArenaFault({ message: `agent ${agent} has no conversation` })) : Effect.succeed(conversation)),
      );

    /** A player's turn input, its view and the log entries it has not been sent, and the delivery that journals them, once per turn. */
    const inputOf = (state: MatchState, player: Letter, view: View, turn: number) => {
      const from = sentCount(state, player);
      const entries = playing.heard(player).slice(from);
      // A resume or a retry of this turn finds its input already journaled.
      const sentThisTurn = state.deliveries.some((line) => line.player === player && line.via === "input" && line.turn === turn);

      return {
        input: `Your turn.\n${JSON.stringify({ ...view, events: entries.length > 0 ? entries : undefined })}`,
        delivered: sentThisTurn ? Effect.void : commit("delivery", (next) => void next.deliveries.push({ player, via: "input", turn, from, count: entries.length })),
      };
    };

    /** An agent: its turn asks its model, and a message is a pi-durable write, with no model call. */
    const agentPlayer = (player: Letter): Player => ({
      write: (state, text, requestId, data) =>
        Effect.flatMap(conversationOf(state, player), (conversation) =>
          attempt("write events", async () => {
            const written = await conversation.submit({ type: "write", requestId, entry: { kind: "arena.events", model: [{ role: "user", content: text, timestamp: Date.now() }], data } }, context);

            await written.wait(context);
          }),
        ),
      turn: (state, view, turn) =>
        Effect.gen(function* () {
          const where = whereIs(player);
          const { input, delivered } = inputOf(state, player, view, turn);
          const conversation = yield* conversationOf(state, player);
          // The same request id after a crash finds the same submission; a retry after a model failure needs a new one.
          const retry = state.retries[String(turn)] ?? 0;
          const requestId = retry === 0 ? `turn-${turn}` : `turn-${turn}-retry-${retry}`;

          /** Runs the model on one input and says whether it moved. A provider error stops the match, to be resumed. */
          const ask = (content: string, request: string, afterSubmit: Effect.Effect<void, ArenaFault>) =>
            Effect.gen(function* () {
              const submittedAt = performance.now();
              const submission = yield* attempt("submit a turn", () => conversation.submit({ type: "input", content, requestId: request }, context));

              yield* afterSubmit;
              yield* attempt("wait for the turn", () => submission.wait(context));

              const moved = playing.turn !== turn;

              logEvent(dir, "turn", { ...where, turn, wall_ms: Math.round(performance.now() - submittedAt), moved });

              const reply = lastReplies.get(player);

              if (!moved && reply?.stopReason === "error") {
                yield* record((next) => void (next.retries[String(turn)] = retry + 1));
                logEvent(dir, "fault", { ...where, turn, error: reply.errorMessage ?? "" });

                return yield* new ArenaFault({ message: `Agent ${player} (position ${where.position}) failed at turn ${turn}: ${reply.errorMessage ?? "no message"}. Run again with the same --dir to resume.` });
              }

              return moved;
            });

          if (yield* ask(input, requestId, Effect.andThen(Effect.sync(() => crashAt("delivery:after-submit")), delivered))) return;

          const reminder = `${requestId}-reminder`;

          const reminded = Effect.sync(() => {
            crashAt("reminder:after-submit");
            logEvent(dir, "reminder", { ...where, turn, request: reminder });
          });

          if (yield* ask(REMINDER, reminder, reminded)) return;

          // A turn with no move after the reminder is forfeited: the arena plays for the player, and the line says so.
          const forfeited = interventionMove(state.seed, turn, player, view.moves ?? []);
          const played = Option.isSome(forfeited) ? playing.tryMove(player, forfeited.value, turn, "fallback") : { ok: false as const, text: `Player ${player} has no moves at turn ${turn}` };

          if (!played.ok) return yield* new ArenaFault({ message: played.text });

          yield* commit("fallback", (next) => void next.moves.push(played.line));
        }),
    });

    /** A human at a terminal: it reads the instructions once, a message is a line on its terminal, and its turn waits for typed lines until one is a legal move, as long as the human takes. */
    const humanPlayer = (player: Letter) =>
      Effect.gen(function* () {
        const { connectHuman } = match;

        if (connectHuman === undefined) return yield* new ArenaFault({ message: `Player ${player} is Human, and this arena has no way to reach a human` });

        const link = yield* attempt(`connect Player ${player}`, () => connectHuman(player));

        // A human reads the same instructions an agent is given, once per terminal.
        yield* attempt(`write to Player ${player}`, () => link.send({ text: INSTRUCTIONS, expectsMove: false }));
        humans.set(player, link);

        return {
          write: (_state, text) => attempt(`write to Player ${player}`, () => link.send({ text, expectsMove: false })),
          turn: (state, view, turn) =>
            Effect.gen(function* () {
              const { input, delivered } = inputOf(state, player, view, turn);

              yield* delivered;

              const startedAt = performance.now();
              let reply = { text: input, expectsMove: true };

              while (playing.turn === turn) {
                yield* attempt(`write to Player ${player}`, () => link.send(reply));

                const typed = (yield* attempt(`wait for Player ${player}; run again with the same --dir to resume`, () => link.nextLine())).trim();
                const played = /^\d+$/.test(typed) ? playing.tryMove(player, Number(typed), turn, "human") : { ok: false as const, text: JSON.stringify({ error: "Type the number of one of your moves." }) };

                if (played.ok) yield* commit("move", (next) => void next.moves.push(played.line));
                else reply = { text: played.text, expectsMove: true };
              }

              logEvent(dir, "turn", { ...whereIs(player), turn, wall_ms: Math.round(performance.now() - startedAt), moved: true });
            }),
        } satisfies Player;
      });

    /** An engine reads the table, so it is sent no messages; its turn is one search. */
    const enginePlayer = (engine: Engine, player: Letter, seat: EngineSeat): Player => ({
      turn: (_state, view, turn) =>
        Effect.gen(function* () {
          const startedAt = performance.now();
          const menu = (view.moves ?? []).map(({ label }) => label);
          const choice = yield* Effect.try({ try: () => engine.choose(playing.match(), player, seat, menu, { dir, turn }), catch: (cause) => new ArenaFault({ message: `engine at Player ${player}, turn ${turn}: ${String(cause)}` }) });
          const played = playing.tryMove(player, menu.indexOf(choice.label), turn, "engine");

          if (!played.ok) return yield* new ArenaFault({ message: `engine at Player ${player}, turn ${turn}, chose "${choice.label}": ${played.text}` });

          yield* commit("move", (next) => void next.moves.push(played.line));
          logEvent(dir, "turn", { ...whereIs(player), turn, wall_ms: Math.round(performance.now() - startedAt), moved: true, depth: choice.depth, nodes: choice.nodes });
        }),
    });

    const players = new Map<Letter, Player>();
    let engine: Engine | undefined;

    for (const player of playing.arenaPlayers()) {
      const controller = playing.controllerOf(player);

      if (controller === "Agent") players.set(player, agentPlayer(player));
      else if (controller === "Human") players.set(player, yield* humanPlayer(player));
      else if (isEngine(controller)) {
        engine ??= yield* Effect.try({ try: openEngine, catch: (cause) => new ArenaFault({ message: `start the engine: ${String(cause)}` }) });
        players.set(player, enginePlayer(engine, player, controller));
      }
    }

    /** Sends a player the log entries it has not been sent; at the end, with the final view. */
    const sendPending = (player: Letter, write: Write, via: "live" | "end") =>
      Effect.gen(function* () {
        const state = yield* journal();
        const from = sentCount(state, player);
        const entries = playing.heard(player).slice(from);

        if (via === "live" && entries.length === 0) return;

        // A resume after the end notice went out sends it no second time.
        if (via === "end" && state.deliveries.some((line) => line.player === player && line.via === "end")) return;

        // The over view's own log ends with "The match is over.", so the end notice needs no heading.
        const text = JSON.stringify(via === "end" ? { ...playing.view(player), events: entries } : { events: entries });

        yield* write(state, text, `${via}-${from}`, { from, count: entries.length });
        yield* commit("delivery", (next) => void next.deliveries.push({ player, via, turn: playing.turn, from, count: entries.length }));
      });

    /** The players that are sent their log, with how a message reaches each. */
    const listeners = [...players].flatMap(([player, { write }]) => (write === undefined ? [] : [[player, write] as const]));

    while (!playing.isOver) {
      if ((yield* journal()).delivery === "live") {
        for (const [player, write] of listeners) yield* sendPending(player, write, "live");
      }

      const player = playing.onTurn();
      const seat = player === undefined ? undefined : players.get(player);

      if (player === undefined || seat === undefined) return yield* new ArenaFault({ message: "no arena player has the turn, but the match is not over" });

      const view = playing.view(player);
      const turn = view.turn ?? -1;

      if (view.moves?.length === 1) {
        const played = playing.tryMove(player, 0, turn, "forced");

        if (!played.ok) return yield* new ArenaFault({ message: played.text });

        yield* commit("forced", (next) => void next.moves.push(played.line));
        continue;
      }

      yield* seat.turn(yield* journal(), view, turn);
    }

    for (const [player, write] of listeners) yield* sendPending(player, write, "end");

    for (const link of humans.values()) link.close();

    const final = yield* journal();
    const audit = yield* auditOf(dir, store, final, playing, listeners.map(([player]) => player));
    const storeUsage = yield* attempt("read usage", () => store.usage(context));
    const someone = Option.getOrThrow(Option.fromUndefinedOr(playing.arenaPlayers()[0]));
    const standings = (playing.view(someone).standings ?? []).map((standing) => ({ ...standing, controller: final.controllers[final.letters.indexOf(standing.player)] ?? null }));
    const moves = Object.fromEntries((["agent", "human", "engine", "forced", "fallback"] as const).map((by) => [by, final.moves.filter((line) => line.by === by).length]));
    const result = { audit, moves, standings, agents: agentsIn(playing, provenance), move_log_sha: sha(JSON.stringify(final.moves)) };

    logEvent(dir, "end", { standings });
    writeManifest(dir, {
      format: RUN_FORMAT,
      status: "finished",
      seed: final.seed,
      controllers: final.controllers,
      letters: final.letters,
      labels: final.labels,
      delivery: final.delivery,
      seating: seatingIn(final),
      instructions_sha: provenance.instructions_sha,
      provenance,
      ...result,
    });
    yield* attempt("close the harness", () => store.close(context));

    return { ...result, storeUsage: Object.fromEntries(Object.entries(storeUsage.models).map(([model, spent]) => [model, { input: spent.input, output: spent.output }])), loggedUsage: addTokens(readCalls(dir)) };
  });

/**
 * Checks the match from the store, not from arena memory: every view an agent was given is its own, the entries each
 * player was sent add up to its own log exactly, with no gaps or repeats, and the seed and journal replay to the same end.
 * A human's transcript is what its terminal was sent, as events.jsonl logs it.
 */
const auditOf = (dir: string, harness: Harness, final: MatchState, table: Table, listeners: ReadonlyArray<Letter>) =>
  Effect.gen(function* () {
    const transcripts: Array<{ readonly agent: AgentId; readonly messages: ReadonlyArray<Message> }> = [];

    for (const agent of table.arenaPlayers().filter((player) => table.controllerOf(player) === "Agent")) {
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
    const sentTo = (player: Letter) => Option.match(Option.fromUndefinedOr(transcripts.find(({ agent }) => agent === player)), { onNone: () => entriesSentTo(dir, player), onSome: ({ messages }) => deliveredOf(messages) });
    const replayed = new Table(final);

    return {
      over: table.isOver,
      every_view_is_own_player: transcripts.every(({ agent, messages }) => viewsOf(messages).every((view) => view.you === agent)),
      delivered_is_own_log_exactly: listeners.every((player) => JSON.stringify(sentTo(player)) === JSON.stringify(table.heard(player))),
      replay_matches: replayed.events === table.events && table.arenaPlayers().every((player) => replayed.viewText(player) === table.viewText(player)),
    };
  });
