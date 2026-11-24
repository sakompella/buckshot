import { paretoFrontier } from "../charts/frontier.ts";
import { linScale, logScale } from "../charts/scales.ts";
import type { Scale } from "../charts/scales.ts";
import { cellPath, tapCells } from "../charts/tap-cells.ts";
import { byEffort, groupBy } from "../arena-viewer/page/data.ts";
import { familiesOf, familyId, isReference, isTopTier } from "./configs.ts";
import type { Config } from "./configs.ts";
import { drawing, esc, LAYOUTS, line, px, rating, ratingInterval, svgText, tipped, tokens, usd } from "./svg.ts";
import type { Layout } from "./svg.ts";

// Figures 2 and 3: the skill score of every model setting against its thinking tokens per move or its cost per match,
// both on log scales. One shade per model, a model's settings joined from least to most effort, the depth-7 search and
// the game's two computer players as reference lines, and 90% ranges on the top group.

const FRAME = {
  wide: { width: 960, height: 500, left: 52, right: 944, top: 40, bottom: 440, labelStep: 50 },
  narrow: { width: 360, height: 420, left: 40, right: 352, top: 40, bottom: 364, labelStep: 100 },
} as const;

const Y_STEP = 50;

/** Cousine's advance is 0.6 em; labels are 12px in the wide layout and 11px in the narrow one. */
const CHAR_WIDTH = { wide: 7.2, narrow: 6.6 } as const;

const LABEL_HEIGHT = 13;

const REACH = 14;

/** The y axis: every plotted range end, widened to steps of 50 that include 0. */
const ratingScale = (configs: ReadonlyArray<Config>, bottom: number, top: number): Scale => {
  const ends = configs.flatMap(({ lo, hi }) => [lo, hi]);
  const from = Math.floor(Math.min(0, ...ends) / Y_STEP) * Y_STEP;
  const to = Math.ceil(Math.max(0, ...ends) / Y_STEP) * Y_STEP;

  return linScale(from, to, bottom, top, Array.from({ length: (to - from) / Y_STEP + 1 }, (_, index) => from + index * Y_STEP));
};

interface Box {
  readonly x0: number;
  readonly y0: number;
  readonly x1: number;
  readonly y1: number;
}

const overlap = (a: Box, b: Box): number => Math.max(0, Math.min(a.x1, b.x1) - Math.max(a.x0, b.x0)) * Math.max(0, Math.min(a.y1, b.y1) - Math.max(a.y0, b.y0));

interface Placed {
  readonly x: number;
  readonly y: number;
  readonly anchor: "start" | "middle" | "end";
  readonly text: string;
  readonly box: Box;
  /** The point the label names. */
  readonly of: { readonly x: number; readonly y: number };
}

/** The label, and a thin leader from its point when the label sits a step away from it. */
const labelSvg = (placed: Placed): string => {
  const { of, box } = placed;
  const [nearX, nearY] = [Math.min(Math.max(of.x, box.x0), box.x1), Math.min(Math.max(of.y, box.y0), box.y1)];
  const leader = Math.hypot(nearX - of.x, nearY - of.y) > 12 ? line(of.x, of.y, nearX, nearY, ' class="leader"') : "";

  return `${leader}<text class="pt-label halo" x="${px(placed.x)}" y="${px(placed.y)}" text-anchor="${placed.anchor}">${esc(placed.text)}</text>`;
};

/** Spots tried around a point, nearest first: right, left, above, below, then the corners and a step further out. */
const SPOTS: ReadonlyArray<readonly [number, number, Placed["anchor"]]> = [
  [9, 4, "start"], [-9, 4, "end"], [0, -11, "middle"], [0, 19, "middle"],
  [7, -10, "start"], [-7, -10, "end"], [7, 18, "start"], [-7, 18, "end"],
  [0, -25, "middle"], [0, 33, "middle"], [9, -24, "start"], [-9, -24, "end"],
];

/** How much of a label's width sits left of its x, by text-anchor. */
const LEFT_SHARE: Readonly<Record<Placed["anchor"], number>> = { start: 0, middle: 0.5, end: 1 };

const boxOf = (x: number, y: number, anchor: Placed["anchor"], width: number): Box => {
  const x0 = x - width * LEFT_SHARE[anchor];

  return { x0: x0 - 2, y0: y - LABEL_HEIGHT + 2, x1: x0 + width + 2, y1: y + 3 };
};

