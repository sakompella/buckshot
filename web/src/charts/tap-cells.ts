// Tap areas for crowded chart points, shared by the arena viewer's scatter and the findings page.

export interface Spot {
  readonly x: number;
  readonly y: number;
}

/** How far from a point a tap or the mouse still picks it: a fingertip's width. */
export const TAP_REACH = 22;

const CELL_SIDES = 24;

/** The part of the convex polygon `cell` nearer `own` than `other`: one Sutherland–Hodgman pass over their bisector. */
const nearerHalf = (cell: ReadonlyArray<Spot>, own: Spot, other: Spot): ReadonlyArray<Spot> => {
  const [dx, dy] = [other.x - own.x, other.y - own.y];
  const [mx, my] = [(own.x + other.x) / 2, (own.y + other.y) / 2];
  const side = ({ x, y }: Spot) => (x - mx) * dx + (y - my) * dy;

  return cell.flatMap((from, index) => {
    const to = cell[(index + 1) % cell.length] ?? from;
    const [a, b] = [side(from), side(to)];
    const kept = a <= 0 ? [from] : [];

    if ((a <= 0) === (b <= 0)) { return kept; }

    const t = a / (a - b);

    return [...kept, { x: from.x + t * (to.x - from.x), y: from.y + t * (to.y - from.y) }];
  });
};

/**
 * Each point's tap area: the places within `reach` of it that are nearer it than any other point, as a polygon. The
 * cells never overlap, so a tap among crowded points picks the nearest one, not the one drawn last.
 */
export const tapCells = (points: ReadonlyArray<Spot>, reach: number): ReadonlyArray<ReadonlyArray<Spot>> =>
  points.map((own, index) => {
    const around: ReadonlyArray<Spot> = Array.from({ length: CELL_SIDES }, (_, step) => ({ x: own.x + reach * Math.cos((2 * Math.PI * step) / CELL_SIDES), y: own.y + reach * Math.sin((2 * Math.PI * step) / CELL_SIDES) }));

    return points.reduce((cell, other, at) => (at === index || (other.x === own.x && other.y === own.y) ? cell : nearerHalf(cell, own, other)), around);
  });

/** A tap cell as an SVG path in whole pixels, empty when it has no area. */
export const cellPath = (cell: ReadonlyArray<Spot>): string => (cell.length < 3 ? "" : `M${cell.map(({ x, y }) => `${Math.round(x)},${Math.round(y)}`).join("L")}Z`);
