import { mkdtempSync, readFileSync, writeFileSync } from "node:fs";
import { tmpdir } from "node:os";
import { join } from "node:path";

import { Effect } from "effect";

import { decodeFindingsData } from "../src/findings/data.ts";
import { ogCard } from "../src/findings/og.ts";
import { runMain, ScriptError } from "../src/script.ts";

// Writes web/online/og.png, the card a shared link shows, from web/online/data with resvg (in `nix develop`). The PNG
// is committed: it holds only numbers the post states.

const ONLINE = join(import.meta.dir, "../online");

const read = (name: string): string => readFileSync(join(ONLINE, "data", `${name}.json`), "utf8");

const program = Effect.gen(function* () {
  const resvg = Bun.which("resvg");

  if (resvg === null) { return yield* ScriptError.make({ message: "resvg not found: run inside `nix develop`", exitCode: 1 }); }

  const { findings } = yield* Effect.try({ try: () => decodeFindingsData(read("summary"), read("findings")), catch: (cause) => ScriptError.make({ message: `web/online/data does not decode: ${String(cause)}`, exitCode: 1 }) });
  const svg = join(mkdtempSync(join(tmpdir(), "og-")), "og.svg");

  writeFileSync(svg, ogCard(findings));

  const run = Bun.spawnSync([resvg, svg, join(ONLINE, "og.png")], { stdout: "inherit", stderr: "inherit" });

  return run.exitCode === 0 ? 0 : yield* ScriptError.make({ message: `resvg exited ${String(run.exitCode)}`, exitCode: 1 });
});

await runMain(program);
