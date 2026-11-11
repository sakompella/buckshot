import { expect, test } from "bun:test";
import { mkdtempSync, readFileSync } from "node:fs";
import { tmpdir } from "node:os";
import { join } from "node:path";

import { type AssistantMessage, contentText, createModels, fauxAssistantMessage, fauxProvider, fauxText, fauxToolCall, getSystemMessageText, type Message, type TranscriptContext } from "@earendil-works/pi-ai";
import * as hegel from "@hegeldev/hegel";
import * as gs from "@hegeldev/hegel/generators";
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
    crashAt,
    onRequest,
  }: { readonly dir?: string; readonly agents?: ReadonlyArray<AgentId>; readonly provenance?: (modelId: string) => AgentProvenance; readonly crashAt?: (point: string) => void; readonly onRequest?: (transcript: TranscriptContext) => void } = {},
) => {
  const faux = fauxProvider({ provider: "faux", models: [{ id: "faux-a", contextWindow, maxTokens: 512 }, { id: "faux-b", contextWindow, maxTokens: 512 }] });
  const models = createModels();
  const seated = agents.slice(0, controllers.filter((controller) => controller === "Agent").length);

  faux.setResponses(Array.from({ length: 5_000 }, () => (transcript: TranscriptContext) => {
    onRequest?.(transcript);

    return decide(transcript);
  }));
  models.setProvider(faux.provider);

  return playMatch({
    dir,
    seed,
    controllers,
    entrants: seated.map((agent, index) => {
      const modelId = index % 2 === 0 ? "faux-a" : "faux-b";

      return { agent, label: modelId, model: { provider: "faux", modelId }, thinkingLevel: undefined, provenance: provenance(modelId) };
    }),
    models,
    delivery,
    crashAt: crashAt ?? (() => undefined),
  });
};

const PinnedAgents = Schema.Struct({ provenance: Schema.Struct({ agents: Schema.Record(Schema.String, Schema.Struct({ account_id: Schema.String })) }) });

const pinOf = (dir: string) => Schema.decodeUnknownSync(Schema.fromJsonString(PinnedAgents))(readFileSync(join(dir, "manifest.json"), "utf8")).provenance.agents.A?.account_id;

const pinned = (account: string) => (modelId: string) => ({ ...fauxProvenance(modelId), account_id: account });

const ADDENDUM = "Answer in as few words as you can.";

/** Agent A's provenance carries the addendum; the other agents' do not. */
const withAddendum = (addendum: string) => (modelId: string) => (modelId === "faux-a" ? { ...fauxProvenance(modelId), instructions_addendum: addendum } : fauxProvenance(modelId));

test("an agent's instructions addendum reaches its own system prompt only, and the manifest records it", async () => {
  const dir = mkdtempSync(join(tmpdir(), "arena-addendum-test-"));
  const systemPromptsOf = new Map<string, Set<string>>();

  const record = (transcript: TranscriptContext) => {
    const system = transcript.messages.find((message) => message.role === "system");
    const opening = transcript.messages.find((message) => message.role === "user" && textOf(message).startsWith("Your turn."));

    if (system === undefined || opening === undefined) return;

    const { you } = parseView(textOf(opening).slice(textOf(opening).indexOf("{")));

    systemPromptsOf.set(you, (systemPromptsOf.get(you) ?? new Set()).add(getSystemMessageText(system)));
  };

  await Effect.runPromise(fauxMatch(["Agent", "Agent"], "3", 200_000, "on-turn", { dir, provenance: withAddendum(ADDENDUM), onRequest: record }));

  const [promptA, promptB] = ["A", "B"].map((you) => [...(systemPromptsOf.get(you) ?? [])]);

  expect(promptA?.length).toBe(1);
  expect(promptB?.length).toBe(1);
  expect(promptA?.[0]).toContain(INSTRUCTIONS);
  expect(promptA?.[0]).toContain(ADDENDUM);
  expect(promptB?.[0]).toContain(INSTRUCTIONS);
  expect(promptB?.[0]).not.toContain(ADDENDUM);

  const manifest = Schema.decodeUnknownSync(Schema.fromJsonString(Schema.Struct({ provenance: Schema.Struct({ agents: Schema.Record(Schema.String, Schema.Struct({ instructions_addendum: Schema.optional(Schema.String) })) }) })))(readFileSync(join(dir, "manifest.json"), "utf8"));

  expect(manifest.provenance.agents.A?.instructions_addendum).toBe(ADDENDUM);
  expect(manifest.provenance.agents.B?.instructions_addendum).toBeUndefined();
});

