import { expect, test } from "bun:test";
import { Array as Arr, Option, Schema } from "effect";

import { AgentCall, AgentReply } from "../src/agent/tools.ts";
import { Seat, SeatCount } from "../src/domain.ts";
import { type Controller, promptsOf } from "../src/driver.ts";
import { init, Message, type Model, handleAgentCall, update } from "../src/main.ts";

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

const call = (model: Model, request: AgentCall) => handleAgentCall(model, request);

const newMatch = (players: SeatCount, items: boolean, seed: string, controllers: ReadonlyArray<Controller>): Model =>
  call(blank(), AgentCall.cases.NewMatch.make({ players, items, seed, controllers })).state;

const getGame = (model: Model, seat: Seat): AgentReply => call(model, AgentCall.cases.GetGame.make({ seat })).reply;

const play = (model: Model, seat: Seat, index: number, turn: number) => call(model, AgentCall.cases.PlayMove.make({ seat, index, turn }));

const answered = (reply: AgentReply): string =>
  AgentReply.match(reply, { Answered: ({ text }) => text, Refused: ({ reason }) => expect.unreachable(`refused: ${reason}`) });

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

test("in the page, two Agent seats and a DoN seat play a 3-seat match to the end through the tools, with autoplay moving the bot", () => {
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

    model = untilAgentTurn(outcome.state);
  }

  expect(isOver(model)).toBe(true);
  expect(viewOf(model, 0).isMatchOver).toBe(true);
  expect(moved).toEqual(new Set<Seat>([0, 1]));
  expect(sharedTurns).toBeGreaterThan(0);
});

test("new_match seats the agent first and DoN elsewhere by default, and autoplay stays armed at the agent's turn", () => {
  const model = untilAgentTurn(call(blank(), AgentCall.cases.NewMatch.make({ players: 3, items: false })).state);

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
