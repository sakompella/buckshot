import { Database } from "bun:sqlite";
import { Effect } from "effect";

import { decodeMoveRow, MISMATCHES, type Mismatch, mismatchesOf, MOVE_COLUMNS } from "../src/arena-viewer/regret.ts";
import { runMain, ScriptError } from "../src/script.ts";

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

const program = Effect.gen(function* () {
  const path = process.argv[2];

  if (path === undefined) return yield* Effect.fail(new ScriptError({ message: "usage: bun scripts/arena-regret-consistency.ts <regret db>", exitCode: 2 }));

  const db = yield* Effect.acquireRelease(
    Effect.try({ try: () => new Database(path, { readonly: true }), catch: (cause) => new ScriptError({ message: `cannot open ${path}: ${String(cause)}`, exitCode: 1 }) }),
    (database) => Effect.sync(() => database.close()),
  );

  const { rows, undecodable, mismatches } = yield* Effect.sync(() => consistencyOf(db.query(`select ${MOVE_COLUMNS} from regret where status = 'searched'`).iterate()));

  console.log(JSON.stringify({ rows, undecodable, ...Object.fromEntries(mismatches) }, null, 2));

  return undecodable > 0 || mismatches.some(([, count]) => count > 0) ? 1 : 0;
}).pipe(Effect.scoped);

if (import.meta.main) await runMain(program);
