import type { Html, HtmlBuilder } from "foldkit/html";

import { anchorId, markTip } from "./charts.ts";
import { colorOfKey, fmtPct, groupBy, keyOf, labelOf, type MatchRow, type SeatFull } from "./data.ts";
import { type Derived, memoLast } from "./derived.ts";
import type { Message } from "./model.ts";

type H = HtmlBuilder<Message>;

// Results on each seed, split by table position: each seed is one shuffle, played by whichever pairings the schedule
// gave it, so a row shows what the deal does and what the players do. Cells are a config's wins on that seed; the rows
// run from the seeds that favour table position 1 to the ones that favour position 2.

export interface Tally {
  readonly wins: number;
  readonly games: number;
}

export interface Cell {
  readonly first: Tally;
  readonly second: Tally;
}

export interface Deal {
  readonly id: string;
  readonly seed: number;
  readonly startedAt: string;
  readonly games: number;
  readonly firstShare: number;
  readonly cells: ReadonlyMap<string, Cell>;
}

export interface DealMatch {
  readonly seed: number;
  readonly startedAt: string;
  readonly status: string;
  readonly seats: ReadonlyArray<Pick<SeatFull, "model" | "effort" | "winShare" | "codeHash">>;
}

/** A deal seats its configs in fewer matches each than this on average, too few for a cell to tell much. */
const MIN_SEATINGS_PER_CONFIG = 4;

const EMPTY: Tally = { wins: 0, games: 0 };

const added = (tally: Tally, share: number): Tally => ({ wins: tally.wins + share, games: tally.games + 1 });

export const dealsOf = (matches: ReadonlyArray<DealMatch>): ReadonlyArray<Deal> =>
  [...groupBy(matches.filter(({ status, seats }) => status === "completed" && seats.length === 2), ({ seed, seats }) => `${seed}|${seats[0]?.codeHash ?? ""}`)]
    .flatMap(([id, played]) => {
      const cells = new Map<string, Cell>();
      let firstWins = 0;

      for (const { seats } of played) {
        const [first, second] = seats;

        if (first === undefined || second === undefined) continue;

        const firstCell = cells.get(keyOf(first)) ?? { first: EMPTY, second: EMPTY };
        const secondCell = cells.get(keyOf(second)) ?? { first: EMPTY, second: EMPTY };

        cells.set(keyOf(first), { ...firstCell, first: added(firstCell.first, first.winShare ?? 0) });
        cells.set(keyOf(second), { ...secondCell, second: added(secondCell.second, second.winShare ?? 0) });
        firstWins += first.winShare ?? 0;
      }

      const [one] = played;

      return one === undefined || (2 * played.length) / cells.size < MIN_SEATINGS_PER_CONFIG ? [] : [{ id, seed: one.seed, startedAt: one.startedAt, games: played.length, firstShare: firstWins / played.length, cells }];
    })
    .toSorted((left, right) => right.firstShare - left.firstShare || left.seed - right.seed);

const dealsMemo = memoLast((matches: ReadonlyArray<MatchRow>) => dealsOf(matches));

const DAY = new Intl.DateTimeFormat("en-US", { timeZone: "America/Los_Angeles", month: "short", day: "numeric" });

const share = ({ wins, games }: Tally): number => wins / games;

const shade = (value: number): string => {
  const level = Math.round(40 + value * 200);

  return `rgb(${level},${level},${level})`;
};

const LABEL = 150;

const ROW = 22;

const HALF = 9;

const MIN_CELL = 16;

/** A phone's cells are wider, so a finger can pick one; the chart scrolls sideways instead. */
const MIN_TOUCH_CELL = 24;

const MAX_CELL = 30;

const tallyText = ({ wins, games }: Tally): string => (games === 0 ? "did not play" : `won ${Number(wins.toFixed(1))} of ${games}`);

