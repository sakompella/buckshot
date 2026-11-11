import { createHash } from "node:crypto";
import { appendFileSync, existsSync, readFileSync } from "node:fs";
import { parseArgs } from "node:util";

import { type Api, type AssistantMessage, type Context, createModels, fauxAssistantMessage, fauxProvider, fauxToolCall, type Message, type Model, type TranscriptContext } from "@earendil-works/pi-ai";
import { toToolDeclaration } from "@earendil-works/pi-ai/utils/transcript";
import { Effect, Schema } from "effect";

import { costOf, DEFAULT_PRICES, loadPrices } from "../src/arena/cost.ts";
import { agentEndpoint, labelOf, provenanceOf, providerIdOf, providerOf } from "../src/arena/endpoints.ts";
import { agentInstructions, GET_GAME, INSTRUCTIONS, PLAY_MOVE } from "../src/arena/match.ts";
import { decodeArgs, runMain, ScriptError } from "../src/script.ts";

// Asks one config every position of a suite (tools/arena/analysis/suite.py), once
// each, and appends its answers to --out. The config is agent A of web/.env, as
// for scripts/arena.ts. Each request is the arena's: the shared instructions and
// the seat tools in the system message after the first turn input, then the
// player's turn inputs, each followed by the move it made from it as a
// play_move call and its result, up to the position's own input. It goes through
// the endpoint code a match uses, with the same thinking level, and a reply's
// first play_move call is its answer. A failed call stops the run, and a rerun
// skips the positions --out has.
// --faux answers from a faux model and needs no endpoint.
// Usage: bun scripts/arena-suite.ts --suite <positions.jsonl> --out <answers.jsonl> [--faux] [--limit N] [--parallel 4]

const USAGE = "usage: bun scripts/arena-suite.ts --suite <positions.jsonl> --out <answers.jsonl> [--faux] [--limit N] [--parallel 4]";

const { values } = parseArgs({
  args: process.argv.slice(2),
  options: {
    suite: { type: "string" },
    out: { type: "string" },
    faux: { type: "boolean", default: false },
    limit: { type: "string", default: String(Number.MAX_SAFE_INTEGER) },
    parallel: { type: "string", default: "4" },
  },
});

const Flags = Schema.Struct({
  suite: Schema.String,
  out: Schema.String,
  faux: Schema.Boolean,
  limit: Schema.NumberFromString.check(Schema.isInt()),
  parallel: Schema.NumberFromString.check(Schema.isInt()),
});

const Turn = Schema.Struct({ input: Schema.NullOr(Schema.String), turn: Schema.Int, move: Schema.Int, label: Schema.String });

const Position = Schema.Struct({ match_id: Schema.String, ordinal: Schema.Int, player: Schema.String, config: Schema.String, system_sha: Schema.String, turns: Schema.NonEmptyArray(Turn) });

type Position = typeof Position.Type;

const decodePosition = Schema.decodeUnknownSync(Schema.fromJsonString(Position));

const decodeAnswered = Schema.decodeUnknownSync(Schema.fromJsonString(Schema.Struct({ match_id: Schema.String, ordinal: Schema.Int })));

/** The last user message of a position's request: its own turn input. On the first turn the system message comes after it. */
const decodeUserText = Schema.decodeUnknownSync(Schema.Struct({ role: Schema.Literal("user"), content: Schema.String }));

const decodeView = Schema.decodeUnknownSync(Schema.fromJsonString(Schema.Struct({ turn: Schema.Int })));

/** The system message a conversation of the arena starts with, as pi-durable writes it after the first input. */
const systemMessage = (instructions: string): Message => ({ role: "system", content: "", sections: { instructions: `<instructions>\n${instructions}\n</instructions>` }, toolsAdded: [GET_GAME, PLAY_MOVE].map(toToolDeclaration), timestamp: 0 });

const sha = (text: string) => createHash("sha256").update(text).digest("hex");

/** A move the player made, as a play_move call the model at `model` made, and its result. */
const played = (model: Model<Api>, calls: ReadonlyArray<typeof Turn.Type>): Array<Message> => [
  {
    role: "assistant",
    content: calls.map(({ move, turn }) => ({ type: "toolCall", id: `play_${turn}`, name: PLAY_MOVE.name, arguments: { move, turn } })),
    api: model.api,
    provider: model.provider,
    model: model.id,
    usage: { input: 0, output: 0, cacheRead: 0, cacheWrite: 0, totalTokens: 0, cost: { input: 0, output: 0, cacheRead: 0, cacheWrite: 0, total: 0 } },
    stopReason: "toolUse",
    timestamp: 0,
  },
  ...calls.map(({ turn, label }): Message => ({ role: "toolResult", toolCallId: `play_${turn}`, toolName: PLAY_MOVE.name, content: [{ type: "text", text: JSON.stringify({ played: label }) }], isError: false, timestamp: 0 })),
];

/** The request for a position: each input, then the moves made from it, which a move without an input of its own joins. */
const transcriptOf = (position: Position, system: Message, model: Model<Api>): Context => {
  const replies: Array<Array<typeof Turn.Type>> = [];

  for (const turn of position.turns.slice(0, -1)) {
    if (turn.input === null) replies.at(-1)?.push(turn);
    else replies.push([turn]);
  }

  const inputs = position.turns.flatMap(({ input }) => (input === null ? [] : [input]));
  const user = (text: string): Message => ({ role: "user", content: text, timestamp: 0 });

  return { messages: inputs.flatMap((input, index) => [user(input), ...(index === 0 ? [system] : []), ...(index < replies.length ? played(model, replies[index] ?? []) : [])]) };
};

