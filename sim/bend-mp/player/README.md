# Multiplayer search player

A pure Bend 2 player for `../simple/`, separate from the single-player simulator. See [ADR-0043](../../../docs/adr/0043-a-bounded-player-searches-beliefs-over-the-simple-machine.md).

## Input and output

`Position{config, board, log, me}` contains the public match configuration, current public board, and the complete chronological `List<Heard>` for `me`. Build `log` with `domain.hear` as the match runs. It must include `RoundBegan` and `Loaded`; do not pass only the latest answer's notes. It contains no hidden shell order, deck or RNG.

`analyse(position, depth, budget)` returns either an input/belief error or every legal move with a fixed-point score and principal variation, the best move/index, expanded node count, completed depth and a budget flag. PVs name player decisions. At chance nodes they follow one representative observation branch, not a prediction of random outcomes. Ties keep the first canonical legal move.

`choose(position, Level{depth, budget, gap, seed})` calls the same analysis and returns a seeded pick among moves no more than `gap` below best. Set gap to zero for best play. Equal best moves may vary with seed. `regret(analysis, index)` reports best minus chosen score. Invalid indices return no score rather than clamp to another move.

## Modules

- `belief.bend` reconstructs synthetic states from public information, enumerates shell orders, replays observations and groups outcomes.
- `evaluation.bend` holds all starting weights and the static win-share estimate.
- `search.bend` does bounded paranoid expectiminimax and iterative deepening.
- `policy.bend` selects a move from completed analysis.
- `main.bend` is the stable export entry point.

## Score and starting weights

Internal win probability is 0 to 1,000,000. Display win percent as `score / 10_000`; regret uses percentage points with the same divisor. Exact current-round terminal wins score 1,000,000, losses 0. This does not estimate who wins the three-round cash total.

The cutoff estimate normalizes effective health over living players. One HP is 100 weight units. Starting item values in HP units are saw 0.65, glass 0.60, jammer 0.90, cigarettes 0.75, beer 0.25, phone 0.30, inverter 0.45, adrenaline 0.80, remote 0.15. Tempo is 0.35 HP, a known chamber is 0.25 HP, and a pending jam discounts 0.50 HP. Dead players always score zero. The evaluator has no random input. These weights are deliberately simple, untrained starting values and must not be tuned to the smoke comparison.

## Calling from JavaScript or TypeScript

Build with the pinned dev shell, from the repository root:

    nix develop -c bend sim/bend-mp/player/main.bend -o /tmp/buckshot-player.mjs

The default export is the Bend export table, as in `../web.bend`. Call `analyse`, `choose` and `regret` from that table. Domain tags are `../domain.*`, simple move tags are `../simple/state.*`, and player types have their module prefix. JavaScript callers only marshal values and call exports. They do not rebuild rules or beliefs. This task does not wire the player into the web or arena.

## Verification

Run `nice -n 10 nix develop -c bun sim/bend-mp/test/player.mjs` for focused scenarios, information equivalence, chance normalization, budget termination and determinism. `check.sh` includes that check. The optional `--strength` comparison uses the existing driver's RNG and DoN/Story decisions against whole simple moves. It makes no model or API calls.
