import { Database } from "bun:sqlite";

import { Schema } from "effect";

import { CERTAIN_TYPES, type CertainMistakes, CertainType, OpportunityType } from "./api.ts";

const RateRow = Schema.Struct({
  scope: Schema.Literals(["config", "model", "all"]),
  model: Schema.String,
  effort: Schema.String,
  type: OpportunityType,
  chose: Schema.Number,
  opportunities: Schema.Number,
  lo: Schema.NullOr(Schema.Number),
  hi: Schema.NullOr(Schema.Number),
});

const MistakeRow = Schema.Struct({ matchId: Schema.String, ordinal: Schema.Number, player: Schema.String, type: CertainType });

const decodeRate = Schema.decodeUnknownSync(RateRow);

const decodeMistake = Schema.decodeUnknownSync(MistakeRow);

export interface Certain {
  readonly summary: CertainMistakes;
  readonly moves: (matchId: string) => ReadonlyMap<number, CertainType>;
}

export const NO_CERTAIN: Certain = { summary: { rates: [], moveSeat: [], moveType: [], moveOrd: [] }, moves: () => new Map() };

export const openCertain = (path: string, seatIndex: ReadonlyMap<string, number>): Certain => {
  const db = new Database(path, { readonly: true });

  const rates = db
    .query(`select scope, model, effort, type, chose, opportunities, lo, hi from rates order by scope, model, effort, type`)
    .all()
    .map((raw) => {
      const { lo, hi, ...rate } = decodeRate(raw);

      return { ...rate, bounds: lo === null || hi === null ? null : { lo, hi } };
    });

  const mistakes = db
    .query(`select match_id matchId, ordinal, player, type from opportunities where outcome = 'mistake' order by match_id, ordinal`)
    .all()
    .flatMap((raw) => {
      const row = decodeMistake(raw);
      const seat = seatIndex.get(`${row.matchId}|${row.player}`);

      return seat === undefined ? [] : [{ ...row, seat }];
    });

  db.close();

  const byMatch = new Map<string, Map<number, CertainType>>();

  for (const { matchId, ordinal, type } of mistakes) byMatch.set(matchId, (byMatch.get(matchId) ?? new Map()).set(ordinal, type));

  return {
    summary: {
      rates,
      moveSeat: mistakes.map(({ seat }) => seat),
      moveType: mistakes.map(({ type }) => CERTAIN_TYPES.indexOf(type)),
      moveOrd: mistakes.map(({ ordinal }) => ordinal),
    },
    moves: (matchId) => byMatch.get(matchId) ?? new Map(),
  };
};
