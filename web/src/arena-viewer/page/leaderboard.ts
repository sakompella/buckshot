import { Option } from "effect";
import type { Html, HtmlBuilder } from "foldkit/html";

import { anchorId, rankingView, tipView } from "./charts.ts";
import { baseName, fitGames, fmtCount, fmtPct, fmtSec, fmtUsd, groupBy, isClaude, keyOf, labelOf, type ModelStats, numberGames, pairsOf, quantile, rankOrder, rng, type SeatFull, sumOf, unique } from "./data.ts";
import { type ItemSummary, memoLast } from "./derived.ts";
import { itemIconOf } from "./items.ts";
import { Message, type Model, type Ranking } from "./model.ts";

type H = HtmlBuilder<Message>;

// One table per cohort, ranked by Bradley-Terry rating (Elo) or by win share within the cohort.

interface Rating {
  readonly rating: number;
  readonly lo: number;
  readonly hi: number;
  readonly group: number;
}

interface BlockGame {
  readonly a: string;
  readonly b: string;
  readonly sa: number;
  readonly block: string;
}

/** Connected groups of configs that played each other; ratings are only comparable inside one. */
const groupsOf = (games: ReadonlyArray<BlockGame>): ReadonlyMap<string, number> => {
  const parent = new Map<string, string>();

  const find = (key: string): string => {
    const up = parent.get(key) ?? key;

    if (up === key) return key;

    const root = find(up);

    parent.set(key, root);

    return root;
  };

  for (const { a, b } of games) {
    parent.set(a, find(a));
    parent.set(b, find(b));
    parent.set(find(a), find(b));
  }

  const roots = unique([...parent.keys()].map(find));

  return new Map([...parent.keys()].map((key) => [key, roots.indexOf(find(key))]));
};

/** Bradley-Terry fitted separately in each connected group of a cohort, with a 95% bootstrap over seed blocks. */
interface CohortRatings {
  readonly ratings: ReadonlyMap<string, Rating>;
  /** How many connected groups the cohort has. */
  readonly parts: number;
}

const cohortRatings = (seats: ReadonlyArray<SeatFull>): CohortRatings => {
  const games = pairsOf(seats).map(([x, y]): BlockGame => ({ a: keyOf(x), b: keyOf(y), sa: x.winShare ?? 0, block: x.seedBlock }));
  const group = groupsOf(games);
  const parts = new Set(group.values()).size;
  const ratings = new Map<string, Rating>();

  for (let part = 0; part < parts; part++) {
    const partGames = games.filter(({ a }) => group.get(a) === part);
    const numbered = numberGames(partGames);
    const point = fitGames(numbered, Int32Array.from(partGames.keys()));
    const blocks = [...groupBy(partGames.keys(), (index) => partGames[index]?.block).values()];
    const random = rng(3);
    const draws = new Map<string, Array<number>>();

    for (let rep = 0; rep < 200; rep++) {
      const sample = Array.from({ length: blocks.length }, () => blocks[Math.floor(random() * blocks.length)] ?? []).flat();

      for (const [key, rating] of fitGames(numbered, sample)) {
        const keyDraws = draws.get(key);

        if (keyDraws) keyDraws.push(rating);
        else draws.set(key, [rating]);
      }
    }

    for (const [key, rating] of point) {
      const sorted = (draws.get(key) ?? []).toSorted((left, right) => left - right);

      ratings.set(key, { rating, lo: quantile(sorted, 0.025), hi: quantile(sorted, 0.975), group: part });
    }
  }

  return { ratings, parts };
};

interface Cohort {
  readonly cohort: string;
  readonly configs: ReadonlyArray<ModelStats>;
  readonly ratings: ReadonlyMap<string, Rating>;
  /** Each config's place by win share among all the cohort's configs, whatever the filter (see rankOrder). */
  readonly places: ReadonlyMap<string, number>;
  readonly parts: number;
  readonly scoredMatches: number;
  /** One model's effort sweep rather than cross-model games. */
  readonly isSweep: boolean;
}

