import { Array as Arr, Option, Result } from "effect";

import { type Seat, SEATS_BY_TABLE } from "../domain.ts";
import { begin, type Controller, play, playAis, type Progress, randomMatchId } from "../driver.ts";
import { seedRng } from "../rng.ts";
import { rosterOf } from "../players.ts";
import { describeError } from "../text.ts";
import type { Applied, MatchSession, MatchSetup } from "./tools.ts";
import { acknowledgedTo, NOTHING_ACKNOWLEDGED, type SeatMove } from "./view.ts";

// Matches with no page: the MCP server holds one HeadlessTable, and runTool
// changes it. The AI seats move as soon as it is their turn, so every reply
// already shows the next Agent turn or the end of the match.

export interface HeadlessMatch extends Progress {
  /** By seat, as in the page's Session. */
  readonly controllers: ReadonlyArray<Controller>;
  /** By seat: the events each Agent seat has acknowledged, as in AgentSource. */
  readonly acknowledged: ReadonlyArray<number>;
}

export interface HeadlessTable {
  readonly maybeMatch: Option.Option<HeadlessMatch>;
}

export const emptyTable: HeadlessTable = { maybeMatch: Option.none() };

const randomSeed = (): number => Math.floor(Math.random() * 2 ** 31);

const failed = (table: HeadlessTable, reason: string): Applied<HeadlessTable> => ({ state: table, maybeError: Option.some(reason) });

const withMatch = (table: HeadlessTable, match: HeadlessMatch): Applied<HeadlessTable> => ({ state: { ...table, maybeMatch: Option.some(match) }, maybeError: Option.none() });

/** Seats the table's controllers by seat; the seats not at the table are never asked. */
const bySeat = ({ table, controllers }: MatchSetup): ReadonlyArray<Controller> =>
  Arr.makeBy(4, (seat) => Option.getOrElse(Arr.findFirstIndex(SEATS_BY_TABLE[table], (tableSeat) => tableSeat === seat).pipe(Option.flatMap((position) => Arr.get(controllers, position))), (): Controller => "Human"));

const start = (table: HeadlessTable, setup: MatchSetup): Applied<HeadlessTable> => {
  if (setup.controllers.includes("Human")) return failed(table, "No one can click in the MCP server, so no player can be Human. Use Agent, DoN or Story.");

  const seed = Option.getOrElse(setup.maybeSeed, randomSeed);
  const controllers = bySeat(setup);

  return Result.match(
    Result.flatMap(begin(setup.table, setup.isItemsEnabled, randomMatchId(), seedRng(seed), controllers, seed), (progress) => playAis(progress, controllers)),
    {
      onSuccess: (progress) => withMatch(table, { ...progress, controllers, acknowledged: NOTHING_ACKNOWLEDGED }),
      onFailure: (error) => failed(table, describeError(rosterOf(SEATS_BY_TABLE[setup.table]), error)),
    },
  );
};

const move = (table: HeadlessTable, { match, generation, seat, index }: SeatMove): Applied<HeadlessTable> =>
  Option.match(table.maybeMatch, {
    onNone: () => failed(table, "No match is running."),
    onSome: (current) =>
      Result.match(
        Result.flatMap(play(current, { match, generation }, seat, index, current.rng), (progress) => playAis(progress, current.controllers)),
        {
          onSuccess: (progress) => withMatch(table, { ...progress, controllers: current.controllers, acknowledged: current.acknowledged }),
          onFailure: (error) => failed(table, describeError(rosterOf(current.game.seats), error)),
        },
      ),
  });

const acknowledge = (table: HeadlessTable, seat: Seat, eventCount: number): HeadlessTable => ({
  ...table,
  maybeMatch: Option.map(table.maybeMatch, (match) => ({ ...match, acknowledged: acknowledgedTo(match.acknowledged, seat, eventCount) })),
});

export const headlessSession: MatchSession<HeadlessTable> = { current: (table) => table.maybeMatch, start, move, acknowledge };
