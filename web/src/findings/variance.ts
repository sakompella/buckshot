import type { Findings, Split } from "./data.ts";
import { drawing, LAYOUTS, pct, px, svgText, tipped } from "./svg.ts";
import type { Layout } from "./svg.ts";

// Figure 5: the variance of round-win share and of mean move regret split into config, seed, config by seed and the
// rest, as two 100% bars, with the seeds each needs for a repeatability of 0.9.

const SEGMENTS: ReadonlyArray<readonly [keyof Split, string]> = [
  ["config", "the config"],
  ["seed", "the seed"],
  ["configSeed", "config by seed"],
  ["residual", "the residual"],
];

const FRAME = {
  wide: { width: 960, height: 170, labelX: 0, barLeft: 132, barRight: 660, barHeight: 28, rows: [44, 112], noteX: 700 },
  narrow: { width: 360, height: 250, labelX: 8, barLeft: 8, barRight: 352, barHeight: 26, rows: [40, 112], noteX: 8 },
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
  const configText = `config ${pct(split.config)}`;

  const labels = [
    configWidth >= FITS ? svgText(frame.barLeft + 8, textY, configText, ' class="v-in"') : svgText(frame.barLeft + configWidth + 8, textY, configText, ' class="v-out"'),
    svgText(frame.barRight - 8, textY, `residual ${pct(split.residual)}`, ' class="v-out" text-anchor="end"'),
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
    const noteTop = layout === "wide" ? 50 : 186;

    const note = [
      svgText(frame.noteX, noteTop, "Seeds for a repeatability of 0.9", ' class="title"'),
      svgText(frame.noteX, noteTop + 22, `${seeds(gStudy.seedsG90.rounds)} for round wins, ${seeds(gStudy.seedsG90.regret)} for move regret`, ' class="label"'),
      svgText(frame.noteX, noteTop + 42, `${Math.round(gStudy.ratioAll)}x fewer, ${gStudy.ratioTop14.toFixed(1)}x among the 14 strongest`, ' class="note"'),
    ];

    return drawing(
      layout,
      frame.width,
      frame.height,
      `Chart. Config explains ${pct(gStudy.rounds.config)} of the variance in round wins and ${pct(gStudy.regret.config)} in move regret.`,
      [bar("Round wins", gStudy.rounds, layout, roundsY), bar("Move regret", gStudy.regret, layout, regretY), ...note].join(""),
    );
  }).join("");
};
