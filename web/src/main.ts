import { Array as Arr, Duration, Effect, Match, Option, Predicate, Result, Schema, Stream } from "effect";
import { Command, Port, Runtime, Subscription, type Update } from "foldkit";
import { modifyFields } from "foldkit/struct";

import { AgentCall, AgentReply, agentGame, agentMove, NO_MATCH, ports } from "./agent.ts";
import type { AnswerError, Game } from "./bend.ts";
import { GameEvent, type Seat, type SeatCount } from "./domain.ts";
import { aiPrompt, aiStep, begin, type Controller, controllerOf, isAi, play, type Progress } from "./driver.ts";
import { Message, type Model, SEATS_BY_TABLE, type Session, type Speed, type Viewer } from "./model.ts";
import { seedRng } from "./rng.ts";

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
  learned: progress.learned,
  ais: progress.ais,
  isAutoplay: match.isAutoplay && canAiMoveAgain(progress.game, match.controllers),
});

const describeError = (error: AnswerError): string =>
  Match.value(error).pipe(
    Match.tag("BendContractError", ({ call, detail }) => `Bend returned an unexpected value from ${call}: ${detail}`),
    Match.tag("StaleAnswer", () => "That move was for an earlier turn. Choose again."),
    Match.tag("NoPrompt", ({ seat }) => `Seat ${seat} has no move right now.`),
    Match.exhaustive,
  );

const NEXT_CONTROLLER: Readonly<Record<Controller, Controller>> = { Human: "Story", Story: "DoN", DoN: "Agent", Agent: "Human" };

const cycleController = (controllers: ReadonlyArray<Controller>, seat: Seat): ReadonlyArray<Controller> =>
  controllers.map((controller, index) => (index === seat ? NEXT_CONTROLLER[controller] : controller));

// UPDATE

type Return = Update.Return<Model, Message>;

const applyResult = (model: Model, match: Session, result: Result.Result<Progress, AnswerError>): Return =>
  Result.match(result, {
    onSuccess: (progress) => ({
      model: modifyFields(model, {
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
              maybeError: () => Option.some(describeError(error)),
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
        maybeError: () => Option.none(),
        maybeMatch: () =>
          Option.some({
            ...progress,
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
    onFailure: (error) => ({ model: modifyFields(model, { maybeError: () => Option.some(describeError(error)) }) }),
  });
};

// AGENT

const ReplyToAgent = Command.define("ReplyToAgent", {
  args: { id: Schema.Number, reply: AgentReply },
  messages: [Message.CompletedReplyToAgent],
  execute: ({ id, reply }) => Port.emit(ports.outbound.agentReplied, { id, reply }).pipe(Effect.as(Message.CompletedReplyToAgent())),
});

const SEED_PATTERN = /^-?\d+$/;

interface AgentOutcome {
  readonly model: Model;
  readonly reply: AgentReply;
}

const refused = (model: Model, reason: string): AgentOutcome => ({ model, reply: AgentReply.cases.Refused.make({ reason }) });

const gameReply = (model: Model, seat: Seat): AgentOutcome => ({
  model,
  reply: Option.match(model.maybeMatch, {
    onNone: () => AgentReply.cases.Refused.make({ reason: NO_MATCH }),
    onSome: (match) => Result.match(agentGame(match, seat), { onSuccess: (game) => AgentReply.cases.Answered.make({ text: JSON.stringify(game) }), onFailure: (reason) => AgentReply.cases.Refused.make({ reason }) }),
  }),
});

/** Runs one tool call over the model, through the same Messages the buttons send. */
export const handleAgentCall = (model: Model, call: AgentCall): AgentOutcome =>
  AgentCall.match<AgentOutcome>(call, {
    GetGame: ({ seat }) => gameReply(model, seat),
    PlayMove: ({ seat, index, turn }) =>
      Option.match(model.maybeMatch, {
        onNone: () => refused(model, NO_MATCH),
        onSome: (match) =>
          Result.match(agentMove(match, seat, index, turn), {
            onFailure: (reason) => refused(model, reason),
            onSuccess: (click) => {
              const moved = update(model, Message.ClickedMove(click)).model;

              return Option.match(moved.maybeError, { onNone: () => gameReply(moved, seat), onSome: (reason) => refused(moved, reason) });
            },
          }),
      }),
    NewMatch: ({ players, items, seed, controllers = defaultAgentControllers(players) }) =>
      seed !== undefined && !SEED_PATTERN.test(seed)
        ? refused(model, `The seed must be an integer, not "${seed}".`)
        : controllers.length === players
          ? newMatchReply(startAgentMatch(model, players, items, seed === undefined ? model.setup.seed : Number(seed), controllers))
          : refused(model, `controllers must list one controller per seat: ${players} for ${players} players, not ${controllers.length}.`),
  });

/** The table as new_match left it: each seat's number and controller, so the agents know which seats to name. */
const newMatchReply = (model: Model): AgentOutcome =>
  Option.match(model.maybeError, {
    onSome: (reason) => refused(model, reason),
    onNone: () =>
      Option.match(model.maybeMatch, {
        onNone: () => refused(model, NO_MATCH),
        onSome: (match) => ({
          model,
          reply: AgentReply.cases.Answered.make({
            text: JSON.stringify({
              seats: match.game.seats.map((seat) => ({ seat, controller: controllerOf(match.controllers, seat) })),
              hint: "Call get_game with an Agent seat's number to see that seat's view and moves.",
            }),
          }),
        }),
      }),
  });

const defaultAgentControllers = (table: SeatCount): ReadonlyArray<Controller> => SEATS_BY_TABLE[table].map((_, position): Controller => (position === 0 ? "Agent" : "DoN"));

/** Seats the table's controllers in seat order. Autoplay is on, so the bots move between the agents' turns. */
const startAgentMatch = (model: Model, table: SeatCount, isItemsEnabled: boolean, seed: number, tableControllers: ReadonlyArray<Controller>): Model => {
  const atTable = (seat: number): Option.Option<Controller> =>
    Arr.findFirstIndex(SEATS_BY_TABLE[table], (tableSeat) => tableSeat === seat).pipe(Option.flatMap((position) => Arr.get(tableControllers, position)));

  const controllers = model.setup.controllers.map((controller, seat) => Option.getOrElse(atTable(seat), () => controller));
  const configured = modifyFields(model, { setup: (setup) => ({ ...setup, table, controllers, isItemsEnabled, seed }) });

  return update(configured, Message.ClickedNewMatch()).model;
};

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

      return { model: outcome.model, commands: [ReplyToAgent({ id, reply: outcome.reply })] };
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
    maybeMatch: Option.none(),
    maybeError: Option.none(),
    isWebMcpAvailable,
  },
});

// SUBSCRIPTION

// The pause after a step, at Normal speed, long enough to see what the step did.
const pauseAfter = (event: GameEvent | undefined): number =>
  event === undefined
    ? 400
    : GameEvent.matchOrElse(
        event,
        {
          Loaded: () => 2600,
          RoundWon: () => 3200,
          Fired: () => 1500,
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

const SPEED_FACTOR: Readonly<Record<Speed, number>> = { Slow: 1.6, Normal: 1, Fast: 0.12 };

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
            pauseMs: Math.round(pauseAfter(match.events.at(-1)) * SPEED_FACTOR[model.speed]),
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
