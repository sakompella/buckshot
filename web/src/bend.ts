import { Array as Arr, Data, Match, Option, Result, Schema } from "effect";

import rules, { type BendNode } from "../generated/rules.mjs";
import { Board, Briefcase, Counter, GameEvent, Move, Secret, Stage, type Damage, type Direction, type DrawLabel, type Item, type HeardSecret, type Mode, type Seat, type SeatCount, type SeatView, type Shell, type Slot } from "./domain.ts";

// The one boundary between the app and the Bend build. It is the only file
// that writes Bend constructor tags, and it decodes every value Bend returns
// before the app sees it. Raw schemas mirror the Bend shapes exactly; small
// functions then convert them to the app types in domain.ts.

export class BendContractError extends Data.TaggedError("BendContractError")<{ readonly call: string; readonly detail: string }> {}

export class StaleAnswer extends Data.TaggedError("StaleAnswer")<{ readonly expected: number; readonly received: number }> {}

export class NoPrompt extends Data.TaggedError("NoPrompt")<{ readonly seat: Seat }> {}

export type AnswerError = BendContractError | StaleAnswer | NoPrompt;

// Bend lists and options
// ======================

interface RawCons<A> {
  readonly $: "Con";
  readonly head: A;
  readonly tail: RawList<A>;
}

interface RawNil {
  readonly $: "Nil";
}

type RawList<A> = RawCons<A> | RawNil;

const rawList = <A>(item: Schema.Codec<A>): Schema.Codec<RawList<A>> => {
  const list: Schema.Codec<RawList<A>> = Schema.Union([
    Schema.Struct({ $: Schema.Literal("Con"), head: item, tail: Schema.suspend((): Schema.Codec<RawList<A>> => list) }),
    Schema.Struct({ $: Schema.Literal("Nil") }),
  ]);

  return list;
};

const listToArray = <A>(list: RawList<A>): ReadonlyArray<A> => {
  const items: Array<A> = [];
  let rest = list;

  while (rest.$ === "Con") {
    items.push(rest.head);
    rest = rest.tail;
  }

  return items;
};

interface RawSome<A> {
  readonly $: "Some";
  readonly value: A;
}

interface RawNone {
  readonly $: "None";
}

type RawMaybe<A> = RawSome<A> | RawNone;

const rawMaybe = <A>(item: Schema.Codec<A>): Schema.Codec<RawMaybe<A>> =>
  Schema.Union([Schema.Struct({ $: Schema.Literal("Some"), value: item }), Schema.Struct({ $: Schema.Literal("None") })]);

const arrayToList = <A>(items: ReadonlyArray<A>): RawList<A> => items.reduceRight<RawList<A>>((tail, head) => ({ $: "Con", head, tail }), { $: "Nil" });

const maybeToOption = <A>(maybe: RawMaybe<A>): Option.Option<A> => (maybe.$ === "Some" ? Option.some(maybe.value) : Option.none());

// A Nat crosses to JS as a plain number: Bend checks it lies in 0..2^53.
const Nat = Schema.Number;

// Enumerations
// ============

const SEAT_BY_TAG = { Seat0: 0, Seat1: 1, Seat2: 2, Seat3: 3 } as const;

const SEAT_TAGS = ["Seat0", "Seat1", "Seat2", "Seat3"] as const;

const RawSeat = Schema.Struct({ $: Schema.Literals(SEAT_TAGS) });

type RawSeat = typeof RawSeat.Type;

const seatOf = (raw: RawSeat): Seat => SEAT_BY_TAG[raw.$];

const seatNode = (seat: Seat): RawSeat => ({ $: SEAT_TAGS[seat] });

const ITEM_BY_TAG = {
  "Saw": "Saw",
  "Glass": "Glass",
  "Jammer": "Jammer",
  "Cigarettes": "Cigarettes",
  "Beer": "Beer",
  "Phone": "Phone",
  "Inverter": "Inverter",
  "Adrenaline": "Adrenaline",
  "Remote": "Remote",
} as const satisfies Readonly<Record<string, Item>>;

