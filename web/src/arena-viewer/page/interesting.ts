import { Option } from "effect";
import { AsyncData } from "foldkit";
import type { Html, HtmlBuilder } from "foldkit/html";

import { patternBit } from "../api.ts";
import { colorOf, fmtUsd, keyOf, labelOf, type MatchRow, type SeatFull, sumOf, winnerOf } from "./data.ts";
import { type Derived, memoLast } from "./derived.ts";
import { Message, type Model } from "./model.ts";
import { moveStripView } from "./replay.ts";

type H = HtmlBuilder<Message>;

// A few notable matches, each a card with a strip of its moves.

export interface Pick {
  readonly title: string;
  readonly stat: string;
  readonly match: MatchRow;
  readonly maybeFocus: Option.Option<number>;
}

const maxBy = <A>(items: ReadonlyArray<A>, score: (item: A) => number): { readonly item: A; readonly value: number } | null =>
  items.reduce<{ readonly item: A; readonly value: number } | null>((best, item) => {
    const value = score(item);

    return best === null || value > best.value ? { item, value } : best;
  }, null);

/** The winner's worst cash deficit after any round but the last, and the round it happened. */
const cashDeficit = (match: MatchRow, winner: SeatFull): readonly [number, number] => {
  const story = winner.story;

  if (story === null || !story.ok) return [0, 0];

  const cash = new Map<string, number>();
  let worst: readonly [number, number] = [0, 0];

  story.rounds.slice(0, -1).forEach((round, index) => {
    cash.set(round.winner, (cash.get(round.winner) ?? 0) + round.prize);
    const behind = Math.max(...match.seats.map(({ player }) => cash.get(player) ?? 0)) - (cash.get(winner.player) ?? 0);

    if (behind > worst[0]) worst = [behind, index + 1];
  });

  return worst;
};

const GLASS_BLANK_OPP = patternBit("glassBlankOpp");

export const picksOf = memoLast((derived: Derived): ReadonlyArray<Pick> => {
  const { matches, ratings, decisions, seats, keep } = derived;
  const done = matches.filter((match) => match.status === "completed" && match.seats.length === 2);

  const won = done.flatMap((match) => {
    const winner = winnerOf(match);
    const loser = match.seats.find((seat) => seat !== winner);

    return winner === undefined || loser === undefined ? [] : [{ match, winner, loser }];
  });

  const ratingOf = (seat: SeatFull) => ratings.get(keyOf(seat)) ?? 0;
  const picks: Array<Pick> = [];

  // Comeback: the winner's worst health deficit in the deciding round, then its worst cash deficit after a round.
  const comeback = maxBy(won, ({ match, winner }) => (winner.low ? winner.low[1] - winner.low[0] : 0) * 1e7 + cashDeficit(match, winner)[0]);
  const low = comeback?.item.winner.low ?? null;

  if (comeback !== null && low !== null) picks.push({ title: "Biggest comeback", stat: `${labelOf(keyOf(comeback.item.winner))} won from ${low[0]} health vs ${low[1]} in round ${low[2]}`, match: comeback.item.match, maybeFocus: Option.none() });

  const sweeps = won.filter(({ winner }) => {
    const rounds = winner.story?.rounds ?? [];

    return rounds.length >= 3 && rounds.every((round) => round.winner === winner.player);
  });

  const sweep = maxBy(sweeps, ({ winner, loser }) => ratingOf(loser) - ratingOf(winner));

  if (sweep !== null && sweep.value > 0) picks.push({ title: "Underdog 3–0", stat: `${labelOf(keyOf(sweep.item.winner))}, rated ${Math.round(sweep.value)} lower, won every round`, match: sweep.item.match, maybeFocus: Option.none() });

  const longest = maxBy(done, (match) => sumOf(match.seats.map(({ moves }) => moves ?? 0)));

  if (longest !== null) picks.push({ title: "Longest match", stat: `${longest.value} model moves`, match: longest.item, maybeFocus: Option.none() });

  const priciest = maxBy(done, (match) => sumOf(match.seats.map(({ cost }) => cost ?? 0)));

  if (priciest !== null) picks.push({ title: "Most expensive", stat: fmtUsd(priciest.value), match: priciest.item, maybeFocus: Option.none() });

  const byId = new Map(done.map((match) => [match.matchId, match]));
  let blunder: { readonly move: number; readonly score: number } | null = null;

  for (const [move, seatIndex] of decisions.seat.entries()) {
    const seat = seats[seatIndex];

    if (seat === undefined || !((decisions.pick[move] ?? 0) & GLASS_BLANK_OPP) || keep[seatIndex] !== true || !byId.has(seat.matchId) || (seat.winShare ?? 0) > 0) continue;

    // Prefer a move with reasoning text to read, then the strongest config.
    const score = ratingOf(seat) + ((decisions.rc[move] ?? 0) > 0 ? 1e6 : 0);

    if (blunder === null || score > blunder.score) blunder = { move, score };
  }

  const blunderSeat = blunder === null ? undefined : seats[decisions.seat[blunder.move] ?? -1];
  const blunderMatch = blunderSeat === undefined ? undefined : byId.get(blunderSeat.matchId);

  if (blunder !== null && blunderSeat !== undefined && blunderMatch !== undefined)
    picks.push({ title: "Known-blank blunder", stat: `${labelOf(keyOf(blunderSeat))} saw a blank, shot the opponent, lost`, match: blunderMatch, maybeFocus: Option.fromUndefinedOr(decisions.ord[blunder.move]) });

  return picks;
});

const CARD_MIN = 260;

const CARD_GAP = 14;

/** The strip's width inside one card of a grid `width` wide: the grid fills columns of at least CARD_MIN. */
const stripWidth = (width: number): number => {
  const columns = Math.max(1, Math.floor((width + CARD_GAP) / (CARD_MIN + CARD_GAP)));

  return Math.max(0, Math.floor((width - CARD_GAP * (columns - 1)) / columns - 28 - 2));
};

const cardView = (h: H, pick: Pick, data: Model["matches"][string] | undefined, width: number): Html => {
  const winner = winnerOf(pick.match);
  const strip = data === undefined ? null : AsyncData.getOrElse(AsyncData.map(data, (detail): Html => moveStripView(h, detail, stripWidth(width))), () => null);

  return h.keyed("div")(
    pick.title,
    [h.Class("icard"), h.OnClick(Message.ClickedMatch({ id: pick.match.matchId, maybeFocus: pick.maybeFocus }))],
    [
      h.div([h.Class("ititle")], [pick.title]),
      h.div(
        [h.Class("ivs")],
        pick.match.seats.flatMap((seat, index) => [
          index > 0 ? h.span([h.Class("k")], [" vs "]) : h.empty,
          h.span([h.Style({ color: colorOf(seat.model, seat.effort), "font-weight": seat === winner ? "600" : "400" })], [labelOf(keyOf(seat))]),
        ]),
      ),
      h.div([h.Class("k")], [pick.stat]),
      strip ?? h.div([h.Style({ height: "26px" })], []),
    ],
  );
};

export const interestingView = (h: H, picks: ReadonlyArray<Pick>, matches: Model["matches"], width: number): Html =>
  picks.length === 0
    ? h.empty
    : h.section([], [h.h2([], ["Interesting matches"]), h.div([h.Class("igrid")], picks.map((pick) => cardView(h, pick, matches[pick.match.matchId], width)))]);
