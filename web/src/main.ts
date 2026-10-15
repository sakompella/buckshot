import { Array as Arr, Duration, Effect, Option, Predicate, Result, Schema, Stream } from "effect";
import { Command, Port, Runtime, Subscription, type Update } from "foldkit";
import type { Document, Html, HtmlBuilder } from "foldkit/html";
import { defineMessageUnion } from "foldkit/message";
import { modifyFields } from "foldkit/struct";

import { AgentCall, AgentReply, type MatchSession, runTool } from "./agent/tools.ts";
import { type AnswerError, Game } from "./bend.ts";
import { type Board, Briefcase, Counter, GameEvent, LearnedSecret, Seat, SEATS_BY_TABLE, SeatCount, type SeatView, seatsOut, Stage } from "./domain.ts";
import { aiPrompt, aiStep, AiSeat, begin, Controller, controllerOf, isAi, play, type Progress, promptsOf } from "./driver.ts";
import { seedRng } from "./rng.ts";
import { describeError, eventText, itemName, moveText, seatName, secretText } from "./text.ts";
import { titles } from "./titles.ts";
import { ports } from "./webmcp.ts";

const AUTOPLAY_INTERVAL_MS = 350;

const DEFAULT_SEED = 20261012;

// MODEL

const Viewer = Schema.Union([Schema.Literal("Spectator"), Seat]);

type Viewer = typeof Viewer.Type;

const Setup = Schema.Struct({
  table: SeatCount,
  controllers: Schema.Array(Controller),
  isItemsEnabled: Schema.Boolean,
  seed: Schema.Number,
});

type Setup = typeof Setup.Type;

const Session = Schema.Struct({
  game: Schema.instanceOf(Game),
  rng: Schema.Number,
  events: Schema.Array(GameEvent),
  learned: Schema.Array(LearnedSecret),
  controllers: Schema.Array(Controller),
  ais: Schema.Array(Schema.Option(AiSeat)),
  seed: Schema.Number,
  viewer: Viewer,
  isAutoplay: Schema.Boolean,
});

type Session = typeof Session.Type;

export const Model = Schema.Struct({
  setup: Setup,
  matchCount: Schema.Number,
  maybeMatch: Schema.Option(Session),
  maybeError: Schema.Option(Schema.String),
  isWebMcpAvailable: Schema.Boolean,
});

export type Model = typeof Model.Type;

// MESSAGE

export const Message = defineMessageUnion({
  SelectedTable: { table: SeatCount },
  ToggledController: { seat: Seat },
  ToggledItems: {},
  UpdatedSeed: { value: Schema.String },
  ClickedNewMatch: {},
  SelectedViewer: { viewer: Viewer },
  ClickedMove: { match: Schema.Number, generation: Schema.Number, seat: Seat, index: Schema.Number },
  ClickedStep: {},
  ToggledAutoplay: {},
  TickedAutoplay: {},
  AgentCalled: { id: Schema.Number, call: AgentCall },
  CompletedReplyToAgent: {},
});

export type Message = typeof Message.Type;

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
            isAutoplay: false,
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

/** Seats the table's controllers in seat order. Autoplay starts so the bots move between the agents' turns. */
const startAgentMatch = (model: Model, table: SeatCount, isItemsEnabled: boolean, seed: number, tableControllers: ReadonlyArray<Controller>): Model => {
  const atTable = (seat: number): Option.Option<Controller> =>
    Arr.findFirstIndex(SEATS_BY_TABLE[table], (tableSeat) => tableSeat === seat).pipe(Option.flatMap((position) => Arr.get(tableControllers, position)));

  const controllers = model.setup.controllers.map((controller, seat) => Option.getOrElse(atTable(seat), () => controller));
  const configured = modifyFields(model, { setup: (setup) => ({ ...setup, table, controllers, isItemsEnabled, seed }) });

  return update(update(configured, Message.ClickedNewMatch()).model, Message.ToggledAutoplay()).model;
};

const applied = (model: Model) => ({ state: model, maybeError: model.maybeError });

/** The agent tools' view of the page: moves go through the same ClickedMove the buttons send. */
const pageSession: MatchSession<Model> = {
  current: (model) => model.maybeMatch,
  start: (model, { table, isItemsEnabled, maybeSeed, controllers }) => applied(startAgentMatch(model, table, isItemsEnabled, Option.getOrElse(maybeSeed, () => model.setup.seed), controllers)),
  move: (model, move) => applied(update(model, Message.ClickedMove(move)).model),
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
    setup: { table: 2, controllers: ["DoN", "Human", "DoN", "DoN"], isItemsEnabled: false, seed: DEFAULT_SEED },
    matchCount: 0,
    maybeMatch: Option.none(),
    maybeError: Option.none(),
    isWebMcpAvailable,
  },
});

