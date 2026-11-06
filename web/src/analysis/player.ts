import { createHash } from "node:crypto";
import { readFileSync } from "node:fs";
import { join } from "node:path";

import { Schema } from "effect";

import rules, { type BendNode } from "../../generated/rules.mjs";
import { type Game } from "../bend.ts";
import { type GameEvent as Event, GameEvent, Item, type LearnedSecret, Move, Seat, type SeatCount, Secret } from "../domain.ts";

// The minimax player (sim/bend-mp/player/, ADR-0043) for the analysis scripts,
// through its export table sim/bend-mp/analysis.bend. That table is rooted
// beside the rules' own (web.bend), so the board and config the rules build
// returns pass into it unchanged. This module only marshals: a player's own log
// and the public board go into Bend, shell orders and analyses come out. The
// machine state, with its hidden gun, never enters.

const PLAYER_SOURCE = new URL("../../../sim/bend-mp/analysis.bend", import.meta.url).pathname;

interface PlayerExports {
  readonly analyse: (position: BendNode, depth: number, budget: number, reload: BendNode, memo: BendNode) => BendNode;
  readonly orders: (log: BendNode, isPrivate: boolean) => BendNode;
}

// A player's own log
// ==================

/** One entry of a player's log: a public event, or a secret only that player heard. `index` is its place in the match's events or learned secrets. */
export type OwnEntry = { readonly kind: "event"; readonly event: Event; readonly index: number } | { readonly kind: "secret"; readonly secret: Secret; readonly index: number };

/** The seat's whole log, in the order the seat heard it: each event, then the secrets heard after it. A secret's `at` counts the events before it, as the driver records it. */
export const ownLog = (events: ReadonlyArray<Event>, learned: ReadonlyArray<LearnedSecret>, seat: Seat): ReadonlyArray<OwnEntry> => {
  const heardAt = (count: number): ReadonlyArray<OwnEntry> =>
    learned.flatMap((note, index): ReadonlyArray<OwnEntry> => (note.seat === seat && note.at === count ? [{ kind: "secret", secret: note.secret, index }] : []));

  return [...heardAt(0), ...events.flatMap((event, index): ReadonlyArray<OwnEntry> => [{ kind: "event", event, index }, ...heardAt(index + 1)])];
};

// Into Bend
// =========

const bendList = (items: ReadonlyArray<BendNode>): BendNode =>
  // SAFETY: a cons cell is a Bend value; BendNode names only its tag.
  items.reduceRight<BendNode>((tail, head) => ({ $: "Con", head, tail }) as BendNode, { $: "Nil" });

const nodesOf = (list: BendNode): ReadonlyArray<BendNode> => {
  const nodes: Array<BendNode> = [];
  let rest = list;

  while (rest.$ === "Con" && "head" in rest && "tail" in rest) {
    // SAFETY: a Bend cons cell's head and tail are Bend values.
    nodes.push(rest.head as BendNode);
    // SAFETY: as above.
    rest = rest.tail as BendNode;
  }

  return nodes;
};

const tag = (name: string, fields: Readonly<Record<string, BendNode | number>> = {}): BendNode => ({ $: name, ...fields });

const seatNode = (seat: Seat): BendNode => tag(`Seat${seat}`);

const slotNode = (slot: number): BendNode => tag(`Slot${slot}`);

