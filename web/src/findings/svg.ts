// Strings for the findings page's build-time SVG and HTML: escaping, number formats and the tooltip mark.

const ENTITIES: ReadonlyMap<string, string> = new Map([["&", "&amp;"], ["<", "&lt;"], [">", "&gt;"], ['"', "&quot;"], ["'", "&#39;"]]);

export const esc = (text: string): string => text.replaceAll(/[&<>"']/g, (char) => ENTITIES.get(char) ?? char);

/** A coordinate with one decimal, enough for a 960-wide drawing. */
export const px = (value: number): string => String(Math.round(value * 10) / 10);

/** A negative number with a true minus sign. */
const signed = (text: string): string => text.replace(/^-/, "\u2212");

/** A fraction as a percentage: 0.576 reads "57.6%". */
export const pct = (share: number, digits = 1): string => `${signed((share * 100).toFixed(digits))}%`;

/** A gap in percentage points from a fraction, with its sign: 0.377 reads "+37.7". */
export const points = (gap: number, digits = 1): string => {
  const text = (gap * 100).toFixed(digits);

  return text.startsWith("-") ? signed(text) : `+${text}`;
};

/** An interval of percentage points, with signs: "[+31.2, +43.3]". */
export const pointsInterval = (lo: number, hi: number, digits = 1): string => `[${points(lo, digits)}, ${points(hi, digits)}]`;

/** An interval of percentages without the unit: "[75.7, 82.7]". */
export const pctInterval = (lo: number, hi: number, digits = 1): string => `[${signed((lo * 100).toFixed(digits))}, ${signed((hi * 100).toFixed(digits))}]`;

/** A rating with its sign, rounded: "+13", "\u22127". */
export const rating = (value: number): string => {
  const rounded = Math.round(value) || 0;

  return rounded > 0 ? `+${rounded}` : signed(String(rounded));
};

export const ratingInterval = (lo: number, hi: number): string => `[${rating(lo)}, ${rating(hi)}]`;

export const usd = (value: number): string => `$${value.toFixed(value >= 0.1 ? 2 : 3)}`;

export const count = (value: number): string => Math.round(value).toLocaleString("en-US");

/** A token count per move: 10, 483, 5.3k, 11.2k. */
export const tokens = (value: number): string => (value >= 1000 ? `${(value / 1000).toFixed(1)}k` : String(Math.round(value)));

/** A mark that shows `tip` on hover, focus or tap: the attribute tips.ts reads, and the same text for screen readers. */
export const tipped = (tip: string, body: string, attributes = ""): string => `<g class="mark" tabindex="0" role="img" aria-label="${esc(tip)}" data-tip="${esc(tip)}"${attributes}>${body}</g>`;

export const svgText = (x: number, y: number, text: string, attributes = ""): string => `<text x="${px(x)}" y="${px(y)}"${attributes}>${esc(text)}</text>`;

export const line = (x1: number, y1: number, x2: number, y2: number, attributes = ""): string => `<line x1="${px(x1)}" y1="${px(y1)}" x2="${px(x2)}" y2="${px(y2)}"${attributes}/>`;

/** An SVG drawing for one of a figure's two layouts; CSS shows the wide one at 760px and up, the narrow one below. */
export const drawing = (layout: Layout, width: number, height: number, label: string, body: string): string =>
  `<svg class="fig-${layout}" viewBox="0 0 ${width} ${height}" width="${width}" height="${height}" role="group" aria-label="${esc(label)}">${body}</svg>`;

export type Layout = "wide" | "narrow";

export const LAYOUTS: ReadonlyArray<Layout> = ["wide", "narrow"];
