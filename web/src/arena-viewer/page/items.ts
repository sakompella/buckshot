import type { Html, HtmlBuilder } from "foldkit/html";
import { inertHtml as ih } from "foldkit/html";

import { Item } from "../../domain.ts";
import { itemIcon } from "../../icons.ts";
import { itemName } from "../../text.ts";
import type { Message } from "./model.ts";

type H = HtmlBuilder<Message>;

// The table's own item drawings (src/icons.ts), found by the names the arena's events use, except the saw, the beer
// and the jammer, which the viewer draws side on as a hand saw, a beer can and a handheld antenna jammer: at the
// viewer's 14 to 24 px they read better than the table's top-down shapes. Original drawings, in the table's palette.

const INK = "#14110c";

const LIGHT = "rgb(255 255 255 / .35)";

const SHADE = "rgb(0 0 0 / .3)";

const path = (d: string, fill: string, stroke = "none", width = 0): Html =>
  ih.path([ih.D(d), ih.Fill(fill), ih.Stroke(stroke), ih.StrokeWidth(`${width}`), ih.StrokeLinejoin("round"), ih.StrokeLinecap("round")], []);

const box = (x: number, y: number, width: number, height: number, fill: string, rx = 0, stroke = "none", strokeWidth = 0): Html =>
  ih.rect([ih.X(`${x}`), ih.Y(`${y}`), ih.Width(`${width}`), ih.Height(`${height}`), ih.Rx(`${rx}`), ih.Fill(fill), ih.Stroke(stroke), ih.StrokeWidth(`${strokeWidth}`)], []);

const dot = (cx: number, cy: number, r: number, fill: string, stroke = "none", width = 0): Html =>
  ih.circle([ih.Cx(`${cx}`), ih.Cy(`${cy}`), ih.R(`${r}`), ih.Fill(fill), ih.Stroke(stroke), ih.StrokeWidth(`${width}`)], []);

// The saw's toothed edge runs from the heel (21, 22) to the tip (2, 17.6), one tooth hooked down every 2 px.
const TEETH = Array.from({ length: 10 }, (_tooth, index) => {
  const at = (share: number) => [21 - 19 * share, 22 - 4.4 * share] as const;
  const [x1, y1] = at(index / 10);
  const [x2, y2] = at((index + 0.6) / 10);

  return `L${x1.toFixed(2)} ${y1.toFixed(2)} L${x2.toFixed(2)} ${(y2 + 2).toFixed(2)}`;
}).join(" ");

const handSaw = (): ReadonlyArray<Html> => [
  path(`M2 13.6 L21 9 ${TEETH} L2 17.6 Z`, "#a7a89f", INK, 1),
  path("M3.5 14.2 L20 10.3", "none", LIGHT, 1.2),
  path("M20 8 L28 6.5 Q31.5 6.5 31.5 10 L31.5 23 Q31.5 26.5 28 26.5 L20 24 Z", "#8a4f2e", INK, 1),
  box(23.5, 11, 4.6, 10.5, "#1f140e", 2.2, INK, 0.8),
  path("M21.5 9.3 L28 8.2", "none", LIGHT, 1),
  path("M30.2 11 L30.2 23", "none", SHADE, 1.2),
  dot(21.6, 12.2, 0.9, "#c9b27a", INK, 0.5),
  dot(21.6, 20.4, 0.9, "#c9b27a", INK, 0.5),
];

const beerCan = (): ReadonlyArray<Html> => [
  path("M9 7.5 L9 27 Q9 29.5 12 29.5 L20 29.5 Q23 29.5 23 27 L23 7.5 Z", "#b9b6ab", INK, 1),
  box(9, 11.5, 14, 13.5, "#a3342a"),
  path("M9 18.5 Q12.5 16 16 18.5 T23 18.5", "none", "#e6d9ad", 1.6),
  dot(16, 14.4, 1.6, "#e6d9ad"),
  path("M9 11.5 L23 11.5 M9 25 L23 25", "none", "#4a1a14", 0.8),
  path("M11.2 9 L11.2 28", "none", LIGHT, 1.8),
  path("M21 9 L21 28", "none", SHADE, 2.2),
  path("M9 7.5 L9 27 Q9 29.5 12 29.5 L20 29.5 Q23 29.5 23 27 L23 7.5", "none", INK, 1),
  ih.ellipse([ih.Cx("16"), ih.Cy("7.5"), ih.Rx("7"), ih.Ry("2"), ih.Fill("#d8d4c8"), ih.Stroke(INK), ih.StrokeWidth("1")], []),
  ih.ellipse([ih.Cx("17.2"), ih.Cy("7.2"), ih.Rx("2.4"), ih.Ry("0.8"), ih.Fill("#6f6b62")], []),
];

const jammer = (): ReadonlyArray<Html> => [
  ...(
    [
      [8.5, 3],
      [13, 6.5],
      [19, 4.5],
      [23.5, 1.5],
    ] as const
  ).flatMap(([x, top]) => [box(x - 1.1, top, 2.2, 14 - top, "#2b2a25", 1.1, INK, 0.8), box(x - 1.7, 11.5, 3.4, 2.5, "#7d7b6c", 0.6, INK, 0.7)]),
  box(5, 13.5, 22, 16.5, "#5b5947", 2.5, INK, 1),
  path("M7 15 L25 15", "none", LIGHT, 1.2),
  path("M7 28.6 L25 28.6", "none", SHADE, 1.2),
  box(8, 17, 10, 6.5, "#1d2a1b", 1, INK, 0.9),
  path("M10 21.8 L10 20.6 M12.5 21.8 L12.5 19.4 M15 21.8 L15 18.4", "none", "#7fd06a", 1.3),
  dot(22.5, 18.6, 1.9, "#c1493a", INK, 0.8),
  box(20.6, 22, 3.8, 2.4, "#a3a393", 1, INK, 0.7),
  path("M8 26.4 L24 26.4", "none", INK, 1),
];

const VIEWER_DRAWINGS: Partial<Readonly<Record<Item, () => ReadonlyArray<Html>>>> = { Saw: handSaw, Beer: beerCan, Jammer: jammer };

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
