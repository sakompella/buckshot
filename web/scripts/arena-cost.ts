import { existsSync, readdirSync } from "node:fs";
import { join } from "node:path";

import { DEFAULT_PRICES, loadPrices, type Total, totalsBy } from "../src/arena/cost.ts";
import { readCalls } from "../src/arena/runlog.ts";

// Prices arena runs offline, from their calls.jsonl and a price table, so a new
// price only means running this again. Each argument is a match directory (it
// has calls.jsonl) or a directory of match directories, such as a tournament.
// Usage: bun scripts/arena-cost.ts <dir>... [--prices src/arena/prices.json]

const pricesAt = process.argv.indexOf("--prices");

const pricesPath = pricesAt === -1 ? DEFAULT_PRICES : (process.argv[pricesAt + 1] ?? "");

const prices = loadPrices(pricesPath);

const roots = process.argv.slice(2).filter((arg, index, args) => arg !== "--prices" && args[index - 1] !== "--prices");

const matchDirs = (root: string): ReadonlyArray<string> =>
  existsSync(join(root, "calls.jsonl"))
    ? [root]
    : readdirSync(root, { withFileTypes: true }).flatMap((entry) => (entry.isDirectory() ? matchDirs(join(root, entry.name)) : []));

const calls = roots.flatMap(matchDirs).flatMap((dir) => readCalls(dir).map((call) => ({ dir, call })));

const show = (title: string, table: ReadonlyMap<string, Total>) => {
  console.log(`\n${title}`);

  for (const [key, total] of table) {
    const priced = total.unpriced === total.calls ? "no price" : `$${total.dollars.toFixed(4)}${total.unpriced > 0 ? ` (${total.unpriced} calls unpriced)` : ""}`;

    console.log(`  ${key}: ${total.calls} calls, in ${total.input}, out ${total.output} (reasoning ${total.reasoning}), cache read ${total.cacheRead}, cache write ${total.cacheWrite}, ${priced}`);
  }
};

console.log(`Prices: ${pricesPath} (${prices.unit})`);

show("Per agent in each match", totalsBy(prices, calls.map(({ dir, call }) => [`${dir} agent ${call.agent} at position ${call.position} (${call.model})`, call])));

show("Per match", totalsBy(prices, calls.map(({ dir, call }) => [dir, call])));

show("Per agent", totalsBy(prices, calls.map(({ call }) => [`agent ${call.agent} (${call.model})`, call])));

show("Per model", totalsBy(prices, calls.map(({ call }) => [`${call.api}/${call.model}`, call])));