const RawItem = Schema.Struct({ $: Schema.Literals(["Saw", "Glass", "Jammer", "Cigarettes", "Beer", "Phone", "Inverter", "Adrenaline", "Remote"]) });

type RawItem = typeof RawItem.Type;

const itemOf = (raw: RawItem): Item => ITEM_BY_TAG[raw.$];

const SLOT_BY_TAG = { "Slot0": 0, "Slot1": 1, "Slot2": 2, "Slot3": 3, "Slot4": 4, "Slot5": 5, "Slot6": 6, "Slot7": 7 } as const;

const RawSlot = Schema.Struct({ $: Schema.Literals(["Slot0", "Slot1", "Slot2", "Slot3", "Slot4", "Slot5", "Slot6", "Slot7"]) });

type RawSlot = typeof RawSlot.Type;

const slotOf = (raw: RawSlot): Slot => SLOT_BY_TAG[raw.$];

const SHELL_BY_TAG = { "Live": "Live", "Blank": "Blank" } as const satisfies Readonly<Record<string, Shell>>;

const RawShell = Schema.Struct({ $: Schema.Literals(["Live", "Blank"]) });

type RawShell = typeof RawShell.Type;

const shellOf = (raw: RawShell): Shell => SHELL_BY_TAG[raw.$];

const DAMAGE_BY_TAG = { "Single": "Single", "Double": "Double" } as const satisfies Readonly<Record<string, Damage>>;

const RawDamage = Schema.Struct({ $: Schema.Literals(["Single", "Double"]) });

const DIRECTION_BY_TAG = { "Clockwise": "Clockwise", "CounterClockwise": "CounterClockwise" } as const satisfies Readonly<Record<string, Direction>>;

const RawDirection = Schema.Struct({ $: Schema.Literals(["Clockwise", "CounterClockwise"]) });

const MODE_BY_TAG = { "Idle": "Idle", "Aiming": "Aiming", "Jamming": "Jamming", "Stealing": "Stealing" } as const satisfies Readonly<Record<string, Mode>>;

const RawMode = Schema.Struct({ $: Schema.Literals(["Idle", "Aiming", "Jamming", "Stealing"]) });

const LABEL_BY_TAG = {
  "FirstSeat": "FirstSeat",
  "StartingHealth": "StartingHealth",
  "ItemAmount": "ItemAmount",
  "ItemChoice": "ItemChoice",
  "SequenceBatch": "SequenceBatch",
  "ShuffleSwap": "ShuffleSwap",
  "PhoneIndex": "PhoneIndex",
} as const satisfies Readonly<Record<string, DrawLabel>>;

const RawLabel = Schema.Struct({ $: Schema.Literals(["FirstSeat", "StartingHealth", "ItemAmount", "ItemChoice", "SequenceBatch", "ShuffleSwap", "PhoneIndex"]) });

const TABLE_TAGS = { 2: "TwoSeats", 3: "ThreeSeats", 4: "FourSeats" } as const satisfies Readonly<Record<SeatCount, string>>;

// Rings
// =====

interface RawDuo<A> {
  readonly $: "Duo";
  readonly s1: A;
  readonly s3: A;
}

interface RawTrio<A> {
  readonly $: "Trio";
  readonly s0: A;
  readonly s1: A;
  readonly s2: A;
}

interface RawQuad<A> {
  readonly $: "Quad";
  readonly s0: A;
  readonly s1: A;
  readonly s2: A;
  readonly s3: A;
}

type RawRing<A> = RawDuo<A> | RawTrio<A> | RawQuad<A>;

const rawRing = <A>(item: Schema.Codec<A>): Schema.Codec<RawRing<A>> =>
  Schema.Union([
    Schema.Struct({ $: Schema.Literal("Duo"), s1: item, s3: item }),
    Schema.Struct({ $: Schema.Literal("Trio"), s0: item, s1: item, s2: item }),
    Schema.Struct({ $: Schema.Literal("Quad"), s0: item, s1: item, s2: item, s3: item }),
  ]);

