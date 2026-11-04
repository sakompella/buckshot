import { Array as Arr, Option, Schema } from "effect";

import type { Prompt } from "./bend.ts";
import { Move, Seat, Slot } from "./domain.ts";
import { controllerOf, promptsOf } from "./driver.ts";
import type { Session } from "./model.ts";
import type { Roster } from "./players.ts";
import { moveText } from "./text.ts";

// Where each legal move is played on the table. The board shows the viewer's
// moves on the things they act on: the shotgun, a seat, an item slot, the
// briefcase. Any moves that share one thing fall back to plain buttons.

/** The thing on the table a move is played by clicking. */
export const Target = Schema.TaggedUnion({
  Gun: {},
  Seat: { seat: Seat },
  Slot: { seat: Seat, slot: Slot },
  Briefcase: { seat: Seat },
});

export type Target = typeof Target.Type;

export const targetOf = (seat: Seat, move: Move): Target =>
  Move.match<Target>(move, {
    PickUp: () => Target.cases.Gun.make({}),
    Shoot: ({ target }) => Target.cases.Seat.make({ seat: target }),
    JamTarget: ({ target }) => Target.cases.Seat.make({ seat: target }),
    UseItem: ({ slot }) => Target.cases.Slot.make({ seat, slot }),
    Place: ({ slot }) => Target.cases.Slot.make({ seat, slot }),
    Steal: ({ owner, slot }) => Target.cases.Slot.make({ seat: owner, slot }),
    Grab: () => Target.cases.Briefcase.make({ seat }),
  });

export const targetKey = (target: Target): string => JSON.stringify(target);

/**
 * A whole move of one seat, named by the machine steps it plays (CONTEXT.md's Move): one step from a prompt's menu,
 * or an agent's chain such as picking up the shotgun, then shooting. The label is for display only.
 */
export const TableMove = Schema.Struct({ seat: Seat, steps: Schema.NonEmptyArray(Move), label: Schema.String });

export type TableMove = typeof TableMove.Type;

/** The prompt's menu, each step a move of its own. */
export const promptMoves = (roster: Roster, prompt: Prompt): ReadonlyArray<TableMove> =>
  prompt.menu.map((move) => ({ seat: prompt.seat, steps: [move], label: moveText(roster, prompt.seat, move) }));

/** Every thing a move acts on, in step order. */
export const targetsOf = (move: TableMove): ReadonlyArray<Target> => move.steps.map((step) => targetOf(move.seat, step));

/** The thing a move is played by clicking: where its last step acts. */
const placeOf = (move: TableMove): Target => targetOf(move.seat, move.steps.at(-1) ?? move.steps[0]);

export interface BoardMove {
  /** In the move list. */
  readonly index: number;
  readonly label: string;
}

export interface BoardMoves {
  /** By target key. */
  readonly onTable: ReadonlyMap<string, BoardMove>;
  /** Moves that share a target with another move, so a click on the table could not tell them apart. */
  readonly buttons: ReadonlyArray<BoardMove>;
}

/** Every move, each either on the table or as a plain button. */
export const boardMoves = (moves: ReadonlyArray<TableMove>): BoardMoves => {
  const placed = moves.map((move, index) => ({ key: targetKey(placeOf(move)), move: { index, label: move.label } }));
  const isShared = (key: string): boolean => placed.filter((other) => other.key === key).length > 1;

  return {
    onTable: new Map(placed.flatMap(({ key, move }) => (isShared(key) ? [] : [[key, move] as const]))),
    buttons: placed.flatMap(({ key, move }) => (isShared(key) ? [move] : [])),
  };
};

/** The prompt the viewer answers by clicking: theirs, and only at a Human seat. */
export const viewerPrompt = (match: Session): Option.Option<Prompt> =>
  Arr.findFirst(promptsOf(match.game), (prompt) => prompt.seat === match.viewer && controllerOf(match.controllers, prompt.seat) === "Human");

/** Where a seat sits, counted from the viewer's side: 0 near, 1 left, 2 far, 3 right. */
export type Position = 0 | 1 | 2 | 3;

const POSITIONS: ReadonlyArray<Position> = [0, 1, 2, 3];

/** Where a seat sits, counted from the near seat. */
export const positionOf = (near: Seat, seat: Seat): Position => POSITIONS[(seat - near + 4) % 4] ?? 0;

/** The seat a match's viewer sees nearest: their own; a spectator sees the table from the first seat. */
export const nearSeat = (match: Session): Seat => (match.viewer === "Spectator" ? (match.game.seats[0] ?? 0) : match.viewer);
