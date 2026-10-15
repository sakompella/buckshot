import { Array as Arr, Option, Result } from "effect";

import type { AnswerError } from "../bend.ts";
import { Briefcase, type Move, type Seat, Stage } from "../domain.ts";
import { play, type Progress, promptsOf } from "../driver.ts";
import type { Roster } from "../players.ts";
import { agentMoveText } from "../text.ts";

// An Agent player moves in whole actions, such as "Shoot Player B", where the
// machine asks for steps: pick up the shotgun, then shoot. Each agent move is a
// chain of the machine's own legal moves, found by playing them on a copy of the
// match, so no rule lives here: a chain goes on while the machine leaves the
// player partway through an action.

/** One machine move of a chain, and its index in the player's menu at that step. */
export interface Step {
  readonly move: Move;
  readonly index: number;
}

export type Chain = readonly [Step, ...Array<Step>];

export interface AgentMove {
  readonly label: string;
  readonly chain: Chain;
}

const menuOf = (progress: Progress, seat: Seat) => Arr.findFirst(promptsOf(progress.game), (prompt) => prompt.seat === seat).pipe(Option.map(({ menu }) => menu));

/** Plays one step of the seat's prompt. */
const playStep = (progress: Progress, seat: Seat, index: number): Result.Result<Progress, AnswerError> => play(progress, progress.game.ticket, seat, index, progress.rng);

const isHolding = (progress: Progress, seat: Seat): boolean => progress.game.board.seats.some((view) => view.seat === seat && Briefcase.guards.Holding(view.briefcase));

/** Holding the shotgun, or choosing whom to jam or what to steal. */
const isMidAction = (progress: Progress, seat: Seat): boolean =>
  Stage.matchOrElse(progress.game.board.stage, { Playing: (playing) => playing.seat === seat && playing.mode !== "Idle" }, () => false);

/** Every chain from the seat's menu. A drawn item goes in the first free slot, the first of the machine's placements. */
const chainsFrom = (progress: Progress, seat: Seat): Result.Result<ReadonlyArray<Chain>, AnswerError> =>
  Result.map(
    Result.all(
      Option.getOrElse(menuOf(progress, seat), (): ReadonlyArray<Move> => []).map((move, index) =>
        Result.flatMap(playStep(progress, seat, index), (after): Result.Result<ReadonlyArray<Chain>, AnswerError> => {
          const continuations = (rest: ReadonlyArray<Chain>): ReadonlyArray<Chain> => rest.map((chain): Chain => [{ move, index }, ...chain]);

          if (isHolding(after, seat)) return Result.map(chainsFrom(after, seat), (rest) => continuations(Arr.take(rest, 1)));

          return isMidAction(after, seat) ? Result.map(chainsFrom(after, seat), continuations) : Result.succeed([[{ move, index }]]);
        }),
      ),
    ),
    Arr.flatten,
  );

/** The seat's agent moves, each named once: of two chains with the same words, which differ only in a slot, the first is kept. The AI seats do not hear the copies' notes. */
export const agentMoves = (progress: Progress, roster: Roster, seat: Seat): Result.Result<ReadonlyArray<AgentMove>, AnswerError> =>
  Result.map(chainsFrom({ ...progress, ais: [] }, seat), (chains) =>
    Arr.dedupeWith(
      chains.map((chain) => ({ label: agentMoveText(roster, seat, chain.map(({ move }) => move)), chain })),
      (left, right) => left.label === right.label,
    ),
  );

/** Plays a chain's steps for the seat, one after another. */
export const playChain = (progress: Progress, seat: Seat, chain: Chain): Result.Result<Progress, AnswerError> =>
  chain.reduce<Result.Result<Progress, AnswerError>>((result, { index }) => Result.flatMap(result, (current) => playStep(current, seat, index)), Result.succeed(progress));