test.each([
  ["effort", fauxProvenance, (modelId: string) => ({ ...fauxProvenance(modelId), effort: "medium" })],
  ["account pin", pinned("account-a"), pinned("account-b")],
  ["instructions addendum", withAddendum(ADDENDUM), withAddendum(`${ADDENDUM} Really.`)],
  ["dropped instructions addendum", withAddendum(ADDENDUM), fauxProvenance],
])("a match refuses to resume when its %s changed", async (_, started, changed) => {
  const dir = mkdtempSync(join(tmpdir(), "arena-resume-"));
  const resume = (provenance: (modelId: string) => AgentProvenance) => Effect.runPromiseExit(fauxMatch(["Agent", "DoN"], "3", 200_000, "on-turn", { dir, provenance }));

  expect(Exit.isSuccess(await resume(started))).toBe(true);

  const refused = await resume(changed);

  expect(Exit.isFailure(refused) && String(refused.cause)).toContain("cannot resume with this one");
  expect(Exit.isSuccess(await resume(started))).toBe(true);
});

test.each(["start:before-commit", "start:after-commit"])("the pin is recoverable from the manifest at %s", async (point) => {
  const dir = mkdtempSync(join(tmpdir(), "arena-start-pin-"));

  await Effect.runPromiseExit(fauxMatch(["Agent", "DoN"], "3", 200_000, "on-turn", { dir, provenance: pinned("account-a"), crashAt: (at) => { if (at === point) throw new Error("crash"); } }));

  expect(pinOf(dir)).toBe("account-a");
});

const tableOf = (tc: hegel.TestCase): ReadonlyArray<Controller> => {
  const size = tc.draw(gs.sampledFrom([2, 3, 4] as const));
  const lead = tc.draw(gs.integers({ minValue: 0, maxValue: size - 1 }));

  return Array.from({ length: size }, (_, seat): Controller => (seat === lead ? "Agent" : tc.draw(gs.sampledFrom(["Agent", "DoN", "Story"] as const))));
};

test("faux players play any table to game over, each seeing only its own seat, whichever letters they sit under and however moves are delivered", async () => {
  await hegel.testAsync(async (tc) => {
    const controllers = tableOf(tc);
    const letters = tc.draw(gs.arrays(gs.sampledFrom(AGENTS), { unique: true, minSize: controllers.filter((controller) => controller === "Agent").length, maxSize: controllers.filter((controller) => controller === "Agent").length }));
    const result = await Effect.runPromise(fauxMatch(controllers, String(tc.draw(gs.integers({ minValue: 0 }))), 6_000, tc.draw(gs.sampledFrom(DELIVERIES)), { agents: letters }));
    const stored = Object.values(result.storeUsage);

    expect(result.audit).toEqual({ over: true, every_view_is_own_player: true, delivered_is_own_log_exactly: true, replay_matches: true });
    expect(result.moves.fallback).toBe(0);
    expect(result.standings.map((standing) => standing.controller).toSorted()).toEqual([...controllers].toSorted());
    expect(result.loggedUsage.input).toBe(stored.reduce((total, usage) => total + usage.input, 0));
    expect(result.loggedUsage.output).toBe(stored.reduce((total, usage) => total + usage.output, 0));
  }, { testCases: 8, suppressHealthCheck: [hegel.HealthCheck.TooSlow] });
}, 180_000);

const Delivered = Schema.Struct({ kind: Schema.String, agent: Schema.optional(Schema.String), via: Schema.optional(Schema.String), entries: Schema.optional(Schema.Array(Schema.String)) });

/** By agent, every entry the arena logged as sent, in order, and how many deliveries carried them. */
const deliveriesIn = (dir: string) => {
  const lines = readFileSync(join(dir, "events.jsonl"), "utf8").trim().split("\n").map((line) => Schema.decodeUnknownSync(Schema.fromJsonString(Delivered))(line));
  const sent = lines.filter((line) => line.kind === "delivered");

  return Object.fromEntries(["A", "B", "C"].map((agent) => [agent, { entries: sent.filter((line) => line.agent === agent).flatMap((line) => line.entries ?? []), deliveries: sent.filter((line) => line.agent === agent && (line.entries?.length ?? 0) > 0).length }]));
};

