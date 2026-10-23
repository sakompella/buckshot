import { Option } from "effect";
import type { Html, HtmlBuilder } from "foldkit/html";

import { type Decisions, ITEMS, type Pattern, patternBit } from "../api.ts";
import { anchorId, rankingView, switchView, tipView, toggleView } from "./charts.ts";
import { baseName, baseOrder, fmtPct, fmtRating, fmtTime, fmtUsd, isClaude, keyOf, type MatchRow, type SeatFull, unique } from "./data.ts";
import { type Derived, memoLast } from "./derived.ts";
import { itemIconOf } from "./items.ts";
import { type HeatMode, Message, type Model, type Ranking } from "./model.ts";

type H = HtmlBuilder<Message>;

// The breakdown heatmap, after RuneBench: one row per config, columns by mode,
// each cell shaded by its share of the column's best visible value.

export interface HeatRow {
  readonly key: string;
  readonly model: string;
  readonly label: string;
  readonly color: string;
  readonly rating: number;
  /** The place by win share, 1 first. */
  readonly rank: number;
  readonly cost: number;
}

/** Higher is better on either ranking. */
const scoreOf = (row: HeatRow, ranking: Ranking): number => (ranking === "elo" ? row.rating : -row.rank);

interface HeatCol {
  readonly id: string;
  readonly label: string;
  readonly title: string;
  /** The item a column counts, drawn above its label. */
  readonly item?: string;
}

interface HeatCell {
  readonly value: number;
  readonly text: string;
  readonly tip: string;
  readonly isFaint: boolean;
  readonly isRinged: boolean;
  readonly maybeClick: Option.Option<Message>;
}

const cellOf = (value: number, text: string, tip: string, isFaint = false, isRinged = false, maybeClick: Option.Option<Message> = Option.none()): HeatCell => ({ value, text, tip, isFaint, isRinged, maybeClick });

const TIERS: ReadonlyArray<readonly [number, string, string]> = [
  [0.9, "#e8e8e8", "#000"],
  [0.75, "#9a9a9a", "#000"],
  [0.5, "#5a5a5a", "#f2f2f2"],
  [0.25, "#3a3a3a", "#d6d6d6"],
  [0, "#262626", "#a8a8a8"],
];

const EMPTY_SHADE = { background: "#101010", color: "#555" };

const tierOf = (value: number, best: number) => {
  if (value <= 0 || best <= 0) return EMPTY_SHADE;

  const [, background, color] = TIERS.find(([share]) => value / best >= share) ?? ["", "#262626", "#a8a8a8"];

  return { background, color };
};

// Cost is not a score, so it gets its own log-scaled green ramp: dark is cheap, bright is expensive.
const COST_RAMP = ["#0f1a14", "#1d4a33", "#2f7d52", "#5cc488"].map((hex) => [1, 3, 5].map((at) => Number.parseInt(hex.slice(at, at + 2), 16)));

const costShade = (share: number) => {
  const at = Math.min(1, Math.max(0, share)) * (COST_RAMP.length - 1);
  const index = Math.min(COST_RAMP.length - 2, Math.floor(at));
  const from = COST_RAMP[index] ?? [];
  const to = COST_RAMP[index + 1] ?? [];
  const rgb = from.map((channel, k) => Math.round(channel + ((to[k] ?? channel) - channel) * (at - index)));

  return { background: `rgb(${rgb.join(",")})`, color: share >= 0.8 ? "#000" : "#e8e8e8" };
};

const ITEM_SHORT = ["glass", "phone", "saw", "beer", "cigs", "inverter", "jammer", "adrenaline"];

const JAMMER = ITEMS.indexOf("jammer");

const MIN_N = 10;

const MIN_LEGAL = 30;

// The known-shell patterns are mistakes; the odds patterns are descriptive.
const CHOICES: ReadonlyArray<readonly [Pattern, string, string]> = [
  ["knownBlankOpp", "blank → opp", "Known blank (glass or phone), shoots the opponent and gives up the free turn"],
  ["glassBlankOpp", "glass blank → opp", "Glass showed blank, shoots the opponent"],
  ["knownLiveSelf", "live → self", "Known live (glass or phone), shoots itself"],
  ["countBlankOpp", "deduced blank → opp", "Only blank can be chambered, shoots the opponent"],
  ["countLiveSelf", "deduced live → self", "Only live can be chambered, shoots itself"],
  ["sawSelf", "saw → self", "Saw on and the shell not known blank, shoots itself"],
  ["invertLiveOpp", "invert live → opp", "Inverted a known live shell, then shoots the opponent"],
  ["glassKnown", "glass on known", "Uses the glass on an already known shell"],
  ["cigsFull", "cigs at full", "Cigarettes at full health"],
  ["oddsLiveSelf", "odds live → self", "P(live) > ½, shoots itself"],
  ["oddsBlankOpp", "odds blank → opp", "P(live) < ½, shoots the opponent"],
  ["tieSelf", "even → self", "P(live) = ½, shoots itself"],
];

