import { Option } from "effect";
import { AsyncData } from "foldkit";
import { createLazy, type Document, type Html, type HtmlBuilder } from "foldkit/html";

import type { Blunders } from "../api.ts";
import { baseName, baseOrder, colorOf, EFFORTS, fmtCount, keyOf, sumOf, unique } from "./data.ts";
import { switchView, tipView } from "./charts.ts";
import { consistencyView } from "./consistency.ts";
import { type Derived, derive, mainConfigsOf, ratingsOf } from "./derived.ts";
import { dealsView } from "./deals.ts";
import { blunderCardsView, blunderRatesView, everyRateFor, galleryFor, ratesFor } from "./blunders.ts";
import { fatesView } from "./fates.ts";
import { breakdownView, heatRowsOf } from "./heat.ts";
import { interestingView, picksOf } from "./interesting.ts";
import { luckView } from "./luck.ts";
import { leaderboardView } from "./leaderboard.ts";
import { oddsView } from "./odds.ts";
import { mistakesView } from "./mistakes.ts";
import { matchesView } from "./matches.ts";
import { momentumView } from "./momentum.ts";
import { type Basis, type Group, GROUPS, Message, type Model, type Ranking, type Section, type Viewport } from "./model.ts";
import { pressureView } from "./pressure.ts";
import { reliabilityView } from "./reliability.ts";
import { replayView } from "./replay.ts";
import { rubberRows, rubbersView } from "./rubbers.ts";
import { scatterView } from "./scatter.ts";
import { seatsView } from "./seats.ts";
import { tourView } from "./tour.ts";
import { spendView } from "./spend.ts";

type H = HtmlBuilder<Message>;

// LAYOUT

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

// FILTERS

/** Which of `every` are on, in the fewest names: all, the ones on, or all but the ones off. */
const keptOf = (every: ReadonlyArray<string>, off: ReadonlyArray<string>, noun: string): string => {
  const on = every.filter((value) => !off.includes(value));
  const offShown = every.filter((value) => off.includes(value));

  if (offShown.length === 0) return `all ${noun}`;

  if (on.length === 0) return `no ${noun}`;

  return on.length <= offShown.length ? on.join(", ") : `${noun} but ${offShown.join(", ")}`;
};

const filtersView = (h: H, derived: Derived, filter: Model["filter"], isOpen: boolean): Html => {
  const { seats } = derived;
  const models = unique(seats.map(({ model }) => model)).toSorted((left, right) => baseOrder(left) - baseOrder(right));
  const names = unique(models.map((model) => baseName(model)));
  const efforts = EFFORTS.filter((effort) => seats.some((seat) => seat.effort === effort));
  const main = mainConfigsOf(seats);
  const hidden = unique(seats.map(keyOf)).filter((key) => !main.has(key)).length;

  // A phone or tablet shows one line saying what the filters keep, and the filters themselves only when it is tapped.
  const summary = [
    keptOf(names, filter.offModels, "models"),
    keptOf(efforts, filter.offEfforts, "efforts"),
    ...(hidden > 0 && !filter.isAllConfigs ? [`${hidden} configs hidden`] : []),
  ].join(" · ");

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
        efforts.map((effort) => h.button([h.Type("button"), h.Class(`chip ${filter.offEfforts.includes(effort) ? "" : "on"}`), h.OnClick(Message.ToggledEffort({ effort }))], [effort])),
      ),
      hidden > 0 ? switchView(h, filter.isAllConfigs, filter.isAllConfigs ? "all configs" : `all configs (${hidden} hidden)`, Message.ToggledAllConfigs()) : h.empty,
    ],
  );
};

// HERO

