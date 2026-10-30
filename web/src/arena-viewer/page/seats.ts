import type { Html, HtmlBuilder } from "foldkit/html";

import { anchorId, chartWidth, figureView, linScale, REFERENCE, REFERENCE_DASH, tippedDot } from "./charts.ts";
import { addTo, type BlockTally, blockRate, colorOfKey, fmtCI, groupBy, keyOf, labelOf, type Rate, type SeatFull } from "./data.ts";
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

/** A seed block with both seat orders scored. */
interface Block {
  readonly id: string;
  readonly games: readonly [Game, Game];
}

interface GroupRow {
  readonly rate: Rate;
  /** The same share with an interval that draws seeds, which every pairing shares and which fix the starter. */
  readonly bySeed: Rate;
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

  for (const [id, pair] of groupBy(games, ({ first }) => first.seedBlock)) {
    const [one, two, ...rest] = pair;

    if (one === undefined || two === undefined || rest.length > 0 || keyOf(one.first) !== keyOf(two.second) || keyOf(one.second) !== keyOf(two.first)) {
      partial++;
      continue;
    }

    blocks.push({ id, games: [one, two] });
  }

  return { blocks, partial };
};

const blockOf = (block: Block) => block.id;

const seedOf = (block: Block) => String(block.games[0].first.seed);

/** The mean of `value` over the blocks' games, with a bootstrap that draws whole `unitOf` groups of blocks. */
const shareOver = (blocks: ReadonlyArray<Block>, value: (game: Game) => number, unitOf: (block: Block) => string): Rate => {
  const tally: BlockTally = new Map();

  for (const block of blocks) for (const game of block.games) addTo(tally, unitOf(block), value(game), 1);

  return blockRate(tally, 1000);
};

const groupedRow = (blocks: ReadonlyArray<Block>, value: (game: Game) => number): GroupRow => ({
  rate: shareOver(blocks, value, blockOf),
  bySeed: shareOver(blocks, value, seedOf),
  blocks: blocks.length,
});

/** The round-1 starter's win share, or NaN when the story does not name a starter. */
const starterShare = ({ first, second }: Game): number => {
  const starter = first.story?.starter;

  if (starter === first.player) return first.winShare ?? 0;

  return starter === second.player ? (second.winShare ?? 0) : Number.NaN;
};

interface ConfigRow {
  readonly key: string;
  readonly difference: BlockTally;
  one: number;
  two: number;
  n: number;
}

const configRows = (blocks: ReadonlyArray<Block>, focal: ReadonlySet<SeatFull>) => {
  const rows = new Map<string, ConfigRow>();

  for (const { id, games } of blocks) {
    const [one, two] = games;

    for (const seat of [one.first, one.second]) {
      if (!focal.has(seat)) continue;

      const key = keyOf(seat);
      const asFirst = keyOf(one.first) === key ? one.first : two.first;
      const asSecond = keyOf(one.second) === key ? one.second : two.second;
      const row = rows.get(key) ?? { key, difference: new Map(), one: 0, two: 0, n: 0 };

      rows.set(key, row);
      addTo(row.difference, id, (asFirst.winShare ?? 0) - (asSecond.winShare ?? 0), 1);
      row.one += asFirst.winShare ?? 0;
      row.two += asSecond.winShare ?? 0;
      row.n++;
    }
  }

  return [...rows.values()]
    .map((row) => ({ ...row, rate: blockRate(row.difference, 1000) }))
    .toSorted((left, right) => right.rate.rate - left.rate.rate);
};

interface StoryRow {
  n: number;
  roundOneWinner: number;
  lostRoundOne: number;
  sweeps: number;
  bad: number;
}

