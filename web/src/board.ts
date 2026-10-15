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

export interface BoardMove {
  readonly index: number;
  readonly label: string;
}

export interface BoardMoves {
  /** By target key. */
  readonly onTable: ReadonlyMap<string, BoardMove>;
  /** Moves that share a target with another move, so a click on the table could not tell them apart. */
  readonly buttons: ReadonlyArray<BoardMove>;
}

/** Every move of the menu, each either on the table or as a plain button. */
export const boardMoves = (roster: Roster, prompt: Prompt): BoardMoves => {
  const placed = prompt.menu.map((move, index) => ({ key: targetKey(targetOf(prompt.seat, move)), move: { index, label: moveText(roster, prompt.seat, move) } }));
  const isShared = (key: string): boolean => placed.filter((other) => other.key === key).length > 1;

  return {
    onTable: new Map(placed.filter(({ key }) => !isShared(key)).map(({ key, move }) => [key, move])),
    buttons: placed.filter(({ key }) => isShared(key)).map(({ move }) => move),
  };
};

/** The prompt the viewer answers by clicking: theirs, and only at a Human seat. */
export const viewerPrompt = (match: Session): Option.Option<Prompt> =>
  Arr.findFirst(promptsOf(match.game), (prompt) => prompt.seat === match.viewer && controllerOf(match.controllers, prompt.seat) === "Human");

/** Where a seat sits, counted from the viewer's side: 0 near, 1 left, 2 far, 3 right. */
export type Position = 0 | 1 | 2 | 3;

const POSITIONS: ReadonlyArray<Position> = [0, 1, 2, 3];

/** The viewer's seat sits nearest; a spectator sees the table from the first seat. */
export const positionOf = (match: Session, seat: Seat): Position => {
  const near = match.viewer === "Spectator" ? (match.game.seats[0] ?? 0) : match.viewer;

  return POSITIONS[(seat - near + 4) % 4] ?? 0;
};
