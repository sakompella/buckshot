import { Array as Arr, Option, Result, Schema } from "effect";
import { Port } from "foldkit";

import type { Game } from "./bend.ts";
import { Briefcase, Counter, type GameEvent, type LearnedSecret, type Seat, SeatCount, seatsOut, Stage } from "./domain.ts";
import { type Controller, controllerOf, promptsOf } from "./driver.ts";
import { eventText, itemName, moveText, seatName, secretText } from "./text.ts";

// What the WebMCP tools say and hear. The agent sees one seat: the public
// board, the events everyone saw, and the notes that seat heard.

export const AgentCall = Schema.TaggedUnion({
  GetGame: {},
  PlayMove: { index: Schema.Number, turn: Schema.optional(Schema.Number) },
  NewMatch: { players: SeatCount, items: Schema.Boolean, seed: Schema.optional(Schema.String) },
});

export type AgentCall = typeof AgentCall.Type;

export const AgentReply = Schema.TaggedUnion({
  Answered: { text: Schema.String },
  Refused: { reason: Schema.String },
});

export type AgentReply = typeof AgentReply.Type;

export const ports = {
  inbound: { agentCalled: Port.inbound(Schema.Struct({ id: Schema.Number, call: AgentCall })) },
  outbound: { agentReplied: Port.outbound(Schema.Struct({ id: Schema.Number, reply: AgentReply })) },
};

const RECENT_EVENTS = 20;

/** The parts of a running match the agent's view is built from. */
export interface AgentSource {
  readonly game: Game;
  readonly controllers: ReadonlyArray<Controller>;
  readonly events: ReadonlyArray<GameEvent>;
  readonly learned: ReadonlyArray<LearnedSecret>;
}

export interface AgentGame {
  readonly you: string;
  readonly isYourTurn: boolean;
  readonly isMatchOver: boolean;
  readonly turn: number;
  readonly hint: string;
  readonly round: { readonly number: number; readonly of: number; readonly startingHealth: number; readonly turnOrder: string };
  readonly gun: { readonly lastLoadShown: { readonly live: number; readonly blank: number }; readonly shellsLeft: number; readonly isSawedOff: boolean };
  readonly seats: ReadonlyArray<{
    readonly seat: string;
    readonly isYou: boolean;
    readonly health: number | null;
    readonly cash: number;
    readonly items: ReadonlyArray<{ readonly slot: number; readonly item: string }>;
    readonly status: ReadonlyArray<string>;
  }>;
  readonly privateNotes: ReadonlyArray<string>;
  readonly recentEvents: ReadonlyArray<string>;
  readonly moves: ReadonlyArray<{ readonly index: number; readonly label: string }>;
}

export const NO_MATCH = "No match is running. Call new_match to start one.";

const NO_AGENT_SEAT = "No seat is set to Agent. Call new_match, or ask the user to set a seat's controller to Agent.";

export const agentSeat = (source: AgentSource): Option.Option<Seat> => Arr.findFirst(source.game.seats, (seat) => controllerOf(source.controllers, seat) === "Agent");

const promptFor = (source: AgentSource, seat: Seat) => Arr.findFirst(promptsOf(source.game), (prompt) => prompt.seat === seat);

const hintFor = (isOver: boolean, isYourTurn: boolean): string =>
  isOver
    ? "The match is over."
    : isYourTurn
      ? "It is your turn. Pick a move and call play_move with its index."
      : "It is not your turn. The other seats are moving; call get_game again in a moment.";

const seatStatus = (source: AgentSource, seat: Seat, isJammed: boolean, briefcase: Briefcase): ReadonlyArray<string> => [
  ...(seatsOut(source.events).has(seat) ? ["out"] : []),
  ...(isJammed ? ["jammed"] : []),
  ...(Option.contains(Stage.matchOrElse(source.game.board.stage, { Playing: ({ seat: acting }) => Option.some(acting) }, () => Option.none<Seat>()), seat) ? ["has the turn"] : []),
  ...Briefcase.match<ReadonlyArray<string>>(briefcase, {
    NotGrabbing: () => [],
    Grabbing: () => ["grabbing from the briefcase"],
    Holding: ({ item }) => [`holding ${itemName(item)} from the briefcase`],
  }),
];

/** The view of the agent's seat, or why there is none. */
export const agentGame = (source: AgentSource): Result.Result<AgentGame, string> =>
  Result.map(Result.fromOption(agentSeat(source), () => NO_AGENT_SEAT), (you) => {
    const { board, pending, ticket } = source.game;
    const prompt = promptFor(source, you);
    const isOver = pending.kind === "Finished";

    return {
      you: seatName(you),
      isYourTurn: Option.isSome(prompt),
      isMatchOver: isOver,
      turn: ticket.generation,
      hint: hintFor(isOver, Option.isSome(prompt)),
      round: { number: board.round.index + 1, of: board.round.rounds, startingHealth: board.round.health, turnOrder: board.direction === "Clockwise" ? "clockwise" : "counterclockwise" },
      gun: { lastLoadShown: board.gun.shown, shellsLeft: board.gun.remaining, isSawedOff: board.gun.sawed },
      seats: board.seats.map((view) => ({
        seat: seatName(view.seat),
        isYou: view.seat === you,
        health: Counter.match(view.counter, { Unjammed: ({ health }) => health, Jammed: () => null }),
        cash: view.cash,
        items: view.slots.flatMap((slot, index) => Option.match(slot, { onNone: () => [], onSome: (item) => [{ slot: index + 1, item: itemName(item) }] })),
        status: seatStatus(source, view.seat, Counter.guards.Jammed(view.counter), view.briefcase),
      })),
      privateNotes: source.learned.filter(({ seat }) => seat === you).map(({ secret }) => secretText(secret)),
      recentEvents: source.events.slice(-RECENT_EVENTS).map(eventText),
      moves: Option.match(prompt, { onNone: () => [], onSome: ({ seat, menu }) => menu.map((move, index) => ({ index, label: moveText(seat, move) })) }),
    };
  });

/** The click the agent's move stands for, or why the move is refused. */
export const agentMove = (source: AgentSource, index: number, turn: number | undefined): Result.Result<{ match: number; generation: number; seat: Seat; index: number }, string> =>
  Result.flatMap(Result.fromOption(agentSeat(source), () => NO_AGENT_SEAT), (seat) =>
    Result.gen(function* () {
      const prompt = yield* Result.fromOption(promptFor(source, seat), () => "It is not your turn. Call get_game and wait until isYourTurn is true.");

      if (turn !== undefined && turn !== prompt.ticket.generation) {
        return yield* Result.fail(`Stale move: you saw turn ${turn}, but the game is at turn ${prompt.ticket.generation}. Call get_game for the current moves.`);
      }

      if (!Number.isInteger(index) || index < 0 || index >= prompt.menu.length) {
        return yield* Result.fail(`There is no move ${index}. Legal moves are 0 to ${prompt.menu.length - 1}.`);
      }

      return { match: prompt.ticket.match, generation: prompt.ticket.generation, seat, index };
    }),
  );
