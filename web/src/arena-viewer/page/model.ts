import { Schema } from "effect";
import { AsyncData } from "foldkit";
import { defineMessageUnion } from "foldkit/message";
import { defineTaggedUnion } from "foldkit/schema";

import { isOnline } from "../../site/online.ts";
import { AGGREGATES } from "../aggregates.ts";
import { CertainMistakes, CertainType, Seat } from "../api.ts";

/** The page's groups below the hero, in page order: the jump menu's links, and the sections the reader can be in. */
export const Group = Schema.Literals(["standings", "decisions", "watch", "tables", "about"]);

export type Group = typeof Group.Type;

/** The sections, each an in-page anchor; a link to one the page no longer has lands at its MOVED_TARGETS entry. */
export const Section = Schema.Literals(["summary", "how", "scatter", "breakdown", "certain-mistakes", "odds", "items", "matches", "leaderboards", "about"]);

export type Section = typeof Section.Type;

export const Target = Schema.Union([Group, Section]);

export type Target = typeof Target.Type;

export const MOVED_TARGETS: ReadonlyMap<string, Target> = new Map([
  ["results", "summary"],
  ["details", "leaderboards"],
  ["interesting", "matches"],
  ["blunders", "matches"],
  ["mistakes", "odds"],
  ["luck", "odds"],
  ["pressure", "leaderboards"],
  ["deals", "matches"],
]);

const EVERY_GROUP: ReadonlyArray<{ readonly group: Group; readonly label: string; readonly sections: ReadonlyArray<Section> }> = [
  { group: "standings", label: "Standings", sections: ["summary", "how", "scatter", "breakdown"] },
  { group: "decisions", label: "How they play", sections: ["certain-mistakes", "odds", "items"] },
  { group: "watch", label: "Matches", sections: ["matches"] },
  { group: "tables", label: "Tables", sections: ["leaderboards"] },
  { group: "about", label: "About", sections: ["about"] },
];

/** The groups this build draws: the online one has no matches, which need per-match data. */
export const GROUPS = isOnline ? EVERY_GROUP.filter(({ group }) => group !== "watch") : EVERY_GROUP;

export const SeatFull = Schema.Struct({ ...Seat.fields, potShare: Schema.NullOr(Schema.Number) });

/** An optional section's data, or why it could not be loaded: its failure leaves the rest of the page standing. */
const OptionalData = <A, I>(schema: Schema.Codec<A, I>) => AsyncData.Schema(schema, Schema.String).schema;

/** What the first paint draws: every config's stats and every pair of configs' matches. */
export const Loaded = Schema.Struct({ summary: AGGREGATES.summary, pairs: AGGREGATES.pairs });

export type Loaded = typeof Loaded.Type;

/** The aggregate files a section fetches when it first comes near. */
export const LazyName = Schema.Literals(["items", "odds", "certain", "consistency"]);

export type LazyName = typeof LazyName.Type;

export const Lazy = Schema.Struct({
  items: OptionalData(AGGREGATES.items),
  odds: OptionalData(AGGREGATES.odds),
  certain: OptionalData(AGGREGATES.certain),
  consistency: OptionalData(AGGREGATES.consistency),
});

export type Lazy = typeof Lazy.Type;

/**
 * The per-seat and per-move data only the arena server has, fetched when a section that needs it first comes near: the
 * match list and the drill's per-move line. The online build never fetches it.
 */
export const Local = Schema.Struct({ seats: Schema.Array(SeatFull), certainMoves: OptionalData(CertainMistakes) });

export type Local = typeof Local.Type;

/** Which seats the page counts: all, minus the efforts and models switched off. */
export const Filter = Schema.Struct({ offEfforts: Schema.Array(Schema.String), offModels: Schema.Array(Schema.String) });

export type Filter = typeof Filter.Type;

/** What the scatter's x axis measures: reasoning tokens per move, cost, model moves or output tokens per match, or accuracy. */
export const ScatterAxis = Schema.Literals(["reasoning", "cost", "moves", "tokens", "regret"]);

