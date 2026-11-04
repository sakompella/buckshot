import { Config, Effect, Option } from "effect";

import { runMain, ScriptError } from "../src/script.ts";

// Builds the Bend JS entry for the UI into generated/rules.mjs.
// Bend comes from $BEND, else `bend` on PATH. The dev shell sets $BEND to the pinned build.

const source = new URL("../../sim/bend-mp/web.bend", import.meta.url).pathname;

const output = new URL("../generated/rules.mjs", import.meta.url).pathname;

const program = Effect.gen(function* () {
  const configured = yield* Config.option(Config.String("BEND"));
  const bend = Option.getOrUndefined(configured) ?? Bun.which("bend") ?? undefined;

  if (bend === undefined) return yield* Effect.fail(new ScriptError({ message: "bend not found: run inside `nix develop`, or set BEND to the pinned Bend binary", exitCode: 1 }));

  const build = yield* Effect.try({
    try: () => Bun.spawnSync([bend, source, "-o", output], { stdout: "inherit", stderr: "inherit" }),
    catch: (cause) => new ScriptError({ message: `${bend} did not run: ${String(cause)}`, exitCode: 1 }),
  });

  return build.exitCode;
});

await runMain(program);
