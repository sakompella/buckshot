import { Option } from "effect";
import { AsyncData } from "foldkit";
import type { Html, HtmlBuilder } from "foldkit/html";

import { CERTAIN_TYPES, type CertainMistakes, type CertainType, OPPORTUNITY_TYPES } from "../api.ts";
import { anchorId, chartWidth, linScale, REFERENCE, REFERENCE_DASH, tippedDot } from "./charts.ts";
import { addTo, baseName, baseOrder, type BlockTally, blockRate, CERTAIN_NAMES, colorOf, EFFORTS, fmtTime, groupBy, keyOf, labelOf, type MatchRow, type SeatFull, shortName, sumOf } from "./data.ts";
import { memoLast } from "./derived.ts";
import { type CertainCell, Message } from "./model.ts";

type H = HtmlBuilder<Message>;

/** The id of the folded table at the page's end that the chart links to. */
export const CERTAIN_TABLE = "certain-table";

// Certain mistakes (docs/arena/analysis/certain-mistakes.md): per config and type, the decisions that made the mistake over
// the decisions where it was a legal move, from the opportunities tools/arena/analysis/certain_mistakes.py classified.

/** A cell with fewer opportunities than this shows its count only. */
const FEWEST_FOR_INTERVAL = 20;

export interface Cell {
  readonly type: CertainType;
  readonly mistakes: number;
  readonly opportunities: number;
  /** The 95% seed-block interval of the rate, or null under FEWEST_FOR_INTERVAL opportunities. */
  readonly bounds: readonly [number, number] | null;
}

export interface Row {
  readonly key: string;
  readonly model: string;
  readonly effort: string;
  readonly cells: ReadonlyArray<Cell>;
}

export interface Tallies {
  /** Every config with a decision, then every model with its efforts pooled (its `effort` is empty). */
  readonly rows: ReadonlyArray<Row>;
  readonly models: ReadonlyArray<Row>;
  readonly pooled: ReadonlyArray<Cell>;
  readonly provenBlanks: { readonly gaveTurnAway: number; readonly total: number };
  readonly hiddenHealth: number;
}

type SeatKey = Pick<SeatFull, "model" | "effort" | "seedBlock">;

const totalsOf = (tally: BlockTally) => {
  const blocks = [...tally.values()];

  return { hits: sumOf(blocks.map(([hits]) => hits)), trials: sumOf(blocks.map(([, trials]) => trials)) };
};

const cellOf = (type: CertainType, tally: BlockTally): Cell => {
  const { hits, trials } = totalsOf(tally);

  if (trials < FEWEST_FOR_INTERVAL) return { type, mistakes: hits, opportunities: trials, bounds: null };

  const { lo, hi } = blockRate(tally);

  return { type, mistakes: hits, opportunities: trials, bounds: [lo, hi] };
};

const EFFORT_ORDER: ReadonlyArray<string> = EFFORTS;

const emptyTallies = (): ReadonlyArray<BlockTally> => OPPORTUNITY_TYPES.map(() => new Map());

/** Each config's and each model's tallies over the kept seats, in strength and effort order, then every kept seat pooled. */
export const talliesOf = memoLast((certain: CertainMistakes, seats: ReadonlyArray<SeatKey>, keep: ReadonlyArray<boolean>): Tallies => {
  const configs = new Map<string, { readonly seat: SeatKey; readonly tallies: ReadonlyArray<BlockTally> }>();
  const models = new Map<string, { readonly seat: SeatKey; readonly tallies: ReadonlyArray<BlockTally> }>();
  const pooled = emptyTallies();

  certain.seat.forEach((seatAt, entry) => {
    const seat = seats[seatAt];
    const type = certain.type[entry] ?? -1;

    if (seat === undefined || keep[seatAt] !== true) return;

    const config = configs.get(keyOf(seat)) ?? { seat, tallies: emptyTallies() };
    const [mistakes, opportunities] = [certain.chose[entry] ?? 0, certain.opportunities[entry] ?? 0];

    const model = models.get(seat.model) ?? { seat, tallies: emptyTallies() };

    configs.set(keyOf(seat), config);
    models.set(seat.model, model);

    for (const tally of [config.tallies[type], model.tallies[type], pooled[type]]) if (tally !== undefined) addTo(tally, seat.seedBlock, mistakes, opportunities);
  });

  const cellsOf = (tallies: ReadonlyArray<BlockTally>) => CERTAIN_TYPES.map((type) => cellOf(type, tallies[OPPORTUNITY_TYPES.indexOf(type)] ?? new Map()));
  const blanks = totalsOf(pooled[OPPORTUNITY_TYPES.indexOf("gave_turn_away")] ?? new Map());

  return {
    rows: [...configs.values()]
      .toSorted((left, right) => baseOrder(left.seat.model) - baseOrder(right.seat.model) || EFFORT_ORDER.indexOf(left.seat.effort) - EFFORT_ORDER.indexOf(right.seat.effort))
      .map(({ seat, tallies }) => ({ key: keyOf(seat), model: seat.model, effort: seat.effort, cells: cellsOf(tallies) })),
    models: [...models.values()]
      .toSorted((left, right) => baseOrder(left.seat.model) - baseOrder(right.seat.model))
      .map(({ seat, tallies }) => ({ key: seat.model, model: seat.model, effort: "", cells: cellsOf(tallies) })),
    pooled: cellsOf(pooled),
    provenBlanks: { gaveTurnAway: blanks.hits, total: blanks.trials },
    hiddenHealth: totalsOf(pooled[OPPORTUNITY_TYPES.indexOf("hidden_health")] ?? new Map()).trials,
  };
});

