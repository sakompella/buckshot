"""Bradley-Terry on fractional win shares, with optional seat and shrunken pair terms.

A game's first-listed player wins with probability p = 1 / (1 + exp(-eta)),
    eta = theta[first] - theta[second] + seat + sign * delta[pair],
and its win share w in [0, 1] counts as w wins and 1 - w losses (a split is half each). The fit is the most
probable parameters under Gaussian regularization: a mean-zero prior on every theta (standard deviation 3, which
also shrinks rating differences slightly; ratings are reported with the entrants' mean at 0), and delta ~ N(0, tau^2),
so tau = 0 means no pair terms and a small tau means strongly shrunk ones.
"""

import math
from dataclasses import dataclass, field

from load import Game

ELO = 400 / math.log(10)  # Elo points per unit of theta


def solve(a: list[list[float]], b: list[float]) -> list[float]:
    """Solves a x = b by Gaussian elimination with partial pivoting."""
    n = len(b)
    rows = [[*row, value] for row, value in zip(a, b)]
    for col in range(n):
        pivot = max(range(col, n), key=lambda r: abs(rows[r][col]))
        rows[col], rows[pivot] = rows[pivot], rows[col]
        for r in range(col + 1, n):
            factor = rows[r][col] / rows[col][col]
            if factor:
                rows[r] = [x - factor * y for x, y in zip(rows[r], rows[col])]
    x = [0.0] * n
    for r in range(n - 1, -1, -1):
        x[r] = (rows[r][n] - sum(rows[r][c] * x[c] for c in range(r + 1, n))) / rows[r][r]
    return x


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

    def elo(self) -> dict[str, float]:
        """Ratings on the Elo scale with the mean of the entrants at 0."""
        mean = sum(self.theta.values()) / len(self.theta)
        return {name: (value - mean) * ELO for name, value in self.theta.items()}


def fit(cells: Cells, tau: float = 0.0, seat: bool = False, start: bool = False, theta_sd: float = 3.0, entrants: set[str] = frozenset()) -> Fit:
    """Newton steps on the log posterior; `entrants` without a game get theta 0."""
    names = sorted({name for key in cells for name in key[:2]} | set(entrants))
    column = {("theta", name): i for i, name in enumerate(names)}
    penalty = [1 / theta_sd**2] * len(names)
    if seat:
        column[("seat", "")] = len(column)
        penalty.append(0.0)
    if start:
        column[("start", "")] = len(column)
        penalty.append(0.0)
    if tau > 0:
        for pair in sorted({pair_of(*key[:2]) for key in cells}):
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
        if tau > 0:
            row[column[("delta", (low, high))]] = 1.0 if first == low else -1.0
        design[key] = row
    x = [0.0] * size
    for _ in range(100):
        grad = [-penalty[i] * x[i] for i in range(size)]
        hess = [[penalty[i] if i == j else 0.0 for j in range(size)] for i in range(size)]
        for key, (n, wins) in cells.items():
            row = design[key]
            p = sigmoid(sum(v * x[i] for i, v in row.items()))
            for i, vi in row.items():
                grad[i] += (wins - n * p) * vi
                for j, vj in row.items():
                    hess[i][j] += n * p * (1 - p) * vi * vj
        step = solve(hess, grad)
        x = [a + b for a, b in zip(x, step)]
        if max(abs(s) for s in step) < 1e-10:
            break
    out = Fit({name: x[column[("theta", name)]] for name in names})
    if seat:
        out.seat = x[column[("seat", "")]]
    if start:
        out.start = x[column[("start", "")]]
    if tau > 0:
        out.delta = {key[1]: x[i] for key, i in column.items() if key[0] == "delta"}
    return out


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
