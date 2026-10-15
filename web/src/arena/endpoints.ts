import { type Api, createProvider, type Model, type ModelThinkingLevel, type Provider } from "@earendil-works/pi-ai";
import { anthropicMessagesApi } from "@earendil-works/pi-ai/api/anthropic-messages.lazy";
import { openAIResponsesApi } from "@earendil-works/pi-ai/api/openai-responses.lazy";
import { anthropicProvider } from "@earendil-works/pi-ai/providers/anthropic";
import { openaiProvider } from "@earendil-works/pi-ai/providers/openai";
import type { ModelRef } from "@earendil-works/pi-durable";
import { Config, Data, Effect, Option, Redacted, Schema } from "effect";

import type { AgentId } from "./agent.ts";

// Where each agent's model lives, read once from the environment (.env). Agent
// A is configured by PLAYER_A_ANT_URL and _ANT_KEY for the Anthropic Messages
// API, or PLAYER_A_OAI_URL and _OAI_KEY for the OpenAI Responses API, plus
// PLAYER_A_MODEL and an optional PLAYER_A_EFFORT; B to D likewise. Keys stay
// Redacted until pi-ai asks for them, so no error or log can show one.

export const THINKING_LEVELS = ["off", "minimal", "low", "medium", "high", "xhigh", "max"] as const satisfies ReadonlyArray<ModelThinkingLevel>;

const EndpointFields = {
  url: Schema.URL,
  key: Schema.Redacted(Schema.String),
  model: Schema.NonEmptyString,
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

const catalogOf = (endpoint: Endpoint): ReadonlyArray<Model<Api>> =>
  Endpoint.match(endpoint, {
    Anthropic: (): ReadonlyArray<Model<Api>> => anthropicProvider().getModels(),
    OpenAIResponses: (): ReadonlyArray<Model<Api>> => openaiProvider().getModels(),
  });

/** One agent's endpoint. Its model must be in pi-ai's catalog for that API, which supplies the context window and thinking levels. */
export const agentEndpoint = (agent: AgentId) =>
  Effect.gen(function* () {
    const name = (suffix: string) => `PLAYER_${agent}_${suffix}`;
    const anthropic = yield* credentials(name("ANT_URL"), name("ANT_KEY"));
    const openai = yield* credentials(name("OAI_URL"), name("OAI_KEY"));

    const settings = yield* Config.all({ model: Config.option(Config.NonEmptyString(name("MODEL"))), effort: Config.option(Config.Literals(THINKING_LEVELS, name("EFFORT"))) }).pipe(
      Effect.mapError((error) => new EndpointConfigError({ message: error.message })),
    );

    if (Option.isSome(anthropic) && Option.isSome(openai)) return yield* new EndpointConfigError({ message: `Set ${name("ANT_URL")} or ${name("OAI_URL")}, not both` });

    if (Option.isNone(settings.model)) return yield* new EndpointConfigError({ message: `${name("MODEL")} must be set` });

    const fields = { model: settings.model.value, effort: Option.getOrUndefined(settings.effort) };

    const inCatalog = (endpoint: Endpoint) =>
      catalogOf(endpoint).some((model) => model.id === endpoint.model) ? Effect.succeed(endpoint) : Effect.fail(new EndpointConfigError({ message: `${name("MODEL")}=${endpoint.model} is not a pi-ai ${endpoint._tag} model` }));

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
  const model = catalogOf(endpoint).find((candidate) => candidate.id === endpoint.model);

  if (model === undefined) throw new Error(`${endpoint.model} left pi-ai's catalog after it was parsed`);

  const options = { id: providerId, baseUrl, auth: apiKeyAuth(endpoint.key, providerId), models: [{ ...model, provider: providerId, baseUrl }] };

  return Endpoint.match(endpoint, {
    Anthropic: () => createProvider({ ...options, api: anthropicMessagesApi() }),
    OpenAIResponses: () => createProvider({ ...options, api: openAIResponsesApi() }),
  });
};

export const modelRefOf = (providerId: string, endpoint: Endpoint): ModelRef => ({ provider: providerId, modelId: endpoint.model });

/** What a manifest may show of an endpoint: never the key. */
export const describeEndpoint = (endpoint: Endpoint) => ({ api: endpoint._tag, url: baseUrlOf(endpoint.url), model: endpoint.model, effort: endpoint.effort ?? null });
