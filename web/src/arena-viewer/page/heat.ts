import { Option } from "effect";
import type { Html, HtmlBuilder } from "foldkit/html";

import { anchorId, pressable, termsView, tipView } from "./charts.ts";
import type { Pair } from "../aggregates.ts";
import { baseName, baseOrder, fmtCount, fmtPct, fmtRating, fmtUsd, isClaude, shortName, splitKey, unique } from "./data.ts";
import { type Derived, memoLast } from "./derived.ts";
import { Message, type Model } from "./model.ts";

type H = HtmlBuilder<Message>;

// The breakdown heatmap, after RuneBench: one row per config, one column per opponent model,
// each cell shaded by its win share.

export interface HeatRow {
  readonly key: string;
  readonly model: string;
  readonly label: string;
  readonly color: string;
  readonly rating: number;
  readonly cost: number;
}

interface HeatCol {
  readonly id: string;
  readonly label: string;
  readonly title: string;
}

interface HeatCell {
  readonly value: number;
  readonly text: string;
  readonly tip: string;
  readonly n: number;
}

export const FULL_N = 10;

const DARKEST = 0x26;
const BRIGHTEST = 0xe8;
const PAGE = 0x10;

export const shadeOf = (value: number, n: number) => {
  const level = Math.round(PAGE + (DARKEST + value * (BRIGHTEST - DARKEST) - PAGE) * Math.min(1, n / FULL_N));

  return { background: `rgb(${level}, ${level}, ${level})`, color: level > 0x80 ? "#000" : "#e6e6e6" };
};

/** Per config, its win shares summed and its scored matches against each opponent model. */
const versus = memoLast((pairs: ReadonlyArray<Pair>): ReadonlyMap<string, ReadonlyMap<string, readonly [number, number]>> => {
  const out = new Map<string, Map<string, [number, number]>>();

  const add = (key: string, opponent: string, wins: number, scored: number) => {
    const row = out.get(key) ?? new Map<string, [number, number]>();
    const counts = row.get(baseName(splitKey(opponent)[0])) ?? [0, 0];

    counts[0] += wins;
    counts[1] += scored;
    row.set(baseName(splitKey(opponent)[0]), counts);
    out.set(key, row);
  };

  for (const pair of pairs) {
    if (pair.scored === 0) continue;

    add(pair.first, pair.second, pair.firstWins, pair.scored);
    add(pair.second, pair.first, pair.secondWins, pair.scored);
  }

  return out;
});

const opponentColumns = memoLast((pairs: ReadonlyArray<Pair>): ReadonlyArray<HeatCol> =>
  unique(pairs.flatMap(({ first, second }) => [splitKey(first)[0], splitKey(second)[0]]))
    .toSorted((left, right) => baseOrder(left) - baseOrder(right))
    .map((model) => ({ id: baseName(model), label: shortName(model), title: baseName(model) })),
);

const cellAt = (derived: Derived, row: HeatRow, col: string): HeatCell | null => {
  const counts = versus(derived.pairs).get(row.key)?.get(col);

  return counts === undefined ? null : { value: counts[0] / counts[1], text: fmtPct(counts[0] / counts[1]), tip: `vs ${col}: ${fmtPct(counts[0] / counts[1])} of ${counts[1]} matches. The shade is at full strength from ${FULL_N} matches.`, n: counts[1] };
};

export const heatRowsOf = memoLast((derived: Derived): ReadonlyArray<HeatRow> =>
  derived.pooled.flatMap((m) => {
    const rating = derived.ratings.get(m.key)?.rating;

    return rating === undefined || m.scored === 0 ? [] : [{ key: m.key, model: m.model, label: m.label, color: m.color, rating, cost: m.avgCost }];
  }),
);

