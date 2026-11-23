import { Schema } from "effect";

import { CERTAIN_TYPES, CertainType, OpportunityType } from "./api.ts";
import type { CertainMistakes } from "./api.ts";
import { readOnly } from "./read-only.ts";

const RateRow = Schema.Struct({
  scope: Schema.Literals(["config", "model", "all"]),
  model: Schema.String,
  effort: Schema.String,
  type: OpportunityType,
  chose: Schema.Finite,
  opportunities: Schema.Finite,
  lo: Schema.NullOr(Schema.Finite),
  hi: Schema.NullOr(Schema.Finite),
});

const MistakeRow = Schema.Struct({ matchId: Schema.String, ordinal: Schema.Finite, player: Schema.String, type: CertainType });

const decodeRate = Schema.decodeUnknownSync(RateRow);

const decodeMistake = Schema.decodeUnknownSync(MistakeRow);

export interface Certain {
  readonly summary: CertainMistakes;
  readonly moves: (matchId: string) => ReadonlyMap<number, CertainType>;
}

export const NO_CERTAIN: Certain = { summary: { rates: [], moveSeat: [], moveType: [], moveOrd: [] }, moves: () => new Map() };

const OpportunityRow = Schema.Struct({ matchId: Schema.String, player: Schema.String, type: OpportunityType, outcome: Schema.String });

const decodeOpportunity = Schema.decodeUnknownSync(OpportunityRow);

/** The outcomes that count as choosing a type's move in its rate; none for the excluded type, whose rate counts every decision. */
const CHOSE: Readonly<Record<OpportunityType, string | null>> = { self_on_live: "mistake", gave_up_guaranteed_win: "mistake", gave_turn_away: "fact pattern", hidden_health: null };

/**
 * Why a certain-mistakes file does not fit the scored seats (`completed`, "<match id>|<player>"), empty when it does:
 * every opportunity is a scored seat's, and the pooled rates count exactly its opportunities, so the rates the page shows
 * were worked out from these rows.
 */
export const certainProblems = (path: string, completed: ReadonlySet<string>): ReadonlyArray<string> => {
  const { rows, pooled } = readOnly(path, (db) => ({
    rows: db.query(`select match_id matchId, player, type, outcome from opportunities`).all().map((raw) => decodeOpportunity(raw)),
    pooled: db.query(`select scope, model, effort, type, chose, opportunities, lo, hi from rates where scope = 'all'`).all().map((raw) => decodeRate(raw)),
  }));

  const stale = rows.filter(({ matchId, player }) => !completed.has(`${matchId}|${player}`));

  const mismatched = OpportunityType.literals.flatMap((type) => {
    const own = rows.filter((row) => row.type === type);
    const chose = CHOSE[type];
    const rate = pooled.find((row) => row.type === type) ?? { chose: 0, opportunities: 0 };
    const counted = { chose: chose === null ? rate.chose : own.filter(({ outcome }) => outcome === chose).length, opportunities: own.length };

    return counted.chose === rate.chose && counted.opportunities === rate.opportunities ? [] : [`the certain-mistake rates for ${type} (${rate.chose} of ${rate.opportunities}) are not those of its opportunities (${counted.chose} of ${counted.opportunities})`];
  });

  return [...(stale.length === 0 ? [] : [`${stale.length} certain-mistake opportunities are not on scored seats of this database, such as ${stale[0]?.matchId ?? ""}|${stale[0]?.player ?? ""}`]), ...mismatched];
};

export const openCertain = (path: string, seatIndex: ReadonlyMap<string, number>): Certain => {
  const { rates, mistakes } = readOnly(path, (db) => ({
    rates: db
      .query(`select scope, model, effort, type, chose, opportunities, lo, hi from rates order by scope, model, effort, type`)
      .all()
      .map((raw) => {
        const { lo, hi, ...rate } = decodeRate(raw);

        return { ...rate, bounds: lo === null || hi === null ? null : { lo, hi } };
      }),
    mistakes: db
      .query(`select match_id matchId, ordinal, player, type from opportunities where outcome = 'mistake' order by match_id, ordinal`)
      .all()
      .flatMap((raw) => {
        const row = decodeMistake(raw);
        const seat = seatIndex.get(`${row.matchId}|${row.player}`);

        return seat === undefined ? [] : [{ ...row, seat }];
      }),
  }));

  const byMatch = new Map<string, Map<number, CertainType>>();

  for (const { matchId, ordinal, type } of mistakes) { byMatch.set(matchId, (byMatch.get(matchId) ?? new Map<number, CertainType>()).set(ordinal, type)); }

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
