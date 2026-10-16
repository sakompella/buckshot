import { expect, test } from "bun:test";
import { mkdtempSync, readFileSync } from "node:fs";
import { tmpdir } from "node:os";
import { join } from "node:path";

import { type AssistantMessage, contentText, createModels, fauxAssistantMessage, fauxProvider, fauxText, fauxToolCall, type Message, type TranscriptContext } from "@earendil-works/pi-ai";
import { ConfigProvider, Effect, Exit, Schema } from "effect";

import { AGENTS, AgentId } from "../src/arena/agent.ts";
import { type AgentProvenance, agentEndpoint, provenanceOf, providerOf } from "../src/arena/endpoints.ts";
import { listenForHuman } from "../src/arena/human.ts";
import { DELIVERIES, type Delivery, INSTRUCTIONS, playMatch } from "../src/arena/match.ts";
import { entriesSentTo } from "../src/arena/runlog.ts";
import type { Controller } from "../src/driver.ts";
import { fauxProvenance } from "./faux-run.ts";

// The arena with faux pi-ai models, which play from their transcripts alone, so
// these matches cost nothing. A faux player's first act probes another player's
// view; the seat tools take no player, so the probe must still return its own.
// The audit checks that every view an agent got names it by its own letter, so
// agents seated out of letter order check that letters follow agents, not seats.

const View = Schema.Struct({ you: Schema.String, turn: Schema.optional(Schema.Int), moves: Schema.optional(Schema.Array(Schema.Struct({ move: Schema.Int, label: Schema.String }))) });

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

  if (last.role === "toolResult") return last.isError ? fauxAssistantMessage([fauxToolCall("get_game", { player: "A" })], { stopReason: "toolUse" }) : play(textOf(last));

  const isFirst = transcript.messages.filter((message) => message.role === "user" && textOf(message).startsWith("Your turn.")).length === 1;

  return isFirst ? fauxAssistantMessage([fauxToolCall("get_game", { player: "B" })], { stopReason: "toolUse" }) : play(textOf(last));
};

/** A faux match; `agents` sit at the Agent seats in table order. */
const fauxMatch = (controllers: ReadonlyArray<Controller>, seed: string, contextWindow: number, delivery: Delivery, {
    dir = mkdtempSync(join(tmpdir(), "arena-test-")),
    agents = AGENTS,
    provenance = fauxProvenance,
  }: { readonly dir?: string; readonly agents?: ReadonlyArray<AgentId>; readonly provenance?: (modelId: string) => AgentProvenance } = {},
) => {
  const faux = fauxProvider({ provider: "faux", models: [{ id: "faux-a", contextWindow, maxTokens: 512 }, { id: "faux-b", contextWindow, maxTokens: 512 }] });
  const models = createModels();
  const seated = agents.slice(0, controllers.filter((controller) => controller === "Agent").length);

  faux.setResponses(Array.from({ length: 5_000 }, () => decide));
  models.setProvider(faux.provider);

  return playMatch({
    dir,
    seed,
    controllers,
    entrants: seated.map((agent, index) => {
      const modelId = index % 2 === 0 ? "faux-a" : "faux-b";

      return { agent, model: { provider: "faux", modelId }, thinkingLevel: undefined, provenance: provenance(modelId) };
    }),
    models,
    delivery,
  });
};

test("a match resumes only with the configuration it started with", async () => {
  const dir = mkdtempSync(join(tmpdir(), "arena-test-"));

  await Effect.runPromise(fauxMatch(["Agent", "DoN"], "3", 200_000, "on-turn", { dir }));

  const changed = await Effect.runPromiseExit(fauxMatch(["Agent", "DoN"], "3", 200_000, "on-turn", { dir, provenance: (modelId) => ({ ...fauxProvenance(modelId), effort: "medium" }) }));

  expect(Exit.isFailure(changed) && String(changed.cause)).toContain("cannot resume with this one");
  expect(Exit.isSuccess(await Effect.runPromiseExit(fauxMatch(["Agent", "DoN"], "3", 200_000, "on-turn", { dir })))).toBe(true);
});

