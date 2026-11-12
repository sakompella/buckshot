import { Option } from "effect";
import { AsyncData } from "foldkit";
import type { Html, HtmlBuilder } from "foldkit/html";

import { CERTAIN_TYPES, type CertainRate } from "../api.ts";
import { type Cell as CertainCell, talliesOf } from "./certain.ts";

import { pressable } from "./charts.ts";
import { effortName } from "../../arena/model-names.ts";
import { baseName, CERTAIN_NAMES, costPerMove, effortLabel, fmtCount, fmtPct, fmtPoints, fmtSec, fmtShare, fmtUsd, isClaude, isProvisional, reasoningPerMove } from "./data.ts";
import { type Derived, LUCK_ELO, type ModelStats, ROUND_ELO } from "./derived.ts";
import { drillView } from "./drill.ts";
import { itemIconOf } from "./items.ts";
import { type Lazy, Message, type Model } from "./model.ts";
import { ANCHOR, matchWinVsAnchor, type Rating } from "./ratings.ts";

type H = HtmlBuilder<Message>;

// One table, ranked by the headline rating (derived.ts), in tiers of configs the data cannot tell apart.

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

/** Below this many reasoning tokens per move a config reasons not at all. */
const NO_REASONING = 0.5;

/** Whether the reasoning measured disagrees with the effort asked for: reasoning with effort off, or none with effort on. */
const isEffortMismatch = (m: ModelStats): boolean => {
  const reasoning = reasoningPerMove(m);

  return reasoning !== null && m.effort !== "" && (m.effort === "off") === reasoning >= NO_REASONING;
};

/** Pairs of one model's configs whose efforts differ but whose measured reasoning per move is the same, within 2%. */
export const sameTreatments = (stats: ReadonlyArray<ModelStats>): ReadonlyArray<readonly [ModelStats, ModelStats]> =>
  stats.flatMap((m, index) =>
    stats.slice(index + 1).flatMap((other) => {
      const [own, theirs] = [reasoningPerMove(m), reasoningPerMove(other)];

      return m.model === other.model && own !== null && theirs !== null && Math.abs(own - theirs) <= NO_REASONING + 0.02 * Math.max(own, theirs) ? [[m, other] as const] : [];
    }),
  );

/** A config's dot, model name and effort; an effort the measured reasoning disagrees with is marked as requested. */
const nameView = (h: H, m: ModelStats): ReadonlyArray<Html | string> => {
  const effort = effortLabel(m.model, m.effort);
  const mismatch = isEffortMismatch(m);

  return [
    h.span([h.Class(`dot ${isClaude(m.model) ? "a" : "o"}`), h.Style({ background: m.color })], []),
    `${baseName(m.model)} `,
    ...(effort === "" ? [] : [h.span([h.Class("eff"), ...(mismatch ? [h.Title(`requested ${effortName(m.effort)}, measured ${fmtCount(reasoningPerMove(m))} reasoning tokens per move`)] : [])], [`[${effort}${mismatch ? " (requested)" : ""}]`])]),
  ];
};

const matchWinView = (elo: Rating | undefined): string => (elo === undefined ? "–" : fmtPct(matchWinVsAnchor(elo.rating)));

