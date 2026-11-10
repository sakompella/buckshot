import type { Database } from "bun:sqlite";

import { Schema } from "effect";

import { GameEvent, type Item, Seat, Secret, type Shell as Loaded } from "../domain.ts";
import { Letter, type Roster, rosterOf } from "../players.ts";
import { itemName } from "../text.ts";
import { type Decisions, ITEMS, NO_GAP, type Pattern, patternBit, type SeatAnalysis, type Shell, type Story } from "./api.ts";

// Per-decision columns for choice patterns, items, reasoning and compute, worked out once at server start.
// Each player's view is what it heard up to each of its decisions: the match's replayed events and its own secrets,
// as the importer stored them (events, secrets and decisions.events_before in docs/arena/database.md).
// Rules checked against sim/bend-mp/sm/main.bend: cigarettes heal only below round health, any shot clears the saw,
// a blank self-shot keeps the turn; phone positions count from 1 = the chambered shell (src/text.ts).
// This tracks the events, not a Bend replay of beliefs: it knows counts, glass and phone clues, inversions and racks.

const flip = (shell: Shell): Shell => (shell === "live" ? "blank" : "live");

const shellOf = (shell: Loaded): Shell => (shell === "Live" ? "live" : "blank");

/** One thing a player heard: a public event, or a secret only it learned. The two unions share no tag. */
export type Heard = GameEvent | Secret;

export const isSecret = Schema.is(Secret);

/** A match's replayed events, the secrets each socket learned (at: the events out by then), and its roster. */
export interface MatchLog {
  readonly events: ReadonlyArray<GameEvent>;
  readonly secrets: ReadonlyArray<{ readonly socket: Seat; readonly at: number; readonly secret: Secret }>;
  readonly roster: Roster;
}

const decodeEvent = Schema.decodeUnknownSync(Schema.fromJsonString(GameEvent));

const SecretRow = Schema.Struct({ socket: Seat, at: Schema.Number, secret: Schema.fromJsonString(Secret) });

const decodeSecret = Schema.decodeUnknownSync(SecretRow);

const decodeSocket = Schema.decodeUnknownSync(Schema.Struct({ player: Letter, socket: Seat }));

export const matchLog = (db: Database, matchId: string): MatchLog => {
  const sockets = db.query("select player, socket from match_seats where match_id = ? and socket is not null").all(matchId).map((row) => decodeSocket(row));

  return {
    events: db.query<{ json: string }, [string]>("select json from events where match_id = ? order by idx").all(matchId).map(({ json }) => decodeEvent(json)),
    secrets: db.query("select socket, at, json secret from secrets where match_id = ? order by idx").all(matchId).map((row) => decodeSecret(row)),
    roster: rosterOf(sockets.map(({ socket }) => socket), new Map(sockets.map(({ player, socket }) => [socket, player]))),
  };
};