const ringEntries = <A>(ring: RawRing<A>): ReadonlyArray<readonly [Seat, A]> =>
  Match.value(ring).pipe(
    Match.discriminatorsExhaustive("$")({
      "Duo": ({ s1, s3 }): ReadonlyArray<readonly [Seat, A]> => [
        [1, s1],
        [3, s3],
      ],
      "Trio": ({ s0, s1, s2 }): ReadonlyArray<readonly [Seat, A]> => [
        [0, s0],
        [1, s1],
        [2, s2],
      ],
      "Quad": ({ s0, s1, s2, s3 }): ReadonlyArray<readonly [Seat, A]> => [
        [0, s0],
        [1, s1],
        [2, s2],
        [3, s3],
      ],
    }),
  );

// Moves
// =====

const RawMove = Schema.Union([
  Schema.Struct({ $: Schema.Literal("PickUp") }),
  Schema.Struct({ $: Schema.Literal("Shoot"), target: RawSeat }),
  Schema.Struct({ $: Schema.Literal("UseItem"), slot: RawSlot, item: RawItem }),
  Schema.Struct({ $: Schema.Literal("Grab") }),
  Schema.Struct({ $: Schema.Literal("Place"), slot: RawSlot }),
  Schema.Struct({ $: Schema.Literal("JamTarget"), target: RawSeat }),
  Schema.Struct({ $: Schema.Literal("Steal"), owner: RawSeat, slot: RawSlot, item: RawItem }),
]);

type RawMove = typeof RawMove.Type;

const moveOf = (raw: RawMove): Move =>
  Match.value(raw).pipe(
    Match.discriminatorsExhaustive("$")({
      "PickUp": () => Move.cases.PickUp.make({}),
      "Shoot": ({ target }) => Move.cases.Shoot.make({ target: seatOf(target) }),
      "UseItem": ({ slot, item }) => Move.cases.UseItem.make({ slot: slotOf(slot), item: itemOf(item) }),
      "Grab": () => Move.cases.Grab.make({}),
      "Place": ({ slot }) => Move.cases.Place.make({ slot: slotOf(slot) }),
      "JamTarget": ({ target }) => Move.cases.JamTarget.make({ target: seatOf(target) }),
      "Steal": ({ owner, slot, item }) => Move.cases.Steal.make({ owner: seatOf(owner), slot: slotOf(slot), item: itemOf(item) }),
    }),
  );

// Board
// =====

const RawLoad = Schema.Struct({ $: Schema.Literal("Load"), live: Nat, blank: Nat });

type RawLoad = typeof RawLoad.Type;

const loadOf = (raw: RawLoad) => ({ live: raw.live, blank: raw.blank });

const RawCounter = Schema.Union([Schema.Struct({ $: Schema.Literal("Unjammed"), health: Nat }), Schema.Struct({ $: Schema.Literal("Jammed") })]);

const RawBriefcase = Schema.Union([
  Schema.Struct({ $: Schema.Literal("NotGrabbing") }),
  Schema.Struct({ $: Schema.Literal("Grabbing") }),
  Schema.Struct({ $: Schema.Literal("Holding"), item: RawItem }),
]);

const RawSlotItem = rawMaybe(RawItem);

const RawSlots = Schema.Struct({
  $: Schema.Literal("Slots"),
  s0: RawSlotItem,
  s1: RawSlotItem,
  s2: RawSlotItem,
  s3: RawSlotItem,
  s4: RawSlotItem,
  s5: RawSlotItem,
  s6: RawSlotItem,
  s7: RawSlotItem,
});

type RawSlots = typeof RawSlots.Type;

const slotsOf = (raw: RawSlots): ReadonlyArray<Option.Option<Item>> =>
  [raw.s0, raw.s1, raw.s2, raw.s3, raw.s4, raw.s5, raw.s6, raw.s7].map((slot) => Option.map(maybeToOption(slot), itemOf));

