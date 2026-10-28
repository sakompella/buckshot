import { Option } from "effect";
import type { Html, HtmlBuilder } from "foldkit/html";

import { anchorId, pressable, ratingToggles, tipView } from "./charts.ts";
import { baseName, configShare, eloName, fmtCount, fmtPct, fmtPoints, fmtSec, fmtUsd, groupBy, isClaude, keyOf, labelOf, type ModelStats, rankOrder, type SeatFull, shareName, sumOf } from "./data.ts";
import { type ItemSummary, memoLast } from "./derived.ts";
import { itemIconOf } from "./items.ts";
import { type Basis, Message, type Model, type Ranking } from "./model.ts";
import type { Rating } from "./ratings.ts";

type H = HtmlBuilder<Message>;

// One table per cohort, ranked by the pooled Bradley-Terry rating (Elo) or by observed share within the cohort.

interface Cohort {
  readonly cohort: string;
  readonly configs: ReadonlyArray<ModelStats>;
  /** Each config's place by observed share among all the cohort's configs, whatever the filter (see rankOrder). */
  readonly places: ReadonlyMap<string, number>;
  readonly scoredMatches: number;
  /** One model's effort sweep rather than cross-model games. */
  readonly isSweep: boolean;
}

const cohortsOf = memoLast((stats: ReadonlyArray<ModelStats>, every: ReadonlyArray<ModelStats>, seats: ReadonlyArray<SeatFull>, ratings: ReadonlyMap<string, Rating>, basis: Basis): ReadonlyArray<Cohort> => {
  const eloOf = (m: ModelStats) => ratings.get(m.key)?.rating ?? 0;

  return [...groupBy(
    stats.filter(({ scored }) => scored.length > 0),
    ({ cohort }) => cohort,
  )]
    .map(([cohort, configs]) => ({
      cohort,
      configs: configs.toSorted((left, right) => eloOf(right) - eloOf(left)),
      places: new Map(rankOrder(every.filter((m) => m.cohort === cohort && m.scored.length > 0), (m) => configShare(m, basis), eloOf).map((m, index) => [m.key, index + 1])),
      scoredMatches: new Set(configs.flatMap(({ scored }) => scored.map(({ matchId }) => matchId))).size,
      isSweep: new Set(seats.flatMap((seat) => (seat.cohort === cohort ? [seat.model] : []))).size === 1,
    }))
    .toSorted((left, right) => right.scoredMatches - left.scoredMatches);
});

const resultOf = (seat: SeatFull): string => {
  const share = seat.winShare ?? 0;

  if (share >= 1) return "Win";

  return share > 0 ? `Split ${fmtPct(share)}` : "Loss";
};

/** Every scored match of one config, grouped by opponent: one square per match, filled by win share. */
const drillView = (h: H, m: ModelStats, seats: ReadonlyArray<SeatFull>, maybeTip: Option.Option<string>): Html => {
  const mine = new Map(m.scored.map((seat) => [seat.matchId, seat]));
  const opponents = new Map(seats.flatMap((seat) => (mine.has(seat.matchId) && mine.get(seat.matchId)?.player !== seat.player ? [[seat.matchId, seat] as const] : [])));

  const games = m.scored.flatMap((seat) => {
    const opponent = opponents.get(seat.matchId);

    return opponent === undefined ? [] : [{ seat, opponent }];
  });

  const groups = [...groupBy(games, ({ opponent }) => keyOf(opponent))]
    .map(([key, rows]) => ({ key, rows, share: sumOf(rows.map(({ seat }) => seat.winShare ?? 0)) / rows.length }))
    .toSorted((left, right) => right.rows.length - left.rows.length || right.share - left.share);

  const fill = (seat: SeatFull) => {
    const share = seat.winShare ?? 0;

    if (share >= 1) return m.color;

    return share > 0 ? `color-mix(in srgb, ${m.color} 45%, #1a1a1a)` : "#1a1a1a";
  };

  const tip = Option.flatMap(maybeTip, (matchId) => Option.fromUndefinedOr(games.find(({ seat }) => seat.matchId === matchId)));

  return h.div(
    [h.Class("drillin")],
    [
      ...groups.map((group) =>
        h.keyed("div")(
          group.key,
          [h.Class("opp")],
          [
            h.span([h.Class("on")], [`vs ${labelOf(group.key)}`]),
            h.span([h.Class("ow")], [`${fmtPct(group.share)} `, h.span([h.Class("pm")], [`of ${group.rows.length}`])]),
            h.span(
              [h.Class("sq")],
              group.rows.map(({ seat }) =>
                h.keyed("i")(
                  seat.matchId,
                  [
                    h.Id(anchorId("sq", seat.matchId)),
                    h.Style({ background: fill(seat) }),
                    h.OnMouseEnter(Message.HoveredSquare({ matchId: seat.matchId })),
                    h.OnMouseLeave(Message.LeftSquare()),
                    h.OnClick(Message.ClickedMatch({ id: seat.matchId, maybeFocus: Option.none() })),
                  ],
                  [],
                ),
              ),
            ),
          ],
        ),
      ),
      Option.match(tip, {
        onNone: () => h.empty,
        onSome: ({ seat, opponent }) =>
          tipView(h, anchorId("sq", seat.matchId), [
            h.b([], [resultOf(seat)]),
            ` vs ${labelOf(keyOf(opponent))}`,
            h.br([]),
            `seed ${seat.seed} · $${seat.cash?.toLocaleString() ?? ""} vs $${opponent.cash?.toLocaleString() ?? ""}`,
          ]),
      }),
    ],
  );
};

