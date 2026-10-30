import { BIG_REGRET, MINOR_REGRET, turningPoints } from "../src/arena-viewer/page/replay.ts";

/** What a replay of one match must show of regret, read from the match's own data rather than guessed from the page. */
export interface RegretCoverage {
  /** Moves that carry a regret score; zero when the derived database has no rows for the match. */
  readonly searched: number;
  /** Moves tagged in the move list. */
  readonly tagged: number;
  /** Rings on the health chart. */
  readonly rings: number;
  /** Turning points listed under the chart. */
  readonly turning: number;
}

interface Decision {
  readonly byWhom: string;
  readonly regret: { readonly points: number } | null;
}

/** The replay lists every decision but the forced ones (stepsOf in the page's replay). */
export const regretCoverageOf = (decisions: ReadonlyArray<Decision>): RegretCoverage => {
  const steps = decisions.filter(({ byWhom }) => byWhom !== "forced");
  const points = steps.flatMap(({ regret }) => (regret === null ? [] : [regret.points]));

  return {
    searched: points.length,
    tagged: points.filter((point) => point >= MINOR_REGRET).length,
    rings: points.filter((point) => point >= BIG_REGRET).length,
    turning: turningPoints(steps).length,
  };
};
