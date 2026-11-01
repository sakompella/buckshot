# Buckshot

Research on Buckshot Roulette: a multiplayer rules library in Bend, a browser table, agent tools, and an arena where models play each other.

- **Unfinished work** and what each branch needs next: `_work/work-in-progress.md` (local, gitignored). Read it first when it exists.
- **Rules live only in Bend** (`sim/bend-mp/`). TypeScript may call Bend exports but never re-implements rules.
- **Never commit** decompiled game code, original game assets or text, raw tournament data, anything under `_work/` or `.audit/`, or in-progress trackers (status notes, progress logs, handoffs, plans). Trackers go in `_work/` or `_*.md`. If one gets committed on a branch, purge it from the branch's history before the merge. Account ids and emails stay out of committed files.
- **Toolchain:** `nix develop` gives the pinned Bend 2.0.36, bun and Python.
- **Before committing:**
  - Bend changes: `bash sim/bend-mp/check.sh`.
  - `web/` changes: from `web/`, run `bun run lint` (0 warnings), `bun run typecheck` and `bun run test`. Use `bun run test`, never bare `bun test`.
  - Run heavy jobs with `nice -n 10`, at most two at once.
- **Git:** work on `main`. Do branch work in a worktree at `~/.t3/worktrees/buckshot/t3-<8 hex>` (never a sibling directory). Merge only verified work, with `--no-ff`.
- **Arena work** (tournaments, model endpoints, quotas, the CLIProxyAPI hub): read `docs/arena/README.md` first. Never restart CLIProxyAPI or 9router, and stop only processes you started.
  - Editing the files that play a match (`PLAY_FILES` in `web/src/arena/match.ts`) changes the arena's code hash.
- **Domain terms and decisions:** `CONTEXT.md` and `docs/adr/`.
- **Issues:** GitHub Issues on sakompella/buckshot through `gh`. Labels and conventions are in `docs/agents/`.
