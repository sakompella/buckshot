import { resolve } from "node:path";
import { parseArgs } from "node:util";

import { Database } from "bun:sqlite";
import { Effect, Schema } from "effect";

import { mulberry32 } from "../src/arena/tournament-stats.ts";
import type { Item } from "../src/domain.ts";
import { decodeArgs, runMain, ScriptError } from "../src/script.ts";
import { itemName } from "../src/text.ts";


// Tables for docs/arena/analysis/beliefs-and-items.md from the database that
// scripts/arena-knowledge.ts writes. Only completed matches and the agents' own
// moves count; forced grabs and fallback moves do not. Excluded matches (a
// DeepSeek seat, matches.disposition) are left out, their opponents' moves
// too. Every rate is numerator/denominator with a 95% interval from resampling seed blocks
// (matches.seed_block_id) within the row's cohort, never single matches. A cohort is
// one kind of comparison pooled over every tournament: all cross-model matches, or
// all of one model's matches against itself. It comes from each match's players.
//
//   bun scripts/arena-knowledge-report.ts --db <knowledge.sqlite> [--draws 2000]

const USAGE = "Usage: bun scripts/arena-knowledge-report.ts --db <knowledge.sqlite> [--draws 2000]";

const DEFAULT_DRAWS = 2000;

const Args = Schema.Struct({ db: Schema.String, draws: Schema.optional(Schema.NumberFromString.check(Schema.isInt(), Schema.isGreaterThanOrEqualTo(1))) });

const decodeLabels = Schema.decodeUnknownSync(Schema.fromJsonString(Schema.Array(Schema.String)));

const openReadOnly = (path: string) =>
  Effect.acquireRelease(
    Effect.try({ try: () => new Database(resolve(path), { readonly: true }), catch: (cause) => new ScriptError({ message: `cannot open ${path}: ${String(cause)}`, exitCode: 1 }) }),
    (database) => Effect.sync(() => database.close()),
  );

