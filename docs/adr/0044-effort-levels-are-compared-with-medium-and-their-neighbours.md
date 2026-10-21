# Effort levels are compared with medium and their neighbouring levels

An effort sweep for a model whose medium entrant already has cross-model ratings plays each new level against medium and against the next level up and down. For Opus 5.5 that's low–medium, medium–high, medium–xhigh, high–xhigh, then medium–max and xhigh–max. That's 6 pairings instead of the 10 of a full round robin. Each pairing plays the same 10 seeds in both seat orders, and the seeds are fixed before any match is played. A follow-up matchup against another model reuses that model's earlier seeds first, for a matched comparison, then adds fresh seeds in a fixed order up to a fixed cap.

## Considered Options

- **Full round robin of every level.** The extra pairings are the ones with the widest effort gaps, which carry the least information per game. The design is already connected, and the cost grows mostly in the expensive max pairings.
- **Each level against medium only (a star).** This is cheapest, but every level then inherits medium's noise, and nothing checks consistency between neighbours.
- **No same-model matches,** with every level playing other models. Effort gaps are then inferred indirectly through other opponents, with wider intervals. Benchmarks such as Kaggle Game Arena skip self-play, but different effort levels are different entrants, not self-play.

## Consequences

Ratings for a model's levels sit on the cross-model scale through medium. Close levels, such as high and xhigh, get a direct comparison. A cap that ends between seed groups leaves the remaining seeds unplayed rather than half a group. Results are never used to choose seeds or decide when to stop.