test.each([
  [["Agent", "Agent"] as const, "7", "on-turn", "A,B"],
  [["Agent", "Agent", "DoN"] as const, "42", "live", "B,A"],
  [["Agent", "DoN", "Story"] as const, "9", "on-turn", "C"],
] as const)("faux players play %p, seed %s, to game over, each seeing only its own seat, with %s delivery, agents %s", async (controllers, seed, delivery, agents) => {
  const result = await Effect.runPromise(fauxMatch(controllers, seed, 6_000, delivery, { agents: Schema.decodeUnknownSync(Schema.Array(AgentId))(agents.split(",")) }));
  const stored = Object.values(result.storeUsage);

  expect(result.audit).toEqual({ over: true, every_view_is_own_player: true, delivered_is_own_log_exactly: true, replay_matches: true });
  expect(result.moves.fallback).toBe(0);
  expect(result.standings.map((standing) => standing.controller).toSorted()).toEqual([...controllers].toSorted());
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
  const onTurn = await Effect.runPromise(fauxMatch(["Agent", "DoN", "Agent"], "5", 200_000, "on-turn", { dir: dirs.onTurn }));
  const live = await Effect.runPromise(fauxMatch(["Agent", "DoN", "Agent"], "5", 200_000, "live", { dir: dirs.live }));
  const [sentOnTurn, sentLive] = [deliveriesIn(dirs.onTurn), deliveriesIn(dirs.live)];

  expect(live.move_log_sha).toBe(onTurn.move_log_sha);
  expect(live.audit.delivered_is_own_log_exactly && onTurn.audit.delivered_is_own_log_exactly).toBe(true);

  for (const agent of ["A", "B"]) {
    expect(sentLive[agent]?.entries).toEqual(sentOnTurn[agent]?.entries ?? []);
    expect(sentLive[agent]?.deliveries ?? 0).toBeGreaterThan(sentOnTurn[agent]?.deliveries ?? 0);
  }
}, 60_000);

/** What a scripted human types: some lines that are not legal moves, and a 0, always legal, in every cycle. */
const TYPED = Array.from({ length: 600 }, () => "9\nx\n2\n1\n0\n").join("");

test.each([...DELIVERIES])("a human types moves into the terminal client and plays Human vs DoN vs Story to game over, seeing only its own seat, with %s delivery", async (delivery) => {
  const dir = mkdtempSync(join(tmpdir(), "arena-human-"));
  const clients: Array<ReturnType<typeof Bun.spawn<"pipe", "pipe", "inherit">>> = [];

  const connectHuman = async () => {
    const socket = join(dir, "human.sock");
    const { connected } = await listenForHuman(socket);
    const client = Bun.spawn(["bun", "scripts/arena-human.ts", socket], { cwd: join(import.meta.dir, ".."), stdin: "pipe", stdout: "pipe", stderr: "inherit" });

    client.stdin.write(TYPED);
    void client.stdin.end();
    clients.push(client);

    return connected;
  };

  const result = await Effect.runPromise(playMatch({ dir, seed: "11", controllers: ["Human", "DoN", "Story"], entrants: [], connectHuman, models: createModels(), delivery }));
  const [client] = clients;

  if (client === undefined) throw new Error("the arena never connected its human");

  expect(await client.exited).toBe(0);
  expect(result.audit).toEqual({ over: true, every_view_is_own_player: true, delivered_is_own_log_exactly: true, replay_matches: true });
  expect(result.moves.human).toBeGreaterThan(0);
  expect(result.standings.map((standing) => standing.controller).toSorted()).toEqual(["DoN", "Human", "Story"]);

  const instructions = new Set(INSTRUCTIONS.split("\n"));
  const shown = (await new Response(client.stdout).text()).split("\n").map((line) => line.replace(/^(> )+/, ""));
  const views = shown.filter((line) => line.startsWith("{")).map((line) => parseView(line));
  const entries = shown.filter((line) => line !== "" && !instructions.has(line) && line !== "Your turn." && !line.startsWith("{") && !line.startsWith("error: ") && !/^\d+\. /.test(line));

  // The human is Player A: the letters left after no agents, in table order.
  expect(views.length).toBeGreaterThan(0);
  expect(views.every((view) => view.you === "A")).toBe(true);
  expect(entries).toEqual([...entriesSentTo(dir, "A")]);
  expect(shown.some((line) => line.startsWith("error: "))).toBe(true);
}, 60_000);

const CPA = { url: "http://127.0.0.1:8318", key: "sk-test-secret-value" };

