import { Schema } from "effect";

// The UI's view of the Bend domain (sim/bend-mp/domain.bend). Only
// web/src/bend.ts builds these values from Bend output.

export const Seat = Schema.Literals([0, 1, 2, 3]);

export type Seat = typeof Seat.Type;

export const SeatCount = Schema.Literals([2, 3, 4]);

export type SeatCount = typeof SeatCount.Type;

export const SEATS_BY_TABLE: Readonly<Record<SeatCount, ReadonlyArray<Seat>>> = { 2: [1, 3], 3: [0, 1, 2], 4: [0, 1, 2, 3] };

// In Bend's item.order (domain.bend); test/rules-constants.test.ts checks it.
export const Item = Schema.Literals(["Saw", "Glass", "Jammer", "Cigarettes", "Beer", "Phone", "Inverter", "Adrenaline", "Remote"]);

export type Item = typeof Item.Type;

export const Slot = Schema.Literals([0, 1, 2, 3, 4, 5, 6, 7]);

export type Slot = typeof Slot.Type;

export const Shell = Schema.Literals(["Live", "Blank"]);

export type Shell = typeof Shell.Type;

export const Direction = Schema.Literals(["Clockwise", "CounterClockwise"]);

export type Direction = typeof Direction.Type;

export const DrawLabel = Schema.Literals(["FirstSeat", "StartingHealth", "ItemAmount", "ItemChoice", "SequenceBatch", "ShuffleSwap", "PhoneIndex"]);

export type DrawLabel = typeof DrawLabel.Type;

export const Load = Schema.Struct({ live: Schema.Number, blank: Schema.Number });

export type Load = typeof Load.Type;

export const Move = Schema.TaggedUnion({
  PickUp: {},
  Shoot: { target: Seat },
  UseItem: { slot: Slot, item: Item },
  Grab: {},
  Place: { slot: Slot },
  JamTarget: { target: Seat },
  Steal: { owner: Seat, slot: Slot, item: Item },
});

export type Move = typeof Move.Type;

export const Counter = Schema.TaggedUnion({
  Unjammed: { health: Schema.Number },
  Jammed: {},
});

export type Counter = typeof Counter.Type;

export const Briefcase = Schema.TaggedUnion({
  NotGrabbing: {},
  Grabbing: {},
  Holding: { item: Item },
});

export type Briefcase = typeof Briefcase.Type;

export const SeatView = Schema.Struct({
  seat: Seat,
  counter: Counter,
  slots: Schema.Array(Schema.Option(Item)),
  cash: Schema.Number,
  briefcase: Briefcase,
});

export type SeatView = typeof SeatView.Type;

export const Mode = Schema.Literals(["Idle", "Aiming", "Jamming", "Stealing"]);

export type Mode = typeof Mode.Type;

export const Stage = Schema.TaggedUnion({
  Setup: {},
  Distributing: {},
  Loading: {},
  Playing: { seat: Seat, mode: Mode },
  MatchOver: {},
});

export type Stage = typeof Stage.Type;

export const Board = Schema.Struct({
  round: Schema.Struct({ index: Schema.Number, rounds: Schema.Number, health: Schema.Number }),
  seats: Schema.Array(SeatView),
  gun: Schema.Struct({ shown: Load, remaining: Schema.Number, sawed: Schema.Boolean }),
  direction: Direction,
  stage: Stage,
});

export type Board = typeof Board.Type;

export const Damage = Schema.Literals(["Single", "Double"]);

export type Damage = typeof Damage.Type;

export const GameEvent = Schema.TaggedUnion({
  RoundBegan: { round: Schema.Number, health: Schema.Number, first: Seat },
  GrabbingBegan: { seats: Schema.Array(Seat) },
  Granted: { seat: Seat, item: Item },
  Placed: { seat: Seat, slot: Slot, item: Item },
  GrabbingEnded: { seat: Seat },
  DistributionDone: {},
  Loaded: { load: Load },
  TurnSkipped: { seat: Seat },
  JamLifted: { seat: Seat },
  TurnGiven: { seat: Seat },
  PickedUp: { seat: Seat },
  Fired: { shooter: Seat, target: Seat, shell: Shell, captured: Damage, applied: Schema.Number, health: Schema.Number },
  Died: { seat: Seat },
  Used: { seat: Seat, owner: Seat, slot: Slot, item: Item },
  Healed: { seat: Seat, health: Schema.Number },
  Ejected: { seat: Seat, shell: Shell },
  Inverted: { seat: Seat },
  JamApplied: { by: Seat, target: Seat },
  DirectionFlipped: { direction: Direction },
  RoundWon: { seat: Seat, prize: Schema.Number },
  MatchConcluded: {},
});

export type GameEvent = typeof GameEvent.Type;

export const Secret = Schema.TaggedUnion({
  Glimpse: { shell: Shell },
  Clue: { position: Schema.Number, shell: Shell },
  NoClue: {},
  EmptyBriefcase: {},
});

export type Secret = typeof Secret.Type;

// A secret as one seat heard it; the seat is the hearer, never read from Bend.
export const HeardSecret = Schema.Struct({ seat: Seat, secret: Secret });

export type HeardSecret = typeof HeardSecret.Type;

// A heard secret, and how many events the log held when the step that told it ended.
export const LearnedSecret = Schema.Struct({ ...HeardSecret.fields, at: Schema.Number });

export type LearnedSecret = typeof LearnedSecret.Type;

// The library reports a death only as a Died event, and a new round revives everyone.
export const seatsOut = (events: ReadonlyArray<GameEvent>): ReadonlySet<Seat> =>
  events.reduce<ReadonlySet<Seat>>(
    (out, event) =>
      GameEvent.matchOrElse(event, { RoundBegan: () => new Set<Seat>(), Died: ({ seat }) => new Set(out).add(seat) }, () => out),
    new Set<Seat>(),
  );
