import { Option } from "effect";
import { AsyncData } from "foldkit";
import { createLazy, type Document, type Html, type HtmlBuilder } from "foldkit/html";

import { baseName, baseOrder, colorOf, EFFORTS, fmtCount, keyOf, sumOf, unique } from "./data.ts";
import { switchView } from "./charts.ts";
import { type Derived, derive, mainConfigsOf } from "./derived.ts";
import { breakdownView, heatRowsOf } from "./heat.ts";
import { interestingView, picksOf } from "./interesting.ts";
import { leaderboardView } from "./leaderboard.ts";
import { matchesView } from "./matches.ts";
import { Message, type Model, TABS, type Viewport } from "./model.ts";
import { reliabilityView } from "./reliability.ts";
import { replayView } from "./replay.ts";
import { scatterView } from "./scatter.ts";
import { seatsView } from "./seats.ts";

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
  const matchesIn = (cohort: string) => new Set(seats.filter((seat) => seat.cohort === cohort).map(({ matchId }) => matchId)).size;
  const main = mainConfigsOf(seats);
  const hidden = unique(seats.map(keyOf)).filter((key) => !main.has(key)).length;

  return h.div(
    [h.Class("filters")],
    [
      h.select(
        [h.Title("tournament · gameplay code hash · pairing kind"), h.Value(filter.cohort), h.OnChange((cohort) => Message.SelectedCohort({ cohort }))],
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

// OVERVIEW

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

const lazyHero = createLazy();

const lazyFilters = createLazy();

const lazyScatter = createLazy();

const lazyBreakdown = createLazy();

const lazyInteresting = createLazy();

const lazyLeaderboard = createLazy();

// A lazy slot reuses its last view only when the view function and every argument are the same references, so
// each slot is handed a module-level function, never an arrow made during the render.

const overviewView = (h: H, model: Model, derived: Derived): Html =>
  h.div(
    [],
    [
      lazyHero(heroView, [h, derived]),
      lazyFilters(filtersView, [h, derived, model.filter]),
      h.div([h.Class("card")], [lazyScatter(scatterView, [h, derived.pooled, derived.ratings, model.scatter, cardWidth(model.viewport)])]),
      lazyBreakdown(breakdownView, [h, derived, model.heat]),
      lazyInteresting(interestingView, [h, picksOf(derived), model.matches, contentWidth(model.viewport)]),
      lazyLeaderboard(leaderboardView, [h, derived.byCohort, derived.matchSeats, derived.items, model.leaderboard, model.filter.isAllConfigs]),
    ],
  );

const lazyMatches = createLazy();

const lazySeats = createLazy();

const lazyReliability = createLazy();

const lazyReplay = createLazy();

const matchesTab = (h: H, derived: Derived, filter: Model["filter"], list: Model["matchList"]): Html => matchesView(h, filtersView(h, derived, filter), derived.matches, list);

const seatsTab = (h: H, derived: Derived, filter: Model["filter"], viewport: Viewport): Html => seatsView(h, filtersView(h, derived, filter), derived, viewport.width, contentWidth(viewport));

const reliabilityTab = (h: H, derived: Derived, filter: Model["filter"], tip: Model["maybeRateTip"], viewport: Viewport): Html =>
  reliabilityView(h, filtersView(h, derived, filter), derived.decisions, derived.seats, derived.keep, tip, viewport.width, contentWidth(viewport));

// The filters apply to the whole tab, so each tab places them above the content they filter.
const tabView = (h: H, model: Model, derived: Derived): Html => {
  switch (model.tab) {
    case "overview":
      return overviewView(h, model, derived);
    case "matches":
      return lazyMatches(matchesTab, [h, derived, model.filter, model.matchList]);
    case "seats":
      return lazySeats(seatsTab, [h, derived, model.filter, model.viewport]);
    case "reliability":
      return lazyReliability(reliabilityTab, [h, derived, model.filter, model.maybeRateTip, model.viewport]);
  }
};

const navView = (h: H, model: Model): Html =>
  h.nav(
    [],
    [
      h.span([h.Class("brand")], ["Buckshot arena"]),
      ...TABS.map(([tab, label]) => h.button([h.Type("button"), h.Class(model.tab === tab ? "on" : ""), h.OnClick(Message.ClickedTab({ tab }))], [label])),
    ],
  );

const isPinned = (model: Model): boolean => Option.isSome(model.scatter.maybePin) || Option.isSome(model.scatter.maybeHover);

export const view = (model: Model, h: H): Document =>
  AsyncData.matchData(model.data, {
    onEmpty: () => ({ title: "Buckshot arena", body: h.main([], [h.p([h.Class("k")], ["Loading the analysis database…"])]) }),
    onFailure: (error) => ({ title: "Buckshot arena", body: h.main([], [h.p([h.Class("k")], [`Could not load the analysis database: ${error}`])]) }),
    onData: (loaded) => {
      const derived = derive(loaded, model.filter);

      const replay = Option.match(model.maybeReplay, {
        onNone: () => h.empty,
        onSome: (open) => lazyReplay(replayView, [h, open, model.matches[open.id], derived.allMatches, model.viewport]),
      });

      return {
        title: "Buckshot arena",
        body: h.div(
          [],
          [
            // Touch has no hover: a tap pins a point, and a tap anywhere outside the chart unpins it.
            h.main(isPinned(model) ? [h.OnClick(Message.ClickedOutsideChart())] : [], [navView(h, model), tabView(h, model, derived)]),
            replay,
          ],
        ),
      };
    },
  });
