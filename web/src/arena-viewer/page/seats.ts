import type { Html, HtmlBuilder } from "foldkit/html";

import { addTo, type BlockTally, blockRate, groupBy, keyOf, type Rate, type SeatFull } from "./data.ts";
import { memoLast } from "./derived.ts";
import type { Message } from "./model.ts";

type H = HtmlBuilder<Message>;


/** A completed two-player match, its seats in table order. */
interface Game {
  readonly first: SeatFull;
  readonly second: SeatFull;
}

/** A seed block with both seat orders scored. */
interface Block {
  readonly games: readonly [Game, Game];
}

const gamesOf = (seats: ReadonlyArray<SeatFull>): ReadonlyArray<Game> =>
  [...groupBy(
    seats.filter(({ status }) => status === "completed"),
    ({ matchId }) => matchId,
  ).values()].flatMap((both) => {
    const [first, second, ...rest] = both.toSorted((left, right) => left.position - right.position);

    return first !== undefined && second !== undefined && rest.length === 0 ? [{ first, second }] : [];
  });

const blocksOf = (games: ReadonlyArray<Game>): ReadonlyArray<Block> =>
  [...groupBy(games, ({ first }) => first.seedBlock).values()].flatMap((pair) => {
    const [one, two, ...rest] = pair;

    return one === undefined || two === undefined || rest.length > 0 || keyOf(one.first) !== keyOf(two.second) || keyOf(one.second) !== keyOf(two.first) ? [] : [{ games: [one, two] as const }];
  });

const shareOver = (blocks: ReadonlyArray<Block>, value: (game: Game) => number): Rate => {
  const tally: BlockTally = new Map();

  blocks.forEach((block, index) => block.games.forEach((game) => addTo(tally, String(index), value(game), 1)));

  return blockRate(tally, 1000);
};

/** The round-1 starter's win share, or NaN when the story does not name a starter. */
const starterShare = ({ first, second }: Game): number => {
  const starter = first.story?.starter;

  if (starter === first.player) return first.winShare ?? 0;

  return starter === second.player ? (second.winShare ?? 0) : Number.NaN;
};

const roundOneWinnerShare = (games: ReadonlyArray<Game>): Pick<Rate, "rate" | "n"> => {
  const decided = games.flatMap(({ first, second }) => {
    const winner = (first.winShare ?? 0) >= 1 ? first.player : (second.winShare ?? 0) >= 1 ? second.player : null;
    const story = first.story;

    return winner === null || story === null || !story.ok ? [] : [story.rounds[0]?.winner === winner];
  });

  const wins = decided.filter(Boolean).length;

  return { n: decided.length, rate: wins / decided.length };
};

const balanceOf = memoLast((matchSeats: ReadonlyArray<SeatFull>) => {
  const games = gamesOf(matchSeats);
  const blocks = blocksOf(games);

  return {
    position: shareOver(blocks, ({ first }) => first.winShare ?? 0),
    starter: shareOver(
      blocks.filter((block) => block.games.every((game) => !Number.isNaN(starterShare(game)))),
      starterShare,
    ),
    roundOneWinner: roundOneWinnerShare(games),
  };
});

const shareView = (h: H, label: string, rate: Pick<Rate, "rate" | "n">): Html =>
  h.span([h.Class("dv")], [h.span([h.Class("k")], [`${label} `]), Number.isNaN(rate.rate) ? "–" : `${(rate.rate * 100).toFixed(1)}%`, " ", h.span([h.Class("pm")], [`n ${rate.n.toLocaleString()}`])]);

export const seatBalanceView = (h: H, matchSeats: ReadonlyArray<SeatFull>): Html => {
  const { position, starter, roundOneWinner } = balanceOf(matchSeats);

  return h.div([h.Class("dline seatline")], [h.b([h.Class("dl")], ["Seat balance"]), shareView(h, "position 1", position), shareView(h, "starter", starter), shareView(h, "round-1 winner", roundOneWinner)]);
};
