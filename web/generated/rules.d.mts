// Hand-written types for the Bend JS build of sim/bend-mp/web.bend, which
// `bun run rules` writes next to this file as rules.mjs. Every value is a Bend
// constructor object ({ $: "<Name>", ...fields }, the bare constructor name); Nat is a number
// (Bend checks it lies in 0..2^53).
// These types only name the boundary: web/src/bend.ts decodes every result
// with a Schema before the app reads it.

export interface BendNode {
  readonly $: string;
}

declare const rules: {
  readonly config: (table: BendNode, items: boolean) => BendNode;
  readonly start: (config: BendNode) => BendNode;
  readonly point: (state: BendNode) => BendNode;
  readonly answer: (state: BendNode, answer: number) => BendNode;
  readonly prompts: (state: BendNode) => BendNode;
  readonly "prompt.answer": (prompt: BendNode, index: number) => number;
  readonly "prompt.next": (state: BendNode, prompts: BendNode) => BendNode;
  readonly hear: (notes: BendNode, seat: BendNode) => BendNode;
  readonly public_events: (notes: BendNode) => BendNode;
  readonly "mind.story": () => BendNode;
  readonly "mind.don": () => BendNode;
  readonly "mind.hear": (mind: BendNode, notes: BendNode, seat: BendNode) => BendNode;
  readonly "mind.decide": (state: BendNode, prompt: BendNode, mind: BendNode, coin: number) => BendNode;
  readonly "mind.coin": (seed: number, seat: BendNode, count: number) => number;
};

export default rules;
