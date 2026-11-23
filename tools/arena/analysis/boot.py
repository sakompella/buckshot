"""Seed-block bootstrap: whole blocks are drawn with replacement, never single matches or seat swaps."""

import random
from collections.abc import Hashable

DRAWS = 2000  # resamples per bootstrap interval, as BOOTSTRAP_DRAWS in web/src/arena/bootstrap.ts


def weights[T: Hashable](blocks: list[T], rng: random.Random) -> dict[T, int]:
    """How often each block is drawn in one resample of the same size."""
    counts: dict[T, int] = {}
    for _ in blocks:
        pick = rng.choice(blocks)
        counts[pick] = counts.get(pick, 0) + 1
    return counts


def quantile(sorted_values: list[float], level: float) -> float:
    at = level * (len(sorted_values) - 1)
    low = int(at)
    high = min(low + 1, len(sorted_values) - 1)
    return sorted_values[low] + (sorted_values[high] - sorted_values[low]) * (at - low)


# The share of replicates a rating interval covers: about one in ten true values falls outside. The viewer's INTERVAL_LEVEL
# (web/src/arena-viewer/page/ratings.ts) is the same number.
LEVEL = 0.90
PERCENT = f"{round(LEVEL * 100)}%"
TAIL = (1 - LEVEL) / 2


MIN_REPLICATES = 20


def bounds(values: list[float], tail: float = 0.025) -> tuple[float, float]:
    """The central 95% of the replicates (rating intervals pass `TAIL`); fewer than MIN_REPLICATES is an error."""
    if len(values) < MIN_REPLICATES:
        raise ValueError(f"{len(values)} replicates are too few for an interval")
    ordered = sorted(values)
    return quantile(ordered, tail), quantile(ordered, 1 - tail)


def interval(values: list[float], tail: float = 0.025) -> tuple[float, float] | None:
    """`bounds`, or None when there are too few replicates to say."""
    return bounds(values, tail) if len(values) >= MIN_REPLICATES else None
