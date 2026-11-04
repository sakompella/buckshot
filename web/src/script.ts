import { Cause, Data, Effect, Exit, Option } from "effect";

/** A script's expected failure: the message goes to stderr and the process exits with `exitCode`. */
export class ScriptError extends Data.TaggedError("ScriptError")<{ readonly message: string; readonly exitCode: number }> {}

/** Runs a script's program. A number it succeeds with is the exit code; a `ScriptError` prints its message, and any other failure prints its cause and exits 1. */
export const runMain = async <E>(program: Effect.Effect<number | void, E>): Promise<void> => {
  const exit = await Effect.runPromiseExit(program);

  if (Exit.isSuccess(exit)) {
    process.exitCode = exit.value ?? 0;

    return;
  }

  const expected = Option.filter(Cause.findErrorOption(exit.cause), (error) => error instanceof ScriptError);

  if (Option.isSome(expected)) {
    console.error(expected.value.message);
    process.exitCode = expected.value.exitCode;
  } else {
    console.error(Cause.pretty(exit.cause));
    process.exitCode = 1;
  }
};
