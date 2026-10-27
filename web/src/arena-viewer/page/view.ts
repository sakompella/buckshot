import { Option } from "effect";
import { AsyncData } from "foldkit";
import { createLazy, type Document, type Html, type HtmlBuilder } from "foldkit/html";

import { baseName, baseOrder, colorOf, EFFORTS, fmtCount, keyOf, sumOf, unique } from "./data.ts";
import { switchView } from "./charts.ts";
import { type Derived, derive, mainConfigsOf, ratingsOf } from "./derived.ts";
import { dealsView } from "./deals.ts";
import { effortView } from "./effort.ts";
import { blundersView, everyRateFor, galleryFor, ratesFor } from "./blunders.ts";
import { fatesView } from "./fates.ts";
import { breakdownView, heatRowsOf } from "./heat.ts";
import { interestingView, picksOf } from "./interesting.ts";
import { luckView } from "./luck.ts";
import { leaderboardView } from "./leaderboard.ts";
import { oddsView } from "./odds.ts";
import { mistakesView } from "./mistakes.ts";
import { matchesView } from "./matches.ts";
import { type Basis, Message, type Model, type Ranking, type Section, SECTIONS, type Viewport } from "./model.ts";
import { pressureView } from "./pressure.ts";
import { reliabilityView } from "./reliability.ts";
import { replayView } from "./replay.ts";
import { rubberRows, rubbersView } from "./rubbers.ts";
import { scatterView } from "./scatter.ts";
import { seatsView } from "./seats.ts";
import { type UpsetBin, upsetOf, upsetView } from "./upset.ts";
import { spendView } from "./spend.ts";

type H = HtmlBuilder<Message>;

// LAYOUT

/** The width inside main's padding, as styles.css lays it out. */
export const contentWidth = ({ width }: Viewport): number => {
  const padding = width < 640 ? 12 : width <= 1024 ? 20 : 36;

  return Math.min(width, 1500) - 2 * padding;
};

/** The width inside a .card: its padding and border. */
const cardWidth = (viewport: Viewport): number => Math.max(0, contentWidth(viewport) - 2 * (viewport.width < 640 ? 10 : 20) - 2);

// FILTERS

