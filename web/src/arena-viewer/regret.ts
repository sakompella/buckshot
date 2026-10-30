import { Database } from "bun:sqlite";

import { Schema } from "effect";

import type { MoveRegret, SeatRegret } from "./api.ts";

// The regret table of the derived database that tools/arena builds (docs/arena/analysis/regret.md), read only. The
// table can hold runs with several evaluators, depth limits, budgets, reload rules or sample counts; scores of different
// runs never mix, so the viewer reads the run with the most searched moves. Scores are millionths of the round win chance, shown as points.

const POINT = 10_000;

const SeatTotalRow = Schema.Struct({ matchId: Schema.String, player: Schema.String, moves: Schema.Number, total: Schema.Number, exact: Schema.Number });

const Score = Schema.Int.check(Schema.isBetween({ minimum: 0, maximum: 1_000_000 }));

const Flag = Schema.Literals([0, 1]);

export const MoveRow = Schema.Struct({
  matchId: Schema.String,
  ordinal: Schema.Number,
  label: Schema.String,
  values: Schema.fromJsonString(Schema.Array(Schema.Struct({ label: Schema.String, score: Score }))),
  regret: Schema.Int,
  exact: Flag,
  best: Schema.String,
  bestScore: Score,
  chosenScore: Score,
  depth: Schema.Int.check(Schema.isGreaterThanOrEqualTo(1)),
  limited: Flag,
});

export type MoveRow = typeof MoveRow.Type;

export const MOVE_COLUMNS = `match_id matchId, ordinal, label, values_json "values", regret, exact, best, best_score bestScore, chosen_score chosenScore, depth, limited`;

export const MISMATCHES = ["best score is not the top value", "chosen move has no value", "chosen value is not the chosen score", "regret is not best minus chosen"] as const;

export type Mismatch = (typeof MISMATCHES)[number];

export const mismatchesOf = (row: MoveRow): ReadonlyArray<Mismatch> => {
  const chosen = row.values.find(({ label }) => label === row.label);

  return MISMATCHES.filter((mismatch) => {
    switch (mismatch) {
      case "best score is not the top value":
        return Math.max(...row.values.map(({ score }) => score)) !== row.bestScore;
      case "chosen move has no value":
        return chosen === undefined;
      case "chosen value is not the chosen score":
        return chosen !== undefined && chosen.score !== row.chosenScore;
      case "regret is not best minus chosen":
        return row.regret !== row.bestScore - row.chosenScore;
    }
  });
};

export const decodeMoveRow = Schema.decodeUnknownSync(MoveRow);

const consistent = (row: MoveRow): MoveRow => {
  const mismatches = mismatchesOf(row);

  if (mismatches.length > 0) throw new Error(`regret row ${row.matchId} #${row.ordinal}: ${mismatches.join("; ")}`);

  return row;
};

const RunRow = Schema.NullOr(Schema.Struct({ evaluator: Schema.String, depth: Schema.Number, budget: Schema.Number, reload: Schema.String, samples: Schema.Number }));

const decodeRun = Schema.decodeUnknownSync(RunRow);

const decodeSeatTotal = Schema.decodeUnknownSync(SeatTotalRow);

export interface Regret {
  readonly seats: ReadonlyMap<string, SeatRegret>;
  readonly moves: (matchId: string) => Map<number, MoveRegret>;
}

export const openRegret = (path: string): Regret => {
  const db = new Database(path, { readonly: true });

  const run = decodeRun(
    db.query(`select evaluator, max_depth depth, budget, reload, samples from regret where status = 'searched' group by evaluator, max_depth, budget, reload, samples order by count(*) desc limit 1`).get(),
  );

  const inRun = [run?.evaluator ?? null, run?.depth ?? null, run?.budget ?? null, run?.reload ?? null, run?.samples ?? null];

  const seatTotals = db.query(
    `select match_id matchId, player, count(*) moves, sum(regret) total, sum(exact) exact from regret
     where status = 'searched' and evaluator is ? and max_depth is ? and budget is ? and reload is ? and samples is ? group by match_id, player`,
  );

  const matchMoves = db.query(
    `select ${MOVE_COLUMNS} from regret
     where match_id = ? and status = 'searched' and evaluator is ? and max_depth is ? and budget is ? and reload is ? and samples is ?`,
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
          const row = consistent(decodeMoveRow(raw));

          return [
            row.ordinal,
            {
              points: row.regret / POINT,
              exact: row.exact === 1,
              best: row.best,
              bestScore: row.bestScore / POINT,
              chosen: row.label,
              chosenScore: row.chosenScore / POINT,
              depth: row.depth,
              limited: row.limited === 1,
              values: row.values.map(({ label, score }) => ({ label, score: score / POINT })),
            },
          ];
        }),
      ),
  };
};
