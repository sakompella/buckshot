import type { Database } from "bun:sqlite";

import { Schema } from "effect";

import { type Decisions, ITEMS, type Pattern, patternBit, type SeatAnalysis, type Shell, type Story } from "./api.ts";

// Per-decision columns for choice patterns, items, reasoning and compute, worked out once at server start.
// Each player's view is rebuilt by joining the event windows of its own decisions in order: a decision's events
// run from that player's previous decision, so together they are everything it saw.
// Rules checked against sim/bend-mp/sm/main.bend: cigarettes heal only below round health, any shot clears the saw,
// a blank self-shot keeps the turn; phone positions count from 1 = the chambered shell (src/text.ts).
// This tracks the event text, not a Bend replay of beliefs: it knows counts, glass and phone clues, inversions and racks.

const flip = (shell: Shell): Shell => (shell === "live" ? "blank" : "live");

const shellOf = (word: string | undefined): Shell => (word === "live" ? "live" : "blank");

type Clue = "glass" | "phone";

/** The chambered shell as one player knows it: its type and how it knows, or only the chance it is live. */
export interface Chamber {
  readonly known: Shell | null;
  readonly by: Clue | "count" | null;
  readonly pLive: number;
}

/** One player's knowledge of the gun, fed that player's events in order. */
export class ShellTracker {
  roundHealth = 0;
  /** Shells left by original type, the chambered one included. */
  live = 0;
  blank = 0;
  cursor = 0;
  total = 0;
  /** Whether the chambered shell was flipped after it reached the chamber. */
  inverted = false;
  sawed = false;
  /** The current type of each shell this player was told, by its place in the load. */
  readonly known = new Map<number, { shell: Shell; by: Clue }>();
  readonly checks = { ok: 0, bad: 0 };
  /** Which load this is; with the cursor it names the shell in the chamber. */
  loadNo = 0;
  /** Inversions seen, so a pending inverter use can tell its own inversion from later ones. */
  inversions = 0;

  event(text: string): void {
    const round = /^Round \d+ begins\. Everyone has (\d+) health/.exec(text);
    const load = /^The shotgun is loaded: (\d+) live, (\d+) blank\./.exec(text);
    const glass = /^The chambered shell is (live|blank)\./.exec(text);
    const phone = /^The (\d+)(?:st|nd|rd|th) shell is (live|blank)\./.exec(text);
    const spent = / shot .*: (live|blank)/.exec(text) ?? / racked out a (live|blank) shell\./.exec(text);

    if (round) this.roundHealth = Number(round[1]);
    else if (load) {
      this.loadNo++;
      this.live = Number(load[1]);
      this.blank = Number(load[2]);
      this.total = this.live + this.blank;
      this.cursor = 0;
      this.inverted = false;
      this.sawed = false;
      this.known.clear();
    } else if (glass) this.known.set(this.cursor, { shell: shellOf(glass[1]), by: "glass" });
    else if (phone) this.known.set(this.cursor + Number(phone[1]) - 1, { shell: shellOf(phone[2]), by: "phone" });
    else if (text.endsWith(" inverted the chambered shell.")) {
      this.inverted = !this.inverted;
      this.inversions++;
      const clue = this.known.get(this.cursor);

      if (clue) clue.shell = flip(clue.shell);
    } else if (text.endsWith(" used handsaw.") || / took handsaw from .* and used it\.$/.test(text)) this.sawed = true;
    else if (spent) this.spend(shellOf(spent[1]), text.includes(" shot "));
  }

  private spend(now: Shell, isShot: boolean): void {
    const chamber = this.chamber();

    if (chamber?.known) {
      if (chamber.known === now) this.checks.ok++;
      else this.checks.bad++;
    }

    if ((this.inverted ? flip(now) : now) === "live") this.live--;
    else this.blank--;

    this.known.delete(this.cursor);
    this.cursor++;
    this.inverted = false;

    if (isShot) this.sawed = false;
  }

  /** Whether the chambered shell is the load's last, so shooting it ends the load whoever it hits. */
  isLastShell(): boolean {
    return this.total - this.cursor === 1;
  }

