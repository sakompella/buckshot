import type { Html, HtmlBuilder } from "foldkit/html";

import { addTo, type BlockTally, blockRate, colorOfKey, fmtCI, groupBy, keyOf, labelOf, type Rate, type SeatFull, unique } from "./data.ts";
import { type Derived, memoLast } from "./derived.ts";
import type { Message } from "./model.ts";

type H = HtmlBuilder<Message>;

// Seat effects: table position, the round-1 starter, and how rounds add up to a match.
// Filters pick focal players: a match is in if either player passes the filters, and both players' results count.
// Per-config rows list only the focal configs.

/** A completed two-player match, its seats in table order. */
interface Game {
  readonly first: SeatFull;
  readonly second: SeatFull;
}

/** A seed block with both seat orders scored. A block whose two games ran under different code hashes has no cohort. */
interface Block {
  readonly id: string;
  readonly tournament: string;
  readonly cohort: string | null;
  readonly games: readonly [Game, Game];
}

interface GroupRow {
  readonly name: string;
  readonly rate: Rate;
  readonly blocks: number;
}

const pct = (value: number) => (Number.isNaN(value) ? "–" : `${(value * 100).toFixed(1)}%`);

const points = (value: number) => `${value >= 0 ? "+" : ""}${(value * 100).toFixed(1)}`;

const interval = (rate: Rate) => (rate.n > 0 && rate.k > 0 && rate.k < rate.n ? `${pct(rate.lo)}–${pct(rate.hi)}` : fmtCI(rate));

const gamesOf = (seats: ReadonlyArray<SeatFull>): ReadonlyArray<Game> =>
  [...groupBy(
    seats.filter(({ status }) => status === "completed"),
    ({ matchId }) => matchId,
  ).values()].flatMap((both) => {
    const [first, second, ...rest] = both.toSorted((left, right) => left.position - right.position);

    return first !== undefined && second !== undefined && rest.length === 0 ? [{ first, second }] : [];
  });

const blocksOf = (games: ReadonlyArray<Game>) => {
  const blocks: Array<Block> = [];
  let partial = 0;
  let crossCode = 0;

  for (const [id, pair] of groupBy(games, ({ first }) => first.seedBlock)) {
    const [one, two, ...rest] = pair;

    if (one === undefined || two === undefined || rest.length > 0 || keyOf(one.first) !== keyOf(two.second) || keyOf(one.second) !== keyOf(two.first)) {
      partial++;
      continue;
    }

    const isOneCohort = one.first.cohort === two.first.cohort;

    if (!isOneCohort) crossCode++;

    blocks.push({ id, tournament: one.first.tournament, cohort: isOneCohort ? one.first.cohort : null, games: [one, two] });
  }

  return { blocks, partial, crossCode };
};

const groupedRows = (blocks: ReadonlyArray<Block>, value: (game: Game) => number): ReadonlyArray<GroupRow> => {
  const row = (name: string, members: ReadonlyArray<Block>): GroupRow => {
    const tally: BlockTally = new Map();

    for (const block of members) for (const game of block.games) addTo(tally, block.id, value(game), 1);

    return { name, rate: blockRate(tally, 1000), blocks: members.length };
  };

  const tournaments = unique(blocks.map(({ tournament }) => tournament)).toSorted();
  const cohorts = unique(blocks.flatMap(({ cohort }) => (cohort === null ? [] : [cohort]))).toSorted();

  return [
    row("All complete seed blocks", blocks),
    ...tournaments.map((tournament) => row(`Tournament ${tournament}`, blocks.filter((block) => block.tournament === tournament))),
    ...cohorts.map((cohort) => row(`Cohort ${cohort}`, blocks.filter((block) => block.cohort === cohort))),
  ];
};

/** The round-1 starter's win share, or NaN when the story does not name a starter. */
const starterShare = ({ first, second }: Game): number => {
  const starter = first.story?.starter;

  if (starter === first.player) return first.winShare ?? 0;

  return starter === second.player ? (second.winShare ?? 0) : Number.NaN;
};

