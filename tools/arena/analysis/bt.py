"""Bradley-Terry on fractional win shares, with optional seat and shrunken pair terms.

A game's first-listed player wins with probability p = 1 / (1 + exp(-eta)),
    eta = theta[first] - theta[second] + seat + sign * delta[pair],
and its win share w in [0, 1] counts as w wins and 1 - w losses (a split is half each). The fit is the most
probable parameters under Gaussian regularization: a mean-zero prior on every theta (standard deviation 3, which
also shrinks rating differences slightly; ratings are reported with ANCHOR at 0, or the entrants' mean when the fit
does not rate it), and delta ~ N(0, tau^2),
so tau = 0 means no pair terms and a small tau means strongly shrunk ones.
"""

import math
import os
from collections.abc import Iterable
from dataclasses import dataclass, field

# The Newton systems are a few hundred wide: OpenBLAS's threads only contend for the cores (on the loaded host a solve took
# about 2 s threaded and 10 ms on one thread). Set before numpy loads.
os.environ.setdefault("OPENBLAS_NUM_THREADS", "1")

import numpy as np  # noqa: E402

# A near-flat prior (sd 1000) on the seat and starter terms: it keeps the Newton system solvable when a training set
# has every game with the same starter, which makes the starter term a copy of the seat term.
FLAT = 1e-6

from load import Game

ELO = 400 / math.log(10)  # Elo points per unit of theta

# The config rated 0, the depth-7 search engine, so adding a config moves no other rating (ANCHOR in web/src/arena-viewer/page/ratings.ts).
ANCHOR = "Engine/7/2000000/sampled"


def sigmoid(x: float) -> float:
    return 1 / (1 + math.exp(-x)) if x >= 0 else math.exp(x) / (1 + math.exp(x))


def pair_of(a: str, b: str) -> tuple[str, str]:
    return (a, b) if a <= b else (b, a)


# cells: (first, second) -> [games, summed share of first]; with starters, (first, second, 1 if first opens round 1)
Cells = dict[tuple, list[float]]


def cells_of(games: list[Game], weights: dict | None = None, unit=lambda game: game.block, starter: bool = False, share=lambda game: game.share_first) -> Cells:
    """Games grouped by who sat first; `weights` counts each resampling unit's repeats (a block unless `unit` says seed). `share` is what a game counts: its win share, or its pot share."""
    cells: Cells = {}
    for game in games:
        count = 1 if weights is None else weights.get(unit(game), 0)
        if count:
            key = (game.first, game.second, int(game.starter == 1)) if starter else (game.first, game.second)
            cell = cells.setdefault(key, [0.0, 0.0])
            cell[0] += count
            cell[1] += count * share(game)
    return cells


@dataclass
class Fit:
    theta: dict[str, float]
    seat: float = 0.0
    start: float = 0.0  # the edge of the player who opens round 1
    delta: dict[tuple[str, str], float] = field(default_factory=dict)  # of the pair's alphabetically first entrant

    def eta(self, first: str, second: str, first_starts: bool = True) -> float:
        low, high = pair_of(first, second)
        sign = 1 if first == low else -1
        edge = self.start if first_starts else -self.start
        return self.theta[first] - self.theta[second] + self.seat + edge + sign * self.delta.get((low, high), 0.0)

    def p_first(self, first: str, second: str, first_starts: bool = True) -> float:
        return sigmoid(self.eta(first, second, first_starts))

    def elo(self, anchor: str | None = ANCHOR) -> dict[str, float]:
        """Ratings on the Elo scale with `anchor` at 0, or centred on the mean of the entrants when it is None or the fit does not rate it.

        Bootstrap draws are best centred and then moved by the point fit's shift: anchoring each draw would add the anchor's own noise to every interval.
        """
        zero = self.theta.get(anchor, sum(self.theta.values()) / len(self.theta))
        return {name: (value - zero) * ELO for name, value in self.theta.items()}


