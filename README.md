# buckshot

Research on Buckshot Roulette, with a rules library for its multiplayer mode.

## Contents

- [`sim/bend-mp/`](sim/bend-mp/README.md) is the multiplayer rules library for 2 to 4 seats, written in Bend. It has a state machine, a faithful reference, laws that tie the two together, and two dealer AIs. Start with its README.
- [`sim/rust/`](sim/rust/) is a Rust mirror of the rules and a search over them, checked against Bend. The arena's engine entrant and regret scoring use it.
- [`web/`](web/README.md) is the site (the Play and Arena pages), the arena runner and the arena viewer.
- `sim/python/dealer_vs_dealer.py` is the 2-player policy simulation that the AIs were ported from.
- [`docs/arena/`](docs/arena/README.md) is the runbook and results for the arena, where language models play each other through the agent tools. `tools/arena/` holds the wrap-up, regret scoring, match checks and the statistics (`tools/arena/analysis/`).
- `dev/` is the `dev` CLI and the Python environment for `tools/arena`.
- [`docs/adr/`](docs/adr/) holds the decisions and [`CONTEXT.md`](CONTEXT.md) the domain terms.

## Quick start

    nix develop
    bash sim/bend-mp/check.sh      # about 7 minutes on a Mac
    bend sim/bend-mp/main.bend     # play matches and print win rates
    cd web && bun install && bun run dev

The dev shell provides Bend 2.0.40, bun, python3 and uv.

## What stays local

Decompiled game code, the decision log and the Godot comparison harness live under `_work/` and `.audit/`. Git ignores both. They are not in this repository.
