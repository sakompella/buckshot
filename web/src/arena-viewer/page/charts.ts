import { Effect, Option, Schema } from "effect";
import type { Html, HtmlBuilder } from "foldkit/html";
import { Mount } from "foldkit";

import { Message } from "./model.ts";

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

/** Text for screen readers only, in parentheses after the figure it explains. */
export const noteView = (h: H, text: string): Html => h.span([h.Class("sr")], [` (${text})`]);

/** The terms a table's column heads stand for, in a fold under it: a head's `title` shows only to a mouse. */
export const termsView = (h: H, summary: string, terms: ReadonlyArray<readonly [string, string]>): Html =>
  terms.length === 0 ? h.empty : h.details([h.Class("fold")], [h.summary([], [summary]), h.dl([h.Class("terms")], terms.flatMap(([term, text]) => [h.dt([], [term]), h.dd([], [text])]))]);

/** An id for an element a tooltip points at, from any key. */
export const anchorId = (...parts: ReadonlyArray<string | number>): string => `a-${parts.join("-").replaceAll(/[^\w-]/g, "_")}`;

// Marks mean the same on every chart: a solid dot is a config's own value, a ring the same config in a second
// situation, a coloured dash an effort, and a grey dashed line a reference (a model's prediction, an even split, an
// overall level). Intervals are thin lines through the mark.

export const REFERENCE = "#8b8b8b";

export const REFERENCE_DASH = "4 3";

/**
 * Gives a chart mark the page's shared tip, the scatter's way: the mouse shows it, and a click, a tap or Enter pins it.
 * A dense mark (an hour's bar, a seed's cell) stays out of the tab order, so the keyboard does not step through hundreds.
 */
export const markTip = (h: H, anchor: string, text: string, isFocusable = true) => {
  const tip = { anchor, text };

  return [
    h.Id(anchor),
    h.Role("button"),
    h.AriaLabel(text),
    h.OnMouseEnter(Message.HoveredMark({ tip })),
    h.OnMouseLeave(Message.LeftMark()),
    h.OnClick(Message.ClickedMark({ tip }), { propagation: "Stop" }),
    ...(isFocusable
      ? [
          h.Tabindex(0),
          h.OnFocus(Message.HoveredMark({ tip })),
          h.OnBlur(Message.LeftMark()),
          h.OnKeyDownSelfPreventDefault((key) => (key === "Enter" || key === " " ? Option.some(Message.ClickedMark({ tip })) : Option.none())),
        ]
      : []),
  ];
};

/** One line in a key: its name, colour and dash. */
export interface KeyLine {
  readonly label: string;
  readonly color: string;
  readonly dash: string;
}

/** A key of line samples, for a phone chart too narrow to name its lines at their ends. */
export const lineKeyView = (h: H, lines: ReadonlyArray<KeyLine>): Html =>
  h.div(
    [h.Class("legend linekey")],
    lines.map(({ label, color, dash }) =>
      h.span([h.Style({ color })], [h.svg([h.Width("22"), h.Height("8")], [h.line([h.X1("0"), h.X2("22"), h.Y1("4"), h.Y2("4"), h.Stroke(color), h.StrokeWidth("1.8"), h.StrokeDasharray(dash)], [])]), label]),
    ),
  );

/** A finger's reach around a small mark. */
const HIT_RADIUS = 11;

/** A dot with the shared tip, inside a clear circle wide enough to tap. `look` draws the dot itself. */
export const tippedDot = (h: H, anchor: string, text: string, cx: string, cy: string, look: ReadonlyArray<Parameters<H["circle"]>[0][number]>): Html =>
  h.g(markTip(h, anchor, text), [h.circle([h.Cx(cx), h.Cy(cy), h.R(String(HIT_RADIUS)), h.Fill("transparent")], []), h.circle([h.Cx(cx), h.Cy(cy), ...look], [])]);

const TIP_GAP_X = 14;

const TIP_GAP_Y = 12;

const MARGIN = 8;

// Sits below and right of its anchor's centre, flipped or clamped to stay inside the viewport (phones are narrower than the tip).
const PlaceTip = Mount.define("PlaceTip", {
  args: { anchor: Schema.String },
  messages: [Message.PlacedTip],
  execute: ({ element, anchor }) =>
    Effect.sync(() => {
      const place = () => {
        const target = document.getElementById(anchor);

        // A tip whose mark is gone (filtered out, or the tip replaced) stops following the page.
        if (target === null || !element.isConnected || !(element instanceof HTMLElement)) {
          removeEventListener("scroll", place);
          removeEventListener("resize", place);

          return;
        }

        const box = target.getBoundingClientRect();
        const own = element.getBoundingClientRect();
        const x = box.left + box.width / 2;
        const y = box.top + box.height / 2;
        const top = y + TIP_GAP_Y + own.height > innerHeight - MARGIN ? Math.max(MARGIN, y - TIP_GAP_Y - own.height) : y + TIP_GAP_Y;

        element.style.left = `${Math.max(MARGIN, Math.min(x + TIP_GAP_X, innerWidth - own.width - MARGIN))}px`;
        element.style.top = `${top}px`;
        element.style.visibility = "visible";
      };

      // A pinned tip follows its mark as the page scrolls or turns.
      addEventListener("scroll", place, { passive: true });
      addEventListener("resize", place);
      place();

      return Message.PlacedTip();
    }),
});

/** A tooltip for the element with id `anchor`. Keyed by the anchor, so moving to another anchor places a new tip. */
export const tipView = (h: H, anchor: string, children: ReadonlyArray<Html | string>): Html =>
  h.keyed("div")(anchor, [h.Class("tip"), h.Style({ visibility: "hidden" }), h.OnMount(PlaceTip({ anchor }))], [...children]);

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

const CHART_GAP = 28;

/** A chart's width in a `.chartrow`: three to a row on a wide screen, else the whole content width. */
export const chartWidth = (width: number, contentWidth: number): number => (width > 1024 ? Math.floor((contentWidth - 2 * CHART_GAP) / 3) : contentWidth);
