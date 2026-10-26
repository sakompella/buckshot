import { Database } from "bun:sqlite";

import { Schema } from "effect";

import type { MoveRegret, SeatRegret } from "./api.ts";

// The regret table of the derived database that tools/arena builds (docs/arena/analysis/regret.md), read only. The
// table can hold runs with several evaluators, depth limits, budgets or reload rules; scores of different runs never mix, so the
// viewer reads the run with the most searched moves. Scores are millionths of the round win chance, shown as points.

const POINT = 10_000;

const SeatTotalRow = Schema.Struct({ matchId: Schema.String, player: Schema.String, moves: Schema.Number, total: Schema.Number, exact: Schema.Number });

const MoveRow = Schema.Struct({
  ordinal: Schema.Number,
  regret: Schema.Number,
  exact: Schema.Number,
  best: Schema.String,
  bestScore: Schema.Number,
  chosenScore: Schema.Number,
  depth: Schema.Number,
  limited: Schema.Number,
});

const RunRow = Schema.NullOr(Schema.Struct({ evaluator: Schema.String, depth: Schema.Number, budget: Schema.Number, reload: Schema.String }));

const decodeRun = Schema.decodeUnknownSync(RunRow);

const decodeSeatTotal = Schema.decodeUnknownSync(SeatTotalRow);

const decodeMove = Schema.decodeUnknownSync(MoveRow);

export interface Regret {
  /** Searched moves per seat, keyed by `${matchId}|${player}`. */
  readonly seats: ReadonlyMap<string, SeatRegret>;
  /** One match's searched moves, keyed by the decision's ordinal. */
  readonly moves: (matchId: string) => Map<number, MoveRegret>;
}

export const openRegret = (path: string): Regret => {
  const db = new Database(path, { readonly: true });

  const run = decodeRun(
    db.query(`select evaluator, max_depth depth, budget, reload from regret where status = 'searched' group by evaluator, max_depth, budget, reload order by count(*) desc limit 1`).get(),
  );

  const inRun = [run?.evaluator ?? null, run?.depth ?? null, run?.budget ?? null, run?.reload ?? null];

  const seatTotals = db.query(
    `select match_id matchId, player, count(*) moves, sum(regret) total, sum(exact) exact from regret
     where status = 'searched' and evaluator is ? and max_depth is ? and budget is ? and reload is ? group by match_id, player`,
  );

  const matchMoves = db.query(
    `select ordinal, regret, exact, best, best_score bestScore, chosen_score chosenScore, depth, limited from regret
     where match_id = ? and status = 'searched' and evaluator is ? and max_depth is ? and budget is ? and reload is ?`,
  );

  return {
    seats: new Map(
      seatTotals.all(...inRun).map((raw) => {
        const row = decodeSeatTotal(raw);

        return [`${row.matchId}|${row.player}`, { moves: row.moves, total: row.total / POINT, exact: row.exact }];
      }),
    ),
    moves: (matchId) =>
      new Map(
        matchMoves.all(matchId, ...inRun).map((raw) => {
          const row = decodeMove(raw);

          return [row.ordinal, { points: row.regret / POINT, exact: row.exact === 1, best: row.best, bestScore: row.bestScore / POINT, chosenScore: row.chosenScore / POINT, depth: row.depth, limited: row.limited === 1 }];
        }),
      ),
  };
};
