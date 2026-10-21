# Code from unlicensed sources is rewritten clean-room

A source with no license grant is all rights reserved, so a direct port is a derivative we may not publish. Its ideas are instead rewritten clean-room:
- **One agent** reads the source and writes a behaviour specification. It describes inputs, state, rules, search, constants, quirks, and worked examples computed by running the original. It copies no code and no identifiers beyond the game's own terms.
- **A second agent** that never sees the source implements from the specification alone. Questions go back to the first agent, which answers in words.
- **Fidelity:** a reference mode reproduces the specification's examples exactly. A source-aware agent checks it against the original as a black box.
- **Corrections:** a fixed mode corrects errors against the repo's own rules evidence.

The first case is github.com/redstone59/BackshotRoulette, ported as `sim/backshot/`.

## Considered Options

- **Ask the author for a license.** This is cleanest, but it waits on someone else. It's still worth doing.
- **Port it and keep it local** in `_work/`. That works for private findings, but can't be committed.
- **Write a new bot from scratch** without studying the original. This loses the parity check that shows which behaviours were errors.

## Consequences

The specification (`sim/backshot/SPEC.md`) is committed; the original's code and any repaired copy never are. Reference mode keeps the original's quirks, so it shouldn't be used for analysis; fixed mode is the default.
