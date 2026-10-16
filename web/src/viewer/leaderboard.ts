import { effortRank, modelName } from "../arena/model-names.ts";
import type { LeaderboardRow } from "./api.ts";
import { type Filter, rowMatches } from "./filter.ts";
import { afterClick as afterClickIn, alphabetically, byKey, type Columns, type Compare, type Direction, numerically, type Order, orderFromQuery as orderFromQueryIn } from "./sorting.ts";

export { writeOrder } from "./sorting.ts";

// The leaderboard's rows as the page shows them: filtered, narrowed to each
// model's best effort when asked, and sorted. Rows without a value for the
// sorted column (a bot has no effort) go last.

export type LeaderboardColumn = "model" | "effort" | "rating" | "share" | "matches" | "interventions" | "cost";

export type LeaderboardOrder = Order<LeaderboardColumn>;

const COLUMNS: Columns<LeaderboardColumn> = { model: "asc", effort: "asc", rating: "desc", share: "desc", matches: "desc", interventions: "desc", cost: "desc" };

export const orderFromQuery = (query: URLSearchParams): LeaderboardOrder => orderFromQueryIn(COLUMNS, query);

export const afterClick = (order: LeaderboardOrder, column: LeaderboardColumn): LeaderboardOrder => afterClickIn(COLUMNS, order, column);

/** The dollars the entrant's calls cost; none when no price covers any of them. */
export const dollarsOf = ({ cost }: LeaderboardRow): number | undefined => (cost.calls > 0 && cost.unpriced === cost.calls ? undefined : cost.dollars);

const COMPARATORS: Record<LeaderboardColumn, (direction: Direction) => Compare<LeaderboardRow>> = {
  model: byKey(({ model }) => modelName(model), alphabetically),
  effort: byKey(({ effort }) => (effort === undefined ? undefined : effortRank(effort)), numerically),
  rating: byKey(({ rating }) => rating, numerically),
  share: byKey(({ share }) => share, numerically),
  matches: byKey(({ matches }) => matches, numerically),
  interventions: byKey(({ interventions }) => interventions, numerically),
  cost: byKey(dollarsOf, numerically),
};

const bestFirst: Compare<LeaderboardRow> = (left, right) => COMPARATORS.rating("desc")(left, right) || left.entrant.localeCompare(right.entrant);

/** Each model at its best-rated effort, as DeepSWE's leaderboard shows by default; a bot is its own model. */
export const bestPerModel = (rows: ReadonlyArray<LeaderboardRow>): ReadonlyArray<LeaderboardRow> => rows.filter((row) => rows.every((other) => other.model !== row.model || bestFirst(row, other) <= 0));

export const rowsShown = (rows: ReadonlyArray<LeaderboardRow>, { filter, best, order }: { readonly filter: Filter; readonly best: boolean; readonly order: LeaderboardOrder }): ReadonlyArray<LeaderboardRow> => {
  const narrowed = rows.filter((row) => rowMatches(filter, row));
  const kept = best ? bestPerModel(narrowed) : narrowed;
  const compare: Compare<LeaderboardRow> = order.kind === "default" ? bestFirst : (left, right) => COMPARATORS[order.column](order.direction)(left, right) || bestFirst(left, right);

  return kept.toSorted(compare);
};