/** How a row shows its standing: its Elo with an interval, or its place. */
type Standing = { readonly elo: Rating | undefined } | { readonly place: number };

const standingView = (h: H, standing: Standing): ReadonlyArray<Html | string> => {
  if ("place" in standing) return [String(standing.place)];

  const { elo } = standing;

  return elo === undefined ? ["–"] : [`${elo.rating >= 0 ? "+" : ""}${elo.rating.toFixed(0)} `, h.span([h.Class("pm")], [`[${elo.lo.toFixed(0)}, ${elo.hi.toFixed(0)}]`])];
};

const regretCell = (h: H, m: ModelStats): Html =>
  h.td(
    [h.DataAttribute("label", "regret"), h.Title(m.regret === null ? "" : `${m.regret.moves.toLocaleString()} moves · ${fmtPct(m.regret.exactShare)} proven exact`)],
    [m.regret === null ? "–" : fmtPoints(m.regret.mean)],
  );

const rowView = (h: H, m: ModelStats, standing: Standing, basis: Basis, item: ItemSummary | undefined, isOpen: boolean, hasRegret: boolean): Html => {
  const { lo, hi } = m.win;
  const moves = sumOf(m.scored.map((seat) => seat.moves ?? 0));
  const cost = sumOf(m.scored.map((seat) => seat.cost ?? 0));
  const favorite = item?.favorite ?? null;

  return h.keyed("tr")(
    m.id,
    [h.Class(`row ${isOpen ? "sel" : ""} ${m.win.n < FEW_MATCHES ? "few" : ""}`), h.AriaExpanded(isOpen), ...pressable(h, Message.ClickedLeaderboardRow({ id: m.id }))],
    [
      h.td([], [h.span([h.Class(`dot ${isClaude(m.model) ? "a" : "o"}`), h.Style({ background: m.color })], []), `${baseName(m.model)} `, h.span([h.Class("eff")], [`[${m.effort}]`])]),
      h.td(
        [h.Class("barcol")],
        [
          h.div(
            [h.Class("track")],
            [h.div([h.Class("fill"), h.Style({ width: `${m.winShare * 100}%`, background: m.color })], []), h.div([h.Class("whisk"), h.Style({ left: `${lo * 100}%`, width: `${(hi - lo) * 100}%` })], [])],
          ),
        ],
      ),
      h.td([h.Class("ws"), h.Title(`${fmtPct(lo)}–${fmtPct(hi)}`)], [h.b([], [fmtPct(m.winShare)]), " ", h.span([h.Class("pm")], [`${m.win.k.toFixed(m.win.k % 1 ? 1 : 0)}/${m.win.n}`])]),
      basis === "rounds" ? h.td([h.DataAttribute("label", "round wins")], [fmtPct(m.roundShare)]) : h.empty,
      basis === "cash" ? h.td([h.DataAttribute("label", "pot share")], [fmtPct(m.potShare)]) : h.empty,
      h.td([h.DataAttribute("label", "place" in standing ? "rank" : eloName(basis))], standingView(h, standing)),
      ...(hasRegret ? [regretCell(h, m)] : []),
      h.td([h.DataAttribute("label", "cost")], [fmtUsd(m.avgCost)]),
      h.td([h.DataAttribute("label", "per move")], [fmtUsd(moves > 0 ? cost / moves : null)]),
      h.td([h.DataAttribute("label", "time")], [fmtSec(moves > 0 ? sumOf(m.scored.map((seat) => seat.lat ?? 0)) / moves : null)]),
      h.td([h.DataAttribute("label", "out tok")], [fmtCount(m.avgOut)]),
      h.td(
        [h.DataAttribute("label", "fav"), h.Title(favorite === null ? "" : `${favorite.k} of ${favorite.n} legal moves`)],
        favorite === null ? ["–"] : [itemIconOf(h, favorite.item), `${favorite.item} `, h.span([h.Class("pm")], [fmtPct(favorite.rate)])],
      ),
    ],
  );
};

