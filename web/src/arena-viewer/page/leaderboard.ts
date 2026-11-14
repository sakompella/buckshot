import { Option } from "effect";
import { AsyncData } from "foldkit";
import type { Html, HtmlBuilder } from "foldkit/html";

import { CERTAIN_TYPES, type CertainRate } from "../api.ts";
import { type Cell as CertainCell, talliesOf } from "./certain.ts";

import { noteView, pressable, termsView } from "./charts.ts";
import { effortName } from "../../arena/model-names.ts";
import { isSameTreatment } from "../../arena/same-treatment.ts";
import { baseName, CERTAIN_NAMES, costPerMove, effortLabel, fmtCount, fmtPct, fmtPoints, fmtRating, fmtSec, fmtShare, fmtUsd, isClaude, isProvisional, PROVISIONAL_BELOW, reasonedShare, reasoningPerMove } from "./data.ts";
import { type Derived, LUCK_ELO, type ModelStats, MOVE_ELO, ROUND_ELO } from "./derived.ts";
import { drillView } from "./drill.ts";
import { itemIconOf } from "./items.ts";
import { type Lazy, Message, type Model } from "./model.ts";
import { ANCHOR, INTERVAL_PERCENT, matchWinVsAnchor, type Rating } from "./ratings.ts";

type H = HtmlBuilder<Message>;

// One table, ranked by the headline rating (derived.ts), in tiers of configs the data cannot tell apart.

const ratingView = (h: H, elo: Rating | undefined): ReadonlyArray<Html | string> =>
  elo === undefined ? ["–"] : [`${elo.rating >= 0 ? "+" : ""}${elo.rating.toFixed(0)} `, ...(elo.interval === null ? [] : [h.span([h.Class("pm")], [`[${elo.interval.lo.toFixed(0)}, ${elo.interval.hi.toFixed(0)}]`])])];

interface Detail {
  readonly label: string;
  readonly note: string;
  readonly content: ReadonlyArray<Html | string>;
}

/** How many moves a config's accuracy figures rest on. */
export const movesTitle = ({ regret }: ModelStats): string => (regret === null ? "" : `${regret.moves.toLocaleString()} moves with a real choice`);

const detailsOf = (h: H, m: ModelStats, hasRegret: boolean): ReadonlyArray<Detail> => {
  const { favorite } = m;

  return [
    { label: "wins vs own opponents", note: "", content: [h.b([], [fmtPct(m.winShare)]), " ", h.span([h.Class("pm")], [`${m.win.k.toFixed(m.win.k % 1 ? 1 : 0)}/${m.win.n}`])] },
    { label: "round wins", note: "", content: [fmtPct(m.roundShare)] },
    { label: "cash share", note: "", content: [fmtPct(m.potShare)] },
    ...(hasRegret
      ? [
          { label: "accuracy", note: movesTitle(m), content: [m.regret === null ? "–" : m.regret.accuracy.toFixed(1)] },
          { label: "p99 points lost", note: movesTitle(m), content: [m.regret === null ? "–" : fmtPoints(m.regret.p99Lost)] },
        ]
      : []),
    { label: "cost / move", note: "", content: [fmtUsd(costPerMove(m))] },
    { label: "time / move", note: "", content: [fmtSec(m.scoredMoves > 0 ? m.scoredLatency / m.scoredMoves : null)] },
    { label: "output tok / match", note: "", content: [fmtCount(m.avgOut)] },
    { label: "fav", note: favorite === null ? "" : `${favorite.k} of ${favorite.n} legal moves`, content: favorite === null ? ["–"] : [itemIconOf(h, favorite.item), `${favorite.item} `, h.span([h.Class("pm")], [fmtPct(favorite.rate)])] },
  ];
};

interface EloScale {
  readonly from: number;
  readonly to: number;
  readonly ticks: ReadonlyArray<number>;
}

/** Zoomed to the top tiers, where configs overlap; weaker configs clip at the left edge (◂). */
const ZOOM_TIERS = 3;
const TICK = 25;