const storyRow = (games: ReadonlyArray<Game>): StoryRow => {
  const row: StoryRow = { n: 0, roundOneWinner: 0, lostRoundOne: 0, sweeps: 0, bad: 0 };

  for (const { first, second } of games) {
    const story = first.story;
    const winner = (first.winShare ?? 0) >= 1 ? first.player : (second.winShare ?? 0) >= 1 ? second.player : null;

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

  return row;
};

/** Seeds with fewer complete blocks than this are left out of the per-seed chart. */
const MIN_SEED_BLOCKS = 5;

const perSeedRows = (blocks: ReadonlyArray<Block>) => {
  const bySeed = groupBy(blocks, seedOf);
  const kept = [...bySeed].filter(([, members]) => members.length >= MIN_SEED_BLOCKS);

  return {
    rows: kept.map(([seed, members]) => ({ seed, blocks: members.length, rate: shareOver(members, starterShare, blockOf) })).toSorted((left, right) => right.rate.rate - left.rate.rate),
    leftOut: bySeed.size - kept.length,
  };
};

const GAPS = ["never behind", "1 behind", "2 behind", "3+ behind"] as const;

/** Each player's win share by its worst health gap in the final round, over decided matches. */
const comebackRows = (games: ReadonlyArray<Game>) => {
  const tallies = GAPS.map((): BlockTally => new Map());

  for (const { first, second } of games) {
    if ((first.winShare ?? 0) < 1 && (second.winShare ?? 0) < 1) continue;

    for (const seat of [first, second]) {
      const gap = seat.low === null ? 0 : seat.low[1] - seat.low[0];
      const tally = tallies[Math.min(Math.max(gap, 0), GAPS.length - 1)];

      if (tally !== undefined) addTo(tally, seat.seedBlock, (seat.winShare ?? 0) >= 1 ? 1 : 0, 1);
    }
  }

  return GAPS.map((label, index) => ({ label, rate: blockRate(tallies[index] ?? new Map(), 1000) }));
};

const seatsOf = memoLast((derived: Derived) => {
  const games = gamesOf(derived.matchSeats);
  const { blocks, partial } = blocksOf(games);
  const startered = blocks.filter((block) => block.games.every((game) => !Number.isNaN(starterShare(game))));

  return {
    games,
    partial,
    position: groupedRow(blocks, ({ first }) => first.winShare ?? 0),
    starter: groupedRow(startered, starterShare),
    firstStarts: games.filter(({ first }) => first.story?.starter === first.player).length,
    configs: configRows(blocks, new Set(derived.filtered)),
    story: storyRow(games),
    perSeed: perSeedRows(startered),
    comebacks: comebackRows(games),
  };
});

const groupTableView = (h: H, row: GroupRow, [shareLabel, otherLabel]: readonly [string, string]): Html =>
  h.table(
    [h.Class("rows")],
    [
      h.thead([], [h.tr([], ["Complete blocks", "Seeds", "Matches", shareLabel, "95% CI, seeds drawn", "95% CI, blocks drawn", otherLabel].map((title) => h.th([], [title])))]),
      h.tbody(
        [],
        [
          h.tr(
            [],
            [
              h.td([h.DataAttribute("label", "blocks")], [String(row.blocks)]),
              h.td([h.DataAttribute("label", "seeds")], [String(row.bySeed.blocks)]),
              h.td([h.DataAttribute("label", "matches")], [String(row.rate.n)]),
              h.td([h.DataAttribute("label", shareLabel)], [h.b([], [pct(row.rate.rate)])]),
              h.td([h.DataAttribute("label", "95% CI, seeds drawn")], [interval(row.bySeed)]),
              h.td([h.DataAttribute("label", "95% CI, blocks drawn")], [interval(row.rate)]),
              h.td([h.DataAttribute("label", otherLabel)], [pct(1 - row.rate.rate)]),
            ],
          ),
        ],
      ),
    ],
  );

const S = (value: number) => value.toFixed(1);

const bigNumberView = (h: H, value: string, label: string, note: string): Html =>
  h.div([h.Class("bignum")], [h.b([], [value]), h.span([h.Class("lbl")], [label]), h.span([h.Class("pm")], [note])]);

/** A ribbon from one vertical span on the left to another on the right. */
const ribbon = (x0: number, top0: number, bottom0: number, x1: number, top1: number, bottom1: number): string => {
  const middle = (x0 + x1) / 2;

  return `M${S(x0)},${S(top0)} C${S(middle)},${S(top0)} ${S(middle)},${S(top1)} ${S(x1)},${S(top1)} L${S(x1)},${S(bottom1)} C${S(middle)},${S(bottom1)} ${S(middle)},${S(bottom0)} ${S(x0)},${S(bottom0)} Z`;
};

const WON = "#d9d9d9";

const LOST = "#6b6b6b";

/** Where the round-1 winner's matches end up: won, with the sweeps marked, or lost. */
const flowView = (h: H, story: StoryRow | undefined, width: number): Html => {
  const won = story?.roundOneWinner ?? 0;
  const lost = story?.lostRoundOne ?? 0;
  const sweeps = story?.sweeps ?? 0;
  const decided = won + lost;

  if (decided === 0) return h.div([h.Class("empty")], ["No decided matches for this filter."]);

  const [height, top, gap, bar] = [230, 30, 16, 14];
  const unit = (height - top - 8 - gap) / decided;
  const [left, right] = [4, width - Math.min(190, width * 0.42)];
  const wonBottom = top + won * unit;
  const lostTop = wonBottom + gap;
  const lostBottom = lostTop + lost * unit;

  const label = (y: number, share: string, name: string, notes: ReadonlyArray<string>) =>
    h.g(
      [],
      [
        h.text([h.X(S(right + bar + 10)), h.Y(S(y - 6)), h.Class("big")], [share]),
        h.text([h.X(S(right + bar + 10)), h.Y(S(y + 11)), h.Class("lbl")], [name]),
        ...notes.map((note, index) => h.text([h.X(S(right + bar + 10)), h.Y(S(y + 25 + 13 * index)), h.Class("small")], [note])),
      ],
    );

  return h.svg(
    [h.Width(String(width)), h.Height(String(height))],
    [
      h.text([h.X(String(left)), h.Y(String(top - 12)), h.Class("lbl")], [`Round-1 winner · ${decided.toLocaleString()} decided matches`]),
      h.path([h.D(ribbon(left + bar, top, wonBottom, right, top, wonBottom)), h.Fill(WON), h.Opacity("0.22")], []),
      h.path([h.D(ribbon(left + bar, wonBottom, top + decided * unit, right, lostTop, lostBottom)), h.Fill(LOST), h.Opacity("0.3")], []),
      h.rect([h.X(String(left)), h.Y(String(top)), h.Width(String(bar)), h.Height(S(decided * unit)), h.Fill("#9a9a9a")], []),
      h.rect([h.X(S(right)), h.Y(String(top)), h.Width(String(bar)), h.Height(S(won * unit)), h.Fill(WON)], []),
      h.rect([h.X(S(right)), h.Y(String(top)), h.Width(String(bar)), h.Height(S(sweeps * unit)), h.Fill("#fff")], []),
      h.line([h.X1(S(right - 4)), h.X2(S(right + bar + 4)), h.Y1(S(top + sweeps * unit)), h.Y2(S(top + sweeps * unit)), h.Stroke("#000"), h.StrokeWidth("2")], []),
      h.rect([h.X(S(right)), h.Y(S(lostTop)), h.Width(String(bar)), h.Height(S(lost * unit)), h.Fill(LOST)], []),
      label((top + wonBottom) / 2, pct(won / decided), "won the match", [`${won.toLocaleString()} matches`, `${sweeps.toLocaleString()} won every round`]),
      label(Math.min((lostTop + lostBottom) / 2, height - 30), pct(lost / decided), "lost the match", [`${lost.toLocaleString()} matches`]),
    ],
  );
};

/** Win share with its interval, one bar per worst health gap in the final round. */
const comebackView = (h: H, rows: ReadonlyArray<{ readonly label: string; readonly rate: Rate }>, width: number): Html => {
  const [height, left, right, top, bottom] = [230, 38, 6, 24, 44];
  const y = linScale(0, 1, height - bottom, top, [0, 0.25, 0.5, 0.75, 1]);
  const band = (width - left - right) / rows.length;
  const bar = Math.min(54, band * 0.56);

  return h.svg(
    [h.Width(String(width)), h.Height(String(height))],
    [
      ...y.ticks.map((tick) =>
        h.g(
          [],
          [
            h.line([...(tick === 0.5 ? [h.Stroke(REFERENCE), h.StrokeDasharray(REFERENCE_DASH)] : [h.Class("grid")]), h.X1(String(left)), h.X2(String(width - right)), h.Y1(S(y.at(tick))), h.Y2(S(y.at(tick)))], []),
            h.text([h.X(String(left - 6)), h.Y(S(y.at(tick) + 4)), h.TextAnchor("end")], [`${tick * 100}%`]),
          ],
        ),
      ),
      ...rows.flatMap(({ label, rate }, index) => {
        const middle = left + band * (index + 0.5);
        const hasData = rate.n > 0;

        return [
          hasData ? h.rect([h.X(S(middle - bar / 2)), h.Y(S(y.at(rate.rate))), h.Width(S(bar)), h.Height(S(y.at(0) - y.at(rate.rate))), h.Fill(WON), h.Opacity(rate.n < 50 ? "0.45" : "0.85")], []) : h.empty,
          hasData ? h.line([h.X1(S(middle)), h.X2(S(middle)), h.Y1(S(y.at(rate.lo))), h.Y2(S(y.at(rate.hi))), h.Stroke("#fff"), h.StrokeWidth("1.5")], []) : h.empty,
          h.text([h.X(S(middle)), h.Y(S(y.at(hasData ? rate.hi : 0) - 6)), h.TextAnchor("middle"), h.Class("val")], [hasData ? pct(rate.rate) : "–"]),
          h.text([h.X(S(middle)), h.Y(String(height - bottom + 17)), h.TextAnchor("middle"), h.Class("lbl")], [label]),
          h.text([h.X(S(middle)), h.Y(String(height - bottom + 32)), h.TextAnchor("middle"), h.Class("small")], [`of ${rate.n.toLocaleString()}`]),
        ];
      }),
    ],
  );
};

/** The round-1 starter's win share on each seed, best first, against the share over every seed. */
const perSeedView = (h: H, rows: ReadonlyArray<{ readonly seed: string; readonly blocks: number; readonly rate: Rate }>, overall: Rate | undefined, width: number): Html => {
  if (rows.length === 0) return h.div([h.Class("empty")], ["No seed has enough complete blocks for this filter."]);

  const [rowHeight, top, bottom, left, right] = [19, 30, 6, 42, 46];
  const height = top + rows.length * rowHeight + bottom;
  const x = linScale(0, 1, left, width - right, [0, 0.25, 0.5, 0.75, 1]);
  const rowY = (index: number) => top + (index + 0.5) * rowHeight;

  return h.svg(
    [h.Width(String(width)), h.Height(String(height))],
    [
      ...x.ticks.map((tick) =>
        h.g(
          [],
          [
            h.line([...(tick === 0.5 ? [h.Stroke(REFERENCE), h.StrokeDasharray(REFERENCE_DASH)] : [h.Class("grid")]), h.X1(S(x.at(tick))), h.X2(S(x.at(tick))), h.Y1(String(top - 4)), h.Y2(String(height - bottom))], []),
            h.text([h.X(S(x.at(tick))), h.Y(String(top - 10)), h.TextAnchor("middle")], [`${tick * 100}%`]),
          ],
        ),
      ),
      overall === undefined || overall.n === 0
        ? h.empty
        : h.line([h.X1(S(x.at(overall.rate))), h.X2(S(x.at(overall.rate))), h.Y1(String(top - 4)), h.Y2(String(height - bottom)), h.Stroke(REFERENCE), h.StrokeDasharray(REFERENCE_DASH)], []),
      ...rows.flatMap(({ seed, blocks, rate }, index) => [
        h.text([h.X(String(left - 8)), h.Y(S(rowY(index) + 4)), h.TextAnchor("end")], [seed]),
        h.line([h.X1(S(x.at(rate.lo))), h.X2(S(x.at(rate.hi))), h.Y1(S(rowY(index))), h.Y2(S(rowY(index))), h.Stroke("#8b8b8b"), h.StrokeWidth("1.5")], []),
        tippedDot(h, anchorId("seed", seed), `seed ${seed}: the starter won ${pct(rate.rate)} over ${blocks} complete blocks, 95% CI ${interval(rate)}`, S(x.at(rate.rate)), S(rowY(index)), [h.R("4.5"), h.Fill(WON), h.Stroke("#000")]),
        h.text([h.X(String(width - right + 8)), h.Y(S(rowY(index) + 4)), h.Class("val")], [pct(rate.rate)]),
      ]),
    ],
  );
};

/** The Seats tab, laid out for a viewport `width` wide with `content` pixels inside main's padding. */
export const seatsView = (h: H, derived: Derived, width: number, content: number): Html => {
  const { position: allPositions, starter: allStarters, story, perSeed, comebacks } = seatsOf(derived);
  const figure = chartWidth(width, content);
  const decided = story.roundOneWinner + story.lostRoundOne;

  const blocksNote = (row: GroupRow) => `${row.blocks.toLocaleString()} complete blocks at ${row.bySeed.blocks} seeds · 95% CI by seeds ${interval(row.bySeed)}`;

  const leftOut = perSeed.leftOut > 0 ? ` ${perSeed.leftOut} seeds under ${MIN_SEED_BLOCKS} blocks left out.` : "";

  return h.div(
    [],
    [
      h.h2([], ["Seat balance"]),
      h.div(
        [],
        [
          h.div(
            [h.Class("bignums")],
            [
              bigNumberView(h, pct(allStarters.rate.rate), "win share of the round-1 starter", blocksNote(allStarters)),
              bigNumberView(h, pct(allPositions.rate.rate), "win share at table position 1", blocksNote(allPositions)),
              bigNumberView(h, pct(decided === 0 ? Number.NaN : story.roundOneWinner / decided), "of matches won by the round-1 winner", `${story.roundOneWinner.toLocaleString()} of ${decided.toLocaleString()} decided matches`),
            ],
          ),
          h.div(
            [h.Class("chartrow")],
            [
              figureView(h, "Round 1 to the match", "Bright cap: sweeps.", flowView(h, story, figure)),
              figureView(h, "Comebacks", "By the worst health gap in the final round.", comebackView(h, comebacks, figure)),
              figureView(h, "The starter's edge per seed", `Dotted line: every seed.${leftOut}`, perSeedView(h, perSeed.rows, allStarters.rate, figure)),
            ],
          ),
        ],
      ),
    ],
  );
};

export const seatTablesView = (h: H, derived: Derived): Html => {
  const { games, partial, position: allPositions, starter: allStarters, firstStarts, configs, story } = seatsOf(derived);
  const left = partial > 0 ? `; ${partial} incomplete blocks left out` : "";

  return h.details(
    [h.Class("tables")],
    [
      h.summary([], ["Seats as tables"]),
      h.section(
        [],
        [
          h.h2([], ["Table position"]),
          h.p(
            [h.Class("sub")],
            [`Position 1 is a table seat, not the first mover (it starts round 1 in ${firstStarts.toLocaleString()} of ${games.length.toLocaleString()}); averaged within seed blocks${left}.`],
          ),
          groupTableView(h, allPositions, ["Position 1 share", "Position 2 share"]),
        ],
      ),
      h.section(
        [],
        [
          h.h2([], ["Round-1 starter"]),
          h.p([h.Class("sub")], ["Win share of the player who starts round 1, over complete seed blocks."]),
          groupTableView(h, allStarters, ["Starter share", "Other player"]),
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
                configs.map((row) =>
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
                ),
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
                [h.tr([], ["Scored matches", "Round-1 winner won the match", "Winner lost round 1", "Sweeps", "Prizes check failed"].map((title) => h.th([], [title])))],
              ),
              h.tbody(
                [],
                [
                  h.tr(
                    [],
                    [
                      h.td([h.DataAttribute("label", "scored")], [String(story.n)]),
                      h.td([h.DataAttribute("label", "round-1 winner won")], [`${story.roundOneWinner} `, h.span([h.Class("pm")], [pct(story.roundOneWinner / (story.roundOneWinner + story.lostRoundOne))])]),
                      h.td([h.DataAttribute("label", "winner lost round 1")], [String(story.lostRoundOne)]),
                      h.td([h.DataAttribute("label", "sweeps")], [String(story.sweeps)]),
                      h.td([h.DataAttribute("label", "prizes check failed")], [String(story.bad)]),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    ],
  );
};
