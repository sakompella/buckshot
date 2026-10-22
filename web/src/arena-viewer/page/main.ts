import { Effect, Option, Schema, Stream } from "effect";
import { HttpClient, HttpClientResponse } from "effect/http";
import { AsyncData, Command, Dom, Http, Runtime, Subscription, type Update } from "foldkit";
import { modifyFields } from "foldkit/struct";

import { Decisions, MatchDetail, SeatsResponse } from "../api.ts";
import { withCohorts } from "./data.ts";
import { derive } from "./derived.ts";
import { picksOf } from "./interesting.ts";
import { MORE_ROWS } from "./matches.ts";
import { type Filter, Message, Model, Tab, type Viewport } from "./model.ts";
import { replayIndex, stepsOf } from "./replay.ts";
import { view } from "./view.ts";

// The arena viewer's page: a Foldkit application over the viewer's JSON API.

type Return = Update.Return<Model, Message>;

const describe = (error: { readonly message: string }) => error.message;

const getJson = <A, I>(url: string, schema: Schema.Codec<A, I>) =>
  HttpClient.get(url).pipe(
    Effect.flatMap(HttpClientResponse.filterStatusOk),
    Effect.flatMap((response) => response.json),
    Effect.flatMap((body) => Schema.decodeUnknownEffect(schema)(body)),
  );

const LoadData = Command.define("LoadData", {
  messages: [Message.SucceededLoad, Message.FailedLoad],
  execute: Effect.all([getJson("/api/seats", SeatsResponse), getJson("/api/decisions", Decisions)], { concurrency: 2 }).pipe(
    Effect.map(([seats, decisions]) => Message.SucceededLoad({ loaded: { seats: withCohorts(seats), decisions } })),
    Effect.catch((error) => Effect.succeed(Message.FailedLoad({ error: describe(error) }))),
    Effect.provide(Http.layer),
  ),
});

const LoadMatch = Command.define("LoadMatch", {
  args: { id: Schema.String },
  messages: [Message.SucceededMatch, Message.FailedMatch],
  execute: ({ id }) =>
    getJson(`/api/match?id=${encodeURIComponent(id)}`, MatchDetail).pipe(
      Effect.map((detail) => Message.SucceededMatch({ id, detail })),
      Effect.catch((error) => Effect.succeed(Message.FailedMatch({ id, error: describe(error) }))),
      Effect.provide(Http.layer),
    ),
});

const WriteHash = Command.define("WriteHash", {
  args: { tab: Tab },
  messages: [Message.CompletedHashWrite],
  execute: ({ tab }) => Effect.sync(() => history.replaceState(null, "", `#${tab}`)).pipe(Effect.as(Message.CompletedHashWrite())),
});

// An open replay owns one history entry, so the phone's back gesture closes it instead of leaving the page.
const ReplayHistory = Schema.Struct({ replay: Schema.Literal(true) });

const PushReplayHistory = Command.define("PushReplayHistory", {
  messages: [Message.CompletedHistoryChange],
  execute: Effect.sync(() => history.pushState({ replay: true }, "")).pipe(Effect.as(Message.CompletedHistoryChange())),
});

const LeaveReplayHistory = Command.define("LeaveReplayHistory", {
  messages: [Message.CompletedHistoryChange],
  execute: Effect.sync(() => {
    if (Schema.is(ReplayHistory)(history.state)) history.back();
  }).pipe(Effect.as(Message.CompletedHistoryChange())),
});

// A tab opens at its top, not at the scroll position the last tab was left at.
const ScrollToTop = Command.define("ScrollToTop", {
  messages: [Message.CompletedScroll],
  execute: Effect.sync(() => scrollTo(0, 0)).pipe(Effect.as(Message.CompletedScroll())),
});

/** Asks for every match detail in `ids` the model does not have yet. */
const withMatches = (model: Model, ids: ReadonlyArray<string>): Return => {
  const missing = ids.filter((id) => model.matches[id] === undefined);

  if (missing.length === 0) return { model };

  return {
    model: modifyFields(model, { matches: (matches) => ({ ...matches, ...Object.fromEntries(missing.map((id) => [id, AsyncData.Loading()])) }) }),
    commands: missing.map((id) => LoadMatch({ id })),
  };
};

/** The interesting matches' cards draw their moves, so a new filter may need new match details. */
const withPickedMatches = (model: Model): Return =>
  AsyncData.matchData(model.data, {
    onEmpty: (): Return => ({ model }),
    onFailure: (): Return => ({ model }),
    onData: (loaded) => withMatches(model, picksOf(derive(loaded, model.filter)).map(({ match }) => match.matchId)),
  });

const toggled = (values: ReadonlyArray<string>, value: string): ReadonlyArray<string> => (values.includes(value) ? values.filter((other) => other !== value) : [...values, value]);