const heroView = (h: H, derived: Derived): Html => {
  const scored = derived.matches.filter(({ status }) => status === "completed").length;
  const stat = (label: string, value: string) => [h.dt([], [label]), h.dd([], [value])];

  return h.div(
    [h.Class("hero")],
    [
      h.div([], [h.div([h.Class("title")], ["Buckshot Arena"]), h.p([h.Class("lead")], ["Frontier models playing two-player Buckshot Roulette."])]),
      h.dl(
        [h.Class("stats")],
        [
          ...stat("scored matches", scored.toLocaleString()),
          ...stat("configs", String(heatRowsOf(derived).length)),
          ...stat("model moves", fmtCount(sumOf(derived.pooled.flatMap(({ started }) => started.map(({ moves }) => moves ?? 0))))),
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

const lazyScatter = createLazy();

const lazySpend = createLazy();

const lazyMomentum = createLazy();

const lazyConsistency = createLazy();

const lazyBreakdown = createLazy();

const lazyBlunderCards = createLazy();

const lazyBlunderRates = createLazy();

const lazyInteresting = createLazy();

const lazyLuck = createLazy();

const lazyMistakes = createLazy();

const lazySeats = createLazy();

const lazyOdds = createLazy();

const lazyPressure = createLazy();

const lazyRubbers = createLazy();

const lazyFates = createLazy();

const lazyDeals = createLazy();

const lazyReliability = createLazy();

const lazyMatches = createLazy();

const lazyLeaderboard = createLazy();

const lazyReplay = createLazy();

const navView = (h: H, maybeGroup: Option.Option<Group>): Html =>
  h.nav(
    [],
    [
      h.span([h.Class("brand")], ["Buckshot Arena"]),
      ...GROUPS.map(({ group, label }) =>
        h.a([h.Href(`#${group}`), ...(Option.contains(maybeGroup, group) ? [h.Class("on"), h.AriaCurrent("location")] : []), h.OnClick(Message.ClickedJump({ target: group }), { defaultAction: "Prevent" })], [label]),
      ),
      h.button([h.Type("button"), h.Class("tourstart"), h.OnClick(Message.ClickedTour())], ["Tour"]),
      h.a([h.Class("download"), h.Href("/api/db")], ["Database (SQLite)"]),
    ],
  );

const scatterCard = (h: H, derived: Derived, ranking: Ranking, basis: Basis, scatter: Model["scatter"], width: number): Html =>
  h.div([h.Class("card")], [scatterView(h, derived.pooled, derived.everyPooled, derived.ratings, derived.ranks, ranking, basis, scatter, width)]);

const spendCard = (h: H, derived: Derived): Html => h.div([h.Class("card")], [spendView(h, derived.pooled)]);

const blunderCardsCard = (h: H, derived: Derived, blunders: Blunders): Html => blunderCardsView(h, galleryFor(derived.seats, derived.keep, ratingsOf(derived.seats)("rounds"), blunders));

const blunderRatesCard = (h: H, derived: Derived, blunders: Blunders, width: number, content: number): Html =>
  blunderRatesView(h, ratesFor(derived.seats, derived.keep, blunders), everyRateFor(derived.seats, blunders), width, content);

/** An optional section's view, or, when its data did not load, a note in its place. */
const optionalView = <A>(h: H, data: AsyncData.AsyncData<A, string>, what: string, draw: (loaded: A) => Html): Html =>
  AsyncData.matchData(data, {
    onEmpty: () => h.empty,
    onFailure: (error) => h.div([h.Class("card")], [h.p([h.Class("k")], [`Could not load the ${what}: ${error}`])]),
    onData: draw,
  });

const dealsCard = (h: H, derived: Derived, width: number): Html => h.div([h.Class("card")], [dealsView(h, derived, width)]);

const momentumCard = (h: H, derived: Derived, width: number): Html => h.div([h.Class("card")], [momentumView(h, derived.pooled, width)]);

const sectionView = (h: H, section: Section, content: Html): Html => h.section([h.Id(section)], [content]);

const groupLabel = (group: Group): string => GROUPS.find((entry) => entry.group === group)?.label ?? group;

/** A group of sections under one heading: what the jump menu links to. */
const groupView = (h: H, group: Group, sections: ReadonlyArray<Html>): Html => h.section([h.Id(group), h.Class("part")], [h.h1([h.Class("ghead")], [groupLabel(group)]), ...sections]);

const pageView = (h: H, model: Model, derived: Derived): Html => {
  const content = contentWidth(model.viewport);
  const card = cardWidth(model.viewport);
  const afterFirstPaint = (draw: () => Html): Html => (model.isFirstPaintDone ? draw() : h.empty);

  return h.div(
    [],
    [
      lazyHero(heroView, [h, derived]),
      // The jump menu and the filters stay at the top; the filters apply to every section.
      h.div([h.Class("top")], [lazyNav(navView, [h, model.maybeGroup]), lazyFilters(filtersView, [h, derived, model.filter, model.isFiltersOpen])]),
      groupView(h, "results", [
        sectionView(
          h,
          "scatter",
          h.div(
            [],
            [
              lazyScatter(scatterCard, [h, derived, model.ranking, model.basis, model.scatter, card]),
            ],
          ),
        ),
      ]),
      groupView(h, "watch", [
        sectionView(h, "interesting", lazyInteresting(interestingView, [h, picksOf(derived), model.matches, content])),
        sectionView(h, "blunders", afterFirstPaint(() => optionalView(h, derived.blunders, "blunders", (blunders) => lazyBlunderCards(blunderCardsCard, [h, derived, blunders])))),
      ]),
      groupView(h, "decisions", [
        sectionView(h, "odds", afterFirstPaint(() => lazyOdds(oddsView, [h, derived.decisions, derived.seats, derived.keep, model.viewport.width, content]))),
        sectionView(
          h,
          "mistakes",
          afterFirstPaint(() =>
            h.div(
              [],
              [
                optionalView(h, derived.mistakes, "regret by shells left", (mistakes) => lazyMistakes(mistakesView, [h, mistakes, derived.seats, derived.keep, model.viewport.width, card])),
                optionalView(h, derived.blunders, "blunder rates", (blunders) => lazyBlunderRates(blunderRatesCard, [h, derived, blunders, model.viewport.width, card])),
              ],
            ),
          ),
        ),
        sectionView(
          h,
          "items",
          afterFirstPaint(() =>
            h.div(
              [],
              [
                lazyFates(fatesView, [h, derived.decisions, derived.seats, derived.filtered]),
                optionalView(h, derived.consistency, "consistency", (consistency) => lazyConsistency(consistencyView, [h, derived.pooled, consistency, card])),
              ],
            ),
          ),
        ),
        sectionView(h, "luck", afterFirstPaint(() => lazyLuck(luckView, [h, derived.matches, model.viewport.width, content]))),
      ]),
      groupView(h, "rounds", [
        sectionView(h, "seats", h.div([], [lazySeats(seatsView, [h, derived, model.viewport.width, content]), afterFirstPaint(() => lazyMomentum(momentumCard, [h, derived, card]))])),
        sectionView(
          h,
          "pressure",
          afterFirstPaint(() =>
            h.div(
              [],
              [
                lazyPressure(pressureView, [h, derived.decisions, derived.seats, derived.keep, model.viewport.width, content]),
                h.div([h.Id("rubbers"), h.Class("card")], [lazyRubbers(rubbersView, [h, rubberRows(derived.filtered), card])]),
              ],
            ),
          ),
        ),
      ]),
      groupView(h, "reliability", [
        afterFirstPaint(() => lazyReliability(reliabilityView, [h, derived.decisions, derived.seats, derived.keep, model.maybeRateTip, model.viewport.width, content])),
        afterFirstPaint(() => lazySpend(spendCard, [h, derived])),
      ]),
      groupView(h, "details", [
        sectionView(h, "leaderboards", lazyLeaderboard(leaderboardView, [h, derived.pooled, derived.everyPooled, derived.ranks, derived.ratings, derived.matchSeats, derived.items, model.leaderboard, model.ranking, model.basis])),
        sectionView(h, "matches", lazyMatches(matchesView, [h, derived.matches, model.matchList])),
        sectionView(h, "deals", afterFirstPaint(() => lazyDeals(dealsCard, [h, derived, card]))),
        sectionView(h, "breakdown", lazyBreakdown(breakdownView, [h, derived, model.heat, model.ranking])),
      ]),
    ],
  );
};

const isPinned = (model: Model): boolean => Option.isSome(model.scatter.maybePin) || Option.isSome(model.scatter.maybeHover) || Option.isSome(model.markTip.maybePin);

export const view = (model: Model, h: H): Document =>
  AsyncData.matchData(model.data, {
    onEmpty: () => ({ title: "Buckshot Arena", body: h.main([], [h.p([h.Class("k")], ["Loading the analysis database…"])]) }),
    onFailure: (error) => ({ title: "Buckshot Arena", body: h.main([], [h.p([h.Class("k")], [`Could not load the analysis database: ${error}`])]) }),
    onData: (loaded) => {
      const derived = derive(loaded, model.filter, model.basis);

      const replay = Option.match(model.maybeReplay, {
        onNone: () => h.empty,
        onSome: (open) => lazyReplay(replayView, [h, open, model.matches[open.id], derived.allMatches, model.viewport]),
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
