import type { Findings, Split } from "./data.ts";
import { drawing, LAYOUTS, pct, px, svgText, tipped } from "./svg.ts";
import type { Layout } from "./svg.ts";

// Figure 4: the variance of round-win share and of points lost per move split into model setting, seed, setting by
// seed and the rest, as two 100% bars, with the seeds each needs for a repeatability of 0.9.

const SEGMENTS: ReadonlyArray<readonly [keyof Split, string]> = [
  ["config", "the setting"],
  ["seed", "the seed"],
  ["configSeed", "setting by seed"],
  ["residual", "the rest"],
];

const FRAME = {
  wide: { width: 960, height: 150, labelX: 0, barLeft: 128, barRight: 640, barHeight: 30, rows: [30, 96], noteX: 680 },
  narrow: { width: 360, height: 250, labelX: 0, barLeft: 0, barRight: 360, barHeight: 28, rows: [24, 96], noteX: 0 },
} as const;

/** Wide enough for its label inside the segment. */
const FITS = 96;

const bar = (name: string, split: Split, layout: Layout, top: number): string => {
  const frame = FRAME[layout];
  const span = frame.barRight - frame.barLeft;
  const isWide = layout === "wide";
  const barY = isWide ? top : top + 8;
  let x = frame.barLeft;

  const segments = SEGMENTS.map(([key, label]) => {
    const width = split[key] * span;
    const from = x;

    x += width;

    return tipped(`${name} \u00b7 ${label} explains ${pct(split[key])} of the variance`, `<rect class="v-${key}" x="${px(from)}" y="${barY}" width="${px(width)}" height="${frame.barHeight}"/>`);
  });

  const configWidth = split.config * span;
  const textY = barY + frame.barHeight / 2 + 4;
  const configText = `setting ${pct(split.config)}`;

  const labels = [
    configWidth >= FITS ? svgText(frame.barLeft + 8, textY, configText, ' class="v-in"') : svgText(frame.barLeft + configWidth + 8, textY, configText, ' class="v-out"'),
    svgText(frame.barRight - 8, textY, `rest ${pct(split.residual)}`, ' class="v-rest" text-anchor="end"'),
  ];

  const title = isWide ? svgText(frame.labelX, textY, name, ' class="label strong-label"') : svgText(frame.labelX, top - 2, name, ' class="label strong-label"');

  return [title, ...segments, ...labels].join("");
};

/** Seeds are whole: 64.6 needed reads 65. */
const seeds = (value: number): string => String(Math.ceil(value));

/** Figure 4 in both layouts. */
export const varianceFigure = (findings: Findings): string => {
  const { gStudy } = findings;

  return LAYOUTS.map((layout) => {
    const frame = FRAME[layout];
    const [roundsY = 0, regretY = 0] = frame.rows;
    const noteTop = layout === "wide" ? 44 : 186;

    const note = [
      svgText(frame.noteX, noteTop, "Seeds to rank settings reliably", ' class="title"'),
      svgText(frame.noteX, noteTop + 30, `${seeds(gStudy.seedsG90.rounds)} for round wins, ${seeds(gStudy.seedsG90.regret)} for move scores`, ' class="label"'),
      svgText(frame.noteX, noteTop + 52, `${Math.round(gStudy.ratioAll)}x fewer, ${gStudy.ratioTop14.toFixed(1)}x among the top 14`, ' class="big-note"'),
    ];

    return drawing(
      layout,
      frame.width,
      frame.height,
      `Chart. The model setting explains ${pct(gStudy.rounds.config)} of the variance in round wins and ${pct(gStudy.regret.config)} in move scores.`,
      [bar("Round wins", gStudy.rounds, layout, roundsY), bar("Move scores", gStudy.regret, layout, regretY), ...note].join(""),
    );
  }).join("");
};