/** `rows` come best first by rating, which is the "rating" sort. */
const sortedRows = (rows: ReadonlyArray<HeatRow>, sort: string, valueOf: (row: HeatRow) => number): ReadonlyArray<HeatRow> => {
  if (sort === "rating") return rows;

  if (sort === "model") return rows.toSorted((left, right) => left.label.localeCompare(right.label));

  if (sort === "cost") return rows.toSorted((left, right) => (left.cost || Infinity) - (right.cost || Infinity));

  return rows.toSorted((left, right) => valueOf(right) - valueOf(left) || right.rating - left.rating);
};

const heatmapView = (h: H, derived: Derived, heat: Model["heat"]): Html => {
  const shown = heatRowsOf(derived).toSorted((left, right) => right.rating - left.rating);
  const columns = opponentColumns(derived.pairs);
  const cells = new Map(shown.map((row) => [row.key, new Map(columns.map((col) => [col.id, cellAt(derived, row, col.id)]))]));
  const cellOfRow = (row: HeatRow, col: string) => cells.get(row.key)?.get(col) ?? null;
  const sorted = sortedRows(shown, heat.sort, (row) => cellOfRow(row, heat.sort)?.value ?? -1);

  const header = (id: string, label: string, extra = "") =>
    h.th([h.Class(`${extra} sortable ${heat.sort === id && id !== "rating" ? "sorted" : ""}`), ...pressable(h, Message.ClickedHeatColumn({ column: id }))], [label]);

  const tip = Option.flatMap(heat.maybeTip, ({ row, col }) => {
    const shownRow = shown.find((candidate) => candidate.key === row);
    const cell = shownRow === undefined ? null : cellOfRow(shownRow, col);

    return shownRow === undefined || cell === null ? Option.none() : Option.some(tipView(h, anchorId("cell", row, col), [h.b([], [shownRow.label]), h.br([]), cell.tip]));
  });

  return h.div(
    [],
    [
      // The grid is wider than a phone; the cue shows only there (styles.css).
      h.p([h.Class("k scrollcue")], ["Swipe sideways for more opponents"]),
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
                      header("model", "Model", "left"),
                      ...columns.map((col) => header(col.id, col.label)),
                      header("rating", "Round Elo"),
                      header("cost", "$/match"),
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
                      h.td([h.Class("left")], [h.span([h.Class(`dot ${isClaude(row.model) ? "a" : "o"}`), h.Style({ background: row.color })], []), h.span([h.Style({ color: row.color })], [row.label])]),
                      ...columns.map((col) => {
                        const cell = cellOfRow(row, col.id);

                        if (cell === null) return h.td([h.Class("cellv none")], ["–"]);

                        return h.td(
                          [
                            h.Id(anchorId("cell", row.key, col.id)),
                            h.Class("cellv"),
                            h.Style(shadeOf(cell.value, cell.n)),
                            h.DataAttribute("tip", `${row.label} ${cell.tip}`),
                            h.OnMouseEnter(Message.HoveredCell({ row: row.key, col: col.id })),
                            h.OnMouseLeave(Message.LeftCell()),
                          ],
                          [h.span([h.AriaHidden(true)], [cell.text, h.span([h.Class("n")], [fmtCount(cell.n)])]), h.span([h.Class("sr")], [`${row.label} ${cell.tip}`])],
                        );
                      }),
                      h.td([h.Class("total")], [fmtRating(row.rating)]),
                      h.td([h.Class("cost")], [row.cost > 0 ? fmtUsd(row.cost) : "–"]),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
      Option.getOrElse(tip, () => h.empty),
      termsView(h, "What the columns mean", [
        ...columns.filter(({ label, title }) => label !== title).map(({ label, title }) => [label, title] as const),
        ["Round Elo", "Bradley-Terry rating fitted over every match of every tournament, on round win share"],
        ["$/match", "average list-price cost per player per scored match"],
        ["A cell", `A config's win share against that opponent model. The number in the corner is how many matches it rests on. Below ${FULL_N} matches the shade fades toward the page's color.`],
      ]),
    ],
  );
};

export const breakdownView = (h: H, derived: Derived, heat: Model["heat"]): Html =>
  h.details([h.Class("tables")], [h.summary([], ["Win share vs opponent"]), heatmapView(h, derived, heat)]);
