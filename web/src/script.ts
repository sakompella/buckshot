import type { parseArgs } from "node:util";

import { Cause, Data, Effect, Exit, Option, Schema } from "effect";

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

export type ParsedArgs = ReturnType<typeof parseArgs>["values"];

/** Decodes the values parseArgs read with `schema`; anything it rejects is a usage error. */
export const decodeArgs =
  <A>(schema: Schema.Decoder<A>, usage: string) =>
  (values: ParsedArgs) =>
    Schema.decodeUnknownEffect(schema)(values).pipe(Effect.mapError(() => new ScriptError({ message: usage, exitCode: 1 })));
