import { Option } from "effect";
import { AsyncData } from "foldkit";
import { createLazy, type Document, type Html, type HtmlBuilder } from "foldkit/html";

import { EFFORTS, effortName } from "../../arena/model-names.ts";
import { baseName, baseOrder, colorOf, fmtBytes, fmtCount, type MatchRow, sumOf, unique } from "./data.ts";
import { tipView } from "./charts.ts";
import { type CertainLinks, certainTableView, certainView } from "./certain.ts";
import { allMatchesOf, type Derived, derive, keptMatchesOf, memoLast } from "./derived.ts";
import { itemUsageView } from "./fates.ts";
import { breakdownView, heatRowsOf } from "./heat.ts";
import { accuracyTableView, configPanelView, leaderboardView } from "./leaderboard.ts";
import { oddsView } from "./odds.ts";
import { matchesView } from "./matches.ts";
import { type Group, GROUPS, LoadFailure, type Local, Message, type Model, type Section, type Viewport } from "./model.ts";
import { replayView } from "./replay.ts";
import { scatterView } from "./scatter.ts";
import { tourView } from "./tour.ts";

type H = HtmlBuilder<Message>;

/** The width inside main's padding, as styles.css lays it out. */
export const contentWidth = ({ width }: Viewport): number => {
  const padding = width < 640 ? 12 : width <= 1024 ? 20 : 36;

  return Math.min(width, 1500) - 2 * padding;
};

/** The bar that stays at the top: the jump menu and filters together on a wide screen, the jump menu alone below. */
export const stickyHeight = (): number => {
  const sticky = [...document.querySelectorAll(".top, nav")].find((element) => getComputedStyle(element).position === "sticky");

  return sticky?.getBoundingClientRect().height ?? 0;
};

/** The width inside a .card: its padding and border. */
const cardWidth = (viewport: Viewport): number => Math.max(0, contentWidth(viewport) - 2 * (viewport.width < 640 ? 10 : 20) - 2);

/** Which of `every` are on, in the fewest names: all, the ones on, or all but the ones off. */
const keptOf = (every: ReadonlyArray<string>, off: ReadonlyArray<string>, noun: string): string => {
  const on = every.filter((value) => !off.includes(value));
  const offShown = every.filter((value) => off.includes(value));

  if (offShown.length === 0) return `all ${noun}`;

  if (on.length === 0) return `no ${noun}`;

  return on.length <= offShown.length ? on.join(", ") : `${noun} but ${offShown.join(", ")}`;
};

const filtersView = (h: H, derived: Derived, filter: Model["filter"], isOpen: boolean): Html => {
  const seats = derived.everyPooled;
  const models = unique(seats.map(({ model }) => model)).toSorted((left, right) => baseOrder(left) - baseOrder(right));
  const names = unique(models.map((model) => baseName(model)));
  const efforts = EFFORTS.filter((effort) => seats.some((seat) => seat.effort === effort));
  const summary = [keptOf(names, filter.offModels, "models"), keptOf(efforts.map(effortName), filter.offEfforts.map(effortName), "efforts")].join(" · ");

  return h.div(
    [h.Class(isOpen ? "filters open" : "filters")],
    [
      h.button([h.Type("button"), h.Class("filtersum"), h.AriaExpanded(isOpen), h.OnClick(Message.ToggledFilters())], [h.span([], [summary]), h.span([h.Class("k")], [isOpen ? "done" : "change"])]),
      h.span(
        [h.Class("chips")],
        names.map((name) => {
          const model = models.find((candidate) => baseName(candidate) === name) ?? name;

          return h.button(
            [h.Type("button"), h.Class(`chip ${filter.offModels.includes(name) ? "" : "on"}`), h.OnClick(Message.ToggledModel({ name }))],
            [h.i([h.Style({ background: colorOf(model) })], []), name],
          );
        }),
      ),
      h.span(
        [h.Class("chips")],
        efforts.map((effort) => h.button([h.Type("button"), h.Class(`chip ${filter.offEfforts.includes(effort) ? "" : "on"}`), h.OnClick(Message.ToggledEffort({ effort }))], [effortName(effort)])),
      ),
    ],
  );
};

