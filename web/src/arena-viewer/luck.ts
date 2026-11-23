import { Schema } from "effect";

import { pairsOf } from "./page/ratings.ts";
import type { SeatFull } from "./page/data.ts";
import { readOnly } from "./read-only.ts";

// The luck database of tools/arena/analysis/aivat.py: per match and player, the sum of the AIVAT corrections at the
// chance events of the match's rounds, in round wins. Keyed by "<match id>|<player>".

const LuckRow = Schema.Struct({ matchId: Schema.String, player: Schema.String, correction: Schema.Finite });

const decodeLuckRow = Schema.decodeUnknownSync(LuckRow);

export const openLuck = (path: string): ReadonlyMap<string, number> => {
  const rows = readOnly(path, (db) => db.query(`select match_id matchId, player, correction from luck`).all().map((raw) => decodeLuckRow(raw)));

  return new Map(rows.map(({ matchId, player, correction }) => [`${matchId}|${player}`, correction]));
};

const example = (keys: ReadonlyArray<string>): string => (keys[0] === undefined ? "" : `, such as ${keys[0]}`);

/**
 * Why a luck file does not fit these seats, empty when it does: it must hold both seats of every scored two-player
 * match, which the luck-adjusted fit corrects, and no seat outside them, which would come from other inputs.
 */
export const luckProblems = (luck: ReadonlyMap<string, number>, seats: ReadonlyArray<SeatFull>): ReadonlyArray<string> => {
  const scored = new Set(pairsOf(seats).flat().map(({ matchId, player }) => `${matchId}|${player}`));
  const missing = [...scored].filter((key) => !luck.has(key));
  const extra = [...luck.keys()].filter((key) => !scored.has(key));

  return [
    ...(missing.length === 0 ? [] : [`the luck file lacks ${missing.length} of the ${scored.size} scored seats${example(missing)}`]),
    ...(extra.length === 0 ? [] : [`the luck file has ${extra.length} seats that are not scored seats of this database${example(extra)}`]),
  ];
};