interface StyleColumn {
  readonly id: string;
  readonly label: string;
  readonly title: string;
  readonly isShare: boolean;
  readonly valueOf: (tally: Tally) => number;
}

const rate = (k: number, n: number) => (n > 0 ? k / n : 0);

const STYLE: ReadonlyArray<StyleColumn> = [
  { id: "atOpp", label: "at opponent", title: "share of its shots aimed at the opponent", isShare: true, valueOf: (tally) => rate(tally.atOpp, tally.shots) },
  { id: "items", label: "item moves", title: "share of its moves that use an item", isShare: true, valueOf: (tally) => rate(tally.items, tally.moves) },
  { id: "jams", label: "jams / match", title: "jams per match", isShare: false, valueOf: (tally) => tally.jams / tally.seats.size },
  { id: "steals", label: "steals / match", title: "adrenaline steals per match", isShare: false, valueOf: (tally) => tally.steals / tally.seats.size },
  { id: "perShot", label: "moves / shot", title: "model-chosen moves per shot fired", isShare: false, valueOf: (tally) => rate(tally.moves, tally.shots) },
];

const MODES: ReadonlyArray<readonly [HeatMode, string]> = [
  ["opp", "Win share vs opponent"],
  ["items", "Item use when legal"],
  ["choices", "Choice patterns"],
  ["style", "Play style"],
];

interface Tally {
  readonly use: Array<[number, number]>;
  readonly pattern: Array<[number, number]>;
  shots: number;
  atOpp: number;
  moves: number;
  items: number;
  jams: number;
  steals: number;
  readonly seats: Set<number>;
}

const CHOICE_BITS = CHOICES.map(([pattern]) => patternBit(pattern));

const emptyTally = (): Tally => ({ use: ITEMS.map(() => [0, 0]), pattern: CHOICES.map(() => [0, 0]), shots: 0, atOpp: 0, moves: 0, items: 0, jams: 0, steals: 0, seats: new Set<number>() });

/** Per cohort and config, as ModelStats ids. A filter keeps or drops whole cohort configs, so these are counted once. */
const cohortTallies = memoLast((decisions: Decisions, seats: ReadonlyArray<SeatFull>): ReadonlyMap<string, Tally> => {
  const out = new Map<string, Tally>();

  const tallyOfSeat = seats.map((seat) => {
    const id = `${seat.cohort}||${keyOf(seat)}`;
    const tally = out.get(id) ?? emptyTally();

    out.set(id, tally);

    return tally;
  });

  for (let move = 0; move < decisions.seat.length; move++) {
    const seatIndex = decisions.seat[move] ?? -1;
    const tally = tallyOfSeat[seatIndex];

    if (tally === undefined) continue;

    const legalUse = decisions.legalUse[move] ?? 0;
    const chances = decisions.opp[move] ?? 0;
    const taken = decisions.pick[move] ?? 0;
    const used = decisions.useItem[move] ?? -1;
    const stolen = decisions.stealItem[move] ?? -1;
    const shot = decisions.shot[move] ?? 0;

    for (let index = 0; index < tally.use.length; index++) {
      const counts = tally.use[index];

      if (counts && legalUse & (1 << index)) {
        counts[1]++;

        if (used === index) counts[0]++;
      }
    }

    for (let index = 0; index < CHOICE_BITS.length; index++) {
      const counts = tally.pattern[index];
      const bit = CHOICE_BITS[index] ?? 0;

      if (counts && chances & bit) {
        counts[1]++;

        if (taken & bit) counts[0]++;
      }
    }

    tally.moves++;
    tally.seats.add(seatIndex);

    if (shot > 0) {
      tally.shots++;

      if (shot === 1) tally.atOpp++;
    }

    if (used >= 0) tally.items++;

    if (used === JAMMER || stolen === JAMMER) tally.jams++;

    if (stolen >= 0) tally.steals++;
  }

  return out;
});

const addCounts = (into: Array<[number, number]>, counts: ReadonlyArray<readonly [number, number]>) =>
  counts.forEach(([k, n], index) => {
    const total = into[index];

    if (total) {
      total[0] += k;
      total[1] += n;
    }
  });