const endpointFrom = (env: Readonly<Record<string, string>>) => Effect.runPromiseExit(agentEndpoint(Schema.decodeUnknownSync(AgentId)("A")).pipe(Effect.provideService(ConfigProvider.ConfigProvider, ConfigProvider.fromEnvRecord(env))));

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
  ["ANT", "claude-haiku-4-5-20251001", { level: "medium", mode: "budget", effort: null, budget_tokens: 8192 }],
  ["ANT", "claude-haiku-5-5", { level: "medium", mode: "adaptive", effort: "medium", budget_tokens: null }],
  ["OAI", "gpt-6-luna", { level: "medium", mode: "effort", effort: "medium", budget_tokens: null }],
  ["OAI", "opencode/deepseek-v4.1-flash", { level: "high", mode: "effort", effort: "high", budget_tokens: null }],
] as const)("the provenance records the thinking settings medium effort resolves to: %s %s", async (api, model, thinking) => {
  const catalogModel = model.includes("/") ? { PLAYER_A_CATALOG_MODEL: model } : {};
  const endpoint = await endpointFrom({ [`PLAYER_A_${api}_URL`]: CPA.url, [`PLAYER_A_${api}_KEY`]: CPA.key, PLAYER_A_MODEL: model, ...catalogModel, PLAYER_A_EFFORT: "medium" });

  if (!Exit.isSuccess(endpoint)) throw new Error(String(endpoint.cause));

  const provenance = provenanceOf("provider-A", endpoint.value);

  expect(provenance.thinking).toEqual(thinking);
  expect(JSON.stringify(provenance)).not.toContain(CPA.key);
});

test.each([
  ["claude-haiku-4-5-20251001", "off", { level: "off", mode: "off", effort: null, budget_tokens: null }],
  ["claude-haiku-4-5-20251001", "max", { level: "high", mode: "budget", effort: null, budget_tokens: 16384 }],
  ["claude-haiku-5-5", "off", { level: "off", mode: "off", effort: null, budget_tokens: null }],
  ["claude-sonnet-5-5", "xhigh", { level: "xhigh", mode: "adaptive", effort: "xhigh", budget_tokens: null }],
] as const)("the provenance records the thinking settings the arena sent CLIProxyAPI for %s at effort %s", async (model, effort, thinking) => {
  const endpoint = await endpointFrom({ PLAYER_A_ANT_URL: CPA.url, PLAYER_A_ANT_KEY: CPA.key, PLAYER_A_MODEL: model, PLAYER_A_EFFORT: effort });

  if (!Exit.isSuccess(endpoint)) throw new Error(String(endpoint.cause));

  expect(provenanceOf("provider-A", endpoint.value).thinking).toEqual(thinking);
});

/** The first Messages API request an endpoint sends, as pi-durable asks for a reply: with no reasoning option at effort off. */
const firstRequestAt = async (model: string, effort: "off" | "low") => {
  const requests: Array<unknown> = [];

  const server = Bun.serve({
    port: 0,
    fetch: async (request) => {
      requests.push(await request.json());

      return Response.json({ type: "error", error: { type: "invalid_request_error", message: "refused by the test" } }, { status: 400 });
    },
  });

  const endpoint = await endpointFrom({ PLAYER_A_ANT_URL: server.url.href, PLAYER_A_ANT_KEY: CPA.key, PLAYER_A_MODEL: model, PLAYER_A_EFFORT: effort });

  if (!Exit.isSuccess(endpoint)) throw new Error(String(endpoint.cause));

  const models = createModels();

  models.setProvider(providerOf("anthropic-A", endpoint.value));

  const listed = models.getModel("anthropic-A", model);

  if (listed === undefined) throw new Error(`${model} is not listed`);

  await models.completeSimple(listed, { messages: [{ role: "user", content: "Your turn.", timestamp: 0 }] }, effort === "off" ? {} : { reasoning: effort });
  await server.stop(true);

  return Schema.decodeUnknownSync(SentRequest)(requests[0]);
};

const SentRequest = Schema.Struct({
  thinking: Schema.optional(Schema.Struct({ type: Schema.String })),
  output_config: Schema.optional(Schema.Struct({ effort: Schema.String })),
  messages: Schema.Array(Schema.Struct({ output_config: Schema.optional(Schema.Struct({ effort: Schema.String })) })),
});

test.each([
  ["claude-haiku-5-5", "off", "disabled", []],
  ["claude-sonnet-5-5", "off", "disabled", []],
  ["claude-haiku-4-5-20251001", "off", "disabled", []],
  ["claude-sonnet-5-5", "low", "adaptive", ["high", "low"]],
] as const)("%s at effort %s asks for thinking %s, at the efforts %j", async (model, effort, thinking, efforts) => {
  const request = await firstRequestAt(model, effort);

  expect(request.thinking?.type).toBe(thinking);
  expect([request.output_config, ...request.messages.map((message) => message.output_config)].flatMap((config) => (config === undefined ? [] : [config.effort]))).toEqual([...efforts]);
});

