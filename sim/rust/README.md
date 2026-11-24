# sim/rust

A Rust port of the Buckshot rules and of the minimax player. The Bend code in
`sim/bend-mp/` is the source of truth: Rust is checked against it, and Bend
wins any disagreement.
Production regret scoring runs the Rust search.

## Crates

- `rules/` (`buckshot-rules`): the simple machine from `sim/bend-mp/simple/`.
  The state is one `Copy` value; a step does not allocate. `seats-2-4` holds
  every table and `seats-2` only the two-seat one.
- `search/` (`buckshot-search`): the player from `sim/bend-mp/player/`,
  as a library and the `buckshot-search` CLI. It has two evaluators:
  - `compat` (the `f32` build only) is Bend's search, bit for bit.
  - `bounded-v1` is the box search that production uses, run with
    `--unpruned`. The `f64,seats-2` build writes the regret rows
    (`buckshot-search score`, called by `tools/arena/score_regret.py`).
  The input is a position's number line: `web/src/analysis/native-input.ts`
  writes it and `search/src/position.rs` reads it, and the two files together
  define the format.
- `branch-map/`: generates the `B` enum of Bend branches
  (`rules/src/branch/ids.rs`) from the Bend sources and checks that every Bend
  branch has its Rust arm (`cargo branch-map check`).

## How Rust is checked against Bend

1. Tape replay (`rules/tests/tapes.rs`). `sim/bend-mp/test/rust-tapes.mjs` plays
   Bend games and writes every state, request, answer, next state and notes.
   Rust replays each step and must give the same result. The modes cover random
   configs, item-heavy games, out-of-range answers, hand-made edge cases and
   states that no valid game reaches. Each manifest also carries Bend's item
   order and default round, and Rust checks both.
2. Branch traces (`cargo trace-test`). With the `trace` feature, Rust records
   each Bend branch it takes, and the replay compares that trace with Bend's.
   `rules/tests/trace-coverage.json` lists the branches that no tape reaches,
   each with a reason, and the list must equal what the replay finds.
3. Branch map (`cargo branch-map check`). A Bend change makes `ids.rs` stale.
   Every other Rust `match`, `if` or loop is listed in `rules/branch-map.toml`
   with a reason.
4. Search oracle (`search/tests/oracle.rs`). `search-oracle.sh` writes
   synthetic decisions with the Bend player's analyses, and `compat` must match
   them bit for bit. `search/tests/pruning.rs` and a Hegel property check that
   pruned `bounded-v1` keeps the unpruned best move and value.
5. Fixed sets (`search/tests/production.rs`). `compat` reproduces rows from the
   Bend player. `bounded-v1` reproduces the committed golden set, node counts
   included, and that set pins `BoundedV1::ID`.
6. Hegel property tests in both crates, for example the fast paths against
   the Bend walks they replace, and forged or out-of-range answers.
7. Mutation testing (`mutants.sh`) and replay of recorded arena matches
   (`check-arena.sh`, which needs the private arena database). Both are run by
   hand; their script headers explain how.

## Running the checks

From the repository root, inside `nix develop`:

    bash sim/rust/check.sh

It writes fresh Bend tapes and oracle files with fixed seeds, then runs fmt,
clippy on every feature set, the branch map, the branch traces and the tests in
each build. For a quicker loop, from `sim/rust/`:

    cargo test
    cargo test --no-default-features --features f32,seats-2-4

Never use `--all-features`: `f32` and `f64` exclude each other, and so do
`seats-2-4` and `seats-2` (`features.sh` lists the valid sets). Install the
pre-commit hook once per clone with `bash sim/rust/install-hooks.sh`.