/** What a socket heard while the events out went from `from` to `to`: each event, then the secrets it learned once that event was out (import.ts heardBy). */
export const heardBetween = (log: MatchLog, socket: Seat, from: number, to: number): ReadonlyArray<Heard> =>
  log.events.slice(from, to).flatMap((event, offset) => [event, ...log.secrets.flatMap((note) => (note.socket === socket && note.at === from + offset + 1 ? [note.secret] : []))]);

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
  live = 0;
  blank = 0;
  cursor = 0;
  total = 0;
  inverted = false;
  sawed = false;
  readonly known = new Map<number, { shell: Shell; by: Clue }>();
  readonly checks = { ok: 0, bad: 0 };
  loadNo = 0;
  /** Inversions seen, so a pending inverter use can tell its own inversion from later ones. */
  inversions = 0;

  hear(heard: Heard): void {
    if (isSecret(heard)) {
      Secret.matchOrElse(
        heard,
        {
          Glimpse: ({ shell }) => this.known.set(this.cursor, { shell: shellOf(shell), by: "glass" }),
          Clue: ({ position, shell }) => this.known.set(this.cursor + position - 1, { shell: shellOf(shell), by: "phone" }),
        },
        () => undefined,
      );

      return;
    }

    GameEvent.matchOrElse(
      heard,
      {
        RoundBegan: ({ health }) => {
          this.roundHealth = health;
        },
        Loaded: ({ load }) => {
          this.loadNo++;
          this.live = load.live;
          this.blank = load.blank;
          this.total = this.live + this.blank;
          this.cursor = 0;
          this.inverted = false;
          this.sawed = false;
          this.known.clear();
        },
        Inverted: () => {
          this.inverted = !this.inverted;
          this.inversions++;
          const clue = this.known.get(this.cursor);

          if (clue) clue.shell = flip(clue.shell);
        },
        Used: ({ item }) => {
          if (item === "Saw") this.sawed = true;
        },
        Fired: ({ shell }) => this.spend(shellOf(shell), true),
        Ejected: ({ shell }) => this.spend(shellOf(shell), false),
      },
      () => undefined,
    );
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

/**
 * The shot and glass patterns a move had the chance to show, given the chamber as the player knows it: each pattern,
 * whether it was available, and whether the move took it. A blank shot at oneself keeps the turn, across a reload too.
 */
export const chamberPatterns = (chamber: Chamber, isSawed: boolean, legal: ReadonlySet<string>, label: string): ReadonlyArray<readonly [Pattern, boolean, boolean]> => {
  const canSelf = legal.has("Shoot yourself");
  const canOpp = [...legal].some((move) => move.startsWith("Shoot Player "));
  const isSelf = label === "Shoot yourself";
  const isOpp = label.startsWith("Shoot Player ");
  const byItem = chamber.by === "glass" || chamber.by === "phone";

  return [
    ["knownBlankOpp", byItem && chamber.known === "blank" && canOpp, isOpp],
    ["glassBlankOpp", chamber.by === "glass" && chamber.known === "blank" && canOpp, isOpp],
    ["knownLiveSelf", byItem && chamber.known === "live" && canSelf, isSelf],
    ["countLiveSelf", chamber.by === "count" && chamber.known === "live" && canSelf, isSelf],
    ["countBlankOpp", chamber.by === "count" && chamber.known === "blank" && canOpp, isOpp],
    ["sawSelf", isSawed && chamber.known !== "blank" && canSelf, isSelf],
    ["oddsLiveSelf", chamber.known === null && chamber.pLive > 0.5 && canSelf, isSelf],
    ["oddsBlankOpp", chamber.known === null && chamber.pLive < 0.5 && canOpp, isOpp],
    ["tieSelf", chamber.known === null && chamber.pLive === 0.5 && canSelf, isSelf],
    ["glassKnown", chamber.known !== null && legal.has("Use magnifying glass"), label === "Use magnifying glass"],
  ];
};

const sumOf = (values: ReadonlyArray<number>): number => values.reduce((total, value) => total + value, 0);

/** Round winners and prizes from the match's events; ok means every round begun has a winner and each player's prizes sum to its final cash. */
export const roundStory = (log: Pick<MatchLog, "events" | "roster">, cash: ReadonlyMap<string, number>): Story => {
  let starter: string | null = null;
  let begun = 0;
  const rounds: Array<Story["rounds"][number]> = [];

  for (const event of log.events) {
    if (GameEvent.guards.RoundBegan(event)) {
      begun++;

      if (event.round === 0) starter = log.roster.playerOf(event.first).letter;
    } else if (GameEvent.guards.RoundWon(event)) rounds.push({ winner: log.roster.playerOf(event.seat).letter, prize: event.prize });
  }

  const isPaid = [...cash].every(([player, total]) => total === sumOf(rounds.flatMap(({ winner, prize }) => (winner === player ? [prize] : []))));

  return { starter, rounds, ok: rounds.length === begun && isPaid };
};

export interface SeatKey {
  readonly matchId: string;
  readonly player: string;
  readonly cash: number | null;
}

const VisiblePlayer = Schema.Struct({ player: Schema.String, health: Schema.optional(Schema.Number), items: Schema.optional(Schema.Array(Schema.String)) });

export const Visible = Schema.fromJsonString(Schema.Struct({ you: Schema.String, players: Schema.Array(VisiblePlayer) }));

export const decodeVisible = Schema.decodeUnknownSync(Visible);

const decodeLegal = Schema.decodeUnknownSync(Schema.fromJsonString(Schema.Array(Schema.Struct({ label: Schema.String }))));

const PerDecisionRow = Schema.Struct({
  d: Schema.String,
  rt: Schema.NullOr(Schema.Number),
  nulls: Schema.Number,
  out: Schema.Number,
  cost: Schema.NullOr(Schema.Number),
  lat: Schema.NullOr(Schema.Number),
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
  e: Schema.Number,
  s: Seat,
});

const decodePerDecision = Schema.decodeUnknownSync(PerDecisionRow);

const decodeDecision = Schema.decodeUnknownSync(DecisionRow);

const itemIndex = (name: string): number => ITEMS.findIndex((item) => item === name);

const itemColumn = (item: Item): number => {
  const index = itemIndex(itemName(item));

  if (index < 0) throw new Error(`no item column for ${item}`);

  return index;
};

/** Each player's items, in ITEMS order, from the match's events: placed from the briefcase, used, and taken from another player and used. */
export const itemsOf = (log: Pick<MatchLog, "events" | "roster">): ReadonlyMap<string, Pick<SeatTally, "acquired" | "used" | "stolen">> => {
  const tallies = new Map<string, Pick<SeatTally, "acquired" | "used" | "stolen">>(log.roster.players.map(({ letter }) => [letter, { acquired: ITEMS.map(() => 0), used: ITEMS.map(() => 0), stolen: ITEMS.map(() => 0) }]));

  const add = (counts: Array<number> | undefined, item: Item) => {
    if (counts) counts[itemColumn(item)] = (counts[itemColumn(item)] ?? 0) + 1;
  };

  for (const event of log.events) {
    if (GameEvent.guards.Placed(event)) add(tallies.get(log.roster.playerOf(event.seat).letter)?.acquired, event.item);
    else if (GameEvent.guards.Used(event)) {
      const tally = tallies.get(log.roster.playerOf(event.seat).letter);

      add(event.seat === event.owner ? tally?.used : tally?.stolen, event.item);
    }
  }

  return tallies;
};

const ADRENALINE = itemIndex("adrenaline");

const JAMMER = itemIndex("jammer");

interface SeatTally {
  acquired: Array<number>;
  used: Array<number>;
  stolen: Array<number>;
  story: Story | null;
  round: number;
  roundThree: [number, number] | null;
  deficits: Array<number>;
}

const emptySeat = (): SeatTally => ({
  acquired: ITEMS.map(() => 0),
  used: ITEMS.map(() => 0),
  stolen: ITEMS.map(() => 0),
  story: null,
  round: 0,
  roundThree: null,
  deficits: [],
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
  readonly seats: ReadonlyArray<SeatAnalysis>;
}

export const analyse = (db: Database, seats: ReadonlyArray<SeatKey>, seatIndex: ReadonlyMap<string, number>): Analysis => {
  const started = performance.now();

  // Several calls (retries, reminders, failed attempts) link to one decision (calls.link_method), so every linked call is added up per decision first.
  const perDecision = new Map(
    db
      .query(
        `select decision_id d, sum(reasoning_tokens) rt, sum(reasoning_tokens is null) nulls,
           sum(coalesce(output_tokens, 0)) out, sum(cost_usd) cost, sum(latency_ms) lat,
           sum(coalesce(input_tokens, 0) + coalesce(output_tokens, 0) + coalesce(cache_read_tokens, 0) + coalesce(cache_write_tokens, 0)) tok
         from calls where decision_id is not null group by decision_id`,
      )
      .all()
      .map((raw) => {
        const row = decodePerDecision(raw);

        return [row.d, { rt: row.nulls === 0 ? (row.rt ?? 0) : -1, out: row.out, cost: row.cost ?? 0, lat: row.lat ?? 0, tok: row.tok }] as const;
      }),
  );

  const extra = seats.map(() => emptySeat());
  const columns: MutableColumns = { seat: [], ord: [], opp: [], pick: [], rt: [], out: [], gap: [], cost: [], lat: [], tok: [], legalUse: [], legalSteal: [], useItem: [], stealItem: [], shot: [], odds: [] };
  const checks = { ok: 0, bad: 0 };

  const seatsOf = new Map<string, Array<number>>();

  seats.forEach((seat, index) => seatsOf.set(seat.matchId, [...(seatsOf.get(seat.matchId) ?? []), index]));

  let tracker = new ShellTracker();
  let currentSeat = "";
  let currentMatch = "";
  let pendingInvert: PendingInvert | null = null;
  let log: MatchLog | null = null;
  let heardTo = 0;

  const finishSeat = () => {
    checks.ok += tracker.checks.ok;
    checks.bad += tracker.checks.bad;
  };

  const finishMatch = () => {
    if (log === null) return;

    const indexes = seatsOf.get(currentMatch) ?? [];
    const cash = new Map(indexes.flatMap((index) => seats[index] ?? []).map((seat) => [seat.player, seat.cash ?? 0]));
    const story = roundStory(log, cash);
    const items = itemsOf(log);

    for (const index of indexes) {
      const seat = extra[index];
      const tally = items.get(seats[index]?.player ?? "");

      if (seat) Object.assign(seat, { story }, tally);
    }
  };

  const decisions = db.query(
    `select d.match_id m, d.player p, d.by_whom w, d.label, d.visible_json v, d.legal_json legal, d.id, d.ordinal ord, d.events_before e, ms.socket s
     from decisions d join matches m on m.id = d.match_id join match_seats ms on ms.match_id = d.match_id and ms.player = d.player
     where m.status in ('completed', 'partial') and d.visible_json is not null order by d.match_id, d.player, d.ordinal`,
  );

  for (const raw of decisions.iterate()) {
    const row = decodeDecision(raw);

    if (row.m !== currentMatch) {
      finishMatch();
      currentMatch = row.m;
      log = matchLog(db, row.m);
    }

    if (`${row.m}|${row.p}` !== currentSeat) {
      finishSeat();
      currentSeat = `${row.m}|${row.p}`;
      tracker = new ShellTracker();
      pendingInvert = null;
      heardTo = 0;
    }

    const seatAt = seatIndex.get(currentSeat);
    const seat = seatAt === undefined ? undefined : extra[seatAt];

    if (seatAt === undefined || seat === undefined || log === null) continue;

    const visible = decodeVisible(row.v);

    for (const heard of heardBetween(log, row.s, heardTo, row.e)) {
      tracker.hear(heard);

      if (GameEvent.guards.RoundBegan(heard)) {
        seat.round = heard.round + 1;
        seat.deficits.push(0);
      }
    }

    heardTo = row.e;

    const ownHealth = visible.players.find(({ player }) => player === visible.you)?.health;
    const opponentHealth = visible.players.find(({ player }) => player !== visible.you)?.health;

    const worst = seat.deficits.at(-1);

    if (ownHealth !== undefined && opponentHealth !== undefined && worst !== undefined && opponentHealth - ownHealth > worst) seat.deficits[seat.deficits.length - 1] = opponentHealth - ownHealth;

    if (row.w !== "agent") continue;

    const legal = new Set(decodeLegal(row.legal ?? "[]").map(({ label }) => label));
    const legalLabels = [...legal];
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

    if (chamber) for (const [pattern, isAvailable, isChosen] of chamberPatterns(chamber, tracker.sawed, legal, row.label)) flag(pattern, isAvailable, isChosen);

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

    if (legal.has("Use jammer") || legalLabels.some((label) => label.startsWith("Jam Player "))) legalUse |= 1 << JAMMER;

    if (legalLabels.some((label) => label.startsWith("Steal "))) legalUse |= 1 << ADRENALINE;

    const calls = perDecision.get(row.id);

    if (seat.round === 3) {
      const [moves, outputTokens] = seat.roundThree ?? [0, 0];

      seat.roundThree = [moves + 1, outputTokens + (calls?.out ?? 0)];
    }

    columns.seat.push(seatAt);
    columns.ord.push(row.ord);
    columns.opp.push(chances);
    columns.pick.push(taken);
    columns.rt.push(calls?.rt ?? -1);
    columns.out.push(calls?.out ?? 0);
    columns.gap.push(visible.players.length === 2 && ownHealth !== undefined && opponentHealth !== undefined ? ownHealth - opponentHealth : NO_GAP);
    columns.cost.push(calls?.cost ?? 0);
    columns.lat.push(calls?.lat ?? 0);
    columns.tok.push(calls?.tok ?? 0);
    columns.legalUse.push(legalUse);
    columns.legalSteal.push(legalSteal);
    columns.useItem.push(steal >= 0 ? ADRENALINE : used);
    columns.stealItem.push(steal);
    columns.shot.push(isOpp ? 1 : isSelf ? 2 : 0);
    columns.odds.push(chamber !== null && (isSelf || isOpp) && chamber.by !== "glass" && chamber.by !== "phone" ? Math.round(chamber.pLive * 100) : -1);
  }

  finishSeat();
  finishMatch();

  console.log(`analysis: ${columns.seat.length} agent moves in ${Math.round(performance.now() - started)} ms; known-shell predictions matched ${checks.ok}, contradicted ${checks.bad}`);

  return { decisions: { ...columns, checks }, seats: extra };
};