/** Per config, over the cohorts the filter keeps. */
const tallies = memoLast((derived: Derived): ReadonlyMap<string, Tally> => {
  const perCohort = cohortTallies(derived.decisions, derived.seats);
  const out = new Map<string, Tally>();

  for (const m of derived.byCohort) {
    const part = perCohort.get(m.id);

    if (part === undefined || part.moves === 0) continue;

    const tally = out.get(m.key) ?? emptyTally();

    out.set(m.key, tally);
    addCounts(tally.use, part.use);
    addCounts(tally.pattern, part.pattern);
    tally.shots += part.shots;
    tally.atOpp += part.atOpp;
    tally.moves += part.moves;
    tally.items += part.items;
    tally.jams += part.jams;
    tally.steals += part.steals;

    for (const seat of part.seats) tally.seats.add(seat);
  }

  return out;
});

/** Each config's win share against each opponent model: hits and games. */
const versus = memoLast((matches: ReadonlyArray<MatchRow>): ReadonlyMap<string, ReadonlyMap<string, readonly [number, number]>> => {
  const out = new Map<string, Map<string, [number, number]>>();

  for (const match of matches) {
    const [first, second] = match.seats;

    if (match.status !== "completed" || match.seats.length !== 2 || first === undefined || second === undefined) continue;

    for (const [seat, opponent] of [
      [first, second],
      [second, first],
    ] as const) {
      const row = out.get(keyOf(seat)) ?? new Map<string, [number, number]>();
      const counts = row.get(baseName(opponent.model)) ?? [0, 0];

      counts[0] += seat.winShare ?? 0;
      counts[1]++;
      row.set(baseName(opponent.model), counts);
      out.set(keyOf(seat), row);
    }
  }

  return out;
});

const opponentColumns = memoLast((matches: ReadonlyArray<MatchRow>): ReadonlyArray<HeatCol> =>
  unique(
    unique(matches.flatMap((match) => match.seats.map(({ model }) => model)))
      .toSorted((left, right) => baseOrder(left) - baseOrder(right))
      .map((model) => baseName(model)),
  ).map((name) => ({ id: name, label: name.replace(/^GPT-[\d.]+ /, ""), title: name })),
);

const favoriteOf = (tally: Tally): number => {
  let best = -1;

  tally.use.forEach(([k, n], index) => {
    const [bestK, bestN] = tally.use[best] ?? [0, 0];

    if (n >= MIN_LEGAL && (best < 0 || rate(k, n) > rate(bestK, bestN))) best = index;
  });

  return best;
};

const columnsOf = (mode: HeatMode, matches: ReadonlyArray<MatchRow>): ReadonlyArray<HeatCol> => {
  if (mode === "opp") return opponentColumns(matches);

  if (mode === "items") return ITEMS.map((item, index) => ({ id: String(index), label: ITEM_SHORT[index] ?? item, title: item, item }));

  return mode === "choices" ? CHOICES.map(([pattern, label, title]) => ({ id: String(patternBit(pattern)), label, title })) : STYLE.map(({ id, label, title }) => ({ id, label, title }));
};

const cellAt = (derived: Derived, mode: HeatMode, row: HeatRow, col: string): HeatCell | null => {
  if (mode === "opp") {
    const counts = versus(derived.matches).get(row.key)?.get(col);

    return counts === undefined ? null : cellOf(counts[0] / counts[1], fmtPct(counts[0] / counts[1]), `vs ${col}: ${fmtPct(counts[0] / counts[1])} of ${counts[1]}`, counts[1] < MIN_N);
  }

  const tally = tallies(derived).get(row.key);

  if (tally === undefined) return null;

  if (mode === "items") {
    const index = Number(col);
    const [k, n] = tally.use[index] ?? [0, 0];

    return n === 0 ? null : cellOf(k / n, fmtPct(k / n), `${ITEMS[index] ?? ""}: used ${k.toLocaleString()} of ${n.toLocaleString()} moves where legal`, n < MIN_LEGAL, favoriteOf(tally) === index);
  }

  if (mode === "choices") {
    const bit = Number(col);
    const index = CHOICES.findIndex(([pattern]) => patternBit(pattern) === bit);
    const [k, n] = tally.pattern[index] ?? [0, 0];
    const title = CHOICES[index]?.[1] ?? "";
    const maybeClick = k > 0 ? Option.some(Message.ClickedPatternCell({ key: row.key, bit, title: `${row.label} · ${title}` })) : Option.none();

    return n === 0 ? null : cellOf(k / n, fmtPct(k / n), `${title}: ${k} of ${n}`, n < MIN_N, false, maybeClick);
  }

  const column = STYLE.find(({ id }) => id === col);

  if (column === undefined) return null;

  const value = column.valueOf(tally);
  const text = column.isShare ? fmtPct(value) : value.toFixed(1);

  return cellOf(value, text, `${column.title}: ${text} · ${tally.seats.size} player-matches`);
};

