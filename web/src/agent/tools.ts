import { flow, Option, Result, Schema, SchemaTransformation } from "effect";

import { SEATS_BY_TABLE, type Seat, SeatCount } from "../domain.ts";
import { Controller, controllerOf } from "../driver.ts";
import { PlayerNumber, rosterOf } from "../players.ts";
import { agentAcknowledgement, agentGame, agentMove, type AgentSource, type SeatMove, Token } from "./view.ts";

// The agent tools, whatever carries them: their names, descriptions and input
// schemas, and what each call does to a match. A front end (WebMCP in the page,
// the stdio MCP server) lists these tools, decodes a call with decodeCall, and
// runs it with runTool over its own MatchSession.

const RULES =
  "Buckshot: a shotgun is loaded with a hidden mix of live and blank shells, and each load is announced. On your turn you shoot a player or yourself, or use an item; a live shell does damage and a blank fired at yourself keeps your turn. The last player alive wins the round and its prize, and the most cash after the last round wins. A match has three rounds.";

const PlayerArgument = PlayerNumber.annotate({ description: "The Agent player this call is for: the number in the player names, 1 for Player 1 up to the number of players at the table (at most 4)." });

const GetGameArguments = Schema.Struct({
  player: PlayerArgument,
  token: Schema.optionalKey(Token.pipe(Schema.annotateEncoded({ description: "The token from this player's last view, to acknowledge the events it showed. Until a token acknowledges them, every view repeats them." }))),
});

const PlayMoveArguments = Schema.Struct({
  player: PlayerArgument,
  index: Schema.Int.check(Schema.isGreaterThanOrEqualTo(0)).annotate({ description: "The position of the move in the view's moves list, from 0." }),
  token: Token.pipe(Schema.annotateEncoded({ description: "The token from the view the move was chosen from. A token from an earlier turn or match is refused. Playing the move also acknowledges that view's events." })),
});

const SEED_RANGE = "an integer from -9007199254740991 to 9007199254740991";

/** A seed as the agent writes it, an integer string, decoded to a safe integer so the seed new_match returns replays the match. */
const Seed = Schema.String.check(Schema.isPattern(/^-?\d+$/, { message: `Expected ${SEED_RANGE}` })).pipe(
  Schema.decodeTo(Schema.Int.annotate({ message: `Expected ${SEED_RANGE}` }), SchemaTransformation.numberFromString),
);

const NewMatchArguments = Schema.Struct({
  players: SeatCount.annotate({ description: "Number of players at the table." }),
  items: Schema.Boolean.annotate({ description: "Whether items are in play." }),
  seed: Schema.optionalKey(Seed.pipe(Schema.annotateEncoded({ description: `A seed for the shell draws, ${SEED_RANGE}, as a string, to replay a match. Optional.` }))),
  controllers: Schema.optionalKey(
    Schema.Array(Controller).annotate({
      description:
        'One controller per player, in player order (Player 1 first), for example ["Agent", "Agent", "DoN"]. Agent players are played through these tools, DoN and Story are bots, Human players wait for clicks in the browser. Optional.',
    }),
  ),
});

export const AgentCall = Schema.TaggedUnion({
  GetGame: GetGameArguments.fields,
  PlayMove: PlayMoveArguments.fields,
  NewMatch: NewMatchArguments.fields,
});

export type AgentCall = typeof AgentCall.Type;

export const AgentReply = Schema.TaggedUnion({
  Answered: { text: Schema.String },
  Refused: { reason: Schema.String },
});

export type AgentReply = typeof AgentReply.Type;

/** Decodes a tool's arguments into its call, or says what is wrong with them. */
const decoder = <A>(name: string, schema: Schema.ConstraintDecoder<A>, toCall: (input: A) => AgentCall) =>
  flow(
    Schema.decodeUnknownResult(schema),
    Result.mapBoth({ onSuccess: toCall, onFailure: (error) => `Invalid arguments for ${name}: ${error.message}` }),
  );

const inputSchemaOf = (schema: Schema.Top) => Schema.toJsonSchemaDocument(schema).schema;

export const tools = [
  {
    name: "get_game",
    description: `${RULES} Returns your view as JSON, without any field that has nothing to show. When it is not your turn the view is just {"status":"waiting"}: call get_game again in a moment. On your turn it is what your screen shows: status "your turn"; token, to pass to play_move; players with health (not shown while jammed), item names, and holding, the item a player drew from the briefcase and has not placed yet; gun, with heldBy once a player has picked it up, and sawed when it is; events, what happened since you last acknowledged events, from the start of the match at first, with what only you learned from the magnifying glass or the phone in its place (a load's live and blank counts, round wins and prizes, and round starts are events; turn order is clockwise at each round's start and changes only when an event says so); and moves, your legal moves, played by their position in the list, from 0. Every view repeats its events until you acknowledge them by passing its token to your next get_game or play_move, so a lost reply loses nothing; after that they are not shown again, so remember what you need. When the match is over the view is "over" with the final standings, which show each player's cash, and, until you acknowledge them, the last events and a token. Several players can be Agents; each sees only its own secrets and events.`,
    inputSchema: inputSchemaOf(GetGameArguments),
    isReadOnly: false,
    decodeCall: decoder("get_game", GetGameArguments, AgentCall.cases.GetGame.make),
  },
  {
    name: "play_move",
    description:
      'Play one of your legal moves, by its position in the view\'s moves list, from 0, with the token from that view. Only legal moves are listed. Playing also acknowledges that view\'s events. Refused, playing nothing, if it is not your turn or the token is from an earlier turn or another match; any player\'s move advances the turn, so after a refusal call get_game for the current moves and token. Returns your view as get_game does. The other players move on their own, so call get_game until status is "your turn".',
    inputSchema: inputSchemaOf(PlayMoveArguments),
    isReadOnly: false,
    decodeCall: decoder("play_move", PlayMoveArguments, AgentCall.cases.PlayMove.make),
  },
  {
    name: "new_match",
    description:
      "Start a new match. It replaces any match in progress. By default Player 1 is the Agent and DoN bots play the others; pass controllers to make more players Agents. Returns each player's number and controller, and the seed; then call get_game for an Agent player.",
    inputSchema: inputSchemaOf(NewMatchArguments),
    isReadOnly: false,
    decodeCall: decoder("new_match", NewMatchArguments, AgentCall.cases.NewMatch.make),
  },
] as const;

