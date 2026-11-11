"""The next matches to play, picked for what they teach about the ratings per dollar.

Games are fitted with Bradley-Terry on win shares (bt.fit), and the ratings' covariance is the inverse of the fit's
Hessian. The targets are the rating differences of neighbours in the ranking whose 95% intervals overlap: a
neighbour pair with separate intervals is settled, and a far pair says little about the order. A block is two
matches on one fresh seed, one per seat order, and it adds 2 p (1 - p) to the information along its pair's difference.
Blocks are picked one at a time, each the one that most cuts the targets' summed variance per dollar, and each pick
updates the covariance before the next, so a batch spreads over pairs instead of repeating the best one.

    from schedule import next_matches
    next_matches(games, costs, 20, seeds)  # 10 blocks: [(first, second, seed), ...]
"""

from collections.abc import Iterator
from itertools import pairwise

import numpy as np

import bt
from load import Game

Z = 1.96


def information(cells: bt.Cells, fitted: bt.Fit, names: list[str]) -> np.ndarray:
    """The Hessian of the negative log posterior of bt.fit, in the ratings of `names`."""
    index = {name: i for i, name in enumerate(names)}
    hessian = np.eye(len(names)) / 3.0**2
    for (first, second), (games, _) in cells.items():
        p = fitted.p_first(first, second)
        u = np.zeros(len(names))
        u[index[first]], u[index[second]] = 1.0, -1.0
        hessian += games * p * (1 - p) * np.outer(u, u)
    return hessian


def centred_sd(cov: np.ndarray) -> np.ndarray:
    """Each rating's standard deviation with the entrants' mean at 0, as ratings are reported."""
    centre = np.eye(len(cov)) - 1 / len(cov)
    return np.sqrt(np.diag(centre @ cov @ centre))


def targets(theta: np.ndarray, cov: np.ndarray) -> list[tuple[int, int]]:
    """Neighbours in the ranking whose 95% intervals overlap."""
    order = np.argsort(-theta)
    sd = centred_sd(cov)
    return [(a, b) for a, b in pairwise(order) if theta[a] - theta[b] < Z * (sd[a] + sd[b])]


def next_matches(games: list[Game], costs: dict[str, float], n: int, seeds: Iterator[int]) -> list[tuple[str, str, int]]:
    """The next `n` matches (n even) among the configs of `costs`, in blocks of both seat orders on a fresh seed from `seeds`.

    `costs` is each config's dollars per match. A config without a game starts at rating 0 and the prior's variance.
    """
    names = sorted(costs)
    played = [game for game in games if game.first in costs and game.second in costs]
    cells = bt.cells_of(played)
    fitted = bt.fit(cells, entrants=set(names))
    theta = np.array([fitted.theta[name] for name in names])
    cov = np.linalg.inv(information(cells, fitted, names))
    diffs = [np.eye(len(names))[a] - np.eye(len(names))[b] for a, b in targets(theta, cov)]
    if not diffs:
        return []
    matches = []
    for _ in range(n // 2):
        best = None
        for i in range(len(names)):
            for j in range(i + 1, len(names)):
                p = bt.sigmoid(theta[i] - theta[j])
                w = 2 * p * (1 - p)
                cu = cov[:, i] - cov[:, j]
                gain = w * sum((v @ cu) ** 2 for v in diffs) / (1 + w * (cu[i] - cu[j]))
                value = gain / (2 * (costs[names[i]] + costs[names[j]]))
                if best is None or value > best[0]:
                    best = (value, i, j, w, cu)
        _, i, j, w, cu = best
        cov -= w * np.outer(cu, cu) / (1 + w * (cu[i] - cu[j]))
        seed = next(seeds)
        matches += [(names[i], names[j], seed), (names[j], names[i], seed)]
    return matches
