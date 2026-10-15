import { Array as Arr, Option, Result } from "effect";

import type { Game } from "../bend.ts";
import { type Board, Counter, GameEvent, type LearnedSecret, type Seat, Stage } from "../domain.ts";
import { type Controller, controllerOf, promptsOf } from "../driver.ts";
import { type PlayerNumber, playerName, type Roster, rosterOf } from "../players.ts";
import { eventText, itemName, moveText, secretText } from "../text.ts";

// An Agent player's view and move checks. Every call names an Agent player and
// sees only what that player's screen shows: the board on the player's turn, what
// appeared since the player's last view, and the notes that player heard.
// Players are numbered 1 to N in table order; the seat ids behind them never
// leave this module. Properties that are undefined are left out of the JSON.

/** The parts of a running match the agent's view is built from. */
export interface AgentSource {
  readonly game: Game;
  readonly controllers: ReadonlyArray<Controller>;
  readonly events: ReadonlyArray<GameEvent>;
  readonly learned: ReadonlyArray<LearnedSecret>;
  readonly seed: number;
}

export interface PlayerLine {
  readonly player: PlayerNumber;
  /** Not on screen while the player is jammed. */
  readonly health: number | undefined;
  readonly items: ReadonlyArray<string> | undefined;
}

interface Standing {
  readonly player: PlayerNumber;
  readonly cash: number;
}

/** Not this player's turn: nothing else, so polling is cheap. */
interface Waiting {
  readonly you: PlayerNumber;
  readonly status: "waiting";
}

/** The screen on this player's turn. */
interface YourTurn {
  readonly you: PlayerNumber;
  readonly status: "your turn";
  readonly turn: number;
  readonly players: ReadonlyArray<PlayerLine>;
  readonly gun: { readonly heldBy: PlayerNumber | undefined; readonly sawed: true | undefined } | undefined;
  /** The round so far, from its start: the public events, and the secrets this player heard, in order. */
  readonly events: ReadonlyArray<string>;
  readonly moves: ReadonlyArray<string>;
}

interface Over {
  readonly you: PlayerNumber;
  readonly status: "over";
  readonly standings: ReadonlyArray<Standing>;
}

export type AgentGame = Waiting | YourTurn | Over;

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

const nonEmpty = <A>(values: ReadonlyArray<A>): ReadonlyArray<A> | undefined => (values.length === 0 ? undefined : values);

const isRoundBegan = GameEvent.guards.RoundBegan;

/** The current round as this player saw it: its public events from the round's start, each secret the player heard just after the event that gave it. */
const roundEventsOf = (source: AgentSource, roster: Roster, seat: Seat): ReadonlyArray<string> => {
  const start = Math.max(0, source.events.findLastIndex(isRoundBegan));
  const heardAt = (count: number): ReadonlyArray<string> => source.learned.flatMap((note) => (note.seat === seat && note.at === count ? [secretText(note.secret)] : []));

  return source.events.slice(start).flatMap((event, index) => [eventText(roster, event), ...heardAt(start + index + 1)]);
};

const gunOf = (board: Board, roster: Roster): YourTurn["gun"] => {
  const heldBy = Stage.matchOrElse(board.stage, { Playing: ({ seat }) => Option.some(roster.playerOf(seat)) }, () => Option.none<PlayerNumber>());
  const sawed = board.gun.sawed ? true : undefined;

  return Option.isNone(heldBy) && sawed === undefined ? undefined : { heldBy: Option.getOrUndefined(heldBy), sawed };
};

const standingsOf = (board: Board, roster: Roster): ReadonlyArray<Standing> =>
  board.seats.toSorted((left, right) => right.cash - left.cash).map((view) => ({ player: roster.playerOf(view.seat), cash: view.cash }));

/** The view of one Agent player, or why there is none. */
export const agentGame = (source: AgentSource, player: PlayerNumber): Result.Result<AgentGame, string> => {
  const roster = rosterOf(source.game.seats);

  return Result.map(agentSeat(source, roster, player), (you): AgentGame => {
    const { board, pending, ticket } = source.game;

    return pending.kind === "Finished"
      ? { you: player, status: "over", standings: standingsOf(board, roster) }
      : Option.match(promptFor(source, you), {
          onNone: (): AgentGame => ({ you: player, status: "waiting" }),
          onSome: ({ seat, menu }): AgentGame => ({
            you: player,
            status: "your turn",
            turn: ticket.generation,
            players: board.seats.map((view) => ({
              player: roster.playerOf(view.seat),
              health: Counter.match(view.counter, { Unjammed: ({ health }) => health, Jammed: () => undefined }),
              items: nonEmpty(view.slots.flatMap(Option.match({ onNone: () => [], onSome: (item) => [itemName(item)] }))),
            })),
            gun: gunOf(board, roster),
            events: roundEventsOf(source, roster, you),
            moves: menu.map((move) => moveText(roster, seat, move)),
          }),
        });
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
      const prompt = yield* Result.fromOption(promptFor(source, seat), () => "It is not your turn. Call get_game and wait until status is \"your turn\".");

      if (turn !== undefined && turn !== prompt.ticket.generation) {
        return yield* Result.fail(`Stale move: you saw turn ${turn}, but the game is at turn ${prompt.ticket.generation}. Call get_game for the current moves.`);
      }

      if (!Number.isInteger(index) || index < 0 || index >= prompt.menu.length) {
        return yield* Result.fail(`There is no move ${index}. Legal moves are 0 to ${prompt.menu.length - 1}.`);
      }

      return { match: prompt.ticket.match, generation: prompt.ticket.generation, seat, index };
    }),
  );
