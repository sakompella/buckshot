import { beforeAll, expect, test } from "bun:test";
import { appendFileSync, cpSync, mkdirSync, mkdtempSync, readFileSync, writeFileSync } from "node:fs";
import { tmpdir } from "node:os";
import { join } from "node:path";

import { Option, Result, Schema } from "effect";

import type { CallLine, EventLine } from "../src/arena/runlog.ts";
import type { JsonlLine, PricedRun, Run } from "../src/viewer/api.ts";
import { afterClick, LIVE_FIRST, orderFromQuery, orderRuns, type RunOrder, writeOrder } from "../src/viewer/order.ts";
import { callsByTurn, reasoningOf } from "../src/viewer/reasoning.ts";
import { replayOf } from "../src/viewer/replay.ts";
import { decodeCallLine, decodeEventLine, movesOf, readJsonl, readRun } from "../src/viewer/runs.ts";
import { playFauxRun } from "./faux-run.ts";

const tempDir = (prefix: string) => mkdtempSync(join(tmpdir(), prefix));

const Numbered = Schema.Struct({ n: Schema.Int });

const decodeNumbered = (line: string) => Result.mapError(Schema.decodeUnknownResult(Schema.fromJsonString(Numbered))(line), (error) => error.message);

const runs = tempDir("viewer-runs-");

const dir = join(runs, "faux");

beforeAll(() => playFauxRun(dir, ["Agent", "Agent", "DoN"], "live"));

test("a line cut mid-JSON is left out until it is complete, and a malformed complete line is unreadable in place", () => {
  const cut = '{"n":1}\n{"n":2}\n{"n":';

  expect(readJsonl(cut, decodeNumbered).map((line) => line.kind === "read" && line.value.n)).toEqual([1, 2]);
  expect(readJsonl(`${cut}3}\n`, decodeNumbered).map((line) => line.kind === "read" && line.value.n)).toEqual([1, 2, 3]);

  const malformed = readJsonl('{"n":1}\n{"n":"two"}\n{"n":3}\n', decodeNumbered);

  expect(malformed.map((line) => line.kind)).toEqual(["read", "unreadable", "read"]);
  expect(malformed[1]).toMatchObject({ kind: "unreadable", line: 2 });
});

/** A seeded linear congruential generator, so a failing cut sequence repeats. */
const randomFrom = (seed: number) => {
  let state = seed;

  return () => {
    state = (state * 1_103_515_245 + 12_345) % 2 ** 31;

    return state / 2 ** 31;
  };
};

/** Writes `file` from the faux run into a new file in chunks cut at seeded random byte offsets, reading it with a cursor after each. */
const tailInChunks = <A>(file: string, decode: (line: string) => Result.Result<A, string>) => {
  const bytes = readFileSync(join(dir, file));
  const path = join(tempDir("viewer-tail-"), file);
  const random = randomFrom(7);
  const cuts = Array.from({ length: 50 }, () => Math.floor(random() * bytes.length)).toSorted((left, right) => left - right);
  const seen: Array<JsonlLine<A>> = [];

  writeFileSync(path, "");

  for (const [from, to] of [0, ...cuts].map((cut, index) => [cut, cuts[index] ?? bytes.length])) {
    appendFileSync(path, bytes.subarray(from, to));
    seen.push(...readJsonl(readFileSync(path, "utf8"), decode).slice(seen.length));
  }

  expect(seen).toEqual([...readJsonl(bytes.toString("utf8"), decode)]);
  expect(seen.every((line) => line.kind === "read")).toBe(true);
};

test("reading events.jsonl with a cursor while it is written in random chunks gives every line once, in order", () => tailInChunks("events.jsonl", decodeEventLine));

test("reading calls.jsonl with a cursor while it is written in random chunks gives every line once, in order", () => tailInChunks("calls.jsonl", decodeCallLine));

