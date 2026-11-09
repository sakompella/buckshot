import { Option } from "effect";
import type { Html, HtmlBuilder } from "foldkit/html";

import { pressable } from "./charts.ts";
import { baseName, costPerMove, effortLabel, fmtCount, fmtPct, fmtPoints, fmtSec, fmtUsd, isClaude, isProvisional } from "./data.ts";
import type { Derived, ModelStats } from "./derived.ts";
import { drillView } from "./drill.ts";
import { itemIconOf } from "./items.ts";
import { type Lazy, Message, type Model } from "./model.ts";
import type { Rating } from "./ratings.ts";

type H = HtmlBuilder<Message>;

// One table, ranked by the pooled Bradley-Terry rating on round wins (Round Elo).

const ratingView = (h: H, elo: Rating | undefined): ReadonlyArray<Html | string> =>
  elo === undefined ? ["–"] : [`${elo.rating >= 0 ? "+" : ""}${elo.rating.toFixed(0)} `, ...(elo.interval === null ? [] : [h.span([h.Class("pm")], [`[${elo.interval.lo.toFixed(0)}, ${elo.interval.hi.toFixed(0)}]`])])];

interface Detail {
  readonly label: string;
  readonly title: string;
  readonly content: ReadonlyArray<Html | string>;
}

/** How many moves a config's accuracy figures rest on. */
export const movesTitle = ({ regret }: ModelStats): string => (regret === null ? "" : `${regret.moves.toLocaleString()} moves with a real choice`);

const detailsOf = (h: H, m: ModelStats, hasRegret: boolean): ReadonlyArray<Detail> => {
  const { favorite } = m;

  return [
    { label: "wins vs own opponents", title: "", content: [h.b([], [fmtPct(m.winShare)]), " ", h.span([h.Class("pm")], [`${m.win.k.toFixed(m.win.k % 1 ? 1 : 0)}/${m.win.n}`])] },
    { label: "round wins", title: "", content: [fmtPct(m.roundShare)] },
    { label: "cash share", title: "", content: [fmtPct(m.potShare)] },
    ...(hasRegret
      ? [
          { label: "accuracy", title: movesTitle(m), content: [m.regret === null ? "–" : m.regret.accuracy.toFixed(1)] },
          { label: "p99 points lost", title: movesTitle(m), content: [m.regret === null ? "–" : fmtPoints(m.regret.p99Lost)] },
        ]
      : []),
    { label: "cost / move", title: "", content: [fmtUsd(costPerMove(m))] },
    { label: "time / move", title: "", content: [fmtSec(m.scoredMoves > 0 ? m.scoredLatency / m.scoredMoves : null)] },
    { label: "output tok / match", title: "", content: [fmtCount(m.avgOut)] },
    { label: "fav", title: favorite === null ? "" : `${favorite.k} of ${favorite.n} legal moves`, content: favorite === null ? ["–"] : [itemIconOf(h, favorite.item), `${favorite.item} `, h.span([h.Class("pm")], [fmtPct(favorite.rate)])] },
  ];
};

interface EloScale {
  readonly from: number;
  readonly to: number;
  readonly ticks: ReadonlyArray<number>;
}

const eloScaleOf = (ratings: ReadonlyMap<string, Rating>, ranks: ReadonlyMap<string, number>): EloScale => {
  const ends = [...ratings].filter(([key]) => ranks.has(key)).flatMap(([, { rating, interval }]) => [rating, interval?.lo ?? rating, interval?.hi ?? rating]);
  const from = Math.floor(Math.min(0, ...ends) / 100) * 100;
  const to = Math.ceil(Math.max(0, ...ends) / 100) * 100;

  return { from, to, ticks: Array.from({ length: (to - from) / 100 + 1 }, (_, index) => from + index * 100) };
};

const percentOf = ({ from, to }: EloScale, elo: number): number => Math.min(100, Math.max(0, ((elo - from) / (to - from)) * 100));

