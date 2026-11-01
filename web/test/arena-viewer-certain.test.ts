import { Database } from "bun:sqlite";
import { expect, test } from "bun:test";
import { mkdtempSync } from "node:fs";
import { tmpdir } from "node:os";
import { join } from "node:path";

import type { CertainMistakes, CertainRate } from "../src/arena-viewer/api.ts";
import { openCertain } from "../src/arena-viewer/certain.ts";
import { talliesOf } from "../src/arena-viewer/page/certain.ts";

const OPPORTUNITIES = [
  ["m1", 3, "A", "self_on_live", "mistake"],
  ["m1", 5, "A", "self_on_live", "mistake"],
  ["m1", 6, "A", "self_on_live", "not a mistake"],
  ["m1", 7, "B", "gave_up_guaranteed_win", "mistake"],
  ["m1", 8, "B", "hidden_health", "excluded"],
  ["m1", 9, "B", "gave_turn_away", "fact pattern"],
  ["m1", 10, "B", "gave_turn_away", "not a mistake"],
  ["partial", 1, "A", "self_on_live", "mistake"],
] as const;

const WRITTEN_RATES = [
  ["config", "opus", "high", "self_on_live", 2, 40, 0.01, 0.12],
  ["config", "opus", "low", "self_on_live", 0, 3, null, null],
  ["model", "opus", "", "self_on_live", 2, 43, 0.012, 0.11],
  ["all", "", "", "self_on_live", 2, 43, 0.012, 0.11],
] as const;

const opportunitiesFile = (): string => {
  const path = join(mkdtempSync(join(tmpdir(), "certain-")), "certain-mistakes.sqlite");
  const db = new Database(path);

  db.run("create table opportunities (match_id text, ordinal integer, player text, type text, outcome text, source text)");
  db.run("create table rates (scope text, model text, effort text, type text, chose integer, opportunities integer, lo real, hi real)");

  const insert = db.query("insert into opportunities values (?, ?, ?, ?, ?, 'public')");

  for (const row of OPPORTUNITIES) insert.run(...row);

  const insertRate = db.query("insert into rates values (?, ?, ?, ?, ?, ?, ?, ?)");

  for (const row of WRITTEN_RATES) insertRate.run(...row);

  db.close();

  return path;
};

const SEATS = new Map([
  ["m1|A", 0],
  ["m1|B", 1],
]);

test("the written rates are served as they are, with an interval only where the file has one", () => {
  const { summary } = openCertain(opportunitiesFile(), SEATS);

  expect(summary.rates.map(({ scope, model, effort, type, chose, opportunities, bounds }) => [scope, model, effort, type, chose, opportunities, bounds])).toEqual([
    ["all", "", "", "self_on_live", 2, 43, { lo: 0.012, hi: 0.11 }],
    ["config", "opus", "high", "self_on_live", 2, 40, { lo: 0.01, hi: 0.12 }],
    ["config", "opus", "low", "self_on_live", 0, 3, null],
    ["model", "opus", "", "self_on_live", 2, 43, { lo: 0.012, hi: 0.11 }],
  ]);
});

test("only certain mistakes are listed, each with its seat, type and decision, and a match's mistakes are found by its id", () => {
  const { summary, moves } = openCertain(opportunitiesFile(), SEATS);

  expect(summary.moveSeat.map((seat, move) => [seat, summary.moveType[move], summary.moveOrd[move]])).toEqual([
    [0, 0, 3],
    [0, 0, 5],
    [1, 1, 7],
  ]);
  expect([...moves("m1")]).toEqual([
    [3, "self_on_live"],
    [5, "self_on_live"],
    [7, "gave_up_guaranteed_win"],
  ]);
  expect(moves("partial").size).toBe(0);
});

type Written = readonly [CertainRate["scope"], string, string, CertainRate["type"], number, number, number | null];

const certainOf = (written: ReadonlyArray<Written>): CertainMistakes => ({
  rates: written.map(([scope, model, effort, type, chose, opportunities, hi]) => ({ scope, model, effort, type, chose, opportunities, bounds: hi === null ? null : { lo: 0, hi } })),
  moveSeat: [],
  moveType: [],
  moveOrd: [],
});

