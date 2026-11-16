import { parseArgs } from "node:util";

import { Effect } from "effect";

import { openArena } from "../src/arena-viewer/load.ts";
import { fittedRatings, gamesOfSeats } from "../src/arena-viewer/page/ratings.ts";
import { withPotShares } from "../src/arena-viewer/page/data.ts";
import { BOOTSTRAP_DRAWS } from "../src/arena/bootstrap.ts";
import { runMain } from "../src/script.ts";

// The luck-adjusted Round Elo gap of two configs, with the standard error the site's block bootstrap gives it:
// bun scripts/arena-gap.ts <db> --luck <luck db> --a "<model>|<effort>" --b "<model>|<effort>"  (a - b, prints JSON)

const options = { luck: { type: "string" }, a: { type: "string" }, b: { type: "string" } } as const;
const { values, positionals } = parseArgs({ allowPositionals: true, options });
const [dbPath] = positionals;

if (dbPath === undefined || values.luck === undefined || values.a === undefined || values.b === undefined) throw new Error("usage: bun scripts/arena-gap.ts <db> --luck <luck db> --a <model|effort> --b <model|effort>");

const { a, b } = values;

const program = openArena(dbPath, { luck: values.luck }).pipe(
  Effect.map((arena) => {
    const seats = withPotShares(arena.seats);
    const { ratings, draws } = fittedRatings(seats, arena.luck);
    const games = gamesOfSeats(seats, arena.luck);
    const point = new Map([...ratings].map(([key, { rating }]) => [key, rating]));
    const left = draws.get(a) ?? new Float64Array();
    const right = draws.get(b) ?? new Float64Array();
    const gaps = Array.from({ length: BOOTSTRAP_DRAWS }, (_, rep) => (left[rep] ?? Number.NaN) - (right[rep] ?? Number.NaN)).filter((gap) => !Number.isNaN(gap));
    const mean = gaps.reduce((sum, gap) => sum + gap, 0) / gaps.length;
    const se = Math.sqrt(gaps.reduce((sum, gap) => sum + (gap - mean) ** 2, 0) / (gaps.length - 1));
    const between = games.filter((game) => (game.a === a && game.b === b) || (game.a === b && game.b === a));
    const rounds = between.reduce((sum, game) => sum + (game.weight ?? 1), 0);

    return { a, b, ratingA: point.get(a), ratingB: point.get(b), gap: (point.get(a) ?? Number.NaN) - (point.get(b) ?? Number.NaN), se, matchesBetween: between.length, roundsBetween: rounds };
  }),
  Effect.scoped,
  Effect.tap((result) => Effect.sync(() => console.log(JSON.stringify(result)))),
  Effect.asVoid,
);

await runMain(program);
