import { expect, test } from "bun:test";
import { mkdtempSync } from "node:fs";
import { tmpdir } from "node:os";
import { join } from "node:path";

import { type AssistantMessage, contentText, createModels, fauxAssistantMessage, fauxProvider, fauxText, fauxToolCall, type Message, type TranscriptContext } from "@earendil-works/pi-ai";
import { ConfigProvider, Effect, Exit, Schema } from "effect";

import { playerEndpoint } from "../src/arena/endpoints.ts";
import { playMatch } from "../src/arena/match.ts";

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

  if (last === undefined || last.role === "assistant") return fauxAssistantMessage(fauxText("Done."));

  if (last.role === "toolResult") return last.isError ? fauxAssistantMessage([fauxToolCall("get_game", { player: 1 })], { stopReason: "toolUse" }) : play(textOf(last));

  const isFirst = transcript.messages.filter((message) => message.role === "user").length === 1;

  return isFirst ? fauxAssistantMessage([fauxToolCall("get_game", { player: 2 })], { stopReason: "toolUse" }) : play(textOf(last));
};

const fauxMatch = (controllers: ReadonlyArray<"Agent" | "DoN">, seed: string, contextWindow: number) => {
  const faux = fauxProvider({ provider: "faux", models: [{ id: "faux-a", contextWindow, maxTokens: 512 }, { id: "faux-b", contextWindow, maxTokens: 512 }] });
  const models = createModels();
  const agents = controllers.filter((controller) => controller === "Agent");

  faux.setResponses(Array.from({ length: 5_000 }, () => decide));
  models.setProvider(faux.provider);

  return playMatch({
    dir: mkdtempSync(join(tmpdir(), "arena-test-")),
    seed,
    controllers,
    entrants: agents.map((_, index) => ({ model: { provider: "faux", modelId: index % 2 === 0 ? "faux-a" : "faux-b" }, thinkingLevel: undefined, describe: `faux ${index}` })),
    models,
    compaction: { enabled: true, reserveTokens: 1_500, keepRecentTokens: 1_500 },
  });
};

test.each([
  [["Agent", "Agent"] as const, "7"],
  [["Agent", "Agent", "DoN"] as const, "42"],
])("faux players play %p to game over, each seeing only its own seat", async (controllers, seed) => {
  const result = await Effect.runPromise(fauxMatch(controllers, seed, 6_000));
  const stored = Object.values(result.storeUsage);

  expect(result.audit).toEqual({ over: true, every_view_is_own_player: true, heard_is_own_log_exactly: true, replay_matches: true });
  expect(result.moves.fallback).toBe(0);
  expect(result.loggedUsage.input).toBe(stored.reduce((total, usage) => total + usage.input, 0));
  expect(result.loggedUsage.output).toBe(stored.reduce((total, usage) => total + usage.output, 0));
}, 60_000);

const CPA = { url: "http://127.0.0.1:8318", key: "sk-test-secret-value" };

const endpointFrom = (env: Readonly<Record<string, string>>) => Effect.runPromiseExit(playerEndpoint("PLAYER_ONE").pipe(Effect.provideService(ConfigProvider.ConfigProvider, ConfigProvider.fromEnvRecord(env))));

const failureOf = async (env: Readonly<Record<string, string>>): Promise<string> => {
  const exit = await endpointFrom(env);

  return Exit.isFailure(exit) ? String(exit.cause) : "succeeded";
};

test("an endpoint is Anthropic or OpenAI Responses, from its URL and key", async () => {
  const anthropic = await endpointFrom({ PLAYER_ONE_ANT_URL: CPA.url, PLAYER_ONE_ANT_KEY: CPA.key, PLAYER_ONE_MODEL: "claude-haiku-5-5", PLAYER_ONE_EFFORT: "low" });
  const openai = await endpointFrom({ PLAYER_ONE_OAI_URL: `${CPA.url}/v1`, PLAYER_ONE_OAI_KEY: CPA.key, PLAYER_ONE_MODEL: "gpt-6-luna" });

  expect(Exit.isSuccess(anthropic) && anthropic.value._tag).toBe("Anthropic");
  expect(Exit.isSuccess(openai) && openai.value._tag).toBe("OpenAIResponses");
});

test.each([
  [{ PLAYER_ONE_ANT_URL: CPA.url, PLAYER_ONE_ANT_KEY: CPA.key, PLAYER_ONE_OAI_URL: CPA.url, PLAYER_ONE_OAI_KEY: CPA.key, PLAYER_ONE_MODEL: "claude-haiku-5-5" }, "not both"],
  [{ PLAYER_ONE_ANT_URL: CPA.url, PLAYER_ONE_MODEL: "claude-haiku-5-5" }, "PLAYER_ONE_ANT_KEY must be set"],
  [{ PLAYER_ONE_OAI_KEY: CPA.key, PLAYER_ONE_MODEL: "gpt-6-luna" }, "PLAYER_ONE_OAI_URL must be set"],
  [{ PLAYER_ONE_ANT_URL: CPA.url, PLAYER_ONE_ANT_KEY: CPA.key }, "PLAYER_ONE_MODEL must be set"],
  [{ PLAYER_ONE_ANT_URL: CPA.url, PLAYER_ONE_ANT_KEY: CPA.key, PLAYER_ONE_MODEL: "gpt-6-luna" }, "not a pi-ai Anthropic model"],
  [{ PLAYER_ONE_MODEL: "gpt-6-luna" }, "Set PLAYER_ONE_ANT_URL and PLAYER_ONE_ANT_KEY, or PLAYER_ONE_OAI_URL and PLAYER_ONE_OAI_KEY"],
])("a bad endpoint fails naming the variable, never the key: %p", async (env, expected) => {
  const failure = await failureOf(env);

  expect(failure).toContain(expected);
  expect(failure).not.toContain(CPA.key);
});