/**
 * Labels for some points, each at the first spot around it that clears the plot's edges, every point and every label
 * placed before it, or the spot that overlaps least when none does.
 */
const placeLabels = (wanted: ReadonlyArray<{ readonly x: number; readonly y: number; readonly text: string }>, points: ReadonlyArray<{ readonly x: number; readonly y: number }>, bounds: Box, taken: ReadonlyArray<Box>, charWidth: number): ReadonlyArray<Placed> => {
  const obstacles: Array<Box> = [...taken, ...points.map(({ x, y }) => ({ x0: x - 6, y0: y - 6, x1: x + 6, y1: y + 6 }))];
  const placed: Array<Placed> = [];

  for (const { x, y, text } of wanted) {
    const width = text.length * charWidth;

    const scored = SPOTS.map(([dx, dy, anchor], order) => {
      const box = boxOf(x + dx, y + dy, anchor, width);
      const outside = Math.max(0, bounds.x0 - box.x0) + Math.max(0, box.x1 - bounds.x1) + Math.max(0, bounds.y0 - box.y0) + Math.max(0, box.y1 - bounds.y1);
      const cost = outside * 100 + obstacles.reduce((total, other) => total + overlap(box, other), 0);

      return { label: { x: x + dx, y: y + dy, anchor, text, box, of: { x, y } }, cost, order };
    }).toSorted((left, right) => left.cost - right.cost || left.order - right.order);

    const best = scored[0]?.label;

    if (best !== undefined) {
      placed.push(best);
      obstacles.push(best.box);
    }
  }

  return placed;
};

/** What one figure plots along x, and how it names it. */
export interface XAxis {
  readonly of: (config: Config) => number | null;
  readonly scale: (left: number, right: number) => Scale;
  readonly ticks: ReadonlyArray<readonly [number, string]>;
  readonly title: Readonly<Record<Layout, string>>;
  /** A point's label: its name and its x value. */
  readonly label: (config: Config, layout: Layout) => string;
  /** The settings named in the narrow layout, where the wide layout names the whole top group. */
  readonly narrowNames: (configs: ReadonlyArray<Config>) => ReadonlyArray<Config>;
  readonly extras: (plotted: ReadonlyArray<Config>, x: Scale, y: Scale, layout: Layout) => { readonly svg: ReadonlyArray<string>; readonly taken: ReadonlyArray<Box> };
}

export const scatterTip = (config: Config): string =>
  `${config.label} \u00b7 skill score ${rating(config.rating)} ${ratingInterval(config.lo, config.hi)} \u00b7 ${usd(config.cost)}/match \u00b7 ${config.tokensPerMove === null ? "no thinking count" : `${tokens(config.tokensPerMove)} thinking tok/move`} \u00b7 ${config.scored.toLocaleString("en-US")} matches`;

const mark = (config: Config, x: number, y: number): string =>
  config.isClaude ? `<circle class="pt" cx="${px(x)}" cy="${px(y)}" r="5"/>` : `<rect class="pt" x="${px(x - 4.5)}" y="${px(y - 4.5)}" width="9" height="9" rx="1"/>`;

