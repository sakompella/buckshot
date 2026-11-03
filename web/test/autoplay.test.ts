import { expect, test } from "bun:test";
import { Array as Arr, Option } from "effect";

import { controllerOf, promptsOf } from "../src/driver.ts";
import { init, update } from "../src/main.ts";
import { Message, type Model } from "../src/model.ts";

const TICK_LIMIT = 5_000;

const send = (model: Model, message: Message): Model => update(model, message).model;

const started = (controllers: Model["setup"]["controllers"]): Model => {
  const model = init({ isWebMcpAvailable: false }).model;

  return send({ ...model, setup: { ...model.setup, controllers } }, Message.ClickedNewMatch());
};

const autoplaying = (model: Model): boolean => Option.exists(model.maybeMatch, (match) => match.isAutoplay);

const humanPrompt = (model: Model) =>
  Option.flatMap(model.maybeMatch, (match) => Arr.findFirst(promptsOf(match.game), (prompt) => controllerOf(match.controllers, prompt.seat) === "Human"));

const pendingKind = (model: Model): string | undefined => Option.getOrUndefined(model.maybeMatch)?.game.pending.kind;

test("autoplay switches off as soon as the match finishes", () => {
  let model = started(["DoN", "Story", "DoN", "Story"]);

  for (let ticks = 0; ticks < TICK_LIMIT && pendingKind(model) !== "Finished"; ticks++) {
    expect(autoplaying(model)).toBe(true);
    model = send(model, Message.TickedAutoplay());
  }

  expect(pendingKind(model)).toBe("Finished");
  expect(autoplaying(model)).toBe(false);
});

test("autoplay stays armed on a human turn and the AI moves on after the human answers", () => {
  let model = started(["DoN", "Human", "DoN", "DoN"]);

  for (let steps = 0; steps < TICK_LIMIT && Option.isNone(humanPrompt(model)); steps++) model = send(model, Message.TickedAutoplay());

  expect(Option.isSome(humanPrompt(model))).toBe(true);
  expect(autoplaying(model)).toBe(true);

  for (let answers = 0; answers < TICK_LIMIT && Option.isSome(humanPrompt(model)); answers++) {
    const prompt = Option.getOrThrow(humanPrompt(model));

    model = send(model, Message.ClickedMove({ match: prompt.ticket.match, generation: prompt.ticket.generation, seat: prompt.seat, index: 0 }));
  }

  const eventsOf = (current: Model): number => Option.getOrThrow(current.maybeMatch).events.length;
  const before = eventsOf(model);

  expect(autoplaying(model)).toBe(true);

  model = send(model, Message.TickedAutoplay());

  expect(eventsOf(model)).toBeGreaterThan(before);
});

test("autoplay cannot be switched on at a table with no AI seat", () => {
  const model = send(started(["Human", "Human", "Human", "Human"]), Message.ToggledAutoplay());

  expect(autoplaying(model)).toBe(false);
});

test("a new match starts with the bots moving, and the toggle pauses them", () => {
  const model = started(["DoN", "Story", "DoN", "Story"]);

  expect(autoplaying(model)).toBe(true);
  expect(autoplaying(send(model, Message.ToggledAutoplay()))).toBe(false);
});

test("a click on a menu the game has moved past changes nothing and keeps autoplay on", () => {
  let model = started(["DoN", "Human", "DoN", "DoN"]);

  for (let steps = 0; steps < TICK_LIMIT && Option.isNone(humanPrompt(model)); steps++) model = send(model, Message.TickedAutoplay());

  const prompt = Option.getOrThrow(humanPrompt(model));
  const click = Message.ClickedMove({ match: prompt.ticket.match, generation: prompt.ticket.generation, seat: prompt.seat, index: 0 });
  const answered = send(model, click);
  const replayed = send(answered, click);

  expect(replayed).toEqual(answered);
  expect(Option.isNone(replayed.maybeError)).toBe(true);
  expect(autoplaying(replayed)).toBe(true);
});
