"""Seed-block bootstrap: whole blocks are drawn with replacement, never single matches or seat swaps."""

import random

DRAWS = 2000  # resamples per bootstrap interval, as BOOTSTRAP_DRAWS in web/src/arena/bootstrap.ts


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


# The share of replicates a rating interval covers: about one in ten true values falls outside. The viewer's INTERVAL_LEVEL
# (web/src/arena-viewer/page/ratings.ts) is the same number.
LEVEL = 0.90
PERCENT = f"{round(LEVEL * 100)}%"
TAIL = (1 - LEVEL) / 2


def interval(values: list[float], tail: float = 0.025) -> tuple[float, float] | None:
    """The central 95% of the replicates (rating intervals pass `TAIL`), or None when there are too few to say."""
    if len(values) < 20:
        return None
    ordered = sorted(values)
    return quantile(ordered, tail), quantile(ordered, 1 - tail)
