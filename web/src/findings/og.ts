import { linScale } from "../charts/scales.ts";
import type { Findings } from "./data.ts";
import { isBelowEven } from "./data.ts";
import { esc, pct, px } from "./svg.ts";

// The 1200x630 card crawlers show for a shared link: one title and Figure 1's two curves, drawn big, with the two rates
// below 50% live. scripts/og-image.ts renders it with the page's own fonts.

export const OG_WIDTH = 1200;

export const OG_HEIGHT = 630;

/** The 600 weight file names its family with its weight. */
const SERIF = "EB Garamond SemiBold, EB Garamond, DejaVu Serif, serif";

const MONO = "Cousine, DejaVu Sans Mono, monospace";

const MODEL = "#c2410c";

const SEARCH = "#1e3a5f";

export const ogCard = (findings: Findings): string => {
  const { headline } = findings;
  const strong = findings.curve.filter(({ group }) => group === "strong").toSorted((left, right) => left.pLive - right.pLive);
  const x = linScale(0.2, 0.8, 110, 1120, []);
  const y = linScale(0, 1, 580, 196, []);
  const half = x.at(0.5);
  const below = strong.filter(isBelowEven);
  const labelX = below.length === 0 ? x.at(0.3) : below.reduce((total, point) => total + x.at(point.pLive), 0) / below.length;
  const curve = (rate: (point: Findings["curve"][number]) => number) => strong.map((point, index) => `${index === 0 ? "M" : "L"}${px(x.at(point.pLive))},${px(y.at(rate(point)))}`).join("");

  return `<svg xmlns="http://www.w3.org/2000/svg" width="${OG_WIDTH}" height="${OG_HEIGHT}" viewBox="0 0 ${OG_WIDTH} ${OG_HEIGHT}">
<rect width="${OG_WIDTH}" height="${OG_HEIGHT}" fill="#ffffff"/>
<rect width="12" height="${OG_HEIGHT}" fill="${MODEL}"/>
<text x="80" y="118" font-family="${SERIF}" font-size="84" font-weight="600" fill="#111111">Two blanks, one live</text>
<rect x="${px(x.at(0.2))}" y="180" width="${px(half - x.at(0.2))}" height="400" fill="#f6f6f6"/>
<line x1="${px(half)}" y1="180" x2="${px(half)}" y2="580" stroke="#111111" stroke-width="2"/>
<line x1="${px(x.at(0.2))}" y1="580" x2="1120" y2="580" stroke="#bbbbbb" stroke-width="2"/>
<text x="${px(half + 14)}" y="206" font-family="${MONO}" font-size="22" fill="#555555">50% live</text>
<path d="${curve(({ searchRate }) => searchRate)}" fill="none" stroke="${SEARCH}" stroke-width="7" stroke-dasharray="16 11" stroke-linecap="round"/>
<path d="${curve(({ modelRate }) => modelRate)}" fill="none" stroke="${MODEL}" stroke-width="10" stroke-linejoin="round" stroke-linecap="round"/>
<text x="${px(labelX)}" y="${px(y.at(headline.strongModelRate) - 34)}" font-family="${MONO}" font-size="56" font-weight="700" fill="${MODEL}" text-anchor="middle">${esc(pct(headline.strongModelRate, 0))}</text>
<text x="${px(labelX)}" y="${px(y.at(headline.strongSearchRate) - 30)}" font-family="${MONO}" font-size="56" font-weight="700" fill="${SEARCH}" text-anchor="middle">${esc(pct(headline.strongSearchRate, 0))}</text>
</svg>`;
};
