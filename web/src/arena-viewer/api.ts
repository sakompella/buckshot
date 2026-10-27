import { Schema } from "effect";

// The arena viewer's JSON API: what its server encodes and its page decodes.
// The server reads the analysis database (docs/arena/database.md) read-only.

const Count = Schema.NullOr(Schema.Number);

/** A tally per item, in ITEMS order. */
const PerItem = Schema.Array(Schema.Number);

export const ITEMS = ["magnifying glass", "burner phone", "handsaw", "beer", "cigarettes", "inverter", "jammer", "adrenaline"] as const;

export const Round = Schema.Struct({ winner: Schema.String, prize: Schema.Number, inferred: Schema.Boolean });

/** Round winners and prizes from the public events; ok means every player's prizes sum exactly to its final cash. */
export const Story = Schema.Struct({ starter: Schema.NullOr(Schema.String), rounds: Schema.Array(Round), ok: Schema.Boolean });

export type Story = typeof Story.Type;

/** One player of one started match, as the database has it. Costs and tokens include failed calls and partial matches. */
export const SeatRow = Schema.Struct({
  tournament: Schema.String,
  matchId: Schema.String,
  matchName: Schema.String,
  status: Schema.Literals(["completed", "partial"]),
  startedAt: Schema.String,
  seed: Schema.Number,
  seedBlock: Schema.String,
  codeHash: Schema.String,
  model: Schema.String,
  effort: Schema.String,
  player: Schema.String,
  position: Schema.Number,
  winShare: Count,
  cash: Count,
  calls: Count,
  cost: Count,
  inp: Count,
  outp: Count,
  cr: Count,
  cw: Count,
  rt: Count,
  lat: Count,
  failed: Count,
  fcost: Count,
  flat: Count,
  rcost: Count,
  rlat: Count,
  rsHidden: Count,
  rsText: Count,
  multiTool: Count,
  moves: Count,
});

export type SeatRow = typeof SeatRow.Type;

/** What the server's analysis adds to a seat. low is the worst health deficit in the last round it saw: own health, opponent health, round. roundThree is the agent moves of round 3 and the output tokens of the calls linked to them, or null when the seat made none. */
export const SeatAnalysis = Schema.Struct({
  acquired: PerItem,
  used: PerItem,
  stolen: PerItem,
  faults: Schema.Number,
  reminders: Schema.Number,
  fallbacks: Schema.Number,
  story: Schema.NullOr(Story),
  round: Schema.Number,
  roundThree: Schema.NullOr(Schema.Tuple([Schema.Number, Schema.Number])),
  low: Schema.NullOr(Schema.Tuple([Schema.Number, Schema.Number, Schema.Number])),
});

export type SeatAnalysis = typeof SeatAnalysis.Type;

/**
 * A seat's searched agent moves: how many, their regret summed in percentage points of the round win chance, and how
 * many of them are proven exact (docs/arena/analysis/regret.md). Null when the viewer has no regret database or the
 * seat has no searched move.
 */
export const SeatRegret = Schema.Struct({ moves: Schema.Number, total: Schema.Number, exact: Schema.Number });

export type SeatRegret = typeof SeatRegret.Type;

export const Seat = Schema.Struct({ ...SeatRow.fields, ...SeatAnalysis.fields, regret: Schema.NullOr(SeatRegret) });

export type Seat = typeof Seat.Type;

export const SeatsResponse = Schema.Array(Seat);

const Column = Schema.Array(Schema.Number);

/**
 * One entry per agent move, column by column. seat indexes the seats response.
 * opp and pick are bit masks over PATTERNS: a pattern's chance came up, and the move took it.
 * rt is -1 when a call did not report reasoning tokens. shot: 0 none, 1 the opponent, 2 itself.
 * useItem and stealItem index ITEMS, or are -1.
 */
