import { Effect, Option, Schema } from "effect";
import { Command } from "foldkit";
import type { Html, HtmlBuilder } from "foldkit/html";

import { Message, type Section, type Tour } from "./model.ts";
import { stickyHeight } from "./view.ts";

type H = HtmlBuilder<Message>;

// The guided tour: hidden until the jump menu's Tour button starts it. Each step scrolls to an element, highlights
// it and shows a short card. The page itself carries no descriptions.

/**
 * One stop. `focus` is a CSS selector for the element to highlight: the first match the page draws, so a list can name
 * a wide screen's element before a phone's. When nothing matches, the step highlights its section.
 */
export interface TourStep {
  readonly anchor: Section;
  readonly focus: string;
  readonly title: string;
  readonly text: string;
}

export const TOUR: ReadonlyArray<TourStep> = [
  {
    anchor: "scatter",
    focus: ".filters",
    title: "Filters",
    text: "The cohort menu and the model and effort chips apply to the whole page. A cohort is one kind of comparison, so pick one to compare like with like.",
  },
  {
    anchor: "scatter",
    focus: "#scatter .ctl > .toggle:nth-child(2)",
    title: "What the rating counts",
    text: "Round wins counts each round as one game, Match wins each match's win share and Cash each player's pot share; Round wins is becoming the default. The choice carries to every rating on the page.",
  },
  {
    anchor: "scatter",
    focus: "#scatter .ctl > .toggle:nth-child(3)",
    title: "Elo / Rank",
    text: "Elo is one Bradley-Terry rating per config, pooled over every tournament; Rank is a place, first at the top. Check the leaderboards' intervals before calling a small gap real.",
  },
  {
    anchor: "scatter",
    focus: "#scatter > div > .card:nth-child(1)",
    title: "Cost, Moves, Tokens, Regret",
    text: "Each point is a config, a model at one effort; the x axis is its cost, model moves or output tokens per match, or its regret, an estimate of the round win chance its moves gave up (lower is better). Look for configs rated alike that sit far apart.",
  },
  {
    anchor: "scatter",
    focus: "#scatter > div > .card:nth-child(2)",
    title: "Effort vs Elo",
    text: "One line per model across its efforts, from off to max, each rating with its interval. Trust only steps larger than the intervals.",
  },
  {
    anchor: "scatter",
    focus: "#scatter > div > .card:nth-child(3)",
    title: "Where the money went",
    text: "Each config's share of the spend, grouped by model, under the current filters. Look for how much of the bill a single config takes.",
  },
  {
    anchor: "interesting",
    focus: "#interesting .igrid",
    title: "Interesting matches",
    text: "A few matches worth a look, such as the biggest comeback or an underdog sweep. A click opens the replay.",
  },
  {
    anchor: "luck",
    focus: "#luck .luckrow",
    title: "Won with higher estimated regret",
    text: "How often the player whose moves gave up more estimated round-win chance still won the match, per move, in total and without tiny gaps, and the lower-regret player's win share by the gap. An estimate is not a measure of luck.",
  },
  {
    anchor: "luck",
    focus: "#luck > div > .card:nth-child(2)",
    title: "Rating gap and results",
    text: "How often the higher-rated config won, by rating gap, against the Bradley-Terry curve. Each match is rated by a fit that held its seed block out, so the curve is tested on matches the ratings did not see.",
  },
  {
    anchor: "luck",
    focus: "#luck > div > .card:nth-child(3)",
    title: "Results after round 1",
    text: "The dot is a config's share of round 2 after winning round 1, the ring its share of round 3 at one round each, the tick its round share. Few trials stand behind each dot, so most gaps are noise.",
  },
  {
    anchor: "seats",
    focus: "#seats .chartrow",
    title: "Seats",
    text: "Whether table position and starting round 1 matter: round 1 to the match, comebacks and the starter's edge per seed. The full tables fold under the charts.",
  },
  {
    anchor: "deals",
    focus: "#deals .card",
    title: "Results on each seed",
    text: "One row per seed and one column per config; the top bar is its wins from table position 1, the bottom from position 2. Look for rows where one position nearly always wins.",
  },
  {
    anchor: "blunders",
    focus: "#blunders .bgrid",
    title: "Blunders",
    text: "The moves that gave up the most round win chance, with the move chosen and the best move. A click opens the replay at that move.",
  },
  {
    anchor: "blunders",
    focus: "#blunders .chart",
    title: "Blunder rate",
    text: "Each config's share of its searched moves that were blunders, with intervals, best on top. The bars say more than any single card.",
  },
  {
    anchor: "mistakes",
    focus: "#mistakes > div > .card:nth-child(1)",
    title: "Regret by shells left",
    text: "Mean regret per move by shells left in the gun, shots on the left and every other move on the right, one line per model. Compare the shots' peak with the flat panel beside it.",
  },
  {
    anchor: "mistakes",
    focus: "#mistakes > div > .card:nth-child(2)",
    title: "Same position, same move",
    text: "How often a config chose the same move when it met the same position again, in the chosen cohort, with the count of repeated positions. It measures steadiness, not good play.",
  },
  {
    anchor: "odds",
    focus: "#odds .chartrow figure:first-child",
    title: "Playing the odds",
    text: "How often a config shoots itself against the chance, by its own count, that the shell is live, one panel per model and a line per effort. A model that counts shells shoots itself on a sure blank.",
  },
  {
    anchor: "items",
    focus: "#items .chartrow",
    title: "Item fates",
    text: "What became of the items each config received: used, stolen by the opponent or left unused, by config and by item. Look for the items most often left unused.",
  },
  {
    anchor: "pressure",
    focus: "#pressure .chartrow figure:first-child",
    title: "Output tokens by health gap",
    text: "Output tokens per move by health gap, as a multiple of the config's own amount at level health, one panel per model. A line sloping down writes less when ahead, though positions behind are also harder.",
  },
  {
    anchor: "rubbers",
    focus: "#rubbers .card",
    title: "Dead rubbers",
    text: "Output tokens per move in round 3: the ring when the match is level at one round each, the dot after one player won both rounds. A big drop means the config writes less once the match is settled.",
  },
  {
    anchor: "reliability",
    focus: "#reliability .chartrow figure:first-child",
    title: "Reliability",
    text: "Failed calls, faults and the time they cost, one bar per config, with the full tables folded underneath. Many failed calls are quota limits on the shared endpoints, not the model's play.",
  },
  {
    anchor: "reliability",
    focus: "#reliability .lanes",
    title: "Failed calls by hour",
    text: "Each model's failed replies, by the hour each call was logged. Lanes failing in the same hours point to an outage rather than a weak model.",
  },
  {
    anchor: "matches",
    focus: "#matches .bar",
    title: "Matches",
    text: "The newest matches, with a search. A row opens its replay, where the arrow keys step through the moves and Escape closes it.",
  },
  {
    anchor: "matches",
    focus: "#matches .matchrows tbody tr:first-child",
    title: "Regret tags",
    text: "In the replay each model move has a regret tag, filled when the move gave up a lot and marked exact when both scores are settled. Open a move for the best move, both scores and the search depth.",
  },
  {
    anchor: "matches",
    focus: "#matches .matchrows tbody tr:first-child",
    title: "Turning points",
    text: "On the replay's health chart, rings mark the costly moves, and the biggest are listed under it as turning points. A click on one jumps to that move.",
  },
  {
    anchor: "leaderboards",
    focus: "#leaderboards .lbt thead, #leaderboards .lbt tbody tr:first-child",
    title: "Leaderboard columns",
    text: "Per config: its share with an interval, the rating, Regret, cost per match and per move, time per move, output tokens and the favourite item. Under Cash or Round wins a pot share or round share column appears.",
  },
  {
    anchor: "leaderboards",
    focus: "#leaderboards .lbt tbody tr:first-child",
    title: "A config's matches",
    text: "A click on a row lists its matches by opponent, one square per match. Faded rows rest on few scored matches.",
  },
  {
    anchor: "breakdown",
    focus: "#breakdown .heatctl > .toggle:first-child",
    title: "Breakdown modes",
    text: "One heatmap per mode, a row per config: win share against each opponent model, item use when legal, choice patterns and play style. A click on a column head sorts by it.",
  },
  {
    anchor: "breakdown",
    focus: "#breakdown .heatctl > .toggle:first-child > button:nth-child(2)",
    title: "Beats the ratings",
    text: "Each cell is a config's share against one opponent model minus the share the pooled ratings predict for those games; lighter beat the prediction. Most cells are noise.",
  },
  {
    anchor: "breakdown",
    focus: "#breakdown .heat tbody tr:first-child",
    title: "Counts",
    text: "The small grey number in each cell is the sample behind it: games, chances or player-matches. Read it before trusting a shade.",
  },
];

