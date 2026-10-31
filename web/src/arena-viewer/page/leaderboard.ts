import { Option } from "effect";
import type { Html, HtmlBuilder } from "foldkit/html";

import { pressable } from "./charts.ts";
import { baseName, fmtCount, fmtPct, fmtPoints, fmtSec, fmtUsd, isClaude, type ModelStats, sumOf } from "./data.ts";
import type { Derived, ItemSummary } from "./derived.ts";
import { drillView } from "./drill.ts";
import { itemIconOf } from "./items.ts";
import { Message, type Model } from "./model.ts";
import type { Rating } from "./ratings.ts";

type H = HtmlBuilder<Message>;

// One table, ranked by the pooled Bradley-Terry rating on round wins (Round Elo).

const ratingView = (h: H, elo: Rating | undefined): ReadonlyArray<Html | string> =>
  elo === undefined ? ["–"] : [`${elo.rating >= 0 ? "+" : ""}${elo.rating.toFixed(0)} `, h.span([h.Class("pm")], [`[${elo.lo.toFixed(0)}, ${elo.hi.toFixed(0)}]`])];

interface Detail {
  readonly label: string;
  readonly title: string;
  readonly content: ReadonlyArray<Html | string>;
}

const detailsOf = (h: H, m: ModelStats, item: ItemSummary | undefined, hasRegret: boolean): ReadonlyArray<Detail> => {
  const { lo, hi } = m.win;
  const moves = sumOf(m.scored.map((seat) => seat.moves ?? 0));
  const cost = sumOf(m.scored.map((seat) => seat.cost ?? 0));
  const favorite = item?.favorite ?? null;

  return [
    { label: "match wins", title: `${fmtPct(lo)}–${fmtPct(hi)}`, content: [h.b([], [fmtPct(m.winShare)]), " ", h.span([h.Class("pm")], [`${m.win.k.toFixed(m.win.k % 1 ? 1 : 0)}/${m.win.n}`])] },
    { label: "round wins", title: "", content: [fmtPct(m.roundShare)] },
    { label: "cash share", title: "", content: [fmtPct(m.potShare)] },
    ...(hasRegret ? [{ label: "regret", title: m.regret === null ? "" : `${m.regret.moves.toLocaleString()} moves · ${fmtPct(m.regret.exactShare)} proven exact`, content: [m.regret === null ? "–" : fmtPoints(m.regret.mean)] }] : []),
    { label: "per move", title: "", content: [fmtUsd(moves > 0 ? cost / moves : null)] },
    { label: "time", title: "", content: [fmtSec(moves > 0 ? sumOf(m.scored.map((seat) => seat.lat ?? 0)) / moves : null)] },
    { label: "out tok", title: "", content: [fmtCount(m.avgOut)] },
    { label: "fav", title: favorite === null ? "" : `${favorite.k} of ${favorite.n} legal moves`, content: favorite === null ? ["–"] : [itemIconOf(h, favorite.item), `${favorite.item} `, h.span([h.Class("pm")], [fmtPct(favorite.rate)])] },
  ];
};

const rowView = (h: H, m: ModelStats, elo: Rating | undefined, details: ReadonlyArray<Detail>, isOpen: boolean): Html => {
  const { lo, hi } = m.win;

  return h.keyed("tr")(
    m.id,
    [h.Class(`row ${isOpen ? "sel" : ""} ${m.win.n < FEW_MATCHES ? "few" : ""}`), h.AriaExpanded(isOpen), ...pressable(h, Message.ClickedLeaderboardRow({ id: m.id }))],
    [
      h.td([], [h.span([h.Class(`dot ${isClaude(m.model) ? "a" : "o"}`), h.Style({ background: m.color })], []), `${baseName(m.model)} `, h.span([h.Class("eff")], [`[${m.effort}]`])]),
      h.td([h.DataAttribute("label", "round elo")], ratingView(h, elo)),
      h.td([h.DataAttribute("label", "matches")], [m.scored.length.toLocaleString()]),
      h.td([h.DataAttribute("label", "cost")], [fmtUsd(m.avgCost)]),
      h.td(
        [h.Class("barcol")],
        [
          h.div(
            [h.Class("track")],
            [h.div([h.Class("fill"), h.Style({ width: `${m.winShare * 100}%`, background: m.color })], []), h.div([h.Class("whisk"), h.Style({ left: `${lo * 100}%`, width: `${(hi - lo) * 100}%` })], [])],
          ),
        ],
      ),
      ...details.map(({ label, title, content }) => h.td([h.Class("detail"), h.DataAttribute("label", label), ...(title === "" ? [] : [h.Title(title)])], [...content])),
    ],
  );
};

const detailsView = (h: H, details: ReadonlyArray<Detail>): Html =>
  h.dl([h.Class("drillstats")], details.flatMap(({ label, title, content }) => [h.dt([], [label]), h.dd(title === "" ? [] : [h.Title(title)], [...content])]));

/** One config's drill-down as a card: what a click on its scatter point opens. */
export const configPanelView = (h: H, derived: Derived, key: string, maybeTip: Option.Option<string>): Html => {
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
      drillView(h, m, derived, maybeTip),
    ],
  );
};

const headersOf = (hasRegret: boolean): ReadonlyArray<string> => [
  "Model",
  "Round Elo",
  "Matches",
  "Avg cost",
  "",
  "Match wins",
  "Round wins",
  "Cash share",
  ...(hasRegret ? ["Regret"] : []),
  "Per move",
  "Time / move",
  "Out tok",
  "Favorite item",
];

const BAR_COLUMN = 4;

/** Rows with fewer scored matches than this are faded: their shares swing widely. */
const FEW_MATCHES = 20;

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

/** Configs with a scored match, by rank; the unranked (no rating) last, by label. */
export const inRankOrder = (stats: ReadonlyArray<ModelStats>, ranks: ReadonlyMap<string, number>): ReadonlyArray<ModelStats> =>
  stats.filter(({ scored }) => scored.length > 0).toSorted((left, right) => (ranks.get(left.key) ?? Number.POSITIVE_INFINITY) - (ranks.get(right.key) ?? Number.POSITIVE_INFINITY) || left.label.localeCompare(right.label));

export const leaderboardView = (h: H, derived: Derived, leaderboard: Model["leaderboard"]): Html => {
  const { pooled: stats, everyPooled: every, ranks, ratings, items } = derived;
  const hasRegret = every.some(({ regret }) => regret !== null);
  const headers = headersOf(hasRegret);
  const configs = inRankOrder(stats, ranks);

  return h.div(
    [h.Class("lb")],
    [
      h.div([h.Class("lbbar")], [h.h2([], ["Leaderboard"])]),
      h.p([h.Class("sub")], ["Round Elo is one Bradley-Terry rating over every match, on round win share; intervals are 95% bootstraps over seed blocks."]),
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
                    rowView(h, m, ratings.get(m.key), details, isOpen),
                    isOpen ? h.keyed("tr")(`drill-${m.id}`, [h.Class("drill")], [h.td([h.Colspan(headers.length)], [detailsView(h, details), drillView(h, m, derived, leaderboard.maybeTip)])]) : h.empty,
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
                      h.td([h.Class("barcol")], [h.div([h.Class("axis")], [0, 25, 50, 75, 100].map((tick) => h.span([h.Style({ left: `${tick}%` })], [`${tick}%`])))]),
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
