import { expect, test } from "bun:test";

import { GROUPS, MOVED_TARGETS, Section } from "../src/arena-viewer/page/model.ts";
import { Option } from "effect";

import { tourMatchOf, tourOf } from "../src/arena-viewer/page/tour.ts";

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

test("the tour visits every section, in page order, and the certain-mistakes one only with its database", () => {
  const anchors = tourOf(true).map(({ anchor }) => pageOrder.indexOf(anchor));

  expect(anchors.every((index) => index >= 0)).toBe(true);
  expect(anchors).toEqual(anchors.toSorted((left, right) => left - right));
  expect(new Set(anchors).size).toBe(pageOrder.length);
  expect(tourOf(false).map(({ anchor }) => anchor)).toEqual(tourOf(true).map(({ anchor }) => anchor).filter((anchor) => anchor !== "certain-mistakes"));
  expect(tourOf(false).some(({ title, text }) => /certain/i.test(`${title} ${text}`))).toBe(false);
});

test("each card is one or two sentences, with no figures", () => {
  for (const { title, text } of [...tourOf(true), ...tourOf(false)]) {
    const sentences = text.split(/[.!?](?:\s|$)/).filter((sentence) => sentence.trim() !== "");

    expect([title, sentences.length <= 2]).toEqual([title, true]);
    expect(`${title} ${text}`.replaceAll(/(?:round|position) \d\b/g, "")).not.toMatch(/\d/);
  }
});

test("the tour's replay is the completed match whose seats gave up the most points", () => {
  const seat = (matchId: string, status: "completed" | "partial", total: number | null) => ({ matchId, status, regret: total === null ? null : { moves: 1, total, exact: 0 } });

  expect(tourMatchOf([seat("a", "completed", 5), seat("a", "completed", 6), seat("b", "completed", 9), seat("c", "partial", 99)])).toEqual(Option.some("a"));
  expect(tourMatchOf([seat("a", "completed", null)])).toEqual(Option.some("a"));
  expect(tourMatchOf([])).toEqual(Option.none());
});

test("only the replay steps of the tour open a replay", () => {
  expect(tourOf(true).filter(({ isReplay }) => isReplay).map(({ anchor }) => anchor)).toEqual(["matches", "matches"]);
});
