import { Database } from "bun:sqlite";

import { decodeMoveRow, MISMATCHES, type Mismatch, mismatchesOf, MOVE_COLUMNS } from "../src/arena-viewer/regret.ts";

export interface Consistency {
  readonly rows: number;
  readonly undecodable: number;
  readonly mismatches: ReadonlyArray<readonly [Mismatch, number]>;
}

export const consistencyOf = (rows: Iterable<unknown>): Consistency => {
  const found: Array<Mismatch> = [];
  let total = 0;
  let undecodable = 0;

  for (const raw of rows) {
    total++;

    try {
      found.push(...mismatchesOf(decodeMoveRow(raw)));
    } catch {
      undecodable++;
    }
  }

  return { rows: total, undecodable, mismatches: MISMATCHES.map((mismatch) => [mismatch, found.filter((each) => each === mismatch).length]) };
};

if (import.meta.main) {
  const path = process.argv[2];

  if (path === undefined) {
    console.error("usage: bun scripts/arena-regret-consistency.ts <regret db>");
    process.exit(2);
  }

  const { rows, undecodable, mismatches } = consistencyOf(new Database(path, { readonly: true }).query(`select ${MOVE_COLUMNS} from regret where status = 'searched'`).iterate());

  console.log(JSON.stringify({ rows, undecodable, ...Object.fromEntries(mismatches) }, null, 2));

  if (undecodable > 0 || mismatches.some(([, count]) => count > 0)) process.exitCode = 1;
}