/** Moves the open replay to another move, clamped to its model moves; nothing happens until its match has loaded. */
const withReplayMove = (model: Model, choose: (at: number) => number): Return =>
  Option.match(model.maybeReplay, {
    onNone: (): Return => ({ model }),
    onSome: (replay): Return => {
      const data = model.matches[replay.id];
      const steps = data === undefined ? [] : AsyncData.getOrElse(AsyncData.map(data, stepsOf), () => []);

      if (steps.length === 0) return { model };

      const at = Math.max(0, Math.min(steps.length - 1, choose(replayIndex(replay, steps))));

      return { model: modifyFields(model, { maybeReplay: () => Option.some({ ...replay, maybeAt: Option.some(at) }) }) };
    },
  });

const openReplay = (model: Model, id: string, maybeFocus: Option.Option<number>): Return => {
  const opened = withMatches(modifyFields(model, { maybeReplay: () => Option.some({ id, maybeFocus, maybeAt: Option.none() }) }), [id]);

  // Opening another match from a replay reuses its history entry.
  return Option.isSome(model.maybeReplay) ? opened : { ...opened, commands: [...(opened.commands ?? []), PushReplayHistory()] };
};

const withFilter = (model: Model, change: (filter: Filter) => Filter): Return => withPickedMatches(modifyFields(model, { filter: change }));

export const update = (model: Model, message: Message): Return =>
  Message.match<Return>(message, {
    ResizedViewport: (viewport) => ({ model: modifyFields(model, { viewport: () => viewport }) }),
    ClickedTab: ({ tab }) => ({ model: modifyFields(model, { tab: () => tab, maybeRateTip: () => Option.none() }), commands: [WriteHash({ tab }), ScrollToTop()] }),
    NavigatedToTab: ({ tab }) => ({ model: modifyFields(model, { tab: () => tab }), commands: [ScrollToTop()] }),
    CompletedHashWrite: () => ({ model }),
    SucceededLoad: ({ loaded }) => withPickedMatches(modifyFields(model, { data: () => AsyncData.succeed(loaded) })),
    FailedLoad: ({ error }) => ({ model: modifyFields(model, { data: () => AsyncData.fail(error) }) }),
    SelectedCohort: ({ cohort }) => withFilter(model, (filter) => ({ ...filter, cohort })),
    ToggledEffort: ({ effort }) => withFilter(model, (filter) => ({ ...filter, offEfforts: toggled(filter.offEfforts, effort) })),
    ToggledModel: ({ name }) => withFilter(model, (filter) => ({ ...filter, offModels: toggled(filter.offModels, name) })),
    SelectedScatterShow: ({ show }) => ({ model: modifyFields(model, { scatter: (scatter) => ({ ...scatter, show }) }) }),
    HoveredPoint: ({ key }) => ({ model: modifyFields(model, { scatter: (scatter) => ({ ...scatter, maybeHover: Option.some(key) }) }) }),
    LeftPoint: () => ({ model: modifyFields(model, { scatter: (scatter) => ({ ...scatter, maybeHover: Option.none() }) }) }),
    ClickedPoint: ({ key }) => ({
      model: modifyFields(model, { scatter: (scatter) => ({ ...scatter, maybePin: Option.exists(scatter.maybePin, (pinned) => pinned === key) ? Option.none() : Option.some(key) }) }),
    }),
    ClickedOutsideChart: () => ({ model: modifyFields(model, { scatter: (scatter) => ({ ...scatter, maybePin: Option.none(), maybeHover: Option.none() }) }) }),
    SelectedHeatMode: ({ mode }) => ({ model: modifyFields(model, { heat: (heat) => ({ ...heat, mode, maybeFlagged: Option.none(), maybeTip: Option.none() }) }) }),
    ClickedHeatColumn: ({ column }) => ({ model: modifyFields(model, { heat: (heat) => ({ ...heat, sort: column }) }) }),
    ToggledBestOnly: () => ({ model: modifyFields(model, { heat: (heat) => ({ ...heat, isBestOnly: !heat.isBestOnly }) }) }),
    HoveredCell: (cell) => ({ model: modifyFields(model, { heat: (heat) => ({ ...heat, maybeTip: Option.some(cell) }) }) }),
    LeftCell: () => ({ model: modifyFields(model, { heat: (heat) => ({ ...heat, maybeTip: Option.none() }) }) }),
    ClickedPatternCell: (flagged) => ({ model: modifyFields(model, { heat: (heat) => ({ ...heat, maybeFlagged: Option.some(flagged) }) }) }),
    ClosedFlagged: () => ({ model: modifyFields(model, { heat: (heat) => ({ ...heat, maybeFlagged: Option.none() }) }) }),
    ClickedLeaderboardRow: ({ id }) => ({
      model: modifyFields(model, { leaderboard: (leaderboard) => ({ maybeTip: Option.none(), maybeOpen: Option.exists(leaderboard.maybeOpen, (open) => open === id) ? Option.none() : Option.some(id) }) }),
    }),
    HoveredSquare: ({ matchId }) => ({ model: modifyFields(model, { leaderboard: (leaderboard) => ({ ...leaderboard, maybeTip: Option.some(matchId) }) }) }),
    LeftSquare: () => ({ model: modifyFields(model, { leaderboard: (leaderboard) => ({ ...leaderboard, maybeTip: Option.none() }) }) }),
    ClickedMatch: ({ id, maybeFocus }) => openReplay(model, id, maybeFocus),
    SucceededMatch: ({ id, detail }) => ({ model: modifyFields(model, { matches: (matches) => ({ ...matches, [id]: AsyncData.succeed(detail) }) }) }),
    FailedMatch: ({ id, error }) => ({ model: modifyFields(model, { matches: (matches) => ({ ...matches, [id]: AsyncData.fail(error) }) }) }),
    ClosedReplay: () => ({ model: modifyFields(model, { maybeReplay: () => Option.none() }), commands: [LeaveReplayHistory()] }),
    NavigatedBack: () => ({ model: modifyFields(model, { maybeReplay: () => Option.none() }) }),
    SteppedReplay: ({ delta }) => withReplayMove(model, (at) => at + delta),
    SelectedStep: ({ index }) => withReplayMove(model, () => index),
    ChangedMatchQuery: ({ query }) => ({ model: modifyFields(model, { matchList: (list) => ({ ...list, query }) }) }),
    ClickedShowMore: () => ({ model: modifyFields(model, { matchList: (list) => ({ ...list, limit: list.limit + MORE_ROWS }) }) }),
    HoveredRate: (cell) => ({ model: modifyFields(model, { maybeRateTip: () => Option.some(cell) }) }),
    LeftRate: () => ({ model: modifyFields(model, { maybeRateTip: () => Option.none() }) }),
    PlacedTip: () => ({ model }),
    CompletedHistoryChange: () => ({ model }),
    CompletedStepScroll: () => ({ model }),
    CompletedScroll: () => ({ model }),
  });

