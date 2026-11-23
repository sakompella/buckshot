import type { Database } from "bun:sqlite";

import { Schema } from "effect";

import { GameEvent, Seat, Secret } from "../domain.ts";
import type { Item } from "../domain.ts";
import { Letter, rosterOf } from "../players.ts";
import type { Roster } from "../players.ts";
import { itemName } from "../text.ts";
import { ITEMS, NO_GAP, patternBit } from "./api.ts";
import { readOnly } from "./read-only.ts";
import type { Decisions, Pattern, SeatAnalysis, Shell, Story } from "./api.ts";

// Per-decision columns for choice patterns, items, reasoning and compute, worked out once at server start.
// Each player's view is what it heard up to each of its decisions: the match's replayed events and its own secrets,
// as the importer stored them (events, secrets and decisions.events_before in docs/arena/database.md).
// What a player knew of the gun (the chambered shell, its odds, the saw) comes from the knowledge database, the Bend
// belief over the player's own log; without one, no chamber pattern or odds is counted.

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

const SecretRow = Schema.Struct({ socket: Seat, at: Schema.Finite, secret: Schema.fromJsonString(Secret) });

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

/** What a socket heard while the events out went from `from` to `to`: each event, then the secrets it learned once that event was out (text.ts heardBy). */
export const heardBetween = (log: MatchLog, socket: Seat, from: number, to: number): ReadonlyArray<Heard> =>
  log.events.slice(from, to).flatMap((event, offset) => [event, ...log.secrets.flatMap((note) => (note.socket === socket && note.at === from + offset + 1 ? [note.secret] : []))]);

/** The chambered shell as one player knows it: its type and how it knows, or only the chance it is live. */
export interface Chamber {
  readonly known: Shell | null;
  readonly by: "glass" | "phone" | "count" | null;
  readonly pLive: number;
}

/** What a player knew at one decision, from the knowledge database (scripts/arena-knowledge.ts, the Bend belief over its own log). */
export interface Knowledge {
  /** Null when the gun holds no shell. */
  readonly chamber: Chamber | null;
  readonly sawed: boolean;
  /** The shells left in the gun, and the round, to tell one shell from the next. */
  readonly remaining: number;
  readonly round: number;
}

const KnowledgeRow = Schema.Struct({
  matchId: Schema.String,
  ordinal: Schema.Finite,
  round: Schema.Finite,
  remaining: Schema.Finite,
  sawed: Schema.Finite,
  chamber: Schema.NullOr(Schema.Literals(["Live", "Blank"])),
  source: Schema.NullOr(Schema.Literals(["glass", "phone", "public", "combined"])),
  /** The share of the shell orders the player still holds possible with a live shell chambered; null with none. */
  pLive: Schema.NullOr(Schema.Finite),
});

const decodeKnowledgeRow = Schema.decodeUnknownSync(KnowledgeRow);

const chamberOf = ({ chamber, source, pLive }: typeof KnowledgeRow.Type): Chamber | null => {
  if (chamber !== null) { return { known: chamber === "Live" ? "live" : "blank", by: source === "glass" || source === "phone" ? source : "count", pLive: chamber === "Live" ? 1 : 0 }; }

  return pLive === null ? null : { known: null, by: null, pLive };
};

/** Each agent decision's knowledge, by "<match id>|<ordinal>". */
export const openKnowledge = (path: string): ReadonlyMap<string, Knowledge> =>
  readOnly(path, (db) =>
    new Map(
      db
        .query(
          `select match_id matchId, ordinal, round, remaining, sawed, chamber, source,
             case when private_orders > 0 and remaining > 0 then json_extract(private_live_json, '$[0]') * 1.0 / private_orders end pLive
           from decisions where by_whom = 'agent'`,
        )
        .all()
        .map((raw) => {
          const row = decodeKnowledgeRow(raw);

          return [`${row.matchId}|${row.ordinal}`, { chamber: chamberOf(row), sawed: row.sawed === 1, remaining: row.remaining, round: row.round }] as const;
        }),
    ),
  );

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

      if (event.round === 0) { starter = log.roster.playerOf(event.first).letter; }
    } else if (GameEvent.guards.RoundWon(event)) { rounds.push({ winner: log.roster.playerOf(event.seat).letter, prize: event.prize }); }
  }

  const isPaid = [...cash].every(([player, total]) => total === sumOf(rounds.flatMap(({ winner, prize }) => (winner === player ? [prize] : []))));

  return { starter, rounds, ok: rounds.length === begun && isPaid };
};

