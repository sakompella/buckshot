import { type Api, clampThinkingLevel, createProvider, type Model, type ModelThinkingLevel, type Provider } from "@earendil-works/pi-ai";
import { anthropicMessagesApi } from "@earendil-works/pi-ai/api/anthropic-messages.lazy";
import { openAIResponsesApi } from "@earendil-works/pi-ai/api/openai-responses.lazy";
import { DEFAULT_THINKING_BUDGETS } from "@earendil-works/pi-ai/api/simple-options";
import { getBuiltinModels, getBuiltinProviders } from "@earendil-works/pi-ai/providers/all";
import { anthropicProvider } from "@earendil-works/pi-ai/providers/anthropic";
import { openaiProvider } from "@earendil-works/pi-ai/providers/openai";
import type { ModelRef } from "@earendil-works/pi-durable";
import { Config, Data, Effect, Option, Redacted, Schema } from "effect";

import type { AgentId } from "./agent.ts";

// Where each agent's model lives, read once from the environment (.env). Agent
// A is configured by PLAYER_A_ANT_URL and _ANT_KEY for the Anthropic Messages
// API, or PLAYER_A_OAI_URL and _OAI_KEY for the OpenAI Responses API, plus
// PLAYER_A_MODEL and an optional PLAYER_A_EFFORT; B to D likewise. A model id
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
    }).pipe(
      Effect.mapError((error) => new EndpointConfigError({ message: error.message })),
    );

    if (Option.isSome(anthropic) && Option.isSome(openai)) return yield* new EndpointConfigError({ message: `Set ${name("ANT_URL")} or ${name("OAI_URL")}, not both` });

    if (Option.isNone(settings.model)) return yield* new EndpointConfigError({ message: `${name("MODEL")} must be set` });

    const fields = { model: settings.model.value, catalogModel: Option.getOrUndefined(settings.catalogModel), effort: Option.getOrUndefined(settings.effort) };

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

const apiKeyAuth = (key: Redacted.Redacted<string>, source: string) => ({
  apiKey: { name: source, resolve: async () => ({ auth: { apiKey: Redacted.value(key) }, source }) },
});

/** The provider id an agent's calls are logged under: the API and the agent, so two agents can share a model. */
export const providerIdOf = (agent: AgentId, endpoint: Endpoint): string => Endpoint.match(endpoint, { Anthropic: () => `anthropic-${agent}`, OpenAIResponses: () => `openai-responses-${agent}` });

/** The endpoint as a pi-ai provider with one model. */
export const providerOf = (providerId: string, endpoint: Endpoint): Provider => {
  const baseUrl = baseUrlOf(endpoint.url);
  const model = { ...listedModelOf(endpoint), id: endpoint.model, provider: providerId, baseUrl };
  const options = { id: providerId, baseUrl, auth: apiKeyAuth(endpoint.key, providerId) };

  return Endpoint.match(endpoint, {
    // SAFETY: a catalog model from another provider can list another API, such
    // as openai-completions for a model a router serves on the Responses API.
    // The model takes the endpoint's API and keeps its compat flags, which say
    // what the model upstream accepts; each API reads only the flags it knows.
    Anthropic: (): Provider => createProvider({ ...options, models: [{ ...model, api: "anthropic-messages" } as Model<"anthropic-messages">], api: anthropicMessagesApi() }),
    // SAFETY: as above.
    OpenAIResponses: (): Provider => createProvider({ ...options, models: [{ ...model, api: "openai-responses" } as Model<"openai-responses">], api: openAIResponsesApi() }),
  });
};

export const modelRefOf = (providerId: string, endpoint: Endpoint): ModelRef => ({ provider: providerId, modelId: endpoint.model });

/** What a run records about an agent's endpoint, fixed when its match starts. Never the key, so a key can change between a crash and the resume. */
export const AgentProvenance = Schema.Struct({
  api: Schema.String,
  provider: Schema.String,
  url: Schema.NullOr(Schema.String),
  model: Schema.String,
  catalog_model: Schema.NullOr(Schema.String),
  effort: Schema.NullOr(Schema.String),
  /** How pi-ai asks the model to think at that effort: not at all, Anthropic adaptive thinking at an effort, an Anthropic thinking budget, or an OpenAI reasoning effort. */
  thinking: Schema.Struct({ level: Schema.NullOr(Schema.String), mode: Schema.Literals(["off", "adaptive", "budget", "effort"]), effort: Schema.NullOr(Schema.String), budget_tokens: Schema.NullOr(Schema.Int) }),
});

export type AgentProvenance = typeof AgentProvenance.Type;

/** The thinking settings pi-ai 1.1.0 derives from the effort and the catalog model (api/anthropic-messages.js and openai-responses.js). */
const thinkingOf = (endpoint: Endpoint, model: Model<Api>): AgentProvenance["thinking"] => {
  const off = { mode: "off", effort: null, budget_tokens: null } as const;

  if (endpoint.effort === undefined || !model.reasoning) return { level: null, ...off };

  const level = clampThinkingLevel(model, endpoint.effort);
  const effort = model.thinkingLevelMap?.[level] ?? level;

  if (level === "off") return { level, ...off };

  return Endpoint.match(endpoint, {
    Anthropic: (): AgentProvenance["thinking"] =>
      model.compat !== undefined && "forceAdaptiveThinking" in model.compat && model.compat.forceAdaptiveThinking === true
        ? { level, mode: "adaptive", effort, budget_tokens: null }
        : { level, mode: "budget", effort: null, budget_tokens: (level === "xhigh" || level === "max" ? undefined : DEFAULT_THINKING_BUDGETS[level]) ?? null },
    OpenAIResponses: (): AgentProvenance["thinking"] => ({ level, mode: "effort", effort, budget_tokens: null }),
  });
};

/** The agent's provenance: the endpoint as the manifest shows it, and the thinking settings its effort resolves to. */
export const provenanceOf = (providerId: string, endpoint: Endpoint): AgentProvenance => {
  return { api: endpoint._tag, provider: providerId, url: baseUrlOf(endpoint.url), model: endpoint.model, catalog_model: endpoint.catalogModel ?? null, effort: endpoint.effort ?? null, thinking: thinkingOf(endpoint, listedModelOf(endpoint)) };
};
