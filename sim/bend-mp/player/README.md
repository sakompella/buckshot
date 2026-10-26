# Multiplayer search player

A pure Bend 2 player for `../simple/`, separate from the single-player simulator. See [ADR-0043](../../../docs/adr/0043-minimax-player.md).

## Input and output

`Position{config, board, log, me}` contains the public match configuration, current public board, and the complete chronological `List<Heard>` for `me`. Build `log` with `domain.hear` as the match runs. It must include `RoundBegan` and `Loaded`; do not pass only the latest answer's notes. It contains no hidden shell order, deck or RNG.

`analyse(position, depth, budget, reload)` returns either an input/belief error or every legal move with a fixed-point score and principal variation, the best move/index, expanded node count, completed depth and a budget flag. A line's score is its value over `me`'s private belief. Ties keep the first canonical legal move.

A PV starts with the line's own move and then names the player decisions that follow, so it holds at most `depth` moves. At a chance node it follows the private observation branch with the highest probability. That branch is the most likely one, not a prediction of the random outcome.

`choose(position, Level{depth, budget, gap, seed})` calls the same analysis and returns a seeded pick among moves no more than `gap` below best. Set gap to zero for best play. Equal best moves may vary with seed. `regret(analysis, index)` reports best minus chosen score. Invalid indices return no score rather than clamp to another move.

## Search

Depth counts decisions, by every player. One node is one world in which a move is played. The budget is checked before a move is expanded, and a move that does not fit spends the iteration. Iterative deepening publishes only finished depths: a spent budget returns the last finished depth with `limited` set.

If not even depth 1 finishes, the result is the depth-0 fallback. Every move gets the same static value, that of the belief before any move, with depth 0 and `limited` set. Its PVs are the moves alone. `analyse` with depth 0 returns the same lines, with `limited` clear.

The searcher maximizes its private value. An opponent takes the move with the lowest public value, so it never uses the searcher's clues, and the searcher's private value is then read off that move.

After a move, worlds are grouped by what the public and the searcher observe. Only the phone's draw is expanded as chance. A node is a leaf, valued by the static evaluation, in three cases:

- **No depth left.**
- **The round ended.** The value is exact: 1,000,000 if `me` won the round, 0 if not. This holds even when the next round began without a draw and already waits on a choice.
- **A reload needs a draw.** A move that empties the gun, by a shot or an ejected shell, stops at the reload's first draw (`NeedTurnAmount`, `NeedItem`, `NeedBatch` or `NeedSwap`). A fully deterministic reload can finish in the same answer, and search continues at its next choice. Expanding random item and batch draws multiplies the branches beyond a useful budget. The `reload` argument says how the leaf is valued:
  - `Static`: the state as it stands, before the draw is resolved. `choose` always uses it.
  - `ExpectedDeal` (two seats only; at three or four `analyse` is invalid): the static evaluation averaged over every distinct deal, as `deal.bend` enumerates it. The machine answers each draw with every value until the next choice. States that differ only in where items sit in the slots, or in the order of the shells, are merged, so each deal is carried once with its probability. The batch and the shuffle read and write no slot, so each load is drawn once for all the ways the items came out. It is exact and slow: see `docs/arena/analysis/regret.md`.
  - `Sampled{count}` (two seats only; at least one deal): the static evaluation averaged over `count` deals drawn at random, each draw answered with a value picked uniformly as the machine asks for it. Each start of the deal seeds its own draws from its key, so a leaf draws the same deals whenever it is valued.

  A deal leaf costs no nodes, so every rule searches the same tree.

## Modules

- `belief.bend` reconstructs synthetic states from public information, enumerates shell orders, replays observations and groups outcomes.
- `evaluation.bend` holds all starting weights and the static win-share estimate.
- `search.bend` does bounded paranoid expectiminimax and iterative deepening.
- `deal.bend` enumerates or samples a reload's deals for the deal leaves.
- `policy.bend` selects a move from completed analysis.
- `main.bend` is the stable export entry point.

## Score and starting weights

Internal win probability is 0 to 1,000,000. Display win percent as `score / 10_000`; regret uses percentage points with the same divisor. Exact current-round terminal wins score 1,000,000, losses 0. This does not estimate who wins the three-round cash total.

The cutoff estimate normalizes effective health over living players. One HP is 100 weight units. Starting item values in HP units are saw 0.65, glass 0.60, jammer 0.90, cigarettes 0.75, beer 0.25, phone 0.30, inverter 0.45, adrenaline 0.80, remote 0.15. Tempo is 0.35 HP, a known chamber is 0.25 HP, and a pending jam discounts 0.50 HP. Dead players always score zero. The evaluator has no random input. These weights are deliberately simple, untrained starting values and must not be tuned to the smoke comparison.

## Calling from JavaScript or TypeScript

Build with the pinned dev shell, from the repository root:

    nix develop -c bend sim/bend-mp/player/main.bend -o /tmp/buckshot-player.mjs

The default export is the Bend export table, as in `../web.bend`. Call `analyse`, `choose` and `regret` from that table. Domain tags are `../domain.*`, simple move tags are `../simple/state.*`, and player types have their module prefix. JavaScript callers only marshal values and call exports. They do not rebuild rules or beliefs. The player is not wired into the web table or the arena's play. The analysis scripts call it through `../analysis.bend` (`web/src/analysis/player.ts`), which sits beside `../web.bend` so that its domain tags are `domain.*`, the same as the rules build's: a board or config from that build passes in unchanged.

## Verification

Inside `nix develop`, from the repository root:

    nice -n 10 bun sim/bend-mp/test/player.mjs

`check.sh` runs it as a gate. It plays seeded random games of the simple machine and takes every choice point as a position, built from the mover's own log. On those positions it checks:

- Outcome probabilities sum to one, and the branches match an independent JavaScript grouping of the notes.
- Score bounds, the best line, the node budget, and that only a spent budget stops short.
- A score of 1,000,000 or 0 at depth 1 really wins or loses the true game, and depths 2 and 3 keep every depth-1 forced win.
- A budget-limited run equals a fresh run to its finished depth.
- `choose` is deterministic for a seed and stays within the gap, and `regret` is 0 for the best move and absent past the menu.
- Public scores, which opponents decide by, do not change when `me`'s clues are removed from the log.
- Scripted games: a forced win; a round won where the next round starts without a draw, which stays exact at depths 1 to 3; and a belief past 100 loads, which stays normalized.
- A seat which is not to move gets no analysis.
- The expected-deal leaf: on a fixed load of one live and one blank shell with saw and beer as the only items, a shot on the last shell scores the mean of the static values of the four deals, played out by hand. On small decks it equals a plain enumeration of every draw sequence, with no merging. Sampled deals' mean lies within four standard errors of the exact one, the error taken from the plain enumeration. With more shells than the search's depth every rule scores alike, and at three or four seats both deal leaves are invalid.

`PLAYER_GAMES` sets the games for each table size (default 2, about a minute). Use `PLAYER_GAMES=4` for an occasional deeper run of about two minutes. `PLAYER_PROFILE=1` also prints the seconds spent in each check.
