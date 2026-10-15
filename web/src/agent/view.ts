import { Array as Arr, Option, Result, Schema, SchemaTransformation } from "effect";

import type { Game } from "../bend.ts";
import { type Board, Briefcase, Counter, GameEvent, type LearnedSecret, type Seat, type SeatView, Stage } from "../domain.ts";
import { type Controller, controllerOf, promptsOf } from "../driver.ts";
import { type PlayerNumber, playerName, type Roster, rosterOf } from "../players.ts";
import { eventText, itemName, moveText, secretText } from "../text.ts";

// An Agent player's view and move checks. Every call names an Agent player and
// sees only what that player's screen shows: the board on the player's turn, what
// appeared since the player last acknowledged its events, and the notes that player heard.
// Players are numbered 1 to N in table order; the seat ids behind them never
// leave this module. Properties that are undefined are left out of the JSON.

/** The parts of a running match the agent's view is built from. */
export interface AgentSource {
  readonly game: Game;
  readonly controllers: ReadonlyArray<Controller>;
  readonly events: ReadonlyArray<GameEvent>;
  readonly learned: ReadonlyArray<LearnedSecret>;
  readonly seed: number;
  /** By seat: how many events the seat has acknowledged. Its views show the events after them. */
  readonly acknowledged: ReadonlyArray<number>;
}

export const NOTHING_ACKNOWLEDGED: ReadonlyArray<number> = [0, 0, 0, 0];

/** The acknowledgements after a seat acknowledged the first `eventCount` events. An older receipt leaves the count where it is. */
export const acknowledgedTo = (acknowledged: ReadonlyArray<number>, seat: Seat, eventCount: number): ReadonlyArray<number> =>
  acknowledged.map((count, index) => (index === seat ? Math.max(count, eventCount) : count));

/** What a view with events or moves was built at: the match, its request point, the player, and the end of the view's events. */
const Receipt = Schema.Struct({ match: Schema.Int, generation: Schema.Int, player: Schema.Int, events: Schema.Int });

export type Receipt = typeof Receipt.Type;

const Count = Schema.String.check(Schema.isPattern(/^\d+$/)).pipe(Schema.decodeTo(Schema.Int, SchemaTransformation.numberFromString));

/** A receipt as the agent carries it: one opaque string, "m<match>t<generation>p<player>e<events>". */
export const Token = Schema.TemplateLiteralParser(["m", Count, "t", Count, "p", Count, "e", Count]).pipe(
  Schema.decodeTo(
    Receipt,
    SchemaTransformation.transform({
      decode: ([, match, , generation, , player, , events]) => ({ match, generation, player, events }),
      encode: ({ match, generation, player, events }) => ["m", match, "t", generation, "p", player, "e", events] as const,
    }),
  ),
);

const tokenOf = Schema.encodeSync(Token);

export interface PlayerLine {
  readonly player: PlayerNumber;
  /** Not on screen while the player is jammed. */
  readonly health: number | undefined;
  readonly items: ReadonlyArray<string> | undefined;
  /** The item the player drew from the briefcase and has not placed yet. */
  readonly holding: string | undefined;
}

interface Standing {
  readonly player: PlayerNumber;
  readonly cash: number;
}

/** Not this player's turn: nothing else, so polling is cheap and delivers nothing. */
interface Waiting {
  readonly you: PlayerNumber;
  readonly status: "waiting";
}

/** The screen on this player's turn. */
interface YourTurn {
  readonly you: PlayerNumber;
  readonly status: "your turn";
  /** Plays one of these moves, and acknowledges these events. */
  readonly token: string;
  readonly players: ReadonlyArray<PlayerLine>;
  readonly gun: { readonly heldBy: PlayerNumber | undefined; readonly sawed: true | undefined } | undefined;
  /** What happened since this player last acknowledged: the public events, and the secrets this player heard, in order. */
  readonly events: ReadonlyArray<string> | undefined;
  readonly moves: ReadonlyArray<string>;
}

