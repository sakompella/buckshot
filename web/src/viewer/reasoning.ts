import type { CallLine, EventLine, MoveLine } from "../arena/runlog.ts";

// What a model call shows of its reasoning, and which call belongs to which
// move. The run log keeps only text: calls.jsonl has the thinking text pi-ai
// collected and the provider's reasoning token count, never encrypted content.

/** The name the provider's API gives reasoning text it returns: Anthropic thinking blocks, or OpenAI Responses reasoning summaries. */
const textLabelOf = (api: string): "thinking" | "reasoning summary" => (api === "openai-responses" ? "reasoning summary" : "thinking");

export type Reasoning =
  | { readonly kind: "text"; readonly label: "thinking" | "reasoning summary"; readonly text: string }
  | { readonly kind: "tokens"; readonly tokens: number }
  | { readonly kind: "none" };

export const reasoningOf = (call: CallLine): Reasoning => {
  if (call.thinking.trim() !== "") return { kind: "text", label: textLabelOf(call.api), text: call.thinking };

  const tokens = call.usage.reasoning ?? 0;

  return tokens > 0 ? { kind: "tokens", tokens } : { kind: "none" };
};

export const tokensLabel = (tokens: number): string => `no reasoning text, ${tokens.toLocaleString("en-US")} reasoning ${tokens === 1 ? "token" : "tokens"}`;

/** A move an agent chose, or the fallback after it failed to: the moves its model calls lead to. */
const isChosen = (line: EventLine): line is MoveLine => (line.kind === "move" || line.kind === "fallback") && (line.by === "agent" || line.by === "fallback");

/**
 * The calls behind each agent move, by the move's turn: an agent's calls up to its move, since its previous one,
 * so retries and reminders belong to the move they led to. A call whose move is not logged yet is left out.
 */
export const callsByTurn = (events: ReadonlyArray<EventLine>, calls: ReadonlyArray<CallLine>): ReadonlyMap<number, ReadonlyArray<CallLine>> => {
  const chosen = events.filter(isChosen);
  const byTurn = new Map<number, Array<CallLine>>();

  for (const call of calls) {
    const move = chosen.find((line) => line.player === call.agent && line.t >= call.t);

    if (move !== undefined) byTurn.set(move.turn, (byTurn.get(move.turn) ?? []).concat(call));
  }

  return byTurn;
};