const RawSeatView = Schema.Struct({ $: Schema.Literal("SeatView"), counter: RawCounter, slots: RawSlots, cash: Schema.Number, briefcase: RawBriefcase });

type RawSeatView = typeof RawSeatView.Type;

const seatViewOf = ([seat, raw]: readonly [Seat, RawSeatView]): SeatView => ({
  seat,
  counter: Match.value(raw.counter).pipe(
    Match.discriminatorsExhaustive("$")({
      "Unjammed": ({ health }) => Counter.cases.Unjammed.make({ health }),
      "Jammed": () => Counter.cases.Jammed.make({}),
    }),
  ),
  slots: slotsOf(raw.slots),
  cash: raw.cash,
  briefcase: Match.value(raw.briefcase).pipe(
    Match.discriminatorsExhaustive("$")({
      "NotGrabbing": () => Briefcase.cases.NotGrabbing.make({}),
      "Grabbing": () => Briefcase.cases.Grabbing.make({}),
      "Holding": ({ item }) => Briefcase.cases.Holding.make({ item: itemOf(item) }),
    }),
  ),
});

const RawStage = Schema.Union([
  Schema.Struct({ $: Schema.Literal("Setup") }),
  Schema.Struct({ $: Schema.Literal("Distributing") }),
  Schema.Struct({ $: Schema.Literal("Loading") }),
  Schema.Struct({ $: Schema.Literal("Playing"), seat: RawSeat, mode: RawMode }),
  Schema.Struct({ $: Schema.Literal("MatchOver") }),
]);

type RawStage = typeof RawStage.Type;

const stageOf = (raw: RawStage): Stage =>
  Match.value(raw).pipe(
    Match.discriminatorsExhaustive("$")({
      "Setup": () => Stage.cases.Setup.make({}),
      "Distributing": () => Stage.cases.Distributing.make({}),
      "Loading": () => Stage.cases.Loading.make({}),
      "Playing": ({ seat, mode }) => Stage.cases.Playing.make({ seat: seatOf(seat), mode: MODE_BY_TAG[mode.$] }),
      "MatchOver": () => Stage.cases.MatchOver.make({}),
    }),
  );

const RawBoard = Schema.Struct({
  $: Schema.Literal("Board"),
  round: Schema.Struct({ $: Schema.Literal("RoundView"), index: Nat, rounds: Nat, health: Nat }),
  seats: rawRing(RawSeatView),
  gun: Schema.Struct({ $: Schema.Literal("GunView"), shown: RawLoad, remaining: Nat, sawed: Schema.Boolean }),
  direction: RawDirection,
  stage: RawStage,
});

type RawBoard = typeof RawBoard.Type;

const boardOf = (raw: RawBoard): Board =>
  Board.make({
    round: { index: raw.round.index, rounds: raw.round.rounds, health: raw.round.health },
    seats: ringEntries(raw.seats).map(seatViewOf),
    gun: { shown: loadOf(raw.gun.shown), remaining: raw.gun.remaining, sawed: raw.gun.sawed },
    direction: DIRECTION_BY_TAG[raw.direction.$],
    stage: stageOf(raw.stage),
  });

// Requests and prompts
// ====================

const RawRequest = Schema.Union([
  Schema.Struct({ $: Schema.Literal("Draw"), label: RawLabel, range: Schema.Struct({ $: Schema.Literal("Range"), lo: Nat, extra: Nat }) }),
  Schema.Struct({ $: Schema.Literal("Choose") }),
  Schema.Struct({ $: Schema.Literal("Finished") }),
  Schema.Struct({ $: Schema.Literal("Stuck") }),
]);

const RawPoint = Schema.Struct({ $: Schema.Literal("Point"), request: RawRequest, board: RawBoard });

const RawPrompt = Schema.Struct({
  $: Schema.Literal("Prompt"),
  seat: RawSeat,
  first: Nat,
  menu: Schema.Struct({ $: Schema.Literal("NonEmpty"), head: RawMove, tail: rawList(RawMove) }),
});

type RawPrompt = typeof RawPrompt.Type;

