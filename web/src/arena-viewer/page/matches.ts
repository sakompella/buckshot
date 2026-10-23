import { Option } from "effect";
import type { Html, HtmlBuilder } from "foldkit/html";

import { colorOf, fmtPct, fmtTime, fmtUsd, keyOf, labelOf, type MatchRow, sumOf, winnerOf } from "./data.ts";
import { memoLast } from "./derived.ts";
import { Message, type Model } from "./model.ts";

type H = HtmlBuilder<Message>;

// Every started match, newest first; a row opens its replay.

export const MORE_ROWS = 500;

const rowsOf = memoLast((matches: ReadonlyArray<MatchRow>, query: string): ReadonlyArray<MatchRow> => {
  const needle = query.trim().toLowerCase();

  return matches
    .filter((match) => needle === "" || match.seats.some((seat) => labelOf(keyOf(seat)).toLowerCase().includes(needle)) || String(match.seed).includes(needle) || match.tournament.includes(needle))
    .toSorted((left, right) => right.startedAt.localeCompare(left.startedAt));
});

const resultOf = (match: MatchRow): string => {
  const winner = winnerOf(match);

  if (match.status !== "completed") return "unscored";

  return winner === undefined ? `split ${fmtPct(match.seats[0]?.winShare ?? 0)}` : `${winner.player} wins`;
};

const rowView = (h: H, match: MatchRow): Html =>
  h.keyed("tr")(
    match.matchId,
    [h.Class("row"), h.OnClick(Message.ClickedMatch({ id: match.matchId, maybeFocus: Option.none() }))],
    [
      h.td([h.Class("when")], [fmtTime(match.startedAt)]),
      h.td([h.Class("tour"), h.DataAttribute("label", "tournament")], [match.tournament]),
      h.td([h.DataAttribute("label", "seed")], [String(match.seed)]),
      ...[match.seats[0], match.seats[1]].map((seat) =>
        seat === undefined ? h.td([h.Class("seat")], ["–"]) : h.td([h.Class("seat"), h.Style({ color: colorOf(seat.model) })], [`${seat.player} · ${labelOf(keyOf(seat))}`]),
      ),
      h.td([h.Class("res")], [resultOf(match)]),
      h.td([h.DataAttribute("label", "moves")], [String(sumOf(match.seats.map(({ moves }) => moves ?? 0)))]),
      h.td([h.DataAttribute("label", "cost")], [fmtUsd(sumOf(match.seats.map(({ cost }) => cost ?? 0)))]),
    ],
  );

export const matchesView = (h: H, filters: Html, matches: ReadonlyArray<MatchRow>, list: Model["matchList"]): Html => {
  const rows = rowsOf(matches, list.query);

  return h.section(
    [],
    [
      h.h2([], ["Matches"]),
      h.p([h.Class("sub")], ["Every started match; times are Pacific."]),
      filters,
      h.div(
        [h.Class("bar")],
        [
          h.input([h.Placeholder("filter by model, seed or tournament"), h.Value(list.query), h.OnInput((query) => Message.ChangedMatchQuery({ query }))]),
          h.span([h.Class("k")], [`${rows.length.toLocaleString()} matches`]),
        ],
      ),
      h.table(
        [h.Class("rows matchrows")],
        [
          h.thead([], [h.tr([], ["Started", "Tournament", "Seed", "Seat 1", "Seat 2", "Result", "Moves", "Cost"].map((title) => h.th(title === "Tournament" ? [h.Class("tour")] : [], [title])))]),
          h.tbody([], rows.slice(0, list.limit).map((match) => rowView(h, match))),
        ],
      ),
      rows.length > list.limit ? h.button([h.Type("button"), h.Class("more"), h.OnClick(Message.ClickedShowMore())], ["Show more"]) : h.empty,
    ],
  );
};
