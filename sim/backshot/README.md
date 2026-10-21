# Backshot move search

A clean-room Bend 2 port from a behaviour specification, with a corrected mode
and a reference mode. The reference reproduces the specified repaired program,
not the real game's rules. No original implementation was read or copied.
The rules and search are Bend; the small JavaScript entry compiles the Bend
module and handles JSON. There is no GUI or arena integration.

## Run

From the repository root, in `nix develop`:

```sh
printf '%s\n' '{"live":2,"blank":2,"playerItems":"hs"}' | bun sim/backshot/cli.mjs --reference --depth=18
printf '%s\n' '{"live":2,"blank":2,"playerItems":"hs"}' | bun sim/backshot/cli.mjs --depth=2
bun sim/backshot/test.mjs
bash sim/bend-mp/check.sh
```

The first command prints:

```json
{"depth":18,"move":"handcuff","value":"1/4","path":["handcuff","dealer","saw","dealer"],"nodes":39}
```

Fixed mode is the default. `--reference` selects the specified quirks.
`--depth=N` runs one depth, including zero. Without it the CLI independently
searches depths 1 through 18. One JSON object on stdin describes the position:

| Key | Default | Meaning |
| --- | --- | --- |
| `playerTurn` | `true` | Player maximizes, Dealer minimizes |
| `maxHealth` | `3` | Health cap |
| `dealerHp`, `playerHp` | `3` | Current health |
| `live`, `blank` | `1` | Remaining shell totals, including the known chamber |
| `shell` | `"unknown"` | `"unknown"`, `"live"` or `"blank"` |
| `dealerItems`, `playerItems` | `""` | Item letters below |
| `cuffs` | `0` | 0 free, 2 opponent not skipped, 1 opponent already skipped |
| `sawed` | `false` | Next shot has double live damage |

Items are `h` handcuffs, `s` saw, `c` cigarettes, `b` beer, `m` glass,
`a` adrenaline, `e` medicine, `f` phone and `i` inverter. Other letters are
ignored, case is ignored, duplicates and order are kept. JSON numbers must
be nonnegative safe integers. Fixed mode also rejects a load above eight,
cuffs above two, or a known chamber absent from its supplied shell total.
The Bend data API additionally exposes pending adrenaline, later known shells,
weights and the inverter flag. JSON represents the specification's CLI inputs.

Each output line contains depth, recommended move, reduced signed rational
value, path and nonterminal node count. An abort is `{"depth":N,"error":"..."}`.
No timing, prompt prose or inaccurate percentage label from the old interface
is retained. Exact rational output makes black-box comparison straightforward.
The `dealer` and `player` shot names name their target, not the mover.

## Shared implementation

- `rational.bend`: signed arbitrary-precision rational arithmetic.
- `state.bend`: position, inventory and knowledge operations.
- `model.bend`: legal candidates and item/shot outcomes, with local mode branches.
- `heuristic.bend`: the specified estimate, ordering and filters. Fixed search
  does not use their unsafe move elimination.
- `search.bend`: one search traversal for both modes.
- `runtime.mjs`, `cli.mjs`: compilation and JSON transport, no game rules.
- `test.mjs`: exact reference examples, correction witnesses and finite
  exhaustive property checks, following the existing compiled-Bend test style.

Reference mode preserves zero-probability outcomes, path weights, choice over
chance, ascending stable move ordering, strict ties, the shoot-player filter,
forced invalid moves, and the original terminal estimate. Error results replace
exceptions for missing glass after beer, an oversized phone index and a zero
health denominator. No transposition table is used. A structural fuel bound
makes recursion total in Bend and reports exhaustion rather than returning an
incorrect evaluation. It allows 256 interpreter frames per shot or held item,
plus two units of slack. It does not change the shot-depth horizon.

## Fixed mode decisions

The Dealer is an adversarial minimizer. This is a worst-case opponent, not a
claim about the game's Dealer AI. Reproducing that AI would be a separate task.
Both sides choose a legal move, then chance chooses an outcome with its exact
probability. Values are conditional on the present state, not path-weighted.
No alpha-beta bound crosses a chance node. This implementation uses full-width
expectiminimax with no pruning, the simplest sound choice for these small loads.
Items do not spend depth; shots do. Item-heavy depth-18 positions can therefore
be expensive. There is no time limit or memoization.

Leaves use Player HP / total HP, with Player death 0, Dealer death 1 and both
dead 1/2. An empty load is a leaf, not a new randomized load. This is a bounded
position score, not a calibrated probability of winning a whole round.
The old kill estimate is deliberately confined to reference mode because it
can exceed its stated range and scores a dead Dealer below a certain win.
Fixed mode continues through known-live and all-blank loads rather than ending
when the unknown live count reaches zero.

