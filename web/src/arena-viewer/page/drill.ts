import { AsyncData } from "foldkit";
import type { Html, HtmlBuilder } from "foldkit/html";

import { type Decisions, NO_GAP } from "../api.ts";
import { fmtCount, fmtPct, keyOf, MIN_BLOCKS_FOR_INTERVAL, type ModelStats, type SeatFull } from "./data.ts";
import { type Derived, memoLast } from "./derived.ts";
import { itemBarsView } from "./fates.ts";
import type { Message } from "./model.ts";

type H = HtmlBuilder<Message>;

const GAPS: ReadonlyArray<readonly [number, string]> = [
  [-2, "behind 2+"],
  [-1, "behind 1"],
  [0, "level"],
  [1, "ahead 1"],
  [2, "ahead 2+"],
];

const MIN_MOVES = 30;

interface GapTokens {
  readonly moves: number;
  readonly tokens: number;
}

const tokensByGap = memoLast((decisions: Decisions, seats: ReadonlyArray<SeatFull>, key: string): ReadonlyArray<GapTokens> => {
  const [lowest = 0] = GAPS[0] ?? [];
  const [highest = 0] = GAPS.at(-1) ?? [];
  const tallies = GAPS.map(() => ({ moves: 0, out: 0 }));

  decisions.seat.forEach((seatIndex, move) => {
    const seat = seats[seatIndex];
    const gap = decisions.gap[move] ?? NO_GAP;
    const tally = tallies[Math.max(lowest, Math.min(highest, gap)) - lowest];

    if (seat === undefined || tally === undefined || gap === NO_GAP || keyOf(seat) !== key) return;

    tally.moves++;
    tally.out += decisions.out[move] ?? 0;
  });

  return tallies.map(({ moves, out }) => ({ moves, tokens: moves === 0 ? 0 : out / moves }));
});

const lineView = (h: H, label: string, content: ReadonlyArray<Html | string>): Html => h.div([h.Class("dline")], [h.span([h.Class("dl")], [label]), ...content]);

const gapLineView = (h: H, decisions: Decisions, seats: ReadonlyArray<SeatFull>, key: string): Html =>
  lineView(
    h,
    "Output tokens per move by health gap",
    tokensByGap(decisions, seats, key).map(({ moves, tokens }, index) =>
      h.span([h.Class("dv"), ...(moves < MIN_MOVES ? [] : [h.Title(`${moves.toLocaleString()} moves`)])], [h.span([h.Class("k")], [`${GAPS[index]?.[1] ?? ""} `]), moves < MIN_MOVES ? "–" : fmtCount(tokens)]),
    ),
  );

const consistencyLineView = (h: H, consistency: Derived["consistency"], key: string, hasInterval: boolean): Html =>
  AsyncData.matchData(consistency, {
    onEmpty: () => h.empty,
    onFailure: (error) => lineView(h, "Same position, same move", [h.span([h.Class("dv")], [`Could not load the consistency: ${error}`])]),
    onData: (rows) => {
      if (rows.length === 0) return h.empty;

      const row = rows.find((candidate) => keyOf(candidate) === key);

      return lineView(
        h,
        "Same position, same move",
        row === undefined
          ? ["–"]
          : [h.span([h.Class("dv")], [fmtPct(row.agree), " ", h.span([h.Class("pm")], [`${hasInterval ? `[${fmtPct(row.lo)}, ${fmtPct(row.hi)}] ` : ""}over ${row.positions.toLocaleString()} positions`])])],
      );
    },
  });

export const drillView = (h: H, m: ModelStats, derived: Derived): Html =>
  h.div(
    [h.Class("drillin")],
    [
      consistencyLineView(h, derived.consistency, m.key, m.win.blocks >= MIN_BLOCKS_FOR_INTERVAL),
      gapLineView(h, derived.decisions, derived.seats, m.key),
      h.div([h.Class("dhead")], ["Items"]),
      itemBarsView(h, derived.seats, m.started, m.color, m.key),
    ],
  );
