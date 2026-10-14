import { expect, test } from "bun:test";
import { Array as Arr, Option, Schema } from "effect";

import { AgentCall, AgentReply } from "../src/agent.ts";
import { Game } from "../src/bend.ts";
import { Seat, SeatCount } from "../src/domain.ts";
import { type Controller, promptsOf } from "../src/driver.ts";
import { handleAgentCall, init, update } from "../src/main.ts";
import { Message, type Model } from "../src/model.ts";
import { nextBelow, type Rng, seedRng } from "../src/rng.ts";

const STEP_LIMIT = 20_000;

const View = Schema.Struct({
  you: Schema.String,
  isYourTurn: Schema.Boolean,
  isMatchOver: Schema.Boolean,
  turn: Schema.Number,
  privateNotes: Schema.Array(Schema.String),
  moves: Schema.Array(Schema.Struct({ index: Schema.Number, label: Schema.String })),
});

const parseView = Schema.decodeUnknownSync(Schema.fromJsonString(View));

const blank = (): Model => init({ isWebMcpAvailable: true }).model;

const call = (model: Model, request: AgentCall): { readonly model: Model; readonly reply: AgentReply } => handleAgentCall(model, request);

const newMatch = (players: SeatCount, items: boolean, seed?: string, controllers?: ReadonlyArray<Controller>): Model =>
  call(blank(), AgentCall.cases.NewMatch.make({ players, items, seed, controllers })).model;

const getGame = (model: Model, seat: Seat): AgentReply => call(model, AgentCall.cases.GetGame.make({ seat })).reply;

const play = (model: Model, seat: Seat, index: number, turn?: number) => call(model, AgentCall.cases.PlayMove.make({ seat, index, turn }));

const answered = (reply: AgentReply): string =>
  AgentReply.match(reply, { Answered: ({ text }) => text, Refused: ({ reason }) => expect.unreachable(`refused: ${reason}`) });

const refusal = (reply: AgentReply): string =>
  AgentReply.match(reply, { Answered: () => expect.unreachable("expected a refusal"), Refused: ({ reason }) => reason });

const viewOf = (model: Model, seat: Seat) => parseView(answered(getGame(model, seat)));

const match = (model: Model) => Option.getOrThrow(model.maybeMatch);

const isOver = (model: Model): boolean => match(model).game.pending.kind === "Finished";

const agentSeats = (model: Model): ReadonlyArray<Seat> => match(model).game.seats.filter((seat) => match(model).controllers[seat] === "Agent");

const agentsToMove = (model: Model): ReadonlyArray<Seat> => promptsOf(match(model).game).map(({ seat }) => seat).filter((seat) => agentSeats(model).includes(seat));

/** Autoplay ticks until an Agent seat has a move or the match ends. */
const untilAgentTurn = (start: Model): Model => {
  let model = start;

  for (let steps = 0; steps < STEP_LIMIT; steps++) {
    if (isOver(model) || agentsToMove(model).length > 0) return model;

    model = update(model, Message.TickedAutoplay()).model;
  }

  return expect.unreachable("the bots never handed the turn to an agent");
};

/** A seeded source of choices, so each run of a test sees the same tables. */
const chooser = (seed: number) => {
  let rng: Rng = seedRng(seed);

  return <A>(options: ReadonlyArray<A>): A => {
    const [value, next] = nextBelow(rng, options.length);

    rng = next;

    return Arr.getUnsafe(options, value);
  };
};

