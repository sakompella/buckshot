import { Option } from "effect";
import type { Html, HtmlBuilder } from "foldkit/html";

import { anchorId, rankingView, tipView } from "./charts.ts";
import { baseName, fmtCount, fmtPct, fmtSec, fmtUsd, groupBy, isClaude, keyOf, labelOf, type ModelStats, rankOrder, type SeatFull, sumOf } from "./data.ts";
import { type ItemSummary, memoLast } from "./derived.ts";
import { itemIconOf } from "./items.ts";
import { Message, type Model, type Ranking } from "./model.ts";
import type { Rating } from "./ratings.ts";

type H = HtmlBuilder<Message>;

// One table per cohort, ranked by the pooled Bradley-Terry rating (Elo) or by win share within the cohort.

interface Cohort {
  readonly cohort: string;
  readonly configs: ReadonlyArray<ModelStats>;
  /** Each config's place by win share among all the cohort's configs, whatever the filter (see rankOrder). */
  readonly places: ReadonlyMap<string, number>;
  readonly scoredMatches: number;
  /** One model's effort sweep rather than cross-model games. */
  readonly isSweep: boolean;
}

const cohortsOf = memoLast((stats: ReadonlyArray<ModelStats>, every: ReadonlyArray<ModelStats>, seats: ReadonlyArray<SeatFull>, ratings: ReadonlyMap<string, Rating>): ReadonlyArray<Cohort> => {
  const eloOf = (m: ModelStats) => ratings.get(m.key)?.rating ?? 0;

  return [...groupBy(
    stats.filter(({ scored }) => scored.length > 0),
    ({ cohort }) => cohort,
  )]
    .map(([cohort, configs]) => ({
      cohort,
      configs: configs.toSorted((left, right) => eloOf(right) - eloOf(left)),
      places: new Map(rankOrder(every.filter((m) => m.cohort === cohort && m.scored.length > 0), eloOf).map((m, index) => [m.key, index + 1])),
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
    .toSorted((left, right) => right.share - left.share);

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

const COLUMNS = 9;

/** How a row shows its standing: its Elo with an interval, or its place. */
type Standing = { readonly elo: Rating | undefined } | { readonly place: number };

const standingView = (h: H, standing: Standing): ReadonlyArray<Html | string> => {
  if ("place" in standing) return [String(standing.place)];

  const { elo } = standing;

  return elo === undefined ? ["–"] : [`${elo.rating >= 0 ? "+" : ""}${elo.rating.toFixed(0)} `, h.span([h.Class("pm")], [`[${elo.lo.toFixed(0)}, ${elo.hi.toFixed(0)}]`])];
};

const rowView = (h: H, m: ModelStats, standing: Standing, item: ItemSummary | undefined, isOpen: boolean): Html => {
  const { lo, hi } = m.win;
  const moves = sumOf(m.scored.map((seat) => seat.moves ?? 0));
  const cost = sumOf(m.scored.map((seat) => seat.cost ?? 0));
  const favorite = item?.favorite ?? null;

  return h.keyed("tr")(
    m.id,
    [h.Class(`row ${isOpen ? "sel" : ""}`), h.OnClick(Message.ClickedLeaderboardRow({ id: m.id }))],
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
      h.td([h.DataAttribute("label", "place" in standing ? "rank" : "Elo")], standingView(h, standing)),
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

const headersOf = (ranking: Ranking): ReadonlyArray<string> => ["Model", "", "Win share", ranking === "elo" ? "Elo" : "Rank", "Avg cost", "Per move", "Time / move", "Out tok", "Favorite item"];

// Without 'all configs' a sweep usually keeps only its medium row, which has nothing to be ranked against.
const isShown = (cohort: Cohort, isAllConfigs: boolean): boolean => isAllConfigs || !cohort.isSweep || cohort.configs.length > 1;

const cohortView = (h: H, { cohort, configs: byElo, places, scoredMatches }: Cohort, ratings: ReadonlyMap<string, Rating>, seats: ReadonlyArray<SeatFull>, items: ReadonlyMap<string, ItemSummary>, leaderboard: Model["leaderboard"], ranking: Ranking): Html => {
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
              h.thead([], [h.tr([], headersOf(ranking).map((label, index) => h.th(index === 1 ? [h.Class("barcol")] : [], [label])))]),
              h.tbody(
                [],
                configs.flatMap((m) => {
                  const isOpen = Option.exists(leaderboard.maybeOpen, (open) => open === m.id);
                  const standing: Standing = ranking === "elo" ? { elo: ratings.get(m.key) } : { place: placeOf(m) };

                  return [
                    rowView(h, m, standing, items.get(m.id), isOpen),
                    isOpen ? h.keyed("tr")(`drill-${m.id}`, [h.Class("drill")], [h.td([h.Colspan(COLUMNS)], [drillView(h, m, seats, leaderboard.maybeTip)])]) : h.empty,
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
                      h.td([h.Colspan(COLUMNS - 2)], []),
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
): Html =>
  h.div(
    [h.Class("lb")],
    [
      h.div([h.Class("lbbar")], [h.h2([], ["Leaderboard by cohort"]), rankingView(h, ranking)]),
      h.p(
        [h.Class("sub")],
        [
          ranking === "elo"
            ? "Elo is one Bradley-Terry rating fitted over every match of every tournament; intervals are 95% bootstraps over seed blocks."
            : "Rank is the place by observed win share among all of a cohort's configs, before the filters; ties go to the higher Elo.",
        ],
      ),
      ...cohortsOf(stats, every, seats, ratings).filter((cohort) => isShown(cohort, isAllConfigs)).map((cohortRow) =>
        cohortView(h, cohortRow, ratings, seats, items, leaderboard, ranking),
      ),
    ],
  );
