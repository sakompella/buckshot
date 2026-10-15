// Throwaway prototype check: runs the referee over the configs the design doc
// cites, twice each, and prints whether every check passed and whether the move
// log repeated. Gated runs must repeat; racing runs usually do not.
// Usage: bun proto/arena/check.ts

const configs = [
  { controllers: "Agent,Agent", seed: "7" },
  { controllers: "Agent,Agent,DoN", seed: "42" },
  { controllers: "Agent,Agent,Agent,Agent", seed: "9" },
];

interface Report { readonly checks: Record<string, boolean>; readonly moveLogSha: string; readonly agentMoves: number; readonly referee: { readonly refusals: number }; readonly wallMs: number }

const runOnce = async (controllers: string, seed: string, gate: string, tag: string): Promise<Report> => {
  const child = Bun.spawn(["nice", "-n", "10", "bun", new URL("referee.ts", import.meta.url).pathname, "--controllers", controllers, "--seed", seed, "--gate", gate, "--out", `/tmp/arena-proto/${tag}`], { stdout: "pipe", stderr: "ignore" });
  const text = await new Response(child.stdout).text();

  await child.exited;

  return JSON.parse(text.trim().split("\n").at(-1) ?? "{}") as Report;
};

let isGreen = true;

for (const { controllers, seed } of configs) {
  for (const gate of ["on", "off"]) {
    const runs = [await runOnce(controllers, seed, gate, `${seed}-${gate}-a`), await runOnce(controllers, seed, gate, `${seed}-${gate}-b`)];
    const failed = runs.flatMap(({ checks }) => Object.entries(checks).filter(([, ok]) => !ok).map(([name]) => name));
    const isRepeated = runs[0]?.moveLogSha === runs[1]?.moveLogSha;

    isGreen &&= failed.length === 0 && (gate === "off" || isRepeated);
    console.log(JSON.stringify({ controllers, seed, gate, failed, isRepeated, agentMoves: runs.map((run) => run.agentMoves), refusals: runs.map((run) => run.referee.refusals), wallMs: runs.map((run) => run.wallMs) }));
  }
}

process.exit(isGreen ? 0 : 1);