interface ConfigRow {
  readonly cohort: string;
  readonly key: string;
  readonly difference: BlockTally;
  one: number;
  two: number;
  n: number;
}

const configRows = (blocks: ReadonlyArray<Block>, focal: ReadonlySet<SeatFull>) => {
  const rows = new Map<string, ConfigRow>();

  for (const { id, cohort, games } of blocks) {
    if (cohort === null) continue;

    const [one, two] = games;

    for (const seat of [one.first, one.second]) {
      if (!focal.has(seat)) continue;

      const key = keyOf(seat);
      const asFirst = keyOf(one.first) === key ? one.first : two.first;
      const asSecond = keyOf(one.second) === key ? one.second : two.second;
      const rowId = `${cohort}||${key}`;
      const row = rows.get(rowId) ?? { cohort, key, difference: new Map(), one: 0, two: 0, n: 0 };

      rows.set(rowId, row);
      addTo(row.difference, id, (asFirst.winShare ?? 0) - (asSecond.winShare ?? 0), 1);
      row.one += asFirst.winShare ?? 0;
      row.two += asSecond.winShare ?? 0;
      row.n++;
    }
  }

  return [...rows.values()]
    .map((row) => ({ ...row, rate: blockRate(row.difference, 1000) }))
    .toSorted((left, right) => left.cohort.localeCompare(right.cohort) || right.rate.rate - left.rate.rate);
};

interface StoryRow {
  n: number;
  roundOneWinner: number;
  lostRoundOne: number;
  sweeps: number;
  bad: number;
}

const ALL_SCORED = "All scored matches";

const storyRows = (games: ReadonlyArray<Game>) => {
  const rows = new Map<string, StoryRow>();

  for (const { first, second } of games) {
    const story = first.story;
    const winner = (first.winShare ?? 0) >= 1 ? first.player : (second.winShare ?? 0) >= 1 ? second.player : null;

    for (const group of [ALL_SCORED, first.cohort]) {
      const row = rows.get(group) ?? { n: 0, roundOneWinner: 0, lostRoundOne: 0, sweeps: 0, bad: 0 };

      rows.set(group, row);
      row.n++;

      if (story === null || !story.ok) {
        row.bad++;
        continue;
      }

      if (winner === null) continue;

      if (story.rounds[0]?.winner === winner) row.roundOneWinner++;
      else row.lostRoundOne++;

      if (story.rounds.every((round) => round.winner === winner)) row.sweeps++;
    }
  }

  return [...rows].toSorted(([left], [right]) => (left === ALL_SCORED ? -1 : right === ALL_SCORED ? 1 : left.localeCompare(right)));
};

const seatsOf = memoLast((derived: Derived) => {
  const games = gamesOf(derived.matchSeats);
  const { blocks, partial, crossCode } = blocksOf(games);
  const startered = blocks.filter((block) => block.games.every((game) => !Number.isNaN(starterShare(game))));

  return {
    games,
    partial,
    crossCode,
    position: groupedRows(blocks, ({ first }) => first.winShare ?? 0),
    starter: groupedRows(startered, starterShare),
    firstStarts: games.filter(({ first }) => first.story?.starter === first.player).length,
    configs: configRows(blocks, new Set(derived.filtered)),
    stories: storyRows(games),
  };
});

const groupTableView = (h: H, rows: ReadonlyArray<GroupRow>, [shareLabel, otherLabel]: readonly [string, string]): Html =>
  h.table(
    [h.Class("rows")],
    [
      h.thead([], [h.tr([], ["Group", "Complete blocks", "Matches", shareLabel, "95% CI", otherLabel].map((title) => h.th([], [title])))]),
      h.tbody(
        [],
        rows.map((row) =>
          h.tr(
            [],
            [
              h.td([], [row.name]),
              h.td([h.DataAttribute("label", "blocks")], [String(row.blocks)]),
              h.td([h.DataAttribute("label", "matches")], [String(row.rate.n)]),
              h.td([h.DataAttribute("label", shareLabel)], [h.b([], [pct(row.rate.rate)])]),
              h.td([h.DataAttribute("label", "95% CI")], [interval(row.rate)]),
              h.td([h.DataAttribute("label", otherLabel)], [pct(1 - row.rate.rate)]),
            ],
          ),
        ),
      ),
    ],
  );

