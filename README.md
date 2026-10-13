# buckshot

Research on Buckshot Roulette, with a rules library for its multiplayer mode.

## Contents

- [`sim/bend-mp/`](sim/bend-mp/README.md) is the multiplayer rules library for 2 to 4 seats, written in Bend. It has a state machine, a faithful reference, laws that tie the two together, and two dealer AIs. Start with its README.
- [`web/`](web/README.md) is a web UI for the library. It plays matches in the browser against the Story and DoN AIs.
- `sim/python/dealer_vs_dealer.py` is the 2-player policy simulation that the AIs were ported from.
- [`docs/accuracy-report.md`](docs/accuracy-report.md) audits a third-party Python simulator of the game. It does not cover the Bend library.
- [`docs/modding-and-macos-port.md`](docs/modding-and-macos-port.md) records an attempt to build a modded macOS app from the decompiled game.
- `scripts/` holds the accuracy checks and the macOS rebuild script.

## Quick start

    nix develop
    bash sim/bend-mp/check.sh      # about 7 minutes on a Mac
    bend sim/bend-mp/main.bend     # play matches and print win rates
    cd web && bun install && bun run dev

The dev shell provides Bend 2.0.36, bun, python3 and uv.

## What stays local

Decompiled game code, the decision log and the Godot comparison harness live under `_work/` and `.audit/`. Git ignores both. They are not in this repository.