const matchesById = memoLast((matches: ReadonlyArray<MatchRow>): ReadonlyMap<string, MatchRow> => new Map(matches.map((match) => [match.matchId, match])));

interface Listed {
  readonly matchId: string;
  /** The first mistake of the cell's type in the match, which the replay opens at. */
  readonly ordinal: number;
  readonly count: number;
  readonly startedAt: string;
  readonly opponent: SeatFull | undefined;
}

/** The matches where a config made a type of certain mistake, newest first. */
const listedOf = (certain: CertainMistakes, seats: ReadonlyArray<SeatFull>, matches: ReadonlyMap<string, MatchRow>, { key, type }: CertainCell): ReadonlyArray<Listed> => {
  const found = certain.moveSeat.flatMap((seatAt, move) => {
    const seat = seats[seatAt];

    return seat !== undefined && keyOf(seat) === key && certain.moveType[move] === CERTAIN_TYPES.indexOf(type) ? [{ seat, ordinal: certain.moveOrd[move] ?? 0 }] : [];
  });

  return [...groupBy(found, ({ seat }) => seat.matchId).values()]
    .flatMap((moves): ReadonlyArray<Listed> => {
      const [first] = moves;

      return first === undefined
        ? []
        : [
            {
              matchId: first.seat.matchId,
              ordinal: Math.min(...moves.map(({ ordinal }) => ordinal)),
              count: moves.length,
              startedAt: first.seat.startedAt,
              opponent: matches.get(first.seat.matchId)?.seats.find(({ player }) => player !== first.seat.player),
            },
          ];
    })
    .toSorted((left, right) => right.startedAt.localeCompare(left.startedAt));
};

const fmtRate = (share: number): string => `${(share * 100).toFixed(1)}%`;

const cellView = (h: H, cell: Cell, link: { readonly key: string; readonly isOpen: boolean } | null): Html => {
  const label = h.DataAttribute("label", CERTAIN_NAMES[cell.type]);

  if (cell.opportunities === 0) return h.td([label], ["–"]);

  const counts = `${cell.mistakes.toLocaleString()} / ${cell.opportunities.toLocaleString()}`;

  return h.td(
    [label],
    [
      link !== null && cell.mistakes > 0
        ? h.button([h.Type("button"), h.Class("cmb"), h.AriaExpanded(link.isOpen), h.OnClick(Message.ClickedCertainCount({ key: link.key, type: cell.type }))], [counts])
        : h.span([], [counts]),
      cell.bounds === null
        ? h.empty
        : h.span([h.Class("cmr")], [h.b([], [fmtRate(cell.mistakes / cell.opportunities)]), " ", h.span([h.Class("pm")], [`[${fmtRate(cell.bounds[0])}, ${fmtRate(cell.bounds[1])}]`])]),
    ],
  );
};

const matchesView = (h: H, listed: ReadonlyArray<Listed>): Html =>
  h.div(
    [h.Class("chips cmmatches")],
    listed.map(({ matchId, ordinal, count, startedAt, opponent }) =>
      h.button(
        [h.Type("button"), h.Class("chip on"), h.OnClick(Message.ClickedMatch({ id: matchId, maybeFocus: Option.some(ordinal) }))],
        [
          opponent === undefined ? h.empty : h.i([h.Style({ background: colorOf(opponent.model) })], []),
          `${fmtTime(startedAt)}${opponent === undefined ? "" : ` · vs ${labelOf(keyOf(opponent))}`}${count > 1 ? ` · ${count} mistakes` : ""}`,
        ],
      ),
    ),
  );