/** One seat's legal moves at one request point. Answer it with answerPrompt. */
export class Prompt {
  constructor(
    readonly seat: Seat,
    readonly menu: readonly [Move, ...Array<Move>],
    readonly ticket: Ticket,
    readonly raw: RawPrompt,
  ) {}
}

/** Identifies one request point of one match; answers carry it back. */
export interface Ticket {
  readonly match: number;
  readonly generation: number;
}

export type Pending =
  | { readonly kind: "Draw"; readonly label: DrawLabel; readonly lo: number; readonly size: number; readonly ticket: Ticket }
  | { readonly kind: "Choose"; readonly prompts: ReadonlyArray<Prompt> }
  | { readonly kind: "Finished" }
  | { readonly kind: "Stuck" };

// Notes
// =====

const RawEvent = Schema.Union([
  Schema.Struct({ $: Schema.Literal("RoundBegan"), round: Nat, health: Nat, first: RawSeat }),
  Schema.Struct({ $: Schema.Literal("GrabbingBegan"), seats: rawList(RawSeat) }),
  Schema.Struct({ $: Schema.Literal("Granted"), seat: RawSeat, item: RawItem }),
  Schema.Struct({ $: Schema.Literal("Placed"), seat: RawSeat, slot: RawSlot, item: RawItem }),
  Schema.Struct({ $: Schema.Literal("GrabbingEnded"), seat: RawSeat }),
  Schema.Struct({ $: Schema.Literal("DistributionDone") }),
  Schema.Struct({ $: Schema.Literal("Loaded"), load: RawLoad }),
  Schema.Struct({ $: Schema.Literal("TurnSkipped"), seat: RawSeat }),
  Schema.Struct({ $: Schema.Literal("JamLifted"), seat: RawSeat }),
  Schema.Struct({ $: Schema.Literal("TurnGiven"), seat: RawSeat }),
  Schema.Struct({ $: Schema.Literal("PickedUp"), seat: RawSeat }),
  Schema.Struct({ $: Schema.Literal("Fired"), shooter: RawSeat, target: RawSeat, shell: RawShell, captured: RawDamage, applied: Nat, health: Nat }),
  Schema.Struct({ $: Schema.Literal("Died"), seat: RawSeat }),
  Schema.Struct({ $: Schema.Literal("Used"), seat: RawSeat, owner: RawSeat, slot: RawSlot, item: RawItem }),
  Schema.Struct({ $: Schema.Literal("Healed"), seat: RawSeat, health: Nat }),
  Schema.Struct({ $: Schema.Literal("Ejected"), seat: RawSeat, shell: RawShell }),
  Schema.Struct({ $: Schema.Literal("Inverted"), seat: RawSeat }),
  Schema.Struct({ $: Schema.Literal("JamApplied"), by: RawSeat, target: RawSeat }),
  Schema.Struct({ $: Schema.Literal("DirectionFlipped"), direction: RawDirection }),
  Schema.Struct({ $: Schema.Literal("RoundWon"), seat: RawSeat, prize: Schema.Number }),
  Schema.Struct({ $: Schema.Literal("MatchConcluded") }),
]);

type RawEvent = typeof RawEvent.Type;

