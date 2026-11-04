import { Schema } from "effect";

// The arena viewer's JSON API: what its server encodes and its page decodes.
// The server reads the analysis database (docs/arena/database.md) read-only.

const Count = Schema.NullOr(Schema.Number);

/** A tally per item, in ITEMS order. */
const PerItem = Schema.Array(Schema.Number);

/**
 * How consistent one config is: over the positions it met at least twice, the
 * chance two of its decisions in the same position chose the same move, with a 95% seed-block bootstrap interval.
 */
export const Consistency = Schema.Struct({
  model: Schema.String,
  effort: Schema.String,
  positions: Schema.Number,
  agree: Schema.Number,
  lo: Schema.Number,
  hi: Schema.Number,
});

export type Consistency = typeof Consistency.Type;

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
  cost: Count,
  inp: Count,
  outp: Count,
  cr: Count,
  cw: Count,
  rt: Count,
  lat: Count,
  rsHidden: Count,
  rsText: Count,
  multiTool: Count,
  moves: Count,
});

export type SeatRow = typeof SeatRow.Type;

/** What the server's analysis adds to a seat. deficits is the worst health deficit the seat had in each round, in order: the opponent's health minus its own, 0 if it never trailed. roundThree is the agent moves of round 3 and the output tokens of the calls linked to them, or null when the seat made none. */
export const SeatAnalysis = Schema.Struct({
  acquired: PerItem,
  used: PerItem,
  stolen: PerItem,
  story: Schema.NullOr(Story),
  round: Schema.Number,
  roundThree: Schema.NullOr(Schema.Tuple([Schema.Number, Schema.Number])),
  deficits: Schema.Array(Schema.Number),
});

export type SeatAnalysis = typeof SeatAnalysis.Type;

/**
 * A seat's searched agent moves: how many, their regret summed in percentage points of the round win chance, how
 * many of them are proven exact (docs/arena/analysis/regret.md), and the move with the most regret. Null when the
 * viewer has no regret database or the seat has no searched move.
 */
export const SeatRegret = Schema.Struct({ moves: Schema.Number, total: Schema.Number, exact: Schema.Number, largest: Schema.Struct({ ordinal: Schema.Number, points: Schema.Number }) });

export type SeatRegret = typeof SeatRegret.Type;

export const Seat = Schema.Struct({ ...SeatRow.fields, ...SeatAnalysis.fields, regret: Schema.NullOr(SeatRegret) });

export type Seat = typeof Seat.Type;

export const SeatsResponse = Schema.Array(Seat);

/** One config's Round Elo (page/ratings.ts), fitted by the server over every match; the interval is null below MIN_BLOCKS_FOR_INTERVAL seed blocks. */
export const RatingRow = Schema.Struct({
  key: Schema.String,
  rating: Schema.Number,
  blocks: Schema.Number,
  interval: Schema.NullOr(Schema.Struct({ lo: Schema.Number, hi: Schema.Number })),
});

export type RatingRow = typeof RatingRow.Type;

export const RatingsResponse = Schema.Array(RatingRow);

// A column holds one number per agent move, over a hundred thousand of them: one type check per column decodes it many
// times faster than a schema per element.
const Column = Schema.declare((input: unknown): input is ReadonlyArray<number> => Array.isArray(input) && input.every(Number.isFinite));

/** A move's `gap` when the player has no single opponent to compare with. */
export const NO_GAP = 99;

/**
 * One entry per agent move, column by column. seat indexes the seats response.
 * opp and pick are bit masks over PATTERNS: a pattern's chance came up, and the move took it.
 * rt is -1 when a call did not report reasoning tokens. out is the output tokens of every call of the move. gap is the
 * player's health minus its opponent's, or NO_GAP at a table of more than two or when a view omits a health.
 * shot: 0 none, 1 the opponent, 2 itself.
 * odds is, for a shot the player had no glass or phone clue for, the whole percent chance it counted the chambered shell live; else -1.
 * useItem and stealItem index ITEMS, or are -1.
 */
export const Decisions = Schema.Struct({
  seat: Column,
  ord: Column,
  opp: Column,
  pick: Column,
  rt: Column,
  out: Column,
  gap: Column,
  cost: Column,
  lat: Column,
  tok: Column,
  legalUse: Column,
  legalSteal: Column,
  useItem: Column,
  stealItem: Column,
  shot: Column,
  odds: Column,
  checks: Schema.Struct({ ok: Schema.Number, bad: Schema.Number }),
});

export type Decisions = typeof Decisions.Type;

/** A searched move that gave up at least this many points of the round win chance is a blunder. */
export const BLUNDER_POINTS = 10;

/**
 * Every blunder, column by column: seat indexes the seats response, ord is the decision's ordinal, points its regret,
 * and chosen and best index labels (the move taken and the best legal move). Scores are percentage points of the round
 * win chance. Empty without a regret database.
 */
export const Blunders = Schema.Struct({
  labels: Schema.Array(Schema.String),
  seat: Column,
  ord: Column,
  points: Column,
  exact: Column,
  chosen: Column,
  best: Column,
  bestScore: Column,
  chosenScore: Column,
});

export type Blunders = typeof Blunders.Type;

export const CERTAIN_TYPES = ["self_on_live", "gave_up_guaranteed_win"] as const;

export const CertainType = Schema.Literals(CERTAIN_TYPES);

export type CertainType = typeof CertainType.Type;

const OPPORTUNITY_TYPES = [...CERTAIN_TYPES, "hidden_health", "gave_turn_away"] as const;

export const OpportunityType = Schema.Literals(OPPORTUNITY_TYPES);

export type OpportunityType = typeof OpportunityType.Type;

/** A rate that certain_mistakes.py wrote: a config's, a model's with its efforts pooled, or every config's. Its interval is null under twenty opportunities. */
export const CertainRate = Schema.Struct({
  scope: Schema.Literals(["config", "model", "all"]),
  model: Schema.String,
  effort: Schema.String,
  type: OpportunityType,
  chose: Schema.Number,
  opportunities: Schema.Number,
  bounds: Schema.NullOr(Schema.Struct({ lo: Schema.Number, hi: Schema.Number })),
});

export type CertainRate = typeof CertainRate.Type;

export const Download = Schema.Struct({ bytes: Schema.Number });

export const CertainMistakes = Schema.Struct({ rates: Schema.Array(CertainRate), moveSeat: Column, moveType: Column, moveOrd: Column });

export type CertainMistakes = typeof CertainMistakes.Type;

/** Bit order of Decisions' opp and pick masks. */
const PATTERNS = [
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
  chosen: Schema.String,
  chosenScore: Schema.Number,
  depth: Schema.Number,
  limited: Schema.Boolean,
  values: Schema.Array(Schema.Struct({ label: Schema.String, score: Schema.Number })),
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
  certain: Schema.NullOr(CertainType),
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