export type ScatterAxis = typeof ScatterAxis.Type;

export const Scatter = Schema.Struct({ axis: ScatterAxis, maybeHover: Schema.Option(Schema.String), maybePin: Schema.Option(Schema.String) });

export const HeatCellId = Schema.Struct({ row: Schema.String, col: Schema.String });

export const Heat = Schema.Struct({ sort: Schema.String, maybeTip: Schema.Option(HeatCellId) });

export const Leaderboard = Schema.Struct({ maybeOpen: Schema.Option(Schema.String) });

export const CertainCell = Schema.Struct({ key: Schema.String, type: CertainType });

export type CertainCell = typeof CertainCell.Type;

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

export const Viewport = Schema.Struct({ width: Schema.Number, height: Schema.Number });

export type Viewport = typeof Viewport.Type;

/** Why the database did not load. A static build of the site has no arena server to ask. */
export const LoadFailure = defineTaggedUnion({ NoServer: {}, Failed: { error: Schema.String } });

export type LoadFailure = typeof LoadFailure.Type;

export const Model = Schema.Struct({
  viewport: Viewport,
  data: AsyncData.Schema(Loaded, LoadFailure).schema,
  lazy: Lazy,
  local: OptionalData(Local),
  filter: Filter,
  scatter: Scatter,
  heat: Heat,
  leaderboard: Leaderboard,
  maybeDrill: Schema.Option(Schema.String),
  maybeCertainOpen: Schema.Option(CertainCell),
  matchList: MatchList,
  /** The chart mark the mouse is over, and the one a click, tap or Enter pinned; the hovered one shows first. */
  markTip: Schema.Struct({ maybeHover: Schema.Option(MarkTip), maybePin: Schema.Option(MarkTip) }),
  /** The text of a chart mark a touch tapped: its SVG title or title attribute, which only a mouse can hover. */
  maybeTappedTitle: Schema.Option(Schema.String),
  maybeGroup: Schema.Option(Group),
  isFiltersOpen: Schema.Boolean,
  /** Whether the page has painted once with the data. Most sections wait for it, so the first paint is quick. */
  isFirstPaintDone: Schema.Boolean,
  maybeTour: Schema.Option(Tour),
});

export type Model = typeof Model.Type;

export const Message = defineMessageUnion({
  ResizedViewport: { width: Schema.Number, height: Schema.Number },
  ClickedJump: { target: Target },
  NavigatedToHash: {},
  SucceededLoad: { loaded: Loaded },
  FailedLoad: { failure: LoadFailure },
  SucceededItems: { items: AGGREGATES.items },
  SucceededOdds: { odds: AGGREGATES.odds },
  SucceededCertain: { certain: AGGREGATES.certain },
  SucceededConsistency: { consistency: AGGREGATES.consistency },
  FailedLazy: { name: LazyName, error: Schema.String },
  SucceededLocal: { local: Local },
  FailedLocal: { error: Schema.String },
  ToggledEffort: { effort: Schema.String },
  ToggledModel: { name: Schema.String },
  ToggledFilters: {},
  ScrolledInto: { group: Group },
  CameNear: { groups: Schema.Array(Group) },
  TappedTitle: { text: Schema.String },
  ClearedTappedTitle: {},
  SelectedScatterAxis: { axis: ScatterAxis },
  HoveredPoint: { key: Schema.String },
  LeftPoint: {},
  ClickedPoint: { key: Schema.String },
  ClosedDrill: {},
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
  ChangedMatchQuery: { query: Schema.String },
  ClickedMatchPreset: { preset: MatchPreset },
  ClickedShowMore: {},
  PlacedTip: {},
  CompletedStepScroll: {},
  CompletedScroll: {},
  CompletedFirstPaint: {},
  ClickedTour: {},
  SteppedTour: { delta: Schema.Number },
  ClosedTour: {},
  PlacedTour: { step: Schema.Number, maybeBox: Schema.Option(TourBox), isCardUnder: Schema.Boolean },
});

export type Message = typeof Message.Type;
