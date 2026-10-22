"""Position and round 1 starter effects, matched within seed blocks.

A complete seed block is two matches of one pair and one seed with the seats swapped. The seed also decides which
position opens round 1, so both matches of a block have the same starter position. Averaging the two matches of a
block cancels who the entrants are, leaving the seat. Half blocks (one match) cannot be matched and are left out.
"""

import random
from dataclasses import dataclass

import boot
from load import Game, blocks_of


@dataclass(frozen=True)
class Block:
    """A complete block: position 1's mean share over the two matches, and the starter's."""

    id: str
    seed: int
    code: str  # the code hash of both matches, or "mixed"
    models: tuple[str, ...]
    first_share: float
    starter_share: float
    starter: int
    first_wins: float  # fractional wins of position 1, over the block's two matches
    starter_wins: float


def complete_blocks(games: list[Game], model_of: dict[str, str]) -> tuple[list[Block], int]:
    """The complete blocks, and the number of matches left out in half blocks."""
    blocks, left_out = [], 0
    for block_id, pair in sorted(blocks_of(games).items()):
        if len(pair) != 2:
            left_out += len(pair)
            continue
        a, b = pair
        if (a.first, a.second) != (b.second, b.first) or a.starter != b.starter:
            raise ValueError(f"block {block_id} does not swap seats on one starter position")
        starter_wins = sum(g.share_first if g.starter == 1 else 1 - g.share_first for g in pair)
        first_wins = a.share_first + b.share_first
        models = tuple(sorted({model_of[a.first], model_of[a.second]}))
        blocks.append(Block(block_id, a.seed, a.code if a.code == b.code else "mixed", models, first_wins / 2, starter_wins / 2, a.starter, first_wins, starter_wins))
    return blocks, left_out


def mean(values: list[float]) -> float:
    return sum(values) / len(values)


def estimates(blocks: list[Block]) -> dict[str, float]:
    """Position 1's share and the starter's, plus the two effects with the other held equal.

    With a1 and a2 the mean share of position 1 over blocks where position 1 / 2 starts,
    seat = (a1 + a2) / 2 - 1/2 and starter = (a1 - a2) / 2, each strata weighted equally.
    """
    out = {"first": mean([b.first_share for b in blocks]), "starter": mean([b.starter_share for b in blocks])}
    one = [b.first_share for b in blocks if b.starter == 1]
    two = [b.first_share for b in blocks if b.starter == 2]
    if one and two:
        out["seat"] = (mean(one) + mean(two)) / 2 - 0.5
        out["start"] = (mean(one) - mean(two)) / 2
    return out


def bootstrap(blocks: list[Block], count: int, rng: random.Random, by_seed: bool = False) -> dict[str, tuple[float, float] | None]:
    """Intervals drawing whole blocks, or (by_seed) whole seeds with every block played at them in any pairing."""
    groups: dict = {}
    for b in blocks:
        groups.setdefault(b.seed if by_seed else b.id, []).append(b)
    units = list(groups.values())
    draws: dict[str, list[float]] = {}
    for _ in range(count):
        picked = [b for _ in units for b in rng.choice(units)]
        for name, value in estimates(picked).items():
            draws.setdefault(name, []).append(value)
    return {name: boot.interval(values) for name, values in draws.items()}
