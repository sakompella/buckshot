import { Data, Effect, Option, Predicate, Schema, Stream } from "effect";
import { HttpClient, HttpClientResponse } from "effect/http";
import { AsyncData, Command, Dom, Http, Subscription, type Update } from "foldkit";
import { modifyFields } from "foldkit/struct";

import { aggregateUrl, isOnline } from "../../site/online.ts";
import { type ArenaRoute, arenaHref, arenaStateOf, replayHref } from "../../site/route.ts";
import { AGGREGATES } from "../aggregates.ts";
import { CertainMistakes, Decisions, Download, MatchDetailJson, SeatsResponse } from "../api.ts";
import { withPotShares } from "./data.ts";
import { INITIAL_ROWS, MORE_ROWS } from "./matches.ts";
import { type Filter, Group, GROUPS, type Lazy, type LazyName, LoadFailure, Message, type Model, MOVED_TARGETS, type Replay, Target, type Viewport } from "./model.ts";
import { replayIndex, stepsOf } from "./replay.ts";
import { reveal } from "./reveal.ts";
import { PlaceTour, tourKeyMessage, tourMatchOf, tourOf } from "./tour.ts";
import { stickyHeight } from "./view.ts";

type Return = Update.Return<Model, Message>;

const describe = (error: { readonly message: string }) => error.message;

/** No arena server answers: a static build of the site, whose host sends a 404 or the page itself for `/api/...`. */
class NoArenaServer extends Data.TaggedError("NoArenaServer") {}

const getJson = <A, I>(url: string, schema: Schema.Codec<A, I>) =>
  HttpClient.get(url).pipe(
    Effect.flatMap((response) => (response.status === 404 || !(response.headers["content-type"] ?? "").includes("json") ? Effect.fail(new NoArenaServer()) : Effect.succeed(response))),
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
  execute: Effect.all([getJson(aggregateUrl("summary"), AGGREGATES.summary), getJson(aggregateUrl("pairs"), AGGREGATES.pairs)], { concurrency: 2 }).pipe(
    Effect.map(([summary, pairs]) => Message.SucceededLoad({ loaded: { summary, pairs } })),
    Effect.catch((error) => Effect.succeed(Message.FailedLoad({ failure: error instanceof NoArenaServer ? LoadFailure.NoServer() : LoadFailure.Failed({ error: describe(error) }) }))),
    Effect.provide(Http.layer),
  ),
});

const lazyFailure = (name: LazyName) => (error: { readonly message: string }) => Effect.succeed(Message.FailedLazy({ name, error: describe(error) }));

const LoadItems = Command.define("LoadItems", {
  messages: [Message.SucceededItems, Message.FailedLazy],
  execute: getJson(aggregateUrl("items"), AGGREGATES.items).pipe(Effect.map((items) => Message.SucceededItems({ items })), Effect.catch(lazyFailure("items")), Effect.provide(Http.layer)),
});

const LoadOdds = Command.define("LoadOdds", {
  messages: [Message.SucceededOdds, Message.FailedLazy],
  execute: getJson(aggregateUrl("odds"), AGGREGATES.odds).pipe(Effect.map((odds) => Message.SucceededOdds({ odds })), Effect.catch(lazyFailure("odds")), Effect.provide(Http.layer)),
});

const LoadCertain = Command.define("LoadCertain", {
  messages: [Message.SucceededCertain, Message.FailedLazy],
  execute: getJson(aggregateUrl("certain"), AGGREGATES.certain).pipe(Effect.map((certain) => Message.SucceededCertain({ certain })), Effect.catch(lazyFailure("certain")), Effect.provide(Http.layer)),
});

const LoadConsistency = Command.define("LoadConsistency", {
  messages: [Message.SucceededConsistency, Message.FailedLazy],
  execute: getJson(aggregateUrl("consistency"), AGGREGATES.consistency).pipe(
    Effect.map((consistency) => Message.SucceededConsistency({ consistency })),
    Effect.catch(lazyFailure("consistency")),
    Effect.provide(Http.layer),
  ),
});

const LOAD_LAZY = { items: LoadItems, odds: LoadOdds, certain: LoadCertain, consistency: LoadConsistency } as const;

