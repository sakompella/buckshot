import { Option } from "effect";
import { AsyncData } from "foldkit";
import type { Html, HtmlBuilder } from "foldkit/html";

import { CERTAIN_TYPES, type CertainMistakes, type CertainRate, type CertainType, type OpportunityType } from "../api.ts";
import { anchorId, chartWidth, linScale, REFERENCE, REFERENCE_DASH, tippedDot } from "./charts.ts";
import { baseName, baseOrder, CERTAIN_NAMES, colorOf, EFFORTS, fmtTime, groupBy, keyOf, labelOf, type MatchRow, type SeatFull, shortName, sumOf } from "./data.ts";
import { memoLast } from "./derived.ts";
import { type CertainCell, Message } from "./model.ts";

type H = HtmlBuilder<Message>;

export const CERTAIN_TABLE = "certain-table";

const FEWEST_FOR_RATE = 20;

export interface Cell {
  readonly type: CertainType;
  readonly mistakes: number;
  readonly opportunities: number;
  readonly bounds: CertainRate["bounds"];
}

export interface Row {
  readonly key: string;
  readonly model: string;
  readonly effort: string;
  readonly cells: ReadonlyArray<Cell>;
}

export interface Tallies {
  readonly rows: ReadonlyArray<Row>;
  readonly models: ReadonlyArray<Row>;
  readonly pooled: ReadonlyArray<Cell>;
  readonly provenBlanks: { readonly gaveTurnAway: number; readonly total: number };
  readonly hiddenHealth: number;
}

type SeatKey = Pick<SeatFull, "model" | "effort">;

const hasRate = ({ opportunities }: Cell): boolean => opportunities >= FEWEST_FOR_RATE;

const cellOf = (type: CertainType, parts: ReadonlyArray<CertainRate>, whole: CertainRate | undefined): Cell => ({
  type,
  mistakes: sumOf(parts.map(({ chose }) => chose)),
  opportunities: sumOf(parts.map(({ opportunities }) => opportunities)),
  bounds: whole?.bounds ?? null,
});

const EFFORT_ORDER: ReadonlyArray<string> = EFFORTS;

const inStrengthOrder = <A extends SeatKey>(items: ReadonlyArray<A>): ReadonlyArray<A> =>
  items.toSorted((left, right) => baseOrder(left.model) - baseOrder(right.model) || EFFORT_ORDER.indexOf(left.effort) - EFFORT_ORDER.indexOf(right.effort));

/** A model's or the pooled row keeps its written interval only while all its configs are shown; a filtered selection has no interval. */
export const talliesOf = memoLast((certain: CertainMistakes, seats: ReadonlyArray<SeatKey>, keep: ReadonlyArray<boolean>): Tallies => {
  const shownKeys = new Set(seats.flatMap((seat, at) => (keep[at] === true ? [keyOf(seat)] : [])));
  const configs = certain.rates.filter(({ scope }) => scope === "config");
  const shown = configs.filter((rate) => shownKeys.has(keyOf(rate)));
  const ofType = (rates: ReadonlyArray<CertainRate>, type: OpportunityType) => rates.filter((rate) => rate.type === type);
  const writtenOf = (scope: CertainRate["scope"], model: string, type: OpportunityType) => certain.rates.find((rate) => rate.scope === scope && rate.model === model && rate.type === type);
  const modelNames = [...new Set(shown.map(({ model }) => model))].toSorted((left, right) => baseOrder(left) - baseOrder(right));
  const blanks = ofType(shown, "gave_turn_away");

  return {
    rows: inStrengthOrder([...groupBy(shown, keyOf).values()].flatMap(([first]) => (first === undefined ? [] : [first]))).map(({ model, effort }) => ({
      key: keyOf({ model, effort }),
      model,
      effort,
      cells: CERTAIN_TYPES.map((type) => {
        const own = shown.filter((rate) => rate.model === model && rate.effort === effort && rate.type === type);

        return cellOf(type, own, own[0]);
      }),
    })),
    models: modelNames.map((model) => {
      const mine = shown.filter((rate) => rate.model === model);
      const isWhole = mine.length === configs.filter((rate) => rate.model === model).length;

      return { key: model, model, effort: "", cells: CERTAIN_TYPES.map((type) => cellOf(type, ofType(mine, type), isWhole ? writtenOf("model", model, type) : undefined)) };
    }),
    pooled: CERTAIN_TYPES.map((type) => cellOf(type, ofType(shown, type), shown.length === configs.length ? writtenOf("all", "", type) : undefined)),
    provenBlanks: { gaveTurnAway: sumOf(blanks.map(({ chose }) => chose)), total: sumOf(blanks.map(({ opportunities }) => opportunities)) },
    hiddenHealth: sumOf(ofType(shown, "hidden_health").map(({ opportunities }) => opportunities)),
  };
});

