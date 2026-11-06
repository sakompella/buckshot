# Rust evaluator

> Draft, proposed 2026-11-06 on branch `proto/rust-eval`. Not accepted.

The minimax player of ADR-0043 gets a Rust implementation in `sim/rust/`: a rules crate that steps the simple machine, then a player crate and a batch CLI. Bend stays the source of truth (ADR-0001 as amended): the Rust rules mirror `sim/bend-mp/simple/` and `sim/bend-mp/sm/`, and are verified against them. The arena's play, the browser table and the agent tools keep calling Bend.

The rules are one flat `Copy` state and an explicit match over every (phase, answer) pair with no wildcard arm, so a new phase or answer kind fails to compile until handled. The search calls an infallible `step` with answer tokens that only a state's own request hands out; external input (replays, fuzzing, the CLI) goes through a fallible `step_event`. Each arm is labelled with the Bend branch it mirrors.

Equivalence is checked in three layers: a static cross-reference of Bend branches to Rust arms, per-step path traces compared between the two, and differential tests on fuzzed games, recorded arena games with their exact draws, and properties.

The first Rust evaluator is a compatibility mode that reproduces the production regret rows exactly. Deeper search, bounds, a transposition table and a fitted horizon heuristic come later as new evaluator ids.

## Considered Options

- **Keep optimizing Bend.** `proto/native-fast` cut instructions by up to 64%, but native is no faster than the JS build and about half its time is the runtime's refcounting. Source cannot remove it.
- **Generate Rust from Bend.** Would keep one source, but Bend's shared records and lists would carry over the allocation the rewrite is meant to remove.
- **An FSM crate** (statig, smlang, rust-fsm and others): they generate the dispatch or split it into handlers, which loses the hand-written exhaustive match that carries the Bend labels.
- **Typestate for the whole machine:** the search holds nodes of every phase in one runtime type. Typestate is kept for answer tokens, validated input and result types.

## Consequences

- A second implementation of the rules exists. A rule change is made in Bend first; the Rust arm labels and the cross-reference gate make the matching Rust change required before `check.sh` passes.
- Rust code must stay isomorphic to Bend at the branch level for path tracing; optimizations either keep the arm structure or move to helpers on a reasoned exemption list.
- Regret rows from Rust carry their own evaluator id. Compatibility-mode rows must equal the Bend rows they replace before the corpus is rescored with them.
- This amends ADR-0043 for later evaluators only: they may prune, use a transposition table and drop the node budget. The compatibility mode keeps ADR-0043's search exactly.
