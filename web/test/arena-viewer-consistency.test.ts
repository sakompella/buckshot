import { Database } from "bun:sqlite";
import { expect, test } from "bun:test";
import { mkdtempSync } from "node:fs";
import { tmpdir } from "node:os";
import { join } from "node:path";

import { consistencyOf, openConsistency, type Repeat } from "../src/arena-viewer/consistency.ts";

const decision = (choice: string, block: string): Repeat => ({ choice, block });

test("every repeated position weighs the same, whatever its size", () => {
  const big = [...Array.from({ length: 50 }, (_, index) => decision("shoot", `b${index}`)), ...Array.from({ length: 50 }, (_, index) => decision("drink", `b${index}`))];
  const { positions, agree, lo, hi } = consistencyOf([[decision("shoot", "b1"), decision("shoot", "b2")], [decision("shoot", "b1"), decision("drink", "b2")], big]);

  expect(positions).toBe(3);
  expect(agree).toBeCloseTo((1 + 0 + 49 / 99) / 3, 4);
  expect(0 <= lo && lo <= hi && hi <= 1).toBe(true);
});

test("a seed block drawn twice in the bootstrap does not agree with its own copy", () => {
  const { agree, lo, hi } = consistencyOf(Array.from({ length: 30 }, () => [decision("shoot", "b1"), decision("drink", "b2")]));

  expect([agree, lo, hi]).toEqual([0, 0, 0]);
});

const SCHEMA = `create table players (match_id text, player text, model text, effort text);
  create table decisions (match_id text, ordinal integer, player text, by_whom text, choice text, exact_key text)`;

/**
 * Thirty positions, each met by four matches of the config "steady": three choose the same move, one another. A fifth match, not one the viewer shows, and a forced move count nowhere.
 */
const knowledgeFile = (): string => {
  const path = join(mkdtempSync(join(tmpdir(), "knowledge-")), "knowledge.sqlite");
  const db = new Database(path);

  db.run(SCHEMA);
  db.run("pragma synchronous = off");

  const player = db.query(`insert into players values (?, 'A', 'steady', 'medium')`);
  const insert = db.query(`insert into decisions values (?, ?, 'A', ?, ?, ?)`);

  for (const match of ["a1", "a2", "b1", "b2", "hidden"]) player.run(match);

  for (let position = 0; position < 30; position++) {
    for (const [match, choice] of [["a1", "shoot"], ["a2", "shoot"], ["b1", "shoot"], ["b2", "drink"], ["hidden", "shoot"]] as const) insert.run(match, position, "agent", choice, `p${position}`);
  }

  insert.run("a1", 99, "forced", "grab", "forced");
  insert.run("a2", 99, "forced", "grab", "forced");
  db.close();

  return path;
};

const SHOWN = new Map([
  ["a1", "s1"],
  ["a2", "s2"],
  ["b1", "s3"],
  ["b2", "s4"],
]);

test("a config's agreement pools its decisions, counting agent moves of the viewer's matches only", () => {
  const rows = openConsistency(knowledgeFile(), SHOWN);

  expect(rows).toHaveLength(1);
  expect(rows[0]).toMatchObject({ model: "steady", effort: "medium", positions: 30, agree: 0.5 });
});