const WRITTEN: ReadonlyArray<Written> = [
  ["config", "claude-opus-5-5", "off", "self_on_live", 1, 3, null],
  ["config", "claude-opus-5-5", "max", "self_on_live", 0, 40, 0.07],
  ["config", "gpt-6-luna", "low", "self_on_live", 5, 25, 0.4],
  ["config", "gpt-6-luna", "low", "gave_turn_away", 11, 50, null],
  ["config", "gpt-6-luna", "low", "hidden_health", 0, 7, null],
  ["model", "claude-opus-5-5", "", "self_on_live", 1, 43, 0.06],
  ["model", "gpt-6-luna", "", "self_on_live", 5, 25, 0.4],
  ["all", "", "", "self_on_live", 6, 68, 0.2],
];

const CONFIGS = [
  { model: "gpt-6-luna", effort: "low" },
  { model: "claude-opus-5-5", effort: "max" },
  { model: "claude-opus-5-5", effort: "off" },
];

const seatsOver = (blocks: number) => CONFIGS.flatMap((config) => Array.from({ length: blocks }, (_, block) => ({ ...config, seedBlock: `block${block}`, status: "completed" as const })));

const SEATS_OF_CONFIGS = seatsOver(4);

const keepConfigs = (configs: ReadonlyArray<boolean>, blocks = 4) => CONFIGS.flatMap((_, at) => Array.from({ length: blocks }, () => configs[at] === true));

test("each config shows its written counts and interval, strongest model and lowest effort first", () => {
  const { rows, pooled } = talliesOf(certainOf(WRITTEN), SEATS_OF_CONFIGS, keepConfigs([true, true, true]));

  expect(rows.map(({ model, effort }) => `${model} ${effort}`)).toEqual(["claude-opus-5-5 off", "claude-opus-5-5 max", "gpt-6-luna low"]);
  expect(rows.map(({ cells }) => [cells[0]?.mistakes, cells[0]?.opportunities, cells[0]?.bounds?.hi ?? null])).toEqual([
    [1, 3, null],
    [0, 40, 0.07],
    [5, 25, 0.4],
  ]);
  expect(pooled[0]).toMatchObject({ mistakes: 6, opportunities: 68, bounds: { hi: 0.2 } });
  expect(pooled[1]).toMatchObject({ mistakes: 0, opportunities: 0, bounds: null });
});

test("a filter that drops a config keeps the other rows' counts, and a pooled row loses the interval it no longer has", () => {
  const { rows, models, pooled } = talliesOf(certainOf(WRITTEN), SEATS_OF_CONFIGS, keepConfigs([false, true, true]));

  expect(rows.map(({ model }) => model)).toEqual(["claude-opus-5-5", "claude-opus-5-5"]);
  expect(models.map(({ model, cells }) => [model, cells[0]?.mistakes, cells[0]?.opportunities, cells[0]?.bounds?.hi])).toEqual([["claude-opus-5-5", 1, 43, 0.06]]);
  expect(pooled[0]).toMatchObject({ mistakes: 1, opportunities: 43, bounds: null });
});

test("a model with some of its configs dropped has counts and no interval", () => {
  const { models, pooled } = talliesOf(certainOf(WRITTEN), SEATS_OF_CONFIGS, keepConfigs([true, true, false]));

  expect(models.map(({ model, cells }) => [model, cells[0]?.mistakes, cells[0]?.opportunities, cells[0]?.bounds])).toEqual([
    ["claude-opus-5-5", 0, 40, null],
    ["gpt-6-luna", 5, 25, { lo: 0, hi: 0.4 }],
  ]);
  expect(pooled[0]).toMatchObject({ mistakes: 5, opportunities: 65, bounds: null });
});

test("proven blanks that gave the turn away, and decisions a jammed opponent hid, are tallied apart from the certain mistakes", () => {
  const { provenBlanks, hiddenHealth } = talliesOf(certainOf(WRITTEN), SEATS_OF_CONFIGS, keepConfigs([true, true, true]));

  expect(provenBlanks).toEqual({ gaveTurnAway: 11, total: 50 });
  expect(hiddenHealth).toBe(7);
});

test("a config, model or pool over fewer than 4 seed blocks has counts and no interval", () => {
  const { rows, models, pooled } = talliesOf(certainOf(WRITTEN), seatsOver(3), keepConfigs([true, true, true], 3));

  expect(rows.map(({ cells }) => [cells[0]?.opportunities, cells[0]?.bounds])).toEqual([[3, null], [40, null], [25, null]]);
  expect(models.map(({ cells }) => cells[0]?.bounds)).toEqual([null, null]);
  expect(pooled[0]).toMatchObject({ opportunities: 68, bounds: null });
});