const eloScaleOf = (ratings: ReadonlyMap<string, Rating>, ranks: ReadonlyMap<string, number>): EloScale => {
  const ends = [...ratings].filter(([key, { tier }]) => ranks.has(key) && tier !== null && tier <= ZOOM_TIERS).flatMap(([, { rating, interval }]) => [rating, interval?.lo ?? rating, interval?.hi ?? rating]);
  const from = Math.floor(Math.min(...ends) / TICK) * TICK;
  const to = Math.ceil(Math.max(...ends) / TICK) * TICK;

  return { from, to, ticks: Array.from({ length: (to - from) / TICK + 1 }, (_, index) => from + index * TICK).filter((tick) => tick % 50 === 0) };
};

const percentOf = ({ from, to }: EloScale, elo: number): number => Math.min(100, Math.max(0, ((elo - from) / (to - from)) * 100));

const ratingText = ({ rating, interval }: Rating): string => `${fmtRating(rating)}${interval === null ? "" : `, ${INTERVAL_PERCENT} interval ${fmtRating(interval.lo)} to ${fmtRating(interval.hi)}`}`;

const eloBarView = (h: H, scale: EloScale, m: ModelStats, elo: Rating | undefined): Html => {
  if (elo === undefined) return h.empty;

  const whisker = elo.interval === null ? null : { left: percentOf(scale, elo.interval.lo), right: percentOf(scale, elo.interval.hi), clippedLow: elo.interval.lo < scale.from, clippedHigh: elo.interval.hi > scale.to };

  return h.div(
    [h.Class("track")],
    [
      h.div([h.Class("zero"), h.Style({ left: `${percentOf(scale, 0)}%` })], []),
      ...(whisker === null ? [] : [h.div([h.Class(`whisk${whisker.clippedLow ? " clip-lo" : ""}${whisker.clippedHigh ? " clip-hi" : ""}`), h.Style({ left: `${whisker.left}%`, width: `${whisker.right - whisker.left}%` })], [])]),
      h.div([h.Class(`mark ${isClaude(m.model) ? "a" : "o"}`), h.Style({ left: `${percentOf(scale, elo.rating)}%`, background: m.color })], []),
      noteView(h, ratingText(elo)),
    ],
  );
};

/** Below this many reasoning tokens per move a config reasons not at all. */
const NO_REASONING = 0.5;

/** Whether the reasoning measured disagrees with the effort asked for: reasoning with effort off, or none with effort on. */
const isEffortMismatch = (m: ModelStats): boolean => {
  const reasoning = reasoningPerMove(m);

  return reasoning !== null && m.effort !== "" && !isSameTreatment(m.effort) && (m.effort === "off") === reasoning >= NO_REASONING;
};

/** A config whose provider reported no reasoning token count on some of its calls: those calls and the share they are of its calls. */
const unreportedOf = ({ scoredUnreported, scoredReturned }: ModelStats): string | null =>
  scoredUnreported === 0 ? null : `${scoredUnreported.toLocaleString()} of ${scoredReturned.toLocaleString()} calls (${fmtShare(scoredUnreported / scoredReturned)})`;

/** A reasoning cell's mark for a config whose provider did not report every reasoning token count. */
const unreportedMark = (h: H, m: ModelStats): ReadonlyArray<Html | string> => {
  const unreported = unreportedOf(m);

  return unreported === null ? [] : [h.span([h.AriaHidden(true)], [" †"]), noteView(h, `no reasoning count reported on ${unreported}`)];
};

/** A config's dot, model name and effort; an effort the measured reasoning disagrees with is marked as requested. */
const nameView = (h: H, m: ModelStats): ReadonlyArray<Html | string> => {
  const effort = effortLabel(m.model, m.effort);
  const mismatch = isEffortMismatch(m);

  return [
    h.span([h.Class(`dot ${isClaude(m.model) ? "a" : "o"}`), h.Style({ background: m.color })], []),
    `${baseName(m.model)} `,
    ...(effort === "" ? [] : [h.span([h.Class("eff")], [`[${effort}${mismatch ? " (requested)" : ""}]`, ...(mismatch ? [noteView(h, `requested ${effortName(m.effort)}, measured ${fmtCount(reasoningPerMove(m))} reasoning tokens per move`)] : [])])]),
  ];
};

