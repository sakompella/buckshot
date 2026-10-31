import { Database } from "bun:sqlite";
import { expect, test } from "bun:test";
import { mkdtempSync } from "node:fs";
import { tmpdir } from "node:os";
import { join } from "node:path";

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

const opportunitiesFile = (): string => {
  const path = join(mkdtempSync(join(tmpdir(), "certain-")), "certain-mistakes.sqlite");
  const db = new Database(path);

  db.run("create table opportunities (match_id text, ordinal integer, player text, type text, outcome text, source text)");

  const insert = db.query("insert into opportunities values (?, ?, ?, ?, ?, 'public')");

  for (const row of OPPORTUNITIES) insert.run(...row);

  db.close();

  return path;
};

const SEATS = new Map([
  ["m1|A", 0],
  ["m1|B", 1],
]);

test("a seat's opportunities count every decision and those that played the type's move, and a match the viewer does not show counts nowhere", () => {
  const { summary } = openCertain(opportunitiesFile(), SEATS);

  const tallies = summary.seat.map((seat, entry) => [seat, summary.type[entry], summary.opportunities[entry], summary.chose[entry]]);

  expect(tallies.toSorted()).toEqual([
    [0, 0, 3, 2],
    [1, 1, 1, 1],
    [1, 2, 1, 0],
    [1, 3, 2, 1],
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

const entries = (seat: ReadonlyArray<number>, type: number, opportunities: ReadonlyArray<number>, chose: ReadonlyArray<number>) => ({
  seat,
  type: seat.map(() => type),
  opportunities,
  chose,
  moveSeat: [],
  moveType: [],
  moveOrd: [],
});

const SEATS_OF_CONFIGS = [
  { model: "gpt-6-luna", effort: "low", seedBlock: "b1" },
  { model: "gpt-6-luna", effort: "low", seedBlock: "b2" },
  { model: "claude-opus-5-5", effort: "max", seedBlock: "b1" },
  { model: "claude-opus-5-5", effort: "off", seedBlock: "b3" },
];

test("each config's mistakes pool its seats over the opportunities, strongest model and lowest effort first, with an interval from twenty opportunities", () => {
  const { rows, pooled } = talliesOf(entries([0, 1, 2, 3], 0, [15, 10, 40, 3], [4, 1, 0, 1]), SEATS_OF_CONFIGS, [true, true, true, true]);

  expect(rows.map(({ model, effort }) => `${model} ${effort}`)).toEqual(["claude-opus-5-5 off", "claude-opus-5-5 max", "gpt-6-luna low"]);
  expect(rows.map(({ cells }) => [cells[0]?.mistakes, cells[0]?.opportunities, cells[0]?.bounds === null])).toEqual([
    [1, 3, true],
    [0, 40, false],
    [5, 25, false],
  ]);

  const [low = 0, high = 1] = rows[2]?.cells[0]?.bounds ?? [];

  expect(low <= 5 / 25 && 5 / 25 <= high).toBe(true);
  expect(pooled[0]).toMatchObject({ mistakes: 6, opportunities: 68 });
  expect(pooled[1]).toMatchObject({ mistakes: 0, opportunities: 0, bounds: null });
});

test("a seat the filter drops leaves its config and the pooled row", () => {
  const { rows, pooled } = talliesOf(entries([0, 1, 2, 3], 0, [15, 10, 40, 3], [4, 1, 0, 1]), SEATS_OF_CONFIGS, [false, false, true, false]);

  expect(rows.map(({ model }) => model)).toEqual(["claude-opus-5-5"]);
  expect(pooled[0]).toMatchObject({ mistakes: 0, opportunities: 40 });
});

test("proven blanks that gave the turn away, and decisions a jammed opponent hid, are tallied apart from the certain mistakes", () => {
  const certain = { seat: [0, 0, 1], type: [3, 2, 3], opportunities: [30, 7, 20], chose: [6, 0, 5], moveSeat: [], moveType: [], moveOrd: [] };
  const { rows, provenBlanks, hiddenHealth } = talliesOf(certain, SEATS_OF_CONFIGS, [true, true, true, true]);

  expect(rows.map(({ cells }) => cells.map(({ opportunities }) => opportunities))).toEqual([[0, 0]]);
  expect(provenBlanks).toEqual({ gaveTurnAway: 11, total: 50 });
  expect(hiddenHealth).toBe(7);
});
