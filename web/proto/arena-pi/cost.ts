// Throwaway prototype: prices arena runs offline from their calls.jsonl and a
// price table, so changing a price only means rerunning this. Each argument is
// a match directory (it has calls.jsonl) or a directory of match directories.
// Usage: bun proto/arena-pi/cost.ts <dir>... [--prices proto/arena-pi/prices.json]

import { existsSync, readdirSync, readFileSync } from "node:fs";
import { join } from "node:path";

interface Rates { readonly input: number; readonly output: number; readonly cacheRead: number; readonly cacheWrite: number }
interface Price extends Rates { readonly tiers?: ReadonlyArray<Rates & { readonly inputTokensAbove: number }>; readonly source: string }
interface PriceTable { readonly unit: string; readonly models: Record<string, Price> }
interface Usage { readonly input: number; readonly output: number; readonly cacheRead: number; readonly cacheWrite: number }
interface Call { readonly player: number; readonly provider: string; readonly model: string; readonly usage: Usage }

const pricesFlag = process.argv.indexOf("--prices");
const pricesPath = pricesFlag === -1 ? new URL("prices.json", import.meta.url).pathname : (process.argv[pricesFlag + 1] ?? "");
const table = JSON.parse(readFileSync(pricesPath, "utf8")) as PriceTable;
const roots = process.argv.slice(2).filter((arg, index, args) => arg !== "--prices" && args[index - 1] !== "--prices");

const matchDirs = (root: string): Array<string> =>
  existsSync(join(root, "calls.jsonl"))
    ? [root]
    : readdirSync(root, { withFileTypes: true }).filter((entry) => entry.isDirectory()).flatMap((entry) => matchDirs(join(root, entry.name)));

const callsOf = (dir: string): Array<Call> =>
  readFileSync(join(dir, "calls.jsonl"), "utf8").trim().split("\n").filter(Boolean).map((line) => JSON.parse(line) as Call);

/** The call's cost in dollars, or undefined when the table has no price for its model. */
const costOf = (call: Call): number | undefined => {
  const price = table.models[call.model];
  if (price === undefined) return undefined;
  const prompt = call.usage.input + call.usage.cacheRead + call.usage.cacheWrite;
  const rates = price.tiers?.findLast((tier) => prompt > tier.inputTokensAbove) ?? price;
  return (call.usage.input * rates.input + call.usage.output * rates.output + call.usage.cacheRead * rates.cacheRead + call.usage.cacheWrite * rates.cacheWrite) / 1_000_000;
};

interface Total { calls: number; input: number; output: number; cacheRead: number; cacheWrite: number; dollars: number; unpriced: number }
const emptyTotal = (): Total => ({ calls: 0, input: 0, output: 0, cacheRead: 0, cacheWrite: 0, dollars: 0, unpriced: 0 });
const add = (total: Total, call: Call) => {
  const dollars = costOf(call);
  total.calls += 1;
  total.input += call.usage.input;
  total.output += call.usage.output;
  total.cacheRead += call.usage.cacheRead;
  total.cacheWrite += call.usage.cacheWrite;
  if (dollars === undefined) total.unpriced += 1;
  else total.dollars += dollars;
};

const byPlayer = new Map<string, Total>();
const byMatch = new Map<string, Total>();
const byModel = new Map<string, Total>();
const tally = (totals: Map<string, Total>, key: string, call: Call) => {
  if (!totals.has(key)) totals.set(key, emptyTotal());
  add(totals.get(key)!, call);
};

for (const dir of roots.flatMap(matchDirs)) {
  for (const call of callsOf(dir)) {
    tally(byPlayer, `${dir} player ${call.player} (${call.model})`, call);
    tally(byMatch, dir, call);
    tally(byModel, `${call.provider}/${call.model}`, call);
  }
}

const show = (title: string, totals: Map<string, Total>) => {
  console.log(`\n${title}`);
  for (const [key, total] of totals) {
    const dollars = total.unpriced === total.calls ? "no price" : `$${total.dollars.toFixed(4)}${total.unpriced > 0 ? ` (+${total.unpriced} unpriced calls)` : ""}`;
    console.log(`  ${key}: ${total.calls} calls, in ${total.input}, out ${total.output}, cache read ${total.cacheRead}, cache write ${total.cacheWrite}, ${dollars}`);
  }
};

console.log(`Prices: ${pricesPath} (${table.unit})`);
show("Per player", byPlayer);
show("Per match", byMatch);
show("Per model", byModel);
