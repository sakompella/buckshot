import { flow, Option, Result, Schema, SchemaTransformation } from "effect";

import { SEATS_BY_TABLE, SeatCount } from "../domain.ts";
import { Controller, controllerOf } from "../driver.ts";
import { Letter, rosterOf } from "../players.ts";
import { agentGame, agentMove, type AgentSource, type SeatMove } from "./view.ts";

// The agent tools, whatever carries them: their names, descriptions and input
// schemas, and what each call does to a match. A front end (WebMCP in the page,
// the stdio MCP server) lists these tools, decodes a call with decodeCall, and
// runs it with runTool over its own MatchSession.

export const RULES =
  "Buckshot: a shotgun is loaded with a hidden mix of live and blank shells, and each load is announced. On your turn you shoot a player or yourself, or use an item; a live shell does damage and a blank fired at yourself keeps your turn. All players return alive at each round start. A round ends only when one player remains alive. That player wins the round and its prize, and the most cash after the last round wins. A match has three rounds.";

const PlayerArgument = Letter.annotate({ description: 'The Agent player this call is for: the letter in the player names, "A" for Player A, then "B" and so on up to the last player at the table (at most "D").' });

const GetGameArguments = Schema.Struct({ player: PlayerArgument });

const Count = Schema.Int.check(Schema.isGreaterThanOrEqualTo(0));

const PlayMoveArguments = Schema.Struct({
  player: PlayerArgument,
  move: Count.annotate({ description: "The number of the move, from the view's moves." }),
  turn: Count.annotate({ description: "The turn of the view the move was chosen from. Any other turn is refused." }),
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
        'One controller per player, in player order (Player A first), for example ["Agent", "Agent", "DoN"]. Agent players are played through these tools, DoN and Story are bots, Human players wait for clicks in the browser. Optional.',
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
    description: `${RULES} Returns your view as JSON, without any field that has nothing to show. Reading it changes nothing: until a player moves, every call returns the same view. When it is not your turn the view is just {"status":"waiting"}: call get_game again in a moment. On your turn it is what your screen shows: status "your turn"; turn, to pass to play_move; players with health (not shown while jammed), item names, and, while players grab from the briefcase, holding, the item a player drew and has not placed yet; gun, with sawed when it is; events, what happened since your previous turn ended (your last move first, then the others' moves; from the match start on your first turn), with what only you learned from the magnifying glass or the phone in its place (a load's live and blank counts, round wins and prizes, and round starts are events; turn order is clockwise at each round's start and changes only when an event says so); and moves, your legal moves, each with its number (move) and its words (label). Each move is a whole action: "Shoot Player B" picks up the shotgun and fires, "Grab an item" draws one and puts it in a free slot. Events are not shown again on a later turn, so remember what you need. When the match is over the view is "over" with the events since your last turn ended and the final standings, which show each player's cash. Several players can be Agents; each sees only its own secrets.`,
    inputSchema: inputSchemaOf(GetGameArguments),
    isReadOnly: true,
    decodeCall: decoder("get_game", GetGameArguments, AgentCall.cases.GetGame.make),
  },
  {
    name: "play_move",
    description:
      'Play one of your legal moves, by its number from the view\'s moves, with the turn from that view. Refused, playing nothing, if it is not your turn or the turn is not the current one: every move by any player and every new match starts a new turn, so a repeated move or one from an earlier view or match is refused. After a refusal call get_game for the current moves and turn. Returns your view as get_game does. The other players move on their own, so call get_game until status is "your turn".',
    inputSchema: inputSchemaOf(PlayMoveArguments),
    isReadOnly: false,
    decodeCall: decoder("play_move", PlayMoveArguments, AgentCall.cases.PlayMove.make),
  },
  {
    name: "new_match",
    description:
      "Start a new match. Refused while a match is in progress: finish it first. By default Player A is the Agent and DoN bots play the others; pass controllers to make more players Agents. Returns each player's letter and controller, and the seed; then call get_game for an Agent player.",
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
  /** Advances with every accepted move and every new match, across matches, so it never repeats in a session. */
  readonly turn: (state: S) => number;
}

export interface ToolOutcome<S> {
  readonly state: S;
  readonly reply: AgentReply;
}

export const NO_MATCH = "No match is running. Call new_match to start one.";

export const MATCH_IN_PROGRESS = "A match is in progress; finish it first.";

const refused = <S>(state: S, reason: string): ToolOutcome<S> => ({ state, reply: AgentReply.cases.Refused.make({ reason }) });

const answered = <S>(state: S, text: string): ToolOutcome<S> => ({ state, reply: AgentReply.cases.Answered.make({ text }) });

const withSource = <S>(session: MatchSession<S>, state: S, reply: (source: AgentSource) => ToolOutcome<S>): ToolOutcome<S> =>
  Option.match(session.current(state), { onNone: () => refused(state, NO_MATCH), onSome: reply });

/** The player's view. Replying changes nothing, so a lost or repeated reply loses nothing. */
const viewReply = <S>(session: MatchSession<S>, state: S, player: Letter): ToolOutcome<S> =>
  withSource(session, state, (source) =>
    Result.match(agentGame(source, session.turn(state), player), {
      onSuccess: (game) => answered(state, JSON.stringify(game)),
      onFailure: (reason) => refused(state, reason),
    }),
  );

/** Replies from the state a change left, or with the error it ran into. */
const after = <S>({ state, maybeError }: Applied<S>, reply: (state: S) => ToolOutcome<S>): ToolOutcome<S> =>
  Option.match(maybeError, { onNone: () => reply(state), onSome: (reason) => refused(state, reason) });

/** The table as new_match left it: each player's letter and controller, so the agents know which players to name. */
const tableReply = <S>(session: MatchSession<S>, state: S): ToolOutcome<S> =>
  withSource(session, state, (source) => {
    const roster = rosterOf(source.game.seats, source.letters);

    return answered(
      state,
      JSON.stringify({
        players: source.game.seats.map((seat) => ({ player: roster.playerOf(seat).letter, controller: controllerOf(source.controllers, seat) })),
        seed: String(source.seed),
      }),
    );
  });

const defaultControllers = (table: SeatCount): ReadonlyArray<Controller> => SEATS_BY_TABLE[table].map((_, position): Controller => (position === 0 ? "Agent" : "DoN"));

/** Some player still has a move. A finished match, or one stuck with no legal move, can be replaced. */
const isInProgress = (source: AgentSource): boolean => source.game.pending.kind === "Choose";

/** Runs one tool call over a session. A refused call leaves the state as it was. */
export const runTool = <S>(session: MatchSession<S>, state: S, call: AgentCall): ToolOutcome<S> =>
  AgentCall.match<ToolOutcome<S>>(call, {
    GetGame: ({ player }) => viewReply(session, state, player),
    PlayMove: ({ player, move, turn }) =>
      withSource(session, state, (source) =>
        Result.match(agentMove(source, session.turn(state), player, move, turn), {
          onFailure: (reason) => refused(state, reason),
          onSuccess: (seatMove) => after(session.move(state, seatMove), (moved) => viewReply(session, moved, player)),
        }),
      ),
    NewMatch: ({ players, items, seed, controllers = defaultControllers(players) }) => {
      if (Option.exists(session.current(state), isInProgress)) return refused(state, MATCH_IN_PROGRESS);

      return controllers.length === players
        ? after(session.start(state, { table: players, isItemsEnabled: items, maybeSeed: Option.fromUndefinedOr(seed), controllers }), (started) => tableReply(session, started))
        : refused(state, `controllers must list one controller per player: ${players} for ${players} players, not ${controllers.length}.`);
    },
  });
