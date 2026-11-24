import { linScale } from "../charts/scales.ts";
import type { Findings } from "./data.ts";
import { esc, pct, px } from "./svg.ts";

// The 1200x630 card crawlers show for a shared link: the title, the headline in one line, and Figure 1's two curves.

const SANS = "DejaVu Sans, Helvetica, Arial, sans-serif";

export const OG_WIDTH = 1200;

export const OG_HEIGHT = 630;

export const ogCard = (findings: Findings): string => {
  const { headline } = findings;
  const strong = findings.curve.filter(({ group }) => group === "strong").toSorted((left, right) => left.pLive - right.pLive);
  const x = linScale(0.2, 0.8, 640, 1120, []);
  const y = linScale(0, 1, 560, 330, []);
  const half = x.at(0.5);
  const curve = (rate: (point: Findings["curve"][number]) => number) => strong.map((point, index) => `${index === 0 ? "M" : "L"}${px(x.at(point.pLive))},${px(y.at(rate(point)))}`).join("");

  return `<svg xmlns="http://www.w3.org/2000/svg" width="${OG_WIDTH}" height="${OG_HEIGHT}" viewBox="0 0 ${OG_WIDTH} ${OG_HEIGHT}" font-family="${SANS}">
<rect width="${OG_WIDTH}" height="${OG_HEIGHT}" fill="#fcfcfa"/>
<rect width="14" height="${OG_HEIGHT}" fill="#c2410c"/>
<text x="80" y="104" font-size="22" font-weight="700" letter-spacing="4" fill="#c2410c">BUCKSHOT ROULETTE · FINDINGS</text>
<text x="80" y="192" font-size="76" font-weight="700" fill="#18181b">Two blanks, one live</text>
<text x="80" y="300" font-size="31" fill="#3f3f46">Below 50% live, strong models</text>
<text x="80" y="344" font-size="31" fill="#3f3f46">shoot themselves <tspan font-weight="700" fill="#c2410c">${esc(pct(headline.strongModelRate, 0))}</tspan> of the time.</text>
<text x="80" y="388" font-size="31" fill="#3f3f46">A depth-7 search, <tspan font-weight="700" fill="#2f5d8a">${esc(pct(headline.strongSearchRate, 0))}</tspan>.</text>
<rect x="${px(x.at(0.2))}" y="320" width="${px(half - x.at(0.2))}" height="250" fill="#f4f2ec"/>
<line x1="${px(half)}" y1="320" x2="${px(half)}" y2="570" stroke="#18181b" stroke-width="2"/>
<path d="${curve(({ searchRate }) => searchRate)}" fill="none" stroke="#2f5d8a" stroke-width="5" stroke-dasharray="12 8"/>
<path d="${curve(({ modelRate }) => modelRate)}" fill="none" stroke="#c2410c" stroke-width="7" stroke-linejoin="round"/>
<text x="80" y="566" font-size="24" fill="#66666e">buckshot.akompella.dev</text>
</svg>`;
};
