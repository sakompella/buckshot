import { Option } from "effect";
import type { Html, HtmlBuilder } from "foldkit/html";

import { anchorId, logScale, linScale, switchView, tipView, toggleView } from "./charts.ts";
import { baseName, DEFAULT_EFFORT, fmtCount, groupBy, fmtPct, fmtRating, fmtUsd, isClaude, type ModelStats } from "./data.ts";
import { leader, measureText, placeLabels, uncrowded } from "./labels.ts";
import { memoLast } from "./derived.ts";
import { Message, type Model, type ScatterAxis } from "./model.ts";

type H = HtmlBuilder<Message>;

// Average cost, model moves or output tokens against the approximate rating, one point per config, labelled as on
// DeepSWE: the model's name, its effort below in small caps. The dashed line is the frontier: no other point is both
// lower on the x axis and higher rated.

/** Effort variants within this many rating points of the model's default effort are hidden (in doubt, show the default). */
const VARIANT_TOLERANCE = 25;

interface Axis {
  /** The switch's label, and the chart title's first word. */
  readonly label: string;
  readonly axisLabel: string;
  readonly isLog: boolean;
  readonly valueOf: (m: ModelStats) => number;
  /** The crosshair's reading. */
  readonly format: (value: number) => string;
  readonly tick: (value: number) => string;
  /** The tooltip's line for a point. */
  readonly perMatch: (value: number) => string;
}

// Output tokens include reasoning tokens, as the providers report them.
const AXES: Readonly<Record<ScatterAxis, Axis>> = {
  cost: {
    label: "Cost",
    axisLabel: "Avg cost per player per match (log)",
    isLog: true,
    valueOf: (m) => m.avgCost,
    format: fmtUsd,
    tick: (value) => `$${value}`,
    perMatch: (value) => `${fmtUsd(value)} per match`,
  },
  moves: {
    label: "Moves",
    axisLabel: "Avg model moves per player per match",
    isLog: false,
    valueOf: (m) => m.avgMoves,
    format: (value) => value.toFixed(1),
    tick: String,
    perMatch: (value) => `${value.toFixed(1)} moves per match`,
  },
  tokens: {
    label: "Output tokens",
    axisLabel: "Avg output tokens per player per match (log)",
    isLog: true,
    valueOf: (m) => m.avgOut,
    format: fmtCount,
    tick: (value) => (value >= 1e6 ? `${value / 1e6}M` : value >= 1e3 ? `${value / 1e3}k` : String(value)),
    perMatch: (value) => `${fmtCount(value)} output tokens per match`,
  },
};

const AXIS_OPTIONS: ReadonlyArray<readonly [ScatterAxis, string]> = (["cost", "moves", "tokens"] as const).map((axis) => [axis, AXES[axis].label]);

interface Point {
  readonly m: ModelStats;
  /** The x axis value. */
  readonly x: number;
  readonly rating: number;
}

const dominates = (other: Point, point: Point) => other.x <= point.x && other.rating >= point.rating && (other.x < point.x || other.rating > point.rating);

// RuneBench's rule: a variant is shown only if it is not within tolerance of the default and no row of its family
// dominates it; the default is hidden only when a shown variant dominates it.
const keepVariants = (points: ReadonlyArray<Point>): ReadonlyArray<Point> => {
  const families = groupBy(points, (point) => point.m.model);

  return [...families.values()].flatMap((family) => {
    const standard = family.find((point) => point.m.effort === DEFAULT_EFFORT);

    const kept = family.filter(
      (variant) => variant !== standard && !(standard !== undefined && Math.abs(variant.rating - standard.rating) < VARIANT_TOLERANCE) && !family.some((other) => other !== variant && dominates(other, variant)),
    );

    return standard !== undefined && !kept.some((variant) => dominates(variant, standard)) ? [standard, ...kept] : kept;
  });
};

const frontierOf = (points: ReadonlyArray<Point>) => points.filter((point) => !points.some((other) => other !== point && dominates(other, point))).toSorted((left, right) => left.x - right.x);

/** The nearest 1-2-5 step strictly past a value. */
const stepPast = (value: number, direction: "down" | "up"): number => {
  const steps: Array<number> = [];

  for (let exponent = Math.floor(Math.log10(value)) - 1; exponent <= Math.ceil(Math.log10(value)) + 1; exponent++) for (const step of [1, 2, 5]) steps.push(Number((step * 10 ** exponent).toPrecision(3)));

  return direction === "down" ? (steps.findLast((step) => step < value) ?? value) : (steps.find((step) => step > value) ?? value);
};

