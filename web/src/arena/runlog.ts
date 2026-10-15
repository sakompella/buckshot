import { appendFileSync, existsSync, readFileSync, writeFileSync } from "node:fs";
import { join } from "node:path";

import type { AssistantMessage } from "@earendil-works/pi-ai";
import { Schema } from "effect";

import { Letter } from "../players.ts";
import { AgentId } from "./agent.ts";

// A match's run directory, in the agent-ts layout: calls.jsonl (one line per
// model reply), events.jsonl (what the arena did) and manifest.json. Usage is
// logged raw, as the provider reported it; prices are applied later, offline,
// by scripts/arena-cost.ts.

export const Usage = Schema.Struct({
  input: Schema.Number,
  output: Schema.Number,
  cacheRead: Schema.Number,
  cacheWrite: Schema.Number,
  cacheWrite1h: Schema.optional(Schema.Number),
  reasoning: Schema.optional(Schema.Number),
});

export type Usage = typeof Usage.Type;

export const CallLine = Schema.Struct({
  t: Schema.String,
  agent: AgentId,
  position: Schema.Int,
  provider: Schema.String,
  api: Schema.String,
  model: Schema.String,
  response_model: Schema.optional(Schema.String),
  thinking_level: Schema.optional(Schema.String),
  stop_reason: Schema.String,
  error: Schema.optional(Schema.String),
  latency_ms: Schema.optional(Schema.Number),
  usage: Usage,
  tool_calls: Schema.Array(Schema.Struct({ name: Schema.String, arguments: Schema.Json })),
  text: Schema.String,
  thinking: Schema.String,
});

export type CallLine = typeof CallLine.Type;

/** The fields of an event line that totals read; the rest of each line is for people. */
const EventLine = Schema.Struct({ kind: Schema.String, agent: Schema.optional(AgentId), player: Schema.optional(Letter), wall_ms: Schema.optional(Schema.Number), entries: Schema.optional(Schema.Array(Schema.String)) });

const decodeCall = Schema.decodeUnknownSync(Schema.fromJsonString(CallLine));

const decodeEvent = Schema.decodeUnknownSync(Schema.fromJsonString(EventLine));

const linesOf = (path: string): ReadonlyArray<string> => (existsSync(path) ? readFileSync(path, "utf8").split("\n").filter((line) => line !== "") : []);

export const readCalls = (dir: string): ReadonlyArray<CallLine> => linesOf(join(dir, "calls.jsonl")).map((line) => decodeCall(line));

const readEvents = (dir: string) => linesOf(join(dir, "events.jsonl")).map((line) => decodeEvent(line));

/** Every log entry the arena sent a player, in order, as its delivered lines record them. */
export const entriesSentTo = (dir: string, player: Letter): ReadonlyArray<string> => readEvents(dir).flatMap((event) => (event.kind === "delivered" && event.player === player ? (event.entries ?? []) : []));

const append = (path: string, line: string) => appendFileSync(path, `${line}\n`);

/** Where an agent sits in this match: its position in table order, from 1. */
export interface Sitting {
  readonly agent: AgentId;
  readonly position: number;
}

export const logCall = (dir: string, { agent, position }: Sitting, message: AssistantMessage): void => {
  const { input, output, cacheRead, cacheWrite, cacheWrite1h, reasoning } = message.usage;

  const line: CallLine = {
    t: new Date().toISOString(),
    agent,
    position,
    provider: message.provider,
    api: message.api,
    model: message.model,
    response_model: message.responseModel,
    thinking_level: message.thinkingLevel,
    stop_reason: message.stopReason,
    error: message.errorMessage,
    latency_ms: message.durationMs,
    usage: { input, output, cacheRead, cacheWrite, cacheWrite1h, reasoning },
    tool_calls: message.content.flatMap((block) => (block.type === "toolCall" ? [{ name: block.name, arguments: block.arguments }] : [])),
    text: message.content.flatMap((block) => (block.type === "text" ? [block.text] : [])).join(""),
    thinking: message.content.flatMap((block) => (block.type === "thinking" ? [block.thinking] : [])).join(""),
  };

  append(join(dir, "calls.jsonl"), JSON.stringify(line));
};

export type EventFields = Readonly<Record<string, Schema.Json>>;

export const logEvent = (dir: string, kind: string, fields: EventFields): void => append(join(dir, "events.jsonl"), JSON.stringify({ t: new Date().toISOString(), kind, ...fields }));

const TOKEN_KEYS = ["input", "output", "cacheRead", "cacheWrite", "reasoning"] as const;

export type Tokens = Readonly<Record<(typeof TOKEN_KEYS)[number], number>>;

export const addTokens = (calls: ReadonlyArray<CallLine>): Tokens => ({
  input: calls.reduce((total, call) => total + call.usage.input, 0),
  output: calls.reduce((total, call) => total + call.usage.output, 0),
  cacheRead: calls.reduce((total, call) => total + call.usage.cacheRead, 0),
  cacheWrite: calls.reduce((total, call) => total + call.usage.cacheWrite, 0),
  reasoning: calls.reduce((total, call) => total + (call.usage.reasoning ?? 0), 0),
});

/** One agent's totals for a match, recomputed from the logs, so they cover every process that played it. */
export const agentTotals = (dir: string, agent: AgentId) => {
  const calls = readCalls(dir).filter((call) => call.agent === agent);
  const events = readEvents(dir).filter((event) => event.agent === agent);
  const latencies = calls.map((call) => call.latency_ms ?? 0);

  return {
    models: [...new Set(calls.map((call) => `${call.provider}/${call.model}`))],
    model_calls: calls.length,
    tool_calls: events.filter((event) => event.kind === "tool").length,
    usage: addTokens(calls),
    latency_ms: { total: latencies.reduce((total, latency) => total + latency, 0), max: Math.max(0, ...latencies) },
    wall_ms: events.reduce((total, event) => total + (event.kind === "turn" ? (event.wall_ms ?? 0) : 0), 0),
  };
};

export const writeManifest = (dir: string, manifest: Readonly<Record<string, Schema.Json>>): void => writeFileSync(join(dir, "manifest.json"), `${JSON.stringify(manifest, null, 2)}\n`);