// PLACING

/** The card docks at the bottom of a phone; elsewhere it sits under the highlight when it fits there. */
const PHONE_WIDTH = 640;

const GAP = 12;

/** The card's height before it is first drawn. */
const CARD_GUESS = 200;

const isDrawn = (element: Element): boolean => element.getBoundingClientRect().height > 0;

/** Scrolls to a step's element, measures it and decides whether the card fits under it. */
const placed = (step: number) => {
  const stop = TOUR[step];
  const target = stop === undefined ? null : ([...document.querySelectorAll(stop.focus)].find(isDrawn) ?? document.getElementById(stop.anchor));

  if (target === null) return Message.PlacedTour({ step, maybeBox: Option.none(), isCardUnder: false });

  const cardHeight = document.querySelector(".tour-card")?.getBoundingClientRect().height ?? CARD_GUESS;

  // A target inside the sticky bar is already in view.
  if (target.closest(".top") === null) scrollTo(0, target.getBoundingClientRect().top + scrollY - stickyHeight() - GAP);

  const rect = target.getBoundingClientRect();
  // A row wider than its scrolling table is cut at the page's edge, so the highlight never widens the page.
  const right = Math.min(rect.right, document.documentElement.clientWidth);

  return Message.PlacedTour({
    step,
    maybeBox: Option.some({ top: rect.top + scrollY, left: rect.left + scrollX, width: Math.max(0, right - rect.left), height: rect.height }),
    isCardUnder: innerWidth >= PHONE_WIDTH && rect.bottom + 2 * GAP + cardHeight <= innerHeight,
  });
};

