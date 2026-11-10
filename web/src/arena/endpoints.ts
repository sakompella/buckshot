import { type Api, clampThinkingLevel, createProvider, type Model, type ModelThinkingLevel, type Provider, type ProviderStreams } from "@earendil-works/pi-ai";
import { anthropicMessagesApi } from "@earendil-works/pi-ai/api/anthropic-messages.lazy";
import { openAIResponsesApi } from "@earendil-works/pi-ai/api/openai-responses.lazy";
import { DEFAULT_THINKING_BUDGETS } from "@earendil-works/pi-ai/api/simple-options";
import { getBuiltinModels, getBuiltinProviders } from "@earendil-works/pi-ai/providers/all";
import { anthropicProvider } from "@earendil-works/pi-ai/providers/anthropic";
import { openaiProvider } from "@earendil-works/pi-ai/providers/openai";
import type { ModelRef } from "@earendil-works/pi-durable";
import { Config, Data, Effect, Option, Redacted, Schema } from "effect";

import type { AgentId } from "./agent.ts";
import { configLabel } from "./model-names.ts";

// Where each agent's model lives, read once from the environment (.env). Agent
// A is configured by PLAYER_A_ANT_URL and _ANT_KEY for the Anthropic Messages
// API, or PLAYER_A_OAI_URL and _OAI_KEY for the OpenAI Responses API, plus
// PLAYER_A_MODEL and an optional PLAYER_A_EFFORT; B to D likewise. An optional
// PLAYER_A_ACCOUNT_ID pins every request of the agent to one account of a
// proxy, by sending the id in the header ARENA_ACCOUNT_HEADER names; without it
// no header is sent and the proxy picks the account. An optional PLAYER_A_INSTRUCTIONS_ADDENDUM is
// text appended to the shared instructions for that agent only (ADR-0048), and an
// optional PLAYER_A_EFFORT_LABEL names the effort in the agent's label when it is
// not PLAYER_A_EFFORT, as for an "off" that is low effort plus that text. A model id
// pi-ai does not list, such as a proxy's alias, names the catalog model it
// stands for in PLAYER_A_CATALOG_MODEL: a model of the endpoint's API, or a
// model of another pi-ai provider after its name and a slash, such as
// opencode/deepseek-v4.1-flash for a router that serves it on the OpenAI
// Responses API. Keys stay Redacted until pi-ai asks for them, so no error or
// log can show one.

export const THINKING_LEVELS = ["off", "minimal", "low", "medium", "high", "xhigh", "max"] as const satisfies ReadonlyArray<ModelThinkingLevel>;

const EndpointFields = {
  url: Schema.URL,
  key: Schema.Redacted(Schema.String),
  model: Schema.NonEmptyString,
  /** The pi-ai catalog model whose context window, thinking levels and prices `model` shares, when pi-ai does not list `model` itself. */
  catalogModel: Schema.optional(Schema.NonEmptyString),
  effort: Schema.optional(Schema.Literals(THINKING_LEVELS)),
  /** The proxy account every request is pinned to, and the header that names it. An id, not a secret. */
  account: Schema.optional(Schema.Struct({ header: Schema.NonEmptyString, id: Schema.NonEmptyString })),
  /** Text appended to the shared instructions for this agent only. */
  instructionsAddendum: Schema.optional(Schema.NonEmptyString),
  /** The effort the agent's label names, when it is not `effort`. */
  effortLabel: Schema.optional(Schema.NonEmptyString),
};

export const Endpoint = Schema.TaggedUnion({
  Anthropic: EndpointFields,
  OpenAIResponses: EndpointFields,
});

export type Endpoint = typeof Endpoint.Type;

export class EndpointConfigError extends Data.TaggedError("EndpointConfigError")<{ readonly message: string }> {}

interface Credentials {
  readonly url: URL;
  readonly key: Redacted.Redacted<string>;
}