const LoadLocal = Command.define("LoadLocal", {
  messages: [Message.SucceededLocal, Message.FailedLocal],
  execute: Effect.all([getJson("/api/seats", SeatsResponse), getJson("/api/decisions", Decisions), getOptional("/api/certain-mistakes", CertainMistakes), getOptional("/api/download", Download)], { concurrency: 4 }).pipe(
    Effect.map(([seats, decisions, certainMoves, download]) => Message.SucceededLocal({ local: { seats: withPotShares(seats), decisions, certainMoves, download } })),
    Effect.catch((error) => Effect.succeed(Message.FailedLocal({ error: describe(error) }))),
    Effect.provide(Http.layer),
  ),
});

const withLazy = <N extends LazyName>(lazy: Lazy, name: N, data: Lazy[N]): Lazy => ({ ...lazy, [name]: data });

/** What a section needs beyond the first paint: an aggregate file, or the arena server's per-seat and per-move data. */
type Need = LazyName | "local";

const GROUP_NEEDS: Readonly<Record<Group, ReadonlyArray<Need>>> = {
  standings: [],
  decisions: ["certain", "odds", "items"],
  watch: ["local"],
  tables: ["certain", "local"],
};

const DRILL_NEEDS: ReadonlyArray<Need> = ["consistency", "items", "local"];

/** Starts fetching each need not yet asked for. The online build has no arena server, so it never asks for the local data. */
const withNeeds = (next: Return, needs: ReadonlyArray<Need>): Return => {
  const { model } = next;
  const lazy = needs.filter((need): need is LazyName => need !== "local" && Predicate.isTagged(model.lazy[need], "Idle"));
  const isLocalNeeded = !isOnline && needs.includes("local") && AsyncData.isIdle(model.local);

  if (lazy.length === 0 && !isLocalNeeded) return next;

  return {
    model: modifyFields(model, {
      lazy: (all) => lazy.reduce((loading, name) => withLazy(loading, name, AsyncData.Loading()), all),
      local: (local) => (isLocalNeeded ? AsyncData.Loading() : local),
    }),
    commands: [...(next.commands ?? []), ...lazy.map((name) => LOAD_LAZY[name]()), ...(isLocalNeeded ? [LoadLocal()] : [])],
  };
};

const LoadMatch = Command.define("LoadMatch", {
  args: { id: Schema.String },
  messages: [Message.SucceededMatch, Message.FailedMatch],
  execute: ({ id }) =>
    getJson(`/api/match?id=${encodeURIComponent(id)}`, MatchDetailJson).pipe(
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
      const nav = document.querySelector("main nav");
      const link = nav?.querySelector(`a[href="#${group}"]`);

      if (nav instanceof HTMLElement && link instanceof HTMLElement) nav.scrollTo({ left: link.offsetLeft - (nav.clientWidth - link.offsetWidth) / 2, behavior: "smooth" });
    }).pipe(Effect.as(Message.CompletedScroll())),
});

const groupInView = (): Option.Option<Message> => {
  const line = stickyHeight() + 8;
  const passed = [...document.querySelectorAll("section.part[id]")].filter((group) => group.getBoundingClientRect().top <= line).at(-1);

  return Option.map(Schema.decodeUnknownOption(Group)(passed?.id), (group) => Message.ScrolledInto({ group }));
};

/** The groups within a viewport above to two below the current one: the ones whose data should be on its way. */
const groupsNear = () =>
  Message.CameNear({
    groups: [...document.querySelectorAll("section.part[id]")].flatMap((part) => {
      const { top, bottom } = part.getBoundingClientRect();

      return bottom >= -innerHeight && top <= 2 * innerHeight ? Option.toArray(Schema.decodeUnknownOption(Group)(part.id)) : [];
    }),
  });

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

const MeasureNear = Command.define("MeasureNear", {
  messages: [Message.CameNear],
  execute: nextFrame.pipe(Effect.map(groupsNear)),
});

const NO_MARK_TIP: Model["markTip"] = { maybeHover: Option.none(), maybePin: Option.none() };

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

const openReplay = (model: Model, id: string, maybeFocus: Option.Option<number>): Return =>
  withNeeds(
    withMatches(
      modifyFields(model, {
        maybeReplay: () => Option.some({ id, maybeFocus, maybeAt: Option.none() }),
        maybeTappedTitle: () => Option.none(),
        markTip: () => NO_MARK_TIP,
      }),
      [id],
    ),
    ["local"],
  );