// The bootstraps are the page's slowest work. A filter changes few cohorts' matches, so each fit is kept by its matches.
const fitted = new Map<string, CohortRatings>();

const cohortRatingsOf = (seats: ReadonlyArray<SeatFull>): CohortRatings => {
  const matches = seats.map(({ matchId }) => matchId).join();
  const known = fitted.get(matches);

  if (known) return known;

  const fresh = cohortRatings(seats);

  fitted.set(matches, fresh);

  return fresh;
};

const cohortsOf = memoLast((stats: ReadonlyArray<ModelStats>, every: ReadonlyArray<ModelStats>, seats: ReadonlyArray<SeatFull>): ReadonlyArray<Cohort> =>
  [...groupBy(
    stats.filter(({ scored }) => scored.length > 0),
    ({ cohort }) => cohort,
  )]
    .map(([cohort, configs]) => {
      const cohortSeats = seats.filter((seat) => seat.cohort === cohort);
      const { ratings, parts } = cohortRatingsOf(cohortSeats);
      const ratingOf = (m: ModelStats) => ratings.get(m.key);
      const everyConfig = every.filter((m) => m.cohort === cohort && m.scored.length > 0);

      return {
        cohort,
        configs: configs.toSorted((left, right) => (ratingOf(left)?.group ?? 0) - (ratingOf(right)?.group ?? 0) || (ratingOf(right)?.rating ?? 0) - (ratingOf(left)?.rating ?? 0)),
        ratings,
        places: new Map(rankOrder(everyConfig, (m) => ratingOf(m)?.rating ?? 0).map((m, index) => [m.key, index + 1])),
        parts,
        scoredMatches: new Set(configs.flatMap(({ scored }) => scored.map(({ matchId }) => matchId))).size,
        isSweep: new Set(cohortSeats.map(({ model }) => model)).size === 1,
      };
    })
    .toSorted((left, right) => right.scoredMatches - left.scoredMatches),
);

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

const cohortView = (h: H, { cohort, configs: byElo, ratings, places, parts, scoredMatches }: Cohort, seats: ReadonlyArray<SeatFull>, items: ReadonlyMap<string, ItemSummary>, leaderboard: Model["leaderboard"], ranking: Ranking): Html => {
  // Connected groups only matter to Elo: places by win share run over the whole cohort.
  const placeOf = (m: ModelStats) => places.get(m.key) ?? 0;
  const configs = ranking === "elo" ? byElo : byElo.toSorted((left, right) => placeOf(left) - placeOf(right));
  const isGrouped = ranking === "elo" && parts > 1;

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
                configs.flatMap((m, index) => {
                  const group = ratings.get(m.key)?.group ?? 0;
                  const previous = configs[index - 1];
                  const isNewGroup = isGrouped && (previous === undefined || (ratings.get(previous.key)?.group ?? 0) !== group);
                  const isOpen = Option.exists(leaderboard.maybeOpen, (open) => open === m.id);
                  const standing: Standing = ranking === "elo" ? { elo: ratings.get(m.key) } : { place: placeOf(m) };

                  return [
                    isNewGroup ? h.keyed("tr")(`group-${group}`, [h.Class("group")], [h.td([h.Colspan(COLUMNS)], [`Connected group ${group + 1} of ${parts}`])]) : h.empty,
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
            ? "Elo is Bradley-Terry within each cohort; intervals are 95% bootstraps over seed blocks."
            : "Rank is the place by observed win share among all of a cohort's configs, before the filters; ties go to the higher Elo.",
        ],
      ),
      ...cohortsOf(stats, every, seats).filter((cohort) => isShown(cohort, isAllConfigs)).map((cohortRow) =>
        cohortView(h, cohortRow, seats, items, leaderboard, ranking),
      ),
    ],
  );
