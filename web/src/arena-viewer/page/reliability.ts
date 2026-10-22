import { Option } from "effect";
import type { Html, HtmlBuilder } from "foldkit/html";

import type { Decisions } from "../api.ts";
import { anchorId, tipView } from "./charts.ts";
import { addTo, type BlockTally, blockRate, colorOf, colorOfKey, fmtTime, fmtUsd, isDegenerate, keyOf, labelOf, type Rate, type SeatFull, sumOf } from "./data.ts";
import { memoLast } from "./derived.ts";
import { Message, type Model } from "./model.ts";

type H = HtmlBuilder<Message>;

// Infrastructure and protocol reliability, kept apart from skill, per tournament and config.

const hours = (ms: number) => `${(ms / 3.6e6).toFixed(2)} h`;

interface Tally {
  readonly tournament: string;
  readonly key: string;
  readonly failed: BlockTally;
  readonly faults: BlockTally;
  readonly reminders: BlockTally;
  readonly extraReturned: BlockTally;
  readonly extraFailed: BlockTally;
  fallbacks: number;
  calls: number;
  moves: number;
  failedCost: number;
  failedTime: number;
  returnedCost: number;
  returnedTime: number;
}

/** A rate column: its id, header, hover title, name in the tip, label on a phone, scale (per cent or per 1,000 moves) and unit. */
const COLUMNS = [
  { id: "failed", header: "Failed calls", title: "", name: "failed calls", label: "failed calls", scale: 100, unit: "%" },
  { id: "faults", header: "Faults", title: "provider errors in events.jsonl", name: "faults", label: "faults", scale: 1000, unit: "" },
  { id: "reminders", header: "Reminders", title: '"It is still your turn" nudges', name: "reminders", label: "reminders", scale: 1000, unit: "" },
  { id: "extraReturned", header: "Extra returned", title: "extra returned replies linked to a move, including get_game calls", name: "extra returned replies", label: "extra returned", scale: 1000, unit: "" },
  { id: "extraFailed", header: "Extra failed", title: "failed replies linked to a move", name: "extra failed replies", label: "extra failed", scale: 1000, unit: "" },
] as const;

type ColumnId = (typeof COLUMNS)[number]["id"];

interface Row extends Tally {
  readonly id: string;
  readonly rates: Readonly<Record<ColumnId, Rate>>;
}

const rowsOf = memoLast((decisions: Decisions, seats: ReadonlyArray<SeatFull>, keep: ReadonlyArray<boolean>): ReadonlyArray<Row> => {
  // Per seat: replies linked to a move, and how many of them failed.
  const linked = new Map<number, [number, number]>();

  decisions.seat.forEach((seat, move) => {
    const counts = linked.get(seat) ?? [0, 0];

    linked.set(seat, [counts[0] + (decisions.calls[move] ?? 0), counts[1] + (decisions.failedCalls[move] ?? 0)]);
  });

  const tallies = new Map<string, Tally>();

  seats.forEach((seat, index) => {
    if (keep[index] !== true) return;

    const id = `${seat.tournament}||${keyOf(seat)}`;

    const tally = tallies.get(id) ?? {
      tournament: seat.tournament,
      key: keyOf(seat),
      failed: new Map(),
      faults: new Map(),
      reminders: new Map(),
      extraReturned: new Map(),
      extraFailed: new Map(),
      fallbacks: 0,
      calls: 0,
      moves: 0,
      failedCost: 0,
      failedTime: 0,
      returnedCost: 0,
      returnedTime: 0,
    };

    const moves = seat.moves ?? 0;
    const calls = seat.calls ?? 0;
    const [linkedCalls, linkedFailed] = linked.get(index) ?? [0, 0];

    tallies.set(id, tally);
    addTo(tally.failed, seat.seedBlock, seat.failed ?? 0, calls);
    addTo(tally.faults, seat.seedBlock, seat.faults, moves);
    addTo(tally.reminders, seat.seedBlock, seat.reminders, moves);
    addTo(tally.extraFailed, seat.seedBlock, linkedFailed, moves);
    addTo(tally.extraReturned, seat.seedBlock, Math.max(0, linkedCalls - linkedFailed - moves), moves);
    tally.fallbacks += seat.fallbacks;
    tally.calls += calls;
    tally.moves += moves;
    tally.failedCost += seat.fcost ?? 0;
    tally.failedTime += seat.flat ?? 0;
    tally.returnedCost += seat.rcost ?? 0;
    tally.returnedTime += seat.rlat ?? 0;
  });

  return [...tallies]
    .map(([id, tally]): Row => ({
      ...tally,
      id,
      rates: {
        failed: blockRate(tally.failed, 300),
        faults: blockRate(tally.faults, 300),
        reminders: blockRate(tally.reminders, 300),
        extraReturned: blockRate(tally.extraReturned, 300),
        extraFailed: blockRate(tally.extraFailed, 300),
      },
    }))
    .toSorted((left, right) => left.tournament.localeCompare(right.tournament) || right.rates.failed.rate - left.rates.failed.rate);
});

