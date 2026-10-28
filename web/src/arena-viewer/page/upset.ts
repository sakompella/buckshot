import type { Html, HtmlBuilder } from "foldkit/html";

import { linScale } from "./charts.ts";
import { addTo, type BlockTally, blockRate, fmtPct, keyOf, type MatchRow, meanOf, type Rate, sumOf } from "./data.ts";
import { type Derived, memoLast, ratingsOf } from "./derived.ts";
import type { Message } from "./model.ts";
import type { Rating } from "./ratings.ts";

type H = HtmlBuilder<Message>;

// How much skill matters: matches grouped by the rating gap between the players, each group's share won by the
// higher-rated one, against what the ratings predict.

/** The Bradley-Terry chance that a player rated `gap` Elo above its opponent wins. */
export const winChance = (gap: number): number => 1 / (1 + 10 ** (-gap / 400));

export interface UpsetBin {
  /** Mean rating gap of the group's matches. */
  readonly gap: number;
  /** Mean chance the ratings give the higher-rated player. */
  readonly expected: number;
  /** The higher-rated player's wins over the group's matches. */
  readonly rate: Rate;
}

interface FavouriteGame {
  readonly gap: number;
  readonly block: string;
  readonly share: number;
}

const BINS = 8;

const MIN_PER_BIN = 20;

/** Each completed two-player match between configs of different ratings, as the higher-rated seat's result. */
const favouriteGames = (matches: ReadonlyArray<MatchRow>, ratings: ReadonlyMap<string, Rating>): ReadonlyArray<FavouriteGame> =>
  matches.flatMap(({ status, seats: [first, second, ...rest] }) => {
    const firstRating = first && ratings.get(keyOf(first))?.rating;
    const secondRating = second && ratings.get(keyOf(second))?.rating;

    if (status !== "completed" || !first || !second || rest.length > 0 || firstRating === undefined || secondRating === undefined || firstRating === secondRating) return [];

    const favourite = firstRating > secondRating ? first : second;

    return [{ gap: Math.abs(firstRating - secondRating), block: first.seedBlock, share: favourite.winShare ?? 0 }];
  });

/** The games sorted by gap and cut into equal-sized groups, so every group's interval is about as wide. */
export const upsetBins = (matches: ReadonlyArray<MatchRow>, ratings: ReadonlyMap<string, Rating>): ReadonlyArray<UpsetBin> => {
  const games = favouriteGames(matches, ratings).toSorted((left, right) => left.gap - right.gap);
  const count = Math.min(BINS, Math.floor(games.length / MIN_PER_BIN));

  return Array.from({ length: count }, (_group, index) => games.slice(Math.floor((index * games.length) / count), Math.floor(((index + 1) * games.length) / count))).map((group) => {
    const tally: BlockTally = new Map();

    for (const { block, share } of group) addTo(tally, block, share, 1);

    return { gap: meanOf(group.map(({ gap }) => gap)), expected: meanOf(group.map(({ gap }) => winChance(gap))), rate: blockRate(tally, 200) };
  });
};

/** The page's groups: about winning matches, so they take the match rating whatever the rating choice. */
export const upsetOf = memoLast((derived: Derived): ReadonlyArray<UpsetBin> => upsetBins(derived.matches, ratingsOf(derived.seats)("matches")));

const T = 24;

const B = 44;

const L = 46;

const CURVE_STEPS = 40;

export const upsetView = (h: H, bins: ReadonlyArray<UpsetBin>, width: number): Html => {
  const isNarrow = width < 600;
  const widestBin = bins.at(-1);
  const matches = sumOf(bins.map(({ rate }) => rate.n));
  const favouriteWins = sumOf(bins.map(({ rate }) => rate.k));
  const right = isNarrow ? 12 : 90;
  const height = isNarrow ? 300 : 360;
  const widest = Math.max(...bins.map(({ gap }) => gap));
  const gapMax = Math.ceil((widest * 1.1) / 100) * 100;
  const low = Math.min(0.4, Math.floor(Math.min(...bins.map(({ rate }) => rate.lo)) * 10) / 10);
  const x = linScale(0, gapMax, L, width - right, []);
  const gapTicks = Array.from({ length: Math.floor(gapMax / 100) + 1 }, (_, index) => index * 100);
  const percentTicks = Array.from({ length: Math.round((1 - low) * 10) + 1 }, (_, index) => low + index / 10);
  const y = linScale(low, 1, height - B, T, percentTicks);
  const curve = Array.from({ length: CURVE_STEPS + 1 }, (_, step) => `${step === 0 ? "M" : "L"}${x.at((step / CURVE_STEPS) * gapMax)},${y.at(winChance((step / CURVE_STEPS) * gapMax))}`).join(" ");

  return h.div(
    [h.Class("chart")],
    [
      h.div(
        [h.Class("lbbar")],
        [
          h.h2([], ["How much skill matters"]),
          ...(widestBin === undefined
            ? []
            : [
                h.span([h.Class("k")], [`the higher-rated player won ${fmtPct(favouriteWins / matches)} of ${matches.toLocaleString()} matches`]),
                h.span([h.Class("k")], [`${fmtPct(widestBin.rate.rate)} at the widest gaps (about ${Math.round(widestBin.gap / 10) * 10} Elo)`]),
              ]),
        ],
      ),
      bins.length === 0
        ? h.div([h.Class("empty")], ["Too few matches in this filter."])
        : h.svg(
            [h.Width(String(width)), h.Height(String(height))],
            [
              ...y.ticks.map((tick) =>
                h.g(
                  [],
                  [
                    h.line([h.Class("grid"), h.X1(String(L)), h.X2(String(width - right)), h.Y1(String(y.at(tick))), h.Y2(String(y.at(tick)))], []),
                    h.text([h.X(String(L - 6)), h.Y(String(y.at(tick) + 4)), h.TextAnchor("end")], [fmtPct(tick)]),
                  ],
                ),
              ),
              ...gapTicks.map((tick) => h.text([h.X(String(x.at(tick))), h.Y(String(height - B + 18)), h.TextAnchor("middle")], [String(tick)])),
              h.text([h.X(String((L + width - right) / 2)), h.Y(String(height - 6)), h.TextAnchor("middle")], ["Elo gap between the players"]),
              h.text([h.X(String(L)), h.Y(String(T - 10)), h.TextAnchor("start")], ["higher-rated player's win share"]),
              h.path([h.D(curve), h.Fill("none"), h.Stroke("#8b8b8b"), h.StrokeWidth("1.6"), h.StrokeDasharray("5 4")], []),
              ...(isNarrow ? [] : [h.text([h.X(String(width - right + 8)), h.Y(String(y.at(winChance(gapMax)) + 4))], ["Elo model"])]),
              ...bins.map(({ gap, expected, rate }) =>
                h.g(
                  [],
                  [
                    h.line([h.X1(String(x.at(gap))), h.X2(String(x.at(gap))), h.Y1(String(y.at(rate.lo))), h.Y2(String(y.at(rate.hi))), h.Stroke("#ececec"), h.StrokeOpacity("0.4"), h.StrokeWidth("3")], []),
                    h.circle(
                      [h.Cx(String(x.at(gap))), h.Cy(String(y.at(rate.rate))), h.R("4.5"), h.Fill("#ececec")],
                      [h.title([], [`${rate.n} matches, about ${Math.round(gap)} Elo apart · higher-rated won ${fmtPct(rate.rate)} [${fmtPct(rate.lo)}, ${fmtPct(rate.hi)}] · Elo model ${fmtPct(expected)}`])],
                    ),
                  ],
                ),
              ),
            ],
          ),
    ],
  );
};