const headersOf = (ranking: Ranking, basis: Basis, hasRegret: boolean): ReadonlyArray<string> => [
  "Model",
  "",
  "Match wins",
  ...SHARE_HEADERS[basis],
  ranking === "elo" ? eloName(basis) : "Rank",
  ...(hasRegret ? ["Regret"] : []),
  "Avg cost",
  "Per move",
  "Time / move",
  "Out tok",
  "Favorite item",
];

/** The share column beside the match win share, for the rating's basis. */
const SHARE_HEADERS = { rounds: ["Round wins"], matches: [], cash: ["Pot share"] } satisfies Record<Basis, ReadonlyArray<string>>;

/** Rows with fewer scored matches than this are faded: their shares swing widely. */
const FEW_MATCHES = 20;

const HEADER_TITLES = new Map([
  ["Pot share", "a config's cash over the match's cash, averaged over scored matches"],
  ["Round wins", "the rounds a config won over the rounds it played"],
  ["Regret", "mean points of round win chance a move gave up against the minimax player's best move; lower is better"],
]);

const headerView = (h: H, label: string, index: number): Html => {
  const title = HEADER_TITLES.get(label);

  return h.th(index === 1 ? [h.Class("barcol")] : label === "Rank" || label.endsWith("Elo") ? [h.Class("rating")] : title === undefined ? [] : [h.Title(title)], [label]);
};

// Without 'all configs' a sweep usually keeps only its medium row, which has nothing to be ranked against.
const isShown = (cohort: Cohort, isAllConfigs: boolean): boolean => isAllConfigs || !cohort.isSweep || cohort.configs.length > 1;

const cohortView = (h: H, { cohort, configs: byElo, places, scoredMatches }: Cohort, ratings: ReadonlyMap<string, Rating>, seats: ReadonlyArray<SeatFull>, items: ReadonlyMap<string, ItemSummary>, leaderboard: Model["leaderboard"], ranking: Ranking, basis: Basis, hasRegret: boolean): Html => {
  const headers = headersOf(ranking, basis, hasRegret);
  const placeOf = (m: ModelStats) => places.get(m.key) ?? 0;
  const configs = ranking === "elo" ? byElo : byElo.toSorted((left, right) => placeOf(left) - placeOf(right));

  return h.keyed("div")(
    cohort,
    [],
    [
      h.div([h.Class("lbbar")], [h.b([], [cohort]), h.span([h.Class("k")], [`${scoredMatches} scored matches`])]),
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
                  const standing: Standing = ranking === "elo" ? { elo: ratings.get(m.key) } : { place: placeOf(m) };

                  return [
                    rowView(h, m, standing, basis, items.get(m.id), isOpen, hasRegret),
                    isOpen ? h.keyed("tr")(`drill-${m.id}`, [h.Class("drill")], [h.td([h.Colspan(headers.length)], [drillView(h, m, seats, leaderboard.maybeTip)])]) : h.empty,
                  ];
                }),
              ),
              h.tfoot(
                [],
                [
                  h.tr(
                    [],
                    [
                      h.td([], []),
                      h.td([h.Class("barcol")], [h.div([h.Class("axis")], [0, 25, 50, 75, 100].map((tick) => h.span([h.Style({ left: `${tick}%` })], [`${tick}%`])))]),
                      h.td([h.Colspan(headers.length - 2)], []),
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

export const leaderboardView = (
  h: H,
  stats: ReadonlyArray<ModelStats>,
  every: ReadonlyArray<ModelStats>,
  ratings: ReadonlyMap<string, Rating>,
  seats: ReadonlyArray<SeatFull>,
  items: ReadonlyMap<string, ItemSummary>,
  leaderboard: Model["leaderboard"],
  isAllConfigs: boolean,
  ranking: Ranking,
  basis: Basis,
): Html => {
  const hasRegret = every.some(({ regret }) => regret !== null);

  return h.div(
    [h.Class("lb")],
    [
      h.div([h.Class("lbbar")], [h.h2([], ["Leaderboards"]), ...ratingToggles(h, ranking, basis)]),
      h.p(
        [h.Class("sub")],
        [
          ranking === "elo"
            ? `${eloName(basis)} is one Bradley-Terry rating over every match, on ${shareName(basis)}; intervals are 95% bootstraps over seed blocks.`
            : `Rank is the place by observed ${shareName(basis)} within each cohort; ties go to the higher ${eloName(basis)}.`,
        ],
      ),
      ...cohortsOf(stats, every, seats, ratings, basis).filter((cohort) => isShown(cohort, isAllConfigs)).map((cohortRow) =>
        cohortView(h, cohortRow, ratings, seats, items, leaderboard, ranking, basis, hasRegret),
      ),
    ],
  );
};