const matchWinView = (elo: Rating | undefined): string => (elo === undefined ? "–" : fmtPct(matchWinVsAnchor(elo.rating)));

const rowView = (h: H, m: ModelStats, elo: Rating | undefined, hasLuck: boolean, hasMoveElo: boolean, scale: EloScale, details: ReadonlyArray<Detail>, isOpen: boolean, startsTier: boolean): Html =>
  h.keyed("tr")(
    m.key,
    [h.Class(`row ${isOpen ? "sel" : ""} ${isProvisional(m) ? "provisional" : ""} ${startsTier ? "tierstart" : ""}`), h.AriaExpanded(isOpen), ...pressable(h, Message.ClickedLeaderboardRow({ id: m.key }))],
    [
      h.td([], [h.span([h.Class("rk")], [elo?.tier == null ? "–" : String(elo.tier)]), ...nameView(h, m)]),
      h.td([h.DataAttribute("label", hasLuck ? "luck-adjusted" : "round elo")], ratingView(h, elo)),
      h.td([h.Class("barcol")], [eloBarView(h, scale, m, elo)]),
      h.td([h.DataAttribute("label", "match win vs engine")], [matchWinView(elo)]),
      ...(hasLuck ? [h.td([h.DataAttribute("label", "round elo")], ratingView(h, m.rating ?? undefined))] : []),
      ...(hasMoveElo ? [h.td([h.DataAttribute("label", "play and move quality")], ratingView(h, m.moveRating ?? undefined))] : []),
      h.td([h.DataAttribute("label", "matches")], [m.scored.toLocaleString(), noteView(h, `${m.win.blocks} seed blocks`)]),
      h.td([h.DataAttribute("label", "reasoning tok / move")], [fmtCount(reasoningPerMove(m)), ...unreportedMark(h, m)]),
      h.td([h.DataAttribute("label", "moves with reasoning")], [fmtShareOrDash(reasonedShare(m)), ...unreportedMark(h, m)]),
      h.td([h.DataAttribute("label", "cost / match")], [fmtUsd(m.avgCost)]),
      ...details.map(({ label, note, content }) => h.td([h.Class("detail"), h.DataAttribute("label", label), ], [...content, ...(note === "" ? [] : [noteView(h, note)])])),
    ],
  );

const detailsView = (h: H, details: ReadonlyArray<Detail>): Html =>
  h.dl([h.Class("drillstats")], details.flatMap(({ label, note, content }) => [h.dt([], [label]), h.dd([], [...content, ...(note === "" ? [] : [" ", h.span([h.Class("pm")], [note])])])]));

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

const PROVISIONAL_NOTE = `A faded row with a – for its tier is provisional: it has fewer than ${PROVISIONAL_BELOW} scored matches and no rank.`;

const PROVISIONAL_NOTE_ACCURACY = `A faded row is provisional: it has fewer than ${PROVISIONAL_BELOW} scored matches.`;

const MATCH_WIN = "Match win vs engine";

const REASONING = "Reasoning tok / move";

const REASONED = "Moves with reasoning";

const fmtShareOrDash = (share: number | null): string => (share === null ? "–" : fmtShare(share));

const headersOf = (ratingName: string, hasRegret: boolean, hasLuck: boolean, hasMoveElo: boolean): ReadonlyArray<string> => [
  "Model",
  ratingName,
  "",
  MATCH_WIN,
  ...(hasLuck ? [ROUND_ELO] : []),
  ...(hasMoveElo ? [MOVE_ELO] : []),
  "Matches",
  REASONING,
  REASONED,
  "Cost / match",
  "Match wins vs own opponents",
  "Round wins",
  "Cash share",
  ...(hasRegret ? ["Accuracy", "p99 points lost"] : []),
  "Cost / move",
  "Time / move",
  "Output tok / match",
  "Favorite item",
];

export const ACCURACY_TITLE = "Lichess's accuracy formula, applied to points of round win chance. Each move is scored by how much it gave up compared with the minimax player's best move. A game's score combines a volatility-weighted mean and a harmonic mean, and a config's accuracy averages its matches. Higher is better; 100 is perfect.";