const heroView = (h: H, derived: Derived): Html => {
  const scored = sumOf(derived.pairs.map((pair) => pair.scored));
  const stat = (label: string, value: string) => [h.dt([], [label]), h.dd([], [value])];

  return h.div(
    [h.Class("hero")],
    [
      h.div(
        [],
        [
          h.div([h.Class("title")], ["Buckshot Arena"]),
          h.p([h.Class("lead")], ["Frontier models playing two-player Buckshot Roulette. ", h.button([h.Type("button"), h.Class("tourstart"), h.OnClick(Message.ClickedTour())], ["Take the tour"])]),
        ],
      ),
      h.dl(
        [h.Class("stats")],
        [
          ...stat("scored matches", scored.toLocaleString()),
          ...stat("configs", String(heatRowsOf(derived).length)),
          ...stat("model moves", fmtCount(sumOf(derived.pooled.map(({ startedMoves }) => startedMoves)))),
          ...stat("list-price cost", `$${Math.round(sumOf(derived.pooled.map(({ totalCost }) => totalCost))).toLocaleString()}`),
        ],
      ),
    ],
  );
};

// A lazy slot reuses its last view only when the view function and every argument are the same references, so
// each slot is handed a module-level function, never an arrow made during the render, and only the parts of the
// model its section reads.

const lazyHero = createLazy();

const lazyNav = createLazy();

const lazyFilters = createLazy();

const lazyLeaderboard = createLazy();

const lazyScatter = createLazy();

const lazyMatches = createLazy();

const lazyCertain = createLazy();

const lazyCertainTable = createLazy();

const lazyAccuracyTable = createLazy();

const lazyOdds = createLazy();

const lazyItems = createLazy();

const lazyBreakdown = createLazy();

const lazyReplay = createLazy();

const lazyDrill = createLazy();

const navView = (h: H, maybeGroup: Option.Option<Group>): Html =>
  h.nav(
    [],
    [
      h.span([h.Class("brand")], ["Buckshot Arena"]),
      ...GROUPS.map(({ group, label }) =>
        h.a([h.Href(`#${group}`), ...(Option.contains(maybeGroup, group) ? [h.Class("on"), h.AriaCurrent("location")] : []), h.OnClick(Message.ClickedJump({ target: group }), { defaultAction: "Prevent" })], [label]),
      ),
    ],
  );

const footView = (h: H, local: Model["local"]): Html =>
  AsyncData.matchData(AsyncData.flatMap(local, ({ download }) => download), {
    onEmpty: () => h.empty,
    onFailure: () => h.empty,
    onData: ({ bytes }) => h.footer([h.Class("foot")], [h.a([h.Class("download"), h.Href("/api/db")], [`Database (SQLite, ${fmtBytes(bytes)})`])]),
  });

const scatterCard = (h: H, derived: Derived, scatter: Model["scatter"], width: number): Html =>
  h.div([h.Class("card")], [scatterView(h, derived.pooled, derived.everyPooled, derived.ratings, derived.ranks, scatter, width)]);

const drillCard = (h: H, derived: Derived, maybeDrill: Model["maybeDrill"], lazy: Model["lazy"]): Html =>
  Option.match(maybeDrill, { onNone: () => h.empty, onSome: (key) => configPanelView(h, derived, key, lazy) });

const optionalView = <A>(h: H, data: AsyncData.AsyncData<A, string>, what: string, draw: (loaded: A) => Html): Html =>
  AsyncData.matchData(data, {
    onEmpty: () => h.empty,
    onFailure: (error) => h.div([h.Class("card")], [h.p([h.Class("k")], [`Could not load the ${what}: ${error}`])]),
    onData: draw,
  });

const certainLinksOf = memoLast((local: Local): Option.Option<CertainLinks> =>
  Option.map(AsyncData.getData(local.certainMoves), (certain) => ({ certain, seats: local.seats, allMatches: allMatchesOf(local.seats) })),
);

const NO_MATCHES: ReadonlyArray<MatchRow> = [];

const localData = (local: Model["local"]): Option.Option<Local> => AsyncData.getData(local);

const isDrawn = (group: Group): boolean => GROUPS.some((entry) => entry.group === group);

const sectionView = (h: H, section: Section, content: Html): Html => h.section([h.Id(section)], [content]);

const groupLabel = (group: Group): string => GROUPS.find((entry) => entry.group === group)?.label ?? group;

/** A group of sections under one heading: what the jump menu links to. */
const groupView = (h: H, group: Group, sections: ReadonlyArray<Html>): Html => h.section([h.Id(group), h.Class("part")], [h.h1([h.Class("ghead")], [groupLabel(group)]), ...sections]);

