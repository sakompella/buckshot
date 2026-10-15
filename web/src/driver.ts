import { Array as Arr, Option, Result, Schema } from "effect";

import { answerDraw, answerPrompt, type AnswerError, type Brain, type BendContractError, coinWord, decideMove, freshMind, type Game, hearNotes, Mind, type Prompt, type Step, startGame, type Ticket } from "./bend.ts";
import type { GameEvent, LearnedSecret, Seat, SeatCount } from "./domain.ts";
import { nextBelow, type Rng } from "./rng.ts";

// Drives a match between controllers. Draws come from the seeded Rng. An AI
// seat (Story or DoN) decides through the same Bend entry points the simulator
// driver uses (sim/bend-mp/driver.bend); its memory is an opaque Bend value
// held in the Progress, and each seat draws coins from its own stream.

export const Controller = Schema.Literals(["Human", "Story", "DoN", "Agent"]);

export type Controller = typeof Controller.Type;

export const isAi = (controller: Controller): controller is Brain => controller === "Story" || controller === "DoN";

/** Draw answers taken in one settle before giving up; a match needs a few hundred at most. */
const DRAW_LIMIT = 10_000;

/** AI moves taken in one go before giving up; a whole match takes a few hundred. */
const AI_MOVE_LIMIT = 10_000;

const SEATS: ReadonlyArray<Seat> = [0, 1, 2, 3];

/** One AI seat: its memory, and how many coins it has drawn. */
export const AiSeat = Schema.Struct({ mind: Schema.instanceOf(Mind), coins: Schema.Number });

export type AiSeat = typeof AiSeat.Type;

export interface Progress {
  readonly game: Game;
  readonly rng: Rng;
  readonly events: ReadonlyArray<GameEvent>;
  readonly learned: ReadonlyArray<LearnedSecret>;
  /** By seat; None for a human seat. */
  readonly ais: ReadonlyArray<Option.Option<AiSeat>>;
  /** The match seed the seats' coin streams come from. */
  readonly seed: number;
}

const withAi = (ais: ReadonlyArray<Option.Option<AiSeat>>, seat: Seat, ai: AiSeat): ReadonlyArray<Option.Option<AiSeat>> => ais.map((current, index) => (index === seat ? Option.some(ai) : current));

/** Absorbs one step: its events and secrets, and every AI seat hearing its notes. */
const absorb = (progress: Progress, step: Step, rng: Rng): Progress => ({
  ...progress,
  game: step.game,
  rng,
  events: [...progress.events, ...step.events],
  learned: [...progress.learned, ...step.learned],
  ais: progress.ais.map((ai, seat) => Option.map(ai, ({ mind, coins }) => ({ mind: hearNotes(mind, step.notes, SEATS[seat] ?? 0), coins }))),
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

export const begin = (table: SeatCount, items: boolean, match: number, rng: Rng, controllers: ReadonlyArray<Controller>, seed: number): Result.Result<Progress, AnswerError | BendContractError> =>
  Result.flatMap(startGame(table, items, match), (step) => {
    const ais = Arr.makeBy(SEATS.length, (seat) =>
      Option.map(
        Option.filter(Arr.get(controllers, seat), isAi),
        (brain) => ({ mind: freshMind(brain), coins: 0 }),
      ),
    );

    return settleDraws(absorb({ game: step.game, rng, events: [], learned: [], ais, seed }, step, rng));
  });

export const promptsOf = (game: Game): ReadonlyArray<Prompt> => (game.pending.kind === "Choose" ? game.pending.prompts : []);

export const controllerOf = (controllers: ReadonlyArray<Controller>, seat: Seat): Controller => Option.getOrElse(Arr.get(controllers, seat), (): Controller => "Human");

/** The first prompt an AI must answer, if any. */
export const aiPrompt = (game: Game, controllers: ReadonlyArray<Controller>): Option.Option<Prompt> =>
  Arr.findFirst(promptsOf(game), (prompt) => isAi(controllerOf(controllers, prompt.seat)));

/** Answers a seat's prompt, then settles the draws that follow. */
export const play = (progress: Progress, ticket: Ticket, seat: Seat, index: number, rng: Rng): Result.Result<Progress, AnswerError> =>
  Result.flatMap(answerPrompt(progress.game, ticket, seat, index), (step) => settleDraws(absorb(progress, step, rng)));

/** One AI decision: the AI picks from its own menu with its next coin; its memory is kept before the notes of its move are heard. */
export const aiStep = (progress: Progress, prompt: Prompt): Result.Result<Progress, AnswerError> =>
  Option.match(Arr.get(progress.ais, prompt.seat).pipe(Option.flatten), {
    onNone: () => Result.succeed(progress),
    onSome: ({ mind, coins }) =>
      Result.flatMap(decideMove(progress.game, prompt, mind, coinWord(progress.seed, prompt.seat, coins)), (choice) =>
        play({ ...progress, ais: withAi(progress.ais, prompt.seat, { mind: choice.mind, coins: coins + 1 }) }, prompt.ticket, prompt.seat, choice.index, progress.rng),
      ),
  });

/** Lets the AI seats move until an Agent or Human seat must answer, or the match is over. */
export const playAis = (start: Progress, controllers: ReadonlyArray<Controller>): Result.Result<Progress, AnswerError> => {
  let progress = start;

  for (let moves = 0; moves < AI_MOVE_LIMIT; moves++) {
    const prompt = aiPrompt(progress.game, controllers);

    if (Option.isNone(prompt)) return Result.succeed(progress);

    const stepped = aiStep(progress, prompt.value);

    if (Result.isFailure(stepped)) return stepped;

    progress = stepped.success;
  }

  return Result.succeed(progress);
};