/** A URL and its key, both or neither; one without the other is an error that names the missing variable. */
const credentials = (urlName: string, keyName: string) =>
  Config.all({ url: Config.option(Config.URL(urlName)), key: Config.option(Config.Redacted(keyName)) }).pipe(
    Effect.mapError((error) => new EndpointConfigError({ message: error.message })),
    Effect.flatMap(({ url, key }): Effect.Effect<Option.Option<Credentials>, EndpointConfigError> => {
      if (Option.isSome(url) && Option.isNone(key)) return Effect.fail(new EndpointConfigError({ message: `${keyName} must be set when ${urlName} is` }));

      if (Option.isNone(url) && Option.isSome(key)) return Effect.fail(new EndpointConfigError({ message: `${urlName} must be set when ${keyName} is` }));

      return Effect.succeed(Option.zipWith(url, key, (givenUrl, givenKey) => ({ url: givenUrl, key: givenKey })));
    }),
  );

const ownCatalogOf = (endpoint: Endpoint): ReadonlyArray<Model<Api>> =>
  Endpoint.match(endpoint, {
    Anthropic: (): ReadonlyArray<Model<Api>> => anthropicProvider().getModels(),
    OpenAIResponses: (): ReadonlyArray<Model<Api>> => openaiProvider().getModels(),
  });

const builtinProvider = (name: string) => getBuiltinProviders().find((provider) => provider === name);

/** The pi-ai catalog model the endpoint's model plays as: its catalog model, from the provider it names before a slash or else from the endpoint's API, or the model itself. */
const catalogModelOf = (endpoint: Endpoint): Model<Api> | undefined => {
  const [, providerName = "", id = ""] = /^([^/]+)\/(.+)$/.exec(endpoint.catalogModel ?? "") ?? [];
  const provider = builtinProvider(providerName);

  if (provider !== undefined) return getBuiltinModels(provider).find((model) => model.id === id);

  return ownCatalogOf(endpoint).find((model) => model.id === (endpoint.catalogModel ?? endpoint.model));
};

/** The endpoint's catalog model, which agentEndpoint has checked is listed. */
const listedModelOf = (endpoint: Endpoint): Model<Api> => {
  const model = catalogModelOf(endpoint);

  if (model === undefined) throw new Error(`${endpoint.catalogModel ?? endpoint.model} left pi-ai's catalog after it was parsed`);

  return model;
};

/** One agent's endpoint. Its model, or the catalog model it names, must be in pi-ai's catalog for that API, which supplies the context window and thinking levels. */
export const agentEndpoint = (agent: AgentId) =>
  Effect.gen(function* () {
    const name = (suffix: string) => `PLAYER_${agent}_${suffix}`;
    const anthropic = yield* credentials(name("ANT_URL"), name("ANT_KEY"));
    const openai = yield* credentials(name("OAI_URL"), name("OAI_KEY"));

    const settings = yield* Config.all({
      model: Config.option(Config.NonEmptyString(name("MODEL"))),
      catalogModel: Config.option(Config.NonEmptyString(name("CATALOG_MODEL"))),
      effort: Config.option(Config.Literals(THINKING_LEVELS, name("EFFORT"))),
      accountId: Config.option(Config.NonEmptyString(name("ACCOUNT_ID"))),
      accountHeader: Config.option(Config.NonEmptyString("ARENA_ACCOUNT_HEADER")),
      instructionsAddendum: Config.option(Config.NonEmptyString(name("INSTRUCTIONS_ADDENDUM"))),
      effortLabel: Config.option(Config.NonEmptyString(name("EFFORT_LABEL"))),
    }).pipe(
      Effect.mapError((error) => new EndpointConfigError({ message: error.message })),
    );

    if (Option.isSome(anthropic) && Option.isSome(openai)) return yield* new EndpointConfigError({ message: `Set ${name("ANT_URL")} or ${name("OAI_URL")}, not both` });

    if (Option.isNone(settings.model)) return yield* new EndpointConfigError({ message: `${name("MODEL")} must be set` });

    if (Option.isSome(settings.accountId) && Option.isNone(settings.accountHeader)) return yield* new EndpointConfigError({ message: `ARENA_ACCOUNT_HEADER must be set when ${name("ACCOUNT_ID")} is` });

    const account = Option.getOrUndefined(Option.zipWith(settings.accountHeader, settings.accountId, (header, id) => ({ header, id })));
    const fields = { model: settings.model.value, catalogModel: Option.getOrUndefined(settings.catalogModel), effort: Option.getOrUndefined(settings.effort), account, instructionsAddendum: Option.getOrUndefined(settings.instructionsAddendum), effortLabel: Option.getOrUndefined(settings.effortLabel) };

    const notListed = (endpoint: Endpoint): string =>
      Option.match(settings.catalogModel, {
        onNone: () => `${name("MODEL")}=${endpoint.model} is not a pi-ai ${endpoint._tag} model; for a proxy's alias, set ${name("CATALOG_MODEL")} to the model it stands for`,
        onSome: (catalogModel) => `${name("CATALOG_MODEL")}=${catalogModel} is not a pi-ai ${endpoint._tag} model, nor a model of the pi-ai provider named before a slash`,
      });

    const inCatalog = (endpoint: Endpoint) => (catalogModelOf(endpoint) === undefined ? Effect.fail(new EndpointConfigError({ message: notListed(endpoint) })) : Effect.succeed(endpoint));

    if (Option.isSome(anthropic)) return yield* inCatalog(Endpoint.cases.Anthropic.make({ ...anthropic.value, ...fields }));

    if (Option.isSome(openai)) return yield* inCatalog(Endpoint.cases.OpenAIResponses.make({ ...openai.value, ...fields }));

    return yield* new EndpointConfigError({ message: `Set ${name("ANT_URL")} and ${name("ANT_KEY")}, or ${name("OAI_URL")} and ${name("OAI_KEY")}` });
  });

