import { Option } from "effect";
import type { Html, HtmlBuilder } from "foldkit/html";

import { pressable } from "./charts.ts";
import { baseName, costPerMove, fmtCount, fmtPct, fmtPoints, fmtSec, fmtUsd, isClaude, isProvisional, type ModelStats, sumOf } from "./data.ts";
import type { Derived, ItemSummary } from "./derived.ts";
import { drillView } from "./drill.ts";
import { itemIconOf } from "./items.ts";
import { Message, type Model } from "./model.ts";
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

const detailsOf = (h: H, m: ModelStats, item: ItemSummary | undefined, hasRegret: boolean): ReadonlyArray<Detail> => {
  const moves = sumOf(m.scored.map((seat) => seat.moves ?? 0));
  const favorite = item?.favorite ?? null;

  return [
    { label: "wins vs own opponents", title: "", content: [h.b([], [fmtPct(m.winShare)]), " ", h.span([h.Class("pm")], [`${m.win.k.toFixed(m.win.k % 1 ? 1 : 0)}/${m.win.n}`])] },
    { label: "round wins", title: "", content: [fmtPct(m.roundShare)] },
    { label: "cash share", title: "", content: [fmtPct(m.potShare)] },
    ...(hasRegret ? [{ label: "regret", title: m.regret === null ? "" : `${m.regret.moves.toLocaleString()} moves · ${fmtPct(m.regret.exactShare)} proven exact`, content: [m.regret === null ? "–" : fmtPoints(m.regret.mean)] }] : []),
    { label: "per move", title: "", content: [fmtUsd(costPerMove(m))] },
    { label: "time", title: "", content: [fmtSec(moves > 0 ? sumOf(m.scored.map((seat) => seat.lat ?? 0)) / moves : null)] },
    { label: "out tok", title: "", content: [fmtCount(m.avgOut)] },
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

const rowView = (h: H, m: ModelStats, rank: number | undefined, elo: Rating | undefined, scale: EloScale, details: ReadonlyArray<Detail>, isOpen: boolean): Html => {
  return h.keyed("tr")(
    m.id,
    [h.Class(`row ${isOpen ? "sel" : ""} ${isProvisional(m) ? "provisional" : ""}`), h.AriaExpanded(isOpen), ...pressable(h, Message.ClickedLeaderboardRow({ id: m.id }))],
    [
      h.td([], [h.span([h.Class("rk")], [rank === undefined ? "" : String(rank)]), h.span([h.Class(`dot ${isClaude(m.model) ? "a" : "o"}`), h.Style({ background: m.color })], []), `${baseName(m.model)} `, h.span([h.Class("eff")], [`[${m.effort}]`])]),
      h.td([h.DataAttribute("label", "round elo")], ratingView(h, elo)),
      h.td([h.DataAttribute("label", "matches"), h.Title(`${m.win.blocks} seed blocks`)], [m.scored.length.toLocaleString()]),
      h.td([h.DataAttribute("label", "cost")], [fmtUsd(m.avgCost)]),
      h.td([h.Class("barcol")], [eloBarView(h, scale, m, elo)]),
      ...details.map(({ label, title, content }) => h.td([h.Class("detail"), h.DataAttribute("label", label), ...(title === "" ? [] : [h.Title(title)])], [...content])),
    ],
  );
};

const detailsView = (h: H, details: ReadonlyArray<Detail>): Html =>
  h.dl([h.Class("drillstats")], details.flatMap(({ label, title, content }) => [h.dt([], [label]), h.dd(title === "" ? [] : [h.Title(title)], [...content])]));

export const configPanelView = (h: H, derived: Derived, key: string): Html => {
  const m = derived.pooled.find((candidate) => candidate.key === key);

  if (m === undefined) return h.empty;

  const details = detailsOf(
    h,
    m,
    derived.items.get(m.id),
    derived.everyPooled.some(({ regret }) => regret !== null),
  );

  return h.div(
    [h.Class("configpanel")],
    [
      h.div(
        [h.Class("lbbar")],
        [
          h.h2([], [h.span([h.Class(`dot ${isClaude(m.model) ? "a" : "o"}`), h.Style({ background: m.color })], []), `${baseName(m.model)} `, h.span([h.Class("eff")], [`[${m.effort}]`])]),
          h.span([h.Class("k")], ratingView(h, derived.ratings.get(m.key))),
          h.button([h.Type("button"), h.Class("drillclose"), h.AriaLabel("Close"), h.OnClick(Message.ClosedDrill())], ["✕"]),
        ],
      ),
      detailsView(h, details),
      drillView(h, m, derived),
    ],
  );
};

const headersOf = (hasRegret: boolean): ReadonlyArray<string> => [
  "Model",
  "Round Elo",
  "Matches",
  "Avg cost",
  "",
  "Match wins vs own opponents",
  "Round wins",
  "Cash share",
  ...(hasRegret ? ["Regret"] : []),
  "Per move",
  "Time / move",
  "Out tok",
  "Favorite item",
];

const BAR_COLUMN = 4;

const HEADER_TITLES = new Map([
  ["Round Elo", "one Bradley-Terry rating over every match, on round win share; the interval is a 95% bootstrap over seed blocks"],
  ["Cash share", "a config's cash over the match's cash, averaged over scored matches"],
  ["Round wins", "the rounds a config won over the rounds it played"],
  ["Regret", "mean points of round win chance a move gave up against the minimax player's best move; lower is better"],
]);

const headerView = (h: H, label: string, index: number): Html => {
  const title = HEADER_TITLES.get(label);

  return h.th(index === BAR_COLUMN ? [h.Class("barcol")] : [...(label === "Round Elo" ? [h.Class("rating")] : []), ...(title === undefined ? [] : [h.Title(title)])], [label]);
};

/** Configs with a scored match, by rank; the unranked (provisional or unrated) after them, by rating and then label. */
export const inRankOrder = (stats: ReadonlyArray<ModelStats>, ranks: ReadonlyMap<string, number>, ratings: ReadonlyMap<string, Rating>): ReadonlyArray<ModelStats> => {
  const eloOf = ({ key }: ModelStats) => ratings.get(key)?.rating ?? Number.NEGATIVE_INFINITY;

  return stats
    .filter(({ scored }) => scored.length > 0)
    .toSorted((left, right) => (ranks.get(left.key) ?? Number.POSITIVE_INFINITY) - (ranks.get(right.key) ?? Number.POSITIVE_INFINITY) || eloOf(right) - eloOf(left) || left.label.localeCompare(right.label));
};

export const leaderboardView = (h: H, derived: Derived, leaderboard: Model["leaderboard"]): Html => {
  const { pooled: stats, everyPooled: every, ranks, ratings, items } = derived;
  const hasRegret = every.some(({ regret }) => regret !== null);
  const headers = headersOf(hasRegret);
  const configs = inRankOrder(stats, ranks, ratings);
  const scale = eloScaleOf(ratings, ranks);

  return h.div(
    [h.Class("lb")],
    [
      h.div([h.Class("lbbar")], [h.h2([], ["Leaderboard"])]),
      h.p([h.Class("sub")], ["Round Elo is one Bradley-Terry rating over every match, on round win share; the bar runs from the average at 0, with its 95% interval over seed blocks. Match wins count a config's own opponents only."]),
      h.div(
        [h.Class("card")],
        [
          h.table(
            [h.Class("lbt rows")],
            [
              h.thead([], [h.tr([], headers.map((label, index) => headerView(h, label, index)))]),
              h.tbody(
                [],
                configs.flatMap((m) => {
                  const isOpen = Option.exists(leaderboard.maybeOpen, (open) => open === m.id);

                  const details = detailsOf(h, m, items.get(m.id), hasRegret);

                  return [
                    rowView(h, m, ranks.get(m.key), ratings.get(m.key), scale, details, isOpen),
                    isOpen ? h.keyed("tr")(`drill-${m.id}`, [h.Class("drill")], [h.td([h.Colspan(headers.length)], [detailsView(h, details), drillView(h, m, derived)])]) : h.empty,
                  ];
                }),
              ),
              h.tfoot(
                [],
                [
                  h.tr(
                    [],
                    [
                      h.td([h.Colspan(BAR_COLUMN)], []),
                      h.td([h.Class("barcol")], [h.div([h.Class("axis")], scale.ticks.map((tick) => h.span([h.Style({ left: `${percentOf(scale, tick)}%` })], [String(tick)])))]),
                      h.td([h.Colspan(headers.length - BAR_COLUMN - 1)], []),
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
