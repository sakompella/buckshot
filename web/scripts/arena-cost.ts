import { existsSync, readdirSync, readFileSync } from "node:fs";
import { join } from "node:path";

import { Schema } from "effect";

import { DEFAULT_PRICES, loadPrices, type Total, totalsBy } from "../src/arena/cost.ts";
import { readCalls } from "../src/arena/runlog.ts";

// Prices arena runs offline, from their calls.jsonl and a price table, so a new
// price only means running this again. Each argument is a match directory (it
// has manifest.json) or a directory of match directories, such as a tournament.
// Bots and humans make no model calls, so they are listed at no cost, beside
// the agents they played.
// Usage: bun scripts/arena-cost.ts <dir>... [--prices src/arena/prices.json]

const pricesAt = process.argv.indexOf("--prices");

const pricesPath = pricesAt === -1 ? DEFAULT_PRICES : (process.argv[pricesAt + 1] ?? "");

const prices = loadPrices(pricesPath);

const roots = process.argv.slice(2).filter((arg, index, args) => arg !== "--prices" && args[index - 1] !== "--prices");

const matchDirs = (root: string): ReadonlyArray<string> =>
  existsSync(join(root, "manifest.json"))
    ? [root]
    : readdirSync(root, { withFileTypes: true }).flatMap((entry) => (entry.isDirectory() ? matchDirs(join(root, entry.name)) : []));

const dirs = roots.flatMap(matchDirs);

const calls = dirs.flatMap((dir) => readCalls(dir).map((call) => ({ dir, call })));

const decodeSeats = Schema.decodeUnknownSync(Schema.fromJsonString(Schema.Struct({ controllers: Schema.Array(Schema.String) })));

/** The bots and humans in each match. */
const others = dirs.flatMap((dir) =>
  decodeSeats(readFileSync(join(dir, "manifest.json"), "utf8")).controllers.flatMap((controller, index) => (controller === "Agent" ? [] : [{ dir, controller, position: index + 1 }])),
);

const FREE: Total = { calls: 0, input: 0, output: 0, cacheRead: 0, cacheWrite: 0, reasoning: 0, dollars: 0, unpriced: 0 };

/** A table with a row at no cost for each key it lacks. */
const withFree = (keys: ReadonlyArray<string>, table: ReadonlyMap<string, Total>): ReadonlyMap<string, Total> => new Map([...table, ...keys.flatMap((key) => (table.has(key) ? [] : [[key, FREE] as const]))]);

const show = (title: string, table: ReadonlyMap<string, Total>) => {
  console.log(`\n${title}`);

  for (const [key, total] of table) {
    const priced = total.calls > 0 && total.unpriced === total.calls ? "no price" : `$${total.dollars.toFixed(4)}${total.unpriced > 0 ? ` (${total.unpriced} calls unpriced)` : ""}`;

    console.log(`  ${key}: ${total.calls} calls, in ${total.input}, out ${total.output} (reasoning ${total.reasoning}), cache read ${total.cacheRead}, cache write ${total.cacheWrite}, ${priced}`);
  }
};

console.log(`Prices: ${pricesPath} (${prices.unit})`);

show(
  "Per entrant in each match",
  withFree(
    others.map(({ dir, controller, position }) => `${dir} ${controller} at position ${position}`),
    totalsBy(prices, calls.map(({ dir, call }) => [`${dir} agent ${call.agent} at position ${call.position} (${call.model})`, call])),
  ),
);

show("Per match", withFree(dirs, totalsBy(prices, calls.map(({ dir, call }) => [dir, call]))));

show("Per entrant", withFree(others.map(({ controller }) => controller), totalsBy(prices, calls.map(({ call }) => [`agent ${call.agent} (${call.model})`, call]))));

show("Per model", totalsBy(prices, calls.map(({ call }) => [`${call.api}/${call.model}`, call])));
