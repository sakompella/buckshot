import { Schema } from "effect";

import { type LeaderboardRow, LeaderboardResponse } from "../api.ts";
import { filterFromQuery, writeFilter } from "../filter.ts";
import { afterClick, type LeaderboardColumn, type LeaderboardOrder, orderFromQuery, rowsShown, writeOrder } from "../leaderboard.ts";
import { count, dollars, effortBadge, fetchText, type Field, h, modelText, nav, picker, sortHeader } from "./dom.ts";

// The leaderboard at "/leaderboard": the tournament's entrants, each a model at
// an effort, rated from its finished matches. Reads the same stats as
// scripts/arena-stats.ts. Like DeepSWE's, it shows each model at its best
// effort or at every effort.

const decodeLeaderboard = Schema.decodeUnknownSync(Schema.fromJsonString(LeaderboardResponse));

const COLUMNS: ReadonlyArray<readonly [string, LeaderboardColumn]> = [
  ["Model", "model"],
  ["Effort", "effort"],
  ["Rating", "rating"],
  ["Win share", "share"],
  ["Matches", "matches"],
  ["Interventions", "interventions"],
  ["Cost at list price", "cost"],
];

const percent = (share: number) => `${(share * 100).toFixed(1)}%`;

/** A value, then the interval around it in a fainter hand. */
const withInterval = (value: string, interval: { readonly low: number; readonly high: number } | undefined, show: (number: number) => string) =>
  h("td", { class: "number" }, value, interval !== undefined && h("span", { class: "faint" }, ` ${show(interval.low)} to ${show(interval.high)}`));

const rowOf = (row: LeaderboardRow): HTMLElement => {
  const turns = row.moves + row.interventions;

  return h(
    "tr",
    {},
    h("td", {}, modelText(row.model)),
    h("td", {}, row.effort === undefined ? "" : effortBadge(row.effort)),
    withInterval(String(Math.round(row.rating)), row.ratingInterval, (rating) => String(Math.round(rating))),
    withInterval(percent(row.share), row.shareInterval, percent),
    h("td", { class: "number" }, count(row.matches)),
    h("td", { class: "number" }, count(row.interventions), turns > 0 && h("span", { class: "faint" }, ` ${percent(row.interventions / turns)}`)),
    h("td", { class: "number" }, row.cost.calls === 0 ? "" : row.cost.unpriced === row.cost.calls ? "no price" : dollars(row.cost.dollars), row.cost.unpriced > 0 && row.cost.unpriced < row.cost.calls && h("span", { class: "faint" }, ` +${row.cost.unpriced} unpriced`)),
  );
};

export const showLeaderboard = async () => {
  const { name, seeds, matches, anchor, rows, notes } = decodeLeaderboard(await fetchText("/api/leaderboard"));
  const query = new URLSearchParams(location.search);
  let filter = { ...filterFromQuery(query), vs: "", vsEffort: "" };
  let order: LeaderboardOrder = orderFromQuery(query);
  let best = query.get("best") === "1";
  const head = h("thead", {});
  const body = h("tbody", {});
  const view = h("div", { class: "view" });

  const sortBy = (column: LeaderboardColumn) => {
    order = afterClick(order, column);
    render();
  };

  const choose = (field: Field, value: string) => {
    filter = { ...filter, [field]: value };
    render();
  };

  const pick = (field: Field) => picker(field, filter, rows, choose);

  const effortButton = (bestOnly: boolean) => {
    const button = h("button", { type: "button", "aria-pressed": String(best === bestOnly) }, bestOnly ? "Best effort per model" : "All effort levels");

    button.addEventListener("click", () => {
      best = bestOnly;
      render();
    });

    return button;
  };

  const render = () => {
    const next = new URLSearchParams();

    writeFilter(next, filter);
    writeOrder(next, order);

    if (best) next.set("best", "1");

    history.replaceState(null, "", next.size === 0 ? location.pathname : `?${next}`);
    head.replaceChildren(h("tr", {}, ...COLUMNS.map(([title, column]) => sortHeader(title, column, order, sortBy))));
    view.replaceChildren(effortButton(false), effortButton(true));
    body.replaceChildren(...rowsShown(rows, { filter, best, order }).map(rowOf));
  };

  render();
  document.body.replaceChildren(
    h(
      "main",
      { class: "list" },
      nav("/leaderboard", true),
      h("h1", {}, `Leaderboard: ${name}`),
      h("p", { class: "dim" }, `${matches.scored} of ${matches.scheduled} matches scored, over ${seeds} seeds. Ratings are on the Elo scale with ${anchor ?? "the mean of all entrants"} at 0; intervals are 95% bootstraps by seed.`),
      h("div", { class: "filters" }, pick("family"), pick("model"), pick("effort"), view),
      h("table", { class: "runs leaderboard" }, head, body),
      ...notes.map((note) => h("p", { class: "faint" }, note)),
    ),
  );
};
