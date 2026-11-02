import { mkdirSync, mkdtempSync, rmSync } from "node:fs";
import { tmpdir } from "node:os";
import { dirname, join, resolve } from "node:path";
import { parseArgs } from "node:util";

import { Database } from "bun:sqlite";
import { Option, Result, Schema } from "effect";

import { type AgentSource } from "../src/agent/view.ts";
import {
  certainAt,
  emptyLedger,
  itemMoveOf,
  type Knowledge,
  knowledgeOf,
  knownText,
  type Ledger,
  ledgerMismatch,
  ledgerStep,
  loadLog,
  positionKeys,
  relativeText,
  shotOf,
  stolenClue,
} from "../src/analysis/knowledge.ts";
import { loadPlayer } from "../src/analysis/player.ts";
import { shortName } from "../src/arena-viewer/page/data.ts";
import { RunManifest } from "../src/arena/match.ts";
import { MoveLine } from "../src/arena/runlog.ts";
import { GameEvent, type Seat, Secret } from "../src/domain.ts";
import { type Letter, rosterOf } from "../src/players.ts";
import { eventText, secretText } from "../src/text.ts";
import { replayOf } from "../src/arena/replay.ts";

// Rebuilds every agent decision's own information from the analysis database
// (docs/arena/database.md) and writes it to a separate database: the shell
// belief and where a certain chamber came from, the items on the table, each
// item's fate, deaths and position keys. The analysis database is opened read
// only. See docs/arena/analysis/beliefs-and-items.md.
//
//   bun scripts/arena-knowledge.ts --db <buckshot.sqlite> --out <knowledge.sqlite>
//   bun scripts/arena-knowledge.ts --db <buckshot.sqlite> --trace <match name>
//   bun scripts/arena-knowledge.ts --db <buckshot.sqlite> --verify [--limit N]
//
// --trace prints one match's decisions with the knowledge rebuilt at each.
// --verify checks, without writing, that the true gun is always one of the
// orders the player's log allows. It reads the hidden gun only for that check.

const { values } = parseArgs({
  args: process.argv.slice(2),
  options: { db: { type: "string" }, out: { type: "string" }, trace: { type: "string" }, verify: { type: "boolean" }, limit: { type: "string" } },
});

if (values.db === undefined || (values.out === undefined && values.trace === undefined && values.verify !== true)) {
  console.error("Usage: bun scripts/arena-knowledge.ts --db <database> (--out <knowledge.sqlite> | --trace <match> | --verify) [--limit N]");
  process.exit(1);
}

const source = new Database(resolve(values.db), { readonly: true });

const scratch = mkdtempSync(join(tmpdir(), "buckshot-knowledge-"));

const belief = await loadPlayer(scratch).finally(() => rmSync(scratch, { recursive: true, force: true }));

const decodeManifest = Schema.decodeUnknownSync(Schema.fromJsonString(RunManifest));

const decodeMove = Schema.decodeUnknownSync(Schema.fromJsonString(MoveLine));

const decodeLetter = Schema.decodeUnknownSync(Schema.Literals(["A", "B", "C", "D"]));

interface MatchRow {
  readonly id: string;
  readonly name: string;
  readonly tournament: string;
  readonly status: string;
  readonly code_hash: string | null;
  readonly instructions_hash: string | null;
  readonly seed: number;
  readonly seed_block_id: string;
  readonly pairing: number;
  readonly manifest_json: string;
}

interface SeatRow {
  readonly position: number;
  readonly player: string;
  readonly entrant: string;
  readonly model: string | null;
  readonly effort: string | null;
}

interface DecisionRow {
  readonly ordinal: number;
  readonly player: string;
  readonly label: string;
  readonly by_whom: string;
  readonly legal_json: string;
  readonly raw: string;
}

/** The comparison a match belongs to: every match between different models, or every match of one model against itself (an effort sweep), from every tournament. Same rule as the arena viewer's cohorts. */
const cohortOf = (seats: ReadonlyArray<SeatRow>): string => {
  const models = [...new Set(seats.map((seat) => seat.model ?? ""))];

  return models.length === 1 ? `${shortName(models[0] ?? "")} efforts` : "Cross-model";
};

