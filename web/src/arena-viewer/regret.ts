import { Database } from "bun:sqlite";

import { Schema } from "effect";

import { gameAccuracy, judgementOf, NO_CHOICE_POINTS, type ScoredMove } from "./accuracy.ts";
import type { MoveRegret, SeatRegret } from "./api.ts";

// The regret table of the derived database that tools/arena builds (docs/arena/analysis/regret.md), read only. The
// table can hold runs with several evaluators, depth limits, budgets, reload rules or sample counts; scores of different
// runs never mix, so the viewer reads the run with the most searched moves. Scores are millionths of the round win chance, shown as points.
// A second database can hold a sampled-reload run of the decisions with few shells left: its rows replace the static run's for the same decision.

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

const RunRow = Schema.NullOr(Schema.Struct({ evaluator: Schema.String, depth: Schema.Number, budget: Schema.Number, reload: Schema.String, samples: Schema.Number }));

const decodeRun = Schema.decodeUnknownSync(RunRow);

const decodeSeatMove = Schema.decodeUnknownSync(SeatMoveRow);

export type Source = MoveRegret["source"];

export interface Regret {
  readonly seats: ReadonlyMap<string, SeatRegret>;
  readonly moves: (matchId: string) => Map<number, MoveRegret>;
}

interface Scores {
  readonly moves: (matchId: string) => Map<number, MoveRow>;
  readonly seatMoves: () => Map<string, SeatMoveRow>;
}

type SeatMoveRow = typeof SeatMoveRow.Type;

const openScores = (path: string): Scores => {
  const db = new Database(path, { readonly: true });

  const run = decodeRun(
    db.query(`select evaluator, max_depth depth, budget, reload, samples from regret where status = 'searched' group by evaluator, max_depth, budget, reload, samples order by count(*) desc limit 1`).get(),
  );

  const inRun = [run?.evaluator ?? null, run?.depth ?? null, run?.budget ?? null, run?.reload ?? null, run?.samples ?? null];

  const seatMoves = db.query(
    `select match_id matchId, player, ordinal, regret, best_score best, chosen_score chosen,
            (select max(json_extract(value, '$.score')) - min(json_extract(value, '$.score')) from json_each(values_json)) spread
     from regret where status = 'searched' and evaluator is ? and max_depth is ? and budget is ? and reload is ? and samples is ?`,
  );

  const matchMoves = db.query(
    `select ${MOVE_COLUMNS} from regret
     where match_id = ? and status = 'searched' and evaluator is ? and max_depth is ? and budget is ? and reload is ? and samples is ?`,
  );

  return {
    moves: (matchId) => new Map(matchMoves.all(matchId, ...inRun).map((raw) => {
      const row = consistent(decodeMoveRow(raw));

      return [row.ordinal, row];
    })),
    seatMoves: () => new Map(seatMoves.all(...inRun).map((raw) => {
      const row = decodeSeatMove(raw);

      return [`${row.matchId}|${row.ordinal}`, row];
    })),
  };
};

const roundedTenth = (points: number): number => Math.round(points * 10) / 10;

/**
 * A seat's statistics over its searched moves, in order. Decisions whose moves all score within NO_CHOICE_POINTS have no
 * real choice and are left out. A move's loss is its regret; losses are kept to a tenth of a point, nonzero ones only.
 */
const seatRegretOf = (moves: ReadonlyArray<{ readonly row: SeatMoveRow; readonly source: Source }>): SeatRegret | null => {
  const real = moves.filter(({ row }) => row.spread > NO_CHOICE_POINTS * POINT);
  const losses = real.map(({ row }) => row.regret / POINT);
  const accuracy = gameAccuracy(real.map(({ row }): ScoredMove => ({ before: row.best / POINT, after: row.chosen / POINT })));
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
        sampled: real.filter(({ source }) => source === "sampled").length,
        losses: losses.map(roundedTenth).filter((loss) => loss > 0),
      };
};

const moveOf = (row: MoveRow, source: Source): MoveRegret => ({
  points: row.regret / POINT,
  exact: row.exact === 1,
  best: row.best,
  bestScore: row.bestScore / POINT,
  chosen: row.label,
  chosenScore: row.chosenScore / POINT,
  depth: row.depth,
  limited: row.limited === 1,
  values: row.values.map(({ label, score }) => ({ label, score: score / POINT })),
  source,
});

/** The static run's scores, with the sampled run's in place of them for every decision it scored. */
export const openRegret = (staticPath: string, sampledPath?: string): Regret => {
  const base = openScores(staticPath);
  const sampled = sampledPath === undefined ? null : openScores(sampledPath);

  const seatRows = base.seatMoves();
  const sampledRows = sampled?.seatMoves() ?? new Map<string, SeatMoveRow>();
  const bySeat = new Map<string, Array<{ readonly row: SeatMoveRow; readonly source: Source }>>();

  for (const [key, row] of new Map([...seatRows, ...sampledRows])) {
    const seat = `${row.matchId}|${row.player}`;
    const list = bySeat.get(seat) ?? [];

    list.push({ row, source: sampledRows.has(key) ? "sampled" : "static" });
    bySeat.set(seat, list);
  }

  return {
    seats: new Map(
      [...bySeat].flatMap(([seat, moves]) => {
        const regret = seatRegretOf(moves.toSorted((left, right) => left.row.ordinal - right.row.ordinal));

        return regret === null ? [] : [[seat, regret] as const];
      }),
    ),
    moves: (matchId) => {
      const merged = new Map<number, MoveRegret>([...base.moves(matchId)].map(([ordinal, row]) => [ordinal, moveOf(row, "static")]));

      for (const [ordinal, row] of sampled?.moves(matchId) ?? []) merged.set(ordinal, moveOf(row, "sampled"));

      return merged;
    },
  };
};
