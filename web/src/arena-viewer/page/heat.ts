import { Option } from "effect";
import type { Html, HtmlBuilder } from "foldkit/html";

import { anchorId, pressable, tipView } from "./charts.ts";
import { baseName, baseOrder, fmtCount, fmtPct, fmtRating, fmtUsd, isClaude, keyOf, type MatchRow, shortName, unique } from "./data.ts";
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

/** Matches against an opponent from which a cell's shade is at full strength; fewer fade it toward the page. */
export const FULL_N = 10;

const DARKEST = 0x26;
const BRIGHTEST = 0xe8;
const PAGE = 0x10;

/** A grey that grows with the win share, pulled toward the page's own grey by as much as the cell lacks of FULL_N matches. */
export const shadeOf = (value: number, n: number) => {
  const level = Math.round(PAGE + (DARKEST + value * (BRIGHTEST - DARKEST) - PAGE) * Math.min(1, n / FULL_N));

  return { background: `rgb(${level}, ${level}, ${level})`, color: level > 0x80 ? "#000" : "#e6e6e6" };
};

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
  unique(matches.flatMap((match) => match.seats.map(({ model }) => model)))
    .toSorted((left, right) => baseOrder(left) - baseOrder(right))
    .map((model) => ({ id: baseName(model), label: shortName(model), title: baseName(model) })),
);

const cellAt = (derived: Derived, row: HeatRow, col: string): HeatCell | null => {
  const counts = versus(derived.matches).get(row.key)?.get(col);

  return counts === undefined ? null : { value: counts[0] / counts[1], text: fmtPct(counts[0] / counts[1]), tip: `vs ${col}: ${fmtPct(counts[0] / counts[1])} of ${counts[1]} matches. Full strength from ${FULL_N} matches.`, n: counts[1] };
};

export const heatRowsOf = memoLast((derived: Derived): ReadonlyArray<HeatRow> =>
  derived.pooled.flatMap((m) => {
    const rating = derived.ratings.get(m.key)?.rating;

    return rating === undefined || m.scored.length === 0 ? [] : [{ key: m.key, model: m.model, label: m.label, color: m.color, rating, cost: m.avgCost }];
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
  const columns = opponentColumns(derived.matches);
  const cells = new Map(shown.map((row) => [row.key, new Map(columns.map((col) => [col.id, cellAt(derived, row, col.id)]))]));
  const cellOfRow = (row: HeatRow, col: string) => cells.get(row.key)?.get(col) ?? null;
  const sorted = sortedRows(shown, heat.sort, (row) => cellOfRow(row, heat.sort)?.value ?? -1);

  const header = (id: string, label: string, title: string, extra = "") =>
    h.th([h.Title(title), h.Class(`${extra} sortable ${heat.sort === id && id !== "rating" ? "sorted" : ""}`), ...pressable(h, Message.ClickedHeatColumn({ column: id }))], [label]);

  const tip = Option.flatMap(heat.maybeTip, ({ row, col }) => {
    const shownRow = shown.find((candidate) => candidate.key === row);
    const cell = shownRow === undefined ? null : cellOfRow(shownRow, col);

    return shownRow === undefined || cell === null ? Option.none() : Option.some(tipView(h, anchorId("cell", row, col), [h.b([], [shownRow.label]), h.br([]), cell.tip]));
  });

  return h.div(
    [],
    [
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
                      ...columns.map((col) => header(col.id, col.label, col.title)),
                      header("rating", "Round Elo", "Bradley-Terry rating fitted over every match of every tournament, on round win share"),
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
                          [cell.text, h.span([h.Class("n")], [fmtCount(cell.n)])],
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
    ],
  );
};

export const breakdownView = (h: H, derived: Derived, heat: Model["heat"]): Html =>
  h.details([h.Class("tables")], [h.summary([], ["Win share vs opponent"]), heatmapView(h, derived, heat)]);
