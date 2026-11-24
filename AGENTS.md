# Buckshot

Research on Buckshot Roulette. A multiplayer rules library in Bend, agent tools, and an arena where models play each other, with a site that shows its results.

## Rules

- Bend (`sim/bend-mp/`) is the source of truth for the game rules.
- TypeScript calls Bend exports and never re-implements rules.
- The Rust evaluator (`sim/rust/`) is verified against Bend. Bend wins any disagreement.
- `CONTEXT.md` defines the domain terms. Use them in code, comments and commit messages.

## Toolchain

- Use `nix develop`. It pins Bend 2.0.40, bun, Python and Rust.
- Run heavy jobs (`buckshot-search`, `score_regret.py`, `aivat.py`, imports, `cargo test`, mutants, `check.sh`) through `dev heavy --mem SIZE --`, with the peak memory declared.

## Checks

Run the checks for what you changed before you commit.

- `sim/bend-mp/` runs `bash sim/bend-mp/check.sh`.
- `sim/rust/` runs `cargo test` and `cargo test --no-default-features --features f32,seats-2-4` from `sim/rust/`. Run `bash sim/rust/check.sh` for Bend parity. Never use `--all-features` (see `sim/rust/features.sh`). Install the hook once per clone with `bash sim/rust/install-hooks.sh`.
- `web/` runs `bun run lint`, `bun run typecheck` and `bun run test` from `web/`. Never run bare `bun test`. The script builds the rules and sets the test code id.
- `tools/arena/` and `dev/` run `nix build .#checks.x86_64-linux.arena-python`. It covers ruff check, ruff format, ty and the tests.

## Git

- Work on `main`. Do branch work in a git worktree.
- Merge only verified work, with `--no-ff`.
- Commit code and docs only. Keep game assets, game text, tournament data, account ids, emails and API keys out of the tree.
- Keep status notes, progress logs and plans out of commits.
