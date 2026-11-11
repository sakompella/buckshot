import { Option } from "effect";
import type { Html, HtmlBuilder } from "foldkit/html";

import { anchorId, linScale, logScale, REFERENCE, REFERENCE_DASH, selectView, tipView, toggleView } from "./charts.ts";
import { baseName, DEFAULT_EFFORT, effortLabel, fmtCount, fmtPct, fmtRating, fmtUsd, isClaude, isEngine, isProvisional } from "./data.ts";
import { leader, measureText, placeLabels, uncrowded } from "./labels.ts";
import { memoLast, type ModelStats } from "./derived.ts";
import { Message, type Model, type ScatterAxis } from "./model.ts";
import type { Rating } from "./ratings.ts";

type H = HtmlBuilder<Message>;

// Average cost, model moves or output tokens against the Round Elo, one point per config, labelled
// as on DeepSWE: the model's name, its effort below in small caps. The dashed line is the frontier: no other point is
// both lower on the x axis and higher rated. The search engines cost nothing, so they are labelled horizontal lines.

interface Axis {
  readonly label: string;
  readonly axisLabel: string;
  readonly isLog: boolean;
  /** A config's place on the axis, or null with nothing to place: no cost, tokens or moves, or no searched move. */
  readonly valueOf: (m: ModelStats) => number | null;
  readonly format: (value: number) => string;
  readonly tick: (value: number) => string;
  readonly perMatch: (value: number) => string;
}

interface Spot {
  readonly x: number;
  readonly y: number;
}

/** How far from a point a tap or the mouse still picks it: a fingertip's width. */
export const TAP_REACH = 22;

const CELL_SIDES = 24;

/** The part of the convex polygon `cell` nearer `own` than `other`: one Sutherland–Hodgman pass over their bisector. */
const nearerHalf = (cell: ReadonlyArray<Spot>, own: Spot, other: Spot): ReadonlyArray<Spot> => {
  const [dx, dy] = [other.x - own.x, other.y - own.y];
  const [mx, my] = [(own.x + other.x) / 2, (own.y + other.y) / 2];
  const side = ({ x, y }: Spot) => (x - mx) * dx + (y - my) * dy;

  return cell.flatMap((from, index) => {
    const to = cell[(index + 1) % cell.length] ?? from;
    const [a, b] = [side(from), side(to)];
    const kept = a <= 0 ? [from] : [];

    if ((a <= 0) === (b <= 0)) return kept;

    const t = a / (a - b);

    return [...kept, { x: from.x + t * (to.x - from.x), y: from.y + t * (to.y - from.y) }];
  });
};

/**
 * Each point's tap area: the places within `reach` of it that are nearer it than any other point, as a polygon. The
 * cells never overlap, so a tap among crowded points picks the nearest one, not the one drawn last.
 */
export const tapCells = (points: ReadonlyArray<Spot>, reach: number): ReadonlyArray<ReadonlyArray<Spot>> =>
  points.map((own, index) => {
    const around: ReadonlyArray<Spot> = Array.from({ length: CELL_SIDES }, (_, step) => ({ x: own.x + reach * Math.cos((2 * Math.PI * step) / CELL_SIDES), y: own.y + reach * Math.sin((2 * Math.PI * step) / CELL_SIDES) }));

    return points.reduce((cell, other, at) => (at === index || (other.x === own.x && other.y === own.y) ? cell : nearerHalf(cell, own, other)), around);
  });

const cellPath = (cell: ReadonlyArray<Spot>): string => (cell.length < 3 ? "" : `M${cell.map(({ x, y }) => `${x.toFixed(1)},${y.toFixed(1)}`).join("L")}Z`);

const positive = (value: number): number | null => (value > 0 ? value : null);

// Output tokens include reasoning tokens, as the providers report them.
export const AXES: Readonly<Record<ScatterAxis, Axis>> = {
  cost: {
    label: "Cost",
    axisLabel: "Cost / match (USD, log)",
    isLog: true,
    valueOf: (m) => positive(m.avgCost),
    format: fmtUsd,
    tick: (value) => `$${value}`,
    perMatch: (value) => `${fmtUsd(value)} / match`,
  },
  moves: {
    label: "Moves",
    axisLabel: "Model moves / match",
    isLog: false,
    valueOf: (m) => positive(m.avgMoves),
    format: (value) => value.toFixed(1),
    tick: String,
    perMatch: (value) => `${value.toFixed(1)} moves / match`,
  },
  tokens: {
    label: "Tokens",
    axisLabel: "Output tok / match (log)",
    isLog: true,
    valueOf: (m) => positive(m.avgOut),
    format: fmtCount,
    tick: (value) => (value >= 1e6 ? `${value / 1e6}M` : value >= 1e3 ? `${value / 1e3}k` : String(value)),
    perMatch: (value) => `${fmtCount(value)} output tok / match`,
  },
  regret: {
    label: "Accuracy",
    axisLabel: "Accuracy (lichess formula over points of round win chance lost)",
    isLog: false,
    valueOf: (m) => (m.regret === null ? null : m.regret.accuracy),
    format: (value) => value.toFixed(1),
    tick: String,
    perMatch: (value) => `accuracy ${value.toFixed(1)}`,
  },
};

