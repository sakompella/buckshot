import type { Database } from "bun:sqlite";

import { Schema } from "effect";

import { BLUNDER_POINTS, type Blunders } from "./api.ts";
import type { Regret } from "./regret.ts";

// The server's blunder list: every searched move that gave up BLUNDER_POINTS or more, found by asking the regret
// database for each match and the analysis database for the label of the move taken.

const LabelRow = Schema.Struct({ ordinal: Schema.Number, player: Schema.String, label: Schema.String });

const decodeLabel = Schema.decodeUnknownSync(LabelRow);

interface Found {
  readonly seat: number;
  readonly ordinal: number;
  readonly chosen: string;
  readonly points: number;
  readonly isExact: boolean;
  readonly best: string;
  readonly bestScore: number;
  readonly chosenScore: number;
}

export const findBlunders = (db: Database, regret: Regret | null, seatIndex: ReadonlyMap<string, number>): Blunders => {
  const matchIds = regret === null ? [] : [...new Set([...seatIndex.keys()].map((key) => key.split("|")[0] ?? ""))];
  const labelOf = db.query(`select ordinal, player, label from decisions where match_id = ?`);

  const found = matchIds.flatMap((matchId): ReadonlyArray<Found> => {
    const blunders = [...(regret?.moves(matchId) ?? [])].filter(([, move]) => move.points >= BLUNDER_POINTS);

    if (blunders.length === 0) return [];

    const decisions = new Map(labelOf.all(matchId).map((raw) => decodeLabel(raw)).map((row) => [row.ordinal, row]));

    return blunders.flatMap(([ordinal, move]) => {
      const decision = decisions.get(ordinal);
      const seat = decision === undefined ? undefined : seatIndex.get(`${matchId}|${decision.player}`);

      return decision === undefined || seat === undefined
        ? []
        : [{ seat, ordinal, chosen: decision.label, points: move.points, isExact: move.exact, best: move.best, bestScore: move.bestScore, chosenScore: move.chosenScore }];
    });
  });

  const labels = [...new Set(found.flatMap(({ chosen, best }) => [chosen, best]))];

  return {
    labels,
    seat: found.map(({ seat }) => seat),
    ord: found.map(({ ordinal }) => ordinal),
    points: found.map(({ points }) => points),
    exact: found.map(({ isExact }) => (isExact ? 1 : 0)),
    chosen: found.map(({ chosen }) => labels.indexOf(chosen)),
    best: found.map(({ best }) => labels.indexOf(best)),
    bestScore: found.map(({ bestScore }) => bestScore),
    chosenScore: found.map(({ chosenScore }) => chosenScore),
  };
};