const eloBarView = (h: H, scale: EloScale, m: ModelStats, elo: Rating | undefined): Html => {
  if (elo === undefined) return h.empty;

  const [low, high] = [percentOf(scale, Math.min(0, elo.rating)), percentOf(scale, Math.max(0, elo.rating))];
  const whisker = elo.interval === null ? null : { left: percentOf(scale, elo.interval.lo), right: percentOf(scale, elo.interval.hi), clippedLow: elo.interval.lo < scale.from, clippedHigh: elo.interval.hi > scale.to };

  return h.div(
    [h.Class("track")],
    [
      h.div([h.Class("zero"), h.Style({ left: `${percentOf(scale, 0)}%` })], []),
      h.div([h.Class("fill"), h.Style({ left: `${low}%`, width: `${high - low}%`, background: m.color })], []),
      ...(whisker === null ? [] : [h.div([h.Class(`whisk${whisker.clippedLow ? " clip-lo" : ""}${whisker.clippedHigh ? " clip-hi" : ""}`), h.Style({ left: `${whisker.left}%`, width: `${whisker.right - whisker.left}%` })], [])]),
    ],
  );
};

/** A config's dot, model name and effort. */
const nameView = (h: H, m: ModelStats): ReadonlyArray<Html | string> => {
  const effort = effortLabel(m.model, m.effort);

  return [
    h.span([h.Class(`dot ${isClaude(m.model) ? "a" : "o"}`), h.Style({ background: m.color })], []),
    `${baseName(m.model)} `,
    ...(effort === "" ? [] : [h.span([h.Class("eff")], [`[${effort}]`])]),
  ];
};

const rowView = (h: H, m: ModelStats, rank: number | undefined, elo: Rating | undefined, hasLuck: boolean, scale: EloScale, details: ReadonlyArray<Detail>, isOpen: boolean): Html =>
  h.keyed("tr")(
    m.key,
    [h.Class(`row ${isOpen ? "sel" : ""} ${isProvisional(m) ? "provisional" : ""}`), h.AriaExpanded(isOpen), ...pressable(h, Message.ClickedLeaderboardRow({ id: m.key }))],
    [
      h.td([], [h.span([h.Class("rk")], [rank === undefined ? "" : String(rank)]), ...nameView(h, m)]),
      h.td([h.DataAttribute("label", "round elo")], ratingView(h, elo)),
      ...(hasLuck ? [h.td([h.DataAttribute("label", "luck-adjusted")], ratingView(h, m.luckRating ?? undefined))] : []),
      h.td([h.DataAttribute("label", "matches"), h.Title(`${m.win.blocks} seed blocks`)], [m.scored.toLocaleString()]),
      h.td([h.DataAttribute("label", "cost / match")], [fmtUsd(m.avgCost)]),
      h.td([h.Class("barcol")], [eloBarView(h, scale, m, elo)]),
      ...details.map(({ label, title, content }) => h.td([h.Class("detail"), h.DataAttribute("label", label), ...(title === "" ? [] : [h.Title(title)])], [...content])),
    ],
  );

const detailsView = (h: H, details: ReadonlyArray<Detail>): Html =>
  h.dl([h.Class("drillstats")], details.flatMap(({ label, title, content }) => [h.dt([], [label]), h.dd(title === "" ? [] : [h.Title(title)], [...content])]));

export const configPanelView = (h: H, derived: Derived, key: string, lazy: Lazy): Html => {
  const m = derived.pooled.find((candidate) => candidate.key === key);

  if (m === undefined) return h.empty;

  const details = detailsOf(h, m, derived.everyPooled.some(({ regret }) => regret !== null));

  return h.div(
    [h.Class("configpanel")],
    [
      h.div(
        [h.Class("lbbar")],
        [
          h.h2([], nameView(h, m)),
          h.span([h.Class("k")], ratingView(h, derived.ratings.get(m.key))),
          h.button([h.Type("button"), h.Class("drillclose"), h.AriaLabel("Close"), h.OnClick(Message.ClosedDrill())], ["✕"]),
        ],
      ),
      detailsView(h, details),
      drillView(h, m, lazy),
    ],
  );
};

