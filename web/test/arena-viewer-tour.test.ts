import { expect, test } from "bun:test";

import { GROUPS, MOVED_TARGETS, Section } from "../src/arena-viewer/page/model.ts";
import { TOUR } from "../src/arena-viewer/page/tour.ts";

const pageOrder: ReadonlyArray<string> = GROUPS.flatMap(({ sections }) => sections);

test("every section sits in exactly one group", () => {
  expect(pageOrder.toSorted()).toEqual([...Section.literals].toSorted());
});

test("every group or section an old link names lands on the page, directly or at the section that took its place", () => {
  const linked = ["results", "watch", "decisions", "rounds", "reliability", "details", "scatter", "interesting", "luck", "seats", "deals", "blunders", "mistakes", "odds", "items", "pressure", "rubbers", "matches", "leaderboards", "breakdown"];
  const onPage = new Set([...GROUPS.map(({ group }) => group), ...pageOrder]);

  expect(linked.filter((id) => !onPage.has(id) && !onPage.has(MOVED_TARGETS.get(id) ?? ""))).toEqual([]);
  expect([...MOVED_TARGETS.keys()].filter((id) => onPage.has(id))).toEqual([]);
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