// DeepSWE's chart type sizes (px), on desktop and below its 640px breakpoint. Its phone chart scales a 440px-wide
// drawing down to the screen; this one draws at the real width, so the phone sizes stay readable as they are.
const TYPE = { desktop: { title: 14, tick: 12, axis: 13, name: 12.5, eff: 9 }, phone: { title: 12, tick: 10, axis: 11, name: 11, eff: 8.5 } };

const SANS = '-apple-system, BlinkMacSystemFont, "Inter", "Segoe UI", sans-serif';

const MONO = "ui-monospace, SFMono-Regular, Menlo, monospace";

const halo = (width: number) => ({ "paint-order": "stroke", stroke: "#000", "stroke-width": `${width}`, "stroke-linejoin": "round" });

const pointsOf = memoLast(
  (stats: ReadonlyArray<ModelStats>, ratings: ReadonlyMap<string, number>): Readonly<Record<ScatterAxis, ReadonlyArray<Point>>> => {
    const on = (axis: ScatterAxis): ReadonlyArray<Point> =>
      stats.flatMap((m) => {
        const rating = ratings.get(m.key);
        const x = AXES[axis].valueOf(m);

        return rating !== undefined && x > 0 && m.scored.length > 0 ? [{ m, x, rating }] : [];
      });

    return { cost: on("cost"), moves: on("moves"), tokens: on("tokens") };
  },
);

/** Round steps of 1, 2 or 5 times a power of ten from low to high, about `count` of them. */
const linearTicks = (low: number, high: number, count: number): ReadonlyArray<number> => {
  const raw = (high - low) / count;
  const power = 10 ** Math.floor(Math.log10(raw));
  const step = ([1, 2, 5, 10].find((multiple) => multiple * power >= raw) ?? 10) * power;

  return Array.from({ length: Math.floor(high / step) - Math.ceil(low / step) + 1 }, (_tick, index) => (Math.ceil(low / step) + index) * step);
};

// The kept variants are chosen by cost on every axis, so switching the axis moves points but never hides or shows one.
const keptKeysOf = memoLast((byCost: ReadonlyArray<Point>): ReadonlyArray<string> => keepVariants(byCost).map(({ m }) => m.key));

const shownOf = memoLast((every: ReadonlyArray<Point>, kept: ReadonlyArray<string>, show: string): ReadonlyArray<Point> => {
  if (show === "all") return every;

  if (show === "medium") return every.filter((point) => point.m.effort === DEFAULT_EFFORT);

  return kept.flatMap((key) => every.filter((point) => point.m.key === key));
});

const L = 46;

const T = 40;

const B = 52;

const xScaleOf = (axis: Axis, values: ReadonlyArray<number>, left: number, right: number, isPhone: boolean) => {
  const least = Math.min(...values);
  const most = Math.max(...values);

  if (axis.isLog) return logScale(stepPast(least, "down"), stepPast(most, "up"), left, right);

  const pad = Math.max((most - least) * 0.06, 1);

  return linScale(least - pad, most + pad, left, right, linearTicks(least - pad, most + pad, isPhone ? 4 : 8));
};

const layoutOf = memoLast((points: ReadonlyArray<Point>, width: number, axis: Axis) => {
  if (points.length === 0) return null;

  const isPhone = width < 640;
  const type = isPhone ? TYPE.phone : TYPE.desktop;
  const height = isPhone ? Math.round(Math.max(380, Math.min(480, width * 1.25))) : Math.round(Math.min(Math.max(width, 600), 960) / 1.6);
  const right = isPhone ? 12 : 24;
  const ratings = points.map(({ rating }) => rating);
  const xFull = xScaleOf(axis, points.map((point) => point.x), L, width - right, isPhone);
  const x = isPhone && xFull.ticks.length > 4 ? { ...xFull, ticks: xFull.ticks.filter((_tick, index) => index % 2 === 0) } : xFull;
  const low = Math.floor((Math.min(...ratings) - 30) / 50) * 50;
  const high = Math.ceil((Math.max(...ratings) + 30) / 50) * 50;
  const tickStep = isPhone ? 100 : 50;

  const y = linScale(
    low,
    high,
    height - B,
    T,
    Array.from({ length: Math.floor((high - low) / 50) + 1 }, (_tick, index) => low + index * 50).filter((tick) => tick % tickStep === 0),
  );

  const nameFont = `600 ${type.name}px ${SANS}`;
  const effortFont = `400 ${type.eff}px ${MONO}`;

  const at = points.map((point) => {
    const name = baseName(point.m.model);
    const effort = point.m.effort.toUpperCase();
    const labelWidth = Math.max(measureText(name, nameFont), measureText(effort, effortFont) + effort.length * type.eff * 0.08);

    return { x: x.at(point.x), y: y.at(point.rating), w: labelWidth, h: type.name + type.eff + 3, name, effort };
  });

  const frontier = frontierOf(points);
  const placed = placeLabels(at, { left: L, right: width - 2, top: T, bottom: height - B });

  // On a phone the frontier is labelled first, then medium effort, then by rating; crowded points are left to tapping.
  const priority = points
    .map((point, index) => ({ index, rank: (frontier.includes(point) ? 2e4 : 0) + (point.m.effort === DEFAULT_EFFORT ? 1e4 : 0) + point.rating }))
    .toSorted((left, right) => right.rank - left.rank)
    .map(({ index }) => index);

  return { isPhone, type, height, right, x, y, at, labels: isPhone ? uncrowded(placed, priority) : placed, frontier };
});

