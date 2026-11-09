import { Database } from "bun:sqlite";

import { Schema } from "effect";

import { gameAccuracy, judgementOf, NO_CHOICE_POINTS, type ScoredMove } from "./accuracy.ts";
import type { MoveRegret, SeatRegret } from "./api.ts";

// The regret table of the derived database that tools/arena builds (docs/arena/analysis/regret.md), read only. A regret
// file holds one run (evaluator, depth limit, budget, reload rule, samples); a file with several is refused. Scores are
// millionths of the round win chance, shown as points.

const POINT = 10_000;

const SeatMoveRow = Schema.Struct({ matchId: Schema.String, player: Schema.String, ordinal: Schema.Number, regret: Schema.Number, best: Schema.Number, chosen: Schema.Number, spread: Schema.Number });

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

const Run = Schema.Struct({ evaluator: Schema.String, depth: Schema.Number, budget: Schema.Number, reload: Schema.String, samples: Schema.Number });

const decodeRuns = Schema.decodeUnknownSync(Schema.Array(Run));

const decodeSeatMove = Schema.decodeUnknownSync(SeatMoveRow);

export interface Regret {
  readonly seats: ReadonlyMap<string, SeatRegret>;
  readonly moves: (matchId: string) => Map<number, MoveRegret>;
}

type SeatMoveRow = typeof SeatMoveRow.Type;

const roundedTenth = (points: number): number => Math.round(points * 10) / 10;

/**
 * A seat's statistics over its searched moves, in order. Decisions whose moves all score within NO_CHOICE_POINTS have no
 * real choice and are left out. A move's loss is its regret; losses are kept to a tenth of a point, nonzero ones only.
 */
const seatRegretOf = (moves: ReadonlyArray<SeatMoveRow>): SeatRegret | null => {
  const real = moves.filter((row) => row.spread > NO_CHOICE_POINTS * POINT);
  const losses = real.map((row) => row.regret / POINT);
  const accuracy = gameAccuracy(real.map((row): ScoredMove => ({ before: row.best / POINT, after: row.chosen / POINT })));
  const countOf = (judgement: ReturnType<typeof judgementOf>) => losses.filter((loss) => judgementOf(loss) === judgement).length;

  return accuracy === null
    ? null
    : {
        moves: real.length,
        total: losses.reduce((sum, loss) => sum + loss, 0),
        accuracy,
        best: countOf("best"),
        inaccuracies: countOf("inaccuracy"),
        mistakes: countOf("mistake"),
        blunders: countOf("blunder"),
        losses: losses.flatMap((loss) => (roundedTenth(loss) > 0 ? [roundedTenth(loss)] : [])),
      };
};

const moveOf = (row: MoveRow): MoveRegret => ({
  points: row.regret / POINT,
  exact: row.exact === 1,
  best: row.best,
  bestScore: row.bestScore / POINT,
  chosen: row.label,
  chosenScore: row.chosenScore / POINT,
  depth: row.depth,
  limited: row.limited === 1,
  values: row.values.map(({ label, score }) => ({ label, score: score / POINT })),
});

/** The scores of the file's one run. */
export const openRegret = (path: string): Regret => {
  const db = new Database(path, { readonly: true });
  const runs = decodeRuns(db.query(`select distinct evaluator, max_depth depth, budget, reload, samples from regret`).all());

  if (runs.length > 1) throw new Error(`${path} holds ${runs.length} regret runs, not one: ${JSON.stringify(runs)}`);

  const seatMoves = db.query(
    `select match_id matchId, player, ordinal, regret, best_score best, chosen_score chosen,
            (select max(json_extract(value, '$.score')) - min(json_extract(value, '$.score')) from json_each(values_json)) spread
     from regret where status = 'searched' order by match_id, player, ordinal`,
  );

  const matchMoves = db.query(`select ${MOVE_COLUMNS} from regret where match_id = ? and status = 'searched'`);
  const bySeat = new Map<string, Array<SeatMoveRow>>();

  for (const raw of seatMoves.all()) {
    const row = decodeSeatMove(raw);
    const seat = `${row.matchId}|${row.player}`;
    const list = bySeat.get(seat) ?? [];

    list.push(row);
    bySeat.set(seat, list);
  }

  return {
    seats: new Map(
      [...bySeat].flatMap(([seat, moves]) => {
        const regret = seatRegretOf(moves);

        return regret === null ? [] : [[seat, regret] as const];
      }),
    ),
    moves: (matchId) => new Map(matchMoves.all(matchId).map((raw) => {
      const row = consistent(decodeMoveRow(raw));

      return [row.ordinal, moveOf(row)];
    })),
  };
};
