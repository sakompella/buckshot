import { Option } from "effect";
import { AsyncData } from "foldkit";
import type { Html, HtmlBuilder } from "foldkit/html";

import { type Decisions, NO_GAP } from "../api.ts";
import { anchorId, tipView } from "./charts.ts";
import { fmtCount, fmtPct, groupBy, keyOf, labelOf, MIN_BLOCKS_FOR_INTERVAL, type ModelStats, type SeatFull, sumOf } from "./data.ts";
import { type Derived, memoLast } from "./derived.ts";
import { itemBarsView } from "./fates.ts";
import { Message, type Model } from "./model.ts";

type H = HtmlBuilder<Message>;

const resultOf = (seat: SeatFull): string => {
  const share = seat.winShare ?? 0;

  if (share >= 1) return "Win";

  return share > 0 ? `Split ${fmtPct(share)}` : "Loss";
};

/** Every scored match of one config, grouped by opponent: one square per match, filled by win share. */
const headToHeadView = (h: H, m: ModelStats, seats: ReadonlyArray<SeatFull>, maybeTip: Option.Option<string>): Html => {
  const mine = new Map(m.scored.map((seat) => [seat.matchId, seat]));
  const opponents = new Map(seats.flatMap((seat) => (mine.has(seat.matchId) && mine.get(seat.matchId)?.player !== seat.player ? [[seat.matchId, seat] as const] : [])));

  const games = m.scored.flatMap((seat) => {
    const opponent = opponents.get(seat.matchId);

    return opponent === undefined ? [] : [{ seat, opponent }];
  });

  const groups = [...groupBy(games, ({ opponent }) => keyOf(opponent))]
    .map(([key, rows]) => ({ key, rows, share: sumOf(rows.map(({ seat }) => seat.winShare ?? 0)) / rows.length }))
    .toSorted((left, right) => right.rows.length - left.rows.length || right.share - left.share);

  const fill = (seat: SeatFull) => {
    const share = seat.winShare ?? 0;

    if (share >= 1) return m.color;

    return share > 0 ? `color-mix(in srgb, ${m.color} 45%, #1a1a1a)` : "#1a1a1a";
  };

  const tip = Option.flatMap(maybeTip, (matchId) => Option.fromUndefinedOr(games.find(({ seat }) => seat.matchId === matchId)));

  return h.div(
    [],
    [
      ...groups.map((group) =>
        h.keyed("div")(
          group.key,
          [h.Class("opp")],
          [
            h.span([h.Class("on")], [`vs ${labelOf(group.key)}`]),
            h.span([h.Class("ow")], [`${fmtPct(group.share)} `, h.span([h.Class("pm")], [`of ${group.rows.length}`])]),
            h.span(
              [h.Class("sq")],
              group.rows.map(({ seat }) =>
                h.keyed("i")(
                  seat.matchId,
                  [
                    h.Id(anchorId("sq", seat.matchId)),
                    h.Style({ background: fill(seat) }),
                    h.OnMouseEnter(Message.HoveredSquare({ matchId: seat.matchId })),
                    h.OnMouseLeave(Message.LeftSquare()),
                    h.OnClick(Message.ClickedMatch({ id: seat.matchId, maybeFocus: Option.none() })),
                  ],
                  [],
                ),
              ),
            ),
          ],
        ),
      ),
      Option.match(tip, {
        onNone: () => h.empty,
        onSome: ({ seat, opponent }) =>
          tipView(h, anchorId("sq", seat.matchId), [
            h.b([], [resultOf(seat)]),
            ` vs ${labelOf(keyOf(opponent))}`,
            h.br([]),
            `seed ${seat.seed} · $${seat.cash?.toLocaleString() ?? ""} vs $${opponent.cash?.toLocaleString() ?? ""}`,
          ]),
      }),
    ],
  );
};

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

export const drillView = (h: H, m: ModelStats, derived: Derived, maybeTip: Model["leaderboard"]["maybeTip"]): Html =>
  h.div(
    [h.Class("drillin")],
    [
      h.div([h.Class("dhead")], ["Head-to-head"]),
      headToHeadView(h, m, derived.matchSeats, maybeTip),
      consistencyLineView(h, derived.consistency, m.key, m.win.blocks >= MIN_BLOCKS_FOR_INTERVAL),
      gapLineView(h, derived.decisions, derived.seats, m.key),
      h.div([h.Class("dhead")], ["Items"]),
      itemBarsView(h, derived.seats, m.started, m.color, m.key),
    ],
  );
