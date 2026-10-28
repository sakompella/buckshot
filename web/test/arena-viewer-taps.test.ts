import { expect, test } from "bun:test";

import { rng } from "../src/arena-viewer/page/data.ts";
import { TAP_REACH, tapCells } from "../src/arena-viewer/page/scatter.ts";

interface Point {
  readonly x: number;
  readonly y: number;
}

/** Whether `point` is inside the convex polygon `cell`: on the same side of every edge. */
const isInside = (cell: ReadonlyArray<Point>, point: Point): boolean => {
  const sides = cell.map((from, index) => {
    const to = cell[(index + 1) % cell.length] ?? from;

    return (to.x - from.x) * (point.y - from.y) - (to.y - from.y) * (point.x - from.x);
  });

  return cell.length >= 3 && (sides.every((side) => side >= 0) || sides.every((side) => side <= 0));
};

const distance = (a: Point, b: Point): number => Math.hypot(a.x - b.x, a.y - b.y);

// A tap picks the nearest point within reach, and no point beyond it: the cells never overlap.
test("a tap lands in the cell of the nearest point within reach, and in no other cell", () => {
  const random = rng(7);

  for (let trial = 0; trial < 300; trial++) {
    const points = Array.from({ length: 1 + Math.floor(random() * 40) }, () => ({ x: random() * 300, y: random() * 200 }));
    const cells = tapCells(points, TAP_REACH);

    for (let tap = 0; tap < 20; tap++) {
      const at = { x: random() * 300, y: random() * 200 };
      const [nearest, runnerUp] = points.map((point, index) => ({ index, gap: distance(point, at) })).toSorted((left, right) => left.gap - right.gap);
      const inside = cells.flatMap((cell, index) => (isInside(cell, at) ? [index] : []));

      // Ties and the edge of reach are left out: either answer is right there.
      if (nearest === undefined || Math.abs(nearest.gap - TAP_REACH) < 1 || (runnerUp !== undefined && runnerUp.gap - nearest.gap < 0.01)) continue;

      expect(inside).toEqual(nearest.gap < TAP_REACH * 0.98 ? [nearest.index] : nearest.gap > TAP_REACH ? [] : inside);
    }
  }
});