const matchesById = memoLast((matches: ReadonlyArray<MatchRow>): ReadonlyMap<string, MatchRow> => new Map(matches.map((match) => [match.matchId, match])));

interface Listed {
  readonly matchId: string;
  readonly ordinal: number;
  readonly count: number;
  readonly startedAt: string;
  readonly opponent: SeatFull | undefined;
}

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

const fmtBounds = ({ lo, hi }: NonNullable<CertainRate["bounds"]>): string => `[${fmtRate(lo)}, ${fmtRate(hi)}]`;

const intervalView = (h: H, bounds: NonNullable<CertainRate["bounds"]>): Html => h.span([h.Class("pm")], [` ${fmtBounds(bounds)}`]);

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
      hasRate(cell) ? h.span([h.Class("cmr")], [h.b([], [fmtRate(cell.mistakes / cell.opportunities)]), cell.bounds === null ? h.empty : intervalView(h, cell.bounds)]) : h.empty,
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

const stepOf = (most: number): number => [0.005, 0.01, 0.02, 0.05, 0.1].find((step) => most / step <= 5) ?? 0.2;

const panelView = (h: H, type: CertainType, models: ReadonlyArray<Row>, pooled: Cell, width: number): Html => {
  const isNarrow = width < 420;
  const [left, right] = isNarrow ? [78, 78] : [96, 92];
  const cellsOf = models.flatMap(({ model, cells }) => cells.filter((cell) => cell.type === type).map((cell) => ({ model, cell })));
  const pooledShare = pooled.opportunities === 0 ? 0 : pooled.mistakes / pooled.opportunities;
  const most = Math.max(pooledShare, ...cellsOf.map(({ cell }) => cell.bounds?.hi ?? (hasRate(cell) ? cell.mistakes / cell.opportunities : 0)));
  const step = stepOf(most);
  const top = Math.max(step, Math.ceil(most / step) * step);
  const ticks = Array.from({ length: Math.round(top / step) + 1 }, (_tick, index) => index * step);
  const x = linScale(0, top, left, width - right, ticks);
  const height = TOP + models.length * ROW + BOTTOM;
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
            hasRate(cell)
              ? h.g(
                  [],
                  [
                    cell.bounds === null
                      ? h.empty
                      : h.line([h.X1(String(x.at(cell.bounds.lo))), h.X2(String(x.at(cell.bounds.hi))), h.Y1(String(y)), h.Y2(String(y)), h.Stroke(color), h.StrokeOpacity("0.4"), h.StrokeWidth("3")], []),
                    tippedDot(
                      h,
                      anchorId("certain", type, model),
                      `${baseName(model)} · ${cell.mistakes.toLocaleString()} of ${cell.opportunities.toLocaleString()} opportunities, ${fmtRate(cell.mistakes / cell.opportunities)}${cell.bounds === null ? "" : ` ${fmtBounds(cell.bounds)}`}`,
                      String(x.at(cell.mistakes / cell.opportunities)),
                      String(y),
                      [h.R("3.5"), h.Fill(color)],
                    ),
                  ],
                )
              : h.empty,
            h.text([h.X(String(width - right + 8)), h.Y(String(y + 4))], [counts]),
          ],
        );
      }),
    ],
  );
};

const pooledNote = (cell: Cell): string =>
  `All shown configs: ${cell.mistakes.toLocaleString()} of ${cell.opportunities.toLocaleString()}${hasRate(cell) ? `, ${fmtRate(cell.mistakes / cell.opportunities)}${cell.bounds === null ? "" : ` ${fmtBounds(cell.bounds)}`}` : ""}`;

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

export const hasCertainChart = (data: AsyncData.AsyncData<CertainMistakes, string>): boolean =>
  AsyncData.matchData(data, { onEmpty: () => false, onFailure: () => false, onData: ({ rates }) => rates.length > 0 });

export const hasCertain = (data: AsyncData.AsyncData<CertainMistakes, string>): boolean =>
  AsyncData.matchData(data, { onEmpty: () => false, onFailure: () => true, onData: ({ rates }) => rates.length > 0 });
