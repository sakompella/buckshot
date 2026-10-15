import { expect, test } from "bun:test";
import { Array as Arr, Option, Schema } from "effect";

import { AgentCall, AgentReply } from "../src/agent/tools.ts";
import { Seat, SeatCount } from "../src/domain.ts";
import { type Controller, promptsOf } from "../src/driver.ts";
import { PlayerNumber, rosterOf } from "../src/players.ts";
import { init, Message, type Model, handleAgentCall, update } from "../src/main.ts";

const STEP_LIMIT = 20_000;

const View = Schema.Struct({
  you: Schema.Number,
  status: Schema.Literals(["your turn", "waiting", "over"]),
  turn: Schema.optionalKey(Schema.Number),
  players: Schema.optionalKey(Schema.Array(Schema.Struct({ player: Schema.Number, holding: Schema.optionalKey(Schema.String) }))),
  moves: Schema.optionalKey(Schema.Array(Schema.String)),
});

const parseView = Schema.decodeUnknownSync(Schema.fromJsonString(View));

const blank = (): Model => init({ isWebMcpAvailable: true }).model;

const call = (model: Model, request: AgentCall) => handleAgentCall(model, request);

const newMatch = (players: SeatCount, items: boolean, seed: number, controllers: ReadonlyArray<Controller>, model = blank()): Model =>
  call(model, AgentCall.cases.NewMatch.make({ players, items, seed, controllers })).state;

const getGame = (model: Model, player: PlayerNumber): AgentReply => call(model, AgentCall.cases.GetGame.make({ player })).reply;

const play = (model: Model, player: PlayerNumber, move: number, turn: number) => call(model, AgentCall.cases.PlayMove.make({ player, move, turn }));

const answered = (reply: AgentReply): string =>
  AgentReply.match(reply, { Answered: ({ text }) => text, Refused: ({ reason }) => expect.unreachable(`refused: ${reason}`) });

const viewOf = (model: Model, player: PlayerNumber) => parseView(answered(getGame(model, player)));

const match = (model: Model) => Option.getOrThrow(model.maybeMatch);

const isOver = (model: Model): boolean => match(model).game.pending.kind === "Finished";

const agentSeats = (model: Model): ReadonlyArray<Seat> => match(model).game.seats.filter((seat) => match(model).controllers[seat] === "Agent");

const agentsToMove = (model: Model): ReadonlyArray<PlayerNumber> => {
  const roster = rosterOf(match(model).game.seats);

  return promptsOf(match(model).game).map(({ seat }) => seat).filter((seat) => agentSeats(model).includes(seat)).map(roster.playerOf);
};

/** Autoplay ticks until an Agent seat has a move or the match ends. */
const untilAgentTurn = (start: Model): Model => {
  let model = start;

  for (let steps = 0; steps < STEP_LIMIT; steps++) {
    if (isOver(model) || agentsToMove(model).length > 0) return model;

    model = update(model, Message.TickedAutoplay()).model;
  }

  return expect.unreachable("the bots never handed the turn to an agent");
};

test("in the page, two Agent players and a DoN player play a 3-player match to the end through the tools, with autoplay moving the bot", () => {
  let model = untilAgentTurn(newMatch(3, true, 42, ["Agent", "Agent", "DoN"]));
  let moves = 0;
  let sharedTurns = 0;
  const moved = new Set<PlayerNumber>();

  for (; moves < STEP_LIMIT && !isOver(model); moves++) {
    const ready = agentsToMove(model);
    const player = Arr.getUnsafe(ready, moves % ready.length);
    const { turn = expect.unreachable("a player to move has no turn"), moves: legal = [] } = viewOf(model, player);
    const outcome = play(model, player, (moves * 7) % legal.length, turn);

    sharedTurns += ready.length > 1 ? 1 : 0;
    moved.add(player);
    expect(outcome.reply._tag).toBe("Answered");

    model = untilAgentTurn(outcome.state);
  }

  expect(isOver(model)).toBe(true);
  expect(viewOf(model, PlayerNumber.make(1)).status).toBe("over");
  expect(moved).toEqual(new Set([PlayerNumber.make(1), PlayerNumber.make(2)]));
  expect(sharedTurns).toBeGreaterThan(0);
});

test("new_match makes Player 1 the agent and DoN the others by default, and autoplay stays armed at the agent's turn", () => {
  const model = untilAgentTurn(call(blank(), AgentCall.cases.NewMatch.make({ players: 3, items: false })).state);

  expect(model.setup.controllers).toEqual(["Agent", "DoN", "DoN", "DoN"]);
  expect(match(model).isAutoplay).toBe(true);

  const ticked = update(model, Message.TickedAutoplay()).model;

  expect(match(ticked).events).toBe(match(model).events);
  expect(match(ticked).isAutoplay).toBe(true);
});

test("new_match gives the listed controllers to the table's players in order and says which player is which", () => {
  const outcome = call(blank(), AgentCall.cases.NewMatch.make({ players: 2, items: false, controllers: ["Story", "Agent"] }));

  expect(JSON.parse(answered(outcome.reply)).players).toEqual([
    { player: 1, controller: "Story" },
    { player: 2, controller: "Agent" },
  ]);
});

test("any number of players can be set to Agent", () => {
  const toAgent = (model: Model, seat: Seat): Model => {
    let current = model;

    for (let clicks = 0; clicks < 4 && current.setup.controllers[seat] !== "Agent"; clicks++) current = update(current, Message.ToggledController({ seat })).model;

    return current;
  };

  expect(Seat.literals.reduce(toAgent, blank()).setup.controllers).toEqual(["Agent", "Agent", "Agent", "Agent"]);
});

test("a tool call through update returns one reply command", () => {
  const outcome = update(blank(), Message.AgentCalled({ id: 9, call: AgentCall.cases.GetGame.make({ player: PlayerNumber.make(1) }) }));

  expect(outcome.commands?.map(({ name }) => name)).toEqual(["ReplyToAgent"]);
});

test("in the page, new_match is refused while a match runs, the Restart match button still starts one, and a turn from before the restart is refused at the same point of the same seed", () => {
  const first = untilAgentTurn(newMatch(2, false, 3, ["Agent", "DoN"]));
  const { turn = expect.unreachable("Player 1 has no turn"), ...before } = viewOf(first, PlayerNumber.make(1));
  const refused = call(first, AgentCall.cases.NewMatch.make({ players: 2, items: false, seed: 3, controllers: ["Agent", "DoN"] }));

  expect(refused.reply).toEqual(AgentReply.cases.Refused.make({ reason: "A match is in progress; finish it first." }));
  expect(refused.state).toBe(first);

  const restarted = untilAgentTurn(update(first, Message.ClickedNewMatch()).model);
  const { turn: laterTurn, ...after } = viewOf(restarted, PlayerNumber.make(1));

  expect(after).toEqual(before);
  expect(laterTurn).toBeGreaterThan(turn);
  expect(play(restarted, PlayerNumber.make(1), 0, turn).reply._tag).toBe("Refused");
});

test("in the page, an Agent sees the item a Human player drew and has not placed yet", () => {
  const model = newMatch(2, true, 5, ["Human", "Agent"]);
  const human = Option.getOrThrow(rosterOf(match(model).game.seats).seatOf(1));
  const grab = Arr.findFirst(promptsOf(match(model).game), ({ seat }) => seat === human).pipe(Option.getOrThrow);
  const holding = update(model, Message.ClickedMove({ ...grab.ticket, seat: human, index: 0 })).model;

  expect(viewOf(holding, PlayerNumber.make(2)).players?.[0]?.holding).toBeString();
});
