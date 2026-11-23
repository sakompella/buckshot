import { expect, test } from "bun:test";

import { Predicate } from "effect";
import { AsyncData, Scene } from "foldkit";
import type { Html } from "foldkit/html";
import { modifyFields } from "foldkit/struct";

import { configSummaries, pairsOf } from "../src/arena-viewer/aggregates.ts";
import { splitKey, withPotShares } from "../src/arena-viewer/page/data.ts";
import { LUCK_ELO } from "../src/arena-viewer/page/derived.ts";
import { Message } from "../src/arena-viewer/page/model.ts";
import type { Loaded } from "../src/arena-viewer/page/model.ts";
import { ANCHOR } from "../src/arena-viewer/page/ratings.ts";
import { SiteRoute } from "../src/site/route.ts";
import { SEAT } from "./fixtures.ts";

// The page's views rendered from small aggregates, read back as text; and the update's fetching of what a group needs.

// The page's subscriptions name `window` when the module loads; bun has the global object under another name.
Object.assign(globalThis, { window: globalThis });

const { init, update } = await import("../src/arena-viewer/page/main.ts");
const { view } = await import("../src/arena-viewer/page/view.ts");

const oneRound = (winner: string) => ({ starter: "A", ok: true, rounds: [{ winner, prize: 1 }] });

/** "strong" against the depth-7 engine over 40 seed blocks, winning 30, with a zero luck correction on every seat. */
const seats = withPotShares(
  Array.from({ length: 40 }, (_match, index) => {
    const winner = index < 30 ? "A" : "B";

    return [
      { ...SEAT, matchId: `m${index}`, seedBlock: `block${index}`, model: "strong", player: "A", position: 0, winShare: winner === "A" ? 1 : 0, cash: winner === "A" ? 1 : 0, story: oneRound(winner) },
      { ...SEAT, matchId: `m${index}`, seedBlock: `block${index}`, model: splitKey(ANCHOR)[0], effort: "", player: "B", position: 1, winShare: winner === "B" ? 1 : 0, cash: winner === "B" ? 1 : 0, story: oneRound(winner) },
    ];
  }).flat(),
);

const luck = new Map(seats.map(({ matchId, player }) => [`${matchId}|${player}`, 0]));

const loaded: Loaded = {
  summary: { configs: configSummaries(seats, { seat: [], legalUse: [], useItem: [] }, luck), hasCertain: false, seedBlocks: { blocks: 40, unpaired: 0 } },
  pairs: pairsOf(seats),
};

/** Every text node under a view, in order. */
const textOf = (html: Html): string => {
  if (html === null) { return ""; }

  return [html.text ?? "", ...(html.children ?? []).map((child) => (Predicate.isString(child) ? child : textOf(child)))].join("");
};

/** The whole page's text once the aggregates are in and the first paint is done. */
const pageText = (): string => {
  const start = init({ width: 1280, height: 800 }, SiteRoute.Arena({})).model;
  const painted = modifyFields(update(start, Message.SucceededLoad({ loaded })).model, { isFirstPaintDone: () => true });
  let text = "";

  Scene.scene(
    { update, view: (model, h) => view(model, h).body },
    Scene.given(painted),
    Scene.tap(({ html }) => {
      text = textOf(html);
    }),
  );

  return text;
};

test("the page names the headline rating in the win-share table, and gives the record against the engine with no claim the two cannot be told apart", () => {
  const text = pageText();

  expect(text).toContain(`${LUCK_ELO}$/match`);
  expect(text).toContain("won 30 of 40 rounds (75.0%");
  expect(text).not.toContain("cannot be told apart");
});

test("coming near a group fetches each aggregate it needs once", () => {
  const { model } = init({ width: 1280, height: 800 }, SiteRoute.Arena({}));
  const near = update(model, Message.CameNear({ groups: ["decisions"] }));
  const again = update(near.model, Message.CameNear({ groups: ["decisions"] }));

  expect([AsyncData.isLoading(near.model.lazy.certain), AsyncData.isLoading(near.model.lazy.odds), AsyncData.isLoading(near.model.lazy.items)]).toEqual([true, true, true]);
  expect(near.model.lazy.consistency).toEqual(AsyncData.Idle());
  expect(near.commands).toHaveLength(3);
  expect(again.commands ?? []).toHaveLength(0);
});
