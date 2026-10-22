import { Option } from "effect";
import { AsyncData } from "foldkit";
import { createLazy, type Document, type Html, type HtmlBuilder } from "foldkit/html";

import { baseName, baseOrder, colorOf, EFFORTS, fmtCount, sumOf, unique } from "./data.ts";
import { type Derived, derive } from "./derived.ts";
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

const overviewView = (h: H, model: Model, derived: Derived): Html =>
  h.div(
    [],
    [
      lazyHero((d: Derived) => heroView(h, d), [derived]),
      lazyFilters((d: Derived, filter: Model["filter"]) => filtersView(h, d, filter), [derived, model.filter]),
      h.div([h.Class("card")], [lazyScatter((d: Derived, scatter: Model["scatter"], width: number) => scatterView(h, d.pooled, d.ratings, scatter, width), [derived, model.scatter, cardWidth(model.viewport)])]),
      lazyBreakdown((d: Derived, heat: Model["heat"]) => breakdownView(h, d, heat), [derived, model.heat]),
      lazyInteresting((d: Derived, matches: Model["matches"], width: number) => interestingView(h, picksOf(d), matches, width), [derived, model.matches, contentWidth(model.viewport)]),
      lazyLeaderboard((d: Derived, leaderboard: Model["leaderboard"]) => leaderboardView(h, d.byCohort, d.matchSeats, d.items, leaderboard), [derived, model.leaderboard]),
    ],
  );

const lazyMatches = createLazy();

const lazySeats = createLazy();

const lazyReliability = createLazy();

const lazyReplay = createLazy();

// The filters apply to the whole tab, so each tab places them above the content they filter.
const tabView = (h: H, model: Model, derived: Derived): Html => {
  switch (model.tab) {
    case "overview":
      return overviewView(h, model, derived);
    case "matches":
      return lazyMatches((d: Derived, filter: Model["filter"], list: Model["matchList"]) => matchesView(h, filtersView(h, d, filter), d.matches, list), [derived, model.filter, model.matchList]);
    case "seats":
      return lazySeats((d: Derived, filter: Model["filter"], viewport: Viewport) => seatsView(h, filtersView(h, d, filter), d, viewport.width, contentWidth(viewport)), [
        derived,
        model.filter,
        model.viewport,
      ]);
    case "reliability":
      return lazyReliability(
        (d: Derived, filter: Model["filter"], tip: Model["maybeRateTip"], viewport: Viewport) =>
          reliabilityView(h, filtersView(h, d, filter), d.decisions, d.seats, d.keep, tip, viewport.width, contentWidth(viewport)),
        [derived, model.filter, model.maybeRateTip, model.viewport],
      );
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
        onSome: (open) =>
          lazyReplay(
            (shown: typeof open, data: Model["matches"][string] | undefined, viewport: Viewport) => replayView(h, shown, data, derived.allMatches, viewport),
            [open, model.matches[open.id], model.viewport],
          ),
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
