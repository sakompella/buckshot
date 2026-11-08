# Rust evaluator

> Accepted 2026-11-08.

The minimax player of ADR-0043 has a Rust implementation in `sim/rust/`: a rules crate (`buckshot-rules`) that steps the simple machine, a player crate (`buckshot-search`) and a batch CLI. Bend stays the source of truth (ADR-0001 as amended): the Rust rules mirror `sim/bend-mp/simple/` and `sim/bend-mp/sm/`, and are verified against them. The arena's play, the browser table and the agent tools keep calling Bend.

## The rules crate

The rules are one flat `Copy` state and an explicit match over every (phase, answer) pair with no wildcard arm, so a new phase or answer kind fails to compile until handled. Each arm is labelled with the Bend branch it mirrors.

`step` is infallible and trusts its caller. Its answer token must come from that state's own request: a value of the Draw request's range, or a move of the Choose request's menu. The types do not enforce this. `Range` has public fields, and `DrawValue` and `LegalMove` are `Copy` and keep no link to the state they came from. With another state's token `step` does not panic, but its result is not a step of the rules. This is a precondition on trusted callers (the search, which takes its tokens from the request it is stepping). External input (replays, fuzzing, the CLI) goes through the fallible `step_event`, which turns a raw number into a token with Bend's clamp and rejects an answer of the wrong kind.

## The search crate

A move is graded on the mover's information set only: public information plus the mover's own clues. The one safe interface is `InfoSet::parse` of a position's number line, then a `Searcher` (or `analyse_batch`). The line has no field for the true state, so a search through this interface cannot see the hidden shell order. The parser refuses what the search cannot hold (a list count over the numbers left, more grabbing seats than the table, a load of more than ten shells) and returns an error. What the crate cannot check is whether a clue in the line was earned: the producer of the line must send only the mover's view.

The raw pieces (the belief builder, `World`, `Belief`, and the position parser) are private to the crate, so no caller can build a belief from anything else. The hidden-state guarantee holds for the `InfoSet` path because it is the only path. The search algorithm is a trait over the rules crate, so other algorithms drop in without touching the rules.

### Modes

Each mode has an evaluator id that every output row records.

- **`compat`**: Bend's ADR-0043 search, bit for bit. Only in the `f32` build, and its default there.
- **`bounded-v1`** (`bounded-v1-f32` or `bounded-v1-f64`, named for the build's arithmetic): a pruned search over value boxes with a memo. Each root line gets a box of the private value (`score` to `upper`). The best move and the move the caller names as chosen are exact; every other line's box is proved no better. The budget counts nodes only, there is no fuel, and a memo hit is free. `--unpruned` searches every child, so every box is exact. At a budget compat finishes within, unpruned values equal compat's.

Later evaluator ids may change the search again (a deeper search, a fitted horizon heuristic). Every id keeps its own rows; rows of different ids are never mixed.

### Features

- `f64` (default) or `f32`, exactly one; both or neither fail to compile. `f32` is Bend's F32, bit for bit, and the only build with `compat`. All float math stays in `num.rs`, behind a newtype with methods and no operators.
- `seats-2-4` (default) or `seats-2`, exactly one. `seats-2` holds only the two-seat table, so a ring stores two seats and a wider table is refused as input.

## Verification

Equivalence with Bend is checked in layers:

- **Tape replay.** Bend writes tapes of seeded fuzzed games; the Rust rules replay them and every state, menu and note must match. Recorded arena games with their exact draws are an extended check (`check-arena.sh`), since the arena database is private and stays out of the repository.
- **Branch traces.** `cargo branch-map check` generates the label enum from the Bend sources (stale when they change) and requires every Bend branch to have its Rust sites and all other Rust control flow to be listed with a reason. `branch-map instrument` writes a Bend tree that reports branch labels. Bend is strict and shares pure calls, so the comparison is per call by presence: every branch Rust takes, Bend took in the same call.
- **Properties** (Hegel) over the rules.
- **The search oracle.** Rows from the current Bend player on synthetic decisions, generated in the gate, must match `compat` exactly, and `bounded-v1` unpruned must equal `compat`, and its pruned run must agree with its unpruned run (same best move, every box holding the exact value). This pins Rust to the Bend source of the same checkout.
- **A production golden suite** (`search/tests/production/`). 36 two-seat decisions as the production evaluator `a3962092b561cfb4` (the hash the regret rows carry) scored them, with no match ids or names; `reference.json` records its source commit, file hash, Bend version and settings. `compat` must reproduce every line, best move, depth, cut and node count, so compatibility with the rows already in the corpus does not depend on whatever the current Bend player is.

The fast checks (fmt, clippy on every feature set of `sim/rust/features.sh`, `cargo check`, `cargo branch-map check`) are plain commands in `sim/rust/hooks.sh`, listed once as pre-commit hooks in `sim/rust/pre-commit-config.json`. The flake installs them with git-hooks.nix and runs them in `nix flake check`; without Nix, `pre-commit` or `prek` installs the same file, and rustup takes the dev shell's toolchain from `sim/rust/rust-toolchain.toml`.

Mutation testing (cargo-mutants, `sim/rust/mutants.sh`) checks that these tests notice a changed rule. Mutants that no input can tell apart from the original, or that only change unreachable defensive code, are listed in `exclude_re` with the reason.

## Considered Options

- **Keep optimizing Bend.** `proto/native-fast` cut instructions by up to 64%, but native is no faster than the JS build and about half its time is the runtime's refcounting. Source cannot remove it.
- **Generate Rust from Bend.** Would keep one source, but Bend's shared records and lists would carry over the allocation the rewrite is meant to remove.
- **An FSM crate** (statig, smlang, rust-fsm and others): they generate the dispatch or split it into handlers, which loses the hand-written exhaustive match that carries the Bend labels.
- **Typestate for the whole machine:** the search holds nodes of every phase in one runtime type. Answer tokens, validated input and result types are typed, but a token is not tied to its state (see the rules crate above).

## Consequences

- A second implementation of the rules exists. A rule change is made in Bend first; the Rust arm labels and the cross-reference gate make the matching Rust change required before `check.sh` passes.
- Rust code must stay isomorphic to Bend at the branch level for path tracing; optimizations either keep the arm structure or move to helpers on a reasoned exemption list.
- Regret rows from Rust carry their own evaluator id. `compat` rows must equal the Bend rows they replace (the golden suite checks this) before the corpus is rescored with them.
- This amends ADR-0043 for later evaluators only: `bounded-v1` prunes, uses a memo and drops the fuel. `compat` keeps ADR-0043's search exactly.
- Rows from the `f32` and `f64` builds can't be confused: `compat` exists only in `f32`, and `bounded-v1` ids name their arithmetic.