const matches = source
  .query<MatchRow, []>(
    `SELECT m.id, m.name, t.name AS tournament, m.status, m.code_hash, m.instructions_hash, m.seed, m.seed_block_id, m.pairing, m.manifest_json
     FROM matches m JOIN tournaments t ON t.id = m.tournament_id
     WHERE m.manifest_json IS NOT NULL AND m.replay_status = 'validated' ORDER BY t.name, m.name`,
  )
  .all()
  .filter((match) => values.trace === undefined || match.name === values.trace)
  .slice(0, values.limit === undefined ? undefined : Number(values.limit));

if (matches.length === 0) {
  console.error("No replay-validated match matched.");
  process.exit(1);
}

const out = values.out === undefined ? undefined : (() => {
  mkdirSync(dirname(resolve(values.out)), { recursive: true });
  const db = new Database(resolve(values.out), { create: true, strict: true });
  db.exec(`
    PRAGMA journal_mode = WAL;
    DROP TABLE IF EXISTS matches; DROP TABLE IF EXISTS players; DROP TABLE IF EXISTS decisions; DROP TABLE IF EXISTS clues;
    DROP TABLE IF EXISTS items; DROP TABLE IF EXISTS deaths; DROP TABLE IF EXISTS problems;
    CREATE TABLE matches (match_id TEXT PRIMARY KEY, name TEXT, tournament TEXT, cohort TEXT, status TEXT, code_hash TEXT, instructions_hash TEXT, seed INTEGER, seed_block_id TEXT, pairing INTEGER);
    CREATE TABLE players (match_id TEXT, player TEXT, position INTEGER, entrant TEXT, model TEXT, effort TEXT, PRIMARY KEY (match_id, player));
    CREATE TABLE decisions (
      match_id TEXT, ordinal INTEGER, player TEXT, by_whom TEXT, label TEXT, choice TEXT, legal_json TEXT,
      round INTEGER, remaining INTEGER, shown_live INTEGER, shown_blank INTEGER, sawed INTEGER,
      public_orders INTEGER, public_live_min INTEGER, public_live_max INTEGER, public_live_json TEXT, public_known TEXT,
      private_orders INTEGER, private_live_min INTEGER, private_live_max INTEGER, private_live_json TEXT, private_known TEXT,
      chamber TEXT, source TEXT, clue_ordinal INTEGER, clue_via_adrenaline INTEGER, moves_since_clue INTEGER, own_moves_since_clue INTEGER,
      shot TEXT, item TEXT, item_stolen INTEGER, legal_items_json TEXT, own_items_json TEXT, opponent_items_json TEXT, health_json TEXT,
      exact_key TEXT, belief_key TEXT, PRIMARY KEY (match_id, ordinal));
    CREATE TABLE clues (match_id TEXT, learned INTEGER, ordinal INTEGER, player TEXT, kind TEXT, position INTEGER, shell TEXT, via_adrenaline INTEGER, PRIMARY KEY (match_id, learned));
    CREATE TABLE items (match_id TEXT, player TEXT, item TEXT, slot INTEGER, round INTEGER, placed_ordinal INTEGER, end TEXT, ended_ordinal INTEGER, by_player TEXT, moves_held INTEGER, own_decisions_held INTEGER);
    CREATE TABLE deaths (match_id TEXT, player TEXT, ordinal INTEGER, round INTEGER, items_held INTEGER);
    CREATE TABLE problems (match_id TEXT, ordinal INTEGER, message TEXT);
  `);

  return db;
})();

const put = (table: string, row: Readonly<Record<string, string | number | null>>): void => {
  const keys = Object.keys(row);
  out?.query(`INSERT INTO ${table} (${keys.join(",")}) VALUES (${keys.map(() => "?").join(",")})`).run(...Object.values(row));
};

const shellLetter = (shell: Option.Option<string>): string | null => Option.getOrNull(shell);

let checked = 0;

let outside = 0;

let wrongCertain = 0;

let problemCount = 0;

const started = performance.now();

