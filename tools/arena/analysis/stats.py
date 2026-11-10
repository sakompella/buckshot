"""Statistics shared by the analysis scripts: rank correlation and the stratified draw and estimate type."""

import math
import random
import statistics
from collections.abc import Callable, Hashable, Mapping, Sequence
from dataclasses import dataclass
from typing import Protocol


def pearson(xs: list[float], ys: list[float]) -> float:
    """Pearson's r; nan when either list has no spread."""
    mx, my = statistics.fmean(xs), statistics.fmean(ys)
    cov = sum((x - mx) * (y - my) for x, y in zip(xs, ys, strict=True))
    spread = math.sqrt(sum((x - mx) ** 2 for x in xs) * sum((y - my) ** 2 for y in ys))
    return cov / spread if spread > 0 else math.nan


def ranks(values: list[float]) -> list[float]:
    """Ranks from 1, tied values sharing the mean of their ranks."""
    ordered = sorted(range(len(values)), key=values.__getitem__)
    out = [0.0] * len(values)
    i = 0
    while i < len(ordered):
        j = i
        while j + 1 < len(ordered) and values[ordered[j + 1]] == values[ordered[i]]:
            j += 1
        for k in range(i, j + 1):
            out[ordered[k]] = (i + j) / 2 + 1
        i = j + 1
    return out


def spearman(xs: list[float], ys: list[float]) -> float:
    return pearson(ranks(xs), ranks(ys))


@dataclass(frozen=True)
class Estimate:
    mean: float
    half_width: float  # of a 95% interval


def split_evenly(total: int, sizes: dict[str, int]) -> dict[str, int]:
    """Shares of `total` equal across the keys, where a key never gets more than its size and its unused share goes to the others."""
    shares = {key: 0 for key in sizes}
    open_keys = [key for key in sizes if sizes[key] > 0]
    left = min(total, sum(sizes.values()))
    while left > 0:
        each, extra = divmod(left, len(open_keys))
        for index, key in enumerate(open_keys):
            shares[key] = min(sizes[key], shares[key] + each + (1 if index < extra else 0))
        left = min(total, sum(sizes.values())) - sum(shares.values())
        open_keys = [key for key in open_keys if shares[key] < sizes[key]]
    return shares


class Modelled(Protocol):
    @property
    def model(self) -> str: ...


def draw[D: Modelled, C: Hashable](decisions: Sequence[D], per_cell: Mapping[C, int], lists: int, seed: int, cell_of: Callable[[D], C]) -> list[list[D]]:
    """`per_cell` decisions for each `cell_of` cell, spread equally over the models, dealt into `lists` lists that each hold an equal share of every stratum."""
    rng = random.Random(seed)
    out: list[list[D]] = [[] for _ in range(lists)]
    turn = 0
    for cell in sorted(per_cell):
        by_model: dict[str, list[D]] = {}
        for decision in decisions:
            if cell_of(decision) == cell:
                by_model.setdefault(decision.model, []).append(decision)
        shares = split_evenly(per_cell[cell], {model: len(group) for model, group in by_model.items()})
        for model in sorted(by_model):
            for decision in rng.sample(by_model[model], shares[model]):
                out[turn % lists].append(decision)
                turn += 1
    return out
