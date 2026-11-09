import { expect, test } from "bun:test";
import { Schema } from "effect";

import rules, { type BendNode } from "../generated/rules.mjs";
import { INSTRUCTIONS } from "../src/arena/match.ts";
import { Item } from "../src/domain.ts";

interface Cell extends BendNode {
  readonly head?: BendNode;
  readonly tail?: Cell;
}

const tags = (list: Cell): ReadonlyArray<string> => (list.$ === "Con" && list.head !== undefined && list.tail !== undefined ? [list.head.$, ...tags(list.tail)] : []);

test("the item list is Bend's item order", () => {
  expect<ReadonlyArray<string>>(Item.literals).toEqual(tags(rules["domain:item.order"]()));
});

test("the prompt's handsaw damage and phone range are Bend's", () => {
  const draw = Schema.decodeUnknownSync(Schema.Struct({ range: Schema.Struct({ lo: Schema.Number }) }))(rules["sm/items:phone.request"](4));

  expect(INSTRUCTIONS).toContain(`Handsaw: your next shot does ${rules["domain:damage.amount"]({ $: "Double" })} damage instead of ${rules["domain:damage.amount"]({ $: "Single" })}.`);
  expect(INSTRUCTIONS).toContain(`The position is from ${1 + draw.range.lo} to ${rules["domain:phone.cap"]()}.`);
});