const eventOf = (raw: RawEvent): GameEvent =>
  Match.value(raw).pipe(
    Match.discriminatorsExhaustive("$")({
      "RoundBegan": ({ round, health, first }) => GameEvent.cases.RoundBegan.make({ round, health, first: seatOf(first) }),
      "GrabbingBegan": ({ seats }) => GameEvent.cases.GrabbingBegan.make({ seats: listToArray(seats).map(seatOf) }),
      "Granted": ({ seat, item }) => GameEvent.cases.Granted.make({ seat: seatOf(seat), item: itemOf(item) }),
      "Placed": ({ seat, slot, item }) => GameEvent.cases.Placed.make({ seat: seatOf(seat), slot: slotOf(slot), item: itemOf(item) }),
      "GrabbingEnded": ({ seat }) => GameEvent.cases.GrabbingEnded.make({ seat: seatOf(seat) }),
      "DistributionDone": () => GameEvent.cases.DistributionDone.make({}),
      "Loaded": ({ load }) => GameEvent.cases.Loaded.make({ load: loadOf(load) }),
      "TurnSkipped": ({ seat }) => GameEvent.cases.TurnSkipped.make({ seat: seatOf(seat) }),
      "JamLifted": ({ seat }) => GameEvent.cases.JamLifted.make({ seat: seatOf(seat) }),
      "TurnGiven": ({ seat }) => GameEvent.cases.TurnGiven.make({ seat: seatOf(seat) }),
      "PickedUp": ({ seat }) => GameEvent.cases.PickedUp.make({ seat: seatOf(seat) }),
      "Fired": ({ shooter, target, shell, captured, applied, health }) =>
        GameEvent.cases.Fired.make({
          shooter: seatOf(shooter),
          target: seatOf(target),
          shell: shellOf(shell),
          captured: DAMAGE_BY_TAG[captured.$],
          applied,
          health,
        }),
      "Died": ({ seat }) => GameEvent.cases.Died.make({ seat: seatOf(seat) }),
      "Used": ({ seat, owner, slot, item }) => GameEvent.cases.Used.make({ seat: seatOf(seat), owner: seatOf(owner), slot: slotOf(slot), item: itemOf(item) }),
      "Healed": ({ seat, health }) => GameEvent.cases.Healed.make({ seat: seatOf(seat), health }),
      "Ejected": ({ seat, shell }) => GameEvent.cases.Ejected.make({ seat: seatOf(seat), shell: shellOf(shell) }),
      "Inverted": ({ seat }) => GameEvent.cases.Inverted.make({ seat: seatOf(seat) }),
      "JamApplied": ({ by, target }) => GameEvent.cases.JamApplied.make({ by: seatOf(by), target: seatOf(target) }),
      "DirectionFlipped": ({ direction }) => GameEvent.cases.DirectionFlipped.make({ direction: DIRECTION_BY_TAG[direction.$] }),
      "RoundWon": ({ seat, prize }) => GameEvent.cases.RoundWon.make({ seat: seatOf(seat), prize }),
      "MatchConcluded": () => GameEvent.cases.MatchConcluded.make({}),
    }),
  );

const RawSecret = Schema.Union([
  Schema.Struct({ $: Schema.Literal("Glimpse"), shell: RawShell }),
  Schema.Struct({ $: Schema.Literal("Clue"), position: Nat, shell: RawShell }),
  Schema.Struct({ $: Schema.Literal("NoClue") }),
  Schema.Struct({ $: Schema.Literal("EmptyBriefcase") }),
]);

type RawSecret = typeof RawSecret.Type;

const secretOf = (raw: RawSecret): Secret =>
  Match.value(raw).pipe(
    Match.discriminatorsExhaustive("$")({
      "Glimpse": ({ shell }) => Secret.cases.Glimpse.make({ shell: shellOf(shell) }),
      "Clue": ({ position, shell }) => Secret.cases.Clue.make({ position, shell: shellOf(shell) }),
      "NoClue": () => Secret.cases.NoClue.make({}),
      "EmptyBriefcase": () => Secret.cases.EmptyBriefcase.make({}),
    }),
  );

const RawHeard = Schema.Union([Schema.Struct({ $: Schema.Literal("Witnessed"), event: RawEvent }), Schema.Struct({ $: Schema.Literal("Learned"), secret: RawSecret })]);

const RawHeardList = rawList(RawHeard);

const RawEventList = rawList(RawEvent);

const RawPromptList = rawList(RawPrompt);

// Machine state and notes pass back into Bend untouched, so they are checked
// with a guard (which keeps the original value) instead of being rebuilt.
const RawState = Schema.declare(Schema.is(Schema.Struct({ $: Schema.Literal("State") })));

const RawNotes = Schema.declare(Schema.is(Schema.Struct({ $: Schema.Literals(["Con", "Nil"]) })));

