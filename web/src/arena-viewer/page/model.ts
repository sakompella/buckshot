import { Schema } from "effect";
import { AsyncData } from "foldkit";
import { defineMessageUnion } from "foldkit/message";

import { Blunders, Consistency, Decisions, MatchDetail, Mistakes, Seat } from "../api.ts";

// MODEL

/** The page's sections below the hero, in page order; each is an in-page anchor. */
export const Section = Schema.Literals(["scatter", "interesting", "luck", "seats", "deals", "blunders", "mistakes", "odds", "items", "pressure", "rubbers", "reliability", "matches", "leaderboards", "breakdown"]);

export type Section = typeof Section.Type;

export const SECTIONS: ReadonlyArray<readonly [Section, string]> = [
  ["scatter", "Scatter"],
  ["interesting", "Interesting"],
  ["luck", "Results"],
  ["seats", "Seats"],
  ["deals", "Seeds"],
  ["blunders", "Blunders"],
  ["mistakes", "Mistakes"],
  ["odds", "Odds"],
  ["items", "Items"],
  ["pressure", "Tokens"],
  ["rubbers", "Dead rubbers"],
  ["reliability", "Reliability"],
  ["matches", "Matches"],
  ["leaderboards", "Leaderboards"],
  ["breakdown", "Breakdown"],
];

/** How ratings show: the Bradley-Terry rating on an Elo scale, or the place by observed win share (see rankOrder). */
export const Ranking = Schema.Literals(["elo", "rank"]);

export type Ranking = typeof Ranking.Type;

/** What ratings count: each match's win share, each player's pot share (its cash over the match's cash), or each round as one game. */
export const Basis = Schema.Literals(["wins", "cash", "rounds"]);

export type Basis = typeof Basis.Type;

export const SeatFull = Schema.Struct({ ...Seat.fields, cohort: Schema.String, potShare: Schema.NullOr(Schema.Number) });

/** An optional section's data, or why it could not be loaded: its failure leaves the rest of the page standing. */
const OptionalData = <A, I>(schema: Schema.Codec<A, I>) => AsyncData.Schema(schema, Schema.String).schema;

/**
 * The database as the page holds it: every seat with its cohort and the agent moves' columns, which every section needs;
 * then the blunders, the regret of the searched moves, and each config's consistency (empty without a knowledge database).
 */
export const Loaded = Schema.Struct({
  seats: Schema.Array(SeatFull),
  decisions: Decisions,
  blunders: OptionalData(Blunders),
  mistakes: OptionalData(Mistakes),
  consistency: OptionalData(Schema.Array(Consistency)),
});

export type Loaded = typeof Loaded.Type;

/**
 * Which seats the page counts: one cohort or all, minus the efforts and models switched off. Unless isAllConfigs,
 * only the main configs count (see mainConfigsOf).
 */
export const Filter = Schema.Struct({ cohort: Schema.String, offEfforts: Schema.Array(Schema.String), offModels: Schema.Array(Schema.String), isAllConfigs: Schema.Boolean });

export type Filter = typeof Filter.Type;

/** Which configs the cost scatter shows: every effort, or medium only. */
export const ScatterShow = Schema.Literals(["all", "medium"]);

export type ScatterShow = typeof ScatterShow.Type;

/** What the scatter's x axis measures per player per match: cost, model moves or output tokens, or the mean regret per move. */
export const ScatterAxis = Schema.Literals(["cost", "moves", "tokens", "regret"]);

export type ScatterAxis = typeof ScatterAxis.Type;

export const Scatter = Schema.Struct({ show: ScatterShow, axis: ScatterAxis, maybeHover: Schema.Option(Schema.String), maybePin: Schema.Option(Schema.String) });

export const HeatMode = Schema.Literals(["opp", "surprise", "items", "choices", "style"]);

export type HeatMode = typeof HeatMode.Type;

export const HeatCellId = Schema.Struct({ row: Schema.String, col: Schema.String });

/** The moves behind one choice-pattern cell: one config, one pattern bit. */
export const Flagged = Schema.Struct({ key: Schema.String, bit: Schema.Number, title: Schema.String });

