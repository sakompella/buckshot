// Throwaway prototype check: runs arena.ts on 2, 3 and 4 player tables. Each
// table runs twice from scratch, which must give the same move log, and once
// more that crashes right after an input is submitted and is then resumed from
// its store, which must give that same move log too.
// Usage: bun proto/arena-pi/check.ts

import { rmSync } from "node:fs";

const tables = [
  { controllers: "Agent,Agent", seed: "7", crashAt: 3 },
  { controllers: "Agent,Agent,DoN", seed: "42", crashAt: 20 },
  { controllers: "Agent,Agent,Agent,Agent", seed: "9", crashAt: 40 },
];

interface Report { readonly checks: Record<string, boolean>; readonly moveLogSha: string; readonly moves: Record<string, number>; readonly modelCalls: number; readonly compactions: Record<string, number> }

const arena = async (dir: string, controllers: string, seed: string, crashAt = 0): Promise<{ readonly code: number; readonly report: Report | undefined }> => {
  const child = Bun.spawn(["nice", "-n", "10", "bun", new URL("arena.ts", import.meta.url).pathname, "--dir", dir, "--controllers", controllers, "--seed", seed, "--crash-at-submit", String(crashAt)], { stdout: "pipe", stderr: "inherit" });
  const text = await new Response(child.stdout).text();
  const code = await child.exited;
  const last = text.trim().split("\n").at(-1) ?? "";

  return { code, report: last.startsWith("{") ? (JSON.parse(last) as Report) : undefined };
};

let isGreen = true;

for (const { controllers, seed, crashAt } of tables) {
  const dirs = ["a", "b", "crash"].map((name) => `/tmp/arena-pi/${seed}-${name}`);
  dirs.forEach((dir) => rmSync(dir, { recursive: true, force: true }));
  const [first, second] = [await arena(dirs[0] ?? "", controllers, seed), await arena(dirs[1] ?? "", controllers, seed)];
  const crashed = await arena(dirs[2] ?? "", controllers, seed, crashAt);
  const resumed = await arena(dirs[2] ?? "", controllers, seed);
  const failed = [first, second, resumed].flatMap(({ report }) => Object.entries(report?.checks ?? { noReport: false }).filter(([, ok]) => !ok).map(([name]) => name));
  const isRepeated = first.report?.moveLogSha === second.report?.moveLogSha;
  const isResumedSame = crashed.code === 3 && resumed.report?.moveLogSha === first.report?.moveLogSha;

  isGreen &&= failed.length === 0 && isRepeated && isResumedSame;
  console.log(JSON.stringify({ controllers, seed, failed, isRepeated, crashExit: crashed.code, isResumedSame, moves: first.report?.moves, modelCalls: first.report?.modelCalls, compactions: first.report?.compactions }));
}

process.exit(isGreen ? 0 : 1);