/** The base URL as the SDKs want it, without a trailing slash. */
const baseUrlOf = (url: URL): string => url.href.replace(/\/$/, "");

/** The key, and the account pin when the endpoint has one, as pi-ai resolves them for every request. createProvider's own `headers` option is never sent. */
const requestAuth = (endpoint: Endpoint, source: string) => ({
  apiKey: {
    name: source,
    resolve: async () => {
      const auth = { apiKey: Redacted.value(endpoint.key) };

      return { auth: endpoint.account === undefined ? auth : { ...auth, headers: { [endpoint.account.header]: endpoint.account.id } }, source };
    },
  },
});

/** The provider id an agent's calls are logged under: the API and the agent, so two agents can share a model. */
export const providerIdOf = (agent: AgentId, endpoint: Endpoint): string => Endpoint.match(endpoint, { Anthropic: () => `anthropic-${agent}`, OpenAIResponses: () => `openai-responses-${agent}` });

/** The API, with each request pi-ai builds read by `schema` and replaced by what `rewrite` makes of it. */
const rewriting = <A>(api: ProviderStreams, schema: Schema.Decoder<A>, rewrite: (request: A) => object): ProviderStreams => ({
  ...api,
  streamSimple: (model, context, options) =>
    api.streamSimple(model, context, {
      ...options,
      onPayload: async (payload, model) => rewrite(Schema.decodeUnknownSync(schema)((await options?.onPayload?.(payload, model)) ?? payload)),
    }),
});

const Rest = [Schema.Record(Schema.String, Schema.Unknown)] as const;

/** A Messages API request, by the parts that carry thinking and effort; the rest passes through. */
const MessagesRequest = Schema.StructWithRest(
  Schema.Struct({
    output_config: Schema.optional(Schema.Unknown),
    messages: Schema.Array(Schema.StructWithRest(Schema.Struct({ role: Schema.String, output_config: Schema.optional(Schema.Unknown) }), Rest)),
  }),
  Rest,
);

/**
 * What a Claude model whose effort pi-ai sets per message is asked for at effort off. Claude Sonnet 5.5 rejects
 * thinking disabled and takes "between_tools" in its place, which turns off only its thinking before the first tool
 * call (platform.claude.com/docs/en/build-with-claude/thinking, read 2026-10-16).
 */