const eventNode = (event: Event): BendNode =>
  GameEvent.match(event, {
    RoundBegan: ({ round, health, first }) => tag("RoundBegan", { round, health, first: seatNode(first) }),
    GrabbingBegan: ({ seats }) => tag("GrabbingBegan", { seats: bendList(seats.map(seatNode)) }),
    Granted: ({ seat, item }) => tag("Granted", { seat: seatNode(seat), item: tag(item) }),
    Placed: ({ seat, slot, item }) => tag("Placed", { seat: seatNode(seat), slot: slotNode(slot), item: tag(item) }),
    GrabbingEnded: ({ seat }) => tag("GrabbingEnded", { seat: seatNode(seat) }),
    DistributionDone: () => tag("DistributionDone"),
    Loaded: ({ load }) => tag("Loaded", { load: tag("Load", { live: load.live, blank: load.blank }) }),
    TurnSkipped: ({ seat }) => tag("TurnSkipped", { seat: seatNode(seat) }),
    JamLifted: ({ seat }) => tag("JamLifted", { seat: seatNode(seat) }),
    TurnGiven: ({ seat }) => tag("TurnGiven", { seat: seatNode(seat) }),
    PickedUp: ({ seat }) => tag("PickedUp", { seat: seatNode(seat) }),
    Fired: ({ shooter, target, shell, captured, applied, health }) =>
      tag("Fired", { shooter: seatNode(shooter), target: seatNode(target), shell: tag(shell), captured: tag(captured), applied, health }),
    Died: ({ seat }) => tag("Died", { seat: seatNode(seat) }),
    Used: ({ seat, owner, slot, item }) => tag("Used", { seat: seatNode(seat), owner: seatNode(owner), slot: slotNode(slot), item: tag(item) }),
    Healed: ({ seat, health }) => tag("Healed", { seat: seatNode(seat), health }),
    Ejected: ({ seat, shell }) => tag("Ejected", { seat: seatNode(seat), shell: tag(shell) }),
    Inverted: ({ seat }) => tag("Inverted", { seat: seatNode(seat) }),
    JamApplied: ({ by, target }) => tag("JamApplied", { by: seatNode(by), target: seatNode(target) }),
    DirectionFlipped: ({ direction }) => tag("DirectionFlipped", { direction: tag(direction) }),
    RoundWon: ({ seat, prize }) => tag("RoundWon", { seat: seatNode(seat), prize }),
    MatchConcluded: () => tag("MatchConcluded"),
  });

const secretNode = (secret: Secret): BendNode =>
  Secret.match(secret, {
    Glimpse: ({ shell }) => tag("Glimpse", { shell: tag(shell) }),
    Clue: ({ position, shell }) => tag("Clue", { position, shell: tag(shell) }),
    NoClue: () => tag("NoClue"),
    EmptyBriefcase: () => tag("EmptyBriefcase"),
  });

export const logNode = (log: ReadonlyArray<OwnEntry>): BendNode =>
  bendList(log.map((entry) => (entry.kind === "event" ? tag("Witnessed", { event: eventNode(entry.event) }) : tag("Learned", { secret: secretNode(entry.secret) }))));

const TABLES = { 2: "TwoSeats", 3: "ThreeSeats", 4: "FourSeats" } as const satisfies Readonly<Record<SeatCount, string>>;

/** The public board at a game's request point, as the rules build returns it. Nothing else is read off the machine state. */
export const boardOf = (game: Game): BendNode => {
  // SAFETY: point returns domain.Point{board, request} (sim/bend-mp/web.bend).
  const point = rules.point(game.state) as BendNode & { readonly board: BendNode };

  return point.board;
};

/** What the player may know at a decision: the match's rules, the public board, and the deciding seat's own log. */
export interface PlayerInput {
  readonly table: SeatCount;
  readonly items: boolean;
  readonly board: BendNode;
  readonly log: ReadonlyArray<OwnEntry>;
  readonly me: Seat;
}

const inputNode = ({ table, items, board, log, me }: PlayerInput): BendNode =>
  // SAFETY: the fields are player/types.Position's, each a Bend value; BendNode names only the tag.
  ({ $: "Position", config: rules.config({ $: TABLES[table] }, items), board, log: logNode(log), me: seatNode(me) }) as BendNode;

// Out of Bend
// ===========

/** Shell orders a log allows, each a string such as "LBL" from the chamber out. Repeated orders carry their weight. */
export type Orders = ReadonlyArray<string>;

const orderText = (order: BendNode): string => nodesOf(order).map((shell) => (shell.$ === "Live" ? "L" : "B")).join("");

const Node = Schema.Struct({ $: Schema.String });

