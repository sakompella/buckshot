import { Option } from "effect";
import type { Html, HtmlBuilder } from "foldkit/html";

import { type Blunders, BLUNDER_POINTS } from "../api.ts";
import { chartWidth, pressable } from "./charts.ts";
import { addTo, type BlockTally, blockRate, colorOf, fmtPoints, groupBy, keyOf, labelOf, type Rate, type SeatFull } from "./data.ts";
import { memoLast } from "./derived.ts";
import { Message } from "./model.ts";
import type { Rating } from "./ratings.ts";
import { configBarsView, rateBar } from "./reliability.ts";

type H = HtmlBuilder<Message>;

// Blunders: the share of each config's searched moves that gave up BLUNDER_POINTS or more, and the costliest ones.

type RateSeat = Pick<SeatFull, "model" | "effort" | "seedBlock" | "regret">;

export interface BlunderRate {
  readonly key: string;
  readonly rate: Rate;
}

/** The blunder rate of every config with a searched move among the kept seats, lowest first, with a seed-block interval. */
export const blunderRates = (seats: ReadonlyArray<RateSeat>, keep: ReadonlyArray<boolean>, blunders: Blunders): ReadonlyArray<BlunderRate> => {
  const perSeat = new Map<number, number>();

  for (const seat of blunders.seat) perSeat.set(seat, (perSeat.get(seat) ?? 0) + 1);

  const tallies = new Map<string, BlockTally>();

  seats.forEach((seat, index) => {
    if (keep[index] !== true || seat.regret === null) return;

    const tally = tallies.get(keyOf(seat)) ?? new Map();

    tallies.set(keyOf(seat), tally);
    addTo(tally, seat.seedBlock, perSeat.get(index) ?? 0, seat.regret.moves);
  });

  return [...tallies].map(([key, tally]) => ({ key, rate: blockRate(tally, 300) })).toSorted((left, right) => left.rate.rate - right.rate.rate);
};

type CardSeat = Pick<SeatFull, "model" | "effort" | "matchId" | "player">;

export interface BlunderCard<S extends CardSeat = SeatFull> {
  readonly seat: S;
  readonly opponent: S | undefined;
  readonly ordinal: number;
  readonly points: number;
  readonly isExact: boolean;
  readonly chosen: string;
  readonly best: string;
  readonly bestScore: number;
  readonly chosenScore: number;
}

/**
 * The costliest kept blunders: proven exact ones first, then by points, then by the config's rating, so ties go to the
 * strongest play. At most one card per config and per match, so the gallery shows variety.
 */
export const galleryOf = <S extends CardSeat>(seats: ReadonlyArray<S>, keep: ReadonlyArray<boolean>, ratings: ReadonlyMap<string, Pick<Rating, "rating">>, blunders: Blunders, count: number): ReadonlyArray<BlunderCard<S>> => {
  const bySeat = groupBy(seats, ({ matchId }) => matchId);
  const ratingOf = (seat: S) => ratings.get(keyOf(seat))?.rating ?? Number.NEGATIVE_INFINITY;

  const cards = blunders.seat.flatMap((seatIndex, at): ReadonlyArray<BlunderCard<S>> => {
    const seat = seats[seatIndex];

    if (seat === undefined || keep[seatIndex] !== true) return [];

    return [
      {
        seat,
        opponent: bySeat.get(seat.matchId)?.find(({ player }) => player !== seat.player),
        ordinal: blunders.ord[at] ?? 0,
        points: blunders.points[at] ?? 0,
        isExact: blunders.exact[at] === 1,
        chosen: blunders.labels[blunders.chosen[at] ?? -1] ?? "",
        best: blunders.labels[blunders.best[at] ?? -1] ?? "",
        bestScore: blunders.bestScore[at] ?? 0,
        chosenScore: blunders.chosenScore[at] ?? 0,
      },
    ];
  });

  const ordered = cards.toSorted((left, right) => Number(right.isExact) - Number(left.isExact) || right.points - left.points || ratingOf(right.seat) - ratingOf(left.seat));
  const configs = new Set<string>();
  const matches = new Set<string>();
  const picked: Array<BlunderCard<S>> = [];

  for (const card of ordered) {
    if (picked.length === count) break;

    if (configs.has(keyOf(card.seat)) || matches.has(card.seat.matchId)) continue;

    configs.add(keyOf(card.seat));
    matches.add(card.seat.matchId);
    picked.push(card);
  }

  return picked;
};

const GALLERY_SIZE = 6;

export const ratesFor = memoLast(blunderRates);

/** Every config whatever the filter: the chart's fixed scale. */
export const everyRateFor = memoLast((seats: ReadonlyArray<SeatFull>, blunders: Blunders) => blunderRates(seats, seats.map(() => true), blunders));

export const galleryFor = memoLast((seats: ReadonlyArray<SeatFull>, keep: ReadonlyArray<boolean>, ratings: ReadonlyMap<string, Rating>, blunders: Blunders) => galleryOf(seats, keep, ratings, blunders, GALLERY_SIZE));

const cardView = (h: H, card: BlunderCard): Html =>
  h.keyed("div")(
    `${card.seat.matchId}|${card.ordinal}`,
    [h.Class("icard"), ...pressable(h, Message.ClickedMatch({ id: card.seat.matchId, maybeFocus: Option.some(card.ordinal) }))],
    [
      h.div([h.Class("ititle"), h.Style({ color: colorOf(card.seat.model) })], [labelOf(keyOf(card.seat))]),
      h.div(
        [h.Class("ivs")],
        card.opponent === undefined ? [] : [h.span([h.Class("k")], ["vs "]), h.span([h.Style({ color: colorOf(card.opponent.model) })], [labelOf(keyOf(card.opponent))])],
      ),
      h.div([], [card.chosen, h.span([h.Class("k")], [` instead of ${card.best}`])]),
      h.div(
        [h.Class("k")],
        [
          `Round win chance ${fmtPoints(card.bestScore)}% → ${fmtPoints(card.chosenScore)}% `,
          h.span([h.Class(`tag regret big ${card.isExact ? "exact" : ""}`)], [`−${fmtPoints(card.points)} · ${card.isExact ? "exact" : "estimated"}`]),
        ],
      ),
    ],
  );

/** The costliest blunders as cards that open the replay at the move. */
export const blunderCardsView = (h: H, cards: ReadonlyArray<BlunderCard>): Html =>
  cards.length === 0 ? h.empty : h.div([], [h.h2([], ["Blunders"]), h.div([h.Class("bgrid")], cards.map((card) => cardView(h, card)))]);

/** Every config's blunder rate, on a scale fixed by every config whatever the filter. */
export const blunderRatesView = (h: H, rates: ReadonlyArray<BlunderRate>, every: ReadonlyArray<BlunderRate>, width: number, content: number): Html =>
  rates.length === 0
    ? h.empty
    : h.div(
        [h.Class("card chart")],
        [
          h.div([h.Class("lbbar")], [h.h2([], ["Blunder rate"]), h.span([h.Class("k")], [`share of searched moves that gave up ${BLUNDER_POINTS}+ points`])]),
          configBarsView(h, "blunders", rates, every, (row) => rateBar(row.rate, 100, 1, "%", "searched moves"), (value) => `${value}%`, Math.min(content, chartWidth(width, content) * 2)),
        ],
      );