// SUBSCRIPTION

export const subscriptions = Subscription.make<Model, Message>()((entry) => ({
  agent: Port.subscriptionEntry(ports.inbound.agentCalled, ({ id, call }) => Message.AgentCalled({ id, call })),
  autoplay: entry(
    { isAutoplay: Schema.Boolean },
    {
      modelToDependencies: (model) => ({ isAutoplay: Option.exists(model.maybeMatch, (match) => match.isAutoplay) }),
      dependenciesToStream: ({ isAutoplay }) =>
        Stream.when(
          Stream.tick(Duration.millis(AUTOPLAY_INTERVAL_MS)).pipe(
            Stream.drop(1),
            Stream.map(() => Message.TickedAutoplay()),
          ),
          Effect.sync(() => isAutoplay),
        ),
    },
  ),
}));

// VIEW

type H = HtmlBuilder<Message>;

const segmented = <A>(h: H, label: string, options: ReadonlyArray<readonly [A, string]>, selected: A, toMessage: (value: A) => Message): Html =>
  h.div(
    [h.Class("field")],
    [
      h.span([h.Class("field-label")], [label]),
      h.div(
        [h.Class("segmented"), h.Role("group"), h.AriaLabel(label)],
        options.map(([value, text]) => h.button([h.Type("button"), h.AriaPressed(value === selected ? "true" : "false"), h.OnClick(toMessage(value))], [text])),
      ),
    ],
  );

const setupView = (h: H, model: Model): Html => {
  const { table, controllers, isItemsEnabled, seed } = model.setup;

  return h.section(
    [h.Class("setup"), h.AriaLabel("Match setup")],
    [
      segmented(h, "Players", [[2, "2"], [3, "3"], [4, "4"]] as const, table, (value) => Message.SelectedTable({ table: value })),
      h.div(
        [h.Class("field")],
        [
          h.span([h.Class("field-label")], ["Controllers"]),
          h.div(
            [h.Class("controllers")],
            SEATS_BY_TABLE[table].map((seat) =>
              h.button([h.Type("button"), h.Class("controller"), h.OnClick(Message.ToggledController({ seat }))], [`${seatName(seat)}: ${controllerOf(controllers, seat)}`]),
            ),
          ),
          model.isWebMcpAvailable || !SEATS_BY_TABLE[table].some((seat) => controllerOf(controllers, seat) === "Agent")
            ? h.empty
            : h.p([h.Class("muted")], ["WebMCP is not available in this browser, so no agent can play the Agent seats."]),
        ],
      ),
      h.label(
        [h.Class("field check")],
        [h.input([h.Type("checkbox"), h.Checked(isItemsEnabled), h.OnChange(() => Message.ToggledItems())]), "Items"],
      ),
      h.label([h.Class("field")], [h.span([h.Class("field-label")], ["Seed"]), h.input([h.Class("seed"), h.Type("number"), h.Value(String(seed)), h.OnInput((value) => Message.UpdatedSeed({ value }))])]),
      h.button([h.Type("button"), h.Class("primary"), h.OnClick(Message.ClickedNewMatch())], [Option.isSome(model.maybeMatch) ? "Restart match" : "Start match"]),
    ],
  );
};

const actingSeat = (board: Board): Option.Option<Seat> =>
  Stage.matchOrElse(board.stage, { Playing: ({ seat }) => Option.some(seat) }, () => Option.none());

