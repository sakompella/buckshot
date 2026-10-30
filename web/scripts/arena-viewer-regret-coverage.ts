export interface RegretCoverage {
  readonly searched: number;
  readonly tagged: number;
  readonly rings: number;
  readonly turning: number;
}

export interface Decision {
  readonly byWhom: string;
  readonly regret: { readonly points: number } | null;
}

// The viewer's thresholds, written out again so that changing them in the viewer fails the check instead of moving both sides.
const TAG_FROM = 2;
const RING_FROM = 5;
const MOST_TURNING_POINTS = 3;

export const regretCoverageOf = (decisions: ReadonlyArray<Decision>): RegretCoverage => {
  const points = decisions.filter(({ byWhom }) => byWhom !== "forced").flatMap(({ regret }) => (regret === null ? [] : [regret.points]));
  const rings = points.filter((point) => point >= RING_FROM).length;

  return { searched: points.length, tagged: points.filter((point) => point >= TAG_FROM).length, rings, turning: Math.min(rings, MOST_TURNING_POINTS) };
};

/** The coverage of the match a replay shows, read from that match's own data by its id, not from whatever response the page last got. */
export const coverageOfMatch = async (matchId: string, decisionsOf: (matchId: string) => Promise<ReadonlyArray<Decision>>): Promise<RegretCoverage> => regretCoverageOf(await decisionsOf(matchId));
