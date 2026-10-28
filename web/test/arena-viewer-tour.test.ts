import { expect, test } from "bun:test";

import { SECTIONS } from "../src/arena-viewer/page/model.ts";
import { TOUR } from "../src/arena-viewer/page/tour.ts";

const pageOrder = SECTIONS.map(([section]) => section);

test("the tour visits every section, in page order", () => {
  const anchors = TOUR.map(({ anchor }) => pageOrder.indexOf(anchor));

  expect(anchors.every((index) => index >= 0)).toBe(true);
  expect(anchors).toEqual(anchors.toSorted((left, right) => left - right));
  expect(new Set(anchors).size).toBe(pageOrder.length);
});

// Figures in the cards would go stale as the data grows; naming round 1 or table position 2 is fine.
test("each card is one or two sentences, with no figures", () => {
  for (const { title, text } of TOUR) {
    const sentences = text.split(/[.!?](?:\s|$)/).filter((sentence) => sentence.trim() !== "");

    expect([title, sentences.length <= 2]).toEqual([title, true]);
    expect(`${title} ${text}`.replaceAll(/(?:round|position) \d\b/g, "")).not.toMatch(/\d/);
  }
});