export interface SeatKey {
  readonly matchId: string;
  readonly player: string;
  readonly cash: number | null;
}

const VisiblePlayer = Schema.Struct({ player: Schema.String, health: Schema.optional(Schema.Finite), items: Schema.optional(Schema.Array(Schema.String)) });

export const Visible = Schema.fromJsonString(Schema.Struct({ you: Schema.String, players: Schema.Array(VisiblePlayer) }));

export const decodeVisible = Schema.decodeUnknownSync(Visible);

const decodeLegal = Schema.decodeUnknownSync(Schema.fromJsonString(Schema.Array(Schema.Struct({ label: Schema.String }))));

const PerDecisionRow = Schema.Struct({
  d: Schema.String,
  rt: Schema.NullOr(Schema.Finite),
  nulls: Schema.Finite,
  out: Schema.Finite,
  cost: Schema.NullOr(Schema.Finite),
  lat: Schema.NullOr(Schema.Finite),
  tok: Schema.Finite,
});

const DecisionRow = Schema.Struct({
  m: Schema.String,
  p: Schema.String,
  w: Schema.String,
  label: Schema.String,
  v: Schema.String,
  legal: Schema.NullOr(Schema.String),
  id: Schema.String,
  ord: Schema.Finite,
  e: Schema.Finite,
  s: Seat,
});

const decodePerDecision = Schema.decodeUnknownSync(PerDecisionRow);

const decodeDecision = Schema.decodeUnknownSync(DecisionRow);

const itemNames: ReadonlyArray<string> = ITEMS;

const itemIndex = (name: string): number => itemNames.indexOf(name);

const itemColumn = (item: Item): number => {
  const index = itemIndex(itemName(item));

  if (index < 0) { throw new Error(`no item column for ${item}`); }

  return index;
};

