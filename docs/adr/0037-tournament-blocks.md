# Tournament blocks

A tournament plays each pairing in seed blocks. A block is one seed and every permutation of the pairing's seats: 24 matches at four players, 6 at three and 2 at two. Block b of every pairing uses seed `config.seed + b`, so pairings share openings. Every entrant then takes every position equally often, and every entrant sits at every relative position to every opponent equally often. The ratings model has a seat term per table size and position, and balanced blocks keep those terms from leaking into the entrants' ratings.

Confidence intervals come from a bootstrap over seed blocks. The unit is one (pairing, block), drawn with replacement from a seeded generator, so a rerun prints the same numbers. The matches of a block share a seed and open alike, so they are not independent, and resampling single matches would give intervals that are too narrow.

## Considered Options

- Cyclic rotations of the seating, as the arena's `--rotation` makes. They give every entrant every position. At three and four players they do not give every relative position: with four seats, an entrant always sits one place before the same neighbour. A tournament runs the arena with `--rotation 0` and chooses the order itself.
- A random subset of permutations at four players. It costs less, but the balance is then only approximate, and the 24 matches of a block are cheap next to the cost of the models that play them.
- Bootstrap over single matches. Simple, but it treats the matches of one seed as independent.

## Consequences

A pairing of four models costs 24 matches per block, so a four-player tournament needs few pairings or few blocks. Two-player blocks cost 2 matches, and three-player blocks 6. A tournament stopped half way is balanced when it stops after a whole block, so the runner schedules block by block.
