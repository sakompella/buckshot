import { Effect, Option, Schema } from "effect";
import { Command } from "foldkit";
import type { Html, HtmlBuilder } from "foldkit/html";

import { GROUPS, Message, type Section, type Tour } from "./model.ts";
import { INTERVAL_PERCENT } from "./ratings.ts";
import { reveal } from "./reveal.ts";
import { stickyHeight } from "./view.ts";

type H = HtmlBuilder<Message>;

// The guided tour: hidden until the hero's tour button starts it. Each step scrolls to an element, highlights
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

const TOUR: ReadonlyArray<TourStep> = [
  {
    anchor: "summary",
    focus: "#summary",
    title: "Results at a glance",
    text: `The first chart shows every ranked config's Round Elo with its ${INTERVAL_PERCENT} interval, best first. When two lines overlap, the data cannot tell those configs apart. The dashed lines are the two search engines, fixed players to compare against.`,
  },
  {
    anchor: "how",
    focus: "#how",
    title: "How the game works",
    text: "If you don't know Buckshot Roulette, this section explains the goal, what a turn is, why a blank fired at yourself keeps your turn, and what the models see and do, with one example turn.",
  },
  {
    anchor: "scatter",
    focus: ".filters",
    title: "Filters",
    text: "The model and effort chips filter the whole page. On a phone they fold into one line; tap it to open them. Every scored match from every tournament is pooled.",
  },
  {
    anchor: "scatter",
    focus: "#scatter .card",
    title: "Cost, Moves, Tokens, Accuracy",
    text: "Each point is a config: one model at one effort. It is placed by its Round Elo against one of: cost per match, model moves per match, output tokens per match, or accuracy. Accuracy is scored the way lichess scores a game, from how much win chance each move gave up (higher is better, 100 is perfect). Click a point to open that config's details under the chart.",
  },
  {
    anchor: "breakdown",
    focus: "#breakdown details",
    title: "Win share against each opponent",
    text: "Each config's win share against each opponent model. The table stays folded until you click its title. Inside, click a column head to sort by it. The small gray number in each cell is the sample behind it: how many matches.",
  },
  {
    anchor: "certain-mistakes",
    focus: "#certain-mistakes .chartrow",
    title: "Certain mistakes",
    text: "Shots that a player's own information proves worse than the other shot, counted over every decision where it could have made one. The dashed line is all configs pooled. Tap a dot to see its interval.",
  },
  {
    anchor: "odds",
    focus: "#odds .chartrow figure:first-child",
    title: "Playing the odds",
    text: "How often a config shoots itself, by the chance, on its own count, that the shell is live. One panel per model, one line per effort. A model that counts shells shoots itself on a sure blank.",
  },
  {
    anchor: "items",
    focus: "#items .chartrow",
    title: "Item usage",
    text: "How often each model used an item when it had one, and what became of each kind of item: used, stolen by the opponent or left unused. Look for the items most often left unused.",
  },
  {
    anchor: "matches",
    focus: "#matches .bar",
    title: "Matches",
    text: "Every started match, newest first. There is a search box and two shortcuts: Comebacks, for matches the winner took from far behind, and Upsets, for matches the lower-rated player won.",
  },
  {
    anchor: "leaderboards",
    focus: "#leaderboards .lbt thead, #leaderboards .lbt tbody tr:first-child",
    title: "Leaderboard columns",
    text: "The tables come near the end of the page. For each config the leaderboard gives its Round Elo, one Bradley-Terry rating pooled over every tournament, drawn as a dot with its interval. Then come its matches, cost per match, match wins against its own opponents, round wins, cash share, accuracy, cost per move, time per move, output tokens and favorite item.",
  },
  {
    anchor: "leaderboards",
    focus: "#leaderboards .lbt tbody tr:first-child",
    title: "A config's row",
    text: "Click a row to see how steady the config is, how much it writes when behind or ahead, and what became of its items. Faded rows rest on few scored matches and have no rank.",
  },
  {
    anchor: "about",
    focus: "#about",
    title: "About the method",
    text: "Run dates, the conditions every match plays under, what Round Elo and luck-adjusted Elo are, and what the comparison cannot settle.",
  },
];

/** The steps over the sections this page draws. */
export const tourOf = (hasCertain: boolean): ReadonlyArray<TourStep> =>
  TOUR.filter(({ anchor }) => (hasCertain || anchor !== "certain-mistakes") && GROUPS.some(({ sections }) => sections.includes(anchor)));

// PLACING

/** The card docks at the bottom of a phone; elsewhere it sits under the highlight when it fits there. */
const PHONE_WIDTH = 640;

const GAP = 12;

/** The card's height before it is first drawn. */
const CARD_GUESS = 200;

const isDrawn = (element: Element): boolean => element.getBoundingClientRect().height > 0;

/** Scrolls to a step's element, measures it and decides whether the card fits under it. */
const placed = (step: number, hasCertain: boolean) => {
  const stop = tourOf(hasCertain)[step];
  const found = stop === undefined ? [] : [...document.querySelectorAll(stop.focus)];

  found.forEach(reveal);

  const target = found.find(isDrawn) ?? (stop === undefined ? null : document.getElementById(stop.anchor));

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
  args: { step: Schema.Number, hasCertain: Schema.Boolean },
  messages: [Message.PlacedTour],
  execute: ({ step, hasCertain }) => nextFrame.pipe(Effect.map(() => placed(step, hasCertain))),
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
  const steps = tourOf(tour.hasCertain);
  const step = steps[tour.step];

  if (step === undefined) return h.empty;

  const isLast = tour.step === steps.length - 1;
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
          h.div([h.Class("tour-head")], [h.b([], [step.title]), h.span([h.Class("k")], [`${tour.step + 1} / ${steps.length}`])]),
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
