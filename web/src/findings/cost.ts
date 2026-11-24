import { paretoFrontier } from "../charts/frontier.ts";
import { linScale, logScale } from "../charts/scales.ts";
import { cellPath, tapCells } from "../charts/tap-cells.ts";
import { byEffort, groupBy } from "../arena-viewer/page/data.ts";
import { isTopTier } from "./configs.ts";
import type { Config } from "./configs.ts";
import { ratingScale } from "./forest.ts";
import { drawing, esc, LAYOUTS, line, px, rating, ratingInterval, svgText, tipped, tokens, usd } from "./svg.ts";
import type { Layout } from "./svg.ts";

// Figure 3: cost per scored match (log) against the luck-adjusted Round Elo, one point per model config, each family's
// efforts joined weakest to strongest, the best rating available at each price as a step line, and a bracket over the
// top tier's price range.

const FRAME = {
  wide: { width: 960, height: 450, left: 56, right: 940, top: 56, bottom: 396, yStep: 50, charWidth: 6.7 },
  narrow: { width: 360, height: 380, left: 38, right: 352, top: 56, bottom: 326, yStep: 100, charWidth: 6.1 },
} as const;

const COST_TICKS = [0.01, 0.03, 0.1, 0.3, 1, 3];

const REACH = 14;

/** A family as an attribute value: "Opus 5.5" reads "opus-5-5". */
export const familyId = (family: string): string => family.toLowerCase().replaceAll(/[^a-z0-9]+/g, "-");

const seconds = (value: number | null): string => (value === null ? "no latency" : `${value.toFixed(1)} s/move`);

const reasoning = (value: number | null): string => (value === null ? "no reasoning count" : `${tokens(value)} reasoning tok/move`);

export const costTip = (config: Config): string =>
  `${config.label} \u00b7 Round Elo ${rating(config.rating)} ${ratingInterval(config.lo, config.hi)} \u00b7 ${usd(config.cost)}/match \u00b7 ${seconds(config.secondsPerMove)} \u00b7 ${reasoning(config.tokensPerMove)} \u00b7 ${config.scored} matches`;

/** The model configs the scatter places: those with a cost. */
export const pricedOf = (configs: ReadonlyArray<Config>): ReadonlyArray<Config> => configs.filter(({ isFixed, cost }) => !isFixed && cost > 0);

/** The top tier's cheapest and dearest model configs, the ends of the bracket. */
export const topTierRange = (configs: ReadonlyArray<Config>): readonly [Config, Config] | undefined => {
  const top = pricedOf(configs).filter(isTopTier).toSorted((left, right) => left.cost - right.cost);
  const [cheapest, dearest] = [top[0], top.at(-1)];

  return cheapest === undefined || dearest === undefined ? undefined : [cheapest, dearest];
};

interface Placed {
  readonly x: number;
  readonly y: number;
  readonly anchor: "start" | "end";
  readonly text: string;
  readonly width: number;
}

/** Labels beside their points, to the left near the right edge, each nudged down until it clears those above it. */
const placeLabels = (wanted: ReadonlyArray<{ readonly x: number; readonly y: number; readonly text: string }>, right: number, charWidth: number): ReadonlyArray<Placed> => {
  const placed: Array<Placed> = [];

  for (const { x, y, text } of wanted.toSorted((left, other) => left.y - other.y)) {
    const width = text.length * charWidth;
    const anchor = x + 8 + width > right ? "end" : "start";
    const from = anchor === "start" ? x + 8 : x - 8 - width;
    const overlaps = (labelY: number) => placed.some((other) => Math.abs(other.y - labelY) < 14 && from < (other.anchor === "start" ? other.x + other.width : other.x) && from + width > (other.anchor === "start" ? other.x : other.x - other.width));
    let labelY = y + 4;

    while (overlaps(labelY)) { labelY += 14; }

    placed.push({ x: anchor === "start" ? x + 8 : x - 8, y: labelY, anchor, text, width });
  }

  return placed;
};