const rowView = (h: H, certain: CertainMistakes, seats: ReadonlyArray<SeatFull>, matches: ReadonlyMap<string, MatchRow>, row: Row, maybeOpen: Option.Option<CertainCell>): ReadonlyArray<Html> => {
  const open = Option.filter(maybeOpen, ({ key }) => key === row.key);

  return [
    h.keyed("tr")(
      row.key,
      [h.Class(Option.isSome(open) ? "sel" : "")],
      [
        h.td([], [h.span([h.Class("dot"), h.Style({ background: colorOf(row.model) })], []), `${baseName(row.model)} `, h.span([h.Class("eff")], [`[${row.effort}]`])]),
        ...row.cells.map((cell) => cellView(h, cell, { key: row.key, isOpen: Option.exists(open, ({ type }) => type === cell.type) })),
      ],
    ),
    Option.match(open, {
      onNone: () => h.empty,
      onSome: (cell) => h.keyed("tr")(`drill-${row.key}`, [h.Class("drill")], [h.td([h.Colspan(CERTAIN_TYPES.length + 1)], [matchesView(h, listedOf(certain, seats, matches, cell))])]),
    }),
  ];
};

/** The configs as a table, folded at the page's end: the counts open the matches. */
export const certainTableView = (h: H, certain: CertainMistakes, seats: ReadonlyArray<SeatFull>, keep: ReadonlyArray<boolean>, allMatches: ReadonlyArray<MatchRow>, maybeOpen: Option.Option<CertainCell>): Html => {
  const { rows, pooled } = talliesOf(certain, seats, keep);
  const matches = matchesById(allMatches);

  return h.details(
    [h.Class("tables"), h.Id(CERTAIN_TABLE)],
    [
      h.summary([], ["Certain mistakes by config"]),
      rows.length === 0
        ? h.div([h.Class("empty")], ["No config in this filter has a decision with a proven shell."])
        : h.div(
            [h.Class("card")],
            [
              h.table(
                [h.Class("cmt")],
                [
                  h.thead([], [h.tr([], ["Model", ...CERTAIN_TYPES.map((type) => CERTAIN_NAMES[type])].map((title) => h.th([], [title])))]),
                  h.tbody([], [...rows.flatMap((row) => rowView(h, certain, seats, matches, row, maybeOpen)), h.tr([h.Class("pooled")], [h.td([], ["All shown configs"]), ...pooled.map((cell) => cellView(h, cell, null))])]),
                ],
              ),
            ],
          ),
    ],
  );
};

const ROW = 24;

const TOP = 8;

const BOTTOM = 26;

/** The nicest axis step that puts about five ticks under the largest rate. */
const stepOf = (most: number): number => [0.005, 0.01, 0.02, 0.05, 0.1].find((step) => most / step <= 5) ?? 0.2;

