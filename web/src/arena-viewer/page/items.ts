import type { Html, HtmlBuilder } from "foldkit/html";
import { inertHtml as ih } from "foldkit/html";

import { Item } from "../../domain.ts";
import { itemIcon } from "../../icons.ts";
import { itemName } from "../../text.ts";
import type { Message } from "./model.ts";

type H = HtmlBuilder<Message>;

// The table's own item drawings (src/icons.ts), found by the names the arena's events use, except the saw, the beer
// and the jammer, which the viewer draws after the game's own: a folding pruning saw with a red grip, a silver can
// with a blue star label, and a flat black jammer with a green screen and a row of pale keys. At the viewer's 14 to
// 24 px these read better than the table's top-down shapes. Original drawings, in the table's palette.

const INK = "#14110c";

const LIGHT = "rgb(255 255 255 / .35)";

const SHADE = "rgb(0 0 0 / .3)";

const path = (d: string, fill: string, stroke = "none", width = 0): Html =>
  ih.path([ih.D(d), ih.Fill(fill), ih.Stroke(stroke), ih.StrokeWidth(`${width}`), ih.StrokeLinejoin("round"), ih.StrokeLinecap("round")], []);

const box = (x: number, y: number, width: number, height: number, fill: string, rx = 0, stroke = "none", strokeWidth = 0): Html =>
  ih.rect([ih.X(`${x}`), ih.Y(`${y}`), ih.Width(`${width}`), ih.Height(`${height}`), ih.Rx(`${rx}`), ih.Fill(fill), ih.Stroke(stroke), ih.StrokeWidth(`${strokeWidth}`)], []);

const dot = (cx: number, cy: number, r: number, fill: string, stroke = "none", width = 0): Html =>
  ih.circle([ih.Cx(`${cx}`), ih.Cy(`${cy}`), ih.R(`${r}`), ih.Fill(fill), ih.Stroke(stroke), ih.StrokeWidth(`${width}`)], []);

// The saw is drawn level and then tipped. Its teeth show along the seam where the folded blade meets the grip, the
// curve from (6, 16.4) through (16, 12) to (26, 15.2).
const seamAt = (share: number) =>
  [(1 - share) ** 2 * 6 + 2 * share * (1 - share) * 16 + share ** 2 * 26, (1 - share) ** 2 * 16.4 + 2 * share * (1 - share) * 12 + share ** 2 * 15.2] as const;

const TEETH = Array.from({ length: 11 }, (_tooth, index) => {
  const [x1, y1] = seamAt((index + 0.5) / 12);
  const [x2, y2] = seamAt((index + 1.5) / 12);

  return `L${x1.toFixed(2)} ${y1.toFixed(2)} L${((x1 + x2) / 2).toFixed(2)} ${((y1 + y2) / 2 + 1.5).toFixed(2)}`;
}).join(" ");

const pruningSaw = (): ReadonlyArray<Html> => [
  ih.g(
    [ih.Attribute("transform", "rotate(-22 16 16)")],
    [
      path("M6 16.4 Q16 12 26 15.2 Q17 25 6 16.4 Z", "#b4b4ab", INK, 1),
      path(`M6 16.4 ${TEETH} L26 15.2`, "none", INK, 0.7),
      path("M8 18 Q15 22.5 22 18.5", "none", SHADE, 1),
      path("M1.5 13.5 Q16 5.5 30.5 12 L30 16.6 Q16 10.8 2.5 18.4 Z", "#a1281f", INK, 1),
      path("M3.5 13.6 Q16 7.4 28.5 12.4", "none", LIGHT, 1),
      path("M1.5 13.5 Q3.5 12.3 6 11.3 L6.6 16.3 Q4.3 17.2 2.5 18.4 Z", "#2a2a28", INK, 1),
      path("M23 9.6 Q27 10.4 30.5 12 L30 16.6 Q26.8 15.3 23.4 14.6 Z", "#2a2a28", INK, 1),
      dot(26.8, 12.8, 1, "#9a5a34", INK, 0.5),
    ],
  ),
];

