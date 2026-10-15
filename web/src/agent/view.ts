import { Array as Arr, Option, Result } from "effect";

import { type Board, Briefcase, Counter, GameEvent, type Seat, type SeatView, Secret } from "../domain.ts";
import { type Controller, controllerOf, type Progress, promptsOf } from "../driver.ts";
import { type PlayerNumber, playerName, type Roster, rosterOf } from "../players.ts";
import { describeError, eventText, itemName, secretText } from "../text.ts";
import { agentMoves, type Chain } from "./moves.ts";

// An Agent player's view and move checks. Every call names an Agent player and
// sees only what that player's screen shows: the board on the player's turn, the
// events since its previous turn ended, and the secrets that player heard.
// Everything comes from the match log, so reading a view changes nothing.
// Players are numbered 1 to N in table order; the seat ids behind them never
// leave this module. Properties that are undefined are left out of the JSON.

/** The parts of a running match the agent's view is built from. */
export interface AgentSource extends Progress {
  readonly controllers: ReadonlyArray<Controller>;
}

export interface PlayerLine {
  readonly player: PlayerNumber;
  /** Not on screen while the player is jammed. */
  readonly health: number | undefined;
  readonly items: ReadonlyArray<string> | undefined;
  /** While players grab: the item the player drew from the briefcase and has not placed yet. */
  readonly holding: string | undefined;
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
  /** Names this point of the session, so a move chosen here plays only here. */
  readonly turn: number;
  readonly players: ReadonlyArray<PlayerLine>;
  readonly gun: { readonly sawed: true } | undefined;
  readonly events: ReadonlyArray<string> | undefined;
  readonly moves: ReadonlyArray<string>;
}

/** The final standings, and the events since the player's last turn ended. */
interface Over {
  readonly you: PlayerNumber;
  readonly status: "over";
  readonly standings: ReadonlyArray<Standing>;
  readonly events: ReadonlyArray<string> | undefined;
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

const hasTurn = (source: AgentSource, seat: Seat): boolean => promptsOf(source.game).some((prompt) => prompt.seat === seat);

const nonEmpty = <A>(values: ReadonlyArray<A>): ReadonlyArray<A> | undefined => (values.length === 0 ? undefined : values);

/**
 * The first thing a move by this seat puts in its log: it picked up the shotgun, used an item of its own, or drew from the briefcase, or learned it was empty.
 * A secret stands at the end of its step, so the empty briefcase marks the start only because that grab emits no event before the next draw.
 */
const startsMove = (seat: Seat) => ({
  event: (event: GameEvent): boolean =>
    GameEvent.matchOrElse(event, { PickedUp: (picked) => picked.seat === seat, Used: (used) => used.seat === seat && used.owner === seat, Granted: (granted) => granted.seat === seat }, () => false),
  secret: Secret.guards.EmptyBriefcase,
});

interface LogLine {
  readonly text: string;
  readonly isMoveStart: boolean;
}

/** The match log as this seat saw it: the public events, each secret the seat heard just after the event that told it. */
const logOf = (source: AgentSource, roster: Roster, seat: Seat): ReadonlyArray<LogLine> => {
  const starts = startsMove(seat);

  const heardAt = (count: number): ReadonlyArray<LogLine> =>
    source.learned.flatMap((note) => (note.seat === seat && note.at === count ? [{ text: secretText(note.secret), isMoveStart: starts.secret(note.secret) }] : []));

  return [...heardAt(0), ...source.events.flatMap((event, index) => [{ text: eventText(roster, event), isMoveStart: starts.event(event) }, ...heardAt(index + 1)])];
};

/** The log since the seat's previous turn ended, which is when its last move began; the whole match before its first move. */
const eventsSinceLastTurn = (source: AgentSource, roster: Roster, seat: Seat): ReadonlyArray<string> | undefined => {
  const log = logOf(source, roster, seat);
  const lastMove = Option.getOrElse(Arr.findLastIndex(log, ({ isMoveStart }) => isMoveStart), () => 0);

  return nonEmpty(log.slice(lastMove).map(({ text }) => text));
};

const gunOf = (board: Board): YourTurn["gun"] => (board.gun.sawed ? { sawed: true } : undefined);

const lineOf = (roster: Roster, view: SeatView): PlayerLine => ({
  player: roster.playerOf(view.seat),
  health: Counter.match(view.counter, { Unjammed: ({ health }) => health, Jammed: () => undefined }),
  items: nonEmpty(view.slots.flatMap(Option.match({ onNone: () => [], onSome: (item) => [itemName(item)] }))),
  holding: Briefcase.matchOrElse(view.briefcase, { Holding: ({ item }) => itemName(item) }, () => undefined),
});

const standingsOf = (board: Board, roster: Roster): ReadonlyArray<Standing> =>
  board.seats.toSorted((left, right) => right.cash - left.cash).map((view) => ({ player: roster.playerOf(view.seat), cash: view.cash }));

/** The view of one Agent player at the session's `turn`, or why there is none. */
export const agentGame = (source: AgentSource, turn: number, player: PlayerNumber): Result.Result<AgentGame, string> => {
  const roster = rosterOf(source.game.seats);

  return Result.flatMap(agentSeat(source, roster, player), (you): Result.Result<AgentGame, string> => {
    const { board, pending } = source.game;

    if (pending.kind === "Finished") return Result.succeed({ you: player, status: "over", standings: standingsOf(board, roster), events: eventsSinceLastTurn(source, roster, you) });

    if (!hasTurn(source, you)) return Result.succeed({ you: player, status: "waiting" });

    return Result.mapBoth(agentMoves(source, roster, you), {
      onFailure: (error) => describeError(roster, error),
      onSuccess: (moves): AgentGame => ({
        you: player,
        status: "your turn",
        turn,
        players: board.seats.map((view) => lineOf(roster, view)),
        gun: gunOf(board),
        events: eventsSinceLastTurn(source, roster, you),
        moves: moves.map(({ label }) => label),
      }),
    });
  });
};

/** An Agent player's move: the seat and the machine moves it chains. */
export interface SeatMove {
  readonly seat: Seat;
  readonly chain: Chain;
}

/** The chain an Agent player's move stands for, or why the move is refused. `given` must be the session's current `turn`. */
export const agentMove = (source: AgentSource, turn: number, player: PlayerNumber, move: number, given: number): Result.Result<SeatMove, string> => {
  const roster = rosterOf(source.game.seats);

  return Result.flatMap(agentSeat(source, roster, player), (seat) =>
    Result.gen(function* () {
      if (!hasTurn(source, seat)) return yield* Result.fail('It is not your turn. Call get_game and wait until status is "your turn".');

      if (given !== turn) return yield* Result.fail(`Stale move: this is turn ${turn}, not ${given}. Call get_game for the current moves.`);

      const moves = yield* Result.mapError(agentMoves(source, roster, seat), (error) => describeError(roster, error));
      const chosen = yield* Result.fromOption(Arr.get(moves, move), () => `There is no move ${move}. Legal moves are 0 to ${moves.length - 1}.`);

      return { seat, chain: chosen.chain };
    }),
  );
};