test("live and on-turn delivery send each player the same entries, in the same order, at different times", async () => {
  await hegel.testAsync(async (tc) => {
    const seed = String(tc.draw(gs.integers({ minValue: 0 })));
    const dirs = { onTurn: mkdtempSync(join(tmpdir(), "arena-on-turn-")), live: mkdtempSync(join(tmpdir(), "arena-live-")) };
    const onTurn = await Effect.runPromise(fauxMatch(["Agent", "DoN", "Agent"], seed, 200_000, "on-turn", { dir: dirs.onTurn }));
    const live = await Effect.runPromise(fauxMatch(["Agent", "DoN", "Agent"], seed, 200_000, "live", { dir: dirs.live }));
    const [sentOnTurn, sentLive] = [deliveriesIn(dirs.onTurn), deliveriesIn(dirs.live)];

    expect(live.move_log_sha).toBe(onTurn.move_log_sha);
    expect(live.audit.delivered_is_own_log_exactly && onTurn.audit.delivered_is_own_log_exactly).toBe(true);

    for (const agent of ["A", "B"]) {
      expect(sentLive[agent]?.entries).toEqual(sentOnTurn[agent]?.entries ?? []);
      expect(sentLive[agent]?.deliveries ?? 0).toBeGreaterThan(sentOnTurn[agent]?.deliveries ?? 0);
    }
  }, { testCases: 3, suppressHealthCheck: [hegel.HealthCheck.TooSlow] });
}, 180_000);

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
});

/** The header a test proxy reads an account pin from, as ARENA_ACCOUNT_HEADER names it. */
const ACCOUNT_HEADER = "X-Account-Id";
const PROXY = { url: "http://127.0.0.1:8318", key: "sk-test-secret-value" };

const endpointFrom = (env: Readonly<Record<string, string>>) => Effect.runPromiseExit(agentEndpoint(Schema.decodeUnknownSync(AgentId)("A")).pipe(Effect.provideService(ConfigProvider.ConfigProvider, ConfigProvider.fromEnvRecord(env))));

const failureOf = async (env: Readonly<Record<string, string>>): Promise<string> => {
  const exit = await endpointFrom(env);

  return Exit.isFailure(exit) ? String(exit.cause) : "succeeded";
};

test("rotating only a provider key preserves resume provenance, and no key ever shows in it", async () => {
  const keyGen = gs.text({ alphabet: "0123456789abcdef", minSize: 16, maxSize: 40 }).map((hex) => `sk-${hex}`);

  await hegel.testAsync(async (tc) => {
    const [api, model] = tc.draw(gs.sampledFrom([["OAI", "gpt-6-luna"], ["ANT", "claude-haiku-5-5"]] as const));
    const env = { [`PLAYER_A_${api}_URL`]: PROXY.url, PLAYER_A_MODEL: model, PLAYER_A_EFFORT: tc.draw(gs.sampledFrom(["off", "low", "medium"] as const)) };
    const [oldKey, newKey] = [tc.draw(keyGen), tc.draw(keyGen)];
    const before = await endpointFrom({ ...env, [`PLAYER_A_${api}_KEY`]: oldKey });
    const after = await endpointFrom({ ...env, [`PLAYER_A_${api}_KEY`]: newKey });

    if (!Exit.isSuccess(before) || !Exit.isSuccess(after)) throw new Error("test endpoints failed");

    const provenance = provenanceOf("provider-A", before.value);

    expect(provenance).toEqual(provenanceOf("provider-A", after.value));
    expect(JSON.stringify(provenance)).not.toContain(oldKey);
  });
});

