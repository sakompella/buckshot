import { type AssistantMessage, contentText, createModels, fauxAssistantMessage, fauxProvider, fauxText, fauxToolCall, type TranscriptContext } from "@earendil-works/pi-ai";
import { Effect, Schema } from "effect";

import { playMatch, REMINDER } from "../src/arena/match.ts";
import { fauxProvenance } from "./faux-run.ts";

// A faux match that ends this process at one crash point, for test/crash.test.ts.
// Its model skips some turns, once more after the reminder on odd turns, so
// reminders and interventions happen too. It answers from the transcript alone,
// so a resumed match plays the same moves as one never stopped.
// Usage: bun test/crash-run.ts <dir> <point|none> <occurrence>

const [dir = "", point = "none", occurrence = "1"] = process.argv.slice(2);

const CRASH_EXIT = 86;

const View = Schema.Struct({ turn: Schema.Int, moves: Schema.Array(Schema.Struct({ move: Schema.Int, label: Schema.String })) });

const parseView = Schema.decodeUnknownSync(Schema.fromJsonString(View));

const userTexts = (transcript: TranscriptContext) => transcript.messages.flatMap((message) => (message.role === "user" ? [contentText(message.content, "")] : []));

const decide = (transcript: TranscriptContext): AssistantMessage => {
  const texts = userTexts(transcript);
  const last = texts.at(-1) ?? "";
  const turnInput = texts.findLast((text) => text.startsWith("Your turn."));

  if (turnInput === undefined || (last !== REMINDER && !last.startsWith("Your turn."))) return fauxAssistantMessage(fauxText("Noted."));

  const view = parseView(turnInput.slice(turnInput.indexOf("{")));
  const skips = last === REMINDER ? view.turn % 2 === 1 : view.turn % 9 === 4;

  if (skips) return fauxAssistantMessage(fauxText("I will wait."));

  return fauxAssistantMessage([fauxText("Playing it."), fauxToolCall("play_move", { move: (view.turn * 7 + 3) % view.moves.length, turn: view.turn })], { stopReason: "toolUse" });
};

const faux = fauxProvider({ provider: "faux", models: [{ id: "faux-a", contextWindow: 200_000, maxTokens: 512 }] });

const models = createModels();

faux.setResponses(Array.from({ length: 5_000 }, () => decide));

models.setProvider(faux.provider);

let seen = 0;

await Effect.runPromise(
  playMatch({
    dir,
    seed: "5",
    controllers: ["Agent", "DoN"],
    entrants: (["A"] as const).map((agent) => ({ agent, model: { provider: "faux", modelId: "faux-a" }, thinkingLevel: undefined, provenance: fauxProvenance("faux-a") })),
    models,
    delivery: "on-turn",
    crashAt: (at) => {
      if (at === point && ++seen === Number(occurrence)) process.exit(CRASH_EXIT);
    },
  }),
);