export const Decisions = Schema.Struct({
  seat: Column,
  ord: Column,
  moveNo: Column,
  opp: Column,
  pick: Column,
  failedCalls: Column,
  rt: Column,
  rc: Column,
  cost: Column,
  lat: Column,
  tok: Column,
  calls: Column,
  legalUse: Column,
  legalSteal: Column,
  useItem: Column,
  stealItem: Column,
  shot: Column,
  checks: Schema.Struct({ ok: Schema.Number, bad: Schema.Number }),
});

export type Decisions = typeof Decisions.Type;

/** Bit order of Decisions' opp and pick masks. */
export const PATTERNS = [
  "knownBlankOpp",
  "knownLiveSelf",
  "countLiveSelf",
  "countBlankOpp",
  "sawSelf",
  "invertLiveOpp",
  "glassKnown",
  "cigsFull",
  "oddsLiveSelf",
  "oddsBlankOpp",
  "tieSelf",
  "glassBlankOpp",
] as const;

export type Pattern = (typeof PATTERNS)[number];

export const patternBit = (pattern: Pattern): number => 1 << PATTERNS.indexOf(pattern);

export const Shell = Schema.Literals(["live", "blank"]);

export type Shell = typeof Shell.Type;

export const Call = Schema.Struct({
  decisionId: Schema.NullOr(Schema.String),
  player: Schema.String,
  t: Schema.String,
  status: Schema.String,
  error: Schema.NullOr(Schema.String),
  latency: Count,
  inp: Count,
  outp: Count,
  cr: Count,
  cw: Count,
  rt: Count,
  cost: Count,
  reasoning: Schema.String,
  response: Schema.String,
  tools: Schema.String,
});

export type Call = typeof Call.Type;

export const PlayerState = Schema.Struct({ player: Schema.String, health: Schema.Number, items: Schema.Array(Schema.String) });

export type PlayerState = typeof PlayerState.Type;

/**
 * What the minimax player made of one searched agent move, in percentage points of the round win chance: the regret,
 * the best move's score and the chosen move's. exact is true only for a proven settled round; false means not proven
 * exact, not that the score is a guess. depth is how deep the search got, and limited whether the node budget stopped it.
 */
export const MoveRegret = Schema.Struct({
  points: Schema.Number,
  exact: Schema.Boolean,
  best: Schema.String,
  bestScore: Schema.Number,
  chosenScore: Schema.Number,
  depth: Schema.Number,
  limited: Schema.Boolean,
});

export type MoveRegret = typeof MoveRegret.Type;

/**
 * One decision of a match, with the deciding player's view: everyone's health and items, the shells it counts
 * by original type, and the chambered shell if glass or phone told it. A view can omit a jammed player's health,
 * so the last known value is carried forward. outcome is the public events the move caused.
 */
export const Step = Schema.Struct({
  id: Schema.String,
  ordinal: Schema.Number,
  turn: Schema.Number,
  player: Schema.String,
  byWhom: Schema.Literals(["agent", "fallback", "forced"]),
  label: Schema.String,
  round: Schema.Number,
  players: Schema.Array(PlayerState),
  live: Schema.Number,
  blank: Schema.Number,
  known: Schema.NullOr(Shell),
  regret: Schema.NullOr(MoveRegret),
  outcome: Schema.Array(Schema.String),
  calls: Schema.Array(Call),
});

export type Step = typeof Step.Type;

export const MatchSummary = Schema.Struct({
  id: Schema.String,
  name: Schema.String,
  status: Schema.String,
  seed: Schema.Number,
  startedAt: Schema.String,
  endedAt: Schema.NullOr(Schema.String),
  tournament: Schema.String,
});

export const MatchSeat = Schema.Struct({
  player: Schema.String,
  position: Schema.Number,
  cash: Count,
  winShare: Count,
  model: Schema.String,
  effort: Schema.String,
});

export type MatchSeat = typeof MatchSeat.Type;

export const MatchDetail = Schema.Struct({
  match: MatchSummary,
  seats: Schema.Array(MatchSeat),
  decisions: Schema.Array(Step),
  unlinked: Schema.Array(Call),
  story: Story,
});

export type MatchDetail = typeof MatchDetail.Type;