export const seatsView = (h: H, filters: Html, derived: Derived): Html => {
  const { games, partial, crossCode, position, starter, firstStarts, configs, stories } = seatsOf(derived);
  const left = partial > 0 ? `; ${partial} incomplete blocks left out` : "";
  const cross = crossCode > 0 ? ` ${crossCode} block spanning two code hashes is in no cohort row.` : "";

  return h.div(
    [],
    [
      h.p([h.Class("sub")], ["Filters pick focal players: a match is in if either player passes; both players count."]),
      filters,
      h.section(
        [],
        [
          h.h2([], ["Table position"]),
          h.p(
            [h.Class("sub")],
            [`Position 1 is a table seat, not the first mover (it starts round 1 in ${firstStarts.toLocaleString()} of ${games.length.toLocaleString()}); averaged within seed blocks${left}.${cross}`],
          ),
          groupTableView(h, position, ["Position 1 share", "Position 2 share"]),
        ],
      ),
      h.section(
        [],
        [
          h.h2([], ["Round-1 starter"]),
          h.p([h.Class("sub")], ["Win share of the player who starts round 1, over complete seed blocks."]),
          groupTableView(h, starter, ["Starter share", "Other player"]),
        ],
      ),
      h.section(
        [],
        [
          h.h2([], ["Table position per config"]),
          h.p([h.Class("sub")], ["Position 1 minus position 2 share within blocks; both configs in a block share the value."]),
          h.table(
            [h.Class("rows")],
            [
              h.thead([], [h.tr([], ["Config", "Blocks", "Position 1 share", "Position 2 share", "Position 1 − 2", "95% CI"].map((title) => h.th([], [title])))]),
              h.tbody(
                [],
                configs.flatMap((row, index) => [
                  index === 0 || configs[index - 1]?.cohort !== row.cohort ? h.tr([h.Class("group")], [h.td([h.Colspan(6)], [row.cohort])]) : h.empty,
                  h.tr(
                    [],
                    [
                      h.td([h.Style({ color: colorOfKey(row.key) })], [labelOf(row.key)]),
                      h.td([h.DataAttribute("label", "blocks")], [String(row.n)]),
                      h.td([h.DataAttribute("label", "position 1")], [pct(row.one / row.n)]),
                      h.td([h.DataAttribute("label", "position 2")], [pct(row.two / row.n)]),
                      h.td([h.DataAttribute("label", "1 − 2")], [h.b([], [points(row.rate.rate)])]),
                      h.td([h.DataAttribute("label", "95% CI")], [`${points(row.rate.lo)} to ${points(row.rate.hi)}`]),
                    ],
                  ),
                ]),
              ),
            ],
          ),
        ],
      ),
      h.section(
        [],
        [
          h.h2([], ["Round story"]),
          h.p([h.Class("sub")], ["The final round is inferred from final cash; a sweep is a winner that won every round."]),
          h.table(
            [h.Class("rows")],
            [
              h.thead(
                [],
                [h.tr([], ["Group", "Scored matches", "Round-1 winner won the match", "Winner lost round 1", "Sweeps", "Prizes check failed"].map((title) => h.th([], [title])))],
              ),
              h.tbody(
                [],
                stories.map(([group, row]) =>
                  h.tr(
                    [],
                    [
                      h.td([], [group]),
                      h.td([h.DataAttribute("label", "scored")], [String(row.n)]),
                      h.td([h.DataAttribute("label", "round-1 winner won")], [`${row.roundOneWinner} `, h.span([h.Class("pm")], [pct(row.roundOneWinner / (row.roundOneWinner + row.lostRoundOne))])]),
                      h.td([h.DataAttribute("label", "winner lost round 1")], [String(row.lostRoundOne)]),
                      h.td([h.DataAttribute("label", "sweeps")], [String(row.sweeps)]),
                      h.td([h.DataAttribute("label", "prizes check failed")], [String(row.bad)]),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    ],
  );
};
