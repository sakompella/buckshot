import type { Html, HtmlBuilder } from "foldkit/html";

import type { Pair } from "../aggregates.ts";
import { sumOf } from "./data.ts";
import { memoLast } from "./derived.ts";
import type { Message } from "./model.ts";

type H = HtmlBuilder<Message>;

interface Share {
  readonly wins: number;
  readonly n: number;
}

const shareOf = (pairs: ReadonlyArray<Pair>, wins: (pair: Pair) => number, n: (pair: Pair) => number): Share => ({ wins: sumOf(pairs.map(wins)), n: sumOf(pairs.map(n)) });

/** Over the scored two-player matches: position 1's win share, the round-1 starter's, and how often the round-1 winner won. */
const balanceOf = memoLast((pairs: ReadonlyArray<Pair>) => ({
  position: shareOf(pairs, ({ firstWins }) => firstWins, ({ scored }) => scored),
  starter: shareOf(pairs, ({ starterWins }) => starterWins, ({ starts }) => starts),
  roundOneWinner: shareOf(pairs, ({ roundOneWins }) => roundOneWins, ({ roundOnes }) => roundOnes),
}));

const shareView = (h: H, label: string, { wins, n }: Share): Html =>
  h.span([h.Class("dv")], [h.span([h.Class("k")], [`${label} `]), n === 0 ? "–" : `${((wins / n) * 100).toFixed(1)}%`, " ", h.span([h.Class("pm")], [`n ${n.toLocaleString()}`])]);

export const seatBalanceView = (h: H, pairs: ReadonlyArray<Pair>): Html => {
  const { position, starter, roundOneWinner } = balanceOf(pairs);

  return h.div([h.Class("dline seatline")], [h.b([h.Class("dl")], ["Seat balance"]), shareView(h, "position 1", position), shareView(h, "starter", starter), shareView(h, "round-1 winner", roundOneWinner)]);
};