const seatPanel = (h: H, match: Session, view: SeatView): Html => {
  const isActing = Option.contains(actingSeat(match.game.board), view.seat);
  const isViewer = match.viewer === view.seat;
  const isOut = seatsOut(match.events).has(view.seat);
  const isJammed = Counter.guards.Jammed(view.counter);

  return h.article(
    [h.Class(`seat${isActing ? " acting" : ""}${isViewer ? " viewer" : ""}${isOut ? " out" : ""}`), h.AriaLabel(seatName(view.seat))],
    [
      h.header(
        [h.Class("seat-head")],
        [
          h.h2([], [seatName(view.seat)]),
          h.span([h.Class("controller-tag")], [controllerOf(match.controllers, view.seat)]),
        ],
      ),
      h.div(
        [h.Class("seat-stats")],
        [
          h.div([h.Class("stat")], [h.span([h.Class("stat-label")], ["Health"]), h.strong([h.Class(isJammed ? "hidden-stat" : "")], [Counter.match(view.counter, { Unjammed: ({ health }) => `${health}`, Jammed: () => "—" })])]),
          h.div([h.Class("stat")], [h.span([h.Class("stat-label")], ["Cash"]), h.strong([], [`$${view.cash.toLocaleString("en-US")}`])]),
        ],
      ),
      h.ol(
        [h.Class("slots"), h.AriaLabel("Item slots")],
        view.slots.map((slot) =>
          Option.match(slot, {
            onNone: () => h.li([h.Class("slot")], []),
            onSome: (item) => h.li([h.Class("slot filled"), h.Title(itemName(item))], [itemName(item)]),
          }),
        ),
      ),
      isOut ? h.p([h.Class("status")], ["Out"]) : h.empty,
      isJammed ? h.p([h.Class("status")], ["Jammed"]) : h.empty,
      Briefcase.match(view.briefcase, {
        NotGrabbing: () => h.empty,
        Grabbing: () => h.p([h.Class("briefcase")], ["Grabbing from the briefcase"]),
        Holding: ({ item }) => h.p([h.Class("briefcase")], [`Holding ${itemName(item)}`]),
      }),
      isActing ? h.p([h.Class("turn")], ["Has the turn"]) : h.empty,
    ],
  );
};

const gunView = (h: H, board: Board): Html => {
  const { shown, remaining, sawed } = board.gun;

  return h.section(
    [h.Class("gun"), h.AriaLabel("Shotgun")],
    [
      h.div(
        [h.Class("shells"), h.AriaLabel(`Last load shown: ${shown.live} live, ${shown.blank} blank`)],
        [...Array.from({ length: shown.live }, () => h.span([h.Class("shell live")], [])), ...Array.from({ length: shown.blank }, () => h.span([h.Class("shell blank")], []))],
      ),
      h.p([], [`Last load shown: ${shown.live} live, ${shown.blank} blank. ${remaining} shell${remaining === 1 ? "" : "s"} left in the gun.${sawed ? " Sawed off: the next shot does double damage." : ""}`]),
      h.p(
        [h.Class("muted")],
        [`Round ${board.round.index + 1} of ${board.round.rounds}. Starting health ${board.round.health}. Turn order ${board.direction === "Clockwise" ? "clockwise" : "counterclockwise"}.`],
      ),
    ],
  );
};

const viewerBar = (h: H, match: Session): Html =>
  segmented<Viewer>(
    h,
    "View as",
    [["Spectator", "Spectator"], ...match.game.seats.map((seat): readonly [Viewer, string] => [seat, seatName(seat)])],
    match.viewer,
    (viewer) => Message.SelectedViewer({ viewer }),
  );

const movesView = (h: H, match: Session): Html => {
  const prompts = promptsOf(match.game);
  const humanPrompts = prompts.filter((prompt) => controllerOf(match.controllers, prompt.seat) === "Human");
  const viewerPrompt = Arr.findFirst(humanPrompts, (prompt) => prompt.seat === match.viewer);
  const waiting = humanPrompts.filter((prompt) => prompt.seat !== match.viewer).map((prompt) => prompt.seat);
  const agentWaiting = prompts.filter((prompt) => controllerOf(match.controllers, prompt.seat) === "Agent").map((prompt) => prompt.seat);
  const hasBotMove = Option.isSome(aiPrompt(match.game, match.controllers));

  return h.section(
    [h.Class("moves"), h.AriaLabel("Moves")],
    [
      h.h2([], [Option.match(viewerPrompt, { onNone: () => "Moves", onSome: ({ seat }) => `Your moves as ${seatName(seat)}` })]),
      Option.match(viewerPrompt, {
        onNone: () => h.p([h.Class("muted")], [match.game.pending.kind === "Finished" ? "The match is over." : "No move for the seat you are viewing."]),
        onSome: (prompt) =>
          h.div(
            [h.Class("move-list")],
            prompt.menu.map((move, index) =>
              h.button(
                [h.Type("button"), h.OnClick(Message.ClickedMove({ match: prompt.ticket.match, generation: prompt.ticket.generation, seat: prompt.seat, index }))],
                [moveText(prompt.seat, move)],
              ),
            ),
          ),
      }),
      ...waiting.map((seat) =>
        h.p([h.Class("waiting")], [`${seatName(seat)} (human) can move. `, h.button([h.Type("button"), h.Class("link"), h.OnClick(Message.SelectedViewer({ viewer: seat }))], [`View as ${seatName(seat)}`])]),
      ),
      ...agentWaiting.map((seat) => h.p([h.Class("waiting")], [`Waiting for the agent (${seatName(seat)}).`])),
      h.div(
        [h.Class("bot-controls")],
        [
          h.button([h.Type("button"), h.Disabled(!hasBotMove), h.OnClick(Message.ClickedStep())], ["Step AI"]),
          h.button([h.Type("button"), h.AriaPressed(match.isAutoplay ? "true" : "false"), h.OnClick(Message.ToggledAutoplay())], [match.isAutoplay ? "Pause autoplay" : "Autoplay AIs"]),
        ],
      ),
    ],
  );
};

