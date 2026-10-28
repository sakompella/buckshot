import type { Html, HtmlBuilder } from "foldkit/html";

import { anchorId, logScale, tippedDot } from "./charts.ts";
import { addTo, type BlockTally, blockRate, colorOfKey, groupBy, keyOf, knownRounds, labelOf, type Rate, type SeatFull } from "./data.ts";
import { memoLast } from "./derived.ts";
import type { Message } from "./model.ts";

type H = HtmlBuilder<Message>;

// Dead rubbers: round 3 of a match already decided. Prizes grow each round, so two round wins beat anything round 3
// can pay another player. Do models write less when the last round cannot change the winner?

/** Round 3 is level after one round each, and decided for both players after two round wins by one of them. */
export type Stake = "level" | "decided";

/** The parts of a seat the rubbers need. */
export type RubberSeat = Pick<SeatFull, "story" | "roundThree" | "seedBlock" | "model" | "effort">;

export const stakeOfRoundThree = (seat: Pick<RubberSeat, "story">): Stake | null => {
  const [first, second, third] = knownRounds(seat);

  if (first === undefined || second === undefined || third === undefined) return null;

  return first.winner === second.winner ? "decided" : "level";
};

export interface RubberRow {
  readonly key: string;
  /** Output tokens per agent move in round 3. */
  readonly level: Rate;
  readonly decided: Rate;
}

/** A config needs this many round 3 moves of each kind to show. */
const MIN_MOVES = 100;

export const rubberRows = memoLast((seats: ReadonlyArray<RubberSeat>): ReadonlyArray<RubberRow> =>
  [...groupBy(seats, keyOf)]
    .flatMap(([key, configSeats]) => {
      const tallies: Record<Stake, BlockTally> = { level: new Map(), decided: new Map() };

      for (const seat of configSeats) {
        const stake = stakeOfRoundThree(seat);
        const [moves = 0, outputTokens = 0] = seat.roundThree ?? [];

        if (stake !== null && moves > 0) addTo(tallies[stake], seat.seedBlock, outputTokens, moves);
      }

      const level = blockRate(tallies.level, 200);
      const decided = blockRate(tallies.decided, 200);

      return level.n >= MIN_MOVES && decided.n >= MIN_MOVES ? [{ key, level, decided }] : [];
    })
    .toSorted((left, right) => left.decided.rate / left.level.rate - right.decided.rate / right.level.rate),
);

const ROW = 20;

const TOP = 26;

const RIGHT = 52;

const change = ({ level, decided }: RubberRow): number => decided.rate / level.rate - 1;

const fmtChange = (value: number): string => `${value < 0 ? "\u2212" : "+"}${Math.abs(Math.round(value * 100))}%`;

/** One row per config: output tokens per move in a level round 3 (ring) and a decided one (dot), on a log scale. */
export const rubbersView = (h: H, rows: ReadonlyArray<RubberRow>, width: number): Html => {
  const labelWidth = Math.min(width * 0.4, 8 + 6.6 * Math.max(0, ...rows.map(({ key }) => labelOf(key).length)));
  const every = rows.flatMap(({ level, decided }) => [level.rate, decided.rate]);
  const x = logScale(Math.min(...every) / 1.3, Math.max(...every) * 1.3, labelWidth + 8, width - RIGHT);
  // A phone has room for the powers of ten only.
  const ticks = x.ticks.filter((tick) => width >= 600 || String(tick).startsWith("1"));
  const height = TOP + rows.length * ROW + 6;

  return h.div(
    [h.Class("chart")],
    [
      h.div([h.Class("lbbar")], [h.h2([], ["Dead rubbers"]), h.span([h.Class("k")], ["output tokens per move in round 3"]), h.span([h.Class("k")], ["\u25CB at 1\u20131 \u00B7 \u25CF after 2\u20130"])]),
      rows.length === 0
        ? h.div([h.Class("empty")], ["No configs have enough round 3 moves for this filter."])
        : h.svg(
            [h.Width(String(width)), h.Height(String(height))],
            [
              ...ticks.flatMap((tick) => [
                h.line([h.Class("grid"), h.X1(String(x.at(tick))), h.X2(String(x.at(tick))), h.Y1(String(TOP - 8)), h.Y2(String(height - 4))], []),
                h.text([h.X(String(x.at(tick))), h.Y("12"), h.TextAnchor("middle")], [String(tick)]),
              ]),
              ...rows.map((row, index) => {
                const color = colorOfKey(row.key);
                const y = TOP + index * ROW + ROW / 2;

                return h.g(
                  [],
                  [
                    h.text([h.X("0"), h.Y(String(y + 4)), h.Style({ fill: color })], [labelOf(row.key)]),
                    h.line([h.X1(String(x.at(row.level.rate))), h.X2(String(x.at(row.decided.rate))), h.Y1(String(y)), h.Y2(String(y)), h.Stroke(color), h.StrokeOpacity("0.5"), h.StrokeWidth("2")], []),
                    tippedDot(h, anchorId("rubbers", row.key, "level"), `${labelOf(row.key)}: ${Math.round(row.level.rate)} tokens per move in round 3 at 1\u20131 (${row.level.n} moves)`, String(x.at(row.level.rate)), String(y), [
                      h.R("4"),
                      h.Fill("#000"),
                      h.Stroke(color),
                      h.StrokeWidth("1.8"),
                    ]),
                    tippedDot(h, anchorId("rubbers", row.key, "decided"), `${labelOf(row.key)}: ${Math.round(row.decided.rate)} tokens per move in round 3 after 2\u20130 (${row.decided.n} moves)`, String(x.at(row.decided.rate)), String(y), [h.R("4"), h.Fill(color)]),
                    h.text([h.X(String(Math.max(x.at(row.level.rate), x.at(row.decided.rate)) + 10)), h.Y(String(y + 4)), h.Style({ fill: "var(--mut)" })], [fmtChange(change(row))]),
                  ],
                );
              }),
            ],
          ),
    ],
  );
};
