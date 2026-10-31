import type { Html, HtmlBuilder } from "foldkit/html";

import { groupBy, type SeatFull } from "./data.ts";
import { memoLast } from "./derived.ts";
import type { Message } from "./model.ts";

type H = HtmlBuilder<Message>;

/** A completed two-player match, its seats in table order. */
interface Game {
  readonly first: SeatFull;
  readonly second: SeatFull;
}

interface Share {
  readonly wins: number;
  readonly n: number;
}

const gamesOf = (seats: ReadonlyArray<SeatFull>): ReadonlyArray<Game> =>
  [...groupBy(
    seats.filter(({ status }) => status === "completed"),
    ({ matchId }) => matchId,
  ).values()].flatMap((both) => {
    const [first, second, ...rest] = both.toSorted((left, right) => left.position - right.position);

    return first !== undefined && second !== undefined && rest.length === 0 ? [{ first, second }] : [];
  });

const shareOf = (outcomes: ReadonlyArray<number>): Share => ({ wins: outcomes.reduce((total, outcome) => total + outcome, 0), n: outcomes.length });

const starterWon = ({ first, second }: Game): ReadonlyArray<number> => {
  const starter = first.story?.starter;

  if (starter === first.player) return [first.winShare ?? 0];

  return starter === second.player ? [second.winShare ?? 0] : [];
};

const roundOneWinnerWon = ({ first, second }: Game): ReadonlyArray<number> => {
  const winner = (first.winShare ?? 0) >= 1 ? first.player : (second.winShare ?? 0) >= 1 ? second.player : null;
  const story = first.story;

  return winner === null || story === null || !story.ok ? [] : [story.rounds[0]?.winner === winner ? 1 : 0];
};

const balanceOf = memoLast((matchSeats: ReadonlyArray<SeatFull>) => {
  const games = gamesOf(matchSeats);

  return {
    position: shareOf(games.map(({ first }) => first.winShare ?? 0)),
    starter: shareOf(games.flatMap(starterWon)),
    roundOneWinner: shareOf(games.flatMap(roundOneWinnerWon)),
  };
});

const shareView = (h: H, label: string, { wins, n }: Share): Html =>
  h.span([h.Class("dv")], [h.span([h.Class("k")], [`${label} `]), n === 0 ? "–" : `${((wins / n) * 100).toFixed(1)}%`, " ", h.span([h.Class("pm")], [`n ${n.toLocaleString()}`])]);

export const seatBalanceView = (h: H, matchSeats: ReadonlyArray<SeatFull>): Html => {
  const { position, starter, roundOneWinner } = balanceOf(matchSeats);

  return h.div([h.Class("dline seatline")], [h.b([h.Class("dl")], ["Seat balance"]), shareView(h, "position 1", position), shareView(h, "starter", starter), shareView(h, "round-1 winner", roundOneWinner)]);
};