const notesView = (h: H, match: Session): Html => {
  const mine = match.learned.filter(({ seat }) => seat === match.viewer);

  return h.section(
    [h.Class("notes"), h.AriaLabel("Private notes")],
    [
      h.h2([], [match.viewer === "Spectator" ? "Private notes" : `Private notes for ${seatName(match.viewer)}`]),
      match.viewer === "Spectator"
        ? h.p([h.Class("muted")], ["Spectators see no private notes."])
        : mine.length === 0
          ? h.p([h.Class("muted")], ["Nothing learned yet."])
          : h.ul([], mine.map(({ secret }) => h.li([], [secretText(secret)]))),
    ],
  );
};

// Hits, deaths and round boundaries stand out in the log.
const isHeadline = (event: GameEvent): boolean =>
  GameEvent.matchOrElse(event, { Fired: ({ applied }) => applied > 0, Died: () => true, RoundWon: () => true, MatchConcluded: () => true }, () => false);

const logView = (h: H, match: Session): Html =>
  h.aside(
    [h.Class("log"), h.AriaLabel("Event log")],
    [
      h.h2([], ["Event log"]),
      h.ol(
        [h.Class("log-list")],
        match.events
          .map((event, index) => h.keyed("li")(index, [h.Class(isHeadline(event) ? "event headline" : "event")], [eventText(event)]))
          .toReversed(),
      ),
    ],
  );

const resultsView = (h: H, match: Session): Html => {
  const seats = match.game.seats;
  const standings = match.game.board.seats.toSorted((left, right) => right.cash - left.cash);

  return h.section(
    [h.Class("results"), h.AriaLabel("Results")],
    [
      h.h2([], ["Results"]),
      h.ol([h.Class("standings")], standings.map((view) => h.li([], [`${seatName(view.seat)}: $${view.cash.toLocaleString("en-US")}`]))),
      h.dl(
        [h.Class("titles")],
        titles(match.events, seats).flatMap((title) => [
          h.dt([], [title.name]),
          h.dd([], [title.seats.length === 0 ? `Nobody (${title.description})` : `${title.seats.map(seatName).join(", ")} with ${title.score} ${title.description}`]),
        ]),
      ),
    ],
  );
};

const matchView = (h: H, match: Session): Html => {
  const pending = match.game.pending;

  return h.div(
    [h.Class("match")],
    [
      h.div(
        [h.Class("table")],
        [
          viewerBar(h, match),
          pending.kind === "Stuck" ? h.p([h.Class("error")], ["The machine is stuck: no seat has a legal move."]) : h.empty,
          pending.kind === "Finished" ? resultsView(h, match) : h.empty,
          gunView(h, match.game.board),
          h.div([h.Class("seats")], match.game.board.seats.map((view) => seatPanel(h, match, view))),
          h.div([h.Class("lower")], [movesView(h, match), notesView(h, match)]),
        ],
      ),
      logView(h, match),
    ],
  );
};

export const view = (model: Model, h: H): Document => ({
  title: "Buckshot table",
  body: h.main(
    [h.Class("app")],
    [
      h.header([h.Class("topbar")], [h.h1([], ["Buckshot table"]), setupView(h, model)]),
      Option.match(model.maybeError, { onNone: () => h.empty, onSome: (error) => h.p([h.Class("error"), h.Role("alert")], [error]) }),
      Option.match(model.maybeMatch, {
        onNone: () => h.p([h.Class("empty")], ["Pick the players and press Start match."]),
        onSome: (match) => matchView(h, match),
      }),
    ],
  ),
});
