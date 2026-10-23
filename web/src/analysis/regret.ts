import { type Move } from "../domain.ts";
import { type Analysis, type Player, type Position } from "./player.ts";

// Regret of one recorded decision: the minimax player's best score minus the
// score of the move the player chose, from that player's own information.
// Scores are the deciding player's chance of winning the current round in
// millionths, so a regret of 10,000 is one percentage point.

/** A certain round win. */
export const WIN = 1_000_000;

/** The search's settings for a run, stored with every row so that runs with different settings are never mixed. */
export interface Limits {
  readonly depth: number;
  readonly budget: number;
}

export interface MoveValue {
  readonly label: string;
  readonly score: number;
}

/**
 * How a decision was scored. `searched` has a regret. The `fallback` gives every move the static value before any move, because not even
 * one decision fit the budget; it has no regret, never a zero one. `invalid` is a position the player cannot analyse, with its reason.
 */
export type Regret =
  | {
      readonly status: "searched";
      readonly values: ReadonlyArray<MoveValue>;
      readonly best: MoveValue;
      readonly chosen: MoveValue;
      readonly regret: number;
      /** Both scores are certain, 0 or a win, so every line they rest on ends the round. Certain values that mix wins and losses count as not exact. */
      readonly exact: boolean;
      readonly depth: number;
      readonly limited: boolean;
      readonly nodes: number;
    }
  | { readonly status: "fallback"; readonly values: ReadonlyArray<MoveValue>; readonly nodes: number }
  | { readonly status: "invalid"; readonly reason: string; readonly nodes: number };

const isCertain = (score: number): boolean => score === 0 || score === WIN;

/**
 * Scores the decision whose menu was `menu` and which chose `chosen`. `labelOf` words a move as the menu does. The player's moves and the
 * menu must name the same moves, one each; anything else means the position or the labels were built wrong, and throws.
 */
export const regretOf = (analysis: Analysis, labelOf: (steps: ReadonlyArray<Move>) => string, menu: ReadonlyArray<string>, chosen: string): Regret => {
  if (analysis.kind === "invalid") return { status: "invalid", reason: analysis.reason, nodes: analysis.nodes };

  const values = analysis.lines.map((line) => ({ label: labelOf(line.steps), score: line.score }));
  const labels = values.map((value) => value.label);

  if (new Set(labels).size !== labels.length || labels.length !== menu.length || menu.some((label) => !labels.includes(label))) {
    throw new Error(`the player's moves ${JSON.stringify(labels)} are not the menu ${JSON.stringify(menu)}`);
  }

  if (analysis.depth === 0 && analysis.limited) return { status: "fallback", values, nodes: analysis.nodes };

  const best = values[analysis.best];
  const choice = values.find((value) => value.label === chosen);

  if (best === undefined || choice === undefined) throw new Error(`"${chosen}" is not on the menu ${JSON.stringify(menu)}`);

  return {
    status: "searched",
    values,
    best,
    chosen: choice,
    regret: best.score - choice.score,
    exact: isCertain(best.score) && isCertain(choice.score),
    depth: analysis.depth,
    limited: analysis.limited,
    nodes: analysis.nodes,
  };
};

/** The player's analysis of `position`, scored against the move chosen there. */
export const regretAt = (player: Player, position: Position, limits: Limits, labelOf: (steps: ReadonlyArray<Move>) => string, menu: ReadonlyArray<string>, chosen: string): Regret =>
  regretOf(player.analyse(position, limits.depth, limits.budget), labelOf, menu, chosen);
