import type { Html } from "foldkit/html";
import { inertHtml as ih } from "foldkit/html";

import type { Item, Shell } from "./domain.ts";

// Original top-down drawings of the table's things, in a muted palette that
// the board's grain and scanlines sit over. Each item fits a 32 by 32 box.

const svg = (viewBox: string, className: string, children: ReadonlyArray<Html>): Html =>
  ih.svg([ih.ViewBox(viewBox), ih.Class(className), ih.AriaHidden(true), ih.Attribute("focusable", "false")], children);

const rect = (x: number, y: number, width: number, height: number, fill: string, rx = 0, stroke = "none", strokeWidth = 0): Html =>
  ih.rect(
    [ih.X(`${x}`), ih.Y(`${y}`), ih.Width(`${width}`), ih.Height(`${height}`), ih.Rx(`${rx}`), ih.Fill(fill), ih.Stroke(stroke), ih.StrokeWidth(`${strokeWidth}`)],
    [],
  );

const circle = (cx: number, cy: number, r: number, fill: string, stroke = "none", width = 0): Html =>
  ih.circle([ih.Cx(`${cx}`), ih.Cy(`${cy}`), ih.R(`${r}`), ih.Fill(fill), ih.Stroke(stroke), ih.StrokeWidth(`${width}`)], []);

const ellipse = (cx: number, cy: number, rx: number, ry: number, fill: string, stroke = "none", width = 0): Html =>
  ih.ellipse([ih.Cx(`${cx}`), ih.Cy(`${cy}`), ih.Rx(`${rx}`), ih.Ry(`${ry}`), ih.Fill(fill), ih.Stroke(stroke), ih.StrokeWidth(`${width}`)], []);

const path = (d: string, fill: string, stroke = "none", width = 0): Html =>
  ih.path([ih.D(d), ih.Fill(fill), ih.Stroke(stroke), ih.StrokeWidth(`${width}`), ih.StrokeLinejoin("round"), ih.StrokeLinecap("round")], []);

/** A straight, square-ended bar between two points, `half` wide on each side of the line. */
const bar = (x1: number, y1: number, x2: number, y2: number, half: number, fill: string, stroke = "none", width = 0): Html => {
  const length = Math.hypot(x2 - x1, y2 - y1);
  const nx = (-(y2 - y1) / length) * half;
  const ny = ((x2 - x1) / length) * half;

  const corners: ReadonlyArray<readonly [number, number]> = [
    [x1 + nx, y1 + ny],
    [x2 + nx, y2 + ny],
    [x2 - nx, y2 - ny],
    [x1 - nx, y1 - ny],
  ];

  return path(`M${corners.map(([x, y]) => `${x.toFixed(2)} ${y.toFixed(2)}`).join(" L")} Z`, fill, stroke, width);
};

// Light comes from the top left: highlights sit on top and left edges, shade on bottom and right.
const LIGHT = "rgb(255 255 255 / .3)";

const SHADE = "rgb(0 0 0 / .3)";

const INK = "#14110c";