const textAt = (h: H, x: number, y: number, anchor: string, style: Readonly<Record<string, string>>, text: string): Html =>
  h.text([h.X(`${x}`), h.Y(`${y}`), h.TextAnchor(anchor), h.Style(style)], [text]);

/** The scatter card's chart, `width` wide. */
export const scatterView = (h: H, stats: ReadonlyArray<ModelStats>, ratings: ReadonlyMap<string, number>, scatter: Model["scatter"], width: number): Html => {
  const axis = AXES[scatter.axis];
  const title = `${axis.label} vs rating (approx.)`;
  const byAxis = pointsOf(stats, ratings);
  const every = byAxis[scatter.axis];
  const kept = keptKeysOf(byAxis.cost);
  const points = shownOf(every, kept, scatter.show);
  const layout = layoutOf(points, width, axis);
  const hidden = every.filter((point) => !kept.includes(point.m.key)).length;
  const activeKey = Option.orElse(scatter.maybeHover, () => scatter.maybePin);
  const active = Option.flatMap(activeKey, (key) => Option.fromUndefinedOr(points.find((point) => point.m.key === key)));
  const isDimmed = (point: Point) => Option.exists(active, (shown) => shown.m.model !== point.m.model);
  const dim = (point: Point) => (isDimmed(point) ? { opacity: "0.55", filter: "grayscale(1)" } : {});

  const controls = h.div(
    [h.Class("ctl")],
    [
      toggleView(h, scatter.axis, AXIS_OPTIONS, (option) => Message.SelectedScatterAxis({ axis: option })),
      hidden > 0 ? switchView(h, scatter.show === "all", `all efforts (${hidden} hidden)`, Message.SelectedScatterShow({ show: scatter.show === "all" ? "kept" : "all" })) : h.empty,
      switchView(h, scatter.show === "medium", "medium only", Message.SelectedScatterShow({ show: scatter.show === "medium" ? "kept" : "medium" })),
    ],
  );

  if (layout === null) return h.div([h.Class("chart")], [h.div([h.Class("lbbar")], [h.h2([], [title])]), controls, h.div([h.Class("empty")], ["No scored matches for this filter."])]);

  const { type, height, right, x, y, at, labels, frontier } = layout;
  const grid = { stroke: "oklch(72% 0 0)", "stroke-opacity": "0.25" };
  const tick = { fill: "oklch(72% 0 0)", "font-size": `${type.tick}px` };
  const gridLine = (x1: number, x2: number, y1: number, y2: number) => h.line([h.X1(`${x1}`), h.X2(`${x2}`), h.Y1(`${y1}`), h.Y2(`${y2}`), h.Style(grid)], []);

  const crosshair = Option.match(active, {
    onNone: () => h.empty,
    onSome: (point) => {
      const ax = x.at(point.x);
      const ay = y.at(point.rating);
      const color = point.m.color;
      const label = { fill: color, "font-size": `${type.tick}px`, "font-weight": "600", ...halo(4) };

      return h.g(
        [h.PointerEvents("none")],
        [
          h.line([h.X1(`${ax}`), h.Y1(`${ay}`), h.X2(`${ax}`), h.Y2(`${height - B}`), h.Stroke(color), h.StrokeDasharray("4 4")], []),
          h.line([h.X1(`${L}`), h.Y1(`${ay}`), h.X2(`${ax}`), h.Y2(`${ay}`), h.Stroke(color), h.StrokeDasharray("4 4")], []),
          textAt(h, ax, height - B + 18, "middle", label, axis.format(point.x)),
          textAt(h, L - 10, ay + 4, "end", label, fmtRating(point.rating)),
        ],
      );
    },
  });

  const leaders = labels.flatMap((label) => {
    const segment = leader(label);
    const point = points[label.idx];

    return segment === null || point === undefined
      ? []
      : [h.line([h.X1(`${segment.x1}`), h.Y1(`${segment.y1}`), h.X2(`${segment.x2}`), h.Y2(`${segment.y2}`), h.Stroke(point.m.color), h.StrokeOpacity("0.35"), h.Style(dim(point))], [])];
  });

  const dots = points.map((point, index) => {
    const spot = at[index];
    const isOn = Option.exists(active, (shown) => shown === point);
    const r = isOn ? 6.5 : 4.5;

    if (spot === undefined) return h.empty;

    return h.keyed("g")(
      point.m.key,
      [
        h.Id(anchorId("pt", point.m.key)),
        h.Class("pt"),
        h.Style({ cursor: "pointer", ...dim(point) }),
        h.OnMouseEnter(Message.HoveredPoint({ key: point.m.key })),
        h.OnMouseLeave(Message.LeftPoint()),
        h.OnClick(Message.ClickedPoint({ key: point.m.key }), { propagation: "Stop" }),
      ],
      [
        h.circle([h.Cx(`${spot.x}`), h.Cy(`${spot.y}`), h.R("14"), h.Fill("transparent")], []),
        isClaude(point.m.model)
          ? h.circle([h.Cx(`${spot.x}`), h.Cy(`${spot.y}`), h.R(`${r}`), h.Fill(point.m.color), h.Stroke("#000")], [])
          : h.rect([h.X(`${spot.x - r}`), h.Y(`${spot.y - r}`), h.Width(`${2 * r}`), h.Height(`${2 * r}`), h.Rx("1.5"), h.Fill(point.m.color), h.Stroke("#000")], []),
      ],
    );
  });

  const names = labels.map((label) => {
    const spot = at[label.idx];
    const point = points[label.idx];

    if (spot === undefined || point === undefined) return h.empty;

    const nameY = label.y - label.h / 2 + type.name * 0.82;

    return h.g(
      [h.Class("ptlabel"), h.Style(dim(point))],
      [
        textAt(h, label.anchorX, nameY, label.align, { fill: point.m.color, "font-size": `${type.name}px`, "font-weight": "600", ...halo(3.5) }, spot.name),
        textAt(h, label.anchorX, nameY + type.eff + 1.5, label.align, { fill: point.m.color, "font-family": MONO, "font-size": `${type.eff}px`, "letter-spacing": "0.08em", opacity: "0.6", ...halo(3) }, spot.effort),
      ],
    );
  });

  return h.div(
    [h.Class("chart")],
    [
      h.div([h.Class("lbbar")], [h.h2([], [title])]),
      controls,
      h.svg(
        [h.Width(`${width}`), h.Height(`${height}`), h.OnClick(Message.ClickedOutsideChart())],
        [
          textAt(h, L, T - 16, "start", { fill: "var(--fg)", "font-size": `${type.title}px`, "font-weight": "600" }, "Rating (approx.)"),
          ...y.ticks.map((value) => h.g([], [gridLine(L, width - right, y.at(value), y.at(value)), textAt(h, L - 10, y.at(value) + 4, "end", tick, fmtRating(value))])),
          ...x.ticks.map((value) => h.g([], [gridLine(x.at(value), x.at(value), T, height - B), textAt(h, x.at(value), height - B + 18, "middle", tick, axis.tick(value))])),
          textAt(h, (L + width - right) / 2, height - 14, "middle", { fill: "var(--fg)", "font-size": `${type.axis}px` }, axis.axisLabel),
          h.path(
            [
              h.D(frontier.map((point, index) => `${index === 0 ? "M" : "L"}${x.at(point.x)},${y.at(point.rating)}`).join("")),
              h.Fill("none"),
              h.Stroke("#777"),
              h.StrokeOpacity("0.6"),
              h.StrokeWidth("1.25"),
              h.StrokeDasharray("3 4"),
            ],
            [],
          ),
          crosshair,
          ...leaders,
          ...dots,
          ...names,
        ],
      ),
      Option.match(active, {
        onNone: () => h.empty,
        onSome: (point) =>
          tipView(h, anchorId("pt", point.m.key), [
            h.b([], [point.m.label]),
            h.br([]),
            `rating ${fmtRating(point.rating)} · ${fmtPct(point.m.winShare)} wins of ${point.m.scored.length}`,
            h.br([]),
            axis.perMatch(point.x),
          ]),
      }),
    ],
  );
};