test.each([
  ["ANT", "claude-haiku-4-5-20251001", "medium", { level: "medium", mode: "budget", effort: null, budget_tokens: 8192, summary: "summarized" }],
  ["ANT", "claude-haiku-5-5", "medium", { level: "medium", mode: "adaptive", effort: "medium", budget_tokens: null, summary: "summarized" }],
  ["ANT", "claude-sonnet-5-5", "xhigh", { level: "xhigh", mode: "adaptive", effort: "xhigh", budget_tokens: null, summary: "summarized" }],
  ["OAI", "gpt-6-luna", "medium", { level: "medium", mode: "effort", effort: "medium", budget_tokens: null, summary: "detailed" }],
  ["OAI", "opencode/deepseek-v4.1-flash", "high", { level: "high", mode: "effort", effort: "high", budget_tokens: null, summary: "auto" }],
] as const)("the provenance records the thinking settings %s %s resolves to at effort %s", async (api, model, effort, thinking) => {
  const catalogModel = model.includes("/") ? { PLAYER_A_CATALOG_MODEL: model } : {};
  const endpoint = await endpointFrom({ [`PLAYER_A_${api}_URL`]: PROXY.url, [`PLAYER_A_${api}_KEY`]: PROXY.key, PLAYER_A_MODEL: model, ...catalogModel, PLAYER_A_EFFORT: effort });

  if (!Exit.isSuccess(endpoint)) throw new Error(String(endpoint.cause));

  const provenance = provenanceOf("provider-A", endpoint.value);

  expect(provenance.thinking).toEqual(thinking);
  expect(JSON.stringify(provenance)).not.toContain(PROXY.key);
});

/** What a local server received: the request body, and the account pin header if it carried one. */
interface Received {
  readonly body: unknown;
  readonly account: string | null;
}

/** The requests an endpoint sends for `replies` replies, as pi-durable asks for each: with no reasoning option at effort off. */
const requestsSentAt = async (api: "ANT" | "OAI", model: string, effort: "off" | "low" | "medium", extraEnv: Readonly<Record<string, string>> = {}, replies = 1) => {
  const requests: Array<Received> = [];

  const server = Bun.serve({
    port: 0,
    fetch: async (request) => {
      requests.push({ body: await request.json(), account: request.headers.get(ACCOUNT_HEADER) });

      return Response.json({ type: "error", error: { type: "invalid_request_error", message: "refused by the test" } }, { status: 400 });
    },
  });

  const endpoint = await endpointFrom({ [`PLAYER_A_${api}_URL`]: server.url.href, [`PLAYER_A_${api}_KEY`]: PROXY.key, PLAYER_A_MODEL: model, PLAYER_A_EFFORT: effort, ...extraEnv });

  if (!Exit.isSuccess(endpoint)) throw new Error(String(endpoint.cause));

  const models = createModels();
  const providerId = api === "ANT" ? "anthropic-A" : "openai-responses-A";

  models.setProvider(providerOf(providerId, endpoint.value));

  const listed = models.getModel(providerId, model);

  if (listed === undefined) throw new Error(`${model} is not listed`);

  for (let reply = 0; reply < replies; reply++) await models.completeSimple(listed, { messages: [{ role: "user", content: "Your turn.", timestamp: 0 }] }, effort === "off" ? {} : { reasoning: effort });

  await server.stop(true);

  return requests;
};

/** The first request an endpoint sends. */
const firstRequestAt = async (api: "ANT" | "OAI", model: string, effort: "off" | "low" | "medium") => Schema.decodeUnknownSync(SentRequest)((await requestsSentAt(api, model, effort))[0]?.body);

const Effort = Schema.Struct({ effort: Schema.String });

const SentRequest = Schema.Struct({
  thinking: Schema.optional(Schema.Struct({ type: Schema.String })),
  output_config: Schema.optional(Effort),
  messages: Schema.optional(Schema.Array(Schema.Struct({ output_config: Schema.optional(Effort) }))),
  reasoning: Schema.optional(Schema.Struct({ summary: Schema.optional(Schema.String) })),
});

const OFF = { level: "off", effort: null, budget_tokens: null, summary: null };