const headersOf = (hasRegret: boolean, hasLuck: boolean): ReadonlyArray<string> => [
  "Model",
  "Round Elo",
  ...(hasLuck ? [LUCK] : []),
  "Matches",
  "Cost / match",
  "",
  "Match wins vs own opponents",
  "Round wins",
  "Cash share",
  ...(hasRegret ? ["Accuracy", "p99 points lost"] : []),
  "Cost / move",
  "Time / move",
  "Output tok / match",
  "Favorite item",
];

const LUCK = "Luck-adjusted Elo";

export const ACCURACY_TITLE = "Lichess's accuracy over points of round win chance: each move scored by what it gave up against the minimax player's best move, a game's value combining a volatility-weighted and a harmonic mean, averaged over the config's matches; higher is better, 100 is perfect";

export const P99_TITLE = "Points of round win chance lost by the 99th-percentile move: one move in a hundred gave up at least this much";

const HEADER_TITLES = new Map([
  ["Round Elo", "one Bradley-Terry rating over every match, on round win share; the interval is a 95% bootstrap over seed blocks"],
  [LUCK, "Round Elo with each round's result corrected for the luck of its shots, loads and first seat (AIVAT): the same strengths with less noise"],
  ["Cash share", "a config's cash over the match's cash, averaged over scored matches"],
  ["Round wins", "the rounds a config won over the rounds it played"],
  ["Accuracy", ACCURACY_TITLE],
  ["p99 points lost", P99_TITLE],
]);

const headerView = (h: H, label: string): Html => {
  const title = HEADER_TITLES.get(label);

  return h.th(label === "" ? [h.Class("barcol")] : [...(label === "Round Elo" || label === LUCK ? [h.Class("rating")] : []), ...(title === undefined ? [] : [h.Title(title)])], [label]);
};

/** Configs with a scored match, by rank; the unranked (provisional or unrated) after them, by rating and then label. */
export const inRankOrder = (stats: ReadonlyArray<ModelStats>, ranks: ReadonlyMap<string, number>, ratings: ReadonlyMap<string, Rating>): ReadonlyArray<ModelStats> => {
  const eloOf = ({ key }: ModelStats) => ratings.get(key)?.rating ?? Number.NEGATIVE_INFINITY;

  return stats
    .filter(({ scored }) => scored > 0)
    .toSorted((left, right) => (ranks.get(left.key) ?? Number.POSITIVE_INFINITY) - (ranks.get(right.key) ?? Number.POSITIVE_INFINITY) || eloOf(right) - eloOf(left) || left.label.localeCompare(right.label));
};