/** Prints every table of the report, reading `db`; each rate resamples seed blocks `draws` times. */
const report = (db: Database, draws: number): void => {
  const cohortByMatch: ReadonlyMap<string, string> = new Map(db.query<{ match_id: string; kind: string }, []>(`SELECT match_id, kind FROM matches WHERE disposition IS NULL`).all().map(({ match_id, kind }) => [match_id, kind]));

  const cohortOf = (matchId: string): string => cohortByMatch.get(matchId) ?? "";

  const COHORTS = ["Cross-model", ...[...new Set(cohortByMatch.values())].filter((cohort) => cohort !== "Cross-model").toSorted()];

  const ITEMS: ReadonlyArray<Item> = ["Glass", "Phone", "Saw", "Beer", "Inverter", "Cigarettes", "Jammer", "Adrenaline"];

  /** Items an owner can use or a thief can take: every item but adrenaline itself. */
  const TARGETS = ITEMS.filter((item) => item !== "Adrenaline");

  interface Decision {
    readonly match_id: string;
    readonly ordinal: number;
    readonly cohort: string;
    readonly code_hash: string;
    readonly block: string;
    readonly model: string;
    readonly choice: string;
    readonly chamber: string | null;
    readonly remaining: number;
    readonly source: string | null;
    readonly via: number | null;
    readonly since: number | null;
    readonly shot: string | null;
    readonly item: string | null;
    readonly stolen: number | null;
    readonly legalItems: ReadonlyArray<string>;
    readonly ownItems: ReadonlyArray<string>;
    readonly exact_key: string;
    readonly belief_key: string;
  }

  type DecisionRow = Omit<Decision, "cohort" | "legalItems" | "ownItems"> & { readonly legal_items_json: string; readonly own_items_json: string };

  const labelsOf = (row: Pick<DecisionRow, "match_id" | "ordinal">, column: string, json: string): ReadonlyArray<string> => {
    try {
      return decodeLabels(json);
    } catch (error) {
      throw new Error(`decision ${row.match_id} #${row.ordinal}: bad ${column}`, { cause: error });
    }
  };

  const decisions = db
    .query<DecisionRow, []>(
      `SELECT d.match_id, d.ordinal, m.code_hash, m.seed_block_id AS block, p.model || ' ' || p.effort AS model, d.choice, d.chamber, d.remaining, d.source,
         d.clue_via_adrenaline AS via, d.moves_since_clue AS since, d.shot, d.item, d.item_stolen AS stolen, d.legal_items_json, d.own_items_json, d.exact_key, d.belief_key
       FROM decisions d JOIN matches m ON m.match_id = d.match_id JOIN players p ON p.match_id = d.match_id AND p.player = d.player
       WHERE m.status = 'completed' AND m.disposition IS NULL AND d.by_whom = 'agent'`,
    )
    .all()
    .map(({ legal_items_json, own_items_json, ...row }) => ({ ...row, legalItems: labelsOf(row, "legal_items_json", legal_items_json), ownItems: labelsOf(row, "own_items_json", own_items_json), cohort: cohortOf(row.match_id) }));

  interface ItemRow {
    readonly match_id: string;
    readonly cohort: string;
    readonly block: string;
    readonly model: string;
    readonly item: string;
    readonly end: string;
    readonly moves_held: number;
    readonly own_decisions_held: number;
  }

  const items = db
    .query<Omit<ItemRow, "cohort">, []>(
      `SELECT i.match_id, m.seed_block_id AS block, p.model || ' ' || p.effort AS model, i.item, i.end, i.moves_held, i.own_decisions_held
       FROM items i JOIN matches m ON m.match_id = i.match_id JOIN players p ON p.match_id = i.match_id AND p.player = i.player WHERE m.status = 'completed' AND m.disposition IS NULL`,
    )
    .all()
    .map((row) => ({ ...row, cohort: cohortOf(row.match_id) }));

  interface DeathRow {
    readonly match_id: string;
    readonly cohort: string;
    readonly block: string;
    readonly model: string;
    readonly items_held: number;
  }

  const deaths = db
    .query<Omit<DeathRow, "cohort">, []>(
      `SELECT x.match_id, m.seed_block_id AS block, p.model || ' ' || p.effort AS model, x.items_held
       FROM deaths x JOIN matches m ON m.match_id = x.match_id JOIN players p ON p.match_id = x.match_id AND p.player = x.player WHERE m.status = 'completed' AND m.disposition IS NULL`,
    )
    .all()
    .map((row) => ({ ...row, cohort: cohortOf(row.match_id) }));

  // Statistics
  // ==========

  /** Seed-block multiplicities for each bootstrap draw: the blocks drawn with replacement, as many as there are. */
  const resamples = (blocks: ReadonlyArray<string>, label: string): ReadonlyArray<ReadonlyMap<string, number>> => {
    const unique = [...new Set(blocks)].toSorted();
    const random = mulberry32([...label].reduce((hash, character) => Math.imul(hash ^ character.charCodeAt(0), 16777619), 2166136261));

    return Array.from({ length: draws }, () => {
      const weights = new Map<string, number>();

      for (let index = 0; index < unique.length; index++) {
        const block = unique[Math.floor(random() * unique.length)] ?? "";
        weights.set(block, (weights.get(block) ?? 0) + 1);
      }

      return weights;
    });
  };

  const percentile = (sorted: ReadonlyArray<number>, share: number): number => sorted[Math.min(sorted.length - 1, Math.max(0, Math.round(share * (sorted.length - 1))))] ?? Number.NaN;

  interface Rate {
    readonly numerator: number;
    readonly denominator: number;
    readonly low: number;
    readonly high: number;
  }

  /** A ratio of sums over observations, each with its block, numerator and denominator, and its seed-block bootstrap interval. */
  const rateOf = (rows: ReadonlyArray<readonly [string, number, number]>, label: string): Rate => {
    const numerator = rows.reduce((sum, [, value]) => sum + value, 0);
    const denominator = rows.reduce((sum, [, , value]) => sum + value, 0);
    const byBlock = new Map<string, readonly [number, number]>();

    for (const [block, top, bottom] of rows) {
      const [sumTop, sumBottom] = byBlock.get(block) ?? [0, 0];
      byBlock.set(block, [sumTop + top, sumBottom + bottom]);
    }

    const draws = resamples([...byBlock.keys()], label).flatMap((weights) => {
      let top = 0;
      let bottom = 0;

      for (const [block, weight] of weights) {
        const [blockTop, blockBottom] = byBlock.get(block) ?? [0, 0];
        top += weight * blockTop;
        bottom += weight * blockBottom;
      }

      return bottom > 0 ? [top / bottom] : [];
    });

    const sorted = draws.toSorted((left, right) => left - right);

    return { numerator, denominator, low: percentile(sorted, 0.025), high: percentile(sorted, 0.975) };
  };

  const percent = (value: number): string => (Number.isNaN(value) ? "–" : `${(100 * value).toFixed(value > 0 && value < 0.1 ? 1 : 0)}%`);

  const show = (rate: Rate): string => (rate.denominator === 0 ? "–" : `${percent(rate.numerator / rate.denominator)} (${rate.numerator}/${rate.denominator}) [${percent(rate.low)}, ${percent(rate.high)}]`);

  const median = (values: ReadonlyArray<number>): string => {
    const sorted = values.toSorted((left, right) => left - right);

    return sorted.length === 0 ? "–" : String(percentile(sorted, 0.5));
  };

  const table = (header: ReadonlyArray<string>, rows: ReadonlyArray<ReadonlyArray<string>>): string =>
    [`| ${header.join(" | ")} |`, `|${header.map(() => "---").join("|")}|`, ...rows.map((row) => `| ${row.join(" | ")} |`)].join("\n");

  const modelsIn = (cohort: string): ReadonlyArray<string> => [...new Set(decisions.filter((row) => row.cohort === cohort).map((row) => row.model))].toSorted();

  const flag = (condition: boolean): number => (condition ? 1 : 0);

  const print = (text: string): void => {
    console.log(`${text}\n`);
  };

  // Coverage
  // ========

  print("## Coverage");

  print(
    table(
      ["Cohort", "Matches", "Seed blocks", "Agent decisions", "Shots", "Shots with a certain chamber", "Code versions"],
      COHORTS.map((cohort) => {
        const rows = decisions.filter((row) => row.cohort === cohort);

        return [
          cohort,
          String(new Set(rows.map((row) => row.match_id)).size),
          String(new Set(rows.map((row) => row.block)).size),
          String(rows.length),
          String(rows.filter((row) => row.shot !== null).length),
          String(rows.filter((row) => row.shot !== null && row.chamber !== null).length),
          [...new Set(rows.map((row) => row.code_hash))].toSorted().join(", "),
        ];
      }),
    ),
  );

  // 2. Information retention
  // ========================

  const certainShots = decisions.filter((row) => row.shot !== null && row.chamber !== null);

  /** Shots against the known shell: the opponent on a known blank, yourself on a known live. */
  const against = (row: Decision): boolean => (row.chamber === "Blank" && row.shot === "opponent") || (row.chamber === "Live" && row.shot === "self");

  print("## Shots with a certain chamber");

  print(
    "Shooting the opponent on a known blank and yourself on a known live. Certainty is the player's own: the public log, its own clues, or both. In the replays a blank shot at yourself always kept the move, also across a reload, and a blank shot at the opponent always passed it, so the blank columns split the gun's last shell from the rest.",
  );

  for (const cohort of COHORTS) {
    print(`### ${cohort}`);
    print(
      table(
        ["Model", "Opponent on known blank, not the last shell", "Opponent on known blank, last shell", "Self on known live"],
        modelsIn(cohort).map((model) => {
          const rows = certainShots.filter((row) => row.cohort === cohort && row.model === model);
          const blank = (last: boolean) => rows.flatMap((row): ReadonlyArray<readonly [string, number, number]> => (row.chamber === "Blank" && (row.remaining === 1) === last ? [[row.block, flag(row.shot === "opponent"), 1]] : []));

          return [
            model,
            show(rateOf(blank(false), `${cohort}|${model}|blank`)),
            show(rateOf(blank(true), `${cohort}|${model}|last blank`)),
            show(rateOf(rows.flatMap((row): ReadonlyArray<readonly [string, number, number]> => (row.chamber === "Live" ? [[row.block, flag(row.shot === "self"), 1]] : [])), `${cohort}|${model}|live`)),
          ];
        }),
      ),
    );
  }

  const SOURCES = ["public", "glass", "phone", "combined"];

  print("## By where the certainty came from");

  print("Shots against the known shell, by source. A clue taken with adrenaline counts with its item.");

  print(
    table(
      ["Cohort", ...SOURCES],
      COHORTS.map((cohort) => [cohort, ...SOURCES.map((source) => show(rateOf(certainShots.filter((row) => row.cohort === cohort && row.source === source).map((row) => [row.block, flag(against(row)), 1]), `${cohort}|${source}`)))]),
    ),
  );

  for (const cohort of COHORTS) {
    print(`### ${cohort}, glass and phone by model`);
    print(
      table(
        ["Model", "glass", "phone"],
        modelsIn(cohort).map((model) => [
          model,
          ...["glass", "phone"].map((source) => show(rateOf(certainShots.filter((row) => row.cohort === cohort && row.model === model && row.source === source).map((row) => [row.block, flag(against(row)), 1]), `${cohort}|${model}|${source}`))),
        ]),
      ),
    );
  }

  const BINS: ReadonlyArray<readonly [string, (moves: number) => boolean]> = [
    ["0", (moves) => moves === 0],
    ["1", (moves) => moves === 1],
    ["2–3", (moves) => moves >= 2 && moves <= 3],
    ["4+", (moves) => moves >= 4],
  ];

  print("## By accepted moves since the clue");

  print("Shots against a chamber known from a clue (glass or phone), by the accepted moves of either player between the clue and the shot. 0 is the very next move.");

  for (const source of ["glass", "phone"]) {
    print(`### ${source}`);
    print(
      table(
        ["Cohort", ...BINS.map(([name]) => name)],
        COHORTS.map((cohort) => [
          cohort,
          ...BINS.map(([name, holds]) => show(rateOf(certainShots.filter((row) => row.cohort === cohort && row.source === source && row.since !== null && holds(row.since)).map((row) => [row.block, flag(against(row)), 1]), `${cohort}|${source}|${name}`))),
        ]),
      ),
    );
  }

  print("## How shots are informed");

  print("Each agent shot by what the player knew of the chamber: a clue from its own item (glass, phone or both), the public count, or nothing. The last column is blind shots taken while the player held a magnifying glass.");

  for (const cohort of COHORTS) {
    print(`### ${cohort}`);
    print(
      table(
        ["Model", "Known from a clue", "Known from the count", "Unknown", "Blind with a glass in hand"],
        modelsIn(cohort).map((model) => {
          const shots = decisions.filter((row) => row.cohort === cohort && row.model === model && row.shot !== null);
          const blind = shots.filter((row) => row.chamber === null);

          return [
            model,
            show(rateOf(shots.map((row) => [row.block, flag(row.source === "glass" || row.source === "phone" || row.source === "combined"), 1]), `${cohort}|${model}|clue`)),
            show(rateOf(shots.map((row) => [row.block, flag(row.source === "public"), 1]), `${cohort}|${model}|count`)),
            show(rateOf(shots.map((row) => [row.block, flag(row.chamber === null), 1]), `${cohort}|${model}|unknown`)),
            show(rateOf(blind.map((row) => [row.block, flag(row.ownItems.includes("Glass")), 1]), `${cohort}|${model}|glass in hand`)),
          ];
        }),
      ),
    );
  }

  // 3. Item flow
  // ============

  print("## Item fates");

  print("Each item a player placed, by how it left: used by its owner, stolen with adrenaline, still held when the owner died, or still held when the round ended (censored). Delays count only items used by their owner. Own turns are the owner's own decisions between placing the item and using it, so 0 is the first decision after the distribution.");

  for (const cohort of COHORTS) {
    print(`### ${cohort}`);
    print(
      table(
        ["Model", "Used", "Stolen", "Held at death", "Held at round end", "Own turns held before use, mean (median)", "Accepted moves to use, median"],
        modelsIn(cohort).map((model) => {
          const rows = items.filter((row) => row.cohort === cohort && row.model === model);
          const used = rows.filter((row) => row.end === "used");
          const ends = (end: (value: string) => boolean, name: string) => show(rateOf(rows.map((row) => [row.block, flag(end(row.end)), 1]), `${cohort}|${model}|${name}`));

          return [
            model,
            ends((end) => end === "used", "used"),
            ends((end) => end === "stolen", "stolen"),
            ends((end) => end === "died", "died"),
            ends((end) => end === "round end" || end === "match end", "censored"),
            used.length === 0 ? "–" : `${(used.reduce((sum, row) => sum + row.own_decisions_held, 0) / used.length).toFixed(2)} (${median(used.map((row) => row.own_decisions_held))})`,
            median(used.map((row) => row.moves_held)),
          ];
        }),
      ),
    );
  }

  const useWhenLegal = (rows: ReadonlyArray<Decision>, option: string, label: string): Rate =>
    rateOf(
      rows.flatMap((row): ReadonlyArray<readonly [string, number, number]> =>
        row.legalItems.includes(option) ? [[row.block, flag(row.item !== null && `${row.stolen === 1 ? "steal " : ""}${row.item}` === option), 1]] : [],
      ),
      label,
    );

  print("## Use when legal");

  print("Agent decisions where using an own item is a legal move, and the share that use it. A player holding two of an item counts once per decision.");

  for (const cohort of COHORTS) {
    print(`### ${cohort}`);
    print(table(["Model", ...TARGETS.map(itemName)], modelsIn(cohort).map((model) => [model, ...TARGETS.map((item) => show(useWhenLegal(decisions.filter((row) => row.cohort === cohort && row.model === model), item, `${cohort}|${model}|use ${item}`)))])));
  }

  print("## Adrenaline steals when legal");

  print("Agent decisions where stealing an item with adrenaline is legal, and the share that steal it. These are separate from the player's own items.");

  for (const cohort of COHORTS) {
    print(`### ${cohort}`);
    print(table(["Model", ...TARGETS.map(itemName)], modelsIn(cohort).map((model) => [model, ...TARGETS.map((item) => show(useWhenLegal(decisions.filter((row) => row.cohort === cohort && row.model === model), `steal ${item}`, `${cohort}|${model}|steal ${item}`)))])));
  }

  print("## Item fates by item");

  print("Share of placed items used by their owner, by item. Adrenaline counts as used when its owner steals with it.");

  for (const cohort of COHORTS) {
    print(`### ${cohort}`);
    print(table(["Model", ...ITEMS.map(itemName)], modelsIn(cohort).map((model) => [model, ...ITEMS.map((item) => show(rateOf(items.filter((row) => row.cohort === cohort && row.model === model && row.item === item).map((row) => [row.block, flag(row.end === "used"), 1]), `${cohort}|${model}|fate ${item}`)))])));
  }

  print("## Items held at elimination");

  print("Deaths, the share with at least one unused item, and the items held per death.");

  for (const cohort of COHORTS) {
    print(`### ${cohort}`);
    print(
      table(
        ["Model", "Deaths with an item held", "Items held per death", "Items held at death, most common"],
        modelsIn(cohort).map((model) => {
          const rows = deaths.filter((row) => row.cohort === cohort && row.model === model);
          const held = items.filter((row) => row.cohort === cohort && row.model === model && row.end === "died");
          const counts = ITEMS.map((item) => [item, held.filter((row) => row.item === item).length] as const).toSorted((left, right) => right[1] - left[1]).slice(0, 3);
          const perDeath = rateOf(rows.map((row) => [row.block, row.items_held, 1]), `${cohort}|${model}|held per death`);

          return [
            model,
            show(rateOf(rows.map((row) => [row.block, flag(row.items_held > 0), 1]), `${cohort}|${model}|held at death`)),
            rows.length === 0 ? "–" : `${(perDeath.numerator / perDeath.denominator).toFixed(2)} (${perDeath.numerator}/${perDeath.denominator}) [${perDeath.low.toFixed(2)}, ${perDeath.high.toFixed(2)}]`,
            counts.flatMap(([item, count]) => (count > 0 ? [`${itemName(item)} ${count}`] : [])).join(", ") || "–",
          ];
        }),
      ),
    );
  }

  // 4. Same-position consistency
  // ============================

  type Key = "exact_key" | "belief_key";

  /** Decisions grouped by position: key to block to choice counts. */
  const groupsOf = (rows: ReadonlyArray<Decision>, key: Key): ReadonlyMap<string, ReadonlyArray<Decision>> => {
    const groups = new Map<string, Array<Decision>>();

    for (const row of rows) groups.set(row[key], [...(groups.get(row[key]) ?? []), row]);

    return groups;
  };

  type Weights = ReadonlyMap<string, number> | undefined;

  const weightOf = (row: Decision, weights: Weights): number => (weights === undefined ? 1 : (weights.get(row.block) ?? 0));

  /**
   * The chance two different decisions of one position agree. A pair of distinct decisions weighs the product of their blocks'
   * bootstrap multiplicities and a decision never pairs with its own copy, so a block drawn twice cannot manufacture agreement.
   * None when fewer than two decisions are drawn.
   */
  const pairAgreement = (group: ReadonlyArray<Decision>, weights: Weights): number | undefined => {
    const byChoice = new Map<string, readonly [number, number]>();

    for (const row of group) {
      const weight = weightOf(row, weights);
      const [sum, squares] = byChoice.get(row.choice) ?? [0, 0];
      byChoice.set(row.choice, [sum + weight, squares + weight * weight]);
    }

    let agreeing = 0;
    let total = 0;
    let squares = 0;

    for (const [sum, square] of byChoice.values()) {
      agreeing += sum * sum - square;
      total += sum;
      squares += square;
    }

    const pairs = total * total - squares;

    return pairs > 0 ? agreeing / pairs : undefined;
  };

  /** A per-position statistic summed over the positions where it is defined, and the count of those positions. */
  const overPositions = (groups: Iterable<ReadonlyArray<Decision>>, statistic: (group: ReadonlyArray<Decision>) => number | undefined): readonly [number, number] => {
    let sum = 0;
    let positions = 0;

    for (const group of groups) {
      const value = statistic(group);

      if (value === undefined) continue;

      sum += value;
      positions++;
    }

    return [sum, positions];
  };

  /** A mean over positions, with its seed-block bootstrap interval. */
  const interval = (rows: ReadonlyArray<Decision>, label: string, statistic: (weights: Weights) => readonly [number, number]): string => {
    const [value, positions] = statistic(undefined);

    const draws = resamples(rows.map((row) => row.block), label)
      .flatMap((weights) => {
        const [drawValue, drawPositions] = statistic(weights);

        return drawPositions > 0 ? [drawValue / drawPositions] : [];
      })
      .toSorted((left, right) => left - right);

    return positions === 0 ? "–" : `${percent(value / positions)} over ${positions} positions [${percent(percentile(draws, 0.025))}, ${percent(percentile(draws, 0.975))}]`;
  };

  print("## Same-position consistency");

  print(
    "Agent decisions grouped by the deciding player's own position. Exact: the same board, cash and round, the same log since the load, the same legal moves, code and instructions. Belief: the same board, load shown, cash, round, legal moves and versions, the same public and private shell beliefs, and the same count of clue items each opponent used this load. Players are named relative to the decider. Coverage is the share of decisions in a position seen at least twice. Non-modal is the share of those decisions that differ from their position's most common choice; it has no interval, because resampling blocks duplicates decisions and a copy always matches the mode. Two differ is the chance two different decisions in a position differ, averaged over positions, with an interval over pairs of distinct decisions.",
  );

  for (const key of ["exact_key", "belief_key"] as const) {
    print(`### ${key === "exact_key" ? "Exact" : "Belief"} positions`);
    print(
      table(
        ["Cohort", "Model", "Positions seen twice or more", "Coverage", "Non-modal choices", "Two differ"],
        COHORTS.flatMap((cohort) =>
          modelsIn(cohort).map((model) => {
            const rows = decisions.filter((row) => row.cohort === cohort && row.model === model);
            const groups = [...groupsOf(rows, key).values()].filter((group) => group.length >= 2);
            const grouped = groups.reduce((sum, group) => sum + group.length, 0);
            const modal = groups.reduce((sum, group) => sum + Math.max(...[...new Set(group.map((row) => row.choice))].map((choice) => group.filter((row) => row.choice === choice).length)), 0);

            const differ = interval(rows, `${cohort}|${model}|${key}`, (weights) =>
              overPositions(groups, (group) => {
                const agree = pairAgreement(group, weights);

                return agree === undefined ? undefined : 1 - agree;
              }),
            );

            return [cohort, model, String(groups.length), `${percent(grouped / rows.length)} (${grouped}/${rows.length})`, grouped === 0 ? "–" : `${percent((grouped - modal) / grouped)} (${grouped - modal}/${grouped})`, differ];
          }),
        ),
      ),
    );
  }

  /** Agreement between two variants in the positions both met: the chance a random decision of each agrees, block-weighted. Decisions of two variants are never copies of each other. */
  const agreement = (left: ReadonlyMap<string, ReadonlyArray<Decision>>, right: ReadonlyMap<string, ReadonlyArray<Decision>>, weights: Weights): readonly [number, number] => {
    const distribution = (group: ReadonlyArray<Decision>) => {
      const counts = new Map<string, number>();
      let size = 0;

      for (const row of group) {
        const weight = weightOf(row, weights);
        size += weight;
        counts.set(row.choice, (counts.get(row.choice) ?? 0) + weight);
      }

      return { counts, size };
    };

    return overPositions(
      [...left.keys()].flatMap((key) => (right.has(key) ? [key] : [])).map((key) => [...(left.get(key) ?? []), ...(right.get(key) ?? [])]),
      (both) => {
        const one = distribution(both.filter((row) => row.model === both[0]?.model));
        const two = distribution(both.filter((row) => row.model !== both[0]?.model));

        if (one.size === 0 || two.size === 0) return undefined;

        return [...one.counts].reduce((sum, [choice, count]) => sum + (count / one.size) * ((two.counts.get(choice) ?? 0) / two.size), 0);
      },
    );
  };

  /** Self-agreement on the positions a variant shares with another: the chance two different decisions of the variant agree. */
  const selfAgreement = (groups: ReadonlyMap<string, ReadonlyArray<Decision>>, shared: ReadonlySet<string>, weights: Weights): readonly [number, number] =>
    overPositions(
      [...groups].flatMap(([key, group]) => (shared.has(key) ? [group] : [])),
      (group) => pairAgreement(group, weights),
    );

  print("## Agreement between effort variants");

  print(
    "For each pair of one model's effort levels in the same cohort, exact positions both met. Across: the chance a random decision of each variant agrees, averaged over shared positions. Within: for comparison, the chance two decisions of the same variant agree, over shared positions that variant met at least twice.",
  );

  const sweeps = COHORTS.flatMap((cohort) => {
    const rows = decisions.filter((row) => row.cohort === cohort);
    const baseModels = [...new Set(rows.map((row) => row.model.split(" ")[0] ?? ""))].toSorted();

    return baseModels.flatMap((base) => {
      const variants = [...new Set(rows.filter((row) => row.model.split(" ")[0] === base).map((row) => row.model))].toSorted();

      return variants.flatMap((left, index) => variants.slice(index + 1).map((right) => ({ cohort, left, right })));
    });
  });

  print(
    table(
      ["Cohort", "Variants", "Shared positions", "Across", "Within, first", "Within, second"],
      sweeps.map(({ cohort, left, right }) => {
        const leftRows = decisions.filter((row) => row.cohort === cohort && row.model === left);
        const rightRows = decisions.filter((row) => row.cohort === cohort && row.model === right);
        const leftGroups = groupsOf(leftRows, "exact_key");
        const rightGroups = groupsOf(rightRows, "exact_key");
        const shared = new Set([...leftGroups.keys()].filter((key) => rightGroups.has(key)));
        const both = [...leftRows, ...rightRows];
        const label = `${cohort}|${left}|${right}`;

        return [
          cohort,
          `${left} vs ${right}`,
          String(shared.size),
          interval(both, `${label}|across`, (weights) => agreement(leftGroups, rightGroups, weights)),
          interval(leftRows, `${label}|left`, (weights) => selfAgreement(leftGroups, shared, weights)),
          interval(rightRows, `${label}|right`, (weights) => selfAgreement(rightGroups, shared, weights)),
        ];
      }),
    ),
  );

  print("## Code versions");

  print("The main rates within each cohort by code version, pooled over models.");

  print(
    table(
      ["Cohort", "Code", "Against a known shell", "Shots known from a clue", "Matches"],
      COHORTS.flatMap((cohort) =>
        [...new Set(decisions.filter((row) => row.cohort === cohort).map((row) => row.code_hash))].toSorted().map((code) => {
          const rows = decisions.filter((row) => row.cohort === cohort && row.code_hash === code);
          const matchIds = new Set(rows.map((row) => row.match_id));
          const label = `${cohort}|${code}`;

          return [
            cohort,
            code,
            show(rateOf(rows.filter((row) => row.shot !== null && row.chamber !== null).map((row) => [row.block, flag(against(row)), 1]), `${label}|against`)),
            show(rateOf(rows.filter((row) => row.shot !== null).map((row) => [row.block, flag(row.source === "glass" || row.source === "phone" || row.source === "combined"), 1]), `${label}|clue`)),
            String(matchIds.size),
          ];
        }),
      ),
    ),
  );
};

const program = Effect.gen(function* () {
  const args = yield* Effect.try({ try: () => parseArgs({ args: process.argv.slice(2), options: { db: { type: "string" }, draws: { type: "string" } } }).values, catch: () => new ScriptError({ message: USAGE, exitCode: 1 }) });
  const { db: path, draws = DEFAULT_DRAWS } = yield* decodeArgs(Args, USAGE)(args);
  const db = yield* openReadOnly(path);

  yield* Effect.sync(() => report(db, draws));
}).pipe(Effect.scoped);

await runMain(program);
