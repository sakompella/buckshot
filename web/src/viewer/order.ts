import { modelName } from "../arena/model-names.ts";
import type { PricedRun, Run } from "./api.ts";
import { afterClick as afterClickIn, alphabetically, byKey, type Columns, type Compare, DEFAULT_ORDER, type Direction, numerically, type Order, orderFromQuery as orderFromQueryIn } from "./sorting.ts";

export { writeOrder } from "./sorting.ts";

// How the run list is ordered. A run missing the sorted value (no winner yet,
// no price) goes last whichever way the column runs.

export type SortColumn = "status" | "started" | "seed" | "winner" | "cost";

export type RunOrder = Order<SortColumn>;

/** No sort in the query string: live runs first, then every other run newest first. */
export const LIVE_FIRST: RunOrder = DEFAULT_ORDER;

const COLUMNS: Columns<SortColumn> = { status: "asc", started: "desc", seed: "asc", winner: "asc", cost: "desc" };

export const orderFromQuery = (query: URLSearchParams): RunOrder => orderFromQueryIn(COLUMNS, query);

export const afterClick = (order: RunOrder, column: SortColumn): RunOrder => afterClickIn(COLUMNS, order, column);

const ranked = ["live", "finished", "fault", "stopped"] as const satisfies ReadonlyArray<PricedRun["status"]>;

/** Live, finished, fault, stopped; a run too old to read is last. */
const statusRank = (run: Run): number => (run.kind === "unreadable" ? ranked.length : ranked.indexOf(run.status));

const startedOf = (run: Run): string | undefined => (run.kind === "readable" ? run.started : undefined);

const seedOf = (run: Run): number | undefined => (run.kind === "readable" && !Number.isNaN(Number(run.seed)) ? Number(run.seed) : undefined);

/** The player that won, or the controller when it was no agent, as the column's winner is called: a model by its name. */
export const winnerOf = (run: Run): string | undefined => {
  if (run.kind === "unreadable") return undefined;

  const winner = run.standings?.[0];
  const model = run.agents.find((agent) => agent.agent === winner?.player)?.model;

  return winner === undefined ? undefined : model === undefined ? (winner.controller ?? winner.player) : modelName(model);
};

/** The dollars a run's calls cost, none when no price covers any of them. */
export const dollarsOf = (run: Run): number | undefined => (run.kind === "readable" && run.cost.calls > run.cost.unpriced ? run.cost.dollars : undefined);

const COMPARATORS: Record<SortColumn, (direction: Direction) => Compare<Run>> = {
  status: byKey(statusRank, numerically),
  started: byKey(startedOf, alphabetically),
  seed: byKey(seedOf, numerically),
  winner: byKey(winnerOf, alphabetically),
  cost: byKey(dollarsOf, numerically),
};

const newestFirst: Compare<Run> = (left, right) => COMPARATORS.started("desc")(left, right) || left.id.localeCompare(right.id);

const liveRank = (run: Run): number => (run.kind === "readable" && run.status === "live" ? 0 : 1);

const liveFirst: Compare<Run> = (left, right) => liveRank(left) - liveRank(right) || newestFirst(left, right);

export const orderRuns = (runs: ReadonlyArray<Run>, order: RunOrder): ReadonlyArray<Run> => {
  const compare: Compare<Run> = order.kind === "default" ? liveFirst : (left, right) => COMPARATORS[order.column](order.direction)(left, right) || newestFirst(left, right);

  return runs.toSorted(compare);
};