export const heatRowsOf = memoLast((derived: Derived): ReadonlyArray<HeatRow> =>
  derived.pooled.flatMap((m) => {
    const rating = derived.ratings.get(m.key);
    const rank = derived.ranks.get(m.key);

    return rating === undefined || rank === undefined ? [] : [{ key: m.key, model: m.model, label: m.label, color: m.color, rating, rank, cost: m.avgCost }];
  }),
);

/** `rows` come best first by the ranking, which is the "rating" sort. */
const sortedRows = (rows: ReadonlyArray<HeatRow>, sort: string, ranking: Ranking, valueOf: (row: HeatRow) => number): ReadonlyArray<HeatRow> => {
  if (sort === "rating") return rows;

  if (sort === "model") return rows.toSorted((left, right) => left.label.localeCompare(right.label));

  if (sort === "cost") return rows.toSorted((left, right) => (left.cost || Infinity) - (right.cost || Infinity));

  return rows.toSorted((left, right) => valueOf(right) - valueOf(left) || scoreOf(right, ranking) - scoreOf(left, ranking));
};

const heatmapView = (h: H, derived: Derived, heat: Model["heat"], ranking: Ranking): Html => {
  const rows = heatRowsOf(derived);
  const byRating = rows.toSorted((left, right) => scoreOf(right, ranking) - scoreOf(left, ranking));
  // The best row per model keeps each model's best effort by the ranking.
  const shown = heat.isBestOnly ? byRating.filter((row, index) => byRating.findIndex((other) => other.model === row.model) === index) : byRating;
  const columns = columnsOf(heat.mode, derived.matches);
  const cells = new Map(shown.map((row) => [row.key, new Map(columns.map((col) => [col.id, cellAt(derived, heat.mode, row, col.id)]))]));
  const cellOfRow = (row: HeatRow, col: string) => cells.get(row.key)?.get(col) ?? null;
  const best = new Map(columns.map((col) => [col.id, Math.max(0, ...shown.map((row) => cellOfRow(row, col.id)?.value ?? 0))]));
  const logs = shown.filter((row) => row.cost > 0).map((row) => Math.log(row.cost));
  const low = Math.min(...logs);
  const high = Math.max(...logs);
  const sorted = sortedRows(shown, heat.sort, ranking, (row) => cellOfRow(row, heat.sort)?.value ?? -1);
  const hiddenRows = rows.length - new Set(rows.map((row) => row.model)).size;

  const header = (id: string, label: string, title: string, extra = "", item?: string) =>
    h.th(
      [h.Title(title), h.Class(`${extra} sortable ${heat.sort === id && id !== "rating" ? "sorted" : ""}`), h.OnClick(Message.ClickedHeatColumn({ column: id }))],
      item === undefined ? [label] : [itemIconOf(h, item), label],
    );

  const tip = Option.flatMap(heat.maybeTip, ({ row, col }) => {
    const shownRow = shown.find((candidate) => candidate.key === row);
    const cell = shownRow === undefined ? null : cellOfRow(shownRow, col);

    return shownRow === undefined || cell === null ? Option.none() : Option.some(tipView(h, anchorId("cell", row, col), [h.b([], [shownRow.label]), h.br([]), cell.tip]));
  });

  return h.div(
    [],
    [
      h.div(
        [h.Class("ctl heatctl")],
        [
          toggleView(h, heat.mode, MODES, (mode) => Message.SelectedHeatMode({ mode })),
          rankingView(h, ranking),
          hiddenRows > 0 ? switchView(h, heat.isBestOnly, `best row per model${heat.isBestOnly ? ` (${hiddenRows} effort rows hidden)` : ""}`, Message.ToggledBestOnly()) : h.empty,
        ],
      ),
      h.div(
        [h.Class("heatscroll")],
        [
          h.table(
            [h.Class("heat")],
            [
              h.thead(
                [],
                [
                  h.tr(
                    [],
                    [
                      header("model", "Model", "", "left"),
                      ...columns.map((col) => header(col.id, col.label, col.title, "", col.item)),
                      ranking === "elo"
                        ? header("rating", "Elo (approx.)", "cross-model Bradley-Terry; effort rows add their offset from medium within their own sweep")
                        : header("rating", "Rank", "place by observed win share among all the cohort's configs, before the filters; ties go to the higher Elo"),
                      header("cost", "$/match", "avg list-price cost per player per scored match"),
                    ],
                  ),
                ],
              ),
              h.tbody(
                [],
                sorted.map((row) =>
                  h.keyed("tr")(
                    row.key,
                    [],
                    [
                      h.td([h.Class("left")], [h.span([h.Class(`dot ${isClaude(row.model) ? "a" : "o"}`), h.Style({ background: row.color })], []), h.span([h.Style({ color: row.color })], [heat.isBestOnly ? baseName(row.model) : row.label])]),
                      ...columns.map((col) => {
                        const cell = cellOfRow(row, col.id);

                        if (cell === null) return h.td([h.Class("cellv none")], ["–"]);

                        const shade = tierOf(cell.value, best.get(col.id) ?? 0);

                        return h.td(
                          [
                            h.Id(anchorId("cell", row.key, col.id)),
                            h.Class(`cellv ${Option.isSome(cell.maybeClick) ? "click" : ""} ${cell.isRinged ? "ring" : ""}`),
                            h.Style({ ...shade, opacity: cell.isFaint ? "0.45" : "1" }),
                            h.OnMouseEnter(Message.HoveredCell({ row: row.key, col: col.id })),
                            h.OnMouseLeave(Message.LeftCell()),
                            ...Option.toArray(Option.map(cell.maybeClick, (message) => h.OnClick(message))),
                          ],
                          [cell.text],
                        );
                      }),
                      h.td([h.Class("total")], [ranking === "elo" ? fmtRating(row.rating) : String(row.rank)]),
                      h.td([h.Class("cellv"), h.Style(row.cost > 0 ? costShade((Math.log(row.cost) - low) / (high - low || 1)) : EMPTY_SHADE)], [row.cost > 0 ? fmtUsd(row.cost) : "–"]),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
      Option.getOrElse(tip, () => h.empty),
    ],
  );
};

const FLAGGED_LIMIT = 300;

const flaggedMoves = memoLast((derived: Derived, key: string, bit: number): ReadonlyArray<number> => {
  const { decisions, seats, keep } = derived;
  const out: Array<number> = [];

  for (let move = 0; move < decisions.seat.length && out.length < FLAGGED_LIMIT; move++) {
    const seatIndex = decisions.seat[move] ?? -1;
    const seat = seats[seatIndex];

    if (seat !== undefined && keep[seatIndex] === true && keyOf(seat) === key && (decisions.opp[move] ?? 0) & bit && (decisions.pick[move] ?? 0) & bit) out.push(move);
  }

  return out;
});

const flaggedView = (h: H, derived: Derived, flagged: { readonly key: string; readonly bit: number; readonly title: string }): Html => {
  const moves = flaggedMoves(derived, flagged.key, flagged.bit);

  return h.div(
    [h.Class("flagged")],
    [
      h.div(
        [h.Class("bar")],
        [
          h.b([], [flagged.title]),
          h.span([h.Class("k")], [`${moves.length}${moves.length === FLAGGED_LIMIT ? "+" : ""} moves`]),
          h.button([h.Type("button"), h.Class("chip"), h.AriaLabel("Close"), h.OnClick(Message.ClosedFlagged())], ["✕"]),
        ],
      ),
      h.table(
        [h.Class("rows")],
        [
          h.thead([], [h.tr([], [h.th([], ["Started"]), h.th([], ["Seed"]), h.th([], ["Player"]), h.th([], ["Move"])])]),
          h.tbody(
            [],
            moves.flatMap((move) => {
              const seat = derived.seats[derived.decisions.seat[move] ?? -1];

              return seat === undefined
                ? []
                : [
                    h.keyed("tr")(
                      move,
                      [h.Class("row"), h.OnClick(Message.ClickedMatch({ id: seat.matchId, maybeFocus: Option.fromUndefinedOr(derived.decisions.ord[move]) }))],
                      [
                        h.td([], [fmtTime(seat.startedAt)]),
                        h.td([h.DataAttribute("label", "seed")], [String(seat.seed)]),
                        h.td([h.DataAttribute("label", "player")], [seat.player]),
                        h.td([h.DataAttribute("label", "move")], [String(derived.decisions.moveNo[move] ?? "")]),
                      ],
                    ),
                  ];
            }),
          ),
        ],
      ),
    ],
  );
};

export const breakdownView = (h: H, derived: Derived, heat: Model["heat"], ranking: Ranking): Html =>
  h.div(
    [],
    [
      h.h2([], ["Breakdown"]),
      heatmapView(h, derived, heat, ranking),
      heat.mode === "choices" ? Option.match(heat.maybeFlagged, { onNone: () => h.empty, onSome: (flagged) => flaggedView(h, derived, flagged) }) : h.empty,
    ],
  );
