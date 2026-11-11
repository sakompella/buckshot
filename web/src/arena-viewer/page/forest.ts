import type { Html, HtmlBuilder } from "foldkit/html";

import { fmtRating, isClaude, isEngine } from "./data.ts";
import type { Derived, ModelStats } from "./derived.ts";
import { inRankOrder } from "./leaderboard.ts";
import type { Message } from "./model.ts";
import type { Rating } from "./ratings.ts";

type H = HtmlBuilder<Message>;

// The first chart: every ranked config's Round Elo with its 95% interval, best first, and the search engines as
// labelled reference lines. Overlapping bars show what the data cannot order.

interface Rated {
  readonly m: ModelStats;
  readonly elo: Rating;
}

const STEP = 50;

const scaleOf = (rated: ReadonlyArray<Rated>) => {
  const ends = rated.flatMap(({ elo }) => [elo.rating, elo.interval?.lo ?? elo.rating, elo.interval?.hi ?? elo.rating]);
  const from = Math.floor(Math.min(0, ...ends) / STEP) * STEP;
  const to = Math.ceil(Math.max(0, ...ends) / STEP) * STEP;

  return { at: (elo: number) => ((elo - from) / (to - from)) * 100, ticks: Array.from({ length: (to - from) / STEP + 1 }, (_, index) => from + index * STEP) };
};

const ratedOf = (stats: ReadonlyArray<ModelStats>, ratings: ReadonlyMap<string, Rating>): ReadonlyArray<Rated> =>
  stats.flatMap((m) => {
    const elo = ratings.get(m.key);

    return elo === undefined ? [] : [{ m, elo }];
  });

export const forestView = (h: H, derived: Derived): Html => {
  const ranked = inRankOrder(derived.pooled, derived.ranks, derived.ratings).filter(({ key }) => derived.ranks.has(key));
  const rows = ratedOf(ranked.filter(({ model }) => !isEngine(model)), derived.ratings);
  const anchors = ratedOf(ranked.filter(({ model }) => isEngine(model)), derived.ratings);

  if (rows.length === 0) return h.p([h.Class("k")], ["No ranked config for this filter."]);

  const scale = scaleOf([...rows, ...anchors]);
  const left = (elo: number) => ({ left: `${scale.at(elo)}%` });
  const lines = [h.div([h.Class("fzero"), h.Style(left(0))], []), ...anchors.map(({ elo }) => h.div([h.Class("fanchor"), h.Style(left(elo.rating))], []))];

  const row = (name: ReadonlyArray<Html | string>, track: ReadonlyArray<Html>, value: ReadonlyArray<Html | string>, className = "frow") =>
    h.div([h.Class(className)], [h.span([h.Class("fname")], name), h.div([h.Class("ftrack")], [...lines, ...track]), h.span([h.Class("fval")], value)]);

  return h.div(
    [h.Class("forest"), h.Role("img"), h.AriaLabel("Round Elo of each ranked config with its 95% interval")],
    [
      ...anchors.map(({ m, elo }) =>
        row([], [h.span([h.Class(scale.at(elo.rating) > 50 ? "falabel end" : "falabel"), h.Style(left(elo.rating))], [`${m.label} ${fmtRating(elo.rating)}`])], [], "frow fhead"),
      ),
      ...rows.map(({ m, elo }) =>
        row(
          [m.label],
          [
            ...(elo.interval === null ? [] : [h.div([h.Class("fci"), h.Style({ left: `${scale.at(elo.interval.lo)}%`, width: `${scale.at(elo.interval.hi) - scale.at(elo.interval.lo)}%`, background: m.color })], [])]),
            h.div([h.Class(`fdot ${isClaude(m.model) ? "a" : "o"}`), h.Style({ ...left(elo.rating), background: m.color })], []),
          ],
          [fmtRating(elo.rating), ...(elo.interval === null ? [] : [h.span([h.Class("pm")], [` [${Math.round(elo.interval.lo)}, ${Math.round(elo.interval.hi)}]`])])],
        ),
      ),
      row([], [h.div([h.Class("faxis")], scale.ticks.map((tick) => h.span([h.Style(left(tick))], [fmtRating(tick)])))], [], "frow ffoot"),
    ],
  );
};
