# Engine anchors

> Accepted 2026-11-08; written down 2026-11-11.

An engine entrant (`{"engine": {"depth": 2, "budget": 20000}}`) is the Rust search of ADR-0052, played as an arena seat. It decides from the player's own log and the public board, as the regret scorer does, values every move unpruned and plays the first best one. It sits on the same rating scale as the models, so it works as an anchor: a fixed, reproducible player that costs no model calls and does not change when a provider changes a model. Its seat is named `Engine/<depth>/<budget>`, with `/sampled` when reloads are valued over sampled deals. The anchors played are depth 2 (weak), depth 6 with sampled reload (strong) and depth 7 with sampled reload and a 2,000,000-node budget (`Engine/7/2000000/sampled`), the zero of the rating scale. The depth-7 engine plays only engines (tournament 14), so it costs nothing to pin down; its budget is large enough that it reaches depth 7 on 95% of its moves (at 20,000 nodes the budget stops depth 6 on 28% of decisions), at about 2.5 s a move. The code is `web/src/arena/engine.ts`; the setup is in `docs/arena/README.md`.

## Considered Options

- **The Bend minimax player (ADR-0043) or the DoN bot as anchors.** The Bend player is too slow to play every move, and DoN is a different, weaker kind of player. The Rust search is fast (about 20 ms a move with the static reload rule) and is the same search that scores regret.
- **No anchors.** Ratings would stay relative to the models in the pool, and a rating would mean nothing outside it.

## Consequences

- An engine plays two-seat pairings only. If its root moves differ from Bend's menu, or the search fails, the match stops and writes a dump (ADR-0052).
- The strong engine plays the move its own scorer rates best, so its regret is zero by construction. Its rating is not an upper bound: the scorer is a depth-limited search, and a model may play at or above its level. It is a yardstick, not a ceiling.
- An anchor's rating rests on few matches against few opponents, so its interval is wide (see tournaments 10 and 11 in `docs/arena/results.md`).
- The zero was the depth-2 engine until 2026-11-14. Moving it to the depth-7 engine shifts every rating by one constant and leaves every gap and tier as it was. The zero's own uncertainty is shown once, as that engine's interval against the mean config.
