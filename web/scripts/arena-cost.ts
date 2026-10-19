import { existsSync, readdirSync, readFileSync } from "node:fs";
import { join } from "node:path";

import { Schema } from "effect";

import { DEFAULT_PRICES, loadPrices, type Total, totalsBy } from "../src/arena/cost.ts";
import { effortName, modelName } from "../src/arena/model-names.ts";
import { readCalls } from "../src/arena/runlog.ts";

// Prices arena runs offline, from their calls.jsonl and a price table, so a new
// price only means running this again. Each argument is a match directory (it
// has manifest.json) or a directory of match directories, such as a tournament.
// Bots and humans make no model calls, so they are listed at no cost, beside
// the agents they played. Models print under their names (see
// src/arena/model-names.ts); an entrant is a model with the effort each match's
// manifest records for the agent, in brackets.
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

const Manifest = Schema.Struct({
  controllers: Schema.Array(Schema.String),
  provenance: Schema.optional(Schema.Struct({ agents: Schema.Record(Schema.String, Schema.Struct({ effort: Schema.optional(Schema.NullOr(Schema.String)) })) })),
});

const decodeManifest = Schema.decodeUnknownSync(Schema.fromJsonString(Manifest));

const manifests = new Map(dirs.map((dir) => [dir, decodeManifest(readFileSync(join(dir, "manifest.json"), "utf8"))] as const));

/** The effort an agent played a match at, as its manifest's provenance has it; older manifests have none. */
const effortOf = (dir: string, agent: string): string => {
  const effort = manifests.get(dir)?.provenance?.agents[agent]?.effort;

  return effort === undefined || effort === null ? "unset" : effortName(effort);
};

const calls = dirs.flatMap((dir) => readCalls(dir).map((call) => ({ dir, call, entrant: `${modelName(call.model)} [${effortOf(dir, call.agent)}]` })));

/** The bots and humans in each match. */
const others = dirs.flatMap((dir) => (manifests.get(dir)?.controllers ?? []).flatMap((controller, index) => (controller === "Agent" ? [] : [{ dir, controller, position: index + 1 }])));

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
    totalsBy(prices, calls.map(({ dir, call, entrant }) => [`${dir} agent ${call.agent} at position ${call.position} (${entrant})`, call])),
  ),
);

show("Per match", withFree(dirs, totalsBy(prices, calls.map(({ dir, call }) => [dir, call]))));

show("Per entrant", withFree(others.map(({ controller }) => controller), totalsBy(prices, calls.map(({ call, entrant }) => [entrant, call]))));

show("Per model", totalsBy(prices, calls.map(({ call }) => [`${modelName(call.model)} (${call.api}/${call.model})`, call])));