for (const [count, match] of matches.entries()) {
  const manifest = decodeManifest(match.manifest_json);

  const seats = source
    .query<SeatRow, [string]>("SELECT s.position, s.player, e.name AS entrant, e.model, e.effort FROM match_seats s JOIN entrants e ON e.id = s.entrant_id WHERE s.match_id = ? ORDER BY s.position")
    .all(match.id);

  const decisions = source
    .query<DecisionRow, [string]>("SELECT d.ordinal, d.player, d.label, d.by_whom, d.legal_json, r.raw FROM decisions d JOIN source_records r ON r.id = d.source_record WHERE d.match_id = ? ORDER BY d.ordinal")
    .all(match.id);

  const moves: Array<MoveLine> = [];
  let replay = Result.getOrThrow(replayOf(Option.none(), manifest, []));
  const current = (): AgentSource => Option.getOrThrow(replay.session.current(replay.table));
  const firstSource = current();
  const roster = rosterOf(firstSource.game.seats, firstSource.letters);
  const letterOf = (seat: Seat): Letter => roster.playerOf(seat).letter;
  const seatOf = (letter: string): Seat => Option.getOrThrow(roster.find(decodeLetter(letter))).seat;
  // The decision whose move produced each event and each secret; -1 before the first move.
  const eventOrdinal: Array<number> = firstSource.events.map(() => -1);
  const learnedOrdinal: Array<number> = firstSource.learned.map(() => -1);
  let ledger: Ledger = firstSource.events.reduce<Ledger>((so, event, index) => ledgerStep(so, event, index), emptyLedger);
  const agentOrdinals = new Map<string, Array<number>>();

  const problem = (ordinal: number, message: string) => {
    problemCount++;
    put("problems", { match_id: match.id, ordinal, message });

    if (out === undefined) console.error(`${match.name} #${ordinal}: ${message}`);
  };

  const ownBetween = (player: string, after: number, before: number): number => (agentOrdinals.get(player) ?? []).filter((ordinal) => ordinal > after && ordinal < before).length;

  put("matches", { match_id: match.id, name: match.name, tournament: match.tournament, cohort: cohortOf(seats), status: match.status, code_hash: match.code_hash, instructions_hash: match.instructions_hash, seed: match.seed, seed_block_id: match.seed_block_id, pairing: match.pairing });

  for (const seat of seats) put("players", { match_id: match.id, player: seat.player, position: seat.position, entrant: seat.entrant, model: seat.model, effort: seat.effort });

  out?.exec("BEGIN");

  for (const decision of decisions) {
    const before = current();
    const seat = seatOf(decision.player);

    Option.map(ledgerMismatch(ledger, before.game.board), (message) => problem(decision.ordinal, message));

    if (decision.by_whom !== "forced") {
      const log = loadLog(before.events, before.learned, seat);
      const knowledge: Knowledge = knowledgeOf(belief, log);
      const board = before.game.board;
      const legal = Schema.decodeUnknownSync(Schema.fromJsonString(Schema.Array(Schema.Struct({ move: Schema.Number, label: Schema.String }))))(decision.legal_json).map(({ label }) => label);
      const keys = positionKeys(roster, seat, board, log, { public: belief.orders(log, false), private: belief.orders(log, true) }, legal, [match.code_hash, match.instructions_hash]);
      const clueOrdinal = Option.map(knowledge.clue, (index) => learnedOrdinal[index] ?? -1);
      const viaAdrenaline = Option.map(knowledge.clue, (index) => stolenClue(before.events, before.learned[index]?.at ?? 0, seat));
      const itemMove = itemMoveOf(decision.label);
      const opponents = board.seats.filter((view) => view.seat !== seat);
      const own = board.seats.find((view) => view.seat === seat);
      const itemsOf = (views: typeof board.seats) => JSON.stringify(views.flatMap((view) => view.slots.flatMap((slot) => Option.toArray(slot))).toSorted());

      put("decisions", {
        match_id: match.id,
        ordinal: decision.ordinal,
        player: decision.player,
        by_whom: decision.by_whom,
        label: decision.label,
        choice: relativeText(roster, seat, decision.label),
        legal_json: JSON.stringify(legal.map((label) => relativeText(roster, seat, label))),
        round: board.round.index,
        remaining: board.gun.remaining,
        shown_live: board.gun.shown.live,
        shown_blank: board.gun.shown.blank,
        sawed: board.gun.sawed ? 1 : 0,
        public_orders: knowledge.public.orders,
        public_live_min: knowledge.public.liveMin,
        public_live_max: knowledge.public.liveMax,
        public_live_json: JSON.stringify(knowledge.public.live),
        public_known: knownText(knowledge.public),
        private_orders: knowledge.private.orders,
        private_live_min: knowledge.private.liveMin,
        private_live_max: knowledge.private.liveMax,
        private_live_json: JSON.stringify(knowledge.private.live),
        private_known: knownText(knowledge.private),
        chamber: shellLetter(knowledge.chamber),
        source: Option.getOrNull(knowledge.source),
        clue_ordinal: Option.getOrNull(clueOrdinal),
        clue_via_adrenaline: Option.match(viaAdrenaline, { onNone: () => null, onSome: (via) => (via ? 1 : 0) }),
        moves_since_clue: Option.getOrNull(Option.map(clueOrdinal, (ordinal) => decision.ordinal - ordinal - 1)),
        own_moves_since_clue: Option.getOrNull(Option.map(clueOrdinal, (ordinal) => ownBetween(decision.player, ordinal, decision.ordinal))),
        shot: Option.getOrNull(shotOf(decision.label)),
        item: Option.getOrNull(Option.map(itemMove, (move) => move.item)),
        item_stolen: Option.match(itemMove, { onNone: () => null, onSome: (move) => (move.stolen ? 1 : 0) }),
        legal_items_json: JSON.stringify([...new Set(legal.flatMap((label) => Option.toArray(itemMoveOf(label)).map((move) => `${move.stolen ? "steal " : ""}${move.item}`)))]),
        own_items_json: itemsOf(own === undefined ? [] : [own]),
        opponent_items_json: itemsOf(opponents),
        health_json: JSON.stringify([own, ...opponents].map((view) => (view === undefined ? null : view.counter))),
        exact_key: keys.exact,
        belief_key: keys.belief,
      });

      if (values.verify === true) {
        const gun = trueGun(before);
        const allowed = belief.orders(log, true);
        checked++;

        if (!allowed.includes(gun) || !belief.orders(log, false).includes(gun) || gun.length !== board.gun.remaining) {
          outside++;
          console.error(`${match.name} #${decision.ordinal}: the true gun ${gun} is outside the allowed orders`);
        }

        if (Option.isSome(knowledge.chamber) && Option.getOrNull(certainAt(knowledge.private, 0)) !== (gun.startsWith("L") ? "Live" : "Blank")) wrongCertain++;
      }

      if (values.trace !== undefined) {
        console.log(
          [
            `#${decision.ordinal} ${decision.player} (${decision.by_whom}) ${decision.label}`,
            `  round ${board.round.index + 1}, ${board.gun.remaining} left of ${board.gun.shown.live}L/${board.gun.shown.blank}B; live left ${knowledge.public.liveMin}-${knowledge.public.liveMax}`,
            `  public  orders ${knowledge.public.orders}, live by position ${JSON.stringify(knowledge.public.live)}, known ${knownText(knowledge.public) || "-"}`,
            `  private orders ${knowledge.private.orders}, live by position ${JSON.stringify(knowledge.private.live)}, known ${knownText(knowledge.private) || "-"}`,
            `  chamber ${shellLetter(knowledge.chamber) ?? "?"} from ${Option.getOrElse(knowledge.source, () => "-")}${Option.isSome(clueOrdinal) ? `, clue at #${Option.getOrThrow(clueOrdinal)}${Option.getOrElse(viaAdrenaline, () => false) ? " (stolen)" : ""}` : ""}`,
            `  items: own ${itemsOf(own === undefined ? [] : [own])}, opponent ${itemsOf(opponents)}`,
            `  log since the load: ${log.map((entry) => (entry.kind === "secret" ? `[${secretText(entry.secret)} from #${learnedOrdinal[entry.index] ?? "?"}]` : eventText(roster, entry.event))).join(" | ")}`,
          ].join("\n"),
        );
      }

      agentOrdinals.set(decision.player, [...(agentOrdinals.get(decision.player) ?? []), decision.ordinal]);
    }

    moves.push(decodeMove(decision.raw));
    replay = Result.getOrThrow(replayOf(Option.some(replay), manifest, moves));

    if (Option.isSome(replay.divergence)) throw new Error(`${match.name}: ${Option.getOrThrow(replay.divergence)}`);

    const after = current();

    for (let index = before.events.length; index < after.events.length; index++) {
      const event = after.events[index];

      if (event === undefined) continue;

      eventOrdinal[index] = decision.ordinal;
      const deaths = GameEvent.matchOrElse(event, { Died: ({ seat: died }) => [died] }, () => []);

      for (const died of deaths) put("deaths", { match_id: match.id, player: letterOf(died), ordinal: decision.ordinal, round: after.game.board.round.index, items_held: ledger.open.filter((holding) => holding.seat === died).length });

      ledger = ledgerStep(ledger, event, index);
    }

    for (let index = before.learned.length; index < after.learned.length; index++) {
      learnedOrdinal[index] = decision.ordinal;
      const note = after.learned[index];

      if (note === undefined) continue;

      const clue = (kind: string, position: number, shell: string) =>
        put("clues", { match_id: match.id, learned: index, ordinal: decision.ordinal, player: letterOf(note.seat), kind, position, shell, via_adrenaline: stolenClue(after.events, note.at, note.seat) ? 1 : 0 });

      Secret.match(note.secret, { Glimpse: ({ shell }) => clue("glass", 1, shell), Clue: ({ position, shell }) => clue("phone", position, shell), NoClue: () => undefined, EmptyBriefcase: () => undefined });
    }
  }

  if (match.status === "completed" && ledger.open.length > 0) problem(-1, `${ledger.open.length} items still open at the end of a completed match`);

  for (const message of ledger.problems) problem(-1, message);

  const roundOf = (eventIndex: number): number => current().events.slice(0, eventIndex + 1).filter(GameEvent.guards.RoundBegan).length - 1;

  for (const record of [...ledger.closed, ...ledger.open.map((holding) => ({ ...holding, end: "open" as const, ended: current().events.length, by: Option.none<Seat>() }))]) {
    const placed = eventOrdinal[record.placed] ?? -1;
    const ended = eventOrdinal[record.ended] ?? decisions.length;
    const player = letterOf(record.seat);
    const held = ownBetween(player, placed, ended) + ((agentOrdinals.get(player) ?? []).includes(ended) && record.end !== "used" ? 1 : 0);
    put("items", { match_id: match.id, player, item: record.item, slot: record.slot, round: roundOf(record.placed), placed_ordinal: placed, end: record.end, ended_ordinal: ended, by_player: Option.getOrNull(Option.map(record.by, letterOf)), moves_held: ended - placed, own_decisions_held: held });
  }

  out?.exec("COMMIT");

  if (out !== undefined && (count + 1) % 50 === 0) console.error(`${count + 1}/${matches.length} matches, ${Math.round((performance.now() - started) / 1000)} s`);
}

interface ShellList {
  readonly $: string;
  readonly head?: { readonly $: string };
  readonly tail?: ShellList;
}

/** Validation only: the hidden gun, read to check the belief and never written or used to judge a player. */
function trueGun(at: AgentSource): string {
  // SAFETY: the machine state is sm/state.State{world: World{..., gun: List<Shell>}} (sim/bend-mp/sm/state.bend).
  const state = at.game.state as { readonly $: string; readonly world: { readonly gun: ShellList } };
  const shells: Array<string> = [];

  for (let rest: ShellList | undefined = state.world.gun; rest?.$ === "Con"; rest = rest.tail) shells.push(rest.head?.$.endsWith(".Live") === true ? "L" : "B");

  return shells.join("");
}

out?.close();

source.close();

const summary = { matches: matches.length, problems: problemCount, seconds: Math.round((performance.now() - started) / 1000) };

console.error(JSON.stringify(values.verify === true ? { ...summary, checked, outside, wrongCertain } : summary));
