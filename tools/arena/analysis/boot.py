"""Seed-block bootstrap: whole blocks are drawn with replacement, never single matches or seat swaps."""

import random


def weights(blocks: list[str], rng: random.Random) -> dict[str, int]:
    """How often each block is drawn in one resample of the same size."""
    counts: dict[str, int] = {}
    for _ in blocks:
        pick = rng.choice(blocks)
        counts[pick] = counts.get(pick, 0) + 1
    return counts


def quantile(sorted_values: list[float], level: float) -> float:
    at = level * (len(sorted_values) - 1)
    low = int(at)
    high = min(low + 1, len(sorted_values) - 1)
    return sorted_values[low] + (sorted_values[high] - sorted_values[low]) * (at - low)


def interval(values: list[float]) -> tuple[float, float] | None:
    """The central 95% of the replicates, or None when there are too few to say."""
    if len(values) < 20:
        return None
    ordered = sorted(values)
    return quantile(ordered, 0.025), quantile(ordered, 0.975)
