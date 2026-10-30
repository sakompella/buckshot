import type { ModelThinkingLevel } from "@earendil-works/pi-ai";

// How people read a model and its effort. Presentation only: logs, configs,
// manifests and the JSON outputs keep the raw model id. A model the table does
// not list is shown under its id, and is its own family.

/** What a model's reasoning text is: its own chain of thought, or the summary OpenAI's API gives of it. */
export type ReasoningText = "thinking" | "reasoning summary";

interface Described {
  readonly name: string;
  readonly family: string;
  readonly reasoningText: ReasoningText;
}

const MODELS: ReadonlyMap<string, Described> = new Map([
  ["claude-haiku-4-5-20251001", { name: "claude-haiku 4.5", family: "claude-haiku", reasoningText: "thinking" }],
  ["claude-haiku-5-5", { name: "claude-haiku 5.5", family: "claude-haiku", reasoningText: "thinking" }],
  ["claude-sonnet-5-5", { name: "claude-sonnet 5.5", family: "claude-sonnet", reasoningText: "thinking" }],
  ["claude-opus-5-5", { name: "claude-opus 5.5", family: "claude-opus", reasoningText: "thinking" }],
  ["gpt-6-luna", { name: "gpt-6 luna", family: "gpt", reasoningText: "reasoning summary" }],
  ["gpt-6.1-sol", { name: "gpt-6.1 sol", family: "gpt", reasoningText: "reasoning summary" }],
  ["gpt-6.1-terra", { name: "gpt-6.1 terra", family: "gpt", reasoningText: "reasoning summary" }],
  ["gpt-6-astra", { name: "gpt-6 astra", family: "gpt", reasoningText: "reasoning summary" }],
  ["oc/deepseek-v4.1-flash-free", { name: "deepseek v4.1", family: "deepseek", reasoningText: "thinking" }],
]);

export const modelName = (id: string): string => MODELS.get(id)?.name ?? id;

/** How to call a model's reasoning text, when the table knows. */
export const reasoningTextOf = (id: string): ReasoningText | undefined => MODELS.get(id)?.reasoningText;

export const modelFamily = (id: string): string => MODELS.get(id)?.family ?? id;

/** pi's thinking levels, weakest first, with what people call each; "off" is "none". */
export const EFFORT_NAMES = { off: "none", minimal: "minimal", low: "low", medium: "medium", high: "high", xhigh: "xhigh", max: "max" } as const satisfies Record<ModelThinkingLevel, string>;

/** The efforts a run can have, weakest first. */
export const EFFORTS = Object.keys(EFFORT_NAMES);

/** Where an effort sits among the efforts, weakest first; an unknown or unset one is after them all. */
export const effortRank = (effort: string | undefined): number => {
  const rank = EFFORTS.indexOf(effort ?? "");

  return rank === -1 ? EFFORTS.length : rank;
};

const isLevel = (effort: string): effort is ModelThinkingLevel => Object.hasOwn(EFFORT_NAMES, effort);

export const effortName = (effort: string): string => (isLevel(effort) ? EFFORT_NAMES[effort] : effort);