const pageView = (h: H, model: Model, derived: Derived): Html => {
  const content = contentWidth(model.viewport);
  const card = cardWidth(model.viewport);
  const { lazy, local } = model;
  const afterFirstPaint = (draw: () => Html): Html => (model.isFirstPaintDone ? draw() : h.empty);
  const maybeLinks = Option.flatMap(localData(local), certainLinksOf);

  return h.div(
    [],
    [
      lazyHero(heroView, [h, derived]),
      h.div([h.Class("top")], [lazyNav(navView, [h, model.maybeGroup]), lazyFilters(filtersView, [h, derived, model.filter, model.isFiltersOpen])]),
      groupView(h, "standings", [
        sectionView(h, "scatter", h.div([], [lazyScatter(scatterCard, [h, derived, model.scatter, card]), lazyDrill(drillCard, [h, derived, model.maybeDrill, lazy])])),
        sectionView(h, "breakdown", afterFirstPaint(() => lazyBreakdown(breakdownView, [h, derived, model.heat]))),
      ]),
      groupView(h, "decisions", [
        ...(derived.hasCertain
          ? [sectionView(h, "certain-mistakes", afterFirstPaint(() => optionalView(h, lazy.certain, "certain mistakes", (rates) => lazyCertain(certainView, [h, rates, derived.kept, model.viewport.width, content]))))]
          : []),
        sectionView(h, "odds", afterFirstPaint(() => optionalView(h, lazy.odds, "odds", (odds) => lazyOdds(oddsView, [h, odds, derived.kept, model.viewport.width, content])))),
        sectionView(h, "items", afterFirstPaint(() => optionalView(h, lazy.items, "items", (items) => lazyItems(itemUsageView, [h, items, derived.kept])))),
      ]),
      ...(isDrawn("watch")
        ? [
            groupView(h, "watch", [
              sectionView(
                h,
                "matches",
                optionalView(h, local, "matches", ({ seats }) => lazyMatches(matchesView, [h, keptMatchesOf(allMatchesOf(seats), derived.kept), derived.ratings, model.matchList])),
              ),
            ]),
          ]
        : []),
      groupView(h, "tables", [
        afterFirstPaint(() =>
          h.details(
            [h.Class("tables")],
            [
              h.summary([], ["Leaderboard · Accuracy · Certain mistakes by config"]),
              sectionView(h, "leaderboards", lazyLeaderboard(leaderboardView, [h, derived, model.leaderboard, lazy])),
              derived.everyPooled.some(({ regret }) => regret !== null) ? lazyAccuracyTable(accuracyTableView, [h, derived]) : h.empty,
              AsyncData.matchData(lazy.certain, {
                onEmpty: () => h.empty,
                onFailure: () => h.empty,
                onData: (rates) => (rates.length === 0 ? h.empty : lazyCertainTable(certainTableView, [h, rates, derived.kept, maybeLinks, model.maybeCertainOpen])),
              }),
            ],
          ),
        ),
      ]),
      footView(h, local),
    ],
  );
};

const isPinned = (model: Model): boolean => Option.isSome(model.scatter.maybePin) || Option.isSome(model.scatter.maybeHover) || Option.isSome(model.markTip.maybePin);

export const view = (model: Model, h: H): Document =>
  AsyncData.matchData(model.data, {
    onEmpty: () => ({ title: "Buckshot Arena", body: h.main([], [h.p([h.Class("k")], ["Loading the analysis database…"])]) }),
    onFailure: (failure) => ({
      title: "Buckshot Arena",
      body: h.main(
        [],
        [
          h.p(
            [h.Class("k")],
            [
              LoadFailure.match(failure, {
                NoServer: () => "The arena needs the arena data, which this copy of the site does not serve. Run the arena viewer (web/README.md) to see it.",
                Failed: ({ error }) => `Could not load the analysis database: ${error}`,
              }),
            ],
          ),
        ],
      ),
    }),
    onData: (loaded) => {
      const derived = derive(loaded, model.filter);

      const replay = Option.match(model.maybeReplay, {
        onNone: () => h.empty,
        onSome: (open) => lazyReplay(replayView, [h, open, model.matches[open.id], Option.match(localData(model.local), { onNone: () => NO_MATCHES, onSome: ({ seats }) => allMatchesOf(seats) }), model.viewport]),
      });

      return {
        title: "Buckshot Arena",
        body: h.div(
          [],
          [
            // Touch has no hover: a tap pins a point, and a tap anywhere outside the chart unpins it.
            h.main(isPinned(model) ? [h.OnClick(Message.ClickedOutsideChart())] : [], [pageView(h, model, derived)]),
            replay,
            Option.match(Option.orElse(model.markTip.maybeHover, () => model.markTip.maybePin), { onNone: () => h.empty, onSome: ({ anchor, text }) => tipView(h, anchor, [text]) }),
            Option.match(model.maybeTappedTitle, { onNone: () => h.empty, onSome: (text) => h.div([h.Class("tip tapped"), h.Role("status")], [text]) }),
            Option.match(model.maybeTour, { onNone: () => h.empty, onSome: (tour) => tourView(h, tour, model.viewport.width) }),
          ],
        ),
      };
    },
  });