const DRAWINGS: Readonly<Record<Item, () => ReadonlyArray<Html>>> = {
  Saw: () => [
    path("M2 14.5 L22 10 L22 21.5 M22 21.50 L21.8 23.9 L20.0 21.2 L19.8 23.6 L18.0 21.0 L17.8 23.4 L16.0 20.8 L15.8 23.1 L14.0 20.5 L13.8 22.9 L12.0 20.2 L11.8 22.6 L10.0 20.0 L9.8 22.4 L8.0 19.8 L7.8 22.1 L6.0 19.5 L5.8 21.9 L4.0 19.2 L3.8 21.6 L2.0 19.0 Z", "#8f8e83", INK, 1),
    path("M3 15.2 L21 11.2", "none", LIGHT, 1),
    path("M3.5 18 L21 20.4", "none", SHADE, 1),
    path("M21 9 L29 8 Q31.5 8 31.5 11 L31.5 22 Q31.5 25 28.5 25 L21 24 Z", "#7a4429", INK, 1),
    path("M22.5 10.5 L29 9.7", "none", LIGHT, 1),
    path("M30 12 L30 23", "none", SHADE, 1),
    rect(24, 12, 4, 8, "#1f140e", 1.8),
    circle(22.8, 22.2, 0.8, "#c9b27a"),
  ],
  Glass: () => [
    path("M20 20 L27 27", "none", INK, 6.5),
    path("M20 20 L27 27", "none", "#6f4630", 4.5),
    path("M19.5 19.5 L22 22", "none", "#b09a5c", 4.5),
    circle(13, 13, 10, "#a08f5c", INK, 1),
    circle(13, 13, 7.2, "#5f7d78", INK, 1),
    path("M5.5 8 Q8 3.5 13 3.5", "none", LIGHT, 1.2),
    path("M8.5 11 Q10 8 13 7.6", "none", "#c8ddd6", 1.6),
    path("M21 16 Q20 21 15 21.5", "none", SHADE, 1.2),
  ],
  Jammer: () => [
    bar(8, 12, 6, 4, 1.4, "#7d7b6c", INK, 1),
    circle(5.8, 3.6, 2, "#b34a38", INK, 1),
    bar(23, 12, 27, 2.5, 1.4, "#7d7b6c", INK, 1),
    circle(27.3, 2.8, 2, "#c9b27a", INK, 1),
    rect(3, 11, 26, 18, "#5b5947", 2.5, INK, 1),
    path("M5 12.6 L27 12.6", "none", LIGHT, 1.2),
    path("M5 27.4 L27 27.4", "none", SHADE, 1.2),
    rect(6, 15, 11, 7, "#1d2a1b", 1, INK, 1),
    path("M7.4 16.4 L12 16.4", "none", "#6fae63", 1.2),
    circle(22, 17, 1.7, "#7fd06a", INK, 0.8),
    circle(22, 22, 1.7, "#c1493a", INK, 0.8),
    path("M6 25 L26 25", "none", INK, 1),
    path("M6 27 L26 27", "none", INK, 1),
  ],
  Cigarettes: () => [
    rect(8, 2, 3.4, 9, "#d8d1bb", 1, INK, 1),
    rect(12.4, 3.5, 3.4, 8, "#d8d1bb", 1, INK, 1),
    rect(8, 2, 3.4, 4, "#c4883f", 1, INK, 1),
    rect(12.4, 3.5, 3.4, 4, "#c4883f", 1, INK, 1),
    path("M23 10 L26.5 7 L26.5 27 L23 30 Z", "#8d8670", INK, 1),
    rect(5, 10, 18, 20, "#cdc4aa", 1.5, INK, 1),
    rect(6, 11, 16, 7, "#962f23", 0.5),
    path("M6.5 11.8 L21.5 11.8", "none", LIGHT, 1),
    circle(14, 14.5, 2.4, "#e9e1cc", INK, 0.8),
    path("M8 22.5 L20 22.5 M8 25.5 L16 25.5", "none", "#7e7761", 1.4),
    path("M6 29 L22 29", "none", SHADE, 1),
  ],
  Beer: () => [
    path("M7 8 L7 26 A9 3.4 0 0 0 25 26 L25 8 Z", "#97938a", INK, 1),
    path("M7 13 A9 3.4 0 0 0 25 13 L25 22 A9 3.4 0 0 1 7 22 Z", "#a03a2c"),
    path("M7 17.5 A9 3.4 0 0 0 25 17.5", "none", "#e0d4a8", 1.4),
    path("M7 13 A9 3.4 0 0 0 25 13 M7 22 A9 3.4 0 0 0 25 22", "none", "#4a1a14", 0.8),
    path("M9.3 9.5 L9.3 25.5", "none", LIGHT, 1.8),
    path("M23 10 L23 26", "none", SHADE, 2.4),
    path("M10 19.5 L12.4 21.2 M20 14.6 L21.4 15.6", "none", "rgb(255 255 255 / .55)", 0.9),
    ellipse(20.6, 24.6, 1.5, 0.8, "#6a3b26"),
    circle(11.4, 14.6, 0.6, "#6a3b26"),
    path("M7 24.2 A9 3.4 0 0 0 25 24.2", "none", "#6f6b62", 1),
    path("M7 8 L7 26 A9 3.4 0 0 0 25 26 L25 8", "none", INK, 1),
    ellipse(16, 8, 9, 3.4, "#cbc7b8", INK, 1),
    ellipse(16, 8.2, 7, 2.5, "#8a867a"),
    ellipse(13, 8.4, 2.4, 0.9, "#25241f"),
    ellipse(17.6, 7.6, 3.6, 1.7, "#e0dccd", INK, 0.9),
    ellipse(18.8, 7.6, 1.1, 0.6, INK),
    circle(15, 7.9, 0.8, "#6f6b62"),
  ],
  Phone: () => [
    rect(20, 0.5, 3, 5, "#3c3c35", 1, INK, 1),
    rect(8, 3.5, 16, 26, "#4d4d43", 3.2, INK, 1),
    path("M10.5 5 L21.5 5 M9.5 7 L9.5 25", "none", LIGHT, 1),
    path("M22.5 8 L22.5 26", "none", SHADE, 1),
    rect(10.5, 6.5, 11, 8, "#6f9c6a", 1, INK, 1),
    path("M11.8 8 L15.5 8", "none", "#b4d6ac", 1.2),
    rect(12.5, 16.2, 7, 1.6, "#a3a393", 0.8, INK, 0.6),
    ...[19.8, 22.6, 25.4].flatMap((y) => [10.8, 14.4, 18].map((x) => rect(x, y, 3.2, 2, "#b2b2a2", 0.8, INK, 0.6))),
  ],
  Inverter: () => [
    rect(3, 6, 26, 20, "#2a2924", 3, INK, 1),
    path("M6 6.5 L16 6.5 L16 25.5 L6 25.5 Q3.5 25.5 3.5 23 L3.5 9 Q3.5 6.5 6 6.5 Z", "#cfc8b2"),
    rect(16, 7, 12, 18, "#2a2924", 2),
    path("M5 8 L15 8 M5 8 L5 22", "none", "rgb(255 255 255 / .45)", 1),
    path("M7.5 16 L13 16 M10.2 13.3 L10.2 18.7", "none", "#2a2924", 2.2),
    path("M19 16 L25 16", "none", "#cfc8b2", 2.2),
    path("M16 6 L16 26", "none", INK, 1),
    path("M4 25 L28 25", "none", SHADE, 1),
    rect(3, 6, 26, 20, "none", 3, INK, 1),
  ],
  Adrenaline: () => [
    bar(2.5, 23.5, 8.5, 29.5, 1.3, "#8a8a7e", INK, 1),
    bar(6, 26, 11, 21, 1.1, "#a9a99c", INK, 1),
    bar(10.5, 21.5, 22, 10, 3.6, "#d4d8c6", INK, 1),
    bar(12.5, 19.5, 20, 12, 2.2, "#a8302a"),
    bar(8.4, 17.6, 14.4, 23.6, 1.4, "#9c9c90", INK, 1),
    bar(22, 10, 25, 7, 1.9, "#7d7d72", INK, 1),
    path("M25 7 L30 2", "none", INK, 2.6),
    path("M25 7 L30 2", "none", "#dedacb", 1),
    path("M12 21 L20 13", "none", LIGHT, 1),
  ],
  Remote: () => [
    rect(8, 1.5, 16, 29, "#4c4b41", 3.5, INK, 1),
    path("M11 3 L21 3 M9.5 5 L9.5 27", "none", LIGHT, 1),
    path("M22.6 6 L22.6 28", "none", SHADE, 1),
    circle(12.8, 7, 2.2, "#b0322a", INK, 0.8),
    circle(19.2, 7, 1.7, "#a3a393", INK, 0.8),
    circle(16, 15, 4.2, "#6d6d60", INK, 1),
    circle(16, 15, 1.5, "#a3a393", INK, 0.6),
    ...[21.5, 25.2].flatMap((y) => [10.6, 14.4, 18.2].map((x) => rect(x, y, 3.2, 2.6, "#a8a898", 0.8, INK, 0.7))),
  ],
};

