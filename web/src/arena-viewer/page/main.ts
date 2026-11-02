import { Effect, Option, Schema, Stream } from "effect";
import { HttpClient, HttpClientResponse } from "effect/http";
import { AsyncData, Command, Dom, Http, Runtime, Subscription, type Update } from "foldkit";
import { modifyFields } from "foldkit/struct";

import { CertainMistakes, Consistency, Decisions, Download, MatchDetail, SeatsResponse } from "../api.ts";
import { hasCertainChart } from "./certain.ts";
import { withPotShares } from "./data.ts";
import { INITIAL_ROWS, MORE_ROWS } from "./matches.ts";
import { type Filter, Group, Message, Model, MOVED_TARGETS, Target, type Viewport } from "./model.ts";
import { replayIndex, stepsOf } from "./replay.ts";
import { reveal } from "./reveal.ts";
import { PlaceTour, tourKeyMessage, tourMatchOf, tourOf } from "./tour.ts";
import { stickyHeight, view } from "./view.ts";

type Return = Update.Return<Model, Message>;

const describe = (error: { readonly message: string }) => error.message;

const getJson = <A, I>(url: string, schema: Schema.Codec<A, I>) =>
  HttpClient.get(url).pipe(
    Effect.flatMap(HttpClientResponse.filterStatusOk),
    Effect.flatMap((response) => response.json),
    Effect.flatMap((body) => Schema.decodeUnknownEffect(schema)(body)),
  );

const getOptional = <A, I>(url: string, schema: Schema.Codec<A, I>) =>
  getJson(url, schema).pipe(
    Effect.map((data) => AsyncData.succeed<A, string>(data)),
    Effect.catch((error) => Effect.succeed(AsyncData.fail<string, A>(describe(error)))),
  );