Corrections and their witnesses in `test.mjs`:

| Correction | Evidence | Test difference |
| --- | --- | --- |
| Cigarettes heal one up to cap | `../bend-mp/ref/main.bend:842-850,868-870`; `../../docs/accuracy-report.md:189` | HP 1 becomes 2, not 3; full health stays 3, not 4 |
| Medicine is 50/50, heal two capped, lose one on failure; no shells change | `../../docs/accuracy-report.md:194,300`, which records current official v1.2.1 odds | HP 2 becomes 3 or 1, not 3 or 0; probabilities 1/2 rather than 2/5 and 3/5 |
| Beer consumes beer and preserves saw | `../bend-mp/ref/main.bend:819-832`; `../../docs/accuracy-report.md:188,200` | Beer alone works, inventory loses beer; no missing-glass abort |
| Glass/phone knowledge reserves a shell from unknown counts; a shot consumes it only once | `../bend-mp/ref/main.bend:826-832,800-809`; `../../docs/accuracy-report.md:187` | Revealed last live remains playable; count invariant holds |
| Known blank is certain blank | `../bend-mp/ref/main.bend:637-638`; `../bend-mp/ref/rules.bend:202-209`, shots read the actual chamber | No damaging branch at a known blank |
| Inverter flips chamber; unknown inversion changes its next draw, not an invented observed shell | `../bend-mp/ref/main.bend:832-833`; `../../docs/accuracy-report.md:192` | Known blank becomes live; unknown 1 live / 2 blank becomes live probability 2/3 |
| Phone never selects the chamber and has total probability one | `../../docs/accuracy-report.md:191,204,233` | Two-shell Player phone reveals slot 1; Dealer gets no clue; probability total 1 instead of 2 |
| Handcuffs have a target, skip one attempted handoff, ignore self-blank shots, then lift on the next handoff | `../../docs/accuracy-report.md:190,202`; `../bend-mp/README.md` D16 | Self blank keeps cuffs 2 rather than consuming one; cuffs 1 no longer grants another skipped turn |
| Obvious saw rule reads the opponent's health on both sides | `../../docs/accuracy-report.md:186`, live damage is 2 against either target | Dealer HP 1 / Player HP 2 suggests saw rather than a single shot |
| All legal shots considered, no forced invalid move or heuristic omission | Search correctness, not a game-rule claim | Cuffed handcuff case has a bounded legal answer rather than -1000000 |
| Chance outcomes are averaged; zero-probability branches omitted | Expectiminimax definition | Independent brute-force traversal agrees on small positions with items |
| Terminal division by zero is a draw; explicit death scores | Evaluation decision above | Both dead gives 1/2 rather than abort |
| Adrenaline only starts with a usable steal | `../bend-mp/ref/items.bend:141-150,187-192`, M4 in `../bend-mp/README.md` | Dead-end inventory combinations cannot strand search without a move |

The phone follows single-player evidence in `docs/accuracy-report.md:191,204,233`.
Player selects uniformly from zero-based slots 1..N-1, with no clue at one
shell. Dealer receives no clue below three shells and otherwise learns a random
later shell. Multiplayer differs at `ref/main.bend:784-809`. The audit's local
source predates v1.2.2 Hotfix 1, which fixed rare wrong phone information;
`docs/accuracy-report.md:205,301-303` records that limitation. This port uses
actual shell indices, not the historical duplicate display-label anomaly.
No other requested discrepancy lacked repository evidence.

Unknown counts mean *unrevealed* shells in fixed mode. Revealing moves reserve
one live or blank and leave the physical load unchanged. Known shells shift
with ejection or firing. For an unknown inverted chamber a latent flip preserves
the original composition until that shell is revealed or consumed; the outgoing
shell probability and type are flipped. Inverter may be used again if another
copy is held. This avoids treating inversion itself as an information reveal.
Both searchers have shared knowledge after a reveal, as in the specification;
this is perfect-information expectiminimax over that knowledge, not a solution
to the game's private-information strategy problem.

## Checks

The reference suite covers all section 7 examples, including exact ordering
keys, all 14 move/value/path/node results, and all three abort paths. Fixed
mode also checks 2,808 signed rational arithmetic combinations and exhaustively checks 858 outcome distributions for normalization, 1,261
physical shell-count transitions, 78 bounded search values and 162 independent
brute-force expected values. Deterministic finite enumeration is used instead
of an external property-test package because these small domains can be covered
completely. These are tests, not kernel proofs of search correctness.
`sim/bend-mp/check.sh` calls this suite before its existing gates.