const thinkingOffType = (catalogModel: Model<Api>): "disabled" | "between_tools" => (catalogModel.id === "claude-sonnet-5-5" ? "between_tools" : "disabled");

/**
 * Effort off for a Claude model whose effort pi-ai sets per message. pi-ai always asks such a model to think
 * adaptively, at effort high when no effort is given, so this rewrites each request it builds: thinking off, and no
 * effort, neither the request's nor the per-message ones pi-ai puts before the assistant turns and at the end.
 */
const withThinkingOff = (api: ProviderStreams, type: "disabled" | "between_tools"): ProviderStreams =>
  rewriting(api, MessagesRequest, ({ output_config: _effort, messages, ...request }) => ({
    ...request,
    thinking: { type },
    messages: messages.filter((message) => !(message.role === "system" && message.output_config !== undefined)),
  }));

/** A Responses API request, by its reasoning settings; the rest passes through. */
const ResponsesRequest = Schema.StructWithRest(Schema.Struct({ reasoning: Schema.optional(Schema.StructWithRest(Schema.Struct({ summary: Schema.optional(Schema.Unknown) }), Rest)) }), Rest);

/**
 * Whether the model is asked for OpenAI's detailed reasoning summary. A model of another provider served on the
 * Responses API by a router, such as DeepSeek through 9router, keeps pi-ai's "auto": it returns its own reasoning
 * text, and whether the router accepts "detailed" is untested.
 */
const asksDetailedSummaries = (catalogModel: Model<Api>): boolean => catalogModel.provider === "openai";

/** The most detailed reasoning summary OpenAI offers, in place of pi-ai's "auto", on every request that asks for one. */
const withDetailedSummaries = (api: ProviderStreams): ProviderStreams =>
  rewriting(api, ResponsesRequest, (request) => (request.reasoning?.summary === undefined ? request : { ...request, reasoning: { ...request.reasoning, summary: "detailed" } }));

/** The endpoint as a pi-ai provider with one model. */
export const providerOf = (providerId: string, endpoint: Endpoint): Provider => {
  const baseUrl = baseUrlOf(endpoint.url);
  const catalogModel = listedModelOf(endpoint);
  const model = { ...catalogModel, id: endpoint.model, provider: providerId, baseUrl };
  const options = { id: providerId, baseUrl, auth: requestAuth(endpoint, providerId) };

  return Endpoint.match(endpoint, {
    // SAFETY: a catalog model from another provider can list another API, such
    // as openai-completions for a model a router serves on the Responses API.
    // The model takes the endpoint's API and keeps its compat flags, which say
    // what the model upstream accepts; each API reads only the flags it knows.
    Anthropic: (): Provider =>
      createProvider({
        ...options,
        models: [{ ...model, api: "anthropic-messages" } as Model<"anthropic-messages">],
        api: endpoint.effort === "off" && setsEffortPerMessage(model) ? withThinkingOff(anthropicMessagesApi(), thinkingOffType(catalogModel)) : anthropicMessagesApi(),
      }),
    // SAFETY: as above.
    OpenAIResponses: (): Provider => createProvider({ ...options, models: [{ ...model, api: "openai-responses" } as Model<"openai-responses">], api: asksDetailedSummaries(catalogModel) ? withDetailedSummaries(openAIResponsesApi()) : openAIResponsesApi() }),
  });
};

/** The agent's label: its model and the effort its config is named by. */
export const labelOf = (endpoint: Endpoint): string => configLabel(endpoint.model, endpoint.effortLabel ?? endpoint.effort);

export const modelRefOf = (providerId: string, endpoint: Endpoint): ModelRef => ({ provider: providerId, modelId: endpoint.model });

