import { linScale } from "../charts/scales.ts";
import type { Scale } from "../charts/scales.ts";
import type { Config } from "./configs.ts";
import { drawing, LAYOUTS, line, pct, pctInterval, px, rating, ratingInterval, svgText, tipped } from "./svg.ts";
import type { Layout } from "./svg.ts";

// Figure 2: every config's luck-adjusted Round Elo with its 90% interval, in tiers. The default view holds tiers 1 and 2
// and the fixed players; a fold holds all 50 on the same scale. Under it, the record against the depth-7 search with
// no judge at all.

const STEP = 50;

const FRAME = {
  wide: { width: 960, tierX: 0, labelX: 58, trackLeft: 236, trackRight: 808, valueX: 822, rowHeight: 22, top: 40, bottomPad: 48 },
  narrow: { width: 360, tierX: 0, labelX: 22, trackLeft: 128, trackRight: 350, valueX: 0, rowHeight: 24, top: 40, bottomPad: 48 },
} as const;

/** A shared x axis: the rating interval ends of every config, widened to steps of 50 that include 0. */
export const ratingScale = (configs: ReadonlyArray<Config>, left: number, right: number): Scale => {
  const ends = configs.flatMap(({ lo, hi }) => [lo, hi]);
  const from = Math.floor(Math.min(0, ...ends) / STEP) * STEP;
  const to = Math.ceil(Math.max(0, ...ends) / STEP) * STEP;

  return linScale(from, to, left, right, Array.from({ length: (to - from) / STEP + 1 }, (_, index) => from + index * STEP));
};

const tierText = (tier: number | null): string => (tier === null ? "provisional" : `Tier ${tier}`);

export const forestTip = (config: Config): string =>
  `${config.label} \u00b7 ${tierText(config.tier)} \u00b7 Round Elo ${rating(config.rating)} ${ratingInterval(config.lo, config.hi)} \u00b7 ${config.scored.toLocaleString("en-US")} scored matches`;

/** Rows in drawing order, a null standing for a gap row before the fixed players shown for reference. */
type Slot = Config | null;

interface Group {
  readonly tier: number | null;
  readonly from: number;
  readonly to: number;
}

/** Runs of consecutive rows in one tier, for the bands and their labels. */
const groupsOf = (slots: ReadonlyArray<Slot>): ReadonlyArray<Group> => {
  const groups: Array<Group> = [];

  slots.forEach((slot, index) => {
    const last = groups.at(-1);

    if (slot === null) { return; }

    if (last !== undefined && last.tier === slot.tier && last.to === index - 1) { groups[groups.length - 1] = { ...last, to: index }; }
    else { groups.push({ tier: slot.tier, from: index, to: index }); }
  });

  return groups;
};

const diamond = (x: number, y: number, r: number): string => `<path class="fixed" d="M${px(x)},${px(y - r)}L${px(x + r)},${px(y)}L${px(x)},${px(y + r)}L${px(x - r)},${px(y)}Z"/>`;

const forestDrawing = (slots: ReadonlyArray<Slot>, every: ReadonlyArray<Config>, layout: Layout, label: string): string => {
  const frame = FRAME[layout];
  const x = ratingScale(every, frame.trackLeft, frame.trackRight);
  const rowY = (index: number) => frame.top + index * frame.rowHeight;
  const bottom = rowY(slots.length);
  const height = bottom + frame.bottomPad;
  const isWide = layout === "wide";

  const bands = groupsOf(slots).map((group, index) => {
    const kind = group.tier === 1 ? "band-top" : index % 2 === 0 ? "band-a" : "band-b";
    const y = rowY(group.from);

    return `<rect class="${kind}" x="0" y="${y}" width="${frame.width}" height="${(group.to - group.from + 1) * frame.rowHeight}"/>${svgText(frame.tierX + 2, y + frame.rowHeight / 2 + 4, isWide ? tierText(group.tier).toUpperCase() : `T${group.tier ?? "?"}`, ` class="tier${group.tier === 1 ? " tier-top" : ""}"`)}`;
  });

  const rows = slots.map((config, index) => {
    const top = rowY(index);
    const cy = top + frame.rowHeight / 2;

    if (config === null) { return svgText(frame.labelX, cy + 4, "Other fixed players, for reference", ' class="note"'); }

    const family = config.isFixed ? "fixed" : config.isClaude ? "claude" : "gpt";
    const mark = config.isFixed ? diamond(x.at(config.rating), cy, 5) : `<circle class="dot ${family}${config.isProvisional ? " hollow" : ""}" cx="${px(x.at(config.rating))}" cy="${px(cy)}" r="4.5"/>`;
    const labelClass = config.tier === 1 ? "label strong-label" : "label";

    const body = [
      `<rect class="hit" x="0" y="${top}" width="${frame.width}" height="${frame.rowHeight}"/>`,
      svgText(frame.labelX, cy + 4, isWide ? config.label : config.short, ` class="${labelClass}"`),
      line(x.at(config.lo), cy, x.at(config.hi), cy, ` class="ci ${family}"`),
      mark,
      isWide ? svgText(frame.valueX, cy + 4, `${rating(config.rating)} ${ratingInterval(config.lo, config.hi)}`, ' class="value"') : "",
    ].join("");

    return tipped(forestTip(config), body);
  });

  const zero = x.at(0);

  const axis = [
    ...x.ticks.map((tick) => line(x.at(tick), frame.top, x.at(tick), bottom, ' class="grid"') + (isWide || tick % 100 === 0 ? svgText(x.at(tick), bottom + 16, rating(tick), ' class="tick" text-anchor="middle"') : "")),
    svgText((frame.trackLeft + frame.trackRight) / 2, bottom + 36, isWide ? "Luck-adjusted Round Elo, 90% interval" : "Round Elo, 90% interval", ' class="axis-title" text-anchor="middle"'),
    line(zero, frame.top - 6, zero, bottom, ' class="rule"'),
    svgText(zero, frame.top - 12, "depth-7 search = 0", ` class="note" text-anchor="${isWide ? "middle" : "end"}"`),
  ];

  return drawing(layout, frame.width, height, label, [...bands, ...axis, ...rows].join(""));
};