/** The text a front end hands the agent. A refusal is {"error": ...} JSON, since Chrome hides a thrown error's message from the agent. */
export const replyText = (reply: AgentReply): string =>
  AgentReply.match(reply, { Answered: ({ text }) => text, Refused: ({ reason }) => JSON.stringify({ error: reason }) });

/** A table new_match asks for. controllers has one entry per player at the table, in table order. */
export interface MatchSetup {
  readonly table: SeatCount;
  readonly isItemsEnabled: boolean;
  readonly maybeSeed: Option.Option<number>;
  readonly controllers: ReadonlyArray<Controller>;
}

/** A session state after a change, with the error the change ran into, if any. */
export interface Applied<S> {
  readonly state: S;
  readonly maybeError: Option.Option<string>;
}

/** Where matches run: the page's Foldkit model, or a headless table in the MCP server. */
export interface MatchSession<S> {
  readonly current: (state: S) => Option.Option<AgentSource>;
  readonly start: (state: S, setup: MatchSetup) => Applied<S>;
  readonly move: (state: S, move: SeatMove) => Applied<S>;
  /** Records that a seat acknowledged the first `eventCount` events, so its views start after them. */
  readonly acknowledge: (state: S, seat: Seat, eventCount: number) => S;
}

export interface ToolOutcome<S> {
  readonly state: S;
  readonly reply: AgentReply;
}

export const NO_MATCH = "No match is running. Call new_match to start one.";

const refused = <S>(state: S, reason: string): ToolOutcome<S> => ({ state, reply: AgentReply.cases.Refused.make({ reason }) });

const answered = <S>(state: S, text: string): ToolOutcome<S> => ({ state, reply: AgentReply.cases.Answered.make({ text }) });

const withSource = <S>(session: MatchSession<S>, state: S, reply: (source: AgentSource) => ToolOutcome<S>): ToolOutcome<S> =>
  Option.match(session.current(state), { onNone: () => refused(state, NO_MATCH), onSome: reply });

/** The player's view. Replying changes nothing, so a lost or repeated reply loses no events. */
const viewReply = <S>(session: MatchSession<S>, state: S, player: PlayerNumber): ToolOutcome<S> =>
  withSource(session, state, (source) =>
    Result.match(agentGame(source, player), {
      onSuccess: (game) => answered(state, JSON.stringify(game)),
      onFailure: (reason) => refused(state, reason),
    }),
  );

/** Replies from the state a change left, or with the error it ran into. */
const after = <S>({ state, maybeError }: Applied<S>, reply: (state: S) => ToolOutcome<S>): ToolOutcome<S> =>
  Option.match(maybeError, { onNone: () => reply(state), onSome: (reason) => refused(state, reason) });

/** The table as new_match left it: each player's number and controller, so the agents know which players to name. */
const tableReply = <S>(session: MatchSession<S>, state: S): ToolOutcome<S> =>
  withSource(session, state, (source) => {
    const roster = rosterOf(source.game.seats);

    return answered(
      state,
      JSON.stringify({
        players: source.game.seats.map((seat) => ({ player: roster.playerOf(seat), controller: controllerOf(source.controllers, seat) })),
        seed: String(source.seed),
      }),
    );
  });

const defaultControllers = (table: SeatCount): ReadonlyArray<Controller> => SEATS_BY_TABLE[table].map((_, position): Controller => (position === 0 ? "Agent" : "DoN"));

/** Runs one tool call over a session. A refused call leaves the state as it was. */
export const runTool = <S>(session: MatchSession<S>, state: S, call: AgentCall): ToolOutcome<S> =>
  AgentCall.match<ToolOutcome<S>>(call, {
    GetGame: ({ player, token }) =>
      token === undefined
        ? viewReply(session, state, player)
        : withSource(session, state, (source) =>
            Result.match(agentAcknowledgement(source, player, token), {
              onFailure: (reason) => refused(state, reason),
              onSuccess: ({ seat, events }) => viewReply(session, session.acknowledge(state, seat, events), player),
            }),
          ),
    PlayMove: ({ player, index, token }) =>
      withSource(session, state, (source) =>
        Result.match(agentMove(source, player, index, token), {
          onFailure: (reason) => refused(state, reason),
          onSuccess: (move) => after(session.move(state, move), (moved) => viewReply(session, session.acknowledge(moved, move.seat, token.events), player)),
        }),
      ),
    NewMatch: ({ players, items, seed, controllers = defaultControllers(players) }) =>
      controllers.length === players
        ? after(session.start(state, { table: players, isItemsEnabled: items, maybeSeed: Option.fromUndefinedOr(seed), controllers }), (started) => tableReply(session, started))
        : refused(state, `controllers must list one controller per player: ${players} for ${players} players, not ${controllers.length}.`),
  });
