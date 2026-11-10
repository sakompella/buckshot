import { Database } from "bun:sqlite";

import { Effect, Schema } from "effect";

import { configOfLabel } from "../arena/model-names.ts";

import { analyse } from "./analysis.ts";
import { type Consistency, type Decisions, type Seat, SeatRow } from "./api.ts";
import { type Certain, NO_CERTAIN, openCertain } from "./certain.ts";
import { openConsistency } from "./consistency.ts";
import { openLuck } from "./luck.ts";
import { openRegret, type Regret } from "./regret.ts";
import { assertCurrentImport } from "../analysis/importer-hash.ts";
import { ScriptError } from "../script.ts";

// Reads the arena analysis database once for the viewer server and the aggregate export. It never selects
// match_seats.provenance_json, which holds an account email. Excluded matches (a DeepSeek seat, matches.disposition)
// are dropped here, so no tab, rating or total sees them.

const SEATS_SQL = `with cs as (select match_id, player, sum(cost_usd) cost, sum(input_tokens) inp, sum(output_tokens) outp,
     sum(cache_read_tokens) cr, sum(cache_write_tokens) cw, sum(reasoning_tokens) rt,
     sum(latency_ms) lat,
     sum(reasoning_tokens > 0 and coalesce(reasoning_text, '') = '') rsHidden, sum(coalesce(reasoning_text, '') != '') rsText,
     sum(json_valid(tool_calls_json) and json_array_length(tool_calls_json) > 1) multiTool
   from calls group by match_id, player),
   ds as (select match_id, player, sum(by_whom = 'agent') moves from decisions group by match_id, player)
   select t.name tournament, m.id matchId, m.name matchName, m.status, m.started_at startedAt, m.seed, m.seed_block_id seedBlock,
     substr(m.code_hash, 1, 8) codeHash, ms.label, ms.player, ms.position, ms.win_share winShare, ms.cash,
     cs.cost, cs.inp, cs.outp, cs.cr, cs.cw, cs.rt, cs.lat, cs.rsHidden, cs.rsText, cs.multiTool, ds.moves
   from match_seats ms join matches m on m.id = ms.match_id join tournaments t on t.id = m.tournament_id
   left join cs on cs.match_id = m.id and cs.player = ms.player
   left join ds on ds.match_id = m.id and ds.player = ms.player
   where m.status in ('completed', 'partial') and m.disposition is not 'excluded' order by m.started_at, ms.position`;

const decodeSeatRow = Schema.decodeUnknownSync(SeatRow);

/** A database row with its seat's label. */
export const decodeLabelled = Schema.decodeUnknownSync(Schema.StructWithRest(Schema.Struct({ label: Schema.String }), [Schema.Record(Schema.String, Schema.Unknown)]));

/** A seat row with its label read as the config the page groups and colours seats by. */
export const withConfig = ({ label, ...rest }: ReturnType<typeof decodeLabelled>) => ({ ...rest, ...configOfLabel(label) });

export interface ArenaPaths {
  readonly regret?: string | undefined;
  readonly knowledge?: string | undefined;
  readonly certain?: string | undefined;
  readonly luck?: string | undefined;
}

export interface Arena {
  readonly db: Database;
  readonly regret: Regret | null;
  readonly seats: ReadonlyArray<Seat>;
  readonly seatIndex: ReadonlyMap<string, number>;
  readonly decisions: Decisions;
  readonly certain: Certain;
  readonly consistency: ReadonlyArray<Consistency>;
  /** Per "<match id>|<player>", the luck correction in round wins; empty without a luck database. */
  readonly luck: ReadonlyMap<string, number>;
}

const closeArena = ({ db, regret }: Pick<Arena, "db" | "regret">) => {
  regret?.close();
  db.close();
};

/** With a regret database, seats carry their regret; with a knowledge database, each config's consistency; with a certain-mistakes database, its rates and moves; with a luck database, the luck-adjusted ratings. */
const loadFrom = (db: Database, regret: Regret | null, paths: ArenaPaths): Arena => {
  assertCurrentImport(db);

  const rows = db
    .query(SEATS_SQL)
    .all()
    .map((row) => decodeSeatRow(withConfig(decodeLabelled(row))));

  const seatIndex = new Map(rows.map((row, index) => [`${row.matchId}|${row.player}`, index]));
  const { decisions, seats: analysed } = analyse(db, rows, seatIndex);

  const seats = rows.flatMap((row, index) => {
    const extra = analysed[index];

    return extra === undefined ? [] : [{ ...row, ...extra, regret: regret?.seats.get(`${row.matchId}|${row.player}`) ?? null }];
  });

  const seedBlocks = new Map(seats.map(({ matchId, seedBlock }) => [matchId, seedBlock]));

  return {
    db,
    regret,
    seats,
    seatIndex,
    decisions,
    certain: paths.certain === undefined ? NO_CERTAIN : openCertain(paths.certain, seatIndex),
    consistency: paths.knowledge === undefined ? [] : openConsistency(paths.knowledge, seedBlocks),
    luck: paths.luck === undefined ? new Map() : openLuck(paths.luck),
  };
};

/** The arena of `dbPath`, open until the scope closes. The main and regret databases stay open for the per-match routes. */
export const openArena = (dbPath: string, paths: ArenaPaths = {}) =>
  Effect.acquireRelease(
    Effect.try({
      try: () => {
        const db = new Database(dbPath, { readonly: true });
        let regret: Regret | null = null;

        try {
          regret = paths.regret === undefined ? null : openRegret(paths.regret);

          return loadFrom(db, regret, paths);
        } catch (error) {
          closeArena({ db, regret });
          throw error;
        }
      },
      catch: (cause) => new ScriptError({ message: `cannot read ${dbPath}: ${String(cause)}`, exitCode: 1 }),
    }),
    (arena) => Effect.sync(() => closeArena(arena)),
  );
