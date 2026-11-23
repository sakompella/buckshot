import { Cause, Effect, Exit, Layer, ManagedRuntime, Option, Schema } from "effect";

/** A script's expected failure: the message goes to stderr and the process exits with `exitCode`. */
export class ScriptError extends Schema.TaggedError<ScriptError>()("ScriptError", { message: Schema.String, exitCode: Schema.Finite }) {}

/** Runs a script's program with the services `layer` builds. A number it succeeds with is the exit code; a `ScriptError` prints its message, and any other failure prints its cause and exits 1. */
export const runMainWith = async <E, R>(layer: Layer.Layer<R>, program: Effect.Effect<number | void, E, R>): Promise<void> => {
  const runtime = ManagedRuntime.make(layer);
  const exit = await runtime.runPromiseExit(program);

  await runtime.dispose();

  if (Exit.isSuccess(exit)) {
    process.exitCode = exit.value ?? 0;

    return;
  }

  const expected = Option.filter(Cause.findErrorOption(exit.cause), Schema.is(ScriptError));

  if (Option.isSome(expected)) {
    console.error(expected.value.message);
    process.exitCode = expected.value.exitCode;
  } else {
    console.error(Cause.pretty(exit.cause));
    process.exitCode = 1;
  }
};

/** Runs a script's program that needs no services; see `runMainWith`. */
export const runMain = async <E>(program: Effect.Effect<number | void, E>): Promise<void> => runMainWith(Layer.empty, program);

export type ParsedArgs = Readonly<Record<string, string | boolean | ReadonlyArray<string | boolean> | undefined>>;

/** Decodes the values parseArgs read with `schema`; anything it rejects is a usage error. */
export const decodeArgs =
  <A>(schema: Schema.Decoder<A>, usage: string) =>
  (values: ParsedArgs) =>
    Schema.decodeEffect(schema)(values).pipe(Effect.mapError(() => ScriptError.make({ message: usage, exitCode: 1 })));