test("a proxy's model alias plays as the catalog model it names", async () => {
  const alias = await endpointFrom({ PLAYER_A_OAI_URL: `${CPA.url}/v1`, PLAYER_A_OAI_KEY: CPA.key, PLAYER_A_MODEL: "gpt-6-luna-fast", PLAYER_A_CATALOG_MODEL: "gpt-6-luna" });

  if (!Exit.isSuccess(alias)) throw new Error(String(alias.cause));

  const model = providerOf("openai-responses-A", alias.value).getModels()[0];

  expect(model?.id).toBe("gpt-6-luna-fast");
  expect(model?.contextWindow).toBeGreaterThan(0);
});

test("a router's model plays as a model of the pi-ai provider its catalog model names", async () => {
  const routed = await endpointFrom({ PLAYER_A_OAI_URL: "http://localhost:20128/v1", PLAYER_A_OAI_KEY: CPA.key, PLAYER_A_MODEL: "oc/deepseek-v4.1-flash-free", PLAYER_A_CATALOG_MODEL: "opencode/deepseek-v4.1-flash" });

  if (!Exit.isSuccess(routed)) throw new Error(String(routed.cause));

  const model = providerOf("openai-responses-A", routed.value).getModels()[0];

  expect(model?.id).toBe("oc/deepseek-v4.1-flash-free");
  expect(model?.baseUrl).toBe("http://localhost:20128/v1");
  expect(model?.contextWindow).toBe(1_000_000);
  expect(model?.api).toBe("openai-responses");
  expect(provenanceOf("openai-responses-A", routed.value).catalog_model).toBe("opencode/deepseek-v4.1-flash");
});

test.each([
  [{ PLAYER_A_ANT_URL: CPA.url, PLAYER_A_ANT_KEY: CPA.key, PLAYER_A_OAI_URL: CPA.url, PLAYER_A_OAI_KEY: CPA.key, PLAYER_A_MODEL: "claude-haiku-5-5" }, "not both"],
  [{ PLAYER_A_ANT_URL: CPA.url, PLAYER_A_MODEL: "claude-haiku-5-5" }, "PLAYER_A_ANT_KEY must be set"],
  [{ PLAYER_A_OAI_KEY: CPA.key, PLAYER_A_MODEL: "gpt-6-luna" }, "PLAYER_A_OAI_URL must be set"],
  [{ PLAYER_A_ANT_URL: CPA.url, PLAYER_A_ANT_KEY: CPA.key }, "PLAYER_A_MODEL must be set"],
  [{ PLAYER_A_ANT_URL: CPA.url, PLAYER_A_ANT_KEY: CPA.key, PLAYER_A_MODEL: "gpt-6-luna" }, "PLAYER_A_MODEL=gpt-6-luna is not a pi-ai Anthropic model"],
  [{ PLAYER_A_OAI_URL: CPA.url, PLAYER_A_OAI_KEY: CPA.key, PLAYER_A_MODEL: "gpt-6-luna-fast", PLAYER_A_CATALOG_MODEL: "gpt-6-lunar" }, "PLAYER_A_CATALOG_MODEL=gpt-6-lunar is not a pi-ai OpenAIResponses model"],
  [{ PLAYER_A_OAI_URL: CPA.url, PLAYER_A_OAI_KEY: CPA.key, PLAYER_A_MODEL: "ds", PLAYER_A_CATALOG_MODEL: "opencode/deepseek-v9" }, "PLAYER_A_CATALOG_MODEL=opencode/deepseek-v9 is not a pi-ai OpenAIResponses model"],
  [{ PLAYER_A_OAI_URL: CPA.url, PLAYER_A_OAI_KEY: CPA.key, PLAYER_A_MODEL: "ds", PLAYER_A_CATALOG_MODEL: "nowhere/deepseek-v4.1-flash" }, "PLAYER_A_CATALOG_MODEL=nowhere/deepseek-v4.1-flash is not a pi-ai OpenAIResponses model"],
  [{ PLAYER_A_MODEL: "gpt-6-luna" }, "Set PLAYER_A_ANT_URL and PLAYER_A_ANT_KEY, or PLAYER_A_OAI_URL and PLAYER_A_OAI_KEY"],
])("a bad endpoint fails naming the variable, never the key: %p", async (env, expected) => {
  const failure = await failureOf(env);

  expect(failure).toContain(expected);
  expect(failure).not.toContain(CPA.key);
});
