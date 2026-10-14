import { Match } from "effect";

import type { AnswerError } from "./bend.ts";
import { GameEvent, type Item, Move, type Seat, Secret } from "./domain.ts";

// The words the UI and the agent tools both use for seats, items, moves and events.

export const seatName = (seat: Seat): string => `Seat ${seat}`;

export const describeError = (error: AnswerError): string =>
  Match.value(error).pipe(
    Match.tag("BendContractError", ({ call, detail }) => `Bend returned an unexpected value from ${call}: ${detail}`),
    Match.tag("StaleAnswer", () => "That move was for an earlier turn. Choose again."),
    Match.tag("NoPrompt", ({ seat }) => `Seat ${seat} has no move right now.`),
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

export const moveText = (seat: Seat, move: Move): string =>
  Move.match(move, {
    PickUp: () => "Pick up the shotgun",
    Shoot: ({ target }) => (target === seat ? "Shoot yourself" : `Shoot ${seatName(target)}`),
    UseItem: ({ item, slot }) => `Use ${itemName(item)} (slot ${slot + 1})`,
    Grab: () => "Grab an item from the briefcase",
    Place: ({ slot }) => `Place the item in slot ${slot + 1}`,
    JamTarget: ({ target }) => `Jam ${seatName(target)} (they skip a turn)`,
    Steal: ({ owner, slot, item }) => `Steal ${itemName(item)} from ${seatName(owner)} (slot ${slot + 1})`,
  });

export const eventText = (event: GameEvent): string =>
  GameEvent.match(event, {
    RoundBegan: ({ round, health, first }) => `Round ${round + 1} begins. Everyone has ${health} health; ${seatName(first)} starts.`,
    GrabbingBegan: ({ seats }) => `Item distribution: ${seats.map(seatName).join(", ")} grab from the briefcase.`,
    Granted: ({ seat }) => `${seatName(seat)} drew an item.`,
    Placed: ({ seat, item, slot }) => `${seatName(seat)} placed ${itemName(item)} in slot ${slot + 1}.`,
    GrabbingEnded: ({ seat }) => `${seatName(seat)} finished grabbing.`,
    DistributionDone: () => "Distribution is over.",
    Loaded: ({ load }) => `The shotgun is loaded: ${load.live} live, ${load.blank} blank.`,
    TurnSkipped: ({ seat }) => `${seatName(seat)} is jammed and loses the turn.`,
    JamLifted: ({ seat }) => `${seatName(seat)} is no longer jammed.`,
    TurnGiven: ({ seat }) => `${seatName(seat)}'s turn.`,
    PickedUp: ({ seat }) => `${seatName(seat)} picked up the shotgun.`,
    Fired: ({ shooter, target, shell, applied, health }) =>
      `${seatName(shooter)} shot ${shooter === target ? "themselves" : seatName(target)}: ${shell === "Live" ? `live, ${applied} damage, ${health} health left` : "blank"}.`,
    Died: ({ seat }) => `${seatName(seat)} is out.`,
    Used: ({ seat, owner, item }) => (seat === owner ? `${seatName(seat)} used ${itemName(item)}.` : `${seatName(seat)} took ${itemName(item)} from ${seatName(owner)} and used it.`),
    Healed: ({ seat, health }) => `${seatName(seat)} healed to ${health}.`,
    Ejected: ({ seat, shell }) => `${seatName(seat)} racked out a ${shell.toLowerCase()} shell.`,
    Inverted: ({ seat }) => `${seatName(seat)} inverted the chambered shell.`,
    JamApplied: ({ by, target }) => `${seatName(by)} jammed ${seatName(target)}.`,
    DirectionFlipped: ({ direction }) => `Turn order is now ${direction === "Clockwise" ? "clockwise" : "counterclockwise"}.`,
    RoundWon: ({ seat, prize }) => `${seatName(seat)} wins the round and $${prize.toLocaleString("en-US")}.`,
    MatchConcluded: () => "The match is over.",
  });

export const secretText = (secret: Secret): string =>
  Secret.match(secret, {
    Glimpse: ({ shell }) => `The chambered shell is ${shell.toLowerCase()}.`,
    Clue: ({ position, shell }) => `Shell ${position + 1} from now is ${shell.toLowerCase()}.`,
    NoClue: () => "The phone gave no clue.",
    EmptyBriefcase: () => "The briefcase was empty.",
  });
