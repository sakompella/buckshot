import { Array as Arr, Duration, Effect, Option, Predicate, Result, Schema, Stream } from "effect";
import { Command, Port, Runtime, Subscription, type Update } from "foldkit";
import { modifyFields } from "foldkit/struct";

import { playChain } from "./agent/moves.ts";
import { AgentCall, AgentReply, type MatchSession, runTool } from "./agent/tools.ts";
import type { AnswerError, Game } from "./bend.ts";
import { GameEvent, type Seat, SEATS_BY_TABLE, type SeatCount } from "./domain.ts";
import { aiPrompt, aiStep, begin, type Controller, controllerOf, isAi, play, type Progress } from "./driver.ts";
import { Message, type Model, type Session, SPEED_FACTOR, type Viewer } from "./model.ts";
import { rosterOf } from "./players.ts";
import { seedRng } from "./rng.ts";
import { describeError } from "./text.ts";
import { ports } from "./webmcp.ts";

const DEFAULT_SEED = 20261012;

// TABLE

const progressOf = (match: Session): Progress => ({ game: match.game, rng: match.rng, events: match.events, learned: match.learned, ais: match.ais, seed: match.seed });

const canAiMoveAgain = (game: Game, controllers: ReadonlyArray<Controller>): boolean =>
  (game.pending.kind === "Draw" || game.pending.kind === "Choose") && game.seats.some((seat) => isAi(controllerOf(controllers, seat)));

const withProgress = (match: Session, progress: Progress): Session => ({
  ...match,
  game: progress.game,
  rng: progress.rng,
  events: progress.events,
  stepStart: match.events.length,
  learnedStart: match.learned.length,
  learned: progress.learned,
  ais: progress.ais,
  isAutoplay: match.isAutoplay && canAiMoveAgain(progress.game, match.controllers),
});

const NEXT_CONTROLLER: Readonly<Record<Controller, Controller>> = { Human: "Story", Story: "DoN", DoN: "Agent", Agent: "Human" };

const cycleController = (controllers: ReadonlyArray<Controller>, seat: Seat): ReadonlyArray<Controller> =>
  controllers.map((controller, index) => (index === seat ? NEXT_CONTROLLER[controller] : controller));

// UPDATE

type Return = Update.Return<Model, Message>;

const applyResult = (model: Model, match: Session, result: Result.Result<Progress, AnswerError>): Return =>
  Result.match(result, {
    onSuccess: (progress) => ({
      model: modifyFields(model, {
        turn: (turn) => turn + 1,
        maybeMatch: () => Option.some(withProgress(match, progress)),
        maybeError: () => Option.none(),
      }),
    }),
    // A click on a menu the game has already moved past is a no-op, not an error.
    onFailure: (error) =>
      Predicate.isTagged(error, "StaleAnswer")
        ? { model }
        : {
            model: modifyFields(model, {
              maybeMatch: () => Option.some({ ...match, isAutoplay: false }),
              maybeError: () => Option.some(describeError(rosterOf(match.game.seats), error)),
            }),
          },
  });

const stepAi = (model: Model, match: Session): Return =>
  Option.match(aiPrompt(match.game, match.controllers), {
    onNone: () => ({ model }),
    onSome: (prompt) => applyResult(model, match, aiStep(progressOf(match), prompt)),
  });

const withMatch = (model: Model, toReturn: (match: Session) => Return): Return => Option.match(model.maybeMatch, { onNone: () => ({ model }), onSome: toReturn });

const startMatch = (model: Model): Return => {
  const { table, controllers, isItemsEnabled, seed } = model.setup;
  const matchNumber = model.matchCount + 1;

  return Result.match(begin(table, isItemsEnabled, matchNumber, seedRng(seed), controllers, seed), {
    onSuccess: (progress) => ({
      model: modifyFields(model, {
        matchCount: () => matchNumber,
        turn: (turn) => turn + 1,
        maybeError: () => Option.none(),
        maybeMatch: () =>
          Option.some({
            ...progress,
            stepStart: 0,
            learnedStart: 0,
            controllers,
            viewer: Option.getOrElse(
              Arr.findFirst(SEATS_BY_TABLE[table], (seat) => controllerOf(controllers, seat) === "Human"),
              (): Viewer => "Spectator",
            ),
            // The bots move on their own from the start, as at a real table.
            isAutoplay: canAiMoveAgain(progress.game, controllers),
          }),
      }),
    }),
    onFailure: (error) => ({ model: modifyFields(model, { maybeError: () => Option.some(describeError(rosterOf(SEATS_BY_TABLE[table]), error)) }) }),
  });
};

// AGENT

const ReplyToAgent = Command.define("ReplyToAgent", {
  args: { id: Schema.Number, reply: AgentReply },
  messages: [Message.CompletedReplyToAgent],
  execute: ({ id, reply }) => Port.emit(ports.outbound.agentReplied, { id, reply }).pipe(Effect.as(Message.CompletedReplyToAgent())),
});

/** Seats the table's controllers in seat order. Autoplay is on, so the bots move between the agents' turns. */
const startAgentMatch = (model: Model, table: SeatCount, isItemsEnabled: boolean, seed: number, tableControllers: ReadonlyArray<Controller>): Model => {
  const atTable = (seat: number): Option.Option<Controller> =>
    Arr.findFirstIndex(SEATS_BY_TABLE[table], (tableSeat) => tableSeat === seat).pipe(Option.flatMap((position) => Arr.get(tableControllers, position)));

  const controllers = model.setup.controllers.map((controller, seat) => Option.getOrElse(atTable(seat), () => controller));
  const configured = modifyFields(model, { setup: (setup) => ({ ...setup, table, controllers, isItemsEnabled, seed }) });

  return update(configured, Message.ClickedNewMatch()).model;
};

