import { Array as Arr, Option, Result } from "effect";

import type { Game } from "../bend.ts";
import { Briefcase, Counter, type GameEvent, type LearnedSecret, type Seat, seatsOut, Stage } from "../domain.ts";
import { type Controller, controllerOf, promptsOf } from "../driver.ts";
import { type PlayerNumber, playerName, type Roster, rosterOf } from "../players.ts";
import { eventText, itemName, moveText, secretText } from "../text.ts";

// An Agent player's view and move checks. Every call names an Agent player and
// sees only that player: the public board, the events everyone saw, and the
// notes that player heard. Players are numbered 1 to N in table order; the
// seat ids behind them never leave this module.

const RECENT_EVENTS = 20;

/** The parts of a running match the agent's view is built from. */
export interface AgentSource {
  readonly game: Game;
  readonly controllers: ReadonlyArray<Controller>;
  readonly events: ReadonlyArray<GameEvent>;
  readonly learned: ReadonlyArray<LearnedSecret>;
  readonly seed: number;
}

export interface AgentGame {
  readonly you: PlayerNumber;
  readonly isYourTurn: boolean;
  readonly isMatchOver: boolean;
  readonly turn: number;
  readonly hint: string;
  readonly round: { readonly number: number; readonly of: number; readonly startingHealth: number; readonly turnOrder: string };
  readonly gun: { readonly lastLoadShown: { readonly live: number; readonly blank: number }; readonly shellsLeft: number; readonly isSawedOff: boolean };
  readonly players: ReadonlyArray<{
    readonly player: PlayerNumber;
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

const agentSeats = (source: AgentSource): ReadonlyArray<Seat> => source.game.seats.filter((seat) => controllerOf(source.controllers, seat) === "Agent");

const notAgent = (source: AgentSource, roster: Roster, seat: Seat): string => {
  const agents = agentSeats(source);

  return agents.length === 0
    ? `${roster.nameOf(seat)} is not an Agent player, and no player is. Call new_match, or ask the user to set a player's controller to Agent.`
    : `${roster.nameOf(seat)} is not an Agent player. Agent players: ${agents.map(roster.nameOf).join(", ")}.`;
};

/** The seat of a player a call names, if the player is at the table and set to Agent. */
const agentSeat = (source: AgentSource, roster: Roster, player: PlayerNumber): Result.Result<Seat, string> =>
  Option.match(roster.seatOf(player), {
    onNone: () => Result.fail(`There is no ${playerName(player)} at this table. The players are ${roster.players.map(playerName).join(", ")}.`),
    onSome: (seat) => (agentSeats(source).includes(seat) ? Result.succeed(seat) : Result.fail(notAgent(source, roster, seat))),
  });

const promptFor = (source: AgentSource, seat: Seat) => Arr.findFirst(promptsOf(source.game), (prompt) => prompt.seat === seat);

const hintFor = (isOver: boolean, isYourTurn: boolean): string =>
  isOver
    ? "The match is over."
    : isYourTurn
      ? "It is your turn. Pick a move and call play_move with its index."
      : "It is not your turn. The other players are moving; call get_game again in a moment.";

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

/** The view of one Agent player, or why there is none. */
export const agentGame = (source: AgentSource, player: PlayerNumber): Result.Result<AgentGame, string> => {
  const roster = rosterOf(source.game.seats);

  return Result.map(agentSeat(source, roster, player), (you) => {
    const { board, pending, ticket } = source.game;
    const prompt = promptFor(source, you);
    const isOver = pending.kind === "Finished";

    return {
      you: player,
      isYourTurn: Option.isSome(prompt),
      isMatchOver: isOver,
      turn: ticket.generation,
      hint: hintFor(isOver, Option.isSome(prompt)),
      round: { number: board.round.index + 1, of: board.round.rounds, startingHealth: board.round.health, turnOrder: board.direction === "Clockwise" ? "clockwise" : "counterclockwise" },
      gun: { lastLoadShown: board.gun.shown, shellsLeft: board.gun.remaining, isSawedOff: board.gun.sawed },
      players: board.seats.map((view) => ({
        player: roster.playerOf(view.seat),
        isYou: view.seat === you,
        health: Counter.match(view.counter, { Unjammed: ({ health }) => health, Jammed: () => null }),
        cash: view.cash,
        items: view.slots.flatMap((slot, index) => Option.match(slot, { onNone: () => [], onSome: (item) => [{ slot: index + 1, item: itemName(item) }] })),
        status: seatStatus(source, view.seat, Counter.guards.Jammed(view.counter), view.briefcase),
      })),
      privateNotes: source.learned.filter(({ seat }) => seat === you).map(({ secret }) => secretText(secret)),
      recentEvents: source.events.slice(-RECENT_EVENTS).map((event) => eventText(roster, event)),
      moves: Option.match(prompt, { onNone: () => [], onSome: ({ seat, menu }) => menu.map((move, index) => ({ index, label: moveText(roster, seat, move) })) }),
    };
  });
};

/** A move as the buttons send it: the request point it answers, and the menu index. */
export interface SeatMove {
  readonly match: number;
  readonly generation: number;
  readonly seat: Seat;
  readonly index: number;
}

/** The click an Agent player's move stands for, or why the move is refused. */
export const agentMove = (source: AgentSource, player: PlayerNumber, index: number, turn: number | undefined): Result.Result<SeatMove, string> =>
  Result.flatMap(agentSeat(source, rosterOf(source.game.seats), player), (seat) =>
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