test.each([
  ["claude-haiku-5-5", "disabled", { ...OFF, mode: "off" }],
  ["claude-haiku-4-5-20251001", "disabled", { ...OFF, mode: "off" }],
  ["claude-sonnet-5-5", "between_tools", { ...OFF, mode: "between_tools" }],
] as const)("%s at effort off asks for thinking %s, sends no effort, and records the same in the provenance", async (model, wire, thinking) => {
  const request = await firstRequestAt("ANT", model, "off");
  const endpoint = await endpointFrom({ PLAYER_A_ANT_URL: PROXY.url, PLAYER_A_ANT_KEY: PROXY.key, PLAYER_A_MODEL: model, PLAYER_A_EFFORT: "off" });

  if (!Exit.isSuccess(endpoint)) throw new Error(String(endpoint.cause));

  expect(request.thinking?.type).toBe(wire);
  expect([request.output_config, ...(request.messages ?? []).map((message) => message.output_config)].flatMap((config) => (config === undefined ? [] : [config.effort]))).toEqual([]);
  expect(provenanceOf("provider-A", endpoint.value).thinking).toEqual(thinking);
});

test.each([
  ["medium", "detailed"],
  ["off", undefined],
] as const)("gpt-6-luna at effort %s asks for the reasoning summary %s", async (effort, summary) => {
  expect((await firstRequestAt("OAI", "gpt-6-luna", effort)).reasoning?.summary).toBe(summary);
});

test.each([
  ["ANT", "claude-haiku-5-5"],
  ["OAI", "gpt-6-luna"],
] as const)("a %s endpoint with PLAYER_A_ACCOUNT_ID pins every request to the account in ARENA_ACCOUNT_HEADER, and one without sends no pin", async (api, model) => {
  const pinned = await requestsSentAt(api, model, "low", { ARENA_ACCOUNT_HEADER: ACCOUNT_HEADER, PLAYER_A_ACCOUNT_ID: "claude-account-2.json" }, 2);
  const unpinned = await requestsSentAt(api, model, "low", { ARENA_ACCOUNT_HEADER: ACCOUNT_HEADER }, 2);

  expect(pinned.map((received) => received.account)).toEqual(["claude-account-2.json", "claude-account-2.json"]);
  expect(unpinned.map((received) => received.account)).toEqual([null, null]);
});

test("the account pin is recorded in the provenance only when set, never with the key", async () => {
  const env = { PLAYER_A_OAI_URL: PROXY.url, PLAYER_A_OAI_KEY: PROXY.key, PLAYER_A_MODEL: "gpt-6-luna", PLAYER_A_EFFORT: "medium" };
  const pinned = await endpointFrom({ ...env, ARENA_ACCOUNT_HEADER: ACCOUNT_HEADER, PLAYER_A_ACCOUNT_ID: "codex-account-1.json" });
  const unpinned = await endpointFrom(env);

  if (!Exit.isSuccess(pinned) || !Exit.isSuccess(unpinned)) throw new Error("test endpoints failed");

  expect(provenanceOf("provider-A", pinned.value).account_id).toBe("codex-account-1.json");
  expect("account_id" in provenanceOf("provider-A", unpinned.value)).toBe(false);
  expect(JSON.stringify(provenanceOf("provider-A", pinned.value))).not.toContain(PROXY.key);
});

test("the instructions addendum is read from PLAYER_A_INSTRUCTIONS_ADDENDUM into the provenance only when set", async () => {
  const env = { PLAYER_A_OAI_URL: PROXY.url, PLAYER_A_OAI_KEY: PROXY.key, PLAYER_A_MODEL: "gpt-6-luna", PLAYER_A_EFFORT: "medium" };
  const withText = await endpointFrom({ ...env, PLAYER_A_INSTRUCTIONS_ADDENDUM: ADDENDUM });
  const without = await endpointFrom(env);

  if (!Exit.isSuccess(withText) || !Exit.isSuccess(without)) throw new Error("test endpoints failed");

  expect(provenanceOf("provider-A", withText.value).instructions_addendum).toBe(ADDENDUM);
  expect("instructions_addendum" in provenanceOf("provider-A", without.value)).toBe(false);
});

test("a proxy's model alias plays as the catalog model it names", async () => {
  const alias = await endpointFrom({ PLAYER_A_OAI_URL: `${PROXY.url}/v1`, PLAYER_A_OAI_KEY: PROXY.key, PLAYER_A_MODEL: "gpt-6-luna-fast", PLAYER_A_CATALOG_MODEL: "gpt-6-luna" });

  if (!Exit.isSuccess(alias)) throw new Error(String(alias.cause));

  const model = providerOf("openai-responses-A", alias.value).getModels()[0];

  expect(model?.id).toBe("gpt-6-luna-fast");
  expect(model?.contextWindow).toBeGreaterThan(0);
});