const closeReplay = (model: Model): Return => ({ model: modifyFields(model, { maybeReplay: () => Option.none() }) });

const openTourReplay = (model: Model): Return => {
  const seats = AsyncData.getOrElse(
    AsyncData.map(model.local, (local) => local.seats),
    () => [],
  );

  return Option.match(tourMatchOf(seats), { onNone: (): Return => ({ model }), onSome: (id) => openReplay(model, id, Option.none()) });
};

const thenReplay = (first: Return, next: (model: Model) => Return): Return => {
  const second = next(first.model);

  return { model: second.model, commands: [...(first.commands ?? []), ...(second.commands ?? [])] };
};

const withFilter = (model: Model, change: (filter: Filter) => Filter): Return => ({
  model: modifyFields(model, { filter: change, markTip: () => NO_MARK_TIP }),
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
    CompletedFirstPaint: () => ({ model: modifyFields(model, { isFirstPaintDone: () => true }), commands: [ScrollToHash(), MeasureNear()] }),
    FailedLoad: ({ failure }) => ({ model: modifyFields(model, { data: () => AsyncData.fail(failure) }) }),
    SucceededItems: ({ items }) => ({ model: modifyFields(model, { lazy: (lazy) => ({ ...lazy, items: AsyncData.succeed(items) }) }) }),
    SucceededOdds: ({ odds }) => ({ model: modifyFields(model, { lazy: (lazy) => ({ ...lazy, odds: AsyncData.succeed(odds) }) }) }),
    SucceededCertain: ({ certain }) => ({ model: modifyFields(model, { lazy: (lazy) => ({ ...lazy, certain: AsyncData.succeed(certain) }) }) }),
    SucceededConsistency: ({ consistency }) => ({ model: modifyFields(model, { lazy: (lazy) => ({ ...lazy, consistency: AsyncData.succeed(consistency) }) }) }),
    FailedLazy: ({ name, error }) => ({ model: modifyFields(model, { lazy: (lazy) => withLazy(lazy, name, AsyncData.fail<string, never>(error)) }) }),
    SucceededLocal: ({ local }) => ({ model: modifyFields(model, { local: () => AsyncData.succeed(local) }) }),
    FailedLocal: ({ error }) => ({ model: modifyFields(model, { local: () => AsyncData.fail(error) }) }),
    CameNear: ({ groups }) => withNeeds({ model }, groups.flatMap((group) => GROUP_NEEDS[group])),
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

      return withNeeds({
        model: modifyFields(model, {
          scatter: (scatter) => ({ ...scatter, maybePin: isPinned ? Option.none() : Option.some(key) }),
          maybeDrill: (drill) => (Option.contains(drill, key) ? Option.none() : Option.some(key)),
          leaderboard: (leaderboard) => ({ ...leaderboard, maybeOpen: Option.none() }),
          markTip: () => NO_MARK_TIP,
        }),
      }, DRILL_NEEDS);
    },
    ClosedDrill: () => ({ model: modifyFields(model, { maybeDrill: () => Option.none() }) }),
    ClickedOutsideChart: () => ({
      model: modifyFields(model, { scatter: (scatter) => ({ ...scatter, maybePin: Option.none(), maybeHover: Option.none() }), markTip: () => NO_MARK_TIP }),
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
    ClickedLeaderboardRow: ({ id }) =>
      withNeeds(
        {
          model: modifyFields(model, {
            leaderboard: (leaderboard) => ({ maybeOpen: Option.exists(leaderboard.maybeOpen, (open) => open === id) ? Option.none() : Option.some(id) }),
            maybeDrill: () => Option.none(),
          }),
        },
        DRILL_NEEDS,
      ),
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
    ClosedReplay: () => closeReplay(model),
    SteppedReplay: ({ delta }) => withReplayMove(model, (at) => at + delta),
    SelectedStep: ({ index }) => withReplayMove(model, () => index),
    ChangedMatchQuery: ({ query }) => ({ model: modifyFields(model, { matchList: (list) => ({ ...list, query }) }) }),
    ClickedMatchPreset: ({ preset }) => ({
      model: modifyFields(model, { matchList: (list) => ({ ...list, limit: INITIAL_ROWS, maybePreset: Option.exists(list.maybePreset, (chosen) => chosen === preset) ? Option.none() : Option.some(preset) }) }),
    }),
    ClickedShowMore: () => ({ model: modifyFields(model, { matchList: (list) => ({ ...list, limit: list.limit + MORE_ROWS }) }) }),
    PlacedTip: () => ({ model }),
    CompletedStepScroll: () => ({ model }),
    CompletedScroll: () => ({ model }),
    ClickedTour: () => {
      const hasCertain = AsyncData.matchData(model.data, { onEmpty: () => false, onFailure: () => false, onData: ({ summary }) => summary.hasCertain });

      return withNeeds(
        { model: modifyFields(model, { maybeTour: () => Option.some({ step: 0, hasCertain, maybeBox: Option.none(), isCardUnder: false }) }), commands: [PlaceTour({ step: 0, hasCertain })] },
        GROUPS.flatMap(({ group }) => GROUP_NEEDS[group]),
      );
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

/** Applies what an arena URL says: the filter and open row of `/arena`, or the replay of `/replay/<id>` over them. */
export const withRoute = (model: Model, route: ArenaRoute): Return => {
  if (Predicate.isTagged(route, "Replay")) return openReplay(model, route.id, Option.fromUndefinedOr(route.at));

  const { filter, maybeRow } = arenaStateOf(route);
  const routed: Return = { model: modifyFields(model, { filter: () => filter, leaderboard: () => ({ maybeOpen: maybeRow }), maybeReplay: () => Option.none() }) };

  return Option.isSome(maybeRow) ? withNeeds(routed, DRILL_NEEDS) : routed;
};

/** The ordinal of the move an open replay shows, once its match has loaded; before that, the one it was asked to show. */
const replayOrdinal = (model: Model, replay: Replay): Option.Option<number> => {
  const data = model.matches[replay.id];
  const steps = data === undefined ? [] : AsyncData.getOrElse(AsyncData.map(data, stepsOf), () => []);

  return steps.length === 0 || Option.isNone(replay.maybeAt) ? replay.maybeFocus : Option.fromUndefinedOr(steps[replayIndex(replay, steps)]?.ordinal);
};

/** The URL of what the arena shows, so it can be shared and survives a reload. */
export const hrefOf = (model: Model): string =>
  Option.match(model.maybeReplay, {
    onNone: () => arenaHref(model.filter, model.leaderboard.maybeOpen),
    onSome: (replay) => replayHref(replay.id, replayOrdinal(model, replay)),
  });

export const init = (viewport: Viewport, route: ArenaRoute): Return => {
  const model: Model = {
    viewport,
    data: AsyncData.Loading(),
    lazy: { items: AsyncData.Idle(), odds: AsyncData.Idle(), certain: AsyncData.Idle(), consistency: AsyncData.Idle() },
    local: AsyncData.Idle(),
    filter: { offEfforts: [], offModels: [] },
    scatter: { axis: "cost", maybeHover: Option.none(), maybePin: Option.none() },
    heat: { sort: "rating", maybeTip: Option.none() },
    leaderboard: { maybeOpen: Option.none() },
    maybeDrill: Option.none(),
    maybeCertainOpen: Option.none(),
    matchList: { query: "", limit: INITIAL_ROWS, maybePreset: Option.none() },
    maybeTappedTitle: Option.none(),
    markTip: NO_MARK_TIP,
    maybeGroup: Option.some("standings"),
    isFiltersOpen: false,
    matches: {},
    maybeReplay: Option.none(),
    isFirstPaintDone: false,
    maybeTour: Option.none(),
  };

  const routed = withRoute(model, route);

  return { model: routed.model, commands: [LoadData(), ...(routed.commands ?? [])] };
};

export const viewportNow = (): Viewport => ({ width: document.documentElement.clientWidth, height: innerHeight });

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

export const subscriptions = Subscription.make<Model, Message>()((entry) => ({
  resize: Subscription.persistentEntry(Dom.streamFromEvent({ target: window, type: "resize", mapEvent: () => Message.ResizedViewport(viewportNow()) })),
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
  near: Subscription.persistentEntry(Dom.streamFromEvent({ target: window, type: "scroll", mapEvent: groupsNear })),
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
