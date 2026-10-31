import { Schema } from "effect";
import { AsyncData } from "foldkit";
import { defineMessageUnion } from "foldkit/message";

import { CertainMistakes, CertainType, Consistency, Decisions, MatchDetail, Seat } from "../api.ts";

/** The page's groups below the hero, in page order: the jump menu's links, and the sections the reader can be in. */
export const Group = Schema.Literals(["standings", "watch", "decisions", "health"]);

export type Group = typeof Group.Type;

/** The sections inside the groups, each an in-page anchor; a link to one the page no longer has lands at its MOVED_TARGETS entry. */
export const Section = Schema.Literals(["leaderboards", "scatter", "breakdown", "matches", "certain-mistakes", "odds", "items", "spend"]);

export type Section = typeof Section.Type;

export const Target = Schema.Union([Group, Section]);

export type Target = typeof Target.Type;

export const MOVED_TARGETS: ReadonlyMap<string, Target> = new Map([
  ["results", "standings"],
  ["rounds", "spend"],
  ["reliability", "spend"],
  ["details", "leaderboards"],
  ["interesting", "matches"],
  ["blunders", "matches"],
  ["mistakes", "odds"],
  ["luck", "odds"],
  ["pressure", "leaderboards"],
  ["rubbers", "spend"],
  ["seats", "spend"],
  ["deals", "matches"],
]);

export const GROUPS: ReadonlyArray<{ readonly group: Group; readonly label: string; readonly sections: ReadonlyArray<Section> }> = [
  { group: "standings", label: "Standings", sections: ["leaderboards", "scatter", "breakdown"] },
  { group: "watch", label: "Matches", sections: ["matches"] },
  { group: "decisions", label: "How they play", sections: ["certain-mistakes", "odds", "items"] },
  { group: "health", label: "Run health", sections: ["spend"] },
];

export const SeatFull = Schema.Struct({ ...Seat.fields, potShare: Schema.NullOr(Schema.Number) });

/** An optional section's data, or why it could not be loaded: its failure leaves the rest of the page standing. */
const OptionalData = <A, I>(schema: Schema.Codec<A, I>) => AsyncData.Schema(schema, Schema.String).schema;

/**
 * The database as the page holds it: every seat with its pot share and the agent moves' columns, which every section needs;
 * then each config's consistency (empty without a knowledge database) and certain mistakes (empty without a certain-mistakes database).
 */
export const Loaded = Schema.Struct({
  seats: Schema.Array(SeatFull),
  decisions: Decisions,
  consistency: OptionalData(Schema.Array(Consistency)),
  certainMistakes: OptionalData(CertainMistakes),
});

export type Loaded = typeof Loaded.Type;

/** Which seats the page counts: all, minus the efforts and models switched off. */
export const Filter = Schema.Struct({ offEfforts: Schema.Array(Schema.String), offModels: Schema.Array(Schema.String) });

export type Filter = typeof Filter.Type;

/** What the scatter's x axis measures per player per match: cost, model moves or output tokens, or the mean regret per move. */
export const ScatterAxis = Schema.Literals(["cost", "moves", "tokens", "regret"]);

export type ScatterAxis = typeof ScatterAxis.Type;

export const Scatter = Schema.Struct({ axis: ScatterAxis, maybeHover: Schema.Option(Schema.String), maybePin: Schema.Option(Schema.String) });

export const HeatCellId = Schema.Struct({ row: Schema.String, col: Schema.String });

export const Heat = Schema.Struct({ sort: Schema.String, maybeTip: Schema.Option(HeatCellId) });

export const Leaderboard = Schema.Struct({ maybeOpen: Schema.Option(Schema.String), maybeTip: Schema.Option(Schema.String) });

export const CertainCell = Schema.Struct({ key: Schema.String, type: CertainType });

export type CertainCell = typeof CertainCell.Type;

/** An open replay. Until a move is chosen, it shows the first model move at or after the focus ordinal. */
export const Replay = Schema.Struct({ id: Schema.String, maybeFocus: Schema.Option(Schema.Number), maybeAt: Schema.Option(Schema.Number) });

export type Replay = typeof Replay.Type;

export const MatchPreset = Schema.Literals(["comebacks", "upsets"]);

