import { existsSync, readdirSync, readFileSync } from "node:fs";
import { join } from "node:path";

import { Schema } from "effect";

import { type CallLine, readCalls } from "../src/arena/runlog.ts";

// Prices arena runs offline, from their calls.jsonl and a price table, so a new
// price only means running this again. Each argument is a match directory (it
// has calls.jsonl) or a directory of match directories, such as a tournament.
// Usage: bun scripts/arena-cost.ts <dir>... [--prices src/arena/prices.json]

const Rates = Schema.Struct({ input: Schema.Number, output: Schema.Number, cacheRead: Schema.Number, cacheWrite: Schema.Number });

const PriceTable = Schema.Struct({
  unit: Schema.String,
  models: Schema.Record(Schema.String, Schema.Struct({ ...Rates.fields, tiers: Schema.optional(Schema.Array(Schema.Struct({ ...Rates.fields, inputTokensAbove: Schema.Number }))), source: Schema.String })),
});

const pricesAt = process.argv.indexOf("--prices");

const pricesPath = pricesAt === -1 ? new URL("../src/arena/prices.json", import.meta.url).pathname : (process.argv[pricesAt + 1] ?? "");

const prices = Schema.decodeUnknownSync(Schema.fromJsonString(PriceTable))(readFileSync(pricesPath, "utf8"));

const roots = process.argv.slice(2).filter((arg, index, args) => arg !== "--prices" && args[index - 1] !== "--prices");

const matchDirs = (root: string): ReadonlyArray<string> =>
  existsSync(join(root, "calls.jsonl"))
    ? [root]
    : readdirSync(root, { withFileTypes: true }).flatMap((entry) => (entry.isDirectory() ? matchDirs(join(root, entry.name)) : []));

/** The call's cost in dollars, or undefined when the table has no price for its model. */
const costOf = (call: CallLine): number | undefined => {
  const price = prices.models[call.model];

  if (price === undefined) return undefined;

  const prompt = call.usage.input + call.usage.cacheRead + call.usage.cacheWrite;
  const rates = price.tiers?.findLast((tier) => prompt > tier.inputTokensAbove) ?? price;

  return (call.usage.input * rates.input + call.usage.output * rates.output + call.usage.cacheRead * rates.cacheRead + call.usage.cacheWrite * rates.cacheWrite) / 1_000_000;
};

interface Total {
  calls: number;
  input: number;
  output: number;
  cacheRead: number;
  cacheWrite: number;
  reasoning: number;
  dollars: number;
  unpriced: number;
}

const totals = { agentInMatch: new Map<string, Total>(), match: new Map<string, Total>(), agent: new Map<string, Total>(), model: new Map<string, Total>() };

const tally = (table: Map<string, Total>, key: string, call: CallLine) => {
  const total = table.get(key) ?? { calls: 0, input: 0, output: 0, cacheRead: 0, cacheWrite: 0, reasoning: 0, dollars: 0, unpriced: 0 };
  const dollars = costOf(call);

  total.calls += 1;
  total.input += call.usage.input;
  total.output += call.usage.output;
  total.cacheRead += call.usage.cacheRead;
  total.cacheWrite += call.usage.cacheWrite;
  total.reasoning += call.usage.reasoning ?? 0;
  total.dollars += dollars ?? 0;
  total.unpriced += dollars === undefined ? 1 : 0;
  table.set(key, total);
};

for (const dir of roots.flatMap(matchDirs)) {
  for (const call of readCalls(dir)) {
    tally(totals.agentInMatch, `${dir} agent ${call.agent} at position ${call.position} (${call.model})`, call);
    tally(totals.match, dir, call);
    tally(totals.agent, `agent ${call.agent} (${call.model})`, call);
    tally(totals.model, `${call.api}/${call.model}`, call);
  }
}

const show = (title: string, table: Map<string, Total>) => {
  console.log(`\n${title}`);

  for (const [key, total] of table) {
    const priced = total.unpriced === total.calls ? "no price" : `$${total.dollars.toFixed(4)}${total.unpriced > 0 ? ` (${total.unpriced} calls unpriced)` : ""}`;

    console.log(`  ${key}: ${total.calls} calls, in ${total.input}, out ${total.output} (reasoning ${total.reasoning}), cache read ${total.cacheRead}, cache write ${total.cacheWrite}, ${priced}`);
  }
};

console.log(`Prices: ${pricesPath} (${prices.unit})`);

show("Per agent in each match", totals.agentInMatch);

show("Per match", totals.match);

show("Per agent", totals.agent);

show("Per model", totals.model);