const LoadData = Command.define("LoadData", {
  messages: [Message.SucceededLoad, Message.FailedLoad],
  execute: Effect.all(
    [getJson("/api/seats", SeatsResponse), getJson("/api/decisions", Decisions), getOptional("/api/consistency", Schema.Array(Consistency)), getOptional("/api/certain-mistakes", CertainMistakes), getOptional("/api/download", Download)],
    { concurrency: 5 },
  ).pipe(
    Effect.map(([seats, decisions, consistency, certainMistakes, download]) => Message.SucceededLoad({ loaded: { seats: withPotShares(seats), decisions, consistency, certainMistakes, download } })),
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

const targetOfHash = (hash: string): Option.Option<Target> => {
  const id = hash.replace(/^#/, "");

  return Option.orElse(Schema.decodeUnknownOption(Target)(id), () => Option.fromUndefinedOr(MOVED_TARGETS.get(id)));
};

const scrollToTarget = (id: Target) => {
  const target = document.getElementById(id);

  if (target === null) return;

  reveal(target);
  // The target's top rule tucks under the bar's own.
  scrollTo(0, target.getBoundingClientRect().top + scrollY - stickyHeight() + 1);
};

/** Scrolls a group's or a section's heading to just below the sticky bar and puts it in the URL. */
const JumpTo = Command.define("JumpTo", {
  args: { target: Target },
  messages: [Message.CompletedScroll],
  execute: ({ target }) =>
    Effect.sync(() => {
      history.replaceState(history.state, "", `#${target}`);
      scrollToTarget(target);
    }).pipe(Effect.as(Message.CompletedScroll())),
});

const OpenTable = Command.define("OpenTable", {
  args: { id: Schema.String },
  messages: [Message.CompletedScroll],
  execute: ({ id }) =>
    Effect.sync(() => {
      const table = document.getElementById(id);

      if (table === null) return;

      reveal(table);
      scrollTo(0, table.getBoundingClientRect().top + scrollY - stickyHeight() - 8);
    }).pipe(Effect.as(Message.CompletedScroll())),
});

const RevealNavLink = Command.define("RevealNavLink", {
  args: { group: Group },
  messages: [Message.CompletedScroll],
  execute: ({ group }) =>
    Effect.sync(() => {
      const nav = document.querySelector("nav");
      const link = nav?.querySelector(`a[href="#${group}"]`);

      if (nav instanceof HTMLElement && link instanceof HTMLElement) nav.scrollTo({ left: link.offsetLeft - (nav.clientWidth - link.offsetWidth) / 2, behavior: "smooth" });
    }).pipe(Effect.as(Message.CompletedScroll())),
});

const groupInView = (): Option.Option<Message> => {
  const line = stickyHeight() + 8;
  const passed = [...document.querySelectorAll("section.part[id]")].filter((group) => group.getBoundingClientRect().top <= line).at(-1);

  return Option.map(Schema.decodeUnknownOption(Group)(passed?.id), (group) => Message.ScrolledInto({ group }));
};

const nextFrame = Effect.callback<void>((resume) => {
  requestAnimationFrame(() => requestAnimationFrame(() => resume(Effect.void)));
});

/** Scrolls to the section the URL names once the page has drawn it: the browser's own jump came before the data. */
const ScrollToHash = Command.define("ScrollToHash", {
  messages: [Message.CompletedScroll],
  execute: nextFrame.pipe(
    Effect.map(() => Option.map(targetOfHash(location.hash), scrollToTarget)),
    Effect.as(Message.CompletedScroll()),
  ),
});

const AwaitFirstPaint = Command.define("AwaitFirstPaint", {
  messages: [Message.CompletedFirstPaint],
  execute: nextFrame.pipe(Effect.as(Message.CompletedFirstPaint())),
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

const withMatches = (model: Model, ids: ReadonlyArray<string>): Return => {
  const missing = ids.filter((id) => model.matches[id] === undefined);

  if (missing.length === 0) return { model };

  return {
    model: modifyFields(model, { matches: (matches) => ({ ...matches, ...Object.fromEntries(missing.map((id) => [id, AsyncData.Loading()])) }) }),
    commands: missing.map((id) => LoadMatch({ id })),
  };
};

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
  const opened = withMatches(
    modifyFields(model, {
      maybeReplay: () => Option.some({ id, maybeFocus, maybeAt: Option.none() }),
      maybeTappedTitle: () => Option.none(),
      markTip: () => ({ maybeHover: Option.none(), maybePin: Option.none() }),
    }),
    [id],
  );

  return Option.isSome(model.maybeReplay) ? opened : { ...opened, commands: [...(opened.commands ?? []), PushReplayHistory()] };
};

const closeReplay = (model: Model): Return => ({ model: modifyFields(model, { maybeReplay: () => Option.none() }), commands: [LeaveReplayHistory()] });

const openTourReplay = (model: Model): Return => {
  const seats = AsyncData.getOrElse(
    AsyncData.map(model.data, (loaded) => loaded.seats),
    () => [],
  );

  return Option.match(tourMatchOf(seats), { onNone: (): Return => ({ model }), onSome: (id) => openReplay(model, id, Option.none()) });
};

const thenReplay = (first: Return, next: (model: Model) => Return): Return => {
  const second = next(first.model);

  return { model: second.model, commands: [...(first.commands ?? []), ...(second.commands ?? [])] };
};

const withFilter = (model: Model, change: (filter: Filter) => Filter): Return => ({
  model: modifyFields(model, { filter: change, markTip: () => ({ maybeHover: Option.none(), maybePin: Option.none() }) }),
});

export const update = (model: Model, message: Message): Return =>
  Message.match<Return>(message, {
    ResizedViewport: (viewport) => ({
      model: modifyFields(model, { viewport: () => viewport }),
      commands: Option.match(model.maybeTour, { onNone: () => [], onSome: ({ step, hasCertain }) => [PlaceTour({ step, hasCertain })] }),
    }),
    ClickedJump: ({ target }) => ({ model, commands: [JumpTo({ target })] }),
    ClickedTableLink: ({ id }) => ({ model, commands: [OpenTable({ id })] }),
    NavigatedToHash: () => ({ model, commands: [ScrollToHash()] }),
    SucceededLoad: ({ loaded }) => ({ model: modifyFields(model, { data: () => AsyncData.succeed(loaded) }), commands: [AwaitFirstPaint()] }),
    CompletedFirstPaint: () => ({ model: modifyFields(model, { isFirstPaintDone: () => true }), commands: [ScrollToHash()] }),
    FailedLoad: ({ error }) => ({ model: modifyFields(model, { data: () => AsyncData.fail(error) }) }),
    ToggledEffort: ({ effort }) => withFilter(model, (filter) => ({ ...filter, offEfforts: toggled(filter.offEfforts, effort) })),
    ToggledModel: ({ name }) => withFilter(model, (filter) => ({ ...filter, offModels: toggled(filter.offModels, name) })),
    ScrolledInto: ({ group }) =>
      Option.contains(model.maybeGroup, group) ? { model } : { model: modifyFields(model, { maybeGroup: () => Option.some(group) }), commands: [RevealNavLink({ group })] },
    ToggledFilters: () => ({ model: modifyFields(model, { isFiltersOpen: (isOpen) => !isOpen }) }),
    TappedTitle: ({ text }) => ({ model: modifyFields(model, { maybeTappedTitle: () => Option.some(text) }) }),
    ClearedTappedTitle: () => ({ model: modifyFields(model, { maybeTappedTitle: () => Option.none() }) }),
    SelectedScatterAxis: ({ axis }) => ({ model: modifyFields(model, { scatter: (scatter) => ({ ...scatter, axis }) }) }),
    HoveredPoint: ({ key }) => ({ model: modifyFields(model, { scatter: (scatter) => ({ ...scatter, maybeHover: Option.some(key) }) }) }),
    LeftPoint: () => ({ model: modifyFields(model, { scatter: (scatter) => ({ ...scatter, maybeHover: Option.none() }) }) }),
    ClickedPoint: ({ key }) => {
      const isPinned = Option.exists(model.scatter.maybePin, (pinned) => pinned === key);

      return {
        model: modifyFields(model, {
          scatter: (scatter) => ({ ...scatter, maybePin: isPinned ? Option.none() : Option.some(key) }),
          maybeDrill: (drill) => (Option.contains(drill, key) ? Option.none() : Option.some(key)),
          leaderboard: (leaderboard) => ({ ...leaderboard, maybeOpen: Option.none() }),
          markTip: () => ({ maybeHover: Option.none(), maybePin: Option.none() }),
        }),
      };
    },
    ClosedDrill: () => ({ model: modifyFields(model, { maybeDrill: () => Option.none() }) }),
    ClickedOutsideChart: () => ({
      model: modifyFields(model, { scatter: (scatter) => ({ ...scatter, maybePin: Option.none(), maybeHover: Option.none() }), markTip: () => ({ maybeHover: Option.none(), maybePin: Option.none() }) }),
    }),
    HoveredMark: ({ tip }) => ({ model: modifyFields(model, { markTip: (markTip) => ({ ...markTip, maybeHover: Option.some(tip) }) }) }),
    LeftMark: () => ({ model: modifyFields(model, { markTip: (markTip) => ({ ...markTip, maybeHover: Option.none() }) }) }),
    ClickedMark: ({ tip }) => ({
      model: modifyFields(model, {
        markTip: ({ maybePin }) => ({ maybeHover: Option.none(), maybePin: Option.exists(maybePin, ({ anchor }) => anchor === tip.anchor) ? Option.none() : Option.some(tip) }),
        scatter: (scatter) => ({ ...scatter, maybePin: Option.none(), maybeHover: Option.none() }),
      }),
    }),
    ClickedHeatColumn: ({ column }) => ({ model: modifyFields(model, { heat: (heat) => ({ ...heat, sort: column }) }) }),
    HoveredCell: (cell) => ({ model: modifyFields(model, { heat: (heat) => ({ ...heat, maybeTip: Option.some(cell) }) }) }),
    LeftCell: () => ({ model: modifyFields(model, { heat: (heat) => ({ ...heat, maybeTip: Option.none() }) }) }),
    ClickedLeaderboardRow: ({ id }) => ({
      model: modifyFields(model, {
        leaderboard: (leaderboard) => ({ maybeOpen: Option.exists(leaderboard.maybeOpen, (open) => open === id) ? Option.none() : Option.some(id) }),
        maybeDrill: () => Option.none(),
      }),
    }),
    ClickedCertainCount: ({ key, type }) => ({
      model: modifyFields(model, { maybeCertainOpen: (open) => (Option.exists(open, (cell) => cell.key === key && cell.type === type) ? Option.none() : Option.some({ key, type })) }),
    }),
    ClickedMatch: ({ id, maybeFocus }) => openReplay(model, id, maybeFocus),
    SucceededMatch: ({ id, detail }) => ({
      model: modifyFields(model, { matches: (matches) => ({ ...matches, [id]: AsyncData.succeed(detail) }) }),
      commands: Option.match(model.maybeTour, {
        onNone: () => [],
        onSome: ({ step, hasCertain }) => (tourOf(hasCertain)[step]?.isReplay === true ? [PlaceTour({ step, hasCertain })] : []),
      }),
    }),
    FailedMatch: ({ id, error }) => ({ model: modifyFields(model, { matches: (matches) => ({ ...matches, [id]: AsyncData.fail(error) }) }) }),
    ClosedReplay: () => ({ model: modifyFields(model, { maybeReplay: () => Option.none() }), commands: [LeaveReplayHistory()] }),
    NavigatedBack: () => ({ model: modifyFields(model, { maybeReplay: () => Option.none() }) }),
    SteppedReplay: ({ delta }) => withReplayMove(model, (at) => at + delta),
    SelectedStep: ({ index }) => withReplayMove(model, () => index),
    ChangedMatchQuery: ({ query }) => ({ model: modifyFields(model, { matchList: (list) => ({ ...list, query }) }) }),
    ClickedMatchPreset: ({ preset }) => ({
      model: modifyFields(model, { matchList: (list) => ({ ...list, limit: INITIAL_ROWS, maybePreset: Option.exists(list.maybePreset, (chosen) => chosen === preset) ? Option.none() : Option.some(preset) }) }),
    }),
    ClickedShowMore: () => ({ model: modifyFields(model, { matchList: (list) => ({ ...list, limit: list.limit + MORE_ROWS }) }) }),
    PlacedTip: () => ({ model }),
    CompletedHistoryChange: () => ({ model }),
    CompletedStepScroll: () => ({ model }),
    CompletedScroll: () => ({ model }),
    ClickedTour: () => {
      const hasCertain = AsyncData.matchData(model.data, { onEmpty: () => false, onFailure: () => false, onData: ({ certainMistakes }) => hasCertainChart(certainMistakes) });

      return { model: modifyFields(model, { maybeTour: () => Option.some({ step: 0, hasCertain, maybeBox: Option.none(), isCardUnder: false }) }), commands: [PlaceTour({ step: 0, hasCertain })] };
    },
    SteppedTour: ({ delta }) =>
      Option.match(model.maybeTour, {
        onNone: (): Return => ({ model }),
        onSome: (tour): Return => {
          const steps = tourOf(tour.hasCertain);
          const step = Math.max(0, Math.min(steps.length - 1, tour.step + delta));

          if (step === tour.step) return { model };

          const toured: Return = { model: modifyFields(model, { maybeTour: () => Option.some({ ...tour, step }) }), commands: [PlaceTour({ step, hasCertain: tour.hasCertain })] };
          const wasReplay = steps[tour.step]?.isReplay === true;
          const isReplay = steps[step]?.isReplay === true;

          if (isReplay && !wasReplay) return thenReplay(toured, openTourReplay);

          return wasReplay && !isReplay ? thenReplay(toured, closeReplay) : toured;
        },
      }),
    ClosedTour: () => {
      const closed: Return = { model: modifyFields(model, { maybeTour: () => Option.none() }) };

      return Option.exists(model.maybeTour, ({ step, hasCertain }) => tourOf(hasCertain)[step]?.isReplay === true) ? thenReplay(closed, closeReplay) : closed;
    },
    PlacedTour: ({ step, maybeBox, isCardUnder }) => ({
      model: modifyFields(model, { maybeTour: (maybeTour) => Option.map(maybeTour, (tour) => (tour.step === step ? { ...tour, maybeBox, isCardUnder } : tour)) }),
    }),
  });

const Flags = Schema.Struct({ viewport: Schema.Struct({ width: Schema.Number, height: Schema.Number }) });

type Flags = typeof Flags.Type;

const init: Runtime.ApplicationInit<Model, Message, Flags> = ({ viewport }) => ({
  model: {
    viewport,
    data: AsyncData.Loading(),
    filter: { offEfforts: [], offModels: [] },
    scatter: { axis: "cost", maybeHover: Option.none(), maybePin: Option.none() },
    heat: { sort: "rating", maybeTip: Option.none() },
    leaderboard: { maybeOpen: Option.none() },
    maybeDrill: Option.none(),
    maybeCertainOpen: Option.none(),
    matchList: { query: "", limit: INITIAL_ROWS, maybePreset: Option.none() },
    maybeTappedTitle: Option.none(),
    markTip: { maybeHover: Option.none(), maybePin: Option.none() },
    maybeGroup: Option.some("standings"),
    isFiltersOpen: false,
    matches: {},
    maybeReplay: Option.none(),
    isFirstPaintDone: false,
    maybeTour: Option.none(),
  },
  commands: [LoadData()],
});

const viewportNow = (): Viewport => ({ width: document.documentElement.clientWidth, height: innerHeight });

const replayKeyMessage = (key: string): Option.Option<Message> => {
  if (key === "Escape") return Option.some(Message.ClosedReplay());

  if (key === "ArrowRight" || key === "ArrowDown") return Option.some(Message.SteppedReplay({ delta: 1 }));

  return key === "ArrowLeft" || key === "ArrowUp" ? Option.some(Message.SteppedReplay({ delta: -1 })) : Option.none();
};

// Controls answer a tap themselves; a tap anywhere else shows the nearest title (or a heat cell's data-tip), or clears the one shown.
const tappedTitleMessage = (event: PointerEvent): Option.Option<Message> => {
  if (event.pointerType !== "touch" || !(event.target instanceof Element) || event.target.closest("button, a, select, input, label, summary, [role=button], .tip") !== null) return Option.none();

  for (let element: Element | null = event.target; element !== null; element = element.parentElement) {
    const text = element.getAttribute("data-tip") ?? element.querySelector(":scope > title")?.textContent ?? element.getAttribute("title");

    if (text) return Option.some(Message.TappedTitle({ text }));
  }

  return Option.some(Message.ClearedTappedTitle());
};

const subscriptions = Subscription.make<Model, Message>()((entry) => ({
  resize: Subscription.persistentEntry(Dom.streamFromEvent({ target: window, type: "resize", mapEvent: () => Message.ResizedViewport(viewportNow()) })),
  back: Subscription.persistentEntry(Dom.streamFromEvent({ target: window, type: "popstate", mapEvent: () => Message.NavigatedBack() })),
  replayKeys: entry(
    { isReplayOpen: Schema.Boolean },
    {
      modelToDependencies: (model) => ({ isReplayOpen: Option.isSome(model.maybeReplay) && Option.isNone(model.maybeTour) }),
      dependenciesToStream: ({ isReplayOpen }) =>
        Stream.when(
          Dom.streamFromEventFilterMapPreventDefault({ target: window, type: "keydown", filterMapEvent: (event) => replayKeyMessage(event.key) }),
          Effect.sync(() => isReplayOpen),
        ),
    },
  ),
  scroll: Subscription.persistentEntry(Dom.streamFromEventFilterMap({ target: window, type: "scroll", filterMapEvent: groupInView })),
  tappedTitle: Subscription.persistentEntry(Dom.streamFromEventFilterMap({ target: window, type: "pointerup", filterMapEvent: tappedTitleMessage })),
  tourKeys: entry(
    { isTourOpen: Schema.Boolean },
    {
      modelToDependencies: (model) => ({ isTourOpen: Option.isSome(model.maybeTour) }),
      dependenciesToStream: ({ isTourOpen }) =>
        Stream.when(
          Dom.streamFromEventFilterMapPreventDefault({ target: window, type: "keydown", filterMapEvent: (event) => tourKeyMessage(event.key) }),
          Effect.sync(() => isTourOpen),
        ),
    },
  ),
  hash: Subscription.persistentEntry(Dom.streamFromEvent({ target: window, type: "hashchange", mapEvent: () => Message.NavigatedToHash() })),
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

Runtime.run(application, { flags: Effect.sync(() => ({ viewport: viewportNow() })) });
