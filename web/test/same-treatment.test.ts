import { expect, test } from "bun:test";

import { configOf } from "../src/arena/same-treatment.ts";

test("a same-treatment label counts as its group's config, and any other label as itself", () => {
  expect(configOf("claude-opus-5-5-off")).toEqual({ model: "claude-opus-5-5", effort: "off/low" });
  expect(configOf("claude-opus-5-5-low")).toEqual({ model: "claude-opus-5-5", effort: "off/low" });
  expect(configOf("claude-opus-5-5-medium")).toEqual({ model: "claude-opus-5-5", effort: "medium" });
  expect(configOf("Engine/2/20000")).toEqual({ model: "Engine/2/20000", effort: "" });
});
