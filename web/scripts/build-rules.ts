import { fileURLToPath } from "node:url";

import { Config, Effect, Option } from "effect";

import { runMain, ScriptError } from "../src/script.ts";

// Builds the Bend JS entry for web/ (sim/bend-mp/web.bend) into generated/rules.mjs.
// Bend comes from $BEND, else `bend` on PATH. The dev shell sets $BEND to the pinned build.

const source = fileURLToPath(new URL("../../sim/bend-mp/web.bend", import.meta.url));

const output = fileURLToPath(new URL("../generated/rules.mjs", import.meta.url));

const program = Effect.gen(function* () {
  const configured = yield* Config.option(Config.String("BEND"));
  const bend = Option.getOrUndefined(configured) ?? Bun.which("bend") ?? undefined;

  if (bend === undefined) { return yield* ScriptError.make({ message: "bend not found: run inside `nix develop`, or set BEND to the pinned Bend binary", exitCode: 1 }); }

  const build = yield* Effect.try({
    try: () => Bun.spawnSync([bend, source, "-o", output], { stdout: "inherit", stderr: "inherit" }),
    catch: (cause) => ScriptError.make({ message: `${bend} did not run: ${String(cause)}`, exitCode: 1 }),
  });

  if (build.exitCode === null) { return yield* ScriptError.make({ message: `${bend} was stopped by ${String(build.signalCode)}; generated/rules.mjs is not rebuilt`, exitCode: 1 }); }

  return build.exitCode;
});

await runMain(program);