/** Each player's items, in ITEMS order, from the match's events: placed from the briefcase, used, and taken from another player and used. */
export const itemsOf = (log: Pick<MatchLog, "events" | "roster">): ReadonlyMap<string, Pick<SeatTally, "acquired" | "used" | "stolen">> => {
  const tallies = new Map<string, Pick<SeatTally, "acquired" | "used" | "stolen">>(log.roster.players.map(({ letter }) => [letter, { acquired: ITEMS.map(() => 0), used: ITEMS.map(() => 0), stolen: ITEMS.map(() => 0) }]));

  const count = (seat: Seat, kind: "acquired" | "used" | "stolen", item: Item) => {
    const counts = tallies.get(log.roster.playerOf(seat).letter)?.[kind];

    if (counts) { counts[itemColumn(item)] = (counts[itemColumn(item)] ?? 0) + 1; }
  };

  for (const event of log.events) {
    if (GameEvent.guards.Placed(event)) { count(event.seat, "acquired", event.item); }
    else if (GameEvent.guards.Used(event)) { count(event.seat, event.seat === event.owner ? "used" : "stolen", event.item); }
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

type MutableColumns = { -readonly [K in keyof Decisions]: Array<number> };

/** An inverter use on a known live shell, tied to that shell: the same round with the same shells left. */
type PendingInvert = Pick<Knowledge, "round" | "remaining">;

/** Works out the decision columns and each seat's analysis. seatIndex maps `matchId|player` to a place in seats. */
export interface Analysis {
  readonly decisions: Decisions;
  readonly seats: ReadonlyArray<SeatAnalysis>;
}

export const analyse = (db: Database, seats: ReadonlyArray<SeatKey>, seatIndex: ReadonlyMap<string, number>, knowledge: ReadonlyMap<string, Knowledge>): Analysis => {
  const started = performance.now();

  // Several calls (retries, reminders, failed attempts) link to one decision (calls.link_method), so every linked call is added up per decision first.
  const perDecision = new Map(
    db
      .query(
        `select decision_id d, sum(reasoning_tokens) rt, sum(reasoning_tokens is null) nulls,
           sum(coalesce(output_tokens, 0)) out, sum(cost_usd) cost, sum(case when status = 'returned' then latency_ms end) lat,
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

  const seatsOf = new Map<string, Array<number>>();

  for (const [index, seat] of seats.entries()) { seatsOf.set(seat.matchId, [...(seatsOf.get(seat.matchId) ?? []), index]); }

  let roundHealth = 0;
  let currentSeat = "";
  let currentMatch = "";
  let pendingInvert: PendingInvert | null = null;
  let log: MatchLog | null = null;
  let heardTo = 0;

  const finishMatch = () => {
    if (log === null) { return; }

    const indexes = seatsOf.get(currentMatch) ?? [];
    const cash = new Map(indexes.flatMap((index) => seats[index] ?? []).map((seat) => [seat.player, seat.cash ?? 0]));
    const story = roundStory(log, cash);
    const items = itemsOf(log);

    for (const index of indexes) {
      const seat = extra[index];
      const tally = items.get(seats[index]?.player ?? "");

      if (seat) { Object.assign(seat, { story }, tally); }
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
      currentSeat = `${row.m}|${row.p}`;
      roundHealth = 0;
      pendingInvert = null;
      heardTo = 0;
    }

    const seatAt = seatIndex.get(currentSeat);
    const seat = seatAt === undefined ? undefined : extra[seatAt];

    if (seatAt === undefined || seat === undefined || log === null) { continue; }

    const visible = decodeVisible(row.v);

    for (const heard of heardBetween(log, row.s, heardTo, row.e)) {
      if (GameEvent.guards.RoundBegan(heard)) {
        roundHealth = heard.health;
        seat.round = heard.round + 1;
        seat.deficits.push(0);
      }
    }

    heardTo = row.e;

    const ownHealth = visible.players.find(({ player }) => player === visible.you)?.health;
    const opponentHealth = visible.players.find(({ player }) => player !== visible.you)?.health;

    const worst = seat.deficits.at(-1);

    if (ownHealth !== undefined && opponentHealth !== undefined && worst !== undefined && opponentHealth - ownHealth > worst) { seat.deficits[seat.deficits.length - 1] = opponentHealth - ownHealth; }

    if (row.w !== "agent") { continue; }

    const legal = new Set(decodeLegal(row.legal ?? "[]").map(({ label }) => label));
    const legalLabels = [...legal];
    const isSelf = row.label === "Shoot yourself";
    const isOpp = row.label.startsWith("Shoot Player ");
    const known = knowledge.get(`${row.m}|${row.ord}`);
    const chamber = known?.chamber ?? null;
    let chances = 0;
    let taken = 0;

    const flag = (pattern: Pattern, isAvailable: boolean, isChosen: boolean) => {
      if (!isAvailable) { return; }

      chances |= patternBit(pattern);

      if (isChosen) { taken |= patternBit(pattern); }
    };

    if (chamber && known) { for (const [pattern, isAvailable, isChosen] of chamberPatterns(chamber, known.sawed, legal, row.label)) {flag(pattern, isAvailable, isChosen); }}

    // Inverting a known live shell, then shooting the opponent with the now blank shell: checked at the next shot,
    // which must be at the same shell, still blank (not inverted back).
    if (pendingInvert && (pendingInvert.round !== known?.round || pendingInvert.remaining !== known.remaining || chamber?.known !== "blank")) { pendingInvert = null; }

    if (pendingInvert && (isSelf || isOpp)) {
      flag("invertLiveOpp", true, isOpp);
      pendingInvert = null;
    }

    if (row.label === "Use inverter" && chamber?.known === "live" && known) { pendingInvert = { round: known.round, remaining: known.remaining }; }

    flag("cigsFull", roundHealth > 0 && (ownHealth ?? 0) >= roundHealth && legal.has("Use cigarettes"), row.label === "Use cigarettes");

    let legalUse = 0;
    let legalSteal = 0;

    ITEMS.forEach((item, index) => {
      if (legal.has(`Use ${item}`)) { legalUse |= 1 << index; }

      if (legalLabels.some((label) => label.startsWith(`Steal ${item} from `))) { legalSteal |= 1 << index; }
    });

    const used = row.label.startsWith("Use ") ? itemIndex(row.label.slice(4)) : row.label.startsWith("Jam ") ? JAMMER : -1;
    const stolen = /^Steal (.+?) from /.exec(row.label);
    const steal = stolen ? itemIndex(stolen[1] ?? "") : -1;

    if (legal.has("Use jammer") || legalLabels.some((label) => label.startsWith("Jam Player "))) { legalUse |= 1 << JAMMER; }

    if (legalLabels.some((label) => label.startsWith("Steal "))) { legalUse |= 1 << ADRENALINE; }

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

  finishMatch();

  console.log(`analysis: ${columns.seat.length} agent moves in ${Math.round(performance.now() - started)} ms`);

  return { decisions: columns, seats: extra };
};