const filtersView = (h: H, derived: Derived, filter: Model["filter"]): Html => {
  const { seats } = derived;
  const cohorts = unique(seats.map(({ cohort }) => cohort)).toSorted();
  const models = unique(seats.map(({ model }) => model)).toSorted((left, right) => baseOrder(left) - baseOrder(right));
  const names = unique(models.map((model) => baseName(model)));
  const matchesIn = (cohort: string) => new Set(seats.filter((seat) => seat.cohort === cohort && seat.status === "completed").map(({ matchId }) => matchId)).size;
  const main = mainConfigsOf(seats);
  const hidden = unique(seats.map(keyOf)).filter((key) => !main.has(key)).length;

  return h.div(
    [h.Class("filters")],
    [
      h.select(
        [h.Title("the kind of comparison"), h.Value(filter.cohort), h.OnChange((cohort) => Message.SelectedCohort({ cohort }))],
        [h.option([h.Value("all")], ["All cohorts"]), ...cohorts.map((cohort) => h.option([h.Value(cohort), h.Selected(cohort === filter.cohort)], [`${cohort} (${matchesIn(cohort)})`]))],
      ),
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
        EFFORTS.filter((effort) => seats.some((seat) => seat.effort === effort)).map((effort) =>
          h.button([h.Type("button"), h.Class(`chip ${filter.offEfforts.includes(effort) ? "" : "on"}`), h.OnClick(Message.ToggledEffort({ effort }))], [effort]),
        ),
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
          ...stat("spent", `$${Math.round(sumOf(derived.pooled.map(({ totalCost }) => totalCost))).toLocaleString()}`),
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

const lazyEffort = createLazy();

const lazyUpset = createLazy();

const lazySpend = createLazy();

const lazyBreakdown = createLazy();

const lazyBlunders = createLazy();

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

const navView = (h: H): Html =>
  h.nav(
    [],
    [
      h.span([h.Class("brand")], ["Buckshot Arena"]),
      ...SECTIONS.map(([section, label]) => h.a([h.Href(`#${section}`), h.OnClick(Message.ClickedJump({ section }), { defaultAction: "Prevent" })], [label])),
      h.a([h.Class("download"), h.Href("/api/db")], ["Database (SQLite)"]),
    ],
  );

const scatterCard = (h: H, derived: Derived, ranking: Ranking, basis: Basis, scatter: Model["scatter"], width: number): Html =>
  h.div([h.Class("card")], [scatterView(h, derived.pooled, derived.everyPooled, derived.ratings, derived.ranks, ranking, basis, scatter, width)]);

const effortCard = (h: H, derived: Derived, basis: Basis, width: number): Html => h.div([h.Class("card")], [effortView(h, derived.pooled, derived.ratings, basis, width)]);

const upsetCard = (h: H, bins: ReadonlyArray<UpsetBin>, width: number): Html => h.div([h.Class("card")], [upsetView(h, bins, width)]);

const spendCard = (h: H, derived: Derived): Html => h.div([h.Class("card")], [spendView(h, derived.pooled)]);

const blundersCard = (h: H, derived: Derived, width: number, content: number): Html =>
  blundersView(h, ratesFor(derived.seats, derived.keep, derived.blunders), everyRateFor(derived.seats, derived.blunders), galleryFor(derived.seats, derived.keep, ratingsOf(derived.seats)("wins"), derived.blunders), width, content);

const oddsCard = (h: H, derived: Derived, width: number): Html => h.div([h.Class("card")], [oddsView(h, derived.decisions, derived.seats, derived.keep, derived.pooled, width)]);

const dealsCard = (h: H, derived: Derived, width: number): Html => h.div([h.Class("card")], [dealsView(h, derived, width)]);

const sectionView = (h: H, section: Section, content: Html): Html => h.section([h.Id(section), h.Class("part")], [content]);

const pageView = (h: H, model: Model, derived: Derived): Html => {
  const content = contentWidth(model.viewport);

  return h.div(
    [],
    [
      lazyHero(heroView, [h, derived]),
      // The jump menu and the filters stay at the top; the filters apply to every section.
      h.div([h.Class("top")], [lazyNav(navView, [h]), lazyFilters(filtersView, [h, derived, model.filter])]),
      sectionView(h, "scatter", h.div([], [lazyScatter(scatterCard, [h, derived, model.ranking, model.basis, model.scatter, cardWidth(model.viewport)]), lazyEffort(effortCard, [h, derived, model.basis, cardWidth(model.viewport)]), lazyUpset(upsetCard, [h, upsetOf(derived), cardWidth(model.viewport)]), lazySpend(spendCard, [h, derived])])),
      sectionView(h, "interesting", lazyInteresting(interestingView, [h, picksOf(derived), model.matches, content])),
      sectionView(h, "luck", lazyLuck(luckView, [h, derived.matches, derived.pooled, model.viewport.width, content, cardWidth(model.viewport)])),
      sectionView(h, "blunders", lazyBlunders(blundersCard, [h, derived, model.viewport.width, content])),
      sectionView(h, "mistakes", lazyMistakes(mistakesView, [h, derived.mistakes, derived.seats, derived.keep, model.viewport.width, cardWidth(model.viewport)])),
      sectionView(h, "seats", lazySeats(seatsView, [h, derived, model.viewport.width, content])),
      sectionView(h, "odds", lazyOdds(oddsCard, [h, derived, cardWidth(model.viewport)])),
      sectionView(h, "pressure", lazyPressure(pressureView, [h, derived.decisions, derived.seats, derived.keep, model.viewport.width, content])),
      sectionView(h, "rubbers", h.div([h.Class("card")], [lazyRubbers(rubbersView, [h, rubberRows(derived.filtered), cardWidth(model.viewport)])])),
      sectionView(h, "items", lazyFates(fatesView, [h, derived.seats, derived.filtered])),
      sectionView(h, "deals", lazyDeals(dealsCard, [h, derived, cardWidth(model.viewport)])),
      sectionView(h, "reliability", lazyReliability(reliabilityView, [h, derived.decisions, derived.seats, derived.keep, model.maybeRateTip, model.viewport.width, content])),
      sectionView(h, "matches", lazyMatches(matchesView, [h, derived.matches, model.matchList])),
      sectionView(h, "leaderboards", lazyLeaderboard(leaderboardView, [h, derived.byCohort, derived.everyByCohort, derived.ratings, derived.matchSeats, derived.items, model.leaderboard, model.filter.isAllConfigs, model.ranking, model.basis])),
      sectionView(h, "breakdown", lazyBreakdown(breakdownView, [h, derived, model.heat, model.ranking])),
    ],
  );
};

const isPinned = (model: Model): boolean => Option.isSome(model.scatter.maybePin) || Option.isSome(model.scatter.maybeHover);

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
          ],
        ),
      };
    },
  });
