import { Database } from "bun:sqlite";

import { Schema } from "effect";

import { CERTAIN_TYPES, type CertainMistakes, CertainType, OPPORTUNITY_TYPES } from "./api.ts";

// The certain-mistake opportunities of the derived database that tools/arena/analysis/certain_mistakes.py writes
// (docs/arena/analysis/certain-mistakes.md), read only. The classification is that script's; this only tallies its rows.

const TallyRow = Schema.Struct({ matchId: Schema.String, player: Schema.String, type: Schema.Literals(OPPORTUNITY_TYPES), opportunities: Schema.Number, chose: Schema.Number });

const MistakeRow = Schema.Struct({ matchId: Schema.String, ordinal: Schema.Number, player: Schema.String, type: CertainType });

const decodeTally = Schema.decodeUnknownSync(TallyRow);

const decodeMistake = Schema.decodeUnknownSync(MistakeRow);

export interface Certain {
  readonly summary: CertainMistakes;
  /** The certain mistakes of one match, by the ordinal of the decision. */
  readonly moves: (matchId: string) => ReadonlyMap<number, CertainType>;
}

export const NO_CERTAIN: Certain = { summary: { seat: [], type: [], opportunities: [], chose: [], moveSeat: [], moveType: [], moveOrd: [] }, moves: () => new Map() };

/** A row of a match the viewer does not show (partial, DeepSeek) has no seat and is left out. */
export const openCertain = (path: string, seatIndex: ReadonlyMap<string, number>): Certain => {
  const db = new Database(path, { readonly: true });

  const tallies = db
    .query(
      `select match_id matchId, player, type, count(*) opportunities, sum(outcome in ('mistake', 'fact pattern')) chose from opportunities group by match_id, player, type`,
    )
    .all()
    .flatMap((raw) => {
      const row = decodeTally(raw);
      const seat = seatIndex.get(`${row.matchId}|${row.player}`);

      return seat === undefined ? [] : [{ seat, type: OPPORTUNITY_TYPES.indexOf(row.type), opportunities: row.opportunities, chose: row.chose }];
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
      seat: tallies.map(({ seat }) => seat),
      type: tallies.map(({ type }) => type),
      opportunities: tallies.map(({ opportunities }) => opportunities),
      chose: tallies.map(({ chose }) => chose),
      moveSeat: mistakes.map(({ seat }) => seat),
      moveType: mistakes.map(({ type }) => CERTAIN_TYPES.indexOf(type)),
      moveOrd: mistakes.map(({ ordinal }) => ordinal),
    },
    moves: (matchId) => byMatch.get(matchId) ?? new Map(),
  };
};