export const P99_TITLE = "The points of round win chance given up by the 99th-percentile move. One move in a hundred gave up at least this much.";

const HEADER_TITLES = new Map([
  [ROUND_ELO, `One Bradley-Terry rating fitted over every match on round win share, with the depth-7 search engine at 0. The interval is a ${INTERVAL_PERCENT} bootstrap interval over seed blocks.`],
  [LUCK_ELO, "Round Elo with each round's result corrected for luck: the shots, loads, first seat, item deals and the shells that items show. The correction (AIVAT) estimates the same strengths with less noise."],
  [MOVE_ELO, "The headline rating combined with the rating that points lost per move predict, as the move scorer counts them. A config with few matches leans on its moves."],
  [MATCH_WIN, "The chance of winning a match against the depth-7 search engine (Engine/7/2000000/sampled, rated 0), worked out from the rating as the chance of two round wins out of three."],
  [REASONING, "Reasoning tokens the provider reported per model move, over scored matches."],
  [REASONED, "The share of scored model moves whose calls billed any reasoning tokens. With a small average per move, a high share means a little reasoning on every move, and a low share means more reasoning on a few."],
  ["Cash share", "A config's cash divided by all the cash in the match, averaged over scored matches."],
  ["Round wins", "The rounds a config won divided by the rounds it played."],
  ["Accuracy", ACCURACY_TITLE],
  ["p99 points lost", P99_TITLE],
]);