test("a router's model plays as a model of the pi-ai provider its catalog model names", async () => {
  const routed = await endpointFrom({ PLAYER_A_OAI_URL: "http://localhost:9440/v1", PLAYER_A_OAI_KEY: PROXY.key, PLAYER_A_MODEL: "oc/deepseek-v4.1-flash-free", PLAYER_A_CATALOG_MODEL: "opencode/deepseek-v4.1-flash" });

  if (!Exit.isSuccess(routed)) throw new Error(String(routed.cause));

  const model = providerOf("openai-responses-A", routed.value).getModels()[0];

  expect(model?.id).toBe("oc/deepseek-v4.1-flash-free");
  expect(model?.baseUrl).toBe("http://localhost:9440/v1");
  expect(model?.contextWindow).toBeGreaterThan(0);
  expect(model?.api).toBe("openai-responses");
  expect(provenanceOf("openai-responses-A", routed.value).catalog_model).toBe("opencode/deepseek-v4.1-flash");
});

test.each([
  [{ PLAYER_A_ANT_URL: PROXY.url, PLAYER_A_ANT_KEY: PROXY.key, PLAYER_A_OAI_URL: PROXY.url, PLAYER_A_OAI_KEY: PROXY.key, PLAYER_A_MODEL: "claude-haiku-5-5" }, "not both"],
  [{ PLAYER_A_ANT_URL: PROXY.url, PLAYER_A_MODEL: "claude-haiku-5-5" }, "PLAYER_A_ANT_KEY must be set"],
  [{ PLAYER_A_OAI_KEY: PROXY.key, PLAYER_A_MODEL: "gpt-6-luna" }, "PLAYER_A_OAI_URL must be set"],
  [{ PLAYER_A_ANT_URL: PROXY.url, PLAYER_A_ANT_KEY: PROXY.key }, "PLAYER_A_MODEL must be set"],
  [{ PLAYER_A_ANT_URL: PROXY.url, PLAYER_A_ANT_KEY: PROXY.key, PLAYER_A_MODEL: "gpt-6-luna" }, "PLAYER_A_MODEL=gpt-6-luna is not a pi-ai Anthropic model"],
  [{ PLAYER_A_OAI_URL: PROXY.url, PLAYER_A_OAI_KEY: PROXY.key, PLAYER_A_MODEL: "gpt-6-luna-fast", PLAYER_A_CATALOG_MODEL: "gpt-6-lunar" }, "PLAYER_A_CATALOG_MODEL=gpt-6-lunar is not a pi-ai OpenAIResponses model"],
  [{ PLAYER_A_OAI_URL: PROXY.url, PLAYER_A_OAI_KEY: PROXY.key, PLAYER_A_MODEL: "ds", PLAYER_A_CATALOG_MODEL: "opencode/deepseek-v9" }, "PLAYER_A_CATALOG_MODEL=opencode/deepseek-v9 is not a pi-ai OpenAIResponses model"],
  [{ PLAYER_A_OAI_URL: PROXY.url, PLAYER_A_OAI_KEY: PROXY.key, PLAYER_A_MODEL: "ds", PLAYER_A_CATALOG_MODEL: "nowhere/deepseek-v4.1-flash" }, "PLAYER_A_CATALOG_MODEL=nowhere/deepseek-v4.1-flash is not a pi-ai OpenAIResponses model"],
  [{ PLAYER_A_OAI_URL: PROXY.url, PLAYER_A_OAI_KEY: PROXY.key, PLAYER_A_MODEL: "gpt-6-luna", PLAYER_A_ACCOUNT_ID: "account-1" }, "ARENA_ACCOUNT_HEADER must be set when PLAYER_A_ACCOUNT_ID is"],
  [{ PLAYER_A_MODEL: "gpt-6-luna" }, "Set PLAYER_A_ANT_URL and PLAYER_A_ANT_KEY, or PLAYER_A_OAI_URL and PLAYER_A_OAI_KEY"],
])("a bad endpoint fails naming the variable, never the key: %p", async (env, expected) => {
  const failure = await failureOf(env);

  expect(failure).toContain(expected);
  expect(failure).not.toContain(PROXY.key);
});
