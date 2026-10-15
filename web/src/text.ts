import { Match } from "effect";

import type { AnswerError } from "./bend.ts";
import { GameEvent, type Item, Move, type Seat, Secret } from "./domain.ts";
import type { Roster } from "./players.ts";

// The words the UI and the agent tools both use for players, items, moves and events.

export const describeError = (roster: Roster, error: AnswerError): string =>
  Match.value(error).pipe(
    Match.tag("BendContractError", ({ call, detail }) => `Bend returned an unexpected value from ${call}: ${detail}`),
    Match.tag("StaleAnswer", () => "That move was for an earlier turn. Choose again."),
    Match.tag("NoPrompt", ({ seat }) => `${roster.nameOf(seat)} has no move right now.`),
    Match.exhaustive,
  );

const ITEM_NAMES: Readonly<Record<Item, string>> = {
  Saw: "handsaw",
  Glass: "magnifying glass",
  Jammer: "jammer",
  Cigarettes: "cigarettes",
  Beer: "beer",
  Phone: "burner phone",
  Inverter: "inverter",
  Adrenaline: "adrenaline",
  Remote: "remote",
};

export const itemName = (item: Item): string => ITEM_NAMES[item];

export const moveText = (roster: Roster, seat: Seat, move: Move): string =>
  Move.match(move, {
    PickUp: () => "Pick up the shotgun",
    Shoot: ({ target }) => (target === seat ? "Shoot yourself" : `Shoot ${roster.nameOf(target)}`),
    UseItem: ({ item, slot }) => `Use ${itemName(item)} (slot ${slot + 1})`,
    Grab: () => "Grab an item from the briefcase",
    Place: ({ slot }) => `Place the item in slot ${slot + 1}`,
    JamTarget: ({ target }) => `Jam ${roster.nameOf(target)} (they skip a turn)`,
    Steal: ({ owner, slot, item }) => `Steal ${itemName(item)} from ${roster.nameOf(owner)} (slot ${slot + 1})`,
  });

/**
 * An agent move's words, from the machine moves it chains, without slots: "Shoot Player B" picks up the shotgun and shoots.
 * Steps that only open an action add none: picking up the shotgun, using a jammer or adrenaline before its target, placing a drawn item.
 */
export const agentMoveText = (roster: Roster, seat: Seat, moves: ReadonlyArray<Move>): string => {
  const phrases = moves.flatMap((move, index) =>
    Move.match(move, {
      PickUp: () => [],
      Shoot: ({ target }) => [target === seat ? "shoot yourself" : `shoot ${roster.nameOf(target)}`],
      UseItem: ({ item }) => (index === moves.length - 1 ? [`use ${itemName(item)}`] : []),
      Grab: () => ["grab an item"],
      Place: () => [],
      JamTarget: ({ target }) => [`jam ${roster.nameOf(target)}`],
      Steal: ({ owner, item }) => [`steal ${itemName(item)} from ${roster.nameOf(owner)}`],
    }),
  );

  const text = phrases.join(" and ");

  return `${text.charAt(0).toUpperCase()}${text.slice(1)}`;
};

export const eventText = (roster: Roster, event: GameEvent): string =>
  GameEvent.match(event, {
    RoundBegan: ({ round, health, first }) => `Round ${round + 1} begins. Everyone has ${health} health; ${roster.nameOf(first)} starts.`,
    GrabbingBegan: ({ seats }) => `Item distribution: ${seats.map(roster.nameOf).join(", ")} grab from the briefcase.`,
    Granted: ({ seat }) => `${roster.nameOf(seat)} drew an item.`,
    Placed: ({ seat, item, slot }) => `${roster.nameOf(seat)} placed ${itemName(item)} in slot ${slot + 1}.`,
    GrabbingEnded: ({ seat }) => `${roster.nameOf(seat)} finished grabbing.`,
    DistributionDone: () => "Distribution is over.",
    Loaded: ({ load }) => `The shotgun is loaded: ${load.live} live, ${load.blank} blank.`,
    TurnSkipped: ({ seat }) => `${roster.nameOf(seat)} is jammed and loses the turn.`,
    JamLifted: ({ seat }) => `${roster.nameOf(seat)} is no longer jammed.`,
    TurnGiven: ({ seat }) => `${roster.nameOf(seat)}'s turn.`,
    PickedUp: ({ seat }) => `${roster.nameOf(seat)} picked up the shotgun.`,
    Fired: ({ shooter, target, shell, applied, health }) =>
      `${roster.nameOf(shooter)} shot ${shooter === target ? "themselves" : roster.nameOf(target)}: ${shell === "Live" ? `live, ${applied} damage, ${health} health left` : "blank"}.`,
    Died: ({ seat }) => `${roster.nameOf(seat)} is out.`,
    Used: ({ seat, owner, item }) => (seat === owner ? `${roster.nameOf(seat)} used ${itemName(item)}.` : `${roster.nameOf(seat)} took ${itemName(item)} from ${roster.nameOf(owner)} and used it.`),
    Healed: ({ seat, health }) => `${roster.nameOf(seat)} healed to ${health}.`,
    Ejected: ({ seat, shell }) => `${roster.nameOf(seat)} racked out a ${shell.toLowerCase()} shell.`,
    Inverted: ({ seat }) => `${roster.nameOf(seat)} inverted the chambered shell.`,
    JamApplied: ({ by, target }) => `${roster.nameOf(by)} jammed ${roster.nameOf(target)}.`,
    DirectionFlipped: ({ direction }) => `Turn order is now ${direction === "Clockwise" ? "clockwise" : "counterclockwise"}.`,
    RoundWon: ({ seat, prize }) => `${roster.nameOf(seat)} wins the round and $${prize.toLocaleString("en-US")}.`,
    MatchConcluded: () => "The match is over.",
  });

const ORDINALS = ["1st", "2nd", "3rd", "4th", "5th", "6th", "7th", "8th"];

const ordinal = (position: number): string => ORDINALS[position - 1] ?? `${position}th`;

/** Clue positions count from 1, the chambered shell, as the rules library does. */
export const secretText = (secret: Secret): string =>
  Secret.match(secret, {
    Glimpse: ({ shell }) => `The chambered shell is ${shell.toLowerCase()}.`,
    Clue: ({ position, shell }) => `The ${ordinal(position)} shell is ${shell.toLowerCase()}.`,
    NoClue: () => "The phone gave no clue.",
    EmptyBriefcase: () => "The briefcase was empty.",
  });
