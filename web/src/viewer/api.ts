import { Schema } from "effect";

import { Total } from "../arena/cost.ts";
import { AgentId } from "../arena/agent.ts";
import { CallLine, EventLine, MoveLine, Standing } from "../arena/runlog.ts";
import { Letter } from "../players.ts";

// What the viewer's server sends and its page reads. The server encodes every
// response with these schemas and the page decodes it with them. Deliveries and
// controllers travel as strings, decoded as such from the run files on the
// server: their schemas live in match.ts and driver.ts, which would pull the
// arena and the rules machine into the page.

/** A model call with its price from prices.json; no dollars when the table has no price for its model. */
export const PricedCall = Schema.Struct({ call: CallLine, dollars: Schema.optional(Schema.Number) });

export type PricedCall = typeof PricedCall.Type;

/** One complete line of a JSONL file: decoded, or why not. `line` counts from 1. */
export type JsonlLine<A> = { readonly kind: "read"; readonly line: number; readonly value: A } | { readonly kind: "unreadable"; readonly line: number; readonly reason: string };

const jsonlLine = <S extends Schema.Top>(value: S) =>
  Schema.Union([Schema.Struct({ kind: Schema.Literal("read"), line: Schema.Int, value }), Schema.Struct({ kind: Schema.Literal("unreadable"), line: Schema.Int, reason: Schema.String })]);

/**
 * "live": running, and a file changed lately. "stopped": running in the manifest, but quiet since.
 * "fault": the last process ended on a model failure, after its last resume.
 */
export const RunStatus = Schema.Literals(["finished", "fault", "live", "stopped"]);

export type RunStatus = typeof RunStatus.Type;

export const RunSummary = Schema.Struct({
  kind: Schema.Literal("readable"),
  id: Schema.String,
  started: Schema.String,
  lastWrite: Schema.String,
  status: RunStatus,
  seed: Schema.String,
  delivery: Schema.String,
  /** In table order: each position's player and controller. */
  seating: Schema.Array(Schema.Struct({ player: Letter, controller: Schema.String })),
  /** The model each agent played with, and its effort (a pi thinking level) when the manifest has one; the model is from its calls until the manifest has an endpoint. */
  agents: Schema.Array(Schema.Struct({ agent: AgentId, model: Schema.optional(Schema.String), api: Schema.optional(Schema.String), effort: Schema.optional(Schema.String) })),
  /** Winner first; only once the match is finished. */
  standings: Schema.optional(Schema.Array(Standing)),
});

export type RunSummary = typeof RunSummary.Type;

/** A run as the list shows it: with what its calls cost, by prices.json. */
export const PricedRun = Schema.Struct({ ...RunSummary.fields, cost: Total });

export type PricedRun = typeof PricedRun.Type;

export const Unreadable = Schema.Struct({ kind: Schema.Literal("unreadable"), id: Schema.String, reason: Schema.String });

export type Unreadable = typeof Unreadable.Type;

export const Run = Schema.Union([PricedRun, Unreadable]);

export type Run = typeof Run.Type;

/** What the calls of one model cost; of one model at one effort when `effort` is there. */
const ModelTotal = Schema.Struct({ model: Schema.String, effort: Schema.optional(Schema.String), total: Total });

export const RunsResponse = Schema.Struct({
  /** Newest first. */
  runs: Schema.Array(Run),
  /** Whether the runs are a tournament's, so there is a leaderboard to show. */
  leaderboard: Schema.Boolean,
  /** Across the readable runs, by model and effort, and by model alone; by model name, then weakest effort first. */
  totals: Schema.Struct({ byEffort: Schema.Array(ModelTotal), byModel: Schema.Array(ModelTotal) }),
});

export type RunsResponse = typeof RunsResponse.Type;

const Interval = Schema.Struct({ low: Schema.Number, high: Schema.Number });

/** One entrant of a tournament, rated over its finished matches; cost covers every match it played or started. */
export const LeaderboardRow = Schema.Struct({
  entrant: Schema.String,
  /** The model's id, or the bot's name. */
  model: Schema.String,
  /** A pi thinking level, from the tournament's config; a bot has none. */
  effort: Schema.optional(Schema.String),
  matches: Schema.Int,
  wins: Schema.Number,
  share: Schema.Number,
  shareInterval: Schema.optional(Interval),
  rating: Schema.Number,
  ratingInterval: Schema.optional(Interval),
  moves: Schema.Int,
  interventions: Schema.Int,
  cost: Total,
});

export type LeaderboardRow = typeof LeaderboardRow.Type;

export const LeaderboardResponse = Schema.Struct({
  name: Schema.String,
  /** The seeds the intervals resample. */
  seeds: Schema.Int,
  matches: Schema.Struct({ scheduled: Schema.Int, finished: Schema.Int, scored: Schema.Int }),
  /** The entrant rated 0; the mean of all entrants when none. */
  anchor: Schema.optional(Schema.String),
  /** Best rating first. */
  rows: Schema.Array(LeaderboardRow),
  /** What to keep in mind reading the numbers, as arena-stats prints them. */
  notes: Schema.Array(Schema.String),
});

export type LeaderboardResponse = typeof LeaderboardResponse.Type;

const PlayerAt = Schema.Struct({
  player: Letter,
  health: Schema.Union([Schema.Number, Schema.Literal("jammed")]),
  items: Schema.Array(Schema.String),
  cash: Schema.Number,
  out: Schema.Boolean,
});

export type PlayerAt = typeof PlayerAt.Type;

/** A log entry a move produced: a public event, or a secret with the player who heard it. */
const Entry = Schema.Struct({ text: Schema.String, heardBy: Schema.optional(Letter) });

/**
 * The table as the rules machine left it after one logged move, the bots' replies included, with the log entries
 * the move produced. The first frame is the start of the match.
 */
export const Frame = Schema.Struct({
  move: Schema.optional(Schema.Struct({ turn: Schema.Int, player: Letter, label: Schema.String, by: MoveLine.fields.by })),
  /** From 1. */
  round: Schema.Int,
  /** Everyone's health when the round began. */
  roundHealth: Schema.Number,
  entries: Schema.Array(Entry),
  players: Schema.Array(PlayerAt),
  gun: Schema.Struct({ live: Schema.Number, blank: Schema.Number, remaining: Schema.Number, sawed: Schema.Boolean }),
});

export type Frame = typeof Frame.Type;

/** Counts of what the page already has, so each poll sends only what is new. */
export const Cursors = Schema.Struct({ calls: Schema.Int, events: Schema.Int, frames: Schema.Int });

export type Cursors = typeof Cursors.Type;

export const MatchResponse = Schema.Struct({
  run: RunSummary,
  calls: Schema.Array(jsonlLine(PricedCall)),
  events: Schema.Array(jsonlLine(EventLine)),
  frames: Schema.Array(Frame),
  /** Why the replay stopped early: the logged move and the one the machine replayed differ. */
  divergence: Schema.optional(Schema.String),
  agents: Schema.Array(Schema.Struct({ agent: AgentId, total: Total, latencyMs: Schema.Number })),
  cursors: Cursors,
});

export type MatchResponse = typeof MatchResponse.Type;