  /** The chambered shell, or null when the load is spent. */
  chamber(): Chamber | null {
    if (this.cursor >= this.total) return null;

    const clue = this.known.get(this.cursor);

    if (clue) return { known: clue.shell, by: clue.by, pLive: clue.shell === "live" ? 1 : 0 };

    const later = [...this.known].filter(([at]) => at > this.cursor);
    const live = this.live - later.filter(([, { shell }]) => shell === "live").length;
    const blank = this.blank - later.filter(([, { shell }]) => shell === "blank").length;

    if (live + blank <= 0) return null;

    const pLive = this.inverted ? blank / (live + blank) : live / (live + blank);

    if (pLive === 1) return { known: "live", by: "count", pLive };

    if (pLive === 0) return { known: "blank", by: "count", pLive };

    return { known: null, by: null, pLive };
  }
}

const sumOf = (values: ReadonlyArray<number>): number => values.reduce((total, value) => total + value, 0);

/**
 * Round winners and prizes from the public events. The last round's win is never in a decision window (the match
 * ends there), so it is inferred from final cash; ok means every player's prizes then sum exactly to its final cash.
 */
export const roundStory = (events: Iterable<string>, cash: ReadonlyMap<string, number>): Story => {
  let current = 0;
  let last = 0;
  let starter: string | null = null;
  const won = new Map<number, { winner: string; prize: number }>();

  for (const text of events) {
    const begins = /^Round (\d+) begins\..*Player (\w+) starts\./.exec(text);
    const wins = /^Player (\w+) wins the round and \$([\d,]+)\./.exec(text);

    if (begins) {
      current = Number(begins[1]);
      last = Math.max(last, current);

      if (current === 1) starter = begins[2] ?? null;
    } else if (wins && !won.has(current)) won.set(current, { winner: wins[1] ?? "", prize: Number((wins[2] ?? "").replaceAll(",", "")) });
  }

  const rounds: Array<Story["rounds"][number]> = [];

  for (let round = 1; round <= last; round++) {
    const win = won.get(round);

    if (win) rounds.push({ ...win, inferred: false });
    else if (round < last) return { starter, rounds, ok: false };
  }

  const residual = new Map([...cash].map(([player, total]) => [player, total - sumOf(rounds.flatMap(({ winner, prize }) => (winner === player ? [prize] : [])))]));

  if (!won.has(last)) {
    const ahead = [...residual].filter(([, left]) => left > 0);
    const [only] = ahead;

    if (ahead.length !== 1 || only === undefined) return { starter, rounds, ok: false };

    rounds.push({ winner: only[0], prize: only[1], inferred: true });
    residual.set(only[0], 0);
  }

  return { starter, rounds, ok: [...residual.values()].every((left) => left === 0) };
};

/** The seats the analysis works over: their order is the seats response's order. */
export interface SeatKey {
  readonly matchId: string;
  readonly player: string;
  readonly cash: number | null;
}

const VisiblePlayer = Schema.Struct({ player: Schema.String, health: Schema.optional(Schema.Number), items: Schema.optional(Schema.Array(Schema.String)) });

/** What a decision showed its player: the database's visible_json. */
export const Visible = Schema.fromJsonString(Schema.Struct({ you: Schema.String, players: Schema.Array(VisiblePlayer), events: Schema.optional(Schema.Array(Schema.String)) }));

export const decodeVisible = Schema.decodeUnknownSync(Visible);

const decodeLegal = Schema.decodeUnknownSync(Schema.fromJsonString(Schema.Array(Schema.Struct({ label: Schema.String }))));

const PerDecisionRow = Schema.Struct({
  d: Schema.String,
  rt: Schema.NullOr(Schema.Number),
  nulls: Schema.Number,
  rc: Schema.Number,
  cost: Schema.NullOr(Schema.Number),
  lat: Schema.NullOr(Schema.Number),
  calls: Schema.Number,
  failed: Schema.Number,
  tok: Schema.Number,
});

const DecisionRow = Schema.Struct({
  m: Schema.String,
  p: Schema.String,
  w: Schema.String,
  label: Schema.String,
  v: Schema.String,
  legal: Schema.NullOr(Schema.String),
  id: Schema.String,
  ord: Schema.Number,
});

const SeatSourceRow = Schema.Struct({ dir: Schema.String, pos: Schema.Number, id: Schema.String, player: Schema.String });

const NoteRow = Schema.Struct({ path: Schema.String, kind: Schema.String, pos: Schema.Number });

