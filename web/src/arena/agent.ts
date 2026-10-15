import { Schema } from "effect";

// The arena's agents are A to D. Each is one model on its own endpoint, and each
// match seats them at Player numbers by rotation, so no agent keeps a seat.

export const AGENTS = ["A", "B", "C", "D"] as const;

export const AgentId = Schema.Literals(AGENTS);

export type AgentId = typeof AgentId.Type;

/** The agent at each Player number, from Player 1: the agents in order, rotated left by `rotation`. */
export const seatingOf = (agents: ReadonlyArray<AgentId>, rotation: number): ReadonlyArray<AgentId> => {
  const shift = ((rotation % agents.length) + agents.length) % agents.length;

  return [...agents.slice(shift), ...agents.slice(0, shift)];
};