const forestPair = (slots: ReadonlyArray<Slot>, every: ReadonlyArray<Config>, label: string): string => LAYOUTS.map((layout) => forestDrawing(slots, every, layout, label)).join("");

const DEFAULT_TIERS = 2;

/** The rows the figure opens with: tiers 1 and 2, then the fixed players outside them for reference. */
export const defaultSlots = (configs: ReadonlyArray<Config>): ReadonlyArray<Slot> => {
  const top = configs.filter(({ tier }) => tier !== null && tier <= DEFAULT_TIERS);
  const references = configs.filter((config) => config.isFixed && !top.includes(config));

  return references.length === 0 ? top : [...top, null, ...references];
};

/** Figure 2's forest: the default rows, and every config in a fold, on one scale. */
export const forestFigure = (configs: ReadonlyArray<Config>): string =>
  [
    forestPair(defaultSlots(configs), configs, "Chart. Luck-adjusted Round Elo for tiers 1 and 2 and the fixed players, with 90% intervals."),
    `<details class="fold"><summary>Show all ${configs.length} configs</summary>`,
    forestPair(configs, configs, `Chart. Luck-adjusted Round Elo for all ${configs.length} configs, with 90% intervals.`),
    "</details>",
  ].join("");

const H2H = {
  wide: { width: 960, labelX: 58, trackLeft: 236, trackRight: 750, valueX: 768, rowHeight: 30, top: 34 },
  narrow: { width: 360, labelX: 8, trackLeft: 128, trackRight: 350, valueX: 0, rowHeight: 34, top: 34 },
} as const;

export const headToHeadTip = (config: Config): string => {
  const record = config.vsEngine;

  return record === null || record.rate === null || record.lo === null || record.hi === null
    ? config.label
    : `${config.label} vs the depth-7 search \u00b7 won ${record.k} of ${record.n} rounds, ${pct(record.rate)} ${pctInterval(record.lo, record.hi)} \u00b7 ${record.blocks} seeds, both seat orders`;
};

/** The model configs with a direct record against the depth-7 search, as proportions of rounds won with their intervals. */
export const headToHeadFigure = (configs: ReadonlyArray<Config>): string => {
  const rows = configs.filter(({ isFixed, vsEngine }) => !isFixed && vsEngine !== null);

  return LAYOUTS.map((layout) => {
    const frame = H2H[layout];
    const x = linScale(0.4, 0.65, frame.trackLeft, frame.trackRight, [0.4, 0.45, 0.5, 0.55, 0.6, 0.65]);
    const bottom = frame.top + rows.length * frame.rowHeight;
    const isWide = layout === "wide";

    const marks = rows.map((config, index) => {
      const cy = frame.top + (index + 0.5) * frame.rowHeight;
      const record = config.vsEngine;

      if (record === null || record.rate === null || record.lo === null || record.hi === null) { return ""; }

      const family = config.isClaude ? "claude" : "gpt";

      return tipped(headToHeadTip(config), [
        `<rect class="hit" x="0" y="${px(cy - frame.rowHeight / 2)}" width="${frame.width}" height="${frame.rowHeight}"/>`,
        svgText(frame.labelX, cy + 4, isWide ? config.label : config.short, ' class="label"'),
        line(x.at(record.lo), cy, x.at(record.hi), cy, ` class="ci ${family}"`),
        `<circle class="dot ${family}" cx="${px(x.at(record.rate))}" cy="${px(cy)}" r="5"/>`,
        isWide ? svgText(frame.valueX, cy + 4, `${record.k}/${record.n} \u00b7 ${pct(record.rate)} ${pctInterval(record.lo, record.hi)}`, ' class="value"') : "",
      ].join(""));
    });

    const body = [
      ...x.ticks.map((tick) => line(x.at(tick), frame.top, x.at(tick), bottom, ' class="grid"') + svgText(x.at(tick), bottom + 16, pct(tick, 0), ' class="tick" text-anchor="middle"')),
      line(x.at(0.5), frame.top - 6, x.at(0.5), bottom, ' class="rule"'),
      svgText(frame.labelX, frame.top - 14, isWide ? "Head-to-head vs the depth-7 search, no judge" : "Head-to-head vs depth-7 search", ' class="title"'),
      isWide ? svgText(x.at(0.5), frame.top - 12, "even", ' class="note" text-anchor="middle"') : "",
      ...marks,
    ];

    return drawing(layout, frame.width, bottom + 26, "Chart. Share of rounds won against the depth-7 search, with 90% intervals.", body.join(""));
  }).join("");
};