/** A faux model, which answers move 0 of the turn it is asked. */
const fauxModels = () => {
  const faux = fauxProvider({ provider: "faux", models: [{ id: "faux", contextWindow: 200_000, maxTokens: 512 }] });
  const models = createModels();

  faux.setResponses(Array.from({ length: 100_000 }, () => (context: TranscriptContext) => {
    const { content } = decodeUserText(context.messages.findLast((message) => message.role === "user"));
    const { turn } = decodeView(content.slice(content.indexOf("{")));

    return fauxAssistantMessage([fauxToolCall(PLAY_MOVE.name, { move: 0, turn })], { stopReason: "toolUse" });
  }));
  models.setProvider(faux.provider);

  return { models, model: faux.getModel(), label: "faux", thinkingLevel: undefined, instructions: agentInstructions({ provenance: { api: "faux", provider: "faux", url: null, model: "faux", catalog_model: null, effort: null, thinking: { level: null, mode: "off", effort: null, budget_tokens: null, summary: null } } }) };
};

/** Agent A of web/.env, with the endpoint code a match uses. */
const endpointModels = Effect.map(agentEndpoint("A"), (endpoint) => {
  const providerId = providerIdOf("A", endpoint);
  const models = createModels();

  models.setProvider(providerOf(providerId, endpoint));

  const model = models.getModel(providerId, endpoint.model);

  if (model === undefined) throw new Error(`${endpoint.model} is not a model of its provider`);

  return { models, model, label: labelOf(endpoint), thinkingLevel: endpoint.effort, instructions: agentInstructions({ provenance: provenanceOf(providerId, endpoint) }) };
});

const answerOf = (reply: AssistantMessage) => {
  const call = reply.content.find((block) => block.type === "toolCall" && block.name === PLAY_MOVE.name);

  return call?.type === "toolCall" ? { move: call.arguments.move ?? null, turn: call.arguments.turn ?? null } : { move: null, turn: null };
};

const program = Effect.gen(function* () {
  const flags = yield* decodeArgs(Flags, USAGE)(values);
  const { models, model, label, thinkingLevel, instructions } = flags.faux ? fauxModels() : yield* endpointModels;
  const system = systemMessage(instructions);
  const prices = loadPrices(DEFAULT_PRICES);
  const keyOf = ({ match_id, ordinal }: { match_id: string; ordinal: number }) => `${match_id}:${ordinal}`;
  const lines = (path: string) => readFileSync(path, "utf8").split("\n").filter(Boolean);
  const done = new Set(existsSync(flags.out) ? lines(flags.out).map((line) => keyOf(decodeAnswered(line))) : []);
  const positions = lines(flags.suite).map((line) => decodePosition(line));
  const todo = positions.filter((position) => !done.has(keyOf(position))).slice(0, flags.limit);
  const shared = systemMessage(INSTRUCTIONS);
  const systemSha = sha(JSON.stringify({ sections: shared.role === "system" ? shared.sections : undefined, toolsAdded: shared.role === "system" ? shared.toolsAdded : undefined }));

  // The shared instructions and the tools must be the ones the recorded players were sent; an addendum of the config asked goes after them.
  const other = positions.find((position) => position.system_sha !== systemSha);

  if (other !== undefined) return yield* new ScriptError({ message: `position ${other.match_id}:${other.ordinal} was played under another system message (${other.system_sha}); this checkout sends ${systemSha}`, exitCode: 1 });

  const ask = async (position: Position) => {
    const started = performance.now();
    const reply = await models.completeSimple(model, transcriptOf(position, system, model), thinkingLevel === undefined || thinkingLevel === "off" ? {} : { reasoning: thinkingLevel });

    // A failed call is no answer: the run stops, and a rerun asks the position again.
    if (reply.stopReason === "error") throw new Error(`${position.match_id}:${position.ordinal}: ${reply.errorMessage ?? "no message"}`);

    const recorded = position.turns.at(-1);
    const answer = answerOf(reply);
    const { input, output, cacheRead, cacheWrite, reasoning } = reply.usage;
    const usage = { input, output, cacheRead, cacheWrite, reasoning: reasoning ?? 0 };

    appendFileSync(
      flags.out,
      `${JSON.stringify({
        match_id: position.match_id,
        ordinal: position.ordinal,
        config: label,
        recorded_config: position.config,
        recorded_move: recorded?.move,
        ...answer,
        agrees: answer.move === recorded?.move,
        stop_reason: reply.stopReason,
        usage,
        cost_usd: costOf(prices, { model: model.id, usage }) ?? null,
        latency_ms: Math.round(performance.now() - started),
        text: reply.content.flatMap((block) => (block.type === "text" ? [block.text] : [])).join(""),
      })}\n`,
    );
  };

  const queue = [...todo];

  yield* Effect.promise(() => Promise.all(Array.from({ length: flags.parallel }, async () => { for (let position = queue.shift(); position !== undefined; position = queue.shift()) await ask(position); })));

  console.error(`${label}: asked ${todo.length} of ${positions.length} positions -> ${flags.out}`);
});

await runMain(program);
