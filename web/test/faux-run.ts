import { type AssistantMessage, contentText, createModels, fauxAssistantMessage, fauxProvider, fauxText, fauxThinking, fauxToolCall, type TranscriptContext } from "@earendil-works/pi-ai";
import { Effect, Schema } from "effect";

import { AGENTS } from "../src/arena/agent.ts";
import type { AgentProvenance } from "../src/arena/endpoints.ts";
import { type Delivery, playMatch } from "../src/arena/match.ts";
import type { Controller } from "../src/driver.ts";

// A finished arena run that costs nothing: faux pi-ai models that answer each
// turn's view with a move. The viewer's tests and its screenshot check use it.

const View = Schema.Struct({ turn: Schema.optional(Schema.Int), moves: Schema.optional(Schema.Array(Schema.Struct({ move: Schema.Int, label: Schema.String }))) });

const parseView = Schema.decodeUnknownSync(Schema.fromJsonString(View));

const decide = (transcript: TranscriptContext): AssistantMessage => {
  const last = transcript.messages.findLast((message) => message.role !== "system");
  const text = last === undefined || last.role === "assistant" ? "" : contentText(last.content, "");

  if (!text.startsWith("Your turn.")) return fauxAssistantMessage(fauxText("Done."));

  const view = parseView(text.slice(text.indexOf("{")));
  const turn = view.turn ?? 0;

  return fauxAssistantMessage([fauxThinking("I weigh the shells left against the items I hold."), fauxText("Playing it."), fauxToolCall("play_move", { move: (turn * 7 + 3) % (view.moves?.length ?? 1), turn })], { stopReason: "toolUse" });
};

/** A faux model's provenance: no endpoint and no thinking. */
export const fauxProvenance = (modelId: string): AgentProvenance => ({ api: "faux", provider: "faux", url: null, model: modelId, catalog_model: null, effort: null, thinking: { level: null, mode: "off", effort: null, budget_tokens: null } });

/** Plays a faux match into `dir`; agents sit at the Agent seats in letter order, on models faux-a and faux-b by turns. */
export const playFauxRun = (dir: string, controllers: ReadonlyArray<Controller>, delivery: Delivery) => {
  const faux = fauxProvider({ provider: "faux", models: [{ id: "faux-a", contextWindow: 200_000, maxTokens: 512 }, { id: "faux-b", contextWindow: 200_000, maxTokens: 512 }] });
  const models = createModels();
  const agents = AGENTS.slice(0, controllers.filter((controller) => controller === "Agent").length);

  faux.setResponses(Array.from({ length: 5_000 }, () => decide));
  models.setProvider(faux.provider);

  return Effect.runPromise(
    playMatch({
      dir,
      seed: "42",
      controllers,
      entrants: agents.map((agent, index) => {
        const modelId = index % 2 === 0 ? "faux-a" : "faux-b";

        return { agent, model: { provider: "faux", modelId }, thinkingLevel: undefined, provenance: fauxProvenance(modelId) };
      }),
      models,
      delivery,
    }),
  );
};