/** The 25 kept moves with the most replies beyond the first, among those with more than three. */
const worstOf = memoLast((decisions: Decisions, seats: ReadonlyArray<SeatFull>, keep: ReadonlyArray<boolean>) =>
  decisions.seat
    .flatMap((seatIndex, move) => {
      const seat = seats[seatIndex];
      const calls = decisions.calls[move] ?? 0;

      return seat !== undefined && calls > 3 && keep[seatIndex] === true ? [{ move, seat, extra: calls - 1 }] : [];
    })
    .toSorted((left, right) => right.extra - left.extra)
    .slice(0, 25),
);

const rateCellView = (h: H, row: Row, column: (typeof COLUMNS)[number]): Html => {
  const rate = row.rates[column.id];

  return h.td(
    [
      h.Id(anchorId("rel", row.id, column.id)),
      h.DataAttribute("label", column.label),
      h.OnMouseEnter(Message.HoveredRate({ row: row.id, column: column.id })),
      h.OnMouseLeave(Message.LeftRate()),
    ],
    [rate.n > 0 ? `${(rate.rate * column.scale).toFixed(column.scale === 1000 ? 1 : 2)}${column.unit}` : "–", h.br([]), h.span([h.Class("pm")], [`${rate.k}/${rate.n}`])],
  );
};

const tipOf = (h: H, rows: ReadonlyArray<Row>, cell: Model["maybeRateTip"]): Html =>
  Option.match(cell, {
    onNone: () => h.empty,
    onSome: ({ row: rowId, column: columnId }) => {
      const row = rows.find(({ id }) => id === rowId);
      const column = COLUMNS.find(({ id }) => id === columnId);

      if (row === undefined || column === undefined) return h.empty;

      const rate = row.rates[column.id];
      const range = isDegenerate(rate) ? ", no interval" : ` · ${(rate.lo * column.scale).toFixed(2)}–${(rate.hi * column.scale).toFixed(2)}${column.unit}`;

      return tipView(h, anchorId("rel", row.id, column.id), [h.b([], [`${labelOf(row.key)} · ${column.name}`]), h.br([]), `${rate.k} of ${rate.n}${range}`]);
    },
  });