const costDrawing = (configs: ReadonlyArray<Config>, layout: Layout): string => {
  const frame = FRAME[layout];
  const isWide = layout === "wide";
  const priced = pricedOf(configs);
  const x = logScale(0.003, 6, frame.left, frame.right);
  const yAxis = ratingScale(configs, frame.bottom, frame.top);
  const y = linScale(yAxis.ticks[0] ?? 0, yAxis.ticks.at(-1) ?? 0, frame.bottom, frame.top, yAxis.ticks.filter((tick) => tick % frame.yStep === 0));
  const at = priced.map((config) => ({ x: x.at(config.cost), y: y.at(config.rating) }));
  const cells = tapCells(at, REACH);

  const families = [...groupBy(priced, ({ family }) => family)].flatMap(([family, members]) => {
    const ordered = members.toSorted((left, right) => byEffort(left.effort, right.effort));

    return ordered.length < 2
      ? []
      : [`<polyline class="traj ${ordered[0]?.isClaude === true ? "claude" : "gpt"}" data-family="${familyId(family)}" points="${ordered.map((config) => `${px(x.at(config.cost))},${px(y.at(config.rating))}`).join(" ")}"/>`];
  });

  const frontier = paretoFrontier(priced.filter(({ isProvisional }) => !isProvisional).map((config) => ({ x: config.cost, rating: config.rating })));
  const steps = frontier.map((point, index) => `${index === 0 ? "M" : "H"}${px(x.at(point.x))}${index === 0 ? `,${px(y.at(point.rating))}` : `V${px(y.at(point.rating))}`}`).join("");

  const marks = priced.map((config, index) => {
    const spot = at[index] ?? { x: 0, y: 0 };
    const family = config.isClaude ? "claude" : "gpt";
    const hollow = config.isProvisional ? " hollow" : "";
    const point = config.isClaude ? `<circle class="dot ${family}${hollow}" cx="${px(spot.x)}" cy="${px(spot.y)}" r="4.5"/>` : `<rect class="dot ${family}${hollow}" x="${px(spot.x - 4)}" y="${px(spot.y - 4)}" width="8" height="8" rx="1"/>`;

    return tipped(costTip(config), `<path class="hit" d="${cellPath(cells[index] ?? [])}"/>${point}`, ` data-family="${familyId(config.family)}"`);
  });

  const range = topTierRange(configs);
  const bestOfTier2 = priced.find(({ tier }) => tier === 2);
  const named = isWide ? priced.filter((config) => isTopTier(config) || config === bestOfTier2) : (range ?? []);
  const labels = placeLabels(named.map((config) => ({ x: x.at(config.cost), y: y.at(config.rating), text: `${config.short} ${usd(config.cost)}` })), frame.right, frame.charWidth);

  const bracket = range === undefined ? [] : (() => {
    const [cheapest, dearest] = range;
    const [x0, x1, by] = [x.at(cheapest.cost), x.at(dearest.cost), frame.top - 14];

    return [
      `<path class="bracket" d="M${px(x0)},${by + 6}V${by}H${px(x1)}V${by + 6}"/>`,
      svgText((x0 + x1) / 2, by - 6, `${Math.round(dearest.cost / cheapest.cost)}x the price, same tier`, ' class="note strong-note" text-anchor="middle"'),
    ];
  })();

  const zero = y.at(0);

  const body = [
    ...y.ticks.map((tick) => line(frame.left, y.at(tick), frame.right, y.at(tick), ' class="grid"') + svgText(frame.left - 6, y.at(tick) + 4, rating(tick), ' class="tick" text-anchor="end"')),
    ...COST_TICKS.map((tick) => line(x.at(tick), frame.top, x.at(tick), frame.bottom, ' class="grid"') + svgText(x.at(tick), frame.bottom + 17, `$${tick}`, ' class="tick" text-anchor="middle"')),
    svgText(frame.left, frame.top - 36, isWide ? "Luck-adjusted Round Elo" : "Round Elo", ' class="title"'),
    svgText((frame.left + frame.right) / 2, frame.bottom + 38, isWide ? "Cost per scored match, list price, log scale" : "Cost per match, log scale", ' class="axis-title" text-anchor="middle"'),
    line(frame.left, zero, frame.right, zero, ' class="rule dashed"'),
    svgText(frame.left + 4, zero - 5, "depth-7 search \u00b7 $0", ' class="note halo"'),
    `<path class="frontier" d="${steps}H${frame.right}"/>`,
    ...families,
    ...bracket,
    ...marks,
    ...labels.map((label) => `<text class="label strong-label halo" x="${px(label.x)}" y="${px(label.y)}" text-anchor="${label.anchor}">${esc(label.text)}</text>`),
  ];

  return drawing(layout, frame.width, frame.height, "Chart. Cost per scored match against luck-adjusted Round Elo for every model config.", body.join(""));
};

/** Figure 3 in both layouts. */
export const costFigure = (configs: ReadonlyArray<Config>): string => LAYOUTS.map((layout) => costDrawing(configs, layout)).join("");

/** The top tier's model configs side by side: price, speed, reasoning tokens and rating. */
export const tierTable = (configs: ReadonlyArray<Config>): string => {
  const rows = configs.filter((config) => isTopTier(config) && !config.isFixed);

  const body = rows.map((config) =>
    `<tr><th scope="row">${esc(config.label)}</th><td>${usd(config.cost)}</td><td>${config.secondsPerMove === null ? "" : config.secondsPerMove.toFixed(1)}</td><td>${config.tokensPerMove === null ? "" : tokens(config.tokensPerMove)}</td><td>${rating(config.rating)} <span class="ci-text">${ratingInterval(config.lo, config.hi)}</span></td></tr>`);

  return `<div class="table-scroll"><table class="data"><caption>Tier 1 at a glance</caption><thead><tr><th scope="col">Config</th><th scope="col">$ / match</th><th scope="col">s / move</th><th scope="col">Reasoning tok / move</th><th scope="col">Round Elo</th></tr></thead><tbody>${body.join("")}</tbody></table></div>`;
};
