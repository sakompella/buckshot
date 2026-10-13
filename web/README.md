# Buckshot table (web UI)

A plain web UI for the Bend multiplayer rules library in `sim/bend-mp/`, built
on Foldkit 0.167 and Effect 4 and run with bun and Vite. It builds `web.bend` to
JavaScript and plays 2- to 4-seat matches in the browser. Any seat can be a
human, a Story AI or a DoN AI. The UI has no rules of its own. Legality,
observation and privacy all come from the machine. See
[`sim/bend-mp/README.md`](../sim/bend-mp/README.md) for the rules library.

## Run

    bun install
    bun run dev        # builds generated/rules.mjs from sim/bend-mp/web.bend, then serves http://localhost:5173/

`bun run rules` needs Bend 2.0.36: `$BEND`, else `bend` on PATH, else the
pinned Nix store path in `scripts/build-rules.ts`. `nix develop` at the repo
root provides it.

Checks:

    bun run typecheck  # tsc --noEmit, strict
    bun run lint       # oxlint with every anti-slop rule and the Effect group, --deny-warnings
    bun run test       # plays full Story and DoN matches through bend.ts at 2, 3 and 4 seats; checks stale answers are rejected
    bun scripts/play.ts [url] [outdir]   # headless Chrome: one human-vs-bot match by clicking, one 4-bot autoplay match

## Layout

- `src/bend.ts`: the only file that writes Bend tags. It decodes every Bend
  value with a Schema, turns lists and Nats into arrays and numbers, and
  tickets every request point (match number + generation) so a stale answer is
  rejected before Bend's `answer` runs.
- `src/driver.ts`: runs a match between controllers. Story and DoN seats decide
  through the Bend entry points that `sim/bend-mp/driver.bend` uses, each with
  its own coin stream. A human seat picks from the legal moves the
  machine offers. Game draws come from a seeded RNG (`src/rng.ts`).
- `src/titles.ts`: end-of-match titles from the public event log. Titles are a UI
  feature. The rules library does not compute them.
- `src/main.ts`: Foldkit Model, Messages, update, view, autoplay subscription.
- `tools/oxlint/anti-slop/`: vendored anti-slop rules (see PROVENANCE.md).