const scatterDrawing = (configs: ReadonlyArray<Config>, axis: XAxis, layout: Layout, label: string): string => {
  const frame = FRAME[layout];
  const plotted = configs.filter((config) => !config.isFixed && axis.of(config) !== null);
  const x = axis.scale(frame.left, frame.right);
  const y = ratingScale(plotted, frame.bottom, frame.top);
  const xOf = (config: Config) => x.at(axis.of(config) ?? 0);
  const at = plotted.map((config) => ({ x: xOf(config), y: y.at(config.rating) }));
  const cells = tapCells(at, REACH);
  const references = configs.filter(isReference);
  const top = plotted.filter(isTopTier);
  const charWidth = CHAR_WIDTH[layout];

  const lines = [...groupBy(plotted, ({ family }) => family)].flatMap(([family, members]) => {
    const ordered = members.toSorted((left, right) => byEffort(left.effort, right.effort));

    return ordered.length < 2 ? [] : [`<polyline class="join" data-family="${familyId(family)}" points="${ordered.map((config) => `${px(xOf(config))},${px(y.at(config.rating))}`).join(" ")}"/>`];
  });

  const whiskers = top.map((config) => line(xOf(config), y.at(config.lo), xOf(config), y.at(config.hi), ` class="whisker" data-family="${familyId(config.family)}"`));

  const pointBoxes = at.map((spot) => ({ x0: spot.x - 10, y0: spot.y - 10, x1: spot.x + 10, y1: spot.y + 10 }));
  const covered = (box: Box) => pointBoxes.reduce((total, other) => total + overlap(box, other), 0);

  /** Each reference line's label at the plot's right end, or its left end when that clears more of the points. */
  const referenceLines = references.map((config) => {
    const ry = y.at(config.rating);
    const isSearch = config.model.startsWith("Engine/");
    const text = isSearch ? `${config.short} (0)` : config.short;
    const width = text.length * charWidth;
    const [startBox, endBox] = [boxOf(frame.left + 4, ry - 5, "start", width), boxOf(frame.right - 2, ry - 5, "end", width)];
    const atRight = covered(endBox) <= covered(startBox);
    const box = atRight ? endBox : startBox;

    return {
      svg: line(frame.left, ry, frame.right, ry, ` class="ref${isSearch ? " anchor" : ""}"`) + svgText(atRight ? frame.right - 2 : frame.left + 4, ry - 5, text, ` class="ref-label halo" text-anchor="${atRight ? "end" : "start"}"`),
      box,
    };
  });

  const extras = axis.extras(plotted, x, y, layout);
  const named = layout === "wide" ? top : axis.narrowNames(plotted);
  const labels = placeLabels(named.map((config) => ({ x: xOf(config), y: y.at(config.rating), text: axis.label(config, layout) })), at, { x0: frame.left, y0: frame.top - 30, x1: frame.right, y1: frame.bottom }, [...referenceLines.map(({ box }) => box), ...extras.taken], charWidth);

  const marks = plotted.map((config, index) => {
    const spot = at[index] ?? { x: 0, y: 0 };

    return tipped(scatterTip(config), `<path class="hit" d="${cellPath(cells[index] ?? [])}"/>${mark(config, spot.x, spot.y)}`, ` data-family="${familyId(config.family)}"`);
  });

  const body = [
    ...y.ticks.map((tick) => line(frame.left, y.at(tick), frame.right, y.at(tick), ' class="grid"') + (tick % frame.labelStep === 0 ? svgText(frame.left - 7, y.at(tick) + 4, rating(tick), ' class="tick" text-anchor="end"') : "")),
    ...axis.ticks.map(([value, text]) => line(x.at(value), frame.top, x.at(value), frame.bottom, ' class="grid"') + svgText(x.at(value), frame.bottom + 18, text, ' class="tick" text-anchor="middle"')),
    svgText(frame.left - 7, frame.top - 22, layout === "wide" ? "Skill score (0 = depth-7 search)" : "Skill score", ' class="axis-title"'),
    svgText((frame.left + frame.right) / 2, frame.bottom + 40, axis.title[layout], ' class="axis-title" text-anchor="middle"'),
    ...referenceLines.map(({ svg }) => svg),
    ...extras.svg,
    ...lines,
    ...whiskers,
    ...marks,
    ...labels.map(labelSvg),
  ];

  return drawing(layout, frame.width, frame.height, label, body.join(""));
};

/** A legend of the models, in shade order, Anthropic's circles then OpenAI's squares. */
const legend = (configs: ReadonlyArray<Config>): string => {
  const claude = new Set(configs.flatMap(({ isClaude, family }) => (isClaude ? [family] : [])));

  const items = familiesOf(configs).map((family) => {
    const swatch = claude.has(family) ? '<circle cx="6" cy="6" r="5"/>' : '<rect x="1.5" y="1.5" width="9" height="9" rx="1"/>';

    return `<li data-family="${familyId(family)}"><svg viewBox="0 0 12 12" width="12" height="12" aria-hidden="true">${swatch}</svg>${esc(family)}</li>`;
  });

  return `<ul class="legend" aria-label="Models">${items.join("")}</ul>`;
};

const scatterFigure = (configs: ReadonlyArray<Config>, axis: XAxis, label: string): string => legend(configs) + LAYOUTS.map((layout) => scatterDrawing(configs, axis, layout, label)).join("");

const noExtras: XAxis["extras"] = () => ({ svg: [], taken: [] });

/** Below one token a move, a setting sits in the lane at 0.3. */
const THINKING_FLOOR = 0.3;

