import { Option, Schema } from "effect";

// How a table is sorted, kept in the query string as `sort` and `dir` next to
// its filters. Clicking a header runs its column one way, then the other, then
// back to the table's own order.

export type Direction = "asc" | "desc";

/** No sort in the query string is the page's own order. */
export type Order<Column extends string> = { readonly kind: "default" } | { readonly kind: "by"; readonly column: Column; readonly direction: Direction };

export const DEFAULT_ORDER: Order<never> = { kind: "default" };

/** The columns of a table, each with the way it runs when first chosen: the first rows are the ones to look at. */
export type Columns<Column extends string> = Readonly<Record<Column, Direction>>;

const decodeDirection = Schema.decodeUnknownOption(Schema.Literals(["asc", "desc"]));

export const orderFromQuery = <Column extends string>(columns: Columns<Column>, query: URLSearchParams): Order<Column> => {
  const column = Object.keys(columns).find((name): name is Column => name === query.get("sort"));

  return column === undefined ? DEFAULT_ORDER : { kind: "by", column, direction: Option.getOrElse(decodeDirection(query.get("dir")), () => columns[column]) };
};

export const writeOrder = <Column extends string>(query: URLSearchParams, order: Order<Column>): void => {
  query.delete("sort");
  query.delete("dir");

  if (order.kind === "by") {
    query.set("sort", order.column);
    query.set("dir", order.direction);
  }
};

/** A column's header was clicked: its first direction, then the reverse, then back to the default order. */
export const afterClick = <Column extends string>(columns: Columns<Column>, order: Order<Column>, column: Column): Order<Column> => {
  if (order.kind === "default" || order.column !== column) return { kind: "by", column, direction: columns[column] };

  return order.direction === columns[column] ? { kind: "by", column, direction: order.direction === "asc" ? "desc" : "asc" } : DEFAULT_ORDER;
};

export type Compare<Row> = (left: Row, right: Row) => number;

/**
 * Orders rows by a key, in a direction. A row without the key goes last whichever way the column runs,
 * so it never leads a table.
 */
export const byKey =
  <Row, Key>(key: (row: Row) => Key | undefined, compare: (left: Key, right: Key) => number) =>
  (direction: Direction): Compare<Row> =>
  (left, right) => {
    const [l, r] = [key(left), key(right)];

    if (l === undefined || r === undefined) return l === r ? 0 : l === undefined ? 1 : -1;

    return direction === "asc" ? compare(l, r) : compare(r, l);
  };

export const numerically = (left: number, right: number): number => left - right;

export const alphabetically = (left: string, right: string): number => left.localeCompare(right);
