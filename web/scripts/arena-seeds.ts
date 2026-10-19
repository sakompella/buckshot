import { Schema } from "effect";

import { SeatCount } from "../src/domain.ts";
import { balancedSeeds, firstPositionOf } from "../src/arena/seeds.ts";

// Prints block seeds whose round 1 starts each position equally often, for a
// pairing's "seeds" in a tournament config, with the position each starts.
// --keep lists seeds that must come first, such as blocks already played.
// Usage: bun scripts/arena-seeds.ts --table 2 --blocks 10 --from 3010 [--keep 3000,3001]

const args = process.argv.slice(2);

const flag = (name: string): string | undefined => {
  const at = args.indexOf(`--${name}`);

  return at === -1 ? undefined : args[at + 1];
};

const table = Number(flag("table") ?? "2");

const blocks = Number(flag("blocks") ?? "10");

const from = Number(flag("from") ?? "0");

const keep = (flag("keep") ?? "").split(",").filter((seed) => seed !== "").map(Number);

if (!Schema.is(SeatCount)(table) || !Number.isInteger(blocks) || blocks < 1 || !Number.isInteger(from) || keep.some((seed) => !Number.isInteger(seed))) {
  console.error("Usage: bun scripts/arena-seeds.ts --table 2|3|4 --blocks N --from SEED [--keep SEED,SEED]");
  process.exit(1);
}

const seeds = balancedSeeds(table, blocks, from, keep);

console.log(JSON.stringify(seeds));

console.log(seeds.map((seed) => `${seed}: position ${firstPositionOf(seed, table)} starts`).join("\n"));
