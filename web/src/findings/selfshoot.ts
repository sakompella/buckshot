import { linScale } from "../charts/scales.ts";
import type { Scale } from "../charts/scales.ts";
import { cellPath, tapCells } from "../charts/tap-cells.ts";
import type { CurvePoint, EffortRow, Findings, Group } from "./data.ts";
import { drawing, line, LAYOUTS, pct, pctInterval, points, pointsInterval, px, svgText, tipped } from "./svg.ts";
import type { Layout } from "./svg.ts";

// Figure 1: how often each group of models shot itself at each chance of a live shell, against the depth-7 search on
// the same states, with Sonnet 5.5 by effort beside it. P(live) is a linear axis, so the drop at 1/2 reads as a step.

const GROUP_NAMES: Readonly<Record<Group, string>> = { strong: "Strong models", haiku: "Haiku 4.5 and 5.5", luna: "Luna 6" };

const LINE_LABELS: Readonly<Record<Layout, Readonly<Record<Group | "search", string>>>> = {
  wide: { strong: "Strong models", search: "Depth-7 search", haiku: "Haiku", luna: "Luna" },
  narrow: { strong: "Strong", search: "Search", haiku: "Haiku", luna: "Luna" },
};

/** Where the main panel sits in each layout, and where the effort panel starts. */
const FRAME = {
  wide: { width: 960, height: 400, left: 48, right: 600, top: 40, bottom: 340, panelX: 668, panelTop: 40, panelWidth: 280, rowGap: 40 },
  narrow: { width: 360, height: 560, left: 34, right: 350, top: 34, bottom: 262, panelX: 8, panelTop: 330, panelWidth: 344, rowGap: 28 },
} as const;

const DRAWN: ReadonlyArray<Group> = ["luna", "haiku", "strong"];

const REACH = 16;

interface Dot {
  readonly x: number;
  readonly y: number;
  readonly r: number;
  readonly series: Group | "search";
  readonly tip: string;
}

const modelTip = (point: CurvePoint): string =>
  `${GROUP_NAMES[point.group]} at P(live) ${point.pLabel} \u00b7 shot themselves on ${pct(point.modelRate)} ${pctInterval(point.modelLo, point.modelHi)} of ${point.n.toLocaleString("en-US")} clean shots \u00b7 depth-7 search on the same states ${pct(point.searchRate)} ${pctInterval(point.searchLo, point.searchHi)}`;

const searchTip = (point: CurvePoint): string =>
  `Depth-7 search on the strong models' states at P(live) ${point.pLabel} \u00b7 prefers shooting itself on ${pct(point.searchRate)} ${pctInterval(point.searchLo, point.searchHi)} of ${point.n.toLocaleString("en-US")} shots`;

const RADIUS: Readonly<Record<Group | "search", number>> = { strong: 4, search: 3.5, haiku: 3, luna: 2.5 };

/** Labels at the left end of the lines, pushed apart where they would overlap. */
const spread = (ys: ReadonlyArray<number>, gap: number): ReadonlyArray<number> => {
  const order = ys.map((y, index) => ({ y, index })).toSorted((left, right) => left.y - right.y);
  const placed: Array<number> = [];

  for (const { y } of order) { placed.push(Math.max(y, (placed.at(-1) ?? -Infinity) + gap)); }

  return ys.map((_, index) => placed[order.findIndex((entry) => entry.index === index)] ?? 0);
};

const pathOf = (spots: ReadonlyArray<readonly [number, number]>): string => spots.map(([x, y], index) => `${index === 0 ? "M" : "L"}${px(x)},${px(y)}`).join("");