/** The final standings, and the last events until they are acknowledged. */
interface Over {
  readonly you: PlayerNumber;
  readonly status: "over";
  readonly standings: ReadonlyArray<Standing>;
  readonly events: ReadonlyArray<string> | undefined;
  readonly token: string | undefined;
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

/** The events after the first `acknowledged`, as this player saw them: each secret the player heard stands just after the event that gave it. */
const eventsSince = (source: AgentSource, roster: Roster, seat: Seat, acknowledged: number): ReadonlyArray<string> => {
  const heardAt = (count: number): ReadonlyArray<string> => source.learned.flatMap((note) => (note.seat === seat && note.at === count ? [secretText(note.secret)] : []));

  return source.events.slice(acknowledged).flatMap((event, index) => [eventText(roster, event), ...heardAt(acknowledged + index + 1)]);
};

const gunOf = (board: Board, roster: Roster): YourTurn["gun"] => {
  const heldBy = Stage.matchOrElse(board.stage, { Playing: ({ seat, mode }) => (mode === "Aiming" ? Option.some(roster.playerOf(seat)) : Option.none()) }, () => Option.none<PlayerNumber>());
  const sawed = board.gun.sawed ? true : undefined;

  return Option.isNone(heldBy) && sawed === undefined ? undefined : { heldBy: Option.getOrUndefined(heldBy), sawed };
};

const lineOf = (roster: Roster, view: SeatView): PlayerLine => ({
  player: roster.playerOf(view.seat),
  health: Counter.match(view.counter, { Unjammed: ({ health }) => health, Jammed: () => undefined }),
  items: nonEmpty(view.slots.flatMap(Option.match({ onNone: () => [], onSome: (item) => [itemName(item)] }))),
  holding: Briefcase.matchOrElse(view.briefcase, { Holding: ({ item }) => itemName(item) }, () => undefined),
});

const standingsOf = (board: Board, roster: Roster): ReadonlyArray<Standing> =>
  board.seats.toSorted((left, right) => right.cash - left.cash).map((view) => ({ player: roster.playerOf(view.seat), cash: view.cash }));

/** The view of one Agent player, or why there is none. Building it changes nothing: only a later acknowledgement moves past its events. */
export const agentGame = (source: AgentSource, player: PlayerNumber): Result.Result<AgentGame, string> => {
  const roster = rosterOf(source.game.seats);

  return Result.map(agentSeat(source, roster, player), (you): AgentGame => {
    const { board, pending, ticket } = source.game;
    const events = nonEmpty(eventsSince(source, roster, you, Option.getOrElse(Arr.get(source.acknowledged, you), () => 0)));
    const token = tokenOf({ match: ticket.match, generation: ticket.generation, player, events: source.events.length });

    return pending.kind === "Finished"
      ? { you: player, status: "over", standings: standingsOf(board, roster), events, token: events === undefined ? undefined : token }
      : Option.match(promptFor(source, you), {
          onNone: (): AgentGame => ({ you: player, status: "waiting" }),
          onSome: ({ seat, menu }): AgentGame => ({
            you: player,
            status: "your turn",
            token,
            players: board.seats.map((view) => lineOf(roster, view)),
            gun: gunOf(board, roster),
            events,
            moves: menu.map((move) => moveText(roster, seat, move)),
          }),
        });
  });
};

/** The events a receipt acknowledges for its player's seat, or why it does not belong to this match and player. */
export const agentAcknowledgement = (source: AgentSource, player: PlayerNumber, receipt: Receipt): Result.Result<{ readonly seat: Seat; readonly events: number }, string> =>
  Result.flatMap(agentSeat(source, rosterOf(source.game.seats), player), (seat) => {
    const { match, generation } = source.game.ticket;

    if (receipt.match !== match) return Result.fail("That token is from another match. Call get_game without a token for this match's view.");

    if (receipt.player !== player) return Result.fail(`That token is Player ${receipt.player}'s, not ${playerName(player)}'s. Pass the token from this player's own view.`);

    if (receipt.generation > generation || receipt.events > source.events.length) return Result.fail("That token is from a point this match has not reached. Pass a token from a view this match returned.");

    return Result.succeed({ seat, events: receipt.events });
  });

/** A move as the buttons send it: the request point it answers, and the menu index. */
export interface SeatMove {
  readonly match: number;
  readonly generation: number;
  readonly seat: Seat;
  readonly index: number;
}

/** The click an Agent player's move stands for, or why the move is refused. The receipt must be from the player's current turn. */
export const agentMove = (source: AgentSource, player: PlayerNumber, index: number, receipt: Receipt): Result.Result<SeatMove, string> =>
  Result.flatMap(agentAcknowledgement(source, player, receipt), ({ seat }) =>
    Result.gen(function* () {
      const prompt = yield* Result.fromOption(promptFor(source, seat), () => "It is not your turn. Call get_game and wait until status is \"your turn\".");

      if (receipt.generation !== prompt.ticket.generation) {
        return yield* Result.fail("Stale move: that token is from an earlier turn, and the game has moved since. Call get_game for the current moves and token.");
      }

      if (!Number.isInteger(index) || index < 0 || index >= prompt.menu.length) {
        return yield* Result.fail(`There is no move ${index}. Legal moves are 0 to ${prompt.menu.length - 1}.`);
      }

      return { match: prompt.ticket.match, generation: prompt.ticket.generation, seat, index };
    }),
  );