const beerCan = (): ReadonlyArray<Html> => [
  path("M9 7.5 L9 27 Q9 29.5 12 29.5 L20 29.5 Q23 29.5 23 27 L23 7.5 Z", "#c4c2ba", INK, 1),
  path("M9 17.5 L11.5 17.5 Q11.5 11 16 11 Q20.5 11 20.5 17.5 L23 17.5 L23 25 L9 25 Z", "#2f56a6"),
  path("M16.00 11.80 L16.85 14.23 L19.42 14.29 L17.38 15.86 L18.12 18.33 L16.00 16.87 L13.88 18.33 L14.62 15.86 L12.58 14.29 L15.15 14.23 Z", "#e8e8e2"),
  path("M10.5 20.5 L21.5 20.5 M11.5 22.6 L20.5 22.6", "none", "#e8e8e2", 1),
  path("M9 24 L23 24", "none", "#1a2f63", 0.8),
  path("M11.2 9 L11.2 28", "none", LIGHT, 1.8),
  path("M21 9 L21 28", "none", SHADE, 2.2),
  path("M9 7.5 L9 27 Q9 29.5 12 29.5 L20 29.5 Q23 29.5 23 27 L23 7.5", "none", INK, 1),
  ih.ellipse([ih.Cx("16"), ih.Cy("7.5"), ih.Rx("7"), ih.Ry("2"), ih.Fill("#dcdad2"), ih.Stroke(INK), ih.StrokeWidth("1")], []),
  ih.ellipse([ih.Cx("17.2"), ih.Cy("7.2"), ih.Rx("2.4"), ih.Ry("0.8"), ih.Fill("#6f6b62")], []),
];

const jammer = (): ReadonlyArray<Html> => [
  box(3.5, 4, 25, 24.5, "#2c2b27", 2.5, INK, 1),
  path("M5.5 5.6 L26.5 5.6", "none", LIGHT, 1),
  path("M5.5 27 L26.5 27", "none", SHADE, 1.2),
  box(6.5, 7, 19, 13, "#0f1a10", 1, INK, 0.9),
  path("M9.5 9 L9.5 18 M8.8 10 L9.5 10 M8.8 12 L9.5 12 M8.8 14 L9.5 14 M8.8 16 L9.5 16", "none", "#c9c6b8", 0.6),
  ih.circle([ih.Cx("17.5"), ih.Cy("13.5"), ih.R("4"), ih.Fill("none"), ih.Stroke("#58d84a"), ih.StrokeWidth("0.9")], []),
  path("M15 11 L20 16 M20 11 L15 16", "none", "#7cff63", 0.9),
  ...[6.5, 10.1, 13.7, 17.3].map((x) => box(x, 22, 3, 3.6, "#cdbfa6", 0.6, INK, 0.7)),
  box(22.2, 22.6, 3, 2.6, "#e0a92a", 0.5, INK, 0.7),
];

const VIEWER_DRAWINGS: Partial<Readonly<Record<Item, () => ReadonlyArray<Html>>>> = { Saw: pruningSaw, Beer: beerCan, Jammer: jammer };

const drawingOf = (item: Item): Html => {
  const drawing = VIEWER_DRAWINGS[item];

  return drawing === undefined
    ? itemIcon(item)
    : ih.svg([ih.ViewBox("0 0 32 32"), ih.Class("item-icon"), ih.AriaHidden(true), ih.Attribute("focusable", "false")], drawing());
};

const ITEM_BY_NAME = new Map(Item.literals.map((item) => [itemName(item), item]));

/** The drawing of the item with this name, or nothing for a name the table does not know. */
export const itemIconOf = (h: H, name: string): Html => {
  const item = ITEM_BY_NAME.get(name);

  return item === undefined ? h.empty : drawingOf(item);
};
