import { expect, test } from "bun:test";

import { GROUPS, Section } from "../src/arena-viewer/page/model.ts";
import { TOUR } from "../src/arena-viewer/page/tour.ts";

const pageOrder: ReadonlyArray<string> = GROUPS.flatMap(({ sections }) => sections);

test("every section sits in exactly one group", () => {
  expect(pageOrder.toSorted()).toEqual([...Section.literals].toSorted());
});

test("every section an old link names is still on the page", () => {
  const linked = ["scatter", "interesting", "luck", "seats", "deals", "blunders", "mistakes", "odds", "items", "pressure", "rubbers", "reliability", "matches", "leaderboards", "breakdown"];

  expect(linked.filter((section) => !pageOrder.includes(section))).toEqual([]);
});

test("the tour visits every section, in page order", () => {
  const anchors = TOUR.map(({ anchor }) => pageOrder.indexOf(anchor));

  expect(anchors.every((index) => index >= 0)).toBe(true);
  expect(anchors).toEqual(anchors.toSorted((left, right) => left - right));
  expect(new Set(anchors).size).toBe(pageOrder.length);
});

test("each card is one or two sentences, with no figures", () => {
  for (const { title, text } of TOUR) {
    const sentences = text.split(/[.!?](?:\s|$)/).filter((sentence) => sentence.trim() !== "");

    expect([title, sentences.length <= 2]).toEqual([title, true]);
    expect(`${title} ${text}`.replaceAll(/(?:round|position) \d\b/g, "")).not.toMatch(/\d/);
  }
});
