import { readFileSync } from "node:fs";

import { Schema } from "effect";

import type { CallLine } from "./runlog.ts";

// Prices model calls from their logged usage and a price table (prices.json),
// so a new price only means reading the logs again.

const Rates = Schema.Struct({ input: Schema.Number, output: Schema.Number, cacheRead: Schema.Number, cacheWrite: Schema.Number });

const PriceTable = Schema.Struct({
  unit: Schema.String,
  models: Schema.Record(Schema.String, Schema.Struct({ ...Rates.fields, tiers: Schema.optional(Schema.Array(Schema.Struct({ ...Rates.fields, inputTokensAbove: Schema.Number }))), source: Schema.String })),
});

export type PriceTable = typeof PriceTable.Type;

export const DEFAULT_PRICES = new URL("./prices.json", import.meta.url).pathname;

export const loadPrices = (path: string): PriceTable => Schema.decodeUnknownSync(Schema.fromJsonString(PriceTable))(readFileSync(path, "utf8"));

/** The call's cost in dollars, or undefined when the table has no price for its model. */
export const costOf = (prices: PriceTable, call: CallLine): number | undefined => {
  const price = prices.models[call.model];

  if (price === undefined) return undefined;

  const prompt = call.usage.input + call.usage.cacheRead + call.usage.cacheWrite;
  const rates = price.tiers?.findLast((tier) => prompt > tier.inputTokensAbove) ?? price;

  return (call.usage.input * rates.input + call.usage.output * rates.output + call.usage.cacheRead * rates.cacheRead + call.usage.cacheWrite * rates.cacheWrite) / 1_000_000;
};

export const Total = Schema.Struct({
  calls: Schema.Number,
  input: Schema.Number,
  output: Schema.Number,
  cacheRead: Schema.Number,
  cacheWrite: Schema.Number,
  reasoning: Schema.Number,
  dollars: Schema.Number,
  unpriced: Schema.Number,
});

export type Total = typeof Total.Type;

export const EMPTY: Total = { calls: 0, input: 0, output: 0, cacheRead: 0, cacheWrite: 0, reasoning: 0, dollars: 0, unpriced: 0 };

const plus = (total: Total, dollars: number | undefined, call: CallLine): Total => ({
  calls: total.calls + 1,
  input: total.input + call.usage.input,
  output: total.output + call.usage.output,
  cacheRead: total.cacheRead + call.usage.cacheRead,
  cacheWrite: total.cacheWrite + call.usage.cacheWrite,
  reasoning: total.reasoning + (call.usage.reasoning ?? 0),
  dollars: total.dollars + (dollars ?? 0),
  unpriced: total.unpriced + (dollars === undefined ? 1 : 0),
});

export const totalOf = (prices: PriceTable, calls: ReadonlyArray<CallLine>): Total => calls.reduce((total, call) => plus(total, costOf(prices, call), call), EMPTY);

/** Totals per key, in the order each key first appears. */
export const totalsBy = <K extends string>(prices: PriceTable, keyed: ReadonlyArray<readonly [K, CallLine]>): ReadonlyMap<K, Total> => {
  const totals = new Map<K, Total>();

  for (const [key, call] of keyed) totals.set(key, plus(totals.get(key) ?? EMPTY, costOf(prices, call), call));

  return totals;
};
