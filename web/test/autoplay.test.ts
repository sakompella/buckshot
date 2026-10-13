import { expect, test } from "bun:test";
import { Array as Arr, Option } from "effect";

import { controllerOf, promptsOf } from "../src/driver.ts";
import { init, Message, type Model, update } from "../src/main.ts";

const TICK_LIMIT = 5_000;

const send = (model: Model, message: Message): Model => update(model, message).model;

const started = (controllers: Model["setup"]["controllers"]): Model => {
  const model = init().model;

  return send({ ...model, setup: { ...model.setup, controllers } }, Message.ClickedNewMatch());
};

const autoplaying = (model: Model): boolean => Option.exists(model.maybeMatch, (match) => match.isAutoplay);

const humanPrompt = (model: Model) =>
  Option.flatMap(model.maybeMatch, (match) => Arr.findFirst(promptsOf(match.game), (prompt) => controllerOf(match.controllers, prompt.seat) === "Human"));

const pendingKind = (model: Model): string | undefined => Option.getOrUndefined(model.maybeMatch)?.game.pending.kind;

test("autoplay switches off as soon as the match finishes", () => {
  let model = send(started(["DoN", "Story", "DoN", "Story"]), Message.ToggledAutoplay());

  for (let ticks = 0; ticks < TICK_LIMIT && pendingKind(model) !== "Finished"; ticks++) {
    expect(autoplaying(model)).toBe(true);
    model = send(model, Message.TickedAutoplay());
  }

  expect(pendingKind(model)).toBe("Finished");
  expect(autoplaying(model)).toBe(false);
});

test("autoplay stays armed on a human turn and the AI moves on after the human answers", () => {
  let model = send(started(["DoN", "Human", "DoN", "DoN"]), Message.ToggledAutoplay());

  for (let steps = 0; steps < TICK_LIMIT && Option.isNone(humanPrompt(model)); steps++) model = send(model, Message.TickedAutoplay());

  expect(Option.isSome(humanPrompt(model))).toBe(true);
  expect(autoplaying(model)).toBe(true);

  for (let answers = 0; answers < TICK_LIMIT && Option.isSome(humanPrompt(model)); answers++) {
    const prompt = Option.getOrThrow(humanPrompt(model));

    model = send(model, Message.ClickedMove({ match: prompt.ticket.match, generation: prompt.ticket.generation, seat: prompt.seat, index: 0 }));
  }

  const match = Option.getOrThrow(model.maybeMatch);
  const aiCoins = (): number => Option.getOrThrow(model.maybeMatch).ais.reduce((total, ai) => total + Option.match(ai, { onNone: () => 0, onSome: ({ coins }) => coins }), 0);
  const before = aiCoins();

  expect(match.isAutoplay).toBe(true);

  model = send(model, Message.TickedAutoplay());

  expect(aiCoins()).toBe(before + 1);
});

test("autoplay cannot be switched on at a table with no AI seat", () => {
  const model = send(started(["Human", "Human", "Human", "Human"]), Message.ToggledAutoplay());

  expect(autoplaying(model)).toBe(false);
});

test("a new match starts with autoplay off", () => {
  const model = send(send(started(["DoN", "Story", "DoN", "Story"]), Message.ToggledAutoplay()), Message.ClickedNewMatch());

  expect(autoplaying(model)).toBe(false);
});
