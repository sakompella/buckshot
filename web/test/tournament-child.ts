import { appendFileSync, existsSync, writeFileSync } from "node:fs";
import { join } from "node:path";

import { playFauxRun } from "./faux-run.ts";

const args = process.argv.slice(2);

const dir = args[args.indexOf("--dir") + 1];

if (dir === undefined) throw new Error("missing --dir");

appendFileSync(join(dir, "starts.jsonl"), `${JSON.stringify({ pid: process.pid })}\n`);

process.on("SIGTERM", () => {
  writeFileSync(join(dir, "stopped"), "SIGTERM");
  process.exit(143);
});

while (existsSync(join(dir, "hold"))) await Bun.sleep(10);

await playFauxRun(dir, ["Agent", "DoN"], "on-turn");
