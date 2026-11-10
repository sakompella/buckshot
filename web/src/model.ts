import { Schema } from "effect";
import { defineMessageUnion } from "foldkit/message";

import { AgentCall } from "./agent/tools.ts";
import { Game } from "./bend.ts";
import { GameEvent, LearnedSecret, Seat, SeatCount } from "./domain.ts";
import { AiSeat, Controller } from "./driver.ts";

// MODEL

export const Viewer = Schema.Union([Schema.Literal("Spectator"), Seat]);

export type Viewer = typeof Viewer.Type;

/** How fast autoplay moves the bots; the pause after each step also leaves time for its animation. */
export const Speed = Schema.Literals(["Slow", "Normal", "Fast"]);

export type Speed = typeof Speed.Type;

/** How long autoplay's pauses and the table's held moments last at each speed, against Normal. */
export const SPEED_FACTOR: Readonly<Record<Speed, number>> = { Slow: 1.6, Normal: 1, Fast: 0.12 };

/** The round-over beat at Normal speed: autoplay's pause after a won round, and the length of its animations (`--round-beat`). */
export const ROUND_BEAT_MS = 4400;

export const Setup = Schema.Struct({
  table: SeatCount,
  controllers: Schema.Array(Controller),
  isItemsEnabled: Schema.Boolean,
  seed: Schema.Number,
});

export type Setup = typeof Setup.Type;

export const Session = Schema.Struct({
  game: Schema.instanceOf(Game),
  rng: Schema.Number,
  events: Schema.Array(GameEvent),
  /** Where the events of the latest step begin: the table animates them, and autoplay waits for them. */
  stepStart: Schema.Number,
  learned: Schema.Array(LearnedSecret),
  /** Where the secrets learned in the latest step begin, so each shows once. */
  learnedStart: Schema.Number,
  controllers: Schema.Array(Controller),
  ais: Schema.Array(Schema.Option(AiSeat)),
  seed: Schema.Number,
  viewer: Viewer,
  isAutoplay: Schema.Boolean,
});

export type Session = typeof Session.Type;

export interface StepEvent {
  readonly index: number;
  readonly event: GameEvent;
}

/** The secrets the latest step taught, with their places in the list. */
export const latestLearned = (match: Session): ReadonlyArray<{ readonly index: number; readonly learned: LearnedSecret }> =>
  match.learned.slice(match.learnedStart).map((learned, offset) => ({ index: match.learnedStart + offset, learned }));

/** The latest step's events with their places in the log. */
export const latestStep = (match: Session): ReadonlyArray<StepEvent> =>
  match.events.slice(match.stepStart).map((event, offset) => ({ index: match.stepStart + offset, event }));

export const Model = Schema.Struct({
  setup: Setup,
  speed: Speed,
  matchCount: Schema.Number,
  /** Advances with every accepted move and every new match, so an agent's turn never repeats on this page. */
  turn: Schema.Number,
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
  ClickedLeaveMatch: {},
  SelectedViewer: { viewer: Viewer },
  SelectedSpeed: { speed: Speed },
  ClickedMove: { match: Schema.Number, generation: Schema.Number, seat: Seat, index: Schema.Number },
  ClickedStep: {},
  ToggledAutoplay: {},
  TickedAutoplay: {},
  AgentCalled: { id: Schema.Number, call: AgentCall },
  CompletedReplyToAgent: {},
});

export type Message = typeof Message.Type;

