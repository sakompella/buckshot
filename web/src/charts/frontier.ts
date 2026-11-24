/** One point dominates another when it is no further along x and no lower, and better on one of them. */
const dominates = <P extends Ranked>(other: P, point: P) => other.x <= point.x && other.rating >= point.rating && (other.x < point.x || other.rating > point.rating);

interface Ranked {
  readonly x: number;
  readonly rating: number;
}

/** The points no other point dominates, left to right: the best rating available at each cost. */
export const paretoFrontier = <P extends Ranked>(points: ReadonlyArray<P>): ReadonlyArray<P> =>
  points.filter((point) => !points.some((other) => other !== point && dominates(other, point))).toSorted((left, right) => left.x - right.x);