test("a faux match replays move for move to its final cash, extends a partial replay, and a format-0 run is unreadable", () => {
  const run = Result.getOrThrow(Option.getOrThrow(readRun(runs, "faux", new Date())));
  const moves = movesOf(run.events);
  const replay = Result.getOrThrow(replayOf(Option.none(), run.manifest, moves));
  const last = replay.frames.at(-1);

  expect(Option.getOrUndefined(replay.divergence)).toBeUndefined();
  expect(replay.frames.slice(1).map((frame) => frame.move?.label)).toEqual(moves.map((line) => line.label));
  expect(last?.players.map(({ player, cash }) => ({ player, cash })).toSorted((left, right) => right.cash - left.cash)).toEqual((run.manifest.standings ?? []).map(({ player, cash }) => ({ player, cash })));
  expect(replay.frames.some((frame) => frame.entries.some((entry) => entry.heardBy !== undefined))).toBe(true);

  const partial = Result.getOrThrow(replayOf(Option.none(), run.manifest, moves.slice(0, 40)));

  expect(Result.getOrThrow(replayOf(Option.some(partial), run.manifest, moves)).frames).toEqual(replay.frames);

  mkdirSync(join(runs, "older"));
  cpSync(join(dir, "events.jsonl"), join(runs, "older", "events.jsonl"));
  writeFileSync(join(runs, "older", "manifest.json"), JSON.stringify({ status: "finished", seed: "42", controllers: ["Agent", "Agent"] }));

  expect(Option.getOrThrow(readRun(runs, "older", new Date()))).toEqual(Result.fail({ kind: "unreadable", id: "older", reason: "format 0 (before agent letters): not readable by this viewer" }));
}, 30_000);

const call = (fields: Partial<CallLine>): CallLine => ({
  t: "2026-01-01T00:00:00.000Z",
  agent: "A",
  position: 1,
  provider: "p",
  api: "anthropic-messages",
  model: "m",
  stop_reason: "toolUse",
  usage: { input: 1, output: 1, cacheRead: 0, cacheWrite: 0 },
  tool_calls: [],
  text: "",
  thinking: "",
  ...fields,
});

test("reasoning is named for what the provider's API returned, and says so when only a token count came back", () => {
  expect(reasoningOf(call({ thinking: "weighing the shells" }))).toEqual({ kind: "text", label: "thinking", text: "weighing the shells" });
  expect(reasoningOf(call({ api: "openai-responses", thinking: "**Choosing beer**" }))).toEqual({ kind: "text", label: "reasoning summary", text: "**Choosing beer**" });
  expect(reasoningOf(call({ api: "openai-responses", usage: { input: 1, output: 1, cacheRead: 0, cacheWrite: 0, reasoning: 52 } }))).toEqual({ kind: "tokens", tokens: 52 });
  expect(reasoningOf(call({ thinking: "  \n", usage: { input: 1, output: 1, cacheRead: 0, cacheWrite: 0, reasoning: 0 } }))).toEqual({ kind: "none" });
});

const at = (second: number) => `2026-01-01T00:00:${String(second).padStart(2, "0")}.000Z`;

const moveLine = (turn: number, player: "A" | "B", second: number, by: "agent" | "forced" | "fallback"): EventLine => ({ t: at(second), kind: by === "fallback" ? "fallback" : "move", player, position: 1, turn, move: 0, label: "Shoot", by });

test("a call belongs to its agent's next chosen move, so retries join the move they led to, and a call still waiting for its move belongs to none", () => {
  const events = [moveLine(1, "A", 5, "forced"), moveLine(2, "A", 10, "agent"), moveLine(3, "B", 12, "agent"), moveLine(4, "A", 20, "fallback")];
  const calls = [call({ agent: "A", t: at(4), thinking: "first" }), call({ agent: "A", t: at(9) }), call({ agent: "B", t: at(11) }), call({ agent: "A", t: at(15), stop_reason: "error" }), call({ agent: "A", t: at(21) })];
  const byTurn = callsByTurn(events, calls);

  expect([...byTurn].map(([turn, own]) => [turn, own.map((line) => `${line.agent}@${line.t.slice(17, 19)}`)])).toEqual([
    [2, ["A@04", "A@09"]],
    [3, ["B@11"]],
    [4, ["A@15"]],
  ]);
});

test("every call of a faux match belongs to one move of its own agent, in order, and each agent move has a call", () => {
  const run = Result.getOrThrow(Option.getOrThrow(readRun(runs, "faux", new Date())));
  const events = run.events.flatMap((line) => (line.kind === "read" ? [line.value] : []));
  const calls = run.calls.flatMap((line) => (line.kind === "read" ? [line.value] : []));
  const byTurn = callsByTurn(events, calls);
  const agentMoves = movesOf(run.events).filter((line) => line.by === "agent");

  expect([...byTurn.values()].flat().length).toBe(calls.length);
  expect(agentMoves.every((line) => (byTurn.get(line.turn) ?? []).length > 0 && (byTurn.get(line.turn) ?? []).every((own) => own.agent === line.player && own.t <= line.t))).toBe(true);
}, 30_000);

