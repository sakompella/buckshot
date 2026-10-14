import { Schema } from "effect";
import { defineMessageUnion } from "foldkit/message";

import { AgentCall } from "./agent.ts";
import { Game } from "./bend.ts";
import { GameEvent, LearnedSecret, Seat, SeatCount } from "./domain.ts";
import { AiSeat, Controller } from "./driver.ts";

// MODEL

export const Viewer = Schema.Union([Schema.Literal("Spectator"), Seat]);

export type Viewer = typeof Viewer.Type;

/** How fast autoplay moves the bots; the pause after each step also leaves time for its animation. */
export const Speed = Schema.Literals(["Slow", "Normal", "Fast"]);

export type Speed = typeof Speed.Type;

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
  learned: Schema.Array(LearnedSecret),
  controllers: Schema.Array(Controller),
  ais: Schema.Array(Schema.Option(AiSeat)),
  seed: Schema.Number,
  viewer: Viewer,
  isAutoplay: Schema.Boolean,
});

export type Session = typeof Session.Type;

export const Model = Schema.Struct({
  setup: Setup,
  speed: Speed,
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

export const SEATS_BY_TABLE: Readonly<Record<SeatCount, ReadonlyArray<Seat>>> = { 2: [1, 3], 3: [0, 1, 2], 4: [0, 1, 2, 3] };
