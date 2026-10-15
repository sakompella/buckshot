import { expect, test } from "bun:test";
import { mkdtempSync, readFileSync } from "node:fs";
import { tmpdir } from "node:os";
import { join } from "node:path";

import { type AssistantMessage, contentText, createModels, fauxAssistantMessage, fauxProvider, fauxText, fauxToolCall, type Message, type TranscriptContext } from "@earendil-works/pi-ai";
import { ConfigProvider, Effect, Exit, Schema } from "effect";

import { AGENTS } from "../src/arena/agent.ts";
import { agentEndpoint } from "../src/arena/endpoints.ts";
import { type Delivery, playMatch } from "../src/arena/match.ts";

// The arena with faux pi-ai models, which play from their transcripts alone, so
// these matches cost nothing. A faux player's first act probes another player's
// view; the seat tools take no player, so the probe must still return its own.

const View = Schema.Struct({ you: Schema.Int, turn: Schema.optional(Schema.Int), moves: Schema.optional(Schema.Array(Schema.String)) });

const parseView = Schema.decodeUnknownSync(Schema.fromJsonString(View));

const textOf = (message: Message): string => contentText(message.role === "assistant" ? [] : message.content, "");

const play = (text: string): AssistantMessage => {
  const view = parseView(text.slice(text.indexOf("{")));
  const turn = view.turn ?? 0;

  return fauxAssistantMessage([fauxToolCall("play_move", { move: (turn * 7 + 3) % (view.moves?.length ?? 1), turn })], { stopReason: "toolUse" });
};

const decide = (transcript: TranscriptContext): AssistantMessage => {
  const last = transcript.messages.findLast((message) => message.role !== "system");

  if (last === undefined || last.role === "assistant" || !(last.role === "toolResult" || textOf(last).startsWith("Your turn."))) return fauxAssistantMessage(fauxText("Done."));

  if (last.role === "toolResult") return last.isError ? fauxAssistantMessage([fauxToolCall("get_game", { player: 1 })], { stopReason: "toolUse" }) : play(textOf(last));

  const isFirst = transcript.messages.filter((message) => message.role === "user" && textOf(message).startsWith("Your turn.")).length === 1;

  return isFirst ? fauxAssistantMessage([fauxToolCall("get_game", { player: 2 })], { stopReason: "toolUse" }) : play(textOf(last));
};

const fauxMatch = (controllers: ReadonlyArray<"Agent" | "DoN">, seed: string, contextWindow: number, delivery: Delivery, dir = mkdtempSync(join(tmpdir(), "arena-test-"))) => {
  const faux = fauxProvider({ provider: "faux", models: [{ id: "faux-a", contextWindow, maxTokens: 512 }, { id: "faux-b", contextWindow, maxTokens: 512 }] });
  const models = createModels();
  const agents = controllers.filter((controller) => controller === "Agent");

  faux.setResponses(Array.from({ length: 5_000 }, () => decide));
  models.setProvider(faux.provider);

  return playMatch({
    dir,
    seed,
    controllers,
    entrants: agents.map((_, index) => ({ agent: AGENTS[index] ?? "A", model: { provider: "faux", modelId: index % 2 === 0 ? "faux-a" : "faux-b" }, thinkingLevel: undefined, describe: `faux ${index}` })),
    models,
    compaction: { enabled: true, reserveTokens: 1_500, keepRecentTokens: 1_500 },
    delivery,
  });
};

test.each([
  [["Agent", "Agent"] as const, "7", "on-turn"],
  [["Agent", "Agent", "DoN"] as const, "42", "live"],
] as const)("faux players play %p, seed %s, to game over, each seeing only its own seat, with %s delivery", async (controllers, seed, delivery) => {
  const result = await Effect.runPromise(fauxMatch(controllers, seed, 6_000, delivery));
  const stored = Object.values(result.storeUsage);

  expect(result.audit).toEqual({ over: true, every_view_is_own_player: true, delivered_is_own_log_exactly: true, replay_matches: true });
  expect(result.moves.fallback).toBe(0);
  expect(result.loggedUsage.input).toBe(stored.reduce((total, usage) => total + usage.input, 0));
  expect(result.loggedUsage.output).toBe(stored.reduce((total, usage) => total + usage.output, 0));
}, 60_000);

const Delivered = Schema.Struct({ kind: Schema.String, agent: Schema.optional(Schema.String), via: Schema.optional(Schema.String), entries: Schema.optional(Schema.Array(Schema.String)) });