// An AI's memory (a driver Mind) also passes back into Bend untouched.
const RawMind = Schema.declare(Schema.is(Schema.Struct({ $: Schema.Literals(["StoryMind", "DonMind"]) })));

const RawDecision = Schema.Struct({ $: Schema.Literal("Decision"), pick: Nat, memory: RawMind });

const RawStepped = Schema.Struct({ $: Schema.Literal("Stepped"), state: RawState, notes: RawNotes });

// Decoding
// ========

const decode =
  <A>(schema: Schema.Codec<A>, call: string) =>
  (value: BendNode): Result.Result<A, BendContractError> =>
    Result.mapError(Schema.decodeUnknownResult(schema)(value), (error) => new BendContractError({ call, detail: error.message }));

const decodeStepped = decode(RawStepped, "answer");

const decodePoint = decode(RawPoint, "point");

const decodePrompts = decode(RawPromptList, "prompts");

const decodeNextPrompt = decode(rawMaybe(RawPrompt), "prompt.next");

const decodeEvents = decode(RawEventList, "public_events");

const decodeDecision = decode(RawDecision, "mind.decide");

const decodeHeard = decode(RawHeardList, "hear");

// Games
// =====

/** A machine state at a request point, with its decoded public view. */
export class Game {
  constructor(
    readonly table: SeatCount,
    readonly seats: ReadonlyArray<Seat>,
    readonly ticket: Ticket,
    readonly board: Board,
    readonly pending: Pending,
    readonly state: BendNode,
  ) {}
}

/** What one answer produced: the next game, the public events, and every secret, each tagged with the seat that heard it. */
export interface Step {
  readonly game: Game;
  readonly events: ReadonlyArray<GameEvent>;
  readonly learned: ReadonlyArray<HeardSecret>;
  readonly notes: BendNode;
}

const promptOf = (ticket: Ticket, raw: RawPrompt): Prompt => new Prompt(seatOf(raw.seat), [moveOf(raw.menu.head), ...listToArray(raw.menu.tail).map(moveOf)], ticket, raw);

const pendingOf = (state: BendNode, request: typeof RawRequest.Type, ticket: Ticket): Result.Result<Pending, BendContractError> =>
  Match.value(request).pipe(
    Match.discriminatorsExhaustive("$")({
      "Draw": ({ label, range }): Result.Result<Pending, BendContractError> =>
        Result.succeed({ kind: "Draw", label: LABEL_BY_TAG[label.$], lo: range.lo, size: range.extra + 2, ticket }),
      "Choose": () => Result.map(decodePrompts(rules.prompts(state)), (prompts): Pending => ({ kind: "Choose", prompts: listToArray(prompts).map((raw) => promptOf(ticket, raw)) })),
      "Finished": (): Result.Result<Pending, BendContractError> => Result.succeed({ kind: "Finished" }),
      "Stuck": (): Result.Result<Pending, BendContractError> => Result.succeed({ kind: "Stuck" }),
    }),
  );

const gameAt = (table: SeatCount, ticket: Ticket, state: BendNode): Result.Result<Game, BendContractError> =>
  Result.gen(function* () {
    const point = yield* decodePoint(rules.point(state));
    const board = boardOf(point.board);
    const pending = yield* pendingOf(state, point.request, ticket);

    return new Game(
      table,
      board.seats.map(({ seat }) => seat),
      ticket,
      board,
      pending,
      state,
    );
  });

const stepFrom = (table: SeatCount, ticket: Ticket, stepped: BendNode): Result.Result<Step, BendContractError> =>
  Result.gen(function* () {
    const { state, notes } = yield* decodeStepped(stepped);
    const game = yield* gameAt(table, ticket, state);
    const events = listToArray(yield* decodeEvents(rules.public_events(notes))).map(eventOf);
    const learned: Array<HeardSecret> = [];

    for (const seat of game.seats) {
      for (const heard of listToArray(yield* decodeHeard(rules.hear(notes, seatNode(seat))))) {
        if (heard.$ === "Learned") learned.push({ seat, secret: secretOf(heard.secret) });
      }
    }

    return { game, events, learned, notes };
  });