export const Heat = Schema.Struct({
  mode: HeatMode,
  /** "rating", "model", "cost" or a column id. */
  sort: Schema.String,
  isBestOnly: Schema.Boolean,
  maybeTip: Schema.Option(HeatCellId),
  maybeFlagged: Schema.Option(Flagged),
});

export const Leaderboard = Schema.Struct({ maybeOpen: Schema.Option(Schema.String), maybeTip: Schema.Option(Schema.String) });

/** An open replay. Until a move is chosen, it shows the first model move at or after the focus ordinal. */
export const Replay = Schema.Struct({ id: Schema.String, maybeFocus: Schema.Option(Schema.Number), maybeAt: Schema.Option(Schema.Number) });

export type Replay = typeof Replay.Type;

/** The match list's search and how many rows it shows. */
export const MatchList = Schema.Struct({ query: Schema.String, limit: Schema.Number });

/** A reliability cell with its tooltip open: a row (tournament and config) and a column. */
export const RateCell = Schema.Struct({ row: Schema.String, column: Schema.String });

export const MatchData = AsyncData.Schema(MatchDetail, Schema.String).schema;

export type MatchData = typeof MatchData.Type;

export const Viewport = Schema.Struct({ width: Schema.Number, height: Schema.Number });

export type Viewport = typeof Viewport.Type;

export const Model = Schema.Struct({
  viewport: Viewport,
  data: AsyncData.Schema(Loaded, Schema.String).schema,
  filter: Filter,
  ranking: Ranking,
  basis: Basis,
  scatter: Scatter,
  heat: Heat,
  leaderboard: Leaderboard,
  matchList: MatchList,
  maybeRateTip: Schema.Option(RateCell),
  /** Each match detail asked for, by match id. */
  matches: Schema.Record(Schema.String, MatchData),
  maybeReplay: Schema.Option(Replay),
  /** Whether the page has painted once with the data. Most sections that came with the analysis ideas wait for it, so the first paint is as quick as before them. */
  isFirstPaintDone: Schema.Boolean,
});

export type Model = typeof Model.Type;

// MESSAGE

export const Message = defineMessageUnion({
  ResizedViewport: { width: Schema.Number, height: Schema.Number },
  ClickedJump: { section: Section },
  NavigatedToHash: {},
  SucceededLoad: { loaded: Loaded },
  FailedLoad: { error: Schema.String },
  SelectedCohort: { cohort: Schema.String },
  ToggledEffort: { effort: Schema.String },
  ToggledModel: { name: Schema.String },
  ToggledAllConfigs: {},
  SelectedRanking: { ranking: Ranking },
  SelectedBasis: { basis: Basis },
  SelectedScatterShow: { show: ScatterShow },
  SelectedScatterAxis: { axis: ScatterAxis },
  HoveredPoint: { key: Schema.String },
  LeftPoint: {},
  ClickedPoint: { key: Schema.String },
  ClickedOutsideChart: {},
  SelectedHeatMode: { mode: HeatMode },
  ClickedHeatColumn: { column: Schema.String },
  ToggledBestOnly: {},
  HoveredCell: { row: Schema.String, col: Schema.String },
  LeftCell: {},
  ClickedPatternCell: { key: Schema.String, bit: Schema.Number, title: Schema.String },
  ClosedFlagged: {},
  ClickedLeaderboardRow: { id: Schema.String },
  HoveredSquare: { matchId: Schema.String },
  LeftSquare: {},
  ClickedMatch: { id: Schema.String, maybeFocus: Schema.Option(Schema.Number) },
  SucceededMatch: { id: Schema.String, detail: MatchDetail },
  FailedMatch: { id: Schema.String, error: Schema.String },
  ClosedReplay: {},
  NavigatedBack: {},
  SteppedReplay: { delta: Schema.Number },
  SelectedStep: { index: Schema.Number },
  ChangedMatchQuery: { query: Schema.String },
  ClickedShowMore: {},
  HoveredRate: { row: Schema.String, column: Schema.String },
  LeftRate: {},
  PlacedTip: {},
  CompletedHistoryChange: {},
  CompletedStepScroll: {},
  CompletedScroll: {},
  CompletedFirstPaint: {},
});

export type Message = typeof Message.Type;
