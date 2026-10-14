import type { Html } from "foldkit/html";
import { inertHtml as ih } from "foldkit/html";

import type { Item, Shell } from "./domain.ts";

// Original top-down drawings of the table's things, in a muted palette that
// the board's grain and scanlines sit over. Each item fits a 32 by 32 box.

const svg = (viewBox: string, className: string, children: ReadonlyArray<Html>): Html =>
  ih.svg([ih.ViewBox(viewBox), ih.Class(className), ih.AriaHidden(true), ih.Attribute("focusable", "false")], children);

const rect = (x: number, y: number, width: number, height: number, fill: string, rx = 0): Html =>
  ih.rect([ih.X(`${x}`), ih.Y(`${y}`), ih.Width(`${width}`), ih.Height(`${height}`), ih.Rx(`${rx}`), ih.Fill(fill)], []);

const circle = (cx: number, cy: number, r: number, fill: string, stroke = "none", width = 0): Html =>
  ih.circle([ih.Cx(`${cx}`), ih.Cy(`${cy}`), ih.R(`${r}`), ih.Fill(fill), ih.Stroke(stroke), ih.StrokeWidth(`${width}`)], []);

const path = (d: string, fill: string, stroke = "none", width = 0): Html =>
  ih.path([ih.D(d), ih.Fill(fill), ih.Stroke(stroke), ih.StrokeWidth(`${width}`), ih.StrokeLinejoin("round"), ih.StrokeLinecap("round")], []);

const INK = "#14110c";

const DRAWINGS: Readonly<Record<Item, () => ReadonlyArray<Html>>> = {
  Saw: () => [
    path("M4 21 L23 4 L28 9 L9 26 Z", "#8b8a80", INK, 1),
    path("M9 26 L9.5 23.5 L11.5 24 L12 21.6 L14 22 L14.5 19.6 L16.5 20 L17 17.6 L19 18 L19.5 15.6 L21.5 16 L22 13.6 L24 14 L24.5 11.6 L26.5 12 L28 9", "none", "#d6d1c2", 0.9),
    path("M1.5 23 L6 19 L11 25 L6.5 30 Z", "#6a3b26", INK, 1),
    path("M4.5 24 L6 22.6 L8 25 L6.6 26.4 Z", INK),
  ],
  Glass: () => [rect(19, 19, 4, 11, "#5a3424", 1.5), circle(14, 13, 9, "#5f7d78", "#a08f5c", 2.5), path("M9 10 Q12 7 15 7", "none", "#c8ddd6", 1.2)],
  Jammer: () => [rect(5, 10, 22, 16, "#4c4a3a", 2), rect(8, 13, 9, 6, "#1d2a1b", 1), circle(22, 20, 1.6, "#7fd06a"), path("M22 10 L26 2", "none", "#8a8878", 1.6), circle(26, 2.5, 1.3, "#8a8878")],
  Cigarettes: () => [rect(7, 4, 18, 25, "#cbc2aa", 1.5), rect(7, 4, 18, 7, "#8c2b20", 1.5), circle(11.5, 7.5, 1.6, "#e9e1cc"), circle(16, 7.5, 1.6, "#e9e1cc"), circle(20.5, 7.5, 1.6, "#e9e1cc"), rect(10, 17, 12, 6, "#a8a089", 1)],
  Beer: () => [circle(16, 16, 12, "#5f2a24", INK, 1), circle(16, 16, 9, "#8f8b80"), circle(16, 16, 7.4, "#a7a397"), rect(12, 13, 8, 5, "#6f6c63", 2.5), circle(16, 11, 1.2, INK)],
  Phone: () => [rect(9, 3, 14, 26, "#2c2c27", 2.5), rect(11, 6, 10, 9, "#456f4b", 1), ...[18, 21, 24].flatMap((y) => [12.5, 16, 19.5].map((x) => rect(x - 1, y - 1, 2, 2, "#8a8a7c")))],
  Inverter: () => [rect(5, 7, 22, 18, "#1f1e1a", 2), path("M16 7 L27 7 L27 25 L16 25 Z", "#c2bba6"), path("M9 16 L13 16 M11 14 L11 18", "none", "#c2bba6", 1.6), path("M19 16 L24 16", "none", "#1f1e1a", 1.6)],
  Adrenaline: () => [path("M6 26 L20 12", "none", "#c9cebb", 5), path("M9 23 L15 17", "none", "#9b2a22", 5), path("M20 12 L23 9", "none", "#6f6f66", 3), path("M23 9 L29 3", "none", "#b8b8ae", 1), path("M3 27 L7 23", "none", "#6f6f66", 4)],
  Remote: () => [rect(10, 3, 12, 26, "#383831", 3), circle(16, 9, 2.6, "#a32b22"), ...[15, 19, 23].flatMap((y) => [13.5, 18.5].map((x) => rect(x - 1.3, y - 1, 2.6, 2, "#77776c")))],
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