test("two Agent seats and a DoN seat play a 3-seat match with items to the end through the tools alone", () => {
  let model = untilAgentTurn(newMatch(3, true, "42", ["Agent", "Agent", "DoN"]));
  let moves = 0;
  let sharedTurns = 0;
  const moved = new Set<Seat>();

  for (; moves < STEP_LIMIT && !isOver(model); moves++) {
    const ready = agentsToMove(model);
    const seat = Arr.getUnsafe(ready, moves % ready.length);
    const view = viewOf(model, seat);
    const outcome = play(model, seat, (moves * 7) % view.moves.length, view.turn);

    sharedTurns += ready.length > 1 ? 1 : 0;
    moved.add(seat);
    expect(outcome.reply._tag).toBe("Answered");

    model = untilAgentTurn(outcome.model);
  }

  expect(isOver(model)).toBe(true);
  expect(viewOf(model, 0).isMatchOver).toBe(true);
  expect(moved).toEqual(new Set<Seat>([0, 1]));
  expect(sharedTurns).toBeGreaterThan(0);
});

test("Agent seats that may move at once can answer in either order, and the later one must reread its turn", () => {
  let model = untilAgentTurn(newMatch(3, true, "42", ["Agent", "Agent", "DoN"]));

  for (let steps = 0; steps < STEP_LIMIT && agentsToMove(model).length < 2; steps++) {
    const seat = Arr.getUnsafe(agentsToMove(model), 0);

    model = untilAgentTurn(play(model, seat, 0, viewOf(model, seat).turn).model);
  }

  for (const [first, second] of [[0, 1], [1, 0]] as const) {
    const before = viewOf(model, second);
    const afterFirst = play(model, first, 0, viewOf(model, first).turn).model;

    expect(viewOf(afterFirst, second).isYourTurn).toBe(true);
    expect(refusal(play(afterFirst, second, 0, before.turn).reply)).toContain("Stale");
    expect(play(afterFirst, second, 0, viewOf(afterFirst, second).turn).reply._tag).toBe("Answered");
  }
});

test("on random tables, each Agent seat sees only its own notes, and calls for other seats or stale turns change nothing", () => {
  const choose = chooser(2026);
  const otherState = match(newMatch(4, true, "8")).game.state;
  let otherAgentNotes = 0;

  for (let trial = 0; trial < 6; trial++) {
    const players = choose(SeatCount.literals);
    const lead = choose(Arr.range(0, players - 1));
    const controllers = Arr.makeBy(players, (position): Controller => (position === lead ? "Agent" : choose(["Agent", "DoN", "Story"] as const)));
    let model = untilAgentTurn(newMatch(players, true, String(choose(Arr.range(1, 10_000))), controllers));

    for (let steps = 0; steps < STEP_LIMIT && !isOver(model); steps++) {
      const current = match(model);
      const agents = agentSeats(model);

      for (const seat of Seat.literals) {
        if (!agents.includes(seat)) {
          const outcome = play(model, seat, 0);

          expect(refusal(getGame(model, seat))).toContain("not an Agent seat");
          expect(refusal(outcome.reply)).toContain("not an Agent seat");
          expect(outcome.model).toBe(model);
          continue;
        }

        const reply = getGame(model, seat);
        const view = parseView(answered(reply));
        const ownNotes = current.learned.filter((note) => note.seat === seat);
        const hiddenSwapped = new Game(current.game.table, current.game.seats, current.game.ticket, current.game.board, current.game.pending, otherState);

        otherAgentNotes += current.learned.filter((note) => note.seat !== seat && agents.includes(note.seat)).length;
        expect(view.privateNotes).toHaveLength(ownNotes.length);
        expect(getGame({ ...model, maybeMatch: Option.some({ ...current, learned: ownNotes }) }, seat)).toEqual(reply);
        expect(getGame({ ...model, maybeMatch: Option.some({ ...current, game: hiddenSwapped }) }, seat)).toEqual(reply);

        for (const turn of [view.turn - 1, view.turn + 1]) {
          const outcome = play(model, seat, 0, turn);

          expect(refusal(outcome.reply)).toContain(view.isYourTurn ? "Stale" : "not your turn");
          expect(outcome.model).toBe(model);
        }
      }

      const seat = choose(agentsToMove(model));
      const view = viewOf(model, seat);

      model = untilAgentTurn(play(model, seat, choose(view.moves).index, view.turn).model);
    }

    expect(isOver(model)).toBe(true);
  }

  expect(otherAgentNotes).toBeGreaterThan(0);
}, 20_000);

