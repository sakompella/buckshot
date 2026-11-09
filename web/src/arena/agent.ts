import { Schema } from "effect";

import { Letter } from "../players.ts";

// The arena's agents are A to D. Each is one model on its own endpoint and plays
// as the player of its letter, Player A for agent A, wherever it sits. Each match
// rotates the seats, agents, bots and humans alike, so no one keeps a position.

export const AgentId = Letter;

export type AgentId = Letter;

export const AGENTS: ReadonlyArray<AgentId> = AgentId.literals;

/** Who sits at each position, in table order: the seats in order, rotated left by `rotation`. */
export const seatingOf = <A>(seats: ReadonlyArray<A>, rotation: number): ReadonlyArray<A> => {
  const shift = ((rotation % seats.length) + seats.length) % seats.length;

  return [...seats.slice(shift), ...seats.slice(0, shift)];
};

/** An engine seat, played by the Rust search (engine.ts): `Engine/<depth>/<budget>`, its decision depth and node budget. */
export const EngineSeat = Schema.TemplateLiteral(["Engine/", Schema.Int, "/", Schema.Int]);

export type EngineSeat = typeof EngineSeat.Type;

export const isEngine = Schema.is(EngineSeat);

/** What can sit at one position: an agent by its letter, a bot, a human at a terminal, or an engine. */
export const SeatSpec = Schema.Union([AgentId, Schema.Literals(["DoN", "Story", "Human"]), EngineSeat]);

export type SeatSpec = typeof SeatSpec.Type;
