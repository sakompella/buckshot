import type { Decisions, Mistakes, MoveRegret } from "./api.ts";

/**
 * Joins each agent move's shells left with its regret. A move with no searched regret is left out, not counted as zero.
 * matchOf gives the match of a seat by its place in the seats response.
 */
export const mistakesOf = (
  decisions: Pick<Decisions, "seat" | "ord" | "shot">,
  shellsLeft: ReadonlyArray<number>,
  matchOf: (seat: number) => string,
  regretOf: (matchId: string) => ReadonlyMap<number, Pick<MoveRegret, "points">>,
): Mistakes => {
  const columns = { seat: new Array<number>(), left: new Array<number>(), isShot: new Array<number>(), points: new Array<number>() };
  const byMatch = new Map<string, ReadonlyMap<number, Pick<MoveRegret, "points">>>();

  decisions.seat.forEach((seat, move) => {
    const matchId = matchOf(seat);

    const moves = byMatch.get(matchId) ?? regretOf(matchId);

    byMatch.set(matchId, moves);

    const regret = moves.get(decisions.ord[move] ?? -1);

    if (regret === undefined) return;

    columns.seat.push(seat);
    columns.left.push(shellsLeft[move] ?? 0);
    columns.isShot.push((decisions.shot[move] ?? 0) > 0 ? 1 : 0);
    columns.points.push(Math.round(regret.points * 100) / 100);
  });

  return columns;
};