export const dealsView = (h: H, derived: Derived, width: number): Html => {
  const deals = dealsMemo(derived.matches);
  const ratingOf = (key: string) => derived.ratings.get(key)?.rating ?? Number.NEGATIVE_INFINITY;
  const keys = [...new Set(deals.flatMap(({ cells }) => [...cells.keys()]))].toSorted((left, right) => ratingOf(right) - ratingOf(left) || labelOf(left).localeCompare(labelOf(right)));

  const seedCount = groupBy(deals, ({ seed }) => seed);
  const nameOf = (deal: Deal) => ((seedCount.get(deal.seed)?.length ?? 1) > 1 ? `${deal.seed} · ${DAY.format(new Date(deal.startedAt))}` : String(deal.seed));

  const head = Math.max(...keys.map((key) => labelOf(key).length), 0) * 7 + 12;
  const cell = Math.max(width < 600 ? MIN_TOUCH_CELL : MIN_CELL, Math.min(MAX_CELL, Math.floor((width - LABEL) / Math.max(keys.length, 1))));
  const columnX = (index: number) => LABEL + index * cell;
  const chartWidth = columnX(keys.length);

  return h.div(
    [h.Class("chart")],
    [
      h.div([h.Class("lbbar")], [h.h2([], ["Results on each seed, split by table position"])]),
      h.p([h.Class("sub")], ["One row per seed and code version, over the matches played on it. Top half of a cell: the config's wins seated at table position 1. Bottom half: position 2. Lighter is more wins."]),
      deals.length === 0
        ? h.div([h.Class("empty")], ["No seed has enough scored matches for this filter."])
        : h.div(
            [h.Class("scrollx")],
            [
              h.svg(
                [h.Width(String(chartWidth)), h.Height(String(head + deals.length * ROW))],
                [
                  h.text([h.X("0"), h.Y(String(head - 6))], ["seed"]),
                  h.text([h.X(String(LABEL - 8)), h.Y(String(head - 6)), h.TextAnchor("end")], ["position 1"]),
                  ...keys.map((key, index) =>
                    h.text(
                      [h.X(String(columnX(index) + cell / 2 + 4)), h.Y(String(head - 6)), h.Transform(`rotate(-90 ${columnX(index) + cell / 2 + 4} ${head - 6})`), h.Style({ fill: colorOfKey(key) })],
                      [labelOf(key)],
                    ),
                  ),
                  ...deals.map((deal, row) => {
                    const top = head + row * ROW;

                    return h.g(
                      [],
                      [
                        h.text([h.X("0"), h.Y(String(top + 15)), h.Class("lbl")], [nameOf(deal)]),
                        h.text([h.X(String(LABEL - 8)), h.Y(String(top + 15)), h.TextAnchor("end"), h.Class("val")], [fmtPct(deal.firstShare)]),
                        ...keys.flatMap((key, index) => {
                          const result = deal.cells.get(key);
                          const x = columnX(index) + 1;

                          if (result === undefined) return [];

                          const halves = [
                            { tally: result.first, offset: 0 },
                            { tally: result.second, offset: HALF + 1 },
                          ].flatMap(({ tally, offset }) =>
                            tally.games === 0 ? [] : [h.rect([h.X(String(x)), h.Y(String(top + offset + 1)), h.Width(String(cell - 2)), h.Height(String(HALF)), h.Fill(shade(share(tally)))], [])],
                          );

                          return [
                            h.g(markTip(h, anchorId("deal", deal.id, key), `${labelOf(key)} on seed ${nameOf(deal)}: ${tallyText(result.first)} at position 1, ${tallyText(result.second)} at position 2`, false), [
                              h.rect([h.X(String(x - 1)), h.Y(String(top)), h.Width(String(cell)), h.Height(String(ROW)), h.Fill("transparent")], []),
                              ...halves,
                            ]),
                          ];
                        }),
                      ],
                    );
                  }),
                ],
              ),
            ],
          ),
    ],
  );
};
