import { Schema } from "effect";

import type { BendNode } from "../../generated/rules.mjs";
import { Item } from "../domain.ts";
import type { Move } from "../domain.ts";
import { isBendNode, logNode } from "./player.ts";
import type { PlayerInput } from "./player.ts";

// The search input line: one analysis input as numbers separated by spaces, and the move codes that name its root moves.
// This file defines the format; sim/rust/search/src/position.rs parses it. A value is its constructor's tag (its index in
// TAG_GROUPS) then its fields in constructor order; types with one constructor carry no tag.

const TAG_GROUPS: ReadonlyArray<ReadonlyArray<string>> = [
  ["Seat0", "Seat1", "Seat2", "Seat3"],
  Item.literals,
  ["Slot0", "Slot1", "Slot2", "Slot3", "Slot4", "Slot5", "Slot6", "Slot7"],
  ["Live", "Blank"],
  ["Single", "Double"],
  ["Clockwise", "CounterClockwise"],
  ["Idle", "Aiming", "Jamming", "Stealing"],
  ["None", "Some"],
  ["Duo", "Trio", "Quad"],
  ["Unjammed", "Jammed"],
  ["NotGrabbing", "Grabbing", "Holding"],
  ["Setup", "Distributing", "Loading", "Playing", "MatchOver"],
  ["Witnessed", "Learned"],
  ["RoundBegan", "GrabbingBegan", "Granted", "Placed", "GrabbingEnded", "DistributionDone", "Loaded", "TurnSkipped", "JamLifted", "TurnGiven", "PickedUp", "Fired", "Died", "Used", "Healed", "Ejected", "Inverted", "JamApplied", "DirectionFlipped", "RoundWon", "MatchConcluded"],
  ["Glimpse", "Clue", "NoClue", "EmptyBriefcase"],
];

const TAGS: Record<string, number> = {};

for (const names of TAG_GROUPS) {
  for (const [index, name] of names.entries()) { TAGS[name] = index; }
}

const SINGLE = new Set(["Board", "RoundView", "GunView", "SeatView", "Load", "Slots"]);

type Value = Cell | number | bigint | boolean;

interface Cell extends BendNode {
  readonly head?: Value;
  readonly tail?: Cell;
}

const isNumber = Schema.is(Schema.Union([Schema.Finite, Schema.BigInt]));

const isBoolean = Schema.is(Schema.Boolean);

const isValue = (value: unknown): value is Value => isNumber(value) || isBoolean(value) || isBendNode(value);

const nameOf = (node: BendNode): string => node.$.split(/[./]/).pop() ?? "";

/** Numbers of a Bend value, fields in constructor order. A list is its length then its items last first: the parser conses each item onto the front. */
const encode = (node: Value): ReadonlyArray<number> => {
  if (isNumber(node)) { return [Number(node)]; }

  if (isBoolean(node)) { return [node ? 1 : 0]; }

  const name = nameOf(node);

  // A layout marker with no fields; the parser adds it back.
  if (name === "Boxed") { return []; }

  if (name === "Nil" || name === "Con") {
    const items: Array<Value> = [];
    let rest: Cell | undefined = node;

    while (rest !== undefined && nameOf(rest) === "Con") {
      if (rest.head !== undefined) { items.push(rest.head); }

      rest = rest.tail;
    }

    return [items.length, ...items.toReversed().flatMap(encode)];
  }

  const fields = Object.entries(node)
    .filter(([key]) => key !== "$")
    .flatMap(([key, field]) => {
      if (!isValue(field)) { throw new Error(`${name}.${key} is not a Bend value`); }

      return encode(field);
    });

  if (SINGLE.has(name)) { return fields; }

  const tag = TAGS[name];

  if (tag === undefined) { throw new Error(`no tag for ${node.$}`); }

  return [tag, ...fields];
};

/** One analysis input as a search input line: table, items flag (on, as the arena plays), me, board, log. */
export const nativeInput = ({ table, board, log, me }: PlayerInput): string =>
  // SAFETY: the tag is all `encode` reads of a seat.
  [table, 1, ...encode({ $: `domain.Seat${me}` }), ...encode(board), ...encode(logNode(log))].join(" ");

const itemIndex = (item: string): number => TAGS[item] ?? -1;

/** A root move's code (`0.target` shoot, `1.item` use, `2.target` jam, `3.owner.item` steal, `4.owner.target` steal the jammer), from the steps the player's analysis gives. */
export const moveCode = (steps: ReadonlyArray<Move>): string => {
  const [first, second, third] = steps;

  if (first?._tag === "PickUp" && second?._tag === "Shoot") { return `0.${second.target}`; }

  if (first?._tag === "UseItem") {
    if (first.item === "Jammer" && second?._tag === "JamTarget") { return `2.${second.target}`; }

    if (first.item === "Adrenaline" && second?._tag === "Steal") { return second.item === "Jammer" && third?._tag === "JamTarget" ? `4.${second.owner}.${third.target}` : `3.${second.owner}.${itemIndex(second.item)}`; }

    return `1.${itemIndex(first.item)}`;
  }

  throw new Error(`no native move name for ${JSON.stringify(steps)}`);
};