const axisOptions = (hasRegret: boolean): ReadonlyArray<readonly [ScatterAxis, string]> => (hasRegret ? (["cost", "moves", "tokens", "regret"] as const) : (["cost", "moves", "tokens"] as const)).map((axis) => [axis, AXES[axis].label]);

interface Point {
  readonly m: ModelStats;
  readonly x: number;
  readonly rating: number;
  readonly rank: number | undefined;
}

const dominates = (other: Point, point: Point) => other.x <= point.x && other.rating >= point.rating && (other.x < point.x || other.rating > point.rating);

export const frontierOf = (points: ReadonlyArray<Point>) => {
  const ranked = points.filter(({ m }) => !isProvisional(m));

  return ranked.filter((point) => !ranked.some((other) => other !== point && dominates(other, point))).toSorted((left, right) => left.x - right.x);
};

/** The nearest 1-2-5 step strictly past a value. */
const stepPast = (value: number, direction: "down" | "up"): number => {
  const steps: Array<number> = [];

  for (let exponent = Math.floor(Math.log10(value)) - 1; exponent <= Math.ceil(Math.log10(value)) + 1; exponent++) for (const step of [1, 2, 5]) steps.push(Number((step * 10 ** exponent).toPrecision(3)));

  return direction === "down" ? (steps.findLast((step) => step < value) ?? value) : (steps.find((step) => step > value) ?? value);
};

// DeepSWE's chart type sizes (px), on desktop and below its 640px breakpoint. Its phone chart scales a 440px-wide
// drawing down to the screen; this one draws at the real width, so the phone sizes stay readable as they are.
const TYPE = { desktop: { title: 14, tick: 12, axis: 13, name: 12.5, eff: 10 }, phone: { title: 12, tick: 10, axis: 11, name: 11, eff: 9.5 } };

/** Below this chart width the controls are menus and the type is the phone's. */
const NARROW = 640;

const SANS = 'system-ui, "Inter", "Segoe UI", sans-serif';

const MONO = "ui-monospace, SFMono-Regular, Menlo, monospace";

const halo = (width: number) => ({ "paint-order": "stroke", stroke: "#000", "stroke-width": `${width}`, "stroke-linejoin": "round" });

const pointsOf = memoLast(
  (stats: ReadonlyArray<ModelStats>, ratings: ReadonlyMap<string, Rating>, ranks: ReadonlyMap<string, number>): Readonly<Record<ScatterAxis, ReadonlyArray<Point>>> => {
    const on = (axis: ScatterAxis): ReadonlyArray<Point> =>
      stats.flatMap((m) => {
        if (isEngine(m.model)) return [];

        const rating = ratings.get(m.key)?.rating;
        const rank = ranks.get(m.key);
        const x = AXES[axis].valueOf(m);

        return rating !== undefined && x !== null && m.scored > 0 ? [{ m, x, rating, rank }] : [];
      });

    return { cost: on("cost"), moves: on("moves"), tokens: on("tokens"), regret: on("regret") };
  },
);

/** Round steps of 1, 2 or 5 times a power of ten from low to high, as close to `count` of them as those steps allow. */
const linearTicks = (low: number, high: number, count: number): ReadonlyArray<number> => {
  const power = 10 ** Math.floor(Math.log10((high - low) / count));
  const steps = [1, 2, 5, 10].map((multiple) => multiple * power);
  const step = steps.reduce((best, candidate) => (Math.abs((high - low) / candidate - count) < Math.abs((high - low) / best - count) ? candidate : best));

  return Array.from({ length: Math.floor(high / step) - Math.ceil(low / step) + 1 }, (_tick, index) => (Math.ceil(low / step) + index) * step);
};

const L = 46;

const T = 40;

const B = 52;

/** The axes' extent, from every config whatever the filter, so a filter only shows or hides points. */
interface Domain {
  readonly x: Readonly<Record<ScatterAxis, readonly [number, number]>>;
  readonly elo: readonly [number, number];
}

