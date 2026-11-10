import { Option } from "effect";
import type { Html, HtmlBuilder } from "foldkit/html";

import { pressable } from "./charts.ts";
import { colorOf, fmtTime, fmtUsd, keyOf, labelOf, type MatchRow, resultOf, type SeatFull, sumOf, winnerOf } from "./data.ts";
import { memoLast } from "./derived.ts";
import { Message, type Model, type MatchPreset } from "./model.ts";
import type { Rating } from "./ratings.ts";

type H = HtmlBuilder<Message>;

// Every started match, newest first; a row opens its replay.

export const INITIAL_ROWS = 25;

export const MORE_ROWS = 200;

const MIN_COMEBACK = 3;

const MIN_UPSET = 100;

const PRESETS: ReadonlyArray<{ readonly preset: MatchPreset; readonly label: string }> = [
  { preset: "comebacks", label: "Comebacks" },
  { preset: "upsets", label: "Upsets" },
];

interface Listed {
  readonly match: MatchRow;
  readonly note: string;
}

interface Decided {
  readonly match: MatchRow;
  readonly winner: SeatFull;
  readonly loser: SeatFull;
}

const decidedOf = (match: MatchRow): ReadonlyArray<Decided> => {
  const winner = winnerOf(match);
  const loser = match.seats.find((seat) => seat !== winner);

  return match.status === "completed" && winner !== undefined && loser !== undefined ? [{ match, winner, loser }] : [];
};

const newestFirst = (left: MatchRow, right: MatchRow) => right.startedAt.localeCompare(left.startedAt);

const comebackOf = (winner: SeatFull): { readonly behind: number; readonly round: number } => {
  const won = winner.story?.ok === true ? winner.story.rounds.flatMap((round, index) => (round.winner === winner.player ? [{ round: index + 1, behind: winner.deficits[index] ?? 0 }] : [])) : [];

  return won.reduce((worst, next) => (next.behind > worst.behind ? next : worst), { behind: 0, round: 0 });
};

const presetRows = (matches: ReadonlyArray<MatchRow>, ratings: ReadonlyMap<string, Rating>, preset: MatchPreset): ReadonlyArray<Listed> => {
  const ratingOf = (seat: SeatFull) => ratings.get(keyOf(seat))?.rating ?? 0;

  const measured = matches.flatMap(decidedOf).map(({ match, winner, loser }) => {
    const { behind, round } = comebackOf(winner);
    const underRated = ratingOf(loser) - ratingOf(winner);

    return preset === "comebacks"
      ? { match, size: behind, min: MIN_COMEBACK, note: `from ${behind} health behind in round ${round}` }
      : { match, size: underRated, min: MIN_UPSET, note: `rated ${Math.round(underRated)} lower` };
  });

  return measured
    .filter(({ size, min }) => size >= min)
    .toSorted((left, right) => right.size - left.size || newestFirst(left.match, right.match))
    .map(({ match, note }) => ({ match, note }));
};

export const rowsOf = memoLast((matches: ReadonlyArray<MatchRow>, ratings: ReadonlyMap<string, Rating>, query: string, maybePreset: Option.Option<MatchPreset>): ReadonlyArray<Listed> => {
  const words = query.toLowerCase().split(/\s+/).filter((word) => word !== "");
  const haystack = (match: MatchRow) => [...match.seats.map((seat) => labelOf(keyOf(seat)).toLowerCase()), String(match.seed)];
  const isMatch = (match: MatchRow) => words.every((word) => haystack(match).some((text) => text.includes(word)));
  const searched = matches.filter(isMatch);

  return Option.match(maybePreset, {
    onNone: () => searched.toSorted(newestFirst).map((match) => ({ match, note: "" })),
    onSome: (preset) => presetRows(searched, ratings, preset),
  });
});

const rowView = (h: H, { match, note }: Listed): Html =>
  h.keyed("tr")(
    match.matchId,
    [h.Class("row"), ...pressable(h, Message.ClickedMatch({ id: match.matchId, maybeFocus: Option.none() }))],
    [
      h.td([h.Class("when")], [fmtTime(match.startedAt)]),
      h.td([h.DataAttribute("label", "seed")], [String(match.seed)]),
      ...[match.seats[0], match.seats[1]].map((seat) =>
        seat === undefined ? h.td([h.Class("seat")], ["–"]) : h.td([h.Class("seat"), h.Style({ color: colorOf(seat.model) })], [`${seat.player} · ${labelOf(keyOf(seat))}`]),
      ),
      h.td([h.Class("res"), h.Style({ color: match.status === "completed" ? colorOf(winnerOf(match)?.model ?? "") : "" })], [resultOf(match), ...(note === "" ? [] : [" ", h.span([h.Class("pm")], [note])])]),
      h.td([h.DataAttribute("label", "moves")], [String(sumOf(match.seats.map(({ moves }) => moves ?? 0)))]),
      h.td([h.DataAttribute("label", "cost")], [fmtUsd(sumOf(match.seats.map(({ cost }) => cost ?? 0)))]),
    ],
  );

export const matchesView = (h: H, matches: ReadonlyArray<MatchRow>, ratings: ReadonlyMap<string, Rating>, list: Model["matchList"]): Html => {
  const rows = rowsOf(matches, ratings, list.query, list.maybePreset);

  return h.div(
    [],
    [
      h.h2([], ["Matches"]),
      h.div(
        [h.Class("bar")],
        [
          h.input([h.Placeholder("filter by model or seed"), h.Value(list.query), h.OnInput((query) => Message.ChangedMatchQuery({ query }))]),
          h.span(
            [h.Class("chips")],
            PRESETS.map(({ preset, label }) => {
              const isOn = Option.exists(list.maybePreset, (chosen) => chosen === preset);

              return h.button([h.Type("button"), h.Class(`chip ${isOn ? "on" : ""}`), h.AriaPressed(String(isOn)), h.OnClick(Message.ClickedMatchPreset({ preset }))], [label]);
            }),
          ),
          h.span([h.Class("k")], [`${rows.length.toLocaleString()} matches`]),
        ],
      ),
      h.table(
        [h.Class("rows matchrows")],
        [
          h.thead([], [h.tr([], ["Started (PT)", "Seed", "Position 1", "Position 2", "Result", "Moves", "Cost"].map((title) => h.th([], [title])))]),
          h.tbody([], rows.slice(0, list.limit).map((row) => rowView(h, row))),
        ],
      ),
      rows.length > list.limit ? h.button([h.Type("button"), h.Class("more"), h.OnClick(Message.ClickedShowMore())], ["Show more"]) : h.empty,
    ],
  );
};
