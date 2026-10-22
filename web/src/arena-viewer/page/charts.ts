import { Effect, Schema } from "effect";
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

export const logScale = (d0: number, d1: number, r0: number, r1: number): Scale => {
  const l0 = Math.log10(d0);
  const l1 = Math.log10(d1);
  const span = l1 - l0;
  const steps = span > 3 ? [1] : span > 1.5 ? [1, 3] : [1, 2, 5];
  const ticks: Array<number> = [];

  for (let exponent = Math.floor(l0); exponent <= Math.ceil(l1); exponent++) {
    for (const step of steps) {
      const value = Number((step * 10 ** exponent).toPrecision(3));

      if (value >= d0 * 0.999 && value <= d1 * 1.001) ticks.push(value);
    }
  }

  return { at: (value) => r0 + ((Math.log10(Math.max(value, d0)) - l0) / (l1 - l0 || 1)) * (r1 - r0), ticks };
};

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
