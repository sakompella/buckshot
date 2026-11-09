import { Database } from "bun:sqlite";

import { Schema } from "effect";

// The luck database of tools/arena/analysis/aivat.py: per match and player, the sum of the AIVAT corrections at the
// chance events of the match's rounds, in round wins. Keyed by "<match id>|<player>".

const LuckRow = Schema.Struct({ matchId: Schema.String, player: Schema.String, correction: Schema.Number });

const decodeLuckRow = Schema.decodeUnknownSync(LuckRow);

export const openLuck = (path: string): ReadonlyMap<string, number> => {
  const db = new Database(path, { readonly: true });
  const rows = db.query(`select match_id matchId, player, correction from luck`).all().map((raw) => decodeLuckRow(raw));

  db.close();

  return new Map(rows.map(({ matchId, player, correction }) => [`${matchId}|${player}`, correction]));
};