const RawMove = Schema.Union([
  Schema.Struct({ $: Schema.Literal("Shoot"), target: Node }),
  Schema.Struct({ $: Schema.Literal("Use"), item: Node }),
  Schema.Struct({ $: Schema.Literal("Jam"), target: Node }),
  Schema.Struct({ $: Schema.Literal("Steal"), owner: Node, item: Node }),
  Schema.Struct({ $: Schema.Literal("StealJam"), owner: Node, target: Node }),
]);

const RawLine = Schema.Struct({ $: Schema.Literal("Line"), move: RawMove, score: Schema.Number, reach: Schema.Struct({ $: Schema.Literals(["Settled", "Reloads", "Cut"]) }) });

const REACH = { Settled: "settled", Reloads: "reloads", Cut: "cut" } as const;

const RawCached = Schema.Struct({ $: Schema.Literal("Cached"), entries: Schema.Number, hits: Schema.Number, deals: Schema.Number, deal_hits: Schema.Number });

const RawAnalysis = Schema.Union([
  Schema.Struct({ $: Schema.Literal("Analysed"), lines: Schema.Unknown, best: Schema.Number, nodes: Schema.Number, depth: Schema.Number, limited: Schema.Boolean, cached: RawCached }),
  Schema.Struct({ $: Schema.Literal("Invalid"), reason: Schema.String, nodes: Schema.Number }),
]);

const decodeAnalysis = Schema.decodeUnknownSync(RawAnalysis);

const decodeLine = Schema.decodeUnknownSync(RawLine);

const decodeSeat = Schema.decodeUnknownSync(Seat);

const decodeItem = Schema.decodeUnknownSync(Item);

const seatOf = (node: typeof Node.Type): Seat => decodeSeat(Number(node.$.replace("Seat", "")));

const itemOf = (node: typeof Node.Type): Item => decodeItem(node.$);

/**
 * A whole move as the machine steps an agent's move chains, so that agentMoveText (src/text.ts) words it as the arena did.
 * The player names items, not slots, and agentMoveText reads no slot, so slots are given as 0.
 */
const stepsOf = (move: typeof RawMove.Type): ReadonlyArray<Move> => {
  const use = (item: Item): Move => Move.cases.UseItem.make({ slot: 0, item });

  switch (move.$) {
    case "Shoot":
      return [Move.cases.PickUp.make({}), Move.cases.Shoot.make({ target: seatOf(move.target) })];
    case "Use":
      return [use(itemOf(move.item))];
    case "Jam":
      return [use("Jammer"), Move.cases.JamTarget.make({ target: seatOf(move.target) })];
    case "Steal":
      return [use("Adrenaline"), Move.cases.Steal.make({ owner: seatOf(move.owner), slot: 0, item: itemOf(move.item) })];
    case "StealJam":
      return [use("Adrenaline"), Move.cases.Steal.make({ owner: seatOf(move.owner), slot: 0, item: "Jammer" }), Move.cases.JamTarget.make({ target: seatOf(move.target) })];
  }
};

/** One legal move and its score: the deciding seat's chance of winning the current round, in millionths. */
export interface Line {
  readonly steps: ReadonlyArray<Move>;
  readonly score: number;
  /** How its leaves ended: every round settled, some at a reload (valued by the reload rule), or some where the depth ran out. Only "cut" can change at more depth. */
  readonly reach: "settled" | "reloads" | "cut";
}

/** The player's search from one position: every legal move in the machine's order, the first best one, and how far the search got. */
export type Analysis =
  | {
      readonly kind: "analysed";
      readonly lines: ReadonlyArray<Line>;
      readonly best: number;
      /** Decisions searched. At 0 every move has the static value before any move: the fallback when `limited` is set, or a search asked for no depth. */
      readonly depth: number;
      /** The node budget ran out before the next depth finished. */
      readonly limited: boolean;
      readonly nodes: number;
      /** What the memo held at the end: decision nodes and reload deals stored, and how often each was reused. */
      readonly cached: { readonly entries: number; readonly hits: number; readonly deals: number; readonly dealHits: number };
    }
  | { readonly kind: "invalid"; readonly reason: string; readonly nodes: number };

