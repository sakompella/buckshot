import { Letter } from "../players.ts";

// The arena's agents are A to D. Each is one model on its own endpoint and plays
// as the player of its letter, Player A for agent A, wherever it sits. Each match
// seats the agents by rotation, so no agent keeps a seat.

export const AgentId = Letter;

export type AgentId = Letter;

export const AGENTS: ReadonlyArray<AgentId> = AgentId.literals;

/** The agent at each seat, in table order: the agents in order, rotated left by `rotation`. */
export const seatingOf = (agents: ReadonlyArray<AgentId>, rotation: number): ReadonlyArray<AgentId> => {
  const shift = ((rotation % agents.length) + agents.length) % agents.length;

  return [...agents.slice(shift), ...agents.slice(0, shift)];
};
