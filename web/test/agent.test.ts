import { expect, test } from "bun:test";
import { Option, Schema } from "effect";

import { AgentCall, AgentReply } from "../src/agent.ts";
import { Game } from "../src/bend.ts";
import { type SeatCount } from "../src/domain.ts";
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

const newMatch = (players: SeatCount, items: boolean, seed?: string): Model => handleAgentCall(blank(), AgentCall.cases.NewMatch.make({ players, items, seed })).model;

const call = (model: Model, request: AgentCall): { readonly model: Model; readonly reply: AgentReply } => handleAgentCall(model, request);

const getGame = (model: Model): AgentReply => call(model, AgentCall.cases.GetGame.make({})).reply;

const answered = (reply: AgentReply): string =>
  AgentReply.match(reply, { Answered: ({ text }) => text, Refused: ({ reason }) => expect.unreachable(`refused: ${reason}`) });

const refusal = (reply: AgentReply): string =>
  AgentReply.match(reply, { Answered: () => expect.unreachable("expected a refusal"), Refused: ({ reason }) => reason });

const viewOf = (model: Model) => parseView(answered(getGame(model)));

const match = (model: Model) => Option.getOrThrow(model.maybeMatch);

/** Autoplay ticks until the agent has a move or the match ends. */
const untilAgentTurn = (start: Model): Model => {
  let model = start;

  for (let steps = 0; steps < STEP_LIMIT; steps++) {
    const view = viewOf(model);

    if (view.isYourTurn || view.isMatchOver) return model;

    model = update(model, Message.TickedAutoplay()).model;
  }

  return expect.unreachable("the bots never handed the turn to the agent");
};

const play = (model: Model, index: number, turn?: number) => call(model, AgentCall.cases.PlayMove.make({ index, turn }));

test("a 2-seat match with items is played to the end through the tools alone", () => {
  let model = untilAgentTurn(newMatch(2, true, "42"));
  let moves = 0;

  for (; moves < STEP_LIMIT && !viewOf(model).isMatchOver; moves++) {
    const view = viewOf(model);
    const outcome = play(model, (moves * 7) % view.moves.length, view.turn);

    expect(outcome.reply._tag).toBe("Answered");

    model = untilAgentTurn(outcome.model);
  }

  expect(viewOf(model).isMatchOver).toBe(true);
  expect(match(model).game.pending.kind).toBe("Finished");
  expect(moves).toBeGreaterThan(5);
});

test("get_game shows no other seat's notes and does not read the hidden state", () => {
  let model = untilAgentTurn(newMatch(3, true, "7"));
  let sawOthersLearn = false;

  const other = newMatch(3, true, "8");
  const otherState = match(other).game.state;

  for (let moves = 0; moves < STEP_LIMIT && !viewOf(model).isMatchOver; moves++) {
    const current = match(model);
    const agent = current.game.seats.find((seat) => current.controllers[seat] === "Agent");
    const onlyAgentsNotes = { ...current, learned: current.learned.filter(({ seat }) => seat === agent) };
    const game = new Game(current.game.table, current.game.seats, current.game.ticket, current.game.board, current.game.pending, otherState);

    sawOthersLearn ||= current.learned.some(({ seat }) => seat !== agent);

    expect(getGame({ ...model, maybeMatch: Option.some(onlyAgentsNotes) })).toEqual(getGame(model));
    expect(getGame({ ...model, maybeMatch: Option.some({ ...current, game }) })).toEqual(getGame(model));

    const view = viewOf(model);

    model = untilAgentTurn(view.isYourTurn ? play(model, 0, view.turn).model : model);
  }

  expect(sawOthersLearn).toBe(true);
});

test("the agent's own notes are in its view", () => {
  let model = untilAgentTurn(newMatch(2, true, "11"));
  let noted = 0;

  for (let moves = 0; moves < STEP_LIMIT && !viewOf(model).isMatchOver; moves++) {
    const view = viewOf(model);
    const own = match(model).learned.filter(({ seat }) => seat === match(model).game.seats.find((candidate) => match(model).controllers[candidate] === "Agent"));

    expect(view.privateNotes).toHaveLength(own.length);
    noted = Math.max(noted, view.privateNotes.length);

    model = untilAgentTurn(play(model, view.moves.length - 1, view.turn).model);
  }

  expect(noted).toBeGreaterThan(0);
});

test("a move number outside the list is refused and changes nothing", () => {
  const model = untilAgentTurn(newMatch(2, true, "3"));
  const { moves } = viewOf(model);

  for (const index of [moves.length, -1, 1.5]) {
    const outcome = play(model, index);

    expect(refusal(outcome.reply)).toContain("no move");
    expect(outcome.model).toBe(model);
  }
});

test("a move for an earlier turn is refused", () => {
  const model = untilAgentTurn(newMatch(2, true, "3"));
  const { turn } = viewOf(model);
  const outcome = play(model, 0, turn - 1);

  expect(refusal(outcome.reply)).toContain("Stale");
  expect(outcome.model).toBe(model);
});

test("a move when it is not the agent's turn is refused", () => {
  let moved = untilAgentTurn(newMatch(2, true, "3"));

  // Picking up the gun and shooting are separate moves, so play until the turn passes.
  for (let moves = 0; moves < STEP_LIMIT && viewOf(moved).isYourTurn; moves++) {
    const { turn, moves: legal } = viewOf(moved);

    moved = play(moved, legal.length - 1, turn).model;
  }

  expect(viewOf(moved).isYourTurn).toBe(false);

  const outcome = play(moved, 0);

  expect(refusal(outcome.reply)).toContain("not your turn");
  expect(outcome.model).toBe(moved);
});

test("the tools refuse without a match or without an Agent seat", () => {
  expect(refusal(getGame(blank()))).toContain("new_match");

  const humanOnly = update({ ...blank(), setup: { ...blank().setup, controllers: ["DoN", "Human", "DoN", "DoN"] } }, Message.ClickedNewMatch()).model;

  expect(refusal(getGame(humanOnly))).toContain("Agent");
  expect(refusal(play(humanOnly, 0).reply)).toContain("Agent");
});

test("new_match refuses a seed that is not an integer", () => {
  expect(refusal(call(blank(), AgentCall.cases.NewMatch.make({ players: 2, items: false, seed: "abc" })).reply)).toContain("seed");
});

test("new_match seats the agent first and DoN elsewhere, and autoplay stays armed at the agent's turn", () => {
  const model = untilAgentTurn(newMatch(3, false, "5"));

  expect(model.setup.controllers).toEqual(["Agent", "DoN", "DoN", "DoN"]);
  expect(match(model).isAutoplay).toBe(true);

  const ticked = update(model, Message.TickedAutoplay()).model;

  expect(match(ticked).events).toBe(match(model).events);
  expect(match(ticked).isAutoplay).toBe(true);
});

test("setting a second seat to Agent moves the role", () => {
  const cycle = (model: Model, seat: 0 | 1 | 2 | 3, times: number): Model => Array.from({ length: times }).reduce<Model>((current) => update(current, Message.ToggledController({ seat })).model, model);

  const first = cycle(blank(), 1, 3);

  expect(first.setup.controllers).toEqual(["DoN", "Agent", "DoN", "DoN"]);
  expect(cycle(first, 3, 1).setup.controllers).toEqual(["DoN", "Human", "DoN", "Agent"]);
});

test("a tool call through update returns one reply command", () => {
  const outcome = update(blank(), Message.AgentCalled({ id: 9, call: AgentCall.cases.GetGame.make({}) }));

  expect(outcome.commands?.map(({ name }) => name)).toEqual(["ReplyToAgent"]);
});
