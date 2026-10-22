import type { Html, HtmlBuilder } from "foldkit/html";

import { Item } from "../../domain.ts";
import { itemIcon } from "../../icons.ts";
import { itemName } from "../../text.ts";
import type { Message } from "./model.ts";

type H = HtmlBuilder<Message>;

// The table's own item drawings (src/icons.ts), found by the names the arena's events use.

const ITEM_BY_NAME = new Map(Item.literals.map((item) => [itemName(item), item]));

/** The drawing of the item with this name, or nothing for a name the table does not know. */
export const itemIconOf = (h: H, name: string): Html => {
  const item = ITEM_BY_NAME.get(name);

  return item === undefined ? h.empty : itemIcon(item);
};