const domainOf = memoLast((every: ReadonlyArray<ModelStats>, ratings: ReadonlyMap<string, Rating>): Domain => {
  const rated = every.filter((m) => m.scored > 0 && ratings.has(m.key));
  const extent = (values: ReadonlyArray<number>): readonly [number, number] => [Math.min(...values), Math.max(...values)];

  const xOf = (axis: ScatterAxis) =>
    extent(
      rated.flatMap((m) => {
        if (isEngine(m.model)) return [];

        const value = AXES[axis].valueOf(m);

        return value === null ? [] : [value];
      }),
    );

  return { x: { cost: xOf("cost"), moves: xOf("moves"), tokens: xOf("tokens"), regret: xOf("regret") }, elo: extent(rated.map((m) => ratings.get(m.key)?.rating ?? 0)) };
});

const xScaleOf = (axis: Axis, least: number, most: number, left: number, right: number) => {
  if (axis.isLog) return logScale(stepPast(least, "down"), stepPast(most, "up"), left, right);

  const pad = (most - least) * 0.06 || 1;

  return linScale(least - pad, most + pad, left, right, linearTicks(least - pad, most + pad, 9));
};

/**
 * The x ticks that get a label: powers of ten first, then the rest from left to right, each only where it clears the
 * labels already placed and the plot's edges.
 */
const labeledTicks = (ticks: ReadonlyArray<number>, at: (value: number) => number, text: (value: number) => string, font: string, left: number, right: number): ReadonlySet<number> => {
  const isPower = (value: number) => Number.isInteger(Math.log10(value));
  const placed: Array<{ readonly value: number; readonly from: number; readonly to: number }> = [];

  for (const value of [...ticks.filter(isPower), ...ticks.filter((value) => !isPower(value))]) {
    const half = measureText(text(value), font) / 2 + 5;
    const [from, to] = [at(value) - half, at(value) + half];

    if (from >= left - 20 && to <= right + 10 && placed.every((label) => to <= label.from || from >= label.to)) placed.push({ value, from, to });
  }

  return new Set(placed.map(({ value }) => value));
};

/** The rating axis: Elo grows upward in 50-point steps. */
const yScaleOf = (elo: readonly [number, number], top: number, bottom: number, isPhone: boolean) => {
  const low = Math.floor((elo[0] - 30) / 50) * 50;
  const high = Math.ceil((elo[1] + 30) / 50) * 50;
  const tickStep = isPhone ? 100 : 50;

  return linScale(
    low,
    high,
    bottom,
    top,
    Array.from({ length: Math.floor((high - low) / 50) + 1 }, (_tick, index) => low + index * 50).filter((tick) => tick % tickStep === 0),
  );
};

const layoutOf = memoLast((points: ReadonlyArray<Point>, width: number, scatterAxis: ScatterAxis, domain: Domain) => {
  if (points.length === 0) return null;

  const axis = AXES[scatterAxis];
  const isPhone = width < NARROW;
  const type = isPhone ? TYPE.phone : TYPE.desktop;
  const height = isPhone ? Math.round(Math.max(380, Math.min(480, width * 1.25))) : Math.round(Math.min(Math.max(width, 600), 960) / 1.6);
  const right = isPhone ? 12 : 24;
  const [least, most] = domain.x[scatterAxis];
  const x = xScaleOf(axis, least, most, L, width - right);
  const xLabels = labeledTicks(x.ticks, x.at, axis.tick, `${type.tick}px ${SANS}`, L, width - right);
  const y = yScaleOf(domain.elo, T, height - B, isPhone);

  const nameFont = `600 ${type.name}px ${SANS}`;
  const effortFont = `400 ${type.eff}px ${MONO}`;

  const at = points.map((point) => {
    const name = baseName(point.m.model);
    const effort = effortLabel(point.m.model, point.m.effort).toUpperCase();
    const labelWidth = Math.max(measureText(name, nameFont), measureText(effort, effortFont) + effort.length * type.eff * 0.08);

    return { x: x.at(point.x), y: y.at(point.rating), w: labelWidth, h: type.name + type.eff + 3, name, effort };
  });

  const frontier = frontierOf(points);
  const placed = placeLabels(at, { left: L, right: width - 2, top: T, bottom: height - B });

  // Where labels collide the frontier is labelled first, then medium effort, then by rating; the rest are left to hovering or tapping.
  const priority = points
    .map((point, index) => ({ index, order: (frontier.includes(point) ? 2e4 : 0) + (point.m.effort === DEFAULT_EFFORT ? 1e4 : 0) + point.rating }))
    .toSorted((left, right) => right.order - left.order)
    .map(({ index }) => index);

  return { isPhone, type, height, right, x, xLabels, y, at, labels: uncrowded(placed, priority), frontier };
});

const textAt = (h: H, x: number, y: number, anchor: string, style: Readonly<Record<string, string>>, text: string): Html =>
  h.text([h.X(`${x}`), h.Y(`${y}`), h.TextAnchor(anchor), h.Style(style)], [text]);