const nextFrame = Effect.callback<void>((resume) => {
  requestAnimationFrame(() => resume(Effect.void));
});

/** Places a step a frame after the card is drawn. */
export const PlaceTour = Command.define("PlaceTour", {
  args: { step: Schema.Number },
  messages: [Message.PlacedTour],
  execute: ({ step }) => nextFrame.pipe(Effect.map(() => placed(step))),
});

// VIEW

export const tourKeyMessage = (key: string): Option.Option<Message> => {
  if (key === "Escape") return Option.some(Message.ClosedTour());

  if (key === "ArrowRight" || key === "ArrowDown") return Option.some(Message.SteppedTour({ delta: 1 }));

  return key === "ArrowLeft" || key === "ArrowUp" ? Option.some(Message.SteppedTour({ delta: -1 })) : Option.none();
};

const px = (value: number): string => `${Math.round(value)}px`;

const CARD_WIDTH = 380;

export const tourView = (h: H, tour: Tour, viewportWidth: number): Html => {
  const step = TOUR[tour.step];

  if (step === undefined) return h.empty;

  const isLast = tour.step === TOUR.length - 1;
  const box = Option.getOrUndefined(tour.maybeBox);
  const cardPlace = box !== undefined && tour.isCardUnder ? { position: "absolute", top: px(box.top + box.height + GAP), left: px(Math.max(GAP, Math.min(box.left, viewportWidth - CARD_WIDTH - GAP))) } : {};

  return h.div(
    [h.Class("tour-layer")],
    [
      h.div([h.Class("tour-backdrop"), h.OnClick(Message.ClosedTour())], []),
      box === undefined ? h.empty : h.div([h.Class("tour-focus"), h.Style({ top: px(box.top - 4), left: px(box.left - 4), width: px(box.width + 8), height: px(box.height + 8) })], []),
      h.div(
        [h.Class(`tour-card ${tour.isCardUnder ? "under" : ""}`), h.Role("dialog"), h.AriaLabel("Tour"), h.Style(cardPlace)],
        [
          h.div([h.Class("tour-head")], [h.b([], [step.title]), h.span([h.Class("k")], [`${tour.step + 1} / ${TOUR.length}`])]),
          h.p([], [step.text]),
          h.div(
            [h.Class("tour-buttons")],
            [
              h.button([h.Type("button"), h.Disabled(tour.step === 0), h.OnClick(Message.SteppedTour({ delta: -1 }))], ["Back"]),
              h.button([h.Type("button"), h.Class("on"), h.OnClick(isLast ? Message.ClosedTour() : Message.SteppedTour({ delta: 1 }))], [isLast ? "Done" : "Next"]),
              h.button([h.Type("button"), h.OnClick(Message.ClosedTour())], ["Close"]),
            ],
          ),
        ],
      ),
    ],
  );
};
