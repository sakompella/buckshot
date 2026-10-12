import { Array as Arr, Option, Result, Schema } from "effect";

import { answerDraw, answerPrompt, type AnswerError, type BendContractError, type Game, type Prompt, type Step, startGame, type Ticket } from "./bend.ts";
import type { GameEvent, LearnedSecret, Seat, SeatCount } from "./domain.ts";
import { nextBelow, type Rng } from "./rng.ts";

// Drives a match between controllers. This is the TS seam for the Bend
// driver and AIs (sim/bend-mp/driver.bend, ai/*.bend): until they land on the
// main branch, draws come from the seeded Rng and a "Bot" seat picks a
// uniformly random legal move. Replace botPick and settleDraws with calls
// through bend.ts once web.bend exports the driver and the AIs.

export const Controller = Schema.Literals(["Human", "Bot"]);

export type Controller = typeof Controller.Type;

/** Draw answers taken in one settle before giving up; a match needs a few hundred at most. */
const DRAW_LIMIT = 10_000;

export interface Progress {
  readonly game: Game;
  readonly rng: Rng;
  readonly events: ReadonlyArray<GameEvent>;
  readonly learned: ReadonlyArray<LearnedSecret>;
}

const absorb = (progress: Progress, step: Step, rng: Rng): Progress => ({
  game: step.game,
  rng,
  events: [...progress.events, ...step.events],
  learned: [...progress.learned, ...step.learned],
});

/** Answers every Draw from the Rng until the game needs a seat's move or is over. */
export const settleDraws = (start: Progress): Result.Result<Progress, AnswerError> => {
  let progress = start;

  for (let taken = 0; taken < DRAW_LIMIT; taken++) {
    const pending = progress.game.pending;

    if (pending.kind !== "Draw") return Result.succeed(progress);

    const [value, rng] = nextBelow(progress.rng, pending.size);
    const answered = answerDraw(progress.game, pending.ticket, value);

    if (Result.isFailure(answered)) return Result.fail(answered.failure);

    progress = absorb(progress, answered.success, rng);
  }

  return Result.succeed(progress);
};

export const begin = (table: SeatCount, items: boolean, match: number, rng: Rng): Result.Result<Progress, AnswerError | BendContractError> =>
  Result.flatMap(startGame(table, items, match), (step) => settleDraws({ game: step.game, rng, events: step.events, learned: step.learned }));

export const promptsOf = (game: Game): ReadonlyArray<Prompt> => (game.pending.kind === "Choose" ? game.pending.prompts : []);

export const controllerOf = (controllers: ReadonlyArray<Controller>, seat: Seat): Controller => Option.getOrElse(Arr.get(controllers, seat), () => "Human");

/** The first prompt a bot must answer, if any. */
export const botPrompt = (game: Game, controllers: ReadonlyArray<Controller>): Option.Option<Prompt> =>
  Arr.findFirst(promptsOf(game), (prompt) => controllerOf(controllers, prompt.seat) === "Bot");

/** Answers a seat's prompt, then settles the draws that follow. */
export const play = (progress: Progress, ticket: Ticket, seat: Seat, index: number, rng: Rng): Result.Result<Progress, AnswerError> =>
  Result.flatMap(answerPrompt(progress.game, ticket, seat, index), (step) => settleDraws(absorb(progress, step, rng)));

/** One bot decision: a random index into its own menu. */
export const botStep = (progress: Progress, prompt: Prompt): Result.Result<Progress, AnswerError> => {
  const [index, rng] = nextBelow(progress.rng, prompt.menu.length);

  return play(progress, prompt.ticket, prompt.seat, index, rng);
};
