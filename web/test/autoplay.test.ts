import { expect, test } from "bun:test";
import { Option } from "effect";

import { init, Message, type Model, update } from "../src/main.ts";

const TICK_LIMIT = 5_000;

const send = (model: Model, message: Message): Model => update(model, message).model;

const started = (controllers: Model["setup"]["controllers"]): Model => {
  const model = init().model;

  return send({ ...model, setup: { ...model.setup, controllers } }, Message.ClickedNewMatch());
};

const autoplaying = (model: Model): boolean => Option.exists(model.maybeMatch, (match) => match.isAutoplay);

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

test("autoplay switches off when only a human move is left, and cannot be switched on", () => {
  let model = send(started(["Human", "Human", "Human", "Human"]), Message.ToggledAutoplay());

  expect(autoplaying(model)).toBe(false);

  model = send(started(["DoN", "Human", "DoN", "DoN"]), Message.ToggledAutoplay());

  for (let ticks = 0; ticks < TICK_LIMIT && autoplaying(model); ticks++) model = send(model, Message.TickedAutoplay());

  expect(pendingKind(model)).toBe("Choose");
  expect(autoplaying(model)).toBe(false);
});

test("a new match starts with autoplay off", () => {
  const model = send(send(started(["DoN", "Story", "DoN", "Story"]), Message.ToggledAutoplay()), Message.ClickedNewMatch());

  expect(autoplaying(model)).toBe(false);
});
