"""Statistics shared by the analysis scripts: rank correlation and the stratified draw and estimate type."""

import math
import random
import statistics
from collections.abc import Callable, Hashable, Mapping, Sequence
from dataclasses import dataclass
from pathlib import Path
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


def stratified_estimate[K: Hashable](
    strata: Mapping[K, list[float]], sizes: Mapping[K, int], total: int
) -> Estimate:
    """The mean of the sampled `strata` weighted by their `sizes` in a population of `total` decisions, with its 95% half-width (normal, stratified)."""
    mean = variance = 0.0
    for key, values in strata.items():
        weight = sizes[key] / total
        centre = sum(values) / len(values)
        mean += weight * centre
        if len(values) > 1:
            variance += (
                weight**2
                * sum((v - centre) ** 2 for v in values)
                / (len(values) - 1)
                / len(values)
            )
    return Estimate(mean, 1.96 * math.sqrt(variance))


def split_evenly(total: int, sizes: dict[str, int]) -> dict[str, int]:
    """Shares of `total` equal across the keys, where a key never gets more than its size and its unused share goes to the others."""
    shares = {key: 0 for key in sizes}
    open_keys = [key for key in sizes if sizes[key] > 0]
    left = min(total, sum(sizes.values()))
    while left > 0:
        each, extra = divmod(left, len(open_keys))
        for index, key in enumerate(open_keys):
            shares[key] = min(
                sizes[key], shares[key] + each + (1 if index < extra else 0)
            )
        left = min(total, sum(sizes.values())) - sum(shares.values())
        open_keys = [key for key in open_keys if shares[key] < sizes[key]]
    return shares


class Modelled(Protocol):
    @property
    def model(self) -> str: ...


class Listed(Protocol):
    @property
    def match_id(self) -> str: ...

    @property
    def ordinal(self) -> int: ...


def draw[D: Modelled, C: tuple](
    decisions: Sequence[D],
    per_cell: Mapping[C, int],
    lists: int,
    seed: int,
    cell_of: Callable[[D], C],
) -> list[list[D]]:
    """`per_cell` decisions for each `cell_of` cell, spread equally over the models, dealt into `lists` lists that each hold an equal share of every stratum."""
    rng = random.Random(seed)
    out: list[list[D]] = [[] for _ in range(lists)]
    turn = 0
    for cell in sorted(per_cell):
        by_model: dict[str, list[D]] = {}
        for decision in decisions:
            if cell_of(decision) == cell:
                by_model.setdefault(decision.model, []).append(decision)
        shares = split_evenly(
            per_cell[cell], {model: len(group) for model, group in by_model.items()}
        )
        for model in sorted(by_model):
            for decision in rng.sample(by_model[model], shares[model]):
                out[turn % lists].append(decision)
                turn += 1
    return out


def write_lists(out: Path, lists: Sequence[Sequence[Listed]]) -> None:
    """One file of "<match id> <ordinal>" lines per list in `out`, and a summary line."""
    out.mkdir(parents=True, exist_ok=True)
    for index, chosen in enumerate(lists):
        (out / f"list-{index:02d}.txt").write_text(
            "".join(f"{d.match_id} {d.ordinal}\n" for d in chosen)
        )
    print(
        f"{sum(map(len, lists)):,} decisions in {len(lists)} lists of {len(lists[0])} or {len(lists[-1])}"
    )
