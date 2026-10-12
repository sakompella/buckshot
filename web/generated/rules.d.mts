// Hand-written types for the Bend JS build of sim/bend-mp/web.bend, which
// `bun run rules` writes next to this file as rules.mjs. Every value is a Bend
// constructor object ({ $: "<module>.<Name>", ...fields }); Nat is a bigint.
// These types only name the boundary: web/src/bend.ts decodes every result
// with a Schema before the app reads it.

export interface BendNode {
  readonly $: string;
}

declare const rules: {
  readonly config: (table: BendNode, items: boolean) => BendNode;
  readonly start: (config: BendNode) => BendNode;
  readonly point: (state: BendNode) => BendNode;
  readonly answer: (state: BendNode, answer: bigint) => BendNode;
  readonly prompts: (state: BendNode) => BendNode;
  readonly "prompt.answer": (prompt: BendNode, index: bigint) => bigint;
  readonly hear: (notes: BendNode, seat: BendNode) => BendNode;
  readonly public_events: (notes: BendNode) => BendNode;
};

export default rules;
