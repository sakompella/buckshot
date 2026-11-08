# No rules in TypeScript

> Amended 2026-11-06 by ADR-0052: Bend is the source of truth and is relied on as the primary game model. Any implementation of the game rules outside Bend must be verified against Bend, and Bend wins any disagreement. TypeScript still never re-implements rules; the Rust evaluator (`sim/rust/`) does, under that verification.

The Bend machine in `sim/bend-mp/` is the only place the game's rules live. The web UI, the agent tools and the arena never decide on their own whether a move is legal, what a player may see, or who moves next. They ask the machine, or they play its moves on a copy of the match and look at the result. That costs some indirection (the agent's whole-action moves are found by search, not written down), but the rules cannot drift between the machine, the UI and the agents.

## Consequences

A rule change is made once, in Bend, and `bun run rules` regenerates `generated/rules.mjs`. A TypeScript check that duplicates a rule is a bug, even if it is faster.