const mainPanel = (curve: ReadonlyArray<CurvePoint>, layout: Layout): string => {
  const frame = FRAME[layout];
  const pValues = [...new Map(curve.map((point) => [point.pLive, point.pLabel])).entries()].toSorted(([left], [right]) => left - right);
  const x: Scale = linScale(layout === "wide" ? 0.1 : 0.08, 0.8, frame.left, frame.right, pValues.map(([p]) => p));
  const y: Scale = linScale(0, 1, frame.bottom, frame.top, [0, 0.25, 0.5, 0.75, 1]);
  const byGroup = (group: Group) => curve.filter((point) => point.group === group).toSorted((left, right) => left.pLive - right.pLive);
  const strong = byGroup("strong");

  const dots: ReadonlyArray<Dot> = [
    ...DRAWN.flatMap((group) => byGroup(group).map((point) => ({ x: x.at(point.pLive), y: y.at(point.modelRate), r: RADIUS[group], series: group, tip: modelTip(point) }))),
    ...strong.map((point) => ({ x: x.at(point.pLive), y: y.at(point.searchRate), r: RADIUS.search, series: "search" as const, tip: searchTip(point) })),
  ];

  const cells = tapCells(dots, REACH);
  const lineOf = (group: Group) => `<path class="s-${group}" d="${pathOf(byGroup(group).map((point) => [x.at(point.pLive), y.at(point.modelRate)]))}"/>`;
  const whiskers = strong.flatMap((point) => [line(x.at(point.pLive), y.at(point.modelLo), x.at(point.pLive), y.at(point.modelHi), ' class="w-strong"'), line(x.at(point.pLive), y.at(point.searchLo), x.at(point.pLive), y.at(point.searchHi), ' class="w-search"')]);

  const first = (group: Group) => byGroup(group)[0];

  const labelled: ReadonlyArray<readonly [Group | "search", number]> = [
    ...DRAWN.flatMap((group) => {
      const point = first(group);

      return point === undefined ? [] : [[group, y.at(point.modelRate)] as const];
    }),
    ...(strong[0] === undefined ? [] : [["search", y.at(strong[0].searchRate)] as const]),
  ];

  const labelYs = spread(labelled.map(([, at]) => at + 4), layout === "wide" ? 15 : 13);
  const labelX = x.at(pValues[0]?.[0] ?? 0.25) - 9;
  const half = x.at(0.5);

  return [
    `<rect class="band" x="${px(x.at(0.2))}" y="${frame.top}" width="${px(half - x.at(0.2))}" height="${frame.bottom - frame.top}"/>`,
    svgText(half - 6, frame.top + 14, layout === "wide" ? "more blanks than lives" : "more blanks", ' class="note" text-anchor="end"'),
    ...y.ticks.map((tick) => line(frame.left, y.at(tick), frame.right, y.at(tick), ' class="grid"') + svgText(frame.left - 6, y.at(tick) + 4, pct(tick, 0), ' class="tick" text-anchor="end"')),
    ...pValues.map(([p, label]) => line(x.at(p), frame.bottom, x.at(p), frame.bottom + 4, ' class="axis"') + svgText(x.at(p), frame.bottom + 17, label, ' class="tick" text-anchor="middle"')),
    line(half, frame.top - 4, half, frame.bottom, ' class="rule"'),
    svgText(half, frame.top - 9, "even odds", ' class="note" text-anchor="middle"'),
    svgText(frame.left, frame.top - 22, "% of clean shots aimed at self", ' class="title"'),
    svgText((frame.left + frame.right) / 2, frame.bottom + 36, layout === "wide" ? "Chance the chambered shell is live, P(live)" : "P(live) of the chambered shell", ' class="axis-title" text-anchor="middle"'),
    ...whiskers,
    `<path class="s-search" d="${pathOf(strong.map((point) => [x.at(point.pLive), y.at(point.searchRate)]))}"/>`,
    ...DRAWN.map(lineOf),
    ...labelled.map(([series], index) => svgText(labelX, labelYs[index] ?? 0, LINE_LABELS[layout][series], ` class="label halo l-${series}" text-anchor="end"`)),
    ...dots.map((dot, index) => tipped(dot.tip, `<path class="hit" d="${cellPath(cells[index] ?? [])}"/><circle class="d-${dot.series}" cx="${px(dot.x)}" cy="${px(dot.y)}" r="${dot.r}"/>`)),
  ].join("");
};

const effortTip = (row: EffortRow): string =>
  `Sonnet 5.5 \u00b7 ${row.effort} \u00b7 shot itself on ${pct(row.modelRate)} of ${row.n} clean shots below even odds \u00b7 depth-7 search ${pct(row.searchRate)} \u00b7 gap ${points(row.gap)} ${pointsInterval(row.gapLo, row.gapHi)} points`;

const effortPanel = (rows: ReadonlyArray<EffortRow>, layout: Layout): string => {
  const frame = FRAME[layout];
  const labelWidth = 112;
  const x = linScale(0, 1, frame.panelX + labelWidth, frame.panelX + frame.panelWidth - 12, [0, 0.5, 1]);
  const rowY = (index: number) => frame.panelTop + 58 + index * frame.rowGap;
  const axisY = rowY(rows.length - 1) + frame.rowGap * 0.7;
  const best = rows.at(-1)?.effort;

  return [
    svgText(frame.panelX, frame.panelTop - 2, "Sonnet 5.5 by effort", ' class="title"'),
    svgText(frame.panelX, frame.panelTop + 16, "clean shots below even odds", ' class="note"'),
    ...x.ticks.map((tick) => line(x.at(tick), frame.panelTop + 34, x.at(tick), axisY, ' class="grid"') + svgText(x.at(tick), axisY + 15, pct(tick, 0), ' class="tick" text-anchor="middle"')),
    ...rows.map((row, index) => {
      const cy = rowY(index);
      const isBest = row.effort === best;

      const body = [
        `<rect class="hit" x="${frame.panelX}" y="${px(cy - frame.rowGap / 2)}" width="${frame.panelWidth}" height="${frame.rowGap}"/>`,
        svgText(frame.panelX, cy + 4, row.effort, isBest ? ' class="label strong-label"' : ' class="label"'),
        svgText(frame.panelX + labelWidth - 8, cy + 4, `n ${row.n}`, ' class="tick" text-anchor="end"'),
        line(x.at(row.searchRate), cy, x.at(row.modelRate), cy, ' class="gapline"'),
        line(x.at(row.searchRate), cy - 6, x.at(row.searchRate), cy + 6, ' class="d-search-tick"'),
        `<circle class="d-strong" cx="${px(x.at(row.modelRate))}" cy="${cy}" r="4.5"/>`,
      ].join("");

      return tipped(effortTip(row), body);
    }),
  ].join("");
};

const label = (findings: Findings): string =>
  `Chart. Below even odds, strong models shoot themselves on ${pct(findings.headline.strongModelRate, 0)} of clean shots; the depth-7 search prefers it on ${pct(findings.headline.strongSearchRate, 0)}.`;

/** Figure 1 in both layouts. */
export const selfShotFigure = (findings: Findings): string =>
  LAYOUTS.map((layout) => drawing(layout, FRAME[layout].width, FRAME[layout].height, label(findings), mainPanel(findings.curve, layout) + effortPanel(findings.sonnetEffort, layout))).join("");