export type MatchPreset = typeof MatchPreset.Type;

export const MatchList = Schema.Struct({ query: Schema.String, limit: Schema.Number, maybePreset: Schema.Option(MatchPreset) });

/** A chart mark's tip: the id of the mark it points at, and what the mark means with its sample size. */
export const MarkTip = Schema.Struct({ anchor: Schema.String, text: Schema.String });

export type MarkTip = typeof MarkTip.Type;

export const TourBox = Schema.Struct({ top: Schema.Number, left: Schema.Number, width: Schema.Number, height: Schema.Number });

export type TourBox = typeof TourBox.Type;

/** The open tour: the step shown (an index into the steps tour.ts gives for `hasCertain`) and, once measured, its highlight and whether the card fits just under it. */
export const Tour = Schema.Struct({ step: Schema.Number, hasCertain: Schema.Boolean, maybeBox: Schema.Option(TourBox), isCardUnder: Schema.Boolean });

export type Tour = typeof Tour.Type;

export const MatchData = AsyncData.Schema(MatchDetail, Schema.String).schema;

export type MatchData = typeof MatchData.Type;

export const Viewport = Schema.Struct({ width: Schema.Number, height: Schema.Number });

export type Viewport = typeof Viewport.Type;

export const Model = Schema.Struct({
  viewport: Viewport,
  data: AsyncData.Schema(Loaded, Schema.String).schema,
  filter: Filter,
  scatter: Scatter,
  heat: Heat,
  leaderboard: Leaderboard,
  maybeCertainOpen: Schema.Option(CertainCell),
  matchList: MatchList,
  /** The chart mark the mouse is over, and the one a click, tap or Enter pinned; the hovered one shows first. */
  markTip: Schema.Struct({ maybeHover: Schema.Option(MarkTip), maybePin: Schema.Option(MarkTip) }),
  /** The text of a chart mark a touch tapped: its SVG title or title attribute, which only a mouse can hover. */
  maybeTappedTitle: Schema.Option(Schema.String),
  maybeGroup: Schema.Option(Group),
  isFiltersOpen: Schema.Boolean,
  matches: Schema.Record(Schema.String, MatchData),
  maybeReplay: Schema.Option(Replay),
  /** Whether the page has painted once with the data. Most sections that came with the analysis ideas wait for it, so the first paint is as quick as before them. */
  isFirstPaintDone: Schema.Boolean,
  maybeTour: Schema.Option(Tour),
});

export type Model = typeof Model.Type;

export const Message = defineMessageUnion({
  ResizedViewport: { width: Schema.Number, height: Schema.Number },
  ClickedJump: { target: Target },
  NavigatedToHash: {},
  SucceededLoad: { loaded: Loaded },
  FailedLoad: { error: Schema.String },
  ToggledEffort: { effort: Schema.String },
  ToggledModel: { name: Schema.String },
  ToggledFilters: {},
  ScrolledInto: { group: Group },
  TappedTitle: { text: Schema.String },
  ClearedTappedTitle: {},
  SelectedScatterAxis: { axis: ScatterAxis },
  HoveredPoint: { key: Schema.String },
  LeftPoint: {},
  ClickedPoint: { key: Schema.String },
  ClickedOutsideChart: {},
  HoveredMark: { tip: MarkTip },
  LeftMark: {},
  ClickedMark: { tip: MarkTip },
  ClickedHeatColumn: { column: Schema.String },
  HoveredCell: { row: Schema.String, col: Schema.String },
  LeftCell: {},
  ClickedLeaderboardRow: { id: Schema.String },
  ClickedTableLink: { id: Schema.String },
  ClickedCertainCount: { key: Schema.String, type: CertainType },
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
  ClickedMatchPreset: { preset: MatchPreset },
  ClickedShowMore: {},
  PlacedTip: {},
  CompletedHistoryChange: {},
  CompletedStepScroll: {},
  CompletedScroll: {},
  CompletedFirstPaint: {},
  ClickedTour: {},
  SteppedTour: { delta: Schema.Number },
  ClosedTour: {},
  PlacedTour: { step: Schema.Number, maybeBox: Schema.Option(TourBox), isCardUnder: Schema.Boolean },
});

export type Message = typeof Message.Type;