/** Starts the default three-round match. With items false every item is disabled. */
export const startGame = (table: SeatCount, items: boolean, match: number): Result.Result<Step, BendContractError> =>
  stepFrom(table, { match, generation: 0 }, rules.start(rules.config({ $: TABLE_TAGS[table] }, items)));

const nextTicket = (ticket: Ticket): Ticket => ({ match: ticket.match, generation: ticket.generation + 1 });

const checkTicket = (game: Game, ticket: Ticket): Result.Result<Game, StaleAnswer> =>
  ticket.match === game.ticket.match && ticket.generation === game.ticket.generation
    ? Result.succeed(game)
    : Result.fail(new StaleAnswer({ expected: game.ticket.generation, received: ticket.generation }));

/** Answers a Draw with a value in 0..size-1 (Bend clamps anything larger). */
export const answerDraw = (game: Game, ticket: Ticket, value: number): Result.Result<Step, AnswerError> =>
  Result.flatMap(checkTicket(game, ticket), (current) => stepFrom(current.table, nextTicket(current.ticket), rules.answer(current.state, value)));

/** Answers seat's prompt at the ticket's request point with the index-th move of that seat's own menu, lifted by Bend's prompt.answer. */
export const answerPrompt = (game: Game, ticket: Ticket, seat: Seat, index: number): Result.Result<Step, AnswerError> =>
  Result.gen(function* () {
    const current = yield* checkTicket(game, ticket);
    const prompts = current.pending.kind === "Choose" ? current.pending.prompts : [];
    const prompt = yield* Result.fromOption(Arr.findFirst(prompts, (candidate) => candidate.seat === seat), () => new NoPrompt({ seat }));

    return yield* stepFrom(current.table, nextTicket(current.ticket), rules.answer(current.state, rules["prompt.answer"](prompt.raw, index)));
  });

/**
 * Which of these prompts the Bend driver serves first (R.prompt.next in
 * sim/bend-mp/driver.bend): a seat holding an item places it, otherwise the
 * seat with the fewest grants this distribution grabs, ties going to the first
 * seat after the first shooter. A malformed answer is a Bend contract bug and throws.
 */
export const nextPrompt = (game: Game, prompts: ReadonlyArray<Prompt>): Option.Option<Prompt> =>
  maybeToOption(Result.getOrThrow(decodeNextPrompt(rules["prompt.next"](game.state, arrayToList(prompts.map(({ raw }) => raw)))))).pipe(
    Option.flatMap(({ seat }) => Arr.findFirst(prompts, (prompt) => prompt.seat === seatOf(seat))),
  );

// AI seats
// ========

/** Which AI plays a seat. Both are the Bend AIs the simulator driver uses. */
export type Brain = "Story" | "DoN";

/** One AI's memory. Opaque: only Bend reads it. */
export class Mind {
  constructor(readonly raw: BendNode) {}
}

export const freshMind = (brain: Brain): Mind => new Mind(brain === "Story" ? rules["mind.story"]() : rules["mind.don"]());

/** The memory after the seat heard the notes of one step. */
export const hearNotes = (mind: Mind, notes: BendNode, seat: Seat): Mind => new Mind(rules["mind.hear"](mind.raw, notes, seatNode(seat)));

/** Word number count of the seat's own random stream for a match seed. */
export const coinWord = (seed: number, seat: Seat, count: number): number => rules["mind.coin"](seed >>> 0, seatNode(seat), count);

/** What an AI chose: an index into the prompt's menu, and its memory after choosing. */
export interface Choice {
  readonly index: number;
  readonly mind: Mind;
}

export const decideMove = (game: Game, prompt: Prompt, mind: Mind, coin: number): Result.Result<Choice, BendContractError> =>
  Result.map(decodeDecision(rules["mind.decide"](game.state, prompt.raw, mind.raw, coin)), ({ pick, memory }) => ({ index: pick, mind: new Mind(memory) }));