const analysisOf = (raw: typeof RawAnalysis.Type): Analysis =>
  raw.$ === "Invalid"
    ? { kind: "invalid", reason: raw.reason, nodes: raw.nodes }
    : {
        kind: "analysed",
        // SAFETY: Analysed.lines is a Bend List<Line>.
        lines: nodesOf(raw.lines as BendNode).map((node) => {
          const line = decodeLine(node);

          return { steps: stepsOf(line.move), score: line.score, reach: REACH[line.reach.$] };
        }),
        best: raw.best,
        depth: raw.depth,
        limited: raw.limited,
        nodes: raw.nodes,
        cached: { entries: raw.cached.entries, hits: raw.cached.hits, deals: raw.cached.deals, dealHits: raw.cached.deal_hits },
      };

// The player
// ==========

/** A search's bounds: at most `depth` decisions, by every player, and at most `budget` expanded nodes. */
export interface Limits {
  readonly depth: number;
  readonly budget: number;
}

/**
 * How the search values a reload it stops at: the static evaluation before the draw, that evaluation averaged over every distinct deal
 * of the reload, or its mean over `samples` deals drawn at random (both two seats only; at three or four the analysis is invalid).
 * See docs/arena/analysis/regret.md.
 */
export const RELOAD_RULES = ["static", "expected-deal", "sampled"] as const;

export type ReloadRule = (typeof RELOAD_RULES)[number];

export type Reload = { readonly rule: "static" } | { readonly rule: "expected-deal" } | { readonly rule: "sampled"; readonly samples: number };

const reloadNode = (reload: Reload): BendNode => {
  switch (reload.rule) {
    case "static":
      return { $: "Static" };
    case "expected-deal":
      return { $: "ExpectedDeal" };
    case "sampled":
      // SAFETY: count is player/types.Sampled's one field, a Nat; BendNode names only the tag.
      return { $: "Sampled", count: reload.samples } as BendNode;
  }
};

/**
 * How the search reuses a position it has already valued. "off" searches every node again. "charged" reuses the value but spends the nodes
 * its first search spent, so scores, nodes and the depth reached match "off" exactly. "free" spends nothing on reuse, so the same budget
 * reaches deeper.
 */
export type Memo = "off" | "charged" | "free";

const MEMO_TAGS = { off: "Off", charged: "Charged", free: "Free" } as const satisfies Record<Memo, string>;

const memoNode = (memo: Memo): BendNode => ({ $: MEMO_TAGS[memo] });

export interface Player {
  /** Names the build: a hash of the compiled player, so that scores from different versions are never mixed. */
  readonly version: string;
  readonly orders: (log: ReadonlyArray<OwnEntry>, isPrivate: boolean) => Orders;
  readonly analyse: (input: PlayerInput, limits: Limits, reload: Reload, memo?: Memo) => Analysis;
}

/** Builds the player into `dir` (with $BEND, else `bend` on PATH) and wraps its exports. */
export const loadPlayer = async (dir: string): Promise<Player> => {
  const bend = process.env["BEND"] ?? Bun.which("bend") ?? undefined;

  if (bend === undefined) throw new Error("bend not found: run inside `nix develop`, or set BEND to the pinned Bend binary");

  const output = join(dir, "player.mjs");
  const build = Bun.spawnSync([bend, PLAYER_SOURCE, "-o", output], { stdout: "pipe", stderr: "pipe" });

  if (build.exitCode !== 0) throw new Error(`Bend player build failed:\n${build.stdout.toString()}${build.stderr.toString()}`);

  const loaded: { readonly default: PlayerExports } = await import(output);
  const exports = loaded.default;

  return {
    version: createHash("sha256").update(readFileSync(output)).digest("hex").slice(0, 16),
    orders: (log, isPrivate) => nodesOf(exports.orders(logNode(log), isPrivate)).map(orderText),
    analyse: (input, { depth, budget }, reload, memo = "charged") =>
      analysisOf(decodeAnalysis(exports.analyse(inputNode(input), depth, budget, reloadNode(reload), memoNode(memo)))),
  };
};