test("a move number outside the list is refused and changes nothing", () => {
  const model = untilAgentTurn(newMatch(2, true, "3"));
  const { moves } = viewOf(model, 1);

  for (const index of [moves.length, -1, 1.5]) {
    const outcome = play(model, 1, index);

    expect(refusal(outcome.reply)).toContain("no move");
    expect(outcome.model).toBe(model);
  }
});

test("a move when it is not the seat's turn is refused", () => {
  let moved = untilAgentTurn(newMatch(2, true, "3"));

  // Picking up the gun and shooting are separate moves, so play until the turn passes.
  for (let moves = 0; moves < STEP_LIMIT && viewOf(moved, 1).isYourTurn; moves++) {
    const { turn, moves: legal } = viewOf(moved, 1);

    moved = play(moved, 1, legal.length - 1, turn).model;
  }

  expect(viewOf(moved, 1).isYourTurn).toBe(false);

  const outcome = play(moved, 1, 0);

  expect(refusal(outcome.reply)).toContain("not your turn");
  expect(outcome.model).toBe(moved);
});

test("the tools refuse without a match or without an Agent seat", () => {
  expect(refusal(getGame(blank(), 1))).toContain("new_match");

  const humanOnly = update({ ...blank(), setup: { ...blank().setup, controllers: ["DoN", "Human", "DoN", "DoN"] } }, Message.ClickedNewMatch()).model;

  expect(refusal(getGame(humanOnly, 1))).toContain("no seat is");
  expect(refusal(play(humanOnly, 1, 0).reply)).toContain("no seat is");
});

test("new_match refuses a seed that is not an integer, and a controller list of the wrong length", () => {
  expect(refusal(call(blank(), AgentCall.cases.NewMatch.make({ players: 2, items: false, seed: "abc" })).reply)).toContain("seed");
  expect(refusal(call(blank(), AgentCall.cases.NewMatch.make({ players: 3, items: false, controllers: ["Agent", "Agent"] })).reply)).toContain("one controller per seat");
});

test("new_match seats the agent first and DoN elsewhere by default, and autoplay stays armed at the agent's turn", () => {
  const model = untilAgentTurn(newMatch(3, false, "5"));

  expect(model.setup.controllers).toEqual(["Agent", "DoN", "DoN", "DoN"]);
  expect(match(model).isAutoplay).toBe(true);

  const ticked = update(model, Message.TickedAutoplay()).model;

  expect(match(ticked).events).toBe(match(model).events);
  expect(match(ticked).isAutoplay).toBe(true);
});

test("new_match gives the listed controllers to the table's seats in order and says which seat is which", () => {
  const outcome = call(blank(), AgentCall.cases.NewMatch.make({ players: 2, items: false, controllers: ["Story", "Agent"] }));

  expect(JSON.parse(answered(outcome.reply)).seats).toEqual([
    { seat: 1, controller: "Story" },
    { seat: 3, controller: "Agent" },
  ]);
});

test("any number of seats can be set to Agent", () => {
  const toAgent = (model: Model, seat: Seat): Model => {
    let current = model;

    for (let clicks = 0; clicks < 4 && current.setup.controllers[seat] !== "Agent"; clicks++) current = update(current, Message.ToggledController({ seat })).model;

    return current;
  };

  expect(Seat.literals.reduce(toAgent, blank()).setup.controllers).toEqual(["Agent", "Agent", "Agent", "Agent"]);
});

test("a tool call through update returns one reply command", () => {
  const outcome = update(blank(), Message.AgentCalled({ id: 9, call: AgentCall.cases.GetGame.make({ seat: 1 }) }));

  expect(outcome.commands?.map(({ name }) => name)).toEqual(["ReplyToAgent"]);
});