const decodePerDecision = Schema.decodeUnknownSync(PerDecisionRow);

const decodeDecision = Schema.decodeUnknownSync(DecisionRow);

const decodeSeatSource = Schema.decodeUnknownSync(SeatSourceRow);

const decodeNote = Schema.decodeUnknownSync(NoteRow);

const itemIndex = (name: string): number => ITEMS.findIndex((item) => item === name);

const ADRENALINE = itemIndex("adrenaline");

const JAMMER = itemIndex("jammer");

/** A seat's analysis while the decisions are read. */
interface SeatTally {
  acquired: Array<number>;
  used: Array<number>;
  stolen: Array<number>;
  faults: number;
  reminders: number;
  fallbacks: number;
  story: Story | null;
  round: number;
  low: [number, number, number] | null;
}

const emptySeat = (): SeatTally => ({
  acquired: ITEMS.map(() => 0),
  used: ITEMS.map(() => 0),
  stolen: ITEMS.map(() => 0),
  faults: 0,
  reminders: 0,
  fallbacks: 0,
  story: null,
  round: 0,
  low: null,
});

type MutableColumns = { -readonly [K in keyof Omit<Decisions, "checks">]: Array<number> };

/** An inverter use on a known live shell, tied to that exact shell: same load, same cursor, and only its own inversion since. */
interface PendingInvert {
  readonly load: number;
  readonly cursor: number;
  readonly inversions: number;
}

/** Works out the decision columns and each seat's analysis. seatIndex maps `matchId|player` to a place in seats. */
export interface Analysis {
  readonly decisions: Decisions;
  /** In the order of the seats analysed. */
  readonly seats: ReadonlyArray<SeatAnalysis>;
}