const run = (id: string, fields: Partial<PricedRun>): Run => ({
  kind: "readable",
  id,
  started: "2026-01-01T00:00:00.000Z",
  lastWrite: "2026-01-01T00:00:00.000Z",
  status: "finished",
  seed: "1",
  delivery: "live",
  seating: [],
  agents: [{ agent: "A", model: "gpt" }, { agent: "B", model: "claude" }],
  cost: { calls: 1, input: 0, output: 0, cacheRead: 0, cacheWrite: 0, reasoning: 0, dollars: 1, unpriced: 0 },
  ...fields,
});

const ids = (runsIn: ReadonlyArray<Run>, order: RunOrder) => orderRuns(runsIn, order).map((entry) => entry.id);

const listed: ReadonlyArray<Run> = [
  run("old-finished", { started: "2026-01-01T00:00:00.000Z", seed: "30", standings: [{ player: "B", cash: 5, controller: "Agent" }], cost: { calls: 2, input: 0, output: 0, cacheRead: 0, cacheWrite: 0, reasoning: 0, dollars: 3, unpriced: 0 } }),
  run("new-finished", { started: "2026-03-01T00:00:00.000Z", seed: "4", standings: [{ player: "A", cash: 5, controller: "Agent" }], cost: { calls: 2, input: 0, output: 0, cacheRead: 0, cacheWrite: 0, reasoning: 0, dollars: 9, unpriced: 0 } }),
  run("old-live", { started: "2026-02-01T00:00:00.000Z", status: "live", seed: "7" }),
  run("new-fault", { started: "2026-04-01T00:00:00.000Z", status: "fault", seed: "100" }),
  run("stopped", { started: "2026-02-15T00:00:00.000Z", status: "stopped", seed: "-2", cost: { calls: 1, input: 0, output: 0, cacheRead: 0, cacheWrite: 0, reasoning: 0, dollars: 0, unpriced: 1 } }),
  { kind: "unreadable", id: "legacy", reason: "format 0" },
];

test("with no sort, live runs come first and the rest newest first, legacy runs last", () => {
  expect(ids(listed, LIVE_FIRST)).toEqual(["old-live", "new-fault", "new-finished", "stopped", "old-finished", "legacy"]);
});

test("a column sorts runs, ties newest first, and a run without the value stays last either way", () => {
  expect(ids(listed, { kind: "by", column: "status", direction: "asc" })).toEqual(["old-live", "new-finished", "old-finished", "new-fault", "stopped", "legacy"]);
  expect(ids(listed, { kind: "by", column: "status", direction: "desc" })).toEqual(["legacy", "stopped", "new-fault", "new-finished", "old-finished", "old-live"]);
  expect(ids(listed, { kind: "by", column: "seed", direction: "asc" })).toEqual(["stopped", "new-finished", "old-live", "old-finished", "new-fault", "legacy"]);

  expect(ids(listed, { kind: "by", column: "cost", direction: "asc" })).toEqual(["new-fault", "old-live", "old-finished", "new-finished", "stopped", "legacy"]);
  expect(ids(listed, { kind: "by", column: "cost", direction: "desc" })).toEqual(["new-finished", "old-finished", "new-fault", "old-live", "stopped", "legacy"]);
  expect(ids(listed, { kind: "by", column: "winner", direction: "asc" }).slice(0, 2)).toEqual(["old-finished", "new-finished"]);
  expect(ids(listed, { kind: "by", column: "winner", direction: "desc" }).slice(0, 2)).toEqual(["new-finished", "old-finished"]);
});

test("the sort lives in the query string beside the filters, and a header click runs its column one way, the other, then back to live first", () => {
  const query = new URLSearchParams("model=gpt&sort=cost");

  expect(orderFromQuery(query)).toEqual({ kind: "by", column: "cost", direction: "desc" });
  expect(orderFromQuery(new URLSearchParams("sort=seed&dir=desc"))).toEqual({ kind: "by", column: "seed", direction: "desc" });
  expect(orderFromQuery(new URLSearchParams("sort=nonsense&dir=asc"))).toEqual(LIVE_FIRST);

  const clicked = afterClick(afterClick(LIVE_FIRST, "started"), "started");

  expect(clicked).toEqual({ kind: "by", column: "started", direction: "asc" });
  expect(afterClick(clicked, "started")).toEqual(LIVE_FIRST);
  expect(afterClick(clicked, "cost")).toEqual({ kind: "by", column: "cost", direction: "desc" });

  writeOrder(query, clicked);

  expect(query.toString()).toBe("model=gpt&sort=started&dir=asc");

  writeOrder(query, LIVE_FIRST);

  expect(query.toString()).toBe("model=gpt");
});