/** By agent, every entry the arena logged as sent, in order, and how many deliveries carried them. */
const deliveriesIn = (dir: string) => {
  const lines = readFileSync(join(dir, "events.jsonl"), "utf8").trim().split("\n").map((line) => Schema.decodeUnknownSync(Schema.fromJsonString(Delivered))(line));
  const sent = lines.filter((line) => line.kind === "delivered");

  return Object.fromEntries(["A", "B", "C"].map((agent) => [agent, { entries: sent.filter((line) => line.agent === agent).flatMap((line) => line.entries ?? []), deliveries: sent.filter((line) => line.agent === agent && (line.entries?.length ?? 0) > 0).length }]));
};

test("live and on-turn delivery send each player the same entries, in the same order, at different times", async () => {
  const dirs = { onTurn: mkdtempSync(join(tmpdir(), "arena-on-turn-")), live: mkdtempSync(join(tmpdir(), "arena-live-")) };
  const onTurn = await Effect.runPromise(fauxMatch(["Agent", "DoN", "Agent"], "5", 200_000, "on-turn", dirs.onTurn));
  const live = await Effect.runPromise(fauxMatch(["Agent", "DoN", "Agent"], "5", 200_000, "live", dirs.live));
  const [sentOnTurn, sentLive] = [deliveriesIn(dirs.onTurn), deliveriesIn(dirs.live)];

  expect(live.move_log_sha).toBe(onTurn.move_log_sha);
  expect(live.audit.delivered_is_own_log_exactly && onTurn.audit.delivered_is_own_log_exactly).toBe(true);

  for (const agent of ["A", "B"]) {
    expect(sentLive[agent]?.entries).toEqual(sentOnTurn[agent]?.entries ?? []);
    expect(sentLive[agent]?.deliveries ?? 0).toBeGreaterThan(sentOnTurn[agent]?.deliveries ?? 0);
  }
}, 60_000);

const CPA = { url: "http://127.0.0.1:8318", key: "sk-test-secret-value" };

const endpointFrom = (env: Readonly<Record<string, string>>) => Effect.runPromiseExit(agentEndpoint("A").pipe(Effect.provideService(ConfigProvider.ConfigProvider, ConfigProvider.fromEnvRecord(env))));

const failureOf = async (env: Readonly<Record<string, string>>): Promise<string> => {
  const exit = await endpointFrom(env);

  return Exit.isFailure(exit) ? String(exit.cause) : "succeeded";
};

test("an endpoint is Anthropic or OpenAI Responses, from its URL and key", async () => {
  const anthropic = await endpointFrom({ PLAYER_A_ANT_URL: CPA.url, PLAYER_A_ANT_KEY: CPA.key, PLAYER_A_MODEL: "claude-haiku-5-5", PLAYER_A_EFFORT: "low" });
  const openai = await endpointFrom({ PLAYER_A_OAI_URL: `${CPA.url}/v1`, PLAYER_A_OAI_KEY: CPA.key, PLAYER_A_MODEL: "gpt-6-luna" });

  expect(Exit.isSuccess(anthropic) && anthropic.value._tag).toBe("Anthropic");
  expect(Exit.isSuccess(openai) && openai.value._tag).toBe("OpenAIResponses");
});

test.each([
  [{ PLAYER_A_ANT_URL: CPA.url, PLAYER_A_ANT_KEY: CPA.key, PLAYER_A_OAI_URL: CPA.url, PLAYER_A_OAI_KEY: CPA.key, PLAYER_A_MODEL: "claude-haiku-5-5" }, "not both"],
  [{ PLAYER_A_ANT_URL: CPA.url, PLAYER_A_MODEL: "claude-haiku-5-5" }, "PLAYER_A_ANT_KEY must be set"],
  [{ PLAYER_A_OAI_KEY: CPA.key, PLAYER_A_MODEL: "gpt-6-luna" }, "PLAYER_A_OAI_URL must be set"],
  [{ PLAYER_A_ANT_URL: CPA.url, PLAYER_A_ANT_KEY: CPA.key }, "PLAYER_A_MODEL must be set"],
  [{ PLAYER_A_ANT_URL: CPA.url, PLAYER_A_ANT_KEY: CPA.key, PLAYER_A_MODEL: "gpt-6-luna" }, "not a pi-ai Anthropic model"],
  [{ PLAYER_A_MODEL: "gpt-6-luna" }, "Set PLAYER_A_ANT_URL and PLAYER_A_ANT_KEY, or PLAYER_A_OAI_URL and PLAYER_A_OAI_KEY"],
])("a bad endpoint fails naming the variable, never the key: %p", async (env, expected) => {
  const failure = await failureOf(env);

  expect(failure).toContain(expected);
  expect(failure).not.toContain(CPA.key);
});
