# Buckshot

Research on Buckshot Roulette: a multiplayer rules library in Bend, a browser table, agent tools, and an arena where models play each other.

- **Unfinished work** and what each branch needs next: `_work/work-in-progress.md` (local, gitignored). Read it first when it exists.
- **Bend is the source of truth for the rules** (`sim/bend-mp/`). TypeScript may call Bend exports but never re-implements rules. Rules outside Bend (the Rust evaluator in `sim/rust/`) must be verified against Bend, and Bend wins any disagreement (ADR-0052).
- **Never commit** decompiled game code, original game assets or text, raw tournament data, anything under `_work/` or `.audit/`, or in-progress trackers (status notes, progress logs, handoffs, plans). Trackers go in `_work/` or `_*.md`. If one gets committed on a branch, purge it from the branch's history before the merge. Account ids and emails stay out of committed files.
- **Toolchain:** `nix develop` gives the pinned Bend 2.0.39, bun, Python and stable Rust.
- **Before committing:**
  - Bend changes: `bash sim/bend-mp/check.sh`.
  - `sim/rust/` changes: the pre-commit hook (`.githooks/pre-commit`; `nix develop` enables it in a Buckshot checkout when `core.hooksPath` is unset, otherwise run `git config core.hooksPath .githooks`) runs `cargo fmt --check`, `cargo clippy` with `-D warnings` and `cargo check` once per feature set when `sim/rust/` files are staged. Also run `cargo test` and `cargo test --no-default-features --features f32,seats-2-4` from `sim/rust/` (`sim/rust/features.sh` lists every feature set; `check.sh` runs them all). The search crate's `f64` (default) and `f32` features exclude each other, so never pass `--all-features`; `f32` is the Bend-exact build and the only one with the compat evaluator. To compare with Bend, write the tapes with `node sim/bend-mp/test/rust-tapes.mjs --random 20` and `--arena 5`, then run the tests with `RUST_TAPES=/tmp/rust-tapes`. Mutation testing is `bash sim/rust/mutants.sh` with cargo-mutants arguments (settings in `sim/rust/.cargo/mutants.toml`); not in the hook or `check.sh`. Run it in chunks of about 15 minutes through `_work/bin/heavy`: `--package buckshot-rules --file rules/src/<file>.rs`, then `--package buckshot-search --no-default-features --features f32,seats-2-4 --shard k/4`. A surviving mutant fails it: add a test, or list the mutant in `exclude_re` with the reason it is equivalent or unreachable.
  - `web/` changes: from `web/`, run `bun run lint` (0 warnings), `bun run typecheck` and `bun run test`. Use `bun run test`, never bare `bun test`.
  - Run heavy jobs with `nice -n 10`, at most two at once.
- **Git:** work on `main`. Do branch work in a worktree at `~/.t3/worktrees/buckshot/t3-<8 hex>` (never a sibling directory). Merge only verified work, with `--no-ff`.
- **Arena work** (tournaments, model endpoints, quotas, the CLIProxyAPI hub): read `docs/arena/README.md` first. Never restart CLIProxyAPI or 9router, and stop only processes you started.
  - Editing the files that play a match (`PLAY_FILES` in `web/src/arena/match.ts`) changes the arena's code hash.
- **Domain terms and decisions:** `CONTEXT.md` and `docs/adr/`.
- **Issues:** GitHub Issues on sakompella/buckshot through `gh`. Labels and conventions are in `docs/agents/`.