export const reliabilityView = (h: H, filters: Html, decisions: Decisions, seats: ReadonlyArray<SeatFull>, keep: ReadonlyArray<boolean>, tip: Model["maybeRateTip"]): Html => {
  const rows = rowsOf(decisions, seats, keep);
  const worst = worstOf(decisions, seats, keep);
  const hasTournaments = new Set(rows.map(({ tournament }) => tournament)).size > 1;
  const total = (pick: (row: Row) => number) => sumOf(rows.map(pick));
  const overhead = rows.filter((row) => row.failedCost > 0 || row.failedTime > 0).toSorted((left, right) => right.failedTime - left.failedTime);

  return h.div(
    [],
    [
      h.section(
        [],
        [
          h.h2([], ["Reliability"]),
          h.p([h.Class("sub")], ["Kept apart from skill; all started matches. Faults, reminders and extra replies are per 1,000 model-chosen moves."]),
          filters,
          h.table(
            [h.Class("rows")],
            [
              h.thead(
                [],
                [
                  h.tr(
                    [],
                    [
                      h.th([], ["Config"]),
                      h.th([], ["Replies"]),
                      h.th([], ["Model moves"]),
                      ...COLUMNS.map((column) => h.th(column.title === "" ? [] : [h.Title(column.title)], [column.header])),
                      h.th([], ["Fallback moves"]),
                    ],
                  ),
                ],
              ),
              h.tbody(
                [],
                rows.flatMap((row, index) => [
                  hasTournaments && (index === 0 || rows[index - 1]?.tournament !== row.tournament) ? h.tr([h.Class("group")], [h.td([h.Colspan(9)], [row.tournament])]) : h.empty,
                  h.tr(
                    [],
                    [
                      h.td([h.Style({ color: colorOfKey(row.key) })], [labelOf(row.key)]),
                      h.td([h.DataAttribute("label", "replies")], [row.calls.toLocaleString()]),
                      h.td([h.DataAttribute("label", "moves")], [row.moves.toLocaleString()]),
                      ...COLUMNS.map((column) => rateCellView(h, row, column)),
                      h.td([h.DataAttribute("label", "fallbacks")], [String(row.fallbacks)]),
                    ],
                  ),
                ]),
              ),
            ],
          ),
        ],
      ),
      h.section(
        [],
        [
          h.h2([], ["Failed-call overhead"]),
          h.p(
            [h.Class("sub")],
            [
              `Failed calls cost ${fmtUsd(total(({ failedCost }) => failedCost))} and ${hours(total(({ failedTime }) => failedTime))} recorded latency, against ${fmtUsd(total(({ returnedCost }) => returnedCost))} and ${hours(total(({ returnedTime }) => returnedTime))} for returned calls (list-price estimate).`,
            ],
          ),
          h.table(
            [h.Class("rows")],
            [
              h.thead([], [h.tr([], ["Config", "Failed cost", "Failed time", "Returned cost", "Returned time"].map((title) => h.th([], [title])))]),
              h.tbody(
                [],
                overhead.map((row) =>
                  h.tr(
                    [],
                    [
                      h.td([h.Style({ color: colorOfKey(row.key) })], [labelOf(row.key), hasTournaments ? h.span([h.Class("pm")], [` · ${row.tournament}`]) : h.empty]),
                      h.td([h.DataAttribute("label", "failed cost")], [fmtUsd(row.failedCost)]),
                      h.td([h.DataAttribute("label", "failed time")], [hours(row.failedTime)]),
                      h.td([h.DataAttribute("label", "returned cost")], [fmtUsd(row.returnedCost)]),
                      h.td([h.DataAttribute("label", "returned time")], [hours(row.returnedTime)]),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
      h.section(
        [],
        [
          h.h2([], ["Moves with the most extra replies"]),
          h.p([h.Class("sub")], ["Top 25 model-chosen moves by linked replies beyond the first."]),
          h.table(
            [h.Class("rows")],
            [
              h.thead([], [h.tr([], ["Config", "Started", "Seed", "Move", "Extra replies", "Of them failed"].map((title) => h.th([], [title])))]),
              h.tbody(
                [],
                worst.map(({ move, seat, extra }) =>
                  h.keyed("tr")(
                    String(move),
                    [h.Class("row"), h.OnClick(Message.ClickedMatch({ id: seat.matchId, maybeFocus: Option.fromUndefinedOr(decisions.ord[move]) }))],
                    [
                      h.td([h.Style({ color: colorOf(seat.model, seat.effort) })], [labelOf(keyOf(seat))]),
                      h.td([h.DataAttribute("label", "started")], [fmtTime(seat.startedAt)]),
                      h.td([h.DataAttribute("label", "seed")], [String(seat.seed)]),
                      h.td([h.DataAttribute("label", "move")], [String(decisions.moveNo[move] ?? "")]),
                      h.td([h.DataAttribute("label", "extra")], [String(extra)]),
                      h.td([h.DataAttribute("label", "failed")], [String(decisions.failedCalls[move] ?? "")]),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
      tipOf(h, rows, tip),
    ],
  );
};
