# Buckshot table (web UI)

A plain web UI for the Bend multiplayer rules machine (`sim/bend-mp/sm/`),
built on Foldkit 0.167 and Effect 4, run with bun and Vite.

## Run

    bun install
    bun run dev        # builds generated/rules.mjs from sim/bend-mp/web.bend, then serves http://localhost:5173/

`bun run rules` needs Bend 2.0.36: `$BEND`, else `bend` on PATH, else the
pinned Nix store path in `scripts/build-rules.ts`.

Checks:

    bun run typecheck  # tsc --noEmit, strict
    bun run lint       # oxlint with every anti-slop rule and the Effect group, --deny-warnings
    bun run test       # plays full bot matches through bend.ts; checks stale answers are rejected
    bun scripts/play.ts [url] [outdir]   # headless Chrome: one human-vs-bot match by clicking, one 4-bot autoplay match

## Layout

- `src/bend.ts`: the only file that writes Bend tags. It decodes every Bend
  value with a Schema, turns lists and Nats into arrays and numbers, and
  tickets every request point (match number + generation) so a stale answer is
  rejected before Bend's `answer` runs.
- `src/driver.ts`: the seam for the Bend driver and AIs. Until
  `sim/bend-mp/driver.bend` and `ai/*.bend` land, draws come from a seeded RNG
  (`src/rng.ts`) and a "Bot" seat picks a random legal move.
- `src/titles.ts`: end-of-match titles from the public event log.
- `src/main.ts`: Foldkit Model, Messages, update, view, autoplay subscription.
- `tools/oxlint/anti-slop/`: vendored anti-slop rules (see PROVENANCE.md).