export const analyse = (db: Database, seats: ReadonlyArray<SeatKey>, seatIndex: ReadonlyMap<string, number>): Analysis => {
  const started = performance.now();

  // Calls link to the next move heuristically (calls.link_method), so every linked call is added up per decision first.
  const perDecision = new Map(
    db
      .query(
        `select decision_id d, sum(reasoning_tokens) rt, sum(reasoning_tokens is null) nulls, sum(length(coalesce(reasoning_text, ''))) rc,
           sum(cost_usd) cost, sum(latency_ms) lat, count(*) calls, sum(status = 'failed') failed,
           sum(coalesce(input_tokens, 0) + coalesce(output_tokens, 0) + coalesce(cache_read_tokens, 0) + coalesce(cache_write_tokens, 0)) tok
         from calls where decision_id is not null group by decision_id`,
      )
      .all()
      .map((raw) => {
        const row = decodePerDecision(raw);

        return [row.d, { rt: row.nulls === 0 ? (row.rt ?? 0) : -1, rc: row.rc, cost: row.cost ?? 0, lat: row.lat ?? 0, tok: row.tok, calls: row.calls, failed: row.failed }] as const;
      }),
  );

  const extra = seats.map(() => emptySeat());
  const columns: MutableColumns = { seat: [], ord: [], moveNo: [], opp: [], pick: [], failedCalls: [], rt: [], rc: [], cost: [], lat: [], tok: [], calls: [], legalUse: [], legalSteal: [], useItem: [], stealItem: [], shot: [] };
  const checks = { ok: 0, bad: 0 };

  const seatsOf = new Map<string, Array<number>>();

  seats.forEach((seat, index) => seatsOf.set(seat.matchId, [...(seatsOf.get(seat.matchId) ?? []), index]));

  let tracker = new ShellTracker();
  let currentSeat = "";
  let currentMatch = "";
  let moveNo = 0;
  let pendingInvert: PendingInvert | null = null;
  let matchEvents: Array<string> = [];

  const finishSeat = () => {
    checks.ok += tracker.checks.ok;
    checks.bad += tracker.checks.bad;
  };

  const finishMatch = () => {
    const indexes = seatsOf.get(currentMatch) ?? [];
    const cash = new Map(indexes.flatMap((index) => seats[index] ?? []).map((seat) => [seat.player, seat.cash ?? 0]));
    const story = roundStory(matchEvents, cash);

    for (const index of indexes) {
      const seat = extra[index];

      if (seat) seat.story = story;
    }
  };

  const decisions = db.query(
    `select d.match_id m, d.player p, d.by_whom w, d.label, d.visible_json v, d.legal_json legal, d.id, d.ordinal ord
     from decisions d join matches m on m.id = d.match_id
     where m.status in ('completed', 'partial') and d.visible_json is not null order by d.match_id, d.player, d.ordinal`,
  );

  for (const raw of decisions.iterate()) {
    const row = decodeDecision(raw);

    if (row.m !== currentMatch) {
      finishMatch();
      currentMatch = row.m;
      matchEvents = [];
    }

    if (`${row.m}|${row.p}` !== currentSeat) {
      finishSeat();
      currentSeat = `${row.m}|${row.p}`;
      tracker = new ShellTracker();
      moveNo = 0;
      pendingInvert = null;
    }

    const seatAt = seatIndex.get(currentSeat);
    const seat = seatAt === undefined ? undefined : extra[seatAt];

    if (seatAt === undefined || seat === undefined) continue;

    const visible = decodeVisible(row.v);
    const placedPrefix = `Player ${visible.you} `;

    for (const text of visible.events ?? []) {
      tracker.event(text);
      matchEvents.push(text);
      const round = /^Round (\d+) begins/.exec(text);

      if (round) {
        seat.round = Number(round[1]);
        seat.low = null;
      }

      const placed = text.startsWith(placedPrefix) ? / placed (.+) in slot \d+\.$/.exec(text) : null;
      const placedItem = placed ? itemIndex(placed[1] ?? "") : -1;

      if (placedItem >= 0) seat.acquired[placedItem] = (seat.acquired[placedItem] ?? 0) + 1;
    }

    const ownHealth = visible.players.find(({ player }) => player === visible.you)?.health;
    const opponentHealth = visible.players.find(({ player }) => player !== visible.you)?.health;

    if (ownHealth !== undefined && opponentHealth !== undefined && opponentHealth - ownHealth > (seat.low ? seat.low[1] - seat.low[0] : 0)) seat.low = [ownHealth, opponentHealth, seat.round];

    if (row.w === "fallback") seat.fallbacks++;

    if (row.w !== "agent") continue;

    moveNo++;
    const legal = new Set(decodeLegal(row.legal ?? "[]").map(({ label }) => label));
    const legalLabels = [...legal];
    const canSelf = legal.has("Shoot yourself");
    const canOpp = legalLabels.some((label) => label.startsWith("Shoot Player "));
    const isSelf = row.label === "Shoot yourself";
    const isOpp = row.label.startsWith("Shoot Player ");
    const chamber = tracker.chamber();
    let chances = 0;
    let taken = 0;

    const flag = (pattern: Pattern, isAvailable: boolean, isChosen: boolean) => {
      if (!isAvailable) return;

      chances |= patternBit(pattern);

      if (isChosen) taken |= patternBit(pattern);
    };

    if (chamber) {
      const byItem = chamber.by === "glass" || chamber.by === "phone";
      // The regret search rates shooting the opponent with a load's last blank close to best, unlike an earlier blank.
      const isFreeBlank = chamber.known === "blank" && canOpp && !tracker.isLastShell();

      flag("knownBlankOpp", byItem && isFreeBlank, isOpp);
      flag("glassBlankOpp", chamber.by === "glass" && isFreeBlank, isOpp);
      flag("knownLiveSelf", byItem && chamber.known === "live" && canSelf, isSelf);
      flag("countLiveSelf", chamber.by === "count" && chamber.known === "live" && canSelf, isSelf);
      flag("countBlankOpp", chamber.by === "count" && isFreeBlank, isOpp);
      flag("sawSelf", tracker.sawed && chamber.known !== "blank" && canSelf, isSelf);
      flag("oddsLiveSelf", chamber.known === null && chamber.pLive > 0.5 && canSelf, isSelf);
      flag("oddsBlankOpp", chamber.known === null && chamber.pLive < 0.5 && canOpp, isOpp);
      flag("tieSelf", chamber.known === null && chamber.pLive === 0.5 && canSelf, isSelf);
      flag("glassKnown", chamber.known !== null && legal.has("Use magnifying glass"), row.label === "Use magnifying glass");
    }

    // Inverting a known live shell, then shooting the opponent with the now blank shell: checked at the next shot.
    if (pendingInvert && (pendingInvert.load !== tracker.loadNo || pendingInvert.cursor !== tracker.cursor || tracker.inversions !== pendingInvert.inversions + 1)) pendingInvert = null;

    if (pendingInvert && (isSelf || isOpp)) {
      flag("invertLiveOpp", true, isOpp);
      pendingInvert = null;
    }

    if (row.label === "Use inverter" && chamber?.known === "live") pendingInvert = { load: tracker.loadNo, cursor: tracker.cursor, inversions: tracker.inversions };

    flag("cigsFull", tracker.roundHealth > 0 && (ownHealth ?? 0) >= tracker.roundHealth && legal.has("Use cigarettes"), row.label === "Use cigarettes");

    let legalUse = 0;
    let legalSteal = 0;

    ITEMS.forEach((item, index) => {
      if (legal.has(`Use ${item}`)) legalUse |= 1 << index;

      if (legalLabels.some((label) => label.startsWith(`Steal ${item} from `))) legalSteal |= 1 << index;
    });

    const used = row.label.startsWith("Use ") ? itemIndex(row.label.slice(4)) : row.label.startsWith("Jam ") ? JAMMER : -1;
    const stolen = /^Steal (.+?) from /.exec(row.label);
    const steal = stolen ? itemIndex(stolen[1] ?? "") : -1;

    if (used >= 0) seat.used[used] = (seat.used[used] ?? 0) + 1;

    if (steal >= 0) {
      seat.stolen[steal] = (seat.stolen[steal] ?? 0) + 1;
      seat.used[ADRENALINE] = (seat.used[ADRENALINE] ?? 0) + 1;
    }

    if (legal.has("Use jammer") || legalLabels.some((label) => label.startsWith("Jam Player "))) legalUse |= 1 << JAMMER;

    if (legalLabels.some((label) => label.startsWith("Steal "))) legalUse |= 1 << ADRENALINE;

    const calls = perDecision.get(row.id);

    columns.seat.push(seatAt);
    columns.ord.push(row.ord);
    columns.failedCalls.push(calls?.failed ?? 0);
    columns.moveNo.push(moveNo);
    columns.opp.push(chances);
    columns.pick.push(taken);
    columns.rt.push(calls?.rt ?? -1);
    columns.rc.push(calls?.rc ?? 0);
    columns.cost.push(calls?.cost ?? 0);
    columns.lat.push(calls?.lat ?? 0);
    columns.tok.push(calls?.tok ?? 0);
    columns.calls.push(calls?.calls ?? 0);
    columns.legalUse.push(legalUse);
    columns.legalSteal.push(legalSteal);
    columns.useItem.push(steal >= 0 ? ADRENALINE : used);
    columns.stealItem.push(steal);
    columns.shot.push(isOpp ? 1 : isSelf ? 2 : 0);
  }

  finishSeat();
  finishMatch();

  // Faults and reminders come from each match's events.jsonl, keyed by seat position.
  const seatBySource = new Map(
    db
      .query(`select m.source_dir dir, s.position pos, m.id, s.player from matches m join match_seats s on s.match_id = m.id where m.status in ('completed', 'partial')`)
      .all()
      .flatMap((raw) => {
        const row = decodeSeatSource(raw);
        const index = seatIndex.get(`${row.id}|${row.player}`);

        return index === undefined ? [] : [[`${row.dir}|${row.pos}`, index] as const];
      }),
  );

  const notes = db.query(
    `select path, json_extract(raw, '$.kind') kind, json_extract(raw, '$.position') pos from source_records
     where current = 1 and path like '%/events.jsonl' and (raw like '%"kind":"reminder"%' or raw like '%"kind":"fault"%')`,
  );

  for (const raw of notes.iterate()) {
    const note = decodeNote(raw);
    const index = seatBySource.get(`${note.path.slice(0, -"/events.jsonl".length)}|${note.pos}`);
    const seat = index === undefined ? undefined : extra[index];

    if (seat === undefined) continue;

    if (note.kind === "reminder") seat.reminders++;
    else seat.faults++;
  }

  console.log(`analysis: ${columns.seat.length} agent moves in ${Math.round(performance.now() - started)} ms; known-shell predictions matched ${checks.ok}, contradicted ${checks.bad}`);

  return { decisions: { ...columns, checks }, seats: extra };
};