export const itemIcon = (item: Item): Html => svg("0 0 32 32", "item-icon", DRAWINGS[item]());

/** A shell seen from the side, cap on the left. */
export const shellIcon = (shell: Shell): Html =>
  svg("0 0 40 14", `shell-icon ${shell === "Live" ? "live" : "blank"}`, [
    rect(9, 1, 30, 12, shell === "Live" ? "#a3281f" : "#2f5591", 2),
    rect(11, 3, 26, 2, shell === "Live" ? "#c8574a" : "#5a7fbd", 1),
    rect(1, 0.5, 10, 13, "#b08d4a", 1.5),
    rect(1, 0.5, 2.5, 13, "#7d6232", 1),
  ]);

/** The shotgun from above, muzzle down. A sawn-off barrel ends short. */
export const gunIcon = (isSawed: boolean): Html => {
  const barrelEnd = isSawed ? 128 : 186;

  return svg("0 0 40 190", "gun-icon", [
    path("M11 2 L29 2 L27 46 L13 46 Z", "#5b2f24", INK, 1.5),
    path("M14 8 L26 8", "none", "#74402f", 1.5),
    rect(13, 44, 14, 14, "#4a2a20", 2),
    rect(12, 56, 16, 30, "#2a2924", 2),
    rect(14, 60, 3, 22, "#4b4a42", 1),
    rect(14.5, 84, 5, barrelEnd - 84, "#3f3e37", 1.5),
    rect(20.5, 84, 5, Math.min(barrelEnd, 160) - 84, "#33322c", 1.5),
    rect(13, 104, 14, 22, "#5b2f24", 3),
    path("M13 110 L27 110 M13 115 L27 115 M13 120 L27 120", "none", "#3e2018", 1),
    rect(14, barrelEnd - 3, 6, 3, "#1b1a16", 1),
  ]);
};

const BOLT = "M11 1 L3 15 L9 15 L5 27 L15 11 L9 11 L13 1 Z";

export const boltIcon = (className: string): Html => svg("0 0 18 28", className, [path(BOLT, "currentColor")]);