const rowView = (h: H, m: ModelStats, elo: Rating | undefined, hasLuck: boolean, scale: EloScale, details: ReadonlyArray<Detail>, isOpen: boolean, startsTier: boolean): Html =>
  h.keyed("tr")(
    m.key,
    [h.Class(`row ${isOpen ? "sel" : ""} ${isProvisional(m) ? "provisional" : ""} ${startsTier ? "tierstart" : ""}`), h.AriaExpanded(isOpen), ...pressable(h, Message.ClickedLeaderboardRow({ id: m.key }))],
    [
      h.td([], [h.span([h.Class("rk")], [elo?.tier == null ? "" : String(elo.tier)]), ...nameView(h, m)]),
      h.td([h.DataAttribute("label", hasLuck ? "luck-adjusted" : "round elo")], ratingView(h, elo)),
      h.td([h.DataAttribute("label", "match win vs engine")], [matchWinView(elo)]),
      ...(hasLuck ? [h.td([h.DataAttribute("label", "round elo")], ratingView(h, m.rating ?? undefined))] : []),
      h.td([h.DataAttribute("label", "matches"), h.Title(`${m.win.blocks} seed blocks`)], [m.scored.toLocaleString()]),
      h.td([h.DataAttribute("label", "reasoning tok / move")], [fmtCount(reasoningPerMove(m))]),
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

const MATCH_WIN = "Match win vs engine";

const REASONING = "Reasoning tok / move";

const headersOf = (ratingName: string, hasRegret: boolean, hasLuck: boolean): ReadonlyArray<string> => [
  "Model",
  ratingName,
  MATCH_WIN,
  ...(hasLuck ? [ROUND_ELO] : []),
  "Matches",
  REASONING,
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

export const ACCURACY_TITLE = "Lichess's accuracy over points of round win chance: each move scored by what it gave up against the minimax player's best move, a game's value combining a volatility-weighted and a harmonic mean, averaged over the config's matches; higher is better, 100 is perfect";

export const P99_TITLE = "Points of round win chance lost by the 99th-percentile move: one move in a hundred gave up at least this much";

const HEADER_TITLES = new Map([
  [ROUND_ELO, "one Bradley-Terry rating over every match, on round win share, with the depth-2 search engine at 0; the interval is a 95% bootstrap over seed blocks"],
  [LUCK_ELO, "Round Elo with each round's result corrected for the luck of its shots, loads, first seat, item deals and the shells items show (AIVAT): the same strengths with less noise"],
  [MATCH_WIN, "the chance of winning a match against the depth-2 search engine (Engine/2/20000, rated 0), from the rating: two round wins of three"],
  [REASONING, "reasoning tokens the provider reported per model move, over scored matches"],
  ["Cash share", "a config's cash over the match's cash, averaged over scored matches"],
  ["Round wins", "the rounds a config won over the rounds it played"],
  ["Accuracy", ACCURACY_TITLE],
  ["p99 points lost", P99_TITLE],
]);

const headerView = (h: H, label: string): Html => {
  const title = HEADER_TITLES.get(label);

  return h.th(label === "" ? [h.Class("barcol")] : [...(label === ROUND_ELO || label === LUCK_ELO ? [h.Class("rating")] : []), ...(title === undefined ? [] : [h.Title(title)])], [label]);
};

/** Configs with a scored match, by rank; the unranked (provisional or unrated) after them, by rating and then label. */
export const inRankOrder = (stats: ReadonlyArray<ModelStats>, ranks: ReadonlyMap<string, number>, ratings: ReadonlyMap<string, Rating>): ReadonlyArray<ModelStats> => {
  const eloOf = ({ key }: ModelStats) => ratings.get(key)?.rating ?? Number.NEGATIVE_INFINITY;

  return stats
    .filter(({ scored }) => scored > 0)
    .toSorted((left, right) => (ranks.get(left.key) ?? Number.POSITIVE_INFINITY) - (ranks.get(right.key) ?? Number.POSITIVE_INFINITY) || eloOf(right) - eloOf(left) || left.label.localeCompare(right.label));
};

export const leaderboardView = (h: H, derived: Derived, leaderboard: Model["leaderboard"], lazy: Lazy): Html => {
  const { pooled: stats, everyPooled: every, ranks, ratings, ratingName } = derived;
  const hasRegret = every.some(({ regret }) => regret !== null);
  const hasLuck = ratingName === LUCK_ELO;
  const headers = headersOf(ratingName, hasRegret, hasLuck);
  const barColumn = headers.indexOf("");
  const configs = inRankOrder(stats, ranks, ratings);
  const scale = eloScaleOf(ratings, ranks);
  const tierOf = (m: ModelStats | undefined) => (m === undefined ? undefined : ratings.get(m.key)?.tier);
  const same = sameTreatments(configs);
  const zero = ratings.get(ANCHOR)?.interval ?? null;

  return h.div(
    [h.Class("lb")],
    [
      h.div([h.Class("lbbar")], [h.h2([], ["Leaderboard"])]),
      h.p([h.Class("sub")], [
        `${hasLuck ? `${LUCK_ELO} is Round Elo with the luck of each round's shots, loads, first seat, item deals and the shells items show taken out. ` : ""}Round Elo is one Bradley-Terry rating over every match, on round win share. The depth-2 search engine (Engine/2/20000) is fixed at 0, so adding a config does not move the others. The bar runs from 0, with its 95% interval over seed blocks.${zero === null ? "" : ` The 0 is itself uncertain: against the mean of all configs, the engine's own 95% interval is ${Math.round(zero.lo)} to +${Math.round(zero.hi)}. The other intervals are measured the same way, so they leave out the engine's noise.`} The number before a config is its tier: the data cannot tell the configs of one tier apart. Match wins count a config's own opponents only.`,
      ]),
      h.div(
        [h.Class("card")],
        [
          h.table(
            [h.Class("lbt rows")],
            [
              h.thead([], [h.tr([], headers.map((label) => headerView(h, label)))]),
              h.tbody(
                [],
                configs.flatMap((m, index) => {
                  const isOpen = Option.exists(leaderboard.maybeOpen, (open) => open === m.key);
                  const details = detailsOf(h, m, hasRegret);

                  return [
                    rowView(h, m, ratings.get(m.key), hasLuck, scale, details, isOpen, index > 0 && tierOf(m) !== tierOf(configs[index - 1])),
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
      ...[
        ...(same.length === 0 ? [] : [`Same measured reasoning under different requested efforts: ${same.map(([one, other]) => `${one.label} and ${other.label} (${fmtCount(reasoningPerMove(one))} and ${fmtCount(reasoningPerMove(other))} tokens per move)`).join("; ")}.`]),
        ...(configs.some(isEffortMismatch) ? ["An effort marked (requested) disagrees with the measured reasoning: reasoning at effort none, or none at another effort."] : []),
      ].map((note) => h.p([h.Class("sub")], [note])),
    ],
  );
};

const ACCURACY_HEADERS: ReadonlyArray<readonly [string, string]> = [
  ["Model", ""],
  ["Avg points lost", "Mean points of round win chance a move gave up against the minimax player's best move; lower is better"],
  ...CERTAIN_TYPES.map((type) => [CERTAIN_NAMES[type], "Share of the decisions where this mistake was a legal move that made it; the player's own information proves it worse, with no evaluator"] as const),
  ["Accuracy", ACCURACY_TITLE],
  ["p99 points lost", P99_TITLE],
  ["Best moves", "Moves as good as the minimax player's best"],
  ["Inaccuracies / 100", "Moves per 100 that gave up 5 to 10 points of round win chance (lichess's inaccuracy, 0.1 of its winning chances)"],
  ["Mistakes / 100", "Moves per 100 that gave up 10 to 15 points (lichess's mistake, 0.2)"],
  ["Blunders / 100", "Moves per 100 that gave up 15 points or more (lichess's blunder, 0.3)"],
  ["Moves", "Moves with a real choice, over the config's scored matches; decisions where every move is within a point are left out"],
];

/** Configs with a scored move, fewest points lost first. */
export const inPointsLostOrder = (stats: ReadonlyArray<ModelStats>): ReadonlyArray<ModelStats> =>
  stats.filter(({ regret }) => regret !== null).toSorted((left, right) => (left.regret?.meanLost ?? 0) - (right.regret?.meanLost ?? 0) || left.label.localeCompare(right.label));

const certainCellView = (h: H, cell: CertainCell | undefined): Html =>
  cell === undefined || cell.opportunities === 0
    ? h.td([h.DataAttribute("label", cell === undefined ? "" : CERTAIN_NAMES[cell.type])], ["–"])
    : h.td([h.DataAttribute("label", CERTAIN_NAMES[cell.type]), h.Title(`${cell.mistakes.toLocaleString()} of ${cell.opportunities.toLocaleString()}`)], [fmtShare(cell.mistakes / cell.opportunities)]);

const accuracyRowView = (h: H, m: ModelStats, rank: number, certain: ReadonlyArray<CertainCell> | undefined): Html => {
  const { regret } = m;
  const cell = (label: string, text: string | undefined) => h.td([h.DataAttribute("label", label), ...(label === "avg points lost" ? [h.Title(movesTitle(m))] : [])], [text ?? "–"]);

  return h.keyed("tr")(
    m.key,
    [h.Class(`row ${isProvisional(m) ? "provisional" : ""}`)],
    [
      h.td([], [h.span([h.Class("rk")], [String(rank)]), ...nameView(h, m)]),
      cell("avg points lost", regret === null ? undefined : fmtPoints(regret.meanLost)),
      ...CERTAIN_TYPES.map((type) => certainCellView(h, certain?.find((own) => own.type === type))),
      cell("accuracy", regret?.accuracy.toFixed(1)),
      cell("p99 points lost", regret === null ? undefined : fmtPoints(regret.p99Lost)),
      cell("best moves", regret === null ? undefined : fmtPct(regret.bestShare)),
      cell("inaccuracies / 100", regret?.inaccuraciesPer100.toFixed(1)),
      cell("mistakes / 100", regret?.mistakesPer100.toFixed(1)),
      cell("blunders / 100", regret?.blundersPer100.toFixed(1)),
      cell("moves", regret?.moves.toLocaleString()),
    ],
  );
};

/** One table of how much each config's moves gave up, fewest points lost first, with its certain mistakes once they load. */
export const accuracyTableView = (h: H, derived: Derived, certain: AsyncData.AsyncData<ReadonlyArray<CertainRate>, string>): Html => {
  const configs = inPointsLostOrder(derived.pooled);
  const certainRows = new Map(Option.match(AsyncData.getData(certain), { onNone: () => [], onSome: (rates) => talliesOf(rates, derived.kept).rows.map((row) => [row.key, row.cells] as const) }));

  return h.div(
    [h.Id("accuracy-table")],
    [
      h.h2([], ["Points lost and certain mistakes by config"]),
      h.p([h.Class("sub")], [
        "Points lost: the round win chance each move gave up against the minimax player's best move. Certain mistakes: shots the player's own information proves worse, which need no evaluator. Accuracy applies lichess's formula and its inaccuracy, mistake and blunder cut-offs to the points lost. Decisions where every move is within a point are left out.",
      ]),
      configs.length === 0
        ? h.div([h.Class("empty")], ["No config in this filter has a scored move."])
        : h.div(
            [h.Class("card")],
            [
              h.table(
                [h.Class("lbt rows")],
                [
                  h.thead([], [h.tr([], ACCURACY_HEADERS.map(([label, title]) => h.th(title === "" ? [] : [h.Title(title)], [label])))]),
                  h.tbody([], configs.map((m, index) => accuracyRowView(h, m, index + 1, certainRows.get(m.key)))),
                ],
              ),
            ],
          ),
    ],
  );
};