// INIT

const tabOfHash = (hash: string): Option.Option<Tab> => Schema.decodeUnknownOption(Tab)(hash.replace(/^#/, ""));

const Flags = Schema.Struct({ viewport: Schema.Struct({ width: Schema.Number, height: Schema.Number }), hash: Schema.String });

type Flags = typeof Flags.Type;

const init: Runtime.ApplicationInit<Model, Message, Flags> = ({ viewport, hash }) => ({
  model: {
    viewport,
    tab: Option.getOrElse(tabOfHash(hash), (): Tab => "overview"),
    data: AsyncData.Loading(),
    filter: { cohort: "all", offEfforts: [], offModels: [] },
    scatter: { show: "kept", maybeHover: Option.none(), maybePin: Option.none() },
    heat: { mode: "opp", sort: "rating", isBestOnly: false, maybeTip: Option.none(), maybeFlagged: Option.none() },
    leaderboard: { maybeOpen: Option.none(), maybeTip: Option.none() },
    matchList: { query: "", limit: 200 },
    maybeRateTip: Option.none(),
    matches: {},
    maybeReplay: Option.none(),
  },
  commands: [LoadData()],
});

// SUBSCRIPTION

const viewportNow = (): Viewport => ({ width: document.documentElement.clientWidth, height: innerHeight });

const replayKeyMessage = (key: string): Option.Option<Message> => {
  if (key === "Escape") return Option.some(Message.ClosedReplay());

  if (key === "ArrowRight" || key === "ArrowDown") return Option.some(Message.SteppedReplay({ delta: 1 }));

  return key === "ArrowLeft" || key === "ArrowUp" ? Option.some(Message.SteppedReplay({ delta: -1 })) : Option.none();
};

const subscriptions = Subscription.make<Model, Message>()((entry) => ({
  resize: Subscription.persistentEntry(Dom.streamFromEvent({ target: window, type: "resize", mapEvent: () => Message.ResizedViewport(viewportNow()) })),
  back: Subscription.persistentEntry(Dom.streamFromEvent({ target: window, type: "popstate", mapEvent: () => Message.NavigatedBack() })),
  // The arrows step through an open replay instead of scrolling the page.
  replayKeys: entry(
    { isReplayOpen: Schema.Boolean },
    {
      modelToDependencies: (model) => ({ isReplayOpen: Option.isSome(model.maybeReplay) }),
      dependenciesToStream: ({ isReplayOpen }) =>
        Stream.when(
          Dom.streamFromEventFilterMapPreventDefault({ target: window, type: "keydown", filterMapEvent: (event) => replayKeyMessage(event.key) }),
          Effect.sync(() => isReplayOpen),
        ),
    },
  ),
  hash: Subscription.persistentEntry(
    Dom.streamFromEventFilterMap({ target: window, type: "hashchange", filterMapEvent: () => Option.map(tabOfHash(location.hash), (tab) => Message.NavigatedToTab({ tab })) }),
  ),
}));

const application = Runtime.makeApplication({
  Model,
  Flags,
  init,
  update,
  view,
  subscriptions,
  container: document.getElementById("root"),
});

Runtime.run(application, { flags: Effect.sync(() => ({ viewport: viewportNow(), hash: location.hash })) });