const headerView = (h: H, label: string): Html => {
  return h.th(label === "" ? [h.Class("barcol")] : label === ROUND_ELO || label === LUCK_ELO || label === MOVE_ELO ? [h.Class("rating")] : [], [label]);
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
  const hasMoveElo = every.some(({ moveRating }) => moveRating !== null);
  const headers = headersOf(ratingName, hasRegret, hasLuck, hasMoveElo);
  const barColumn = headers.indexOf("");
  const configs = inRankOrder(stats, ranks, ratings);
  const scale = eloScaleOf(ratings, ranks);
  const tierOf = (m: ModelStats | undefined) => (m === undefined ? undefined : ratings.get(m.key)?.tier);
  const sameTreatment = configs.filter(({ effort }) => isSameTreatment(effort));
  const unreported = configs.flatMap((m) => [unreportedOf(m)].flatMap((calls) => (calls === null ? [] : [`${m.label} on ${calls}`])));
  const zero = ratings.get(ANCHOR)?.interval ?? null;

  return h.div(
    [h.Class("lb")],
    [
      h.div([h.Class("lbbar")], [h.h2([], ["Leaderboard"])]),
      h.p([h.Class("sub")], [
        `${hasLuck ? `${LUCK_ELO} is Round Elo with the luck taken out of each round: its shots, loads, first seat, item deals and the shells that items show. ` : ""}Round Elo is one Bradley-Terry rating fitted over every match on round win share. The depth-7 search engine (Engine/7/2000000/sampled) is fixed at 0, so adding a config does not move the others. The dot is the rating, and the line is its ${INTERVAL_PERCENT} interval over seed blocks: about one in ten true values falls outside it. The vertical line is the depth-7 engine at 0. Configs whose lines do not overlap differ clearly. The number before a config is its tier, and the data cannot put the configs within one tier in order.${zero === null ? "" : ` The 0 is uncertain too: measured against the mean of all configs, the engine's own ${INTERVAL_PERCENT} interval is ${Math.round(zero.lo)} to +${Math.round(zero.hi)}. The other intervals are measured the same way, so they leave out the engine's noise.`} Match wins count only a config's own opponents.`,
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
                    rowView(h, m, ratings.get(m.key), hasLuck, hasMoveElo, scale, details, isOpen, index > 0 && tierOf(m) !== tierOf(configs[index - 1])),
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
      termsView(h, "What the columns mean", headers.flatMap((label) => (HEADER_TITLES.has(label) ? [[label, HEADER_TITLES.get(label) ?? ""] as const] : []))),
      ...[
        ...(sameTreatment.length === 0 ? [] : [`${sameTreatment.map(({ label }) => label).join(", ")}: each of these merges two requested efforts into one config. The two ran the same and billed the same reasoning tokens per call.`]),
        ...(unreported.length === 0 ? [] : [`† The provider reported no reasoning token count on some calls: ${unreported.join("; ")}. Reasoning figures count only the calls that reported one.`]),
        ...(configs.some(isProvisional) ? [PROVISIONAL_NOTE] : []),
        ...(configs.some(isEffortMismatch) ? ["An effort marked (requested) does not match the reasoning that was measured: the config reasoned at effort none, or did not reason at another effort."] : []),
      ].map((note) => h.p([h.Class("sub")], [note])),
    ],
  );
};

const ACCURACY_HEADERS: ReadonlyArray<readonly [string, string]> = [
  ["Model", ""],
  ["Avg points lost", "The average points of round win chance a move gave up compared with the minimax player's best move. Lower is better."],
  ...CERTAIN_TYPES.map((type) => [CERTAIN_NAMES[type], "Of the decisions where this mistake was a legal move, the share where the player made it. The player's own information proves this mistake worse, so no evaluator is needed."] as const),
  ["Accuracy", ACCURACY_TITLE],
  ["p99 points lost", P99_TITLE],
  ["Best moves", "Moves as good as the minimax player's best"],
  ["Inaccuracies / 100", "Moves per 100 that gave up 5 to 10 points of round win chance (lichess's inaccuracy, 0.1 of its winning chances)"],
  ["Mistakes / 100", "Moves per 100 that gave up 10 to 15 points (lichess's mistake, 0.2)"],
  ["Blunders / 100", "Moves per 100 that gave up 15 points or more (lichess's blunder, 0.3)"],
  ["Moves", "Moves with a real choice in the config's scored matches. Decisions where every move is within a point are left out."],
];

/** Configs with a scored move, fewest points lost first. */
export const inPointsLostOrder = (stats: ReadonlyArray<ModelStats>): ReadonlyArray<ModelStats> =>
  stats.filter(({ regret }) => regret !== null).toSorted((left, right) => (left.regret?.meanLost ?? 0) - (right.regret?.meanLost ?? 0) || left.label.localeCompare(right.label));

const certainCellView = (h: H, cell: CertainCell | undefined): Html =>
  cell === undefined || cell.opportunities === 0
    ? h.td([h.DataAttribute("label", cell === undefined ? "" : CERTAIN_NAMES[cell.type])], ["–"])
    : h.td([h.DataAttribute("label", CERTAIN_NAMES[cell.type])], [fmtShare(cell.mistakes / cell.opportunities), noteView(h, `${cell.mistakes.toLocaleString()} of ${cell.opportunities.toLocaleString()}`)]);

const accuracyRowView = (h: H, m: ModelStats, rank: number, certain: ReadonlyArray<CertainCell> | undefined): Html => {
  const { regret } = m;
  const cell = (label: string, text: string | undefined) => h.td([h.DataAttribute("label", label), ], [text ?? "–", ...(label === "avg points lost" && movesTitle(m) !== "" ? [noteView(h, movesTitle(m))] : [])]);

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
        "Points lost is the round win chance each move gave up compared with the minimax player's best move. Certain mistakes are shots that the player's own information proves worse; they need no evaluator. Accuracy applies lichess's formula, and its cut-offs for inaccuracies, mistakes and blunders, to the points lost. Decisions where every move is within a point are left out.",
      ]),
      configs.length === 0
        ? h.div([h.Class("empty")], ["No config in this filter has a scored move."])
        : h.div(
            [h.Class("card")],
            [
              h.table(
                [h.Class("lbt rows")],
                [
                  h.thead([], [h.tr([], ACCURACY_HEADERS.map(([label]) => h.th([], [label])))]),
                  h.tbody([], configs.map((m, index) => accuracyRowView(h, m, index + 1, certainRows.get(m.key)))),
                ],
              ),
            ],
          ),
      termsView(h, "What the columns mean", ACCURACY_HEADERS.filter(([, text]) => text !== "")),
      ...(configs.some(isProvisional) ? [h.p([h.Class("sub")], [PROVISIONAL_NOTE_ACCURACY])] : []),
    ],
  );
};