const panelView = (h: H, type: CertainType, models: ReadonlyArray<Row>, pooled: Cell, width: number): Html => {
  const isNarrow = width < 420;
  const [left, right] = isNarrow ? [78, 78] : [96, 92];
  const cellsOf = models.flatMap(({ model, cells }) => cells.filter((cell) => cell.type === type).map((cell) => ({ model, cell })));
  const pooledShare = pooled.opportunities === 0 ? 0 : pooled.mistakes / pooled.opportunities;
  const most = Math.max(pooledShare, ...cellsOf.map(({ cell }) => cell.bounds?.[1] ?? 0));
  const step = stepOf(most);
  const top = Math.max(step, Math.ceil(most / step) * step);
  const ticks = Array.from({ length: Math.round(top / step) + 1 }, (_tick, index) => index * step);
  const x = linScale(0, top, left, width - right, ticks);
  const height = TOP + models.length * ROW + BOTTOM;
  const rate = (share: number) => `${(share * 100).toFixed(1)}%`;
  const tickLabel = (value: number) => `${+(value * 100).toFixed(1)}%`;

  return h.svg(
    [h.Width(String(width)), h.Height(String(height))],
    [
      ...x.ticks.map((tick) =>
        h.g(
          [],
          [
            h.line([h.Class("grid"), h.X1(String(x.at(tick))), h.X2(String(x.at(tick))), h.Y1(String(TOP)), h.Y2(String(height - BOTTOM))], []),
            h.text([h.X(String(x.at(tick))), h.Y(String(height - BOTTOM + 16)), h.TextAnchor("middle")], [tickLabel(tick)]),
          ],
        ),
      ),
      h.line([h.X1(String(x.at(pooledShare))), h.X2(String(x.at(pooledShare))), h.Y1(String(TOP)), h.Y2(String(height - BOTTOM)), h.Stroke(REFERENCE), h.StrokeDasharray(REFERENCE_DASH)], []),
      ...cellsOf.map(({ model, cell }, index) => {
        const y = TOP + index * ROW + ROW / 2;
        const color = colorOf(model);
        const counts = cell.opportunities === 0 ? "–" : `${cell.mistakes.toLocaleString()} / ${cell.opportunities.toLocaleString()}`;
        const name = isNarrow ? shortName(model) : baseName(model);

        return h.g(
          [],
          [
            h.text([h.X(String(left - 8)), h.Y(String(y + 4)), h.TextAnchor("end"), h.Style({ fill: color })], [name]),
            cell.bounds === null
              ? h.empty
              : h.g(
                  [],
                  [
                    h.line([h.X1(String(x.at(cell.bounds[0]))), h.X2(String(x.at(cell.bounds[1]))), h.Y1(String(y)), h.Y2(String(y)), h.Stroke(color), h.StrokeOpacity("0.4"), h.StrokeWidth("3")], []),
                    tippedDot(
                      h,
                      anchorId("certain", type, model),
                      `${baseName(model)} · ${cell.mistakes.toLocaleString()} of ${cell.opportunities.toLocaleString()} opportunities, ${rate(cell.mistakes / cell.opportunities)} [${rate(cell.bounds[0])}, ${rate(cell.bounds[1])}]`,
                      String(x.at(cell.mistakes / cell.opportunities)),
                      String(y),
                      [h.R("3.5"), h.Fill(color)],
                    ),
                  ],
                ),
            h.text([h.X(String(width - right + 8)), h.Y(String(y + 4))], [counts]),
          ],
        );
      }),
    ],
  );
};

const pooledNote = ({ mistakes, opportunities, bounds }: Cell): string =>
  `All shown configs: ${mistakes.toLocaleString()} of ${opportunities.toLocaleString()}${bounds === null ? "" : `, ${((mistakes / opportunities) * 100).toFixed(1)}% [${(bounds[0] * 100).toFixed(1)}%, ${(bounds[1] * 100).toFixed(1)}%]`}`;

/** The section in How they play: each model's rate for each type, its counts on the right and its interval on a tap, and the pooled rate as the dashed line. */
export const certainView = (h: H, certain: CertainMistakes, seats: ReadonlyArray<SeatFull>, keep: ReadonlyArray<boolean>, width: number, content: number): Html => {
  const { models, pooled, provenBlanks, hiddenHealth } = talliesOf(certain, seats, keep);
  const figure = chartWidth(width, content);

  return h.div(
    [],
    [
      h.h2([], ["Certain mistakes"]),
      h.p([h.Class("sub")], ["An opportunity is every decision where the mistake was a legal move."]),
      models.length === 0
        ? h.div([h.Class("empty")], ["No config in this filter has a decision with a proven shell."])
        : h.div(
            [h.Class("chartrow")],
            pooled.map((cell) => h.figure([], [h.h3([], [CERTAIN_NAMES[cell.type]]), h.p([h.Class("sub")], [pooledNote(cell)]), panelView(h, cell.type, models, cell, figure)])),
          ),
      h.p(
        [h.Class("k")],
        [
          `Not counted: on a proven blank, giving the turn away (${provenBlanks.gaveTurnAway.toLocaleString()} of ${provenBlanks.total.toLocaleString()}) is not proven worse, and ${hiddenHealth.toLocaleString()} decisions where a jammed opponent hid its health. `,
          h.button([h.Type("button"), h.Class("tablelink"), h.OnClick(Message.ClickedTableLink({ id: CERTAIN_TABLE }))], ["Each config's counts and matches are in a table at the end."]),
        ],
      ),
    ],
  );
};

/** The section is drawn when the certain-mistakes data loaded and holds a decision, or failed to load, so the page says so. */
export const hasCertain = (data: AsyncData.AsyncData<CertainMistakes, string>): boolean =>
  AsyncData.matchData(data, { onEmpty: () => false, onFailure: () => true, onData: ({ seat }) => seat.length > 0 });
