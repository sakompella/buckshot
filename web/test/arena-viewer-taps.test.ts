import * as hegel from "@hegeldev/hegel";
import * as gs from "@hegeldev/hegel/generators";
import { expect, test } from "bun:test";

import { TAP_REACH, tapCells } from "../src/arena-viewer/page/scatter.ts";

interface Point {
  readonly x: number;
  readonly y: number;
}

const isInside = (cell: ReadonlyArray<Point>, point: Point): boolean => {
  const sides = cell.map((from, index) => {
    const to = cell[(index + 1) % cell.length] ?? from;

    return (to.x - from.x) * (point.y - from.y) - (to.y - from.y) * (point.x - from.x);
  });

  return cell.length >= 3 && (sides.every((side) => side >= 0) || sides.every((side) => side <= 0));
};

const distance = (a: Point, b: Point): number => Math.hypot(a.x - b.x, a.y - b.y);

test("a tap lands in the cell of the nearest point within reach, and in no other cell", () =>
  hegel.test(
    (tc) => {
      const position = gs.tuples(gs.integers({ minValue: 0, maxValue: 3000 }), gs.integers({ minValue: 0, maxValue: 2000 })).map(([x, y]): Point => ({ x: x / 10, y: y / 10 }));
      const points = tc.draw(gs.arrays(position, { minSize: 1, maxSize: 40, unique: true }));
      const cells = tapCells(points, TAP_REACH);
      const at = tc.draw(position);
      const [nearest, runnerUp] = points.map((from, index) => ({ index, gap: distance(from, at) })).toSorted((left, right) => left.gap - right.gap);
      const inside = cells.flatMap((cell, index) => (isInside(cell, at) ? [index] : []));

      if (nearest === undefined) return expect.unreachable("there is at least one point");

      // Ties and the edge of reach are left out: either answer is right there.
      tc.assume(Math.abs(nearest.gap - TAP_REACH) >= 1 && (runnerUp === undefined || runnerUp.gap - nearest.gap >= 0.01));

      // Cells are polygons inside the reach circle, so between 0.98 and 1 times the reach a tap may miss its point's cell but never lands in another's.
      if (nearest.gap < TAP_REACH * 0.98) expect(inside).toEqual([nearest.index]);
      else if (nearest.gap > TAP_REACH) expect(inside).toEqual([]);
      else expect(inside.every((index) => index === nearest.index)).toBe(true);
    },
    { testCases: 500 },
  ));