export const leaderboardView = (h: H, derived: Derived, leaderboard: Model["leaderboard"], lazy: Lazy): Html => {
  const { pooled: stats, everyPooled: every, ranks, ratings } = derived;
  const hasRegret = every.some(({ regret }) => regret !== null);
  const hasLuck = every.some(({ luckRating }) => luckRating !== null);
  const headers = headersOf(hasRegret, hasLuck);
  const barColumn = headers.indexOf("");
  const configs = inRankOrder(stats, ranks, ratings);
  const scale = eloScaleOf(ratings, ranks);

  return h.div(
    [h.Class("lb")],
    [
      h.div([h.Class("lbbar")], [h.h2([], ["Leaderboard"])]),
      h.p([h.Class("sub")], [`Round Elo is one Bradley-Terry rating over every match, on round win share; the bar runs from the average at 0, with its 95% interval over seed blocks.${hasLuck ? " Luck-adjusted Elo is the same fit with the luck of each round's shots, loads and first seat taken out." : ""} Match wins count a config's own opponents only.`]),
      h.div(
        [h.Class("card")],
        [
          h.table(
            [h.Class("lbt rows")],
            [
              h.thead([], [h.tr([], headers.map((label) => headerView(h, label)))]),
              h.tbody(
                [],
                configs.flatMap((m) => {
                  const isOpen = Option.exists(leaderboard.maybeOpen, (open) => open === m.key);
                  const details = detailsOf(h, m, hasRegret);

                  return [
                    rowView(h, m, ranks.get(m.key), ratings.get(m.key), hasLuck, scale, details, isOpen),
                    isOpen ? h.keyed("tr")(`drill-${m.key}`, [h.Class("drill")], [h.td([h.Colspan(headers.length)], [detailsView(h, details), drillView(h, m, lazy)])]) : h.empty,
                  ];
                }),
              ),
              h.tfoot(
                [],
                [
                  h.tr(
                    [],
                    [
                      h.td([h.Colspan(barColumn)], []),
                      h.td([h.Class("barcol")], [h.div([h.Class("axis")], scale.ticks.map((tick) => h.span([h.Style({ left: `${percentOf(scale, tick)}%` })], [String(tick)])))]),
                      h.td([h.Colspan(headers.length - barColumn - 1)], []),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    ],
  );
};

const ACCURACY_HEADERS: ReadonlyArray<readonly [string, string]> = [
  ["Model", ""],
  ["Accuracy", ACCURACY_TITLE],
  ["Avg points lost", "Mean points of round win chance a move gave up against the minimax player's best move"],
  ["p99 points lost", P99_TITLE],
  ["Best moves", "Moves as good as the minimax player's best"],
  ["Inaccuracies / 100", "Moves per 100 that gave up 5 to 10 points of round win chance (lichess's inaccuracy, 0.1 of its winning chances)"],
  ["Mistakes / 100", "Moves per 100 that gave up 10 to 15 points (lichess's mistake, 0.2)"],
  ["Blunders / 100", "Moves per 100 that gave up 15 points or more (lichess's blunder, 0.3)"],
  ["Moves", "Moves with a real choice, over the config's scored matches; decisions where every move is within a point are left out"],
];

/** Configs with a scored move, best accuracy first. */
export const inAccuracyOrder = (stats: ReadonlyArray<ModelStats>): ReadonlyArray<ModelStats> =>
  stats.filter(({ regret }) => regret !== null).toSorted((left, right) => (right.regret?.accuracy ?? 0) - (left.regret?.accuracy ?? 0) || left.label.localeCompare(right.label));

const accuracyRowView = (h: H, m: ModelStats, rank: number): Html => {
  const { regret } = m;
  const cell = (label: string, text: string | undefined) => h.td([h.DataAttribute("label", label), ...(label === "accuracy" ? [h.Title(movesTitle(m))] : [])], [text ?? "–"]);

  return h.keyed("tr")(
    m.key,
    [h.Class(`row ${isProvisional(m) ? "provisional" : ""}`)],
    [
      h.td([], [h.span([h.Class("rk")], [String(rank)]), ...nameView(h, m)]),
      cell("accuracy", regret?.accuracy.toFixed(1)),
      cell("avg points lost", regret === null ? undefined : fmtPoints(regret.meanLost)),
      cell("p99 points lost", regret === null ? undefined : fmtPoints(regret.p99Lost)),
      cell("best moves", regret === null ? undefined : fmtPct(regret.bestShare)),
      cell("inaccuracies / 100", regret?.inaccuraciesPer100.toFixed(1)),
      cell("mistakes / 100", regret?.mistakesPer100.toFixed(1)),
      cell("blunders / 100", regret?.blundersPer100.toFixed(1)),
      cell("moves", regret?.moves.toLocaleString()),
    ],
  );
};

/** One table of how well each config's moves held the round win chance, best accuracy first. */
export const accuracyTableView = (h: H, derived: Derived): Html => {
  const configs = inAccuracyOrder(derived.pooled);

  return h.div(
    [h.Id("accuracy-table")],
    [
      h.h2([], ["Accuracy by config"]),
      h.p([h.Class("sub")], ["Each move is scored by the round win chance it gave up against the minimax player's best move, with lichess's accuracy formula and its inaccuracy, mistake and blunder cut-offs. Decisions where every move is within a point are left out."]),
      configs.length === 0
        ? h.div([h.Class("empty")], ["No config in this filter has a scored move."])
        : h.div(
            [h.Class("card")],
            [
              h.table(
                [h.Class("lbt rows")],
                [
                  h.thead([], [h.tr([], ACCURACY_HEADERS.map(([label, title]) => h.th(title === "" ? [] : [h.Title(title)], [label])))]),
                  h.tbody([], configs.map((m, index) => accuracyRowView(h, m, index + 1))),
                ],
              ),
            ],
          ),
    ],
  );
};