const THINKING: XAxis = {
  of: ({ tokensPerMove }) => (tokensPerMove === null ? null : Math.max(THINKING_FLOOR, tokensPerMove)),
  scale: (left, right) => logScale(THINKING_FLOOR, 20_000, left + 10, right - 6),
  ticks: [[THINKING_FLOOR, "<1"], [1, "1"], [10, "10"], [100, "100"], [1000, "1k"], [10_000, "10k"]],
  title: { wide: "Thinking tokens per move, log scale", narrow: "Thinking tokens / move, log" },
  label: (config, layout) => (layout === "wide" ? `${config.short} \u00b7 ${tokens(config.tokensPerMove ?? 0)}` : config.short),
  narrowNames: (plotted) => {
    const top = plotted.filter(isTopTier).toSorted((left, right) => (left.tokensPerMove ?? 0) - (right.tokensPerMove ?? 0));

    return [top[0], top.at(-1)].filter((config) => config !== undefined);
  },
  extras: noExtras,
};

/** Figure 2 in both layouts, under a legend of the models. */
export const thinkingFigure = (configs: ReadonlyArray<Config>): string => scatterFigure(configs, THINKING, "Chart. Skill score against thinking tokens per move for every model setting, one line per model.");

/** The model settings with a cost, which Figure 3 places. */
export const pricedOf = (configs: ReadonlyArray<Config>): ReadonlyArray<Config> => configs.filter(({ isFixed, cost }) => !isFixed && cost > 0);

/** The top group's cheapest and dearest model settings, the ends of Figure 3's bracket. */
export const topTierRange = (configs: ReadonlyArray<Config>): readonly [Config, Config] | undefined => {
  const top = pricedOf(configs).filter(isTopTier).toSorted((left, right) => left.cost - right.cost);
  const [cheapest, dearest] = [top[0], top.at(-1)];

  return cheapest === undefined || dearest === undefined ? undefined : [cheapest, dearest];
};

/** How many times the dearest top-group setting costs the cheapest, rounded. */
export const priceRatio = (configs: ReadonlyArray<Config>): number => {
  const range = topTierRange(configs);

  return range === undefined ? 0 : Math.round(range[1].cost / range[0].cost);
};

const COST: XAxis = {
  of: ({ cost }) => (cost > 0 ? cost : null),
  scale: (left, right) => logScale(0.003, 6, left, right),
  ticks: [0.01, 0.03, 0.1, 0.3, 1, 3].map((tick) => [tick, `$${tick}`] as const),
  title: { wide: "Cost per match at list price, log scale", narrow: "Cost per match, log" },
  label: (config, layout) => (layout === "wide" ? `${config.short} ${usd(config.cost)}` : config.short),
  narrowNames: (plotted) => topTierRange(plotted) ?? [],
  extras: (plotted, x, y, layout) => {
    const frontier = paretoFrontier(plotted.filter(({ isProvisional }) => !isProvisional).map((config) => ({ x: config.cost, rating: config.rating })));
    const steps = frontier.map((point, index) => `${index === 0 ? "M" : "H"}${px(x.at(point.x))}${index === 0 ? `,${px(y.at(point.rating))}` : `V${px(y.at(point.rating))}`}`).join("");
    const range = topTierRange(plotted);
    const frontierSvg = frontier.length === 0 ? [] : [`<path class="frontier" d="${steps}"/>`];

    if (range === undefined) { return { svg: frontierSvg, taken: [] }; }

    const [cheapest, dearest] = range;
    const [x0, x1, by] = [x.at(cheapest.cost), x.at(dearest.cost), y.at(Math.max(cheapest.hi, dearest.hi)) - 10];
    const text = layout === "wide" ? `${priceRatio(plotted)}x the price, same top group` : `${priceRatio(plotted)}x the price`;
    const textY = by - 7;

    return {
      svg: [...frontierSvg, `<path class="bracket" d="M${px(x0)},${px(by + 6)}V${px(by)}H${px(x1)}V${px(by + 6)}"/>`, svgText((x0 + x1) / 2, textY, text, ' class="bracket-label halo" text-anchor="middle"')],
      taken: [{ x0: x0 - 4, y0: by - 2, x1: x1 + 4, y1: by + 8 }, boxOf((x0 + x1) / 2, textY, "middle", text.length * CHAR_WIDTH[layout])],
    };
  },
};

/** Figure 3 in both layouts, under a legend of the models. */
export const costFigure = (configs: ReadonlyArray<Config>): string => scatterFigure(configs, COST, "Chart. Skill score against cost per match for every model setting, one line per model, with the best score at each price as a dashed step.");
