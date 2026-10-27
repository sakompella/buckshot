import { Database } from "bun:sqlite";
import { expect, test } from "bun:test";
import { mkdtempSync } from "node:fs";
import { tmpdir } from "node:os";
import { join } from "node:path";

import { agreement, consistencyOf, openConsistency } from "../src/arena-viewer/consistency.ts";

test("two decisions agree as often as pairs of them choose the same move", () => {
  expect(agreement([2])).toBe(1);
  expect(agreement([1, 1])).toBe(0);
  expect(agreement([3, 1])).toBe(0.5);
});

test("every repeated position weighs the same, whatever its size", () => {
  const { positions, decisions, agree, lo, hi } = consistencyOf([[2], [1, 1], [50, 50]]);

  expect(positions).toBe(3);
  expect(decisions).toBe(104);
  expect(agree).toBeCloseTo((1 + 0 + 0.49) / 3, 2);
  expect(lo).toBeLessThan(agree);
  expect(hi).toBeGreaterThan(agree);
  expect(hi).toBeLessThanOrEqual(1);
});

const SCHEMA = `create table players (match_id text, player text, model text, effort text);
  create table decisions (match_id text, ordinal integer, player text, by_whom text, choice text, exact_key text)`;

// Each of 30 positions is met by two matches of the steady config and one of the other, which is only ever met once.
const knowledgeFile = (): string => {
  const path = join(mkdtempSync(join(tmpdir(), "knowledge-")), "knowledge.sqlite");
  const db = new Database(path);

  db.run(SCHEMA);
  db.run("pragma synchronous = off");

  const player = db.query(`insert into players values (?, 'A', ?, 'medium')`);
  const decision = db.query(`insert into decisions values (?, ?, 'A', ?, ?, ?)`);

  for (const [match, model] of [["m1", "steady"], ["m2", "steady"], ["m3", "rare"], ["m4", "oc/deepseek-v4.1-flash-free"], ["m5", "oc/deepseek-v4.1-flash-free"]] as const) player.run(match, model);

  for (let position = 0; position < 30; position++) {
    decision.run("m1", position, "agent", "shoot", `p${position}`);
    decision.run("m2", position, "agent", "shoot", `p${position}`);
    decision.run("m3", position, "agent", "shoot", `p${position}`);
    decision.run("m4", position, "agent", "shoot", `p${position}`);
    decision.run("m5", position, "agent", "shoot", `p${position}`);
  }

  decision.run("m1", 99, "forced", "grab", "forced");
  decision.run("m2", 99, "forced", "grab", "forced");
  db.close();

  return path;
};

test("a knowledge database gives each config with enough repeated positions its agreement, counting agent moves only", () => {
  expect(openConsistency(knowledgeFile())).toEqual([{ model: "steady", effort: "medium", positions: 30, decisions: 60, agree: 1, lo: 1, hi: 1 }]);
});