/** What a run records about an agent's endpoint, fixed when its match starts. Never the key, so a key can change between a crash and the resume. */
export const AgentProvenance = Schema.Struct({
  api: Schema.String,
  provider: Schema.String,
  url: Schema.NullOr(Schema.String),
  model: Schema.String,
  catalog_model: Schema.NullOr(Schema.String),
  effort: Schema.NullOr(Schema.String),
  /** The proxy account the agent is pinned to; absent when it is not, as before the pin existed. */
  account_id: Schema.optionalKey(Schema.String),
  /** The text appended to the shared instructions for this agent only; absent when the agent plays on the shared instructions alone. */
  instructions_addendum: Schema.optionalKey(Schema.String),
  /**
   * How the model is asked to think at that effort: not at all, only between tool calls (Claude Sonnet 5.5 at off),
   * Anthropic adaptive thinking at an effort, an Anthropic thinking budget, or an OpenAI reasoning effort. `summary` is
   * the reasoning text asked for: Anthropic's summarized thinking, OpenAI's detailed summary, pi-ai's "auto" for
   * another provider's model on the Responses API, or none.
   */
  thinking: Schema.Struct({
    level: Schema.NullOr(Schema.String),
    mode: Schema.Literals(["off", "between_tools", "adaptive", "budget", "effort"]),
    effort: Schema.NullOr(Schema.String),
    budget_tokens: Schema.NullOr(Schema.Int),
    summary: Schema.NullOr(Schema.Literals(["summarized", "detailed", "auto"])),
  }),
});

export type AgentProvenance = typeof AgentProvenance.Type;

const setsEffortPerMessage = (model: Model<Api>): boolean => model.compat !== undefined && "supportsMidConvoEffort" in model.compat && model.compat.supportsMidConvoEffort === true;

/** The thinking settings the arena asks for at the effort, as pi-ai 1.1.0 derives them from the catalog model (api/anthropic-messages.js and openai-responses.js) and providerOf rewrites them. */
const thinkingOf = (endpoint: Endpoint, model: Model<Api>): AgentProvenance["thinking"] => {
  const off = { mode: "off", effort: null, budget_tokens: null, summary: null } as const;

  if (endpoint.effort === undefined || !model.reasoning) return { level: null, ...off };

  // pi-durable passes no reasoning option at effort off, so pi-ai does not clamp
  // it, and providerOf turns off the thinking pi-ai would still ask some Claude
  // models for.
  if (endpoint.effort === "off") {
    return Endpoint.match(endpoint, {
      Anthropic: (): AgentProvenance["thinking"] => ({ level: "off", ...off, mode: setsEffortPerMessage(model) && thinkingOffType(model) === "between_tools" ? "between_tools" : "off" }),
      OpenAIResponses: (): AgentProvenance["thinking"] => ({ level: "off", ...off }),
    });
  }

  const level = clampThinkingLevel(model, endpoint.effort);
  const effort = model.thinkingLevelMap?.[level] ?? level;

  if (level === "off") return { level, ...off };

  return Endpoint.match(endpoint, {
    Anthropic: (): AgentProvenance["thinking"] =>
      model.compat !== undefined && "forceAdaptiveThinking" in model.compat && model.compat.forceAdaptiveThinking === true
        ? { level, mode: "adaptive", effort, budget_tokens: null, summary: "summarized" }
        : { level, mode: "budget", effort: null, budget_tokens: (level === "xhigh" || level === "max" ? undefined : DEFAULT_THINKING_BUDGETS[level]) ?? null, summary: "summarized" },
    OpenAIResponses: (): AgentProvenance["thinking"] => ({ level, mode: "effort", effort, budget_tokens: null, summary: asksDetailedSummaries(model) ? "detailed" : "auto" }),
  });
};

/** The agent's provenance: the endpoint as the manifest shows it, and the thinking settings its effort resolves to. */
export const provenanceOf = (providerId: string, endpoint: Endpoint): AgentProvenance => {
  const provenance = { api: endpoint._tag, provider: providerId, url: baseUrlOf(endpoint.url), model: endpoint.model, catalog_model: endpoint.catalogModel ?? null, effort: endpoint.effort ?? null, thinking: thinkingOf(endpoint, listedModelOf(endpoint)) };

  const pinned = endpoint.account === undefined ? provenance : { ...provenance, account_id: endpoint.account.id };

  return endpoint.instructionsAddendum === undefined ? pinned : { ...pinned, instructions_addendum: endpoint.instructionsAddendum };
};
