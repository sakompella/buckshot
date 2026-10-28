import { Effect, Option, Schema } from "effect";
import type { Html, HtmlBuilder } from "foldkit/html";
import { Mount } from "foldkit";

import { type Basis, Message, type Ranking } from "./model.ts";

type H = HtmlBuilder<Message>;

// Scales, controls and tooltips shared by the page's charts.

/** A linear or log mapping from data to pixels, with the ticks to draw. */
export interface Scale {
  readonly at: (value: number) => number;
  readonly ticks: ReadonlyArray<number>;
}

export const linScale = (d0: number, d1: number, r0: number, r1: number, ticks: ReadonlyArray<number>): Scale => ({
  at: (value) => r0 + ((value - d0) / (d1 - d0 || 1)) * (r1 - r0),
  ticks,
});

/** Ticks at 1, 2 and 5 times each power of ten in the domain. */
export const logScale = (d0: number, d1: number, r0: number, r1: number): Scale => {
  const l0 = Math.log10(d0);
  const l1 = Math.log10(d1);
  const ticks: Array<number> = [];

  for (let exponent = Math.floor(l0); exponent <= Math.ceil(l1); exponent++) {
    for (const step of [1, 2, 5]) {
      const value = Number((step * 10 ** exponent).toPrecision(3));

      if (value >= d0 * 0.999 && value <= d1 * 1.001) ticks.push(value);
    }
  }

  return { at: (value) => r0 + ((Math.log10(Math.max(value, d0)) - l0) / (l1 - l0 || 1)) * (r1 - r0), ticks };
};

/** A click target that is not a button: it takes focus, and Enter or Space press it. */
export const pressable = (h: H, message: Message) =>
  [h.OnClick(message), h.Tabindex(0), h.Role("button"), h.OnKeyDownSelfPreventDefault((key) => (key === "Enter" || key === " " ? Option.some(message) : Option.none()))] as const;

/** An id for an element a tooltip points at, from any key. */
export const anchorId = (...parts: ReadonlyArray<string | number>): string => `a-${parts.join("-").replaceAll(/[^\w-]/g, "_")}`;

const TIP_GAP_X = 14;

const TIP_GAP_Y = 12;

const MARGIN = 8;

// Sits below and right of its anchor's centre, flipped or clamped to stay inside the viewport (phones are narrower than the tip).
const PlaceTip = Mount.define("PlaceTip", {
  args: { anchor: Schema.String },
  messages: [Message.PlacedTip],
  execute: ({ element, anchor }) =>
    Effect.sync(() => {
      const target = document.getElementById(anchor);

      if (target !== null && element instanceof HTMLElement) {
        const box = target.getBoundingClientRect();
        const own = element.getBoundingClientRect();
        const x = box.left + box.width / 2;
        const y = box.top + box.height / 2;
        const top = y + TIP_GAP_Y + own.height > innerHeight - MARGIN ? Math.max(MARGIN, y - TIP_GAP_Y - own.height) : y + TIP_GAP_Y;

        element.style.left = `${Math.max(MARGIN, Math.min(x + TIP_GAP_X, innerWidth - own.width - MARGIN))}px`;
        element.style.top = `${top}px`;
        element.style.visibility = "visible";
      }

      return Message.PlacedTip();
    }),
});

/** A tooltip for the element with id `anchor`. Keyed by the anchor, so moving to another anchor places a new tip. */
export const tipView = (h: H, anchor: string, children: ReadonlyArray<Html | string>): Html =>
  h.keyed("div")(anchor, [h.Class("tip"), h.Style({ visibility: "hidden" }), h.OnMount(PlaceTip({ anchor }))], [...children]);

/** A labelled on/off switch. */
export const switchView = (h: H, isOn: boolean, label: string, message: Message): Html =>
  h.label(
    [h.Class("switch")],
    [h.input([h.Type("checkbox"), h.Role("switch"), h.Checked(isOn), h.OnChange(() => message)]), h.span([h.Class("knob"), h.AriaHidden(true)], []), label],
  );

/** A row of buttons choosing one value. */
export const toggleView = <A extends string>(h: H, value: A, options: ReadonlyArray<readonly [A, string]>, toMessage: (value: A) => Message): Html =>
  h.div(
    [h.Class("toggle")],
    options.map(([option, label]) => h.button([h.Type("button"), h.Class(option === value ? "on" : ""), h.OnClick(toMessage(option))], [label])),
  );

/** The same choice as toggleView, as a native menu, for a phone row with no room for buttons. */
export const selectView = <A extends string>(h: H, label: string, value: A, options: ReadonlyArray<readonly [A, string]>, toMessage: (value: A) => Message): Html =>
  h.select(
    [h.AriaLabel(label), h.OnChange((chosen) => toMessage(options.find(([option]) => option === chosen)?.[0] ?? value))],
    options.map(([option, optionLabel]) => h.option([h.Value(option), h.Selected(option === value)], [optionLabel])),
  );

const RANKINGS: ReadonlyArray<readonly [Ranking, string]> = [
  ["elo", "Elo"],
  ["rank", "Rank"],
];

const BASES: ReadonlyArray<readonly [Basis, string]> = [
  ["rounds", "Round wins"],
  ["matches", "Match wins"],
  ["cash", "Cash"],
];

/** The page-wide choices for ratings, drawn wherever they show: what they count (round wins, match wins or cash), and Elo or rank. */
export const ratingToggles = (h: H, ranking: Ranking, basis: Basis): ReadonlyArray<Html> => [
  toggleView(h, basis, BASES, (option) => Message.SelectedBasis({ basis: option })),
  toggleView(h, ranking, RANKINGS, (option) => Message.SelectedRanking({ ranking: option })),
];

export const ratingSelects = (h: H, ranking: Ranking, basis: Basis): ReadonlyArray<Html> => [
  selectView(h, "what the ratings count", basis, BASES, (option) => Message.SelectedBasis({ basis: option })),
  selectView(h, "Elo or rank", ranking, RANKINGS, (option) => Message.SelectedRanking({ ranking: option })),
];

const CHART_GAP = 28;

/** A chart's width in a `.chartrow`: three to a row on a wide screen, else the whole content width. */
export const chartWidth = (width: number, contentWidth: number): number => (width > 1024 ? Math.floor((contentWidth - 2 * CHART_GAP) / 3) : contentWidth);

export const figureView = (h: H, title: string, note: string, chart: Html): Html => h.figure([], [h.h3([], [title]), h.p([h.Class("sub")], [note]), chart]);