def fit(cells: Cells, tau: float = 0.0, seat: bool = False, start: bool = False, theta_sd: float = 3.0, seat_sd: float = 1000.0, entrants: set[str] = frozenset(), pair_terms: set[tuple[str, str]] | None = None) -> Fit:
    """Newton steps on the log posterior; `entrants` without a game get theta 0."""
    names = sorted({name for key in cells for name in key[:2]} | set(entrants))
    column = {("theta", name): i for i, name in enumerate(names)}
    penalty = [1 / theta_sd**2] * len(names)
    if seat:
        column[("seat", "")] = len(column)
        penalty.append(1 / seat_sd**2)
    if start:
        column[("start", "")] = len(column)
        penalty.append(FLAT)
    if tau > 0:
        pairs = {pair_of(*key[:2]) for key in cells}
        if pair_terms is not None:
            pairs &= pair_terms
        for pair in sorted(pairs):
            column[("delta", pair)] = len(column)
            penalty.append(1 / tau**2)
    size = len(column)
    design = {}
    for key in cells:
        first, second = key[:2]
        low, high = pair_of(first, second)
        row = {column[("theta", first)]: 1.0, column[("theta", second)]: -1.0}
        if seat:
            row[column[("seat", "")]] = 1.0
        if start:
            row[column[("start", "")]] = 1.0 if key[2] else -1.0
        if tau > 0 and (pair_terms is None or (low, high) in pair_terms):
            row[column[("delta", (low, high))]] = 1.0 if first == low else -1.0
        design[key] = row
    games, shares = np.array(list(cells.values())).reshape(-1, 2).T
    matrix = np.zeros((len(cells), size))
    for r, key in enumerate(cells):
        for i, v in design[key].items():
            matrix[r, i] = v
    prior = np.array(penalty)
    x = np.zeros(size)
    for _ in range(100):
        p = 0.5 * (1 + np.tanh(matrix @ x / 2))
        grad = matrix.T @ (shares - games * p) - prior * x
        step = np.linalg.solve((matrix.T * (games * p * (1 - p))) @ matrix + np.diag(prior), grad)
        x += step
        if np.abs(step).max() < 1e-10:
            break
    out = Fit({name: x[column[("theta", name)]] for name in names})
    if seat:
        out.seat = x[column[("seat", "")]]
    if start:
        out.start = x[column[("start", "")]]
    if tau > 0:
        out.delta = {key[1]: x[i] for key, i in column.items() if key[0] == "delta"}
    return out


def round_elo(matches: Iterable[tuple[str, str, float, float]], entrants: Iterable[str] = (), anchor: str | None = ANCHOR) -> dict[str, float]:
    """Round Elo, the viewer's rating (web/src/arena-viewer/page/ratings.ts): the fit on round shares, each match counting its rounds.

    `matches` are (first config, second config, rounds, the first config's round wins), wins fractional for luck-adjusted ones; the Elo of each config, `anchor` at 0 (Fit.elo).
    """
    cells: Cells = {}
    for first, second, rounds, wins in matches:
        cell = cells.setdefault((first, second), [0.0, 0.0])
        cell[0] += rounds
        cell[1] += wins
    return fit(cells, entrants=set(entrants)).elo(anchor)


def log_loss(fitted: Fit, games: list[Game]) -> float:
    """Summed negative log likelihood of the games' shares; an entrant the fit never saw counts as theta 0."""
    total = 0.0
    for game in games:
        p = min(max(fitted.p_first(game.first, game.second, game.starter == 1), 1e-12), 1 - 1e-12)
        total -= game.share_first * math.log(p) + (1 - game.share_first) * math.log(1 - p)
    return total


def components(games: list[Game]) -> list[set[str]]:
    """The connected groups of entrants, joined by games between them."""
    parent: dict[str, str] = {}

    def find(a: str) -> str:
        parent.setdefault(a, a)
        while parent[a] != a:
            parent[a] = parent[parent[a]]
            a = parent[a]
        return a

    for game in games:
        parent[find(game.first)] = find(game.second)
    groups: dict[str, set[str]] = {}
    for name in list(parent):
        groups.setdefault(find(name), set()).add(name)
    return sorted(groups.values(), key=lambda g: sorted(g))
