import { flow, Option, Result, Schema } from "effect";

import { SEATS_BY_TABLE, SeatCount } from "../domain.ts";
import { Controller, controllerOf } from "../driver.ts";
import { PlayerNumber, rosterOf } from "../players.ts";
import { type AgentSource, agentGame, agentMove, type SeatMove } from "./view.ts";

// The agent tools, whatever carries them: their names, descriptions and input
// schemas, and what each call does to a match. A front end (WebMCP in the page,
// the stdio MCP server) lists these tools, decodes a call with decodeCall, and
// runs it with runTool over its own MatchSession.

const RULES =
  "Buckshot: a shotgun is loaded with a hidden mix of live and blank shells, and each load is announced. On your turn you shoot a player or yourself, or use an item; a live shell does damage and a blank fired at yourself keeps your turn. The last player alive wins the round and its prize, and the most cash after the last round wins.";

const PlayerArgument = PlayerNumber.annotate({ description: "The Agent player this call is for: the number in the player names, 1 for Player 1 up to the number of players at the table (at most 4)." });

const GetGameArguments = Schema.Struct({ player: PlayerArgument });

const PlayMoveArguments = Schema.Struct({
  player: PlayerArgument,
  index: Schema.Int.check(Schema.isGreaterThanOrEqualTo(0)).annotate({ description: "The index of the move in get_game's moves list." }),
  turn: Schema.optionalKey(Schema.Int.annotate({ description: "The turn value from get_game. Pass it so a stale move is refused instead of played." })),
});

const NewMatchArguments = Schema.Struct({
  players: SeatCount.annotate({ description: "Number of players at the table." }),
  items: Schema.Boolean.annotate({ description: "Whether items are in play." }),
  seed: Schema.optionalKey(Schema.String.annotate({ description: "An integer seed for the shell draws, to replay a match. Optional." })),
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
    description: `${RULES} Returns your view as JSON: the public board, your private notes, recent events, whether it is your turn, and your legal moves as a numbered list. Only legal moves are listed. Several players can be Agents; each sees only its own notes.`,
    inputSchema: inputSchemaOf(GetGameArguments),
    isReadOnly: true,
    decodeCall: decoder("get_game", GetGameArguments, AgentCall.cases.GetGame.make),
  },
  {
    name: "play_move",
    description:
      "Play one of your legal moves, by its number in get_game's moves list. Only legal moves are listed, so any listed number is allowed. Fails if it is not your turn or the turn is stale; any player's move advances the turn. Returns your new view. The other players move on their own, so call get_game until isYourTurn is true.",
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
}

export interface ToolOutcome<S> {
  readonly state: S;
  readonly reply: AgentReply;
}

export const NO_MATCH = "No match is running. Call new_match to start one.";

const SEED_PATTERN = /^-?\d+$/;

const refused = <S>(state: S, reason: string): ToolOutcome<S> => ({ state, reply: AgentReply.cases.Refused.make({ reason }) });

const answered = <S>(state: S, text: string): ToolOutcome<S> => ({ state, reply: AgentReply.cases.Answered.make({ text }) });

const viewReply = <S>(session: MatchSession<S>, state: S, player: PlayerNumber): ToolOutcome<S> =>
  Option.match(session.current(state), {
    onNone: () => refused(state, NO_MATCH),
    onSome: (source) => Result.match(agentGame(source, player), { onSuccess: (game) => answered(state, JSON.stringify(game)), onFailure: (reason) => refused(state, reason) }),
  });

/** Replies from the state a change left, or with the error it ran into. */
const after = <S>({ state, maybeError }: Applied<S>, reply: (state: S) => ToolOutcome<S>): ToolOutcome<S> =>
  Option.match(maybeError, { onNone: () => reply(state), onSome: (reason) => refused(state, reason) });

/** The table as new_match left it: each player's number and controller, so the agents know which players to name. */
const tableReply = <S>(session: MatchSession<S>, state: S): ToolOutcome<S> =>
  Option.match(session.current(state), {
    onNone: () => refused(state, NO_MATCH),
    onSome: (source) => {
      const roster = rosterOf(source.game.seats);

      return answered(
        state,
        JSON.stringify({
          players: source.game.seats.map((seat) => ({ player: roster.playerOf(seat), controller: controllerOf(source.controllers, seat) })),
          seed: String(source.seed),
          hint: "Call get_game with an Agent player's number to see that player's view and moves.",
        }),
      );
    },
  });

const defaultControllers = (table: SeatCount): ReadonlyArray<Controller> => SEATS_BY_TABLE[table].map((_, position): Controller => (position === 0 ? "Agent" : "DoN"));

/** Runs one tool call over a session. */
export const runTool = <S>(session: MatchSession<S>, state: S, call: AgentCall): ToolOutcome<S> =>
  AgentCall.match<ToolOutcome<S>>(call, {
    GetGame: ({ player }) => viewReply(session, state, player),
    PlayMove: ({ player, index, turn }) =>
      Option.match(session.current(state), {
        onNone: () => refused(state, NO_MATCH),
        onSome: (source) =>
          Result.match(agentMove(source, player, index, turn), {
            onFailure: (reason) => refused(state, reason),
            onSuccess: (move) => after(session.move(state, move), (moved) => viewReply(session, moved, player)),
          }),
      }),
    NewMatch: ({ players, items, seed, controllers = defaultControllers(players) }) =>
      seed !== undefined && !SEED_PATTERN.test(seed)
        ? refused(state, `The seed must be an integer, not "${seed}".`)
        : controllers.length === players
          ? after(session.start(state, { table: players, isItemsEnabled: items, maybeSeed: Option.map(Option.fromUndefinedOr(seed), Number), controllers }), (started) => tableReply(session, started))
          : refused(state, `controllers must list one controller per player: ${players} for ${players} players, not ${controllers.length}.`),
  });