export const scatterView = (
  h: H,
  stats: ReadonlyArray<ModelStats>,
  everyConfig: ReadonlyArray<ModelStats>,
  ratings: ReadonlyMap<string, Rating>,
  ranks: ReadonlyMap<string, number>,
  scatter: Model["scatter"],
  width: number,
): Html => {
  const axis = AXES[scatter.axis];
  const yLabel = "Round Elo";
  const title = `${axis.label} vs Round Elo`;
  const byAxis = pointsOf(stats, ratings, ranks);
  const points = byAxis[scatter.axis];
  const layout = layoutOf(points, width, scatter.axis, domainOf(everyConfig, ratings));
  const activeKey = Option.orElse(scatter.maybeHover, () => scatter.maybePin);
  const active = Option.flatMap(activeKey, (key) => Option.fromUndefinedOr(points.find((point) => point.m.key === key)));
  const isDimmed = (point: Point) => Option.exists(active, (shown) => shown.m.model !== point.m.model);
  const dim = (point: Point) => (isDimmed(point) ? { opacity: "0.55", filter: "grayscale(1)" } : isProvisional(point.m) ? { opacity: "0.4" } : {});

  const axes = axisOptions(everyConfig.some(({ regret }) => regret !== null));
  const selectAxis = (option: ScatterAxis) => Message.SelectedScatterAxis({ axis: option });

  // A phone has no room for a row of buttons above the chart, so the choice is a menu.
  const controls = h.div([h.Class(width < NARROW ? "ctl menus" : "ctl")], [width < NARROW ? selectView(h, "x axis", scatter.axis, axes, selectAxis) : toggleView(h, scatter.axis, axes, selectAxis)]);

  if (layout === null) return h.div([h.Class("chart")], [h.div([h.Class("lbbar")], [h.h2([], [title])]), controls, h.div([h.Class("empty")], ["No scored matches for this filter."])]);

  const { type, height, right, x, xLabels, y, at, labels, frontier } = layout;
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

  const cells = tapCells(at, TAP_REACH);

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
        h.Tabindex(0),
        h.Role("button"),
        h.AriaLabel(point.m.label),
        h.OnKeyDownSelfPreventDefault((key) => (key === "Enter" || key === " " ? Option.some(Message.ClickedPoint({ key: point.m.key })) : Option.none())),
      ],
      [
        h.path([h.D(cellPath(cells[index] ?? [])), h.Fill("transparent")], []),
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
          textAt(h, L, T - 16, "start", { fill: "var(--fg)", "font-size": `${type.title}px`, "font-weight": "600" }, yLabel),
          ...y.ticks.map((value) => h.g([], [gridLine(L, width - right, y.at(value), y.at(value)), textAt(h, L - 10, y.at(value) + 4, "end", tick, fmtRating(value))])),
          ...x.ticks.map((value) => h.g([], [gridLine(x.at(value), x.at(value), T, height - B), xLabels.has(value) ? textAt(h, x.at(value), height - B + 18, "middle", tick, axis.tick(value)) : h.empty])),
          textAt(h, (L + width - right) / 2, height - 14, "middle", { fill: "var(--fg)", "font-size": `${type.axis}px` }, axis.axisLabel),
          ...stats.flatMap((m) => {
            const rating = ratings.get(m.key)?.rating;

            return isEngine(m.model) && rating !== undefined
              ? [
                  h.g(
                    [h.Class("anchor")],
                    [
                      h.line([h.X1(`${L}`), h.X2(`${width - right}`), h.Y1(`${y.at(rating)}`), h.Y2(`${y.at(rating)}`), h.Stroke(REFERENCE), h.StrokeOpacity("0.6"), h.StrokeDasharray("2 4")], []),
                      textAt(h, L + 4, y.at(rating) - 5, "start", { fill: "var(--mut)", "font-size": `${type.tick}px`, ...halo(3) }, `${m.label} ${fmtRating(rating)}`),
                    ],
                  ),
                ]
              : [];
          }),
          h.path(
            [
              h.D(frontier.map((point, index) => `${index === 0 ? "M" : "L"}${x.at(point.x)},${y.at(point.rating)}`).join("")),
              h.Fill("none"),
              h.Stroke(REFERENCE),
              h.StrokeOpacity("0.6"),
              h.StrokeWidth("1.25"),
              h.StrokeDasharray(REFERENCE_DASH),
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
            `${point.rank === undefined ? "provisional" : `rank ${point.rank}`} · Round Elo ${fmtRating(point.rating)} · ${fmtPct(point.m.roundShare)} of rounds won, ${fmtPct(point.m.winShare)} of matches won, ${fmtPct(point.m.potShare)} of the pot, over ${point.m.scored} matches`,
            h.br([]),
            axis.perMatch(point.x),
          ]),
      }),
    ],
  );
};
