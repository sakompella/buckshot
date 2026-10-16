import { Option, Schema } from "effect";

import type { PricedRun, Run } from "./api.ts";

// How the run list is ordered, kept in the query string as `sort` and `dir`
// next to the filters. A run missing the sorted value (no winner yet, no
// price) goes last whichever way the column runs, so it never leads a list.

export const SORT_COLUMNS = ["status", "started", "seed", "winner", "cost"] as const;

export type SortColumn = (typeof SORT_COLUMNS)[number];

export type Direction = "asc" | "desc";

/** No sort in the query string: live runs first, then every other run newest first. */
export type RunOrder = { readonly kind: "live-first" } | { readonly kind: "by"; readonly column: SortColumn; readonly direction: Direction };

export const LIVE_FIRST: RunOrder = { kind: "live-first" };

/** The way a column runs when first chosen: the first rows are the ones to look at. */
const FIRST_DIRECTION = { status: "asc", started: "desc", seed: "asc", winner: "asc", cost: "desc" } as const satisfies Record<SortColumn, Direction>;

const decodeColumn = Schema.decodeUnknownOption(Schema.Literals(SORT_COLUMNS));

const decodeDirection = Schema.decodeUnknownOption(Schema.Literals(["asc", "desc"]));

export const orderFromQuery = (query: URLSearchParams): RunOrder =>
  Option.match(decodeColumn(query.get("sort")), {
    onNone: () => LIVE_FIRST,
    onSome: (column): RunOrder => ({ kind: "by", column, direction: Option.getOrElse(decodeDirection(query.get("dir")), () => FIRST_DIRECTION[column]) }),
  });

export const writeOrder = (query: URLSearchParams, order: RunOrder): void => {
  query.delete("sort");
  query.delete("dir");

  if (order.kind === "by") {
    query.set("sort", order.column);
    query.set("dir", order.direction);
  }
};

/** A column's header was clicked: its first direction, then the reverse, then back to live first. */
export const afterClick = (order: RunOrder, column: SortColumn): RunOrder => {
  if (order.kind === "live-first" || order.column !== column) return { kind: "by", column, direction: FIRST_DIRECTION[column] };

  return order.direction === FIRST_DIRECTION[column] ? { kind: "by", column, direction: order.direction === "asc" ? "desc" : "asc" } : LIVE_FIRST;
};

type Compare = (left: Run, right: Run) => number;

const ranked = ["live", "finished", "fault", "stopped"] as const satisfies ReadonlyArray<PricedRun["status"]>;

/** Live, finished, fault, stopped; a run too old to read is last. */
const statusRank = (run: Run): number => (run.kind === "unreadable" ? ranked.length : ranked.indexOf(run.status));

const startedOf = (run: Run): string | undefined => (run.kind === "readable" ? run.started : undefined);

const seedOf = (run: Run): number | undefined => (run.kind === "readable" && !Number.isNaN(Number(run.seed)) ? Number(run.seed) : undefined);

/** The model that won, or the controller when it was no agent, and so what the column's winner is called. */
export const winnerOf = (run: Run): string | undefined => {
  if (run.kind === "unreadable") return undefined;

  const winner = run.standings?.[0];

  return winner === undefined ? undefined : (run.agents.find((agent) => agent.agent === winner.player)?.model ?? winner.controller ?? winner.player);
};

/** The dollars a run's calls cost, none when no price covers any of them. */
export const dollarsOf = (run: Run): number | undefined => (run.kind === "readable" && run.cost.calls > run.cost.unpriced ? run.cost.dollars : undefined);

const byNumber = (left: number, right: number): number => left - right;

const byText = (left: string, right: string): number => left.localeCompare(right);

const sorted =
  <K>(key: (run: Run) => K | undefined, compare: (left: K, right: K) => number) =>
  (direction: Direction): Compare =>
  (left, right) => {
    const [l, r] = [key(left), key(right)];

    if (l === undefined || r === undefined) return l === r ? 0 : l === undefined ? 1 : -1;

    return direction === "asc" ? compare(l, r) : compare(r, l);
  };

const COMPARATORS = {
  status: sorted(statusRank, byNumber),
  started: sorted(startedOf, byText),
  seed: sorted(seedOf, byNumber),
  winner: sorted(winnerOf, byText),
  cost: sorted(dollarsOf, byNumber),
} as const satisfies Record<SortColumn, (direction: Direction) => Compare>;

const newestFirst: Compare = (left, right) => COMPARATORS.started("desc")(left, right) || left.id.localeCompare(right.id);

const liveRank = (run: Run): number => (run.kind === "readable" && run.status === "live" ? 0 : 1);

const liveFirst: Compare = (left, right) => liveRank(left) - liveRank(right) || newestFirst(left, right);

export const orderRuns = (runs: ReadonlyArray<Run>, order: RunOrder): ReadonlyArray<Run> => {
  const compare: Compare = order.kind === "live-first" ? liveFirst : (left, right) => COMPARATORS[order.column](order.direction)(left, right) || newestFirst(left, right);

  return runs.toSorted(compare);
};
