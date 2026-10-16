import { effortName, effortRank, modelFamily, modelName } from "../../arena/model-names.ts";
import { FILTER_FIELDS, type Filter, type Played } from "../filter.ts";
import type { Order } from "../sorting.ts";

// What the viewer's pages share: building elements, formatting, how a model
// and its effort read, and the filter pickers.

export type Child = Node | string | undefined | false;

export const h = <K extends keyof HTMLElementTagNameMap>(tag: K, attributes: Readonly<Record<string, string>> = {}, ...children: ReadonlyArray<Child>): HTMLElementTagNameMap[K] => {
  const element = document.createElement(tag);

  for (const [name, value] of Object.entries(attributes)) element.setAttribute(name, value);

  for (const child of children) if (child !== undefined && child !== false) element.append(child);

  return element;
};

export const dollars = (amount: number) => `$${amount.toFixed(4)}`;

export const count = (amount: number) => amount.toLocaleString("en-US");

export const fetchText = async (url: string): Promise<string> => {
  const response = await fetch(url);
  const text = await response.text();

  if (!response.ok) throw new Error(text);

  return text;
};

/** A model by its name, with the raw id as its tooltip. */
export const modelText = (model: string | undefined): HTMLElement => (model === undefined ? h("span", { class: "dim" }, "no calls yet") : h("span", { class: "model", title: model }, modelName(model)));

/** An effort as its own badge. "none" is a level, "unset" is a run that has no effort in its manifest. */
export const effortBadge = (effort: string | undefined): HTMLElement =>
  effort === undefined ? h("span", { class: "effort unset", title: "no effort in the manifest" }, "unset") : h("span", { class: "effort", title: `effort: ${effort}` }, effortName(effort));

/** A model, then its effort as a badge. */
export const modelLabel = (played: Played): ReadonlyArray<HTMLElement> => [modelText(played.model), effortBadge(played.effort)];

const PAGES = [
  ["Runs", "/"],
  ["Leaderboard", "/leaderboard"],
] as const;

/** The viewer's pages; the leaderboard only when the runs are a tournament's. */
export const nav = (current: "/" | "/leaderboard", leaderboard: boolean): HTMLElement =>
  h("nav", { class: "nav" }, ...PAGES.flatMap(([name, path]) => (leaderboard || path !== "/leaderboard" ? [h("a", path === current ? { href: path, "aria-current": "page" } : { href: path }, name)] : [])));

export type Field = (typeof FILTER_FIELDS)[number];

const PLACEHOLDERS = { model: "Any model", vs: "vs any model", family: "Any family", effort: "Any effort" } as const satisfies Record<Field, string>;

const distinct = (values: ReadonlyArray<string | undefined>): ReadonlyArray<string> => [...new Set(values.flatMap((value) => (value === undefined ? [] : [value])))];

/** What each field can be, from the models and efforts that were played, in the order a picker lists them. */
const valuesOf = (field: Field, played: ReadonlyArray<Played>): ReadonlyArray<string> => {
  switch (field) {
    case "model":
    case "vs":
      return distinct(played.map(({ model }) => model)).toSorted((left, right) => modelName(left).localeCompare(modelName(right)));
    case "family":
      return distinct(played.flatMap(({ model }) => (model === undefined ? [] : [modelFamily(model)]))).toSorted();
    case "effort":
      return distinct(played.map(({ effort }) => effort)).toSorted((left, right) => effortRank(left) - effortRank(right));
    default: {
      const _exhaustive: never = field;

      return _exhaustive;
    }
  }
};

const textOf = (field: Field, value: string): string => {
  switch (field) {
    case "model":
    case "vs":
      return modelName(value);
    case "family":
      return value;
    case "effort":
      return effortName(value);
    default: {
      const _exhaustive: never = field;

      return _exhaustive;
    }
  }
};

/** A picker for one field, set to the filter's choice; `choose` hears each change. */
export const picker = (field: Field, filter: Filter, played: ReadonlyArray<Played>, choose: (field: Field, value: string) => void): HTMLElement => {
  const values = valuesOf(field, played);
  const shown = filter[field] === "" || values.includes(filter[field]) ? values : [...values, filter[field]];
  const element = h("select", { "aria-label": PLACEHOLDERS[field], "data-field": field }, h("option", { value: "" }, PLACEHOLDERS[field]), ...shown.map((value) => h("option", { value }, textOf(field, value))));

  element.value = filter[field];
  element.addEventListener("change", () => choose(field, element.value));

  return element;
};

/** A table header; one with a column is a button that sorts by it, and says which way when it does. */
export const sortHeader = <Column extends string>(name: string, column: Column | undefined, order: Order<Column>, sortBy: (column: Column) => void): HTMLElement => {
  if (column === undefined) return h("th", {}, name);

  const active = order.kind === "by" && order.column === column ? order.direction : undefined;
  const button = h("button", { type: "button", class: "sort" }, name, active !== undefined && h("span", { class: "arrow" }, active === "asc" ? " ▲" : " ▼"));

  button.addEventListener("click", () => sortBy(column));

  return h("th", { "aria-sort": active === undefined ? "none" : active === "asc" ? "ascending" : "descending" }, button);
};