const applied = (model: Model) => ({ state: model, maybeError: model.maybeError });

/** The agent tools' view of the page. A move's steps are played at once, so a failed step leaves the match as it was. */
const pageSession: MatchSession<Model> = {
  current: (model) => model.maybeMatch,
  turn: (model) => model.turn,
  start: (model, { table, isItemsEnabled, maybeSeed, controllers }) => applied(startAgentMatch(model, table, isItemsEnabled, Option.getOrElse(maybeSeed, () => model.setup.seed), controllers)),
  move: (model, { seat, chain }) => applied(withMatch(model, (match) => applyResult(model, match, playChain(progressOf(match), seat, chain))).model),
};

/** Runs one tool call over the model. */
export const handleAgentCall = (model: Model, call: AgentCall) => runTool(pageSession, model, call);

export const update = (model: Model, message: Message): Return =>
  Message.match<Return>(message, {
    SelectedTable: ({ table }) => ({ model: modifyFields(model, { setup: (setup) => ({ ...setup, table }) }) }),
    ToggledController: ({ seat }) => ({
      model: modifyFields(model, {
        setup: (setup) => ({ ...setup, controllers: cycleController(setup.controllers, seat) }),
      }),
    }),
    ToggledItems: () => ({ model: modifyFields(model, { setup: (setup) => ({ ...setup, isItemsEnabled: !setup.isItemsEnabled }) }) }),
    UpdatedSeed: ({ value }) => ({
      model: modifyFields(model, { setup: (setup) => ({ ...setup, seed: Option.getOrElse(Option.filter(Option.some(Number.parseInt(value, 10)), Number.isSafeInteger), () => setup.seed) }) }),
    }),
    ClickedNewMatch: () => startMatch(model),
    ClickedLeaveMatch: () => ({ model: modifyFields(model, { maybeMatch: () => Option.none(), maybeError: () => Option.none() }) }),
    SelectedSpeed: ({ speed }) => ({ model: modifyFields(model, { speed: () => speed }) }),
    SelectedViewer: ({ viewer }) => withMatch(model, (match) => ({ model: modifyFields(model, { maybeMatch: () => Option.some({ ...match, viewer }) }) })),
    ClickedMove: ({ match: matchNumber, generation, seat, index }) =>
      withMatch(model, (match) => applyResult(model, match, play(progressOf(match), { match: matchNumber, generation }, seat, index, match.rng))),
    ClickedStep: () => withMatch(model, (match) => stepAi(model, match)),
    ToggledAutoplay: () => withMatch(model, (match) => ({ model: modifyFields(model, { maybeMatch: () => Option.some({ ...match, isAutoplay: !match.isAutoplay && canAiMoveAgain(match.game, match.controllers) }) }) })),
    TickedAutoplay: () => withMatch(model, (match) => (match.isAutoplay ? stepAi(model, match) : { model })),
    AgentCalled: ({ id, call }) => {
      const outcome = handleAgentCall(model, call);

      return { model: outcome.state, commands: [ReplyToAgent({ id, reply: outcome.reply })] };
    },
    CompletedReplyToAgent: () => ({ model }),
  });

// INIT

export const Flags = Schema.Struct({ isWebMcpAvailable: Schema.Boolean });

export type Flags = typeof Flags.Type;

export const init: Runtime.ApplicationInit<Model, Message, Flags> = ({ isWebMcpAvailable }) => ({
  model: {
    setup: { table: 2, controllers: ["DoN", "Human", "DoN", "DoN"], isItemsEnabled: true, seed: DEFAULT_SEED },
    speed: "Normal",
    matchCount: 0,
    turn: 0,
    maybeMatch: Option.none(),
    maybeError: Option.none(),
    isWebMcpAvailable,
  },
});

// SUBSCRIPTION

// The pause after an event, at Normal speed, long enough to see it.
const pauseAfter = (event: GameEvent): number =>
  GameEvent.matchOrElse(
    event,
    {
      Loaded: () => 2600,
      RoundWon: () => 4400,
      Fired: () => 2200,
      Used: () => 1000,
      Ejected: () => 1000,
      Inverted: () => 900,
      JamApplied: () => 900,
      Healed: () => 900,
      PickedUp: () => 700,
      Granted: () => 250,
      Placed: () => 250,
    },
    () => 400,
  );

const pauseAfterStep = (match: Session): number => Math.max(0, ...match.events.slice(match.stepStart).map(pauseAfter));

export const subscriptions = Subscription.make<Model, Message>()((entry) => ({
  agent: Port.subscriptionEntry(ports.inbound.agentCalled, ({ id, call }) => Message.AgentCalled({ id, call })),
  // One tick per request point: the stream restarts whenever the game moves on.
  autoplay: entry(
    { isAutoplay: Schema.Boolean, pauseMs: Schema.Number, match: Schema.Number, generation: Schema.Number },
    {
      modelToDependencies: (model) =>
        Option.match(model.maybeMatch, {
          onNone: () => ({ isAutoplay: false, pauseMs: 0, match: model.matchCount, generation: 0 }),
          onSome: (match) => ({
            isAutoplay: match.isAutoplay,
            pauseMs: Math.round(pauseAfterStep(match) * SPEED_FACTOR[model.speed]),
            match: model.matchCount,
            generation: match.game.ticket.generation,
          }),
        }),
      dependenciesToStream: ({ isAutoplay, pauseMs }) =>
        Stream.when(
          Stream.fromEffect(Effect.sleep(Duration.millis(pauseMs)).pipe(Effect.as(Message.TickedAutoplay()))),
          Effect.sync(() => isAutoplay),
        ),
    },
  ),
}));
