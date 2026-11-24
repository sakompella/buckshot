#!/usr/bin/env python3
"""The numbers behind the findings page, from the analysis databases: self-shots below even odds, the loss they and missed items cost, the effort slope at a fixed position, and the seeds a benchmark needs.

Writes one JSON file (no match ids, seeds or accounts in it) that the page's charts and headline figures read. Read-only on every database.

- Clean shot: an agent shot at a chamber its player does not know, with the gun unsawed and the opponent not jammed.
- Below even: the chance the shell is live, from the player's own information, is under one half. Odds of 1/5 and 4/5 count with 1/4 and 3/4.
- Search self-shot rate: the share of shots where the production search scores shooting oneself above shooting the opponent, a tie counting half.
- Missed item: a shot taken when no shot reached the best score, so some item, steal or jam did. The loss share is its points over all points lost.
- Fixed position: the effort slope within groups of one model's decisions at one exact position (`exact_key`) that two or more efforts played, in
  points per effort step (off 0, minimal and low 1, medium 2, high 3, xhigh 4, max 5). Its share of the raw slope is the ratio to the slope across all
  of the model's decisions.
- G-study: variance components of seat-match means by restricted maximum likelihood, for the 36 model configs on the shared seeds 3000 to 3030, and the
  seeds a design of two seat-matches per seed needs for a given reliability.

Intervals are 90% percentile bootstraps of whole `matches.seed` clusters: DRAWS multinomial resamples of every seed, one fixed set for all statistics.
A resample in which a ratio has no denominator is left out of that ratio's interval.

    python3 tools/arena/analysis/selfshoot.py [--db PATH] [--regret PATH] [--knowledge PATH] [--out FILE]
"""

import argparse
import json
from collections import Counter, defaultdict
from collections.abc import Callable, Hashable, Iterable, Sequence
from dataclasses import dataclass
from datetime import date
from fractions import Fraction
from pathlib import Path

import numpy as np
import regret
from boot import DRAWS, TAIL, bounds
from configs import config_effort
from load import DB, REPO, connect, require_current, round_winners
from regret import DERIVED
from rules import POINT, ROUNDS
from scipy.linalg import cho_factor, cho_solve
from scipy.optimize import minimize

SEED = 20261123  # numpy generator seed of the resamples, as in the other analyses of this data
PLACES = 4

STRONG, HAIKU, LUNA = "strong", "haiku", "luna"
GROUP_OF = {
    "gpt-6-astra": STRONG,
    "gpt-6.1-sol": STRONG,
    "claude-sonnet-5-5": STRONG,
    "claude-opus-5-5": STRONG,
    "gpt-6.1-terra": STRONG,
    "gpt-5.6-terra": STRONG,
    "claude-haiku-4-5-20251001": HAIKU,
    "claude-haiku-5-5": HAIKU,
    "gpt-6-luna": LUNA,
}
SONNET = "claude-sonnet-5-5"
SONNET_EFFORTS = ("off", "low", "medium", "high", "xhigh", "max")

EVEN = Fraction(1, 2)
ODDS_BIN = {
    Fraction(1, 5): Fraction(1, 4),
    Fraction(1, 4): Fraction(1, 4),
    Fraction(1, 3): Fraction(1, 3),
    Fraction(2, 5): Fraction(2, 5),
    EVEN: EVEN,
    Fraction(3, 5): Fraction(3, 5),
    Fraction(2, 3): Fraction(2, 3),
    Fraction(3, 4): Fraction(3, 4),
    Fraction(4, 5): Fraction(3, 4),
}

STEP = {"off": 0, "minimal": 1, "low": 1, "medium": 2, "high": 3, "xhigh": 4, "max": 5}

PANEL_SEEDS = (3000, 3030)
PER_SEED = 2  # seat-matches of a config on one seed in the design the G-study sizes
TOP_LOST = 1.0  # points per move: the "top" configs are those at or below it
RELIABILITIES = (0.8, 0.9)


@dataclass(frozen=True, slots=True)
class Decision:
    """An agent decision the production search scored. `effort` is the merged effort; `lost` is in points."""

    seed: int
    model: str
    effort: str
    position: str
    lost: float
    missed_item: bool


@dataclass(frozen=True, slots=True)
class Shot:
    """A clean shot at an unknown chamber. `search_self` is 1, 0.5 or 0 for the search preferring to shoot itself, tying, or not."""

    seed: int
    model: str
    effort: str
    odds: Fraction
    self_shot: bool
    search_self: float

    @property
    def group(self) -> str:
        try:
            return GROUP_OF[self.model]
        except KeyError:
            raise ValueError(f"{self.model} belongs to no shot group") from None


@dataclass(frozen=True, slots=True)
class SeatMatch:
    """One seat of a panel match: the config, the seed, the mean points lost per move and the share of the rounds won."""

    seed: int
    config: tuple[str, str]
    lost: float
    rounds: float


@dataclass(frozen=True, slots=True)
class Estimate:
    value: float
    lo: float
    hi: float


class Seeds:
    """The seed-cluster resamples every interval of a run shares."""

    def __init__(self, seeds: Iterable[int]):
        self.index = {seed: i for i, seed in enumerate(sorted(set(seeds)))}
        n = len(self.index)
        self.counts = np.random.default_rng(SEED).multinomial(
            n, np.full(n, 1 / n), size=DRAWS
        )

    def sums(self, rows: Iterable[tuple[int, Sequence[float]]], width: int):
        """Per seed, the column sums of its rows: one row per seed, `width` columns."""
        out = np.zeros((len(self.index), width))
        for seed, values in rows:
            out[self.index[seed]] += values
        return out

    def estimate(self, sums, stat: Callable) -> Estimate:
        """`stat` reads the columns of the summed rows, as `lambda s: s[1] / s[0]` does for a rate, over the sample and over every resample."""
        with np.errstate(divide="ignore", invalid="ignore"):
            value = stat(sums.sum(axis=0))
            draws = stat((self.counts @ sums).T)
        lo, hi = bounds(draws[~np.isnan(draws)].tolist(), TAIL)
        return Estimate(float(value), lo, hi)


def shot_scores(values_json: str) -> tuple[int, int]:
    """The search's scores for shooting oneself and for shooting the one opponent."""
    scores = {m["label"]: m["score"] for m in json.loads(values_json)}
    (opponent,) = [
        s
        for label, s in scores.items()
        if label.startswith("Shoot ") and label != "Shoot yourself"
    ]
    return scores["Shoot yourself"], opponent


def search_self(own: int, opponent: int) -> float:
    return 1.0 if own > opponent else 0.0 if own < opponent else 0.5


def load(regret_path: Path, knowledge_path: Path) -> tuple[list[Decision], list[Shot]]:
    """Every scored agent decision of the scored matches, and of those the clean shots at an unknown chamber."""
    db = connect(str(regret_path), k=knowledge_path)
    decisions, shots = [], []
    rows = db.execute(
        """SELECT m.seed, p.model, p.effort, d.chamber IS NULL, d.shot, d.sawed, d.private_orders,
                  json_extract(d.private_live_json, '$[0]'), json_extract(d.health_json, '$[1]._tag'),
                  d.exact_key, r.regret, r.best_score, CASE WHEN d.shot IS NOT NULL THEN r.values_json END
           FROM regret r
           JOIN k.matches m ON m.match_id = r.match_id AND m.status = 'completed' AND m.disposition IS NULL
           JOIN k.decisions d ON d.match_id = r.match_id AND d.ordinal = r.ordinal AND d.by_whom = 'agent'
           JOIN k.players p ON p.match_id = d.match_id AND p.player = d.player
           WHERE r.status = 'searched'"""
    ).fetchall()
    db.close()
    for (
        seed,
        model,
        effort,
        unknown,
        shot,
        sawed,
        orders,
        live,
        jammed,
        position,
        lost,
        best,
        values,
    ) in rows:
        merged = config_effort(model, effort)
        missed = False
        if shot is not None:
            own, opponent = shot_scores(values)
            missed = best > max(own, opponent)
            if unknown and not sawed and jammed != "Jammed":
                shots.append(
                    Shot(
                        seed,
                        model,
                        merged,
                        Fraction(live, orders),
                        shot == "self",
                        search_self(own, opponent),
                    )
                )
        decisions.append(Decision(seed, model, merged, position, lost / POINT, missed))
    return decisions, shots


def seat_matches(
    db_path: str, regret_path: Path, knowledge_path: Path
) -> list[SeatMatch]:
    """The seats of the scored matches on the panel seeds that have a scored agent decision."""
    main = connect(db_path)
    won = {
        match: Counter(winners.values())
        for match, winners in round_winners(main).items()
    }
    main.close()
    db = connect(str(regret_path), k=knowledge_path)
    rows = db.execute(
        """SELECT r.match_id, p.player, m.seed, p.model, p.effort, AVG(r.regret)
               FROM regret r
               JOIN k.matches m ON m.match_id = r.match_id AND m.status = 'completed' AND m.disposition IS NULL AND m.seed BETWEEN ? AND ?
               JOIN k.decisions d ON d.match_id = r.match_id AND d.ordinal = r.ordinal AND d.by_whom = 'agent'
               JOIN k.players p ON p.match_id = d.match_id AND p.player = d.player
               WHERE r.status = 'searched' GROUP BY r.match_id, p.player""",
        PANEL_SEEDS,
    ).fetchall()
    db.close()
    return [
        SeatMatch(
            seed,
            (model, config_effort(model, effort)),
            mean_lost / POINT,
            won[match][player] / len(ROUNDS),
        )
        for match, player, seed, model, effort, mean_lost in rows
    ]


def codes(values: Iterable[Hashable]) -> np.ndarray:
    """Each value as the number of its place among the sorted distinct values."""
    items = list(values)
    place = {v: i for i, v in enumerate(sorted(set(items), key=repr))}
    return np.array([place[v] for v in items])


def reml(y: np.ndarray, factors: Sequence[np.ndarray]) -> list[float]:
    """Variance components, one per random factor then the residual, of y = mean + a normal effect per level of each factor (factors are level codes) + error.

    Restricted maximum likelihood on the mixed model equations with the residual variance profiled out; the variance ratios are found from several starts, the best kept.
    """
    n = len(y)
    levels = [int(f.max()) + 1 for f in factors]
    z = np.zeros((n, sum(levels)))
    start = 0
    for f, count in zip(factors, levels):
        z[np.arange(n), start + f] = 1
        start += count
    base = np.empty((z.shape[1] + 1,) * 2)
    base[0, 0] = n
    base[0, 1:] = base[1:, 0] = z.sum(axis=0)
    base[1:, 1:] = z.T @ z
    rhs = np.concatenate([[y.sum()], z.T @ y])
    diagonal = np.arange(1, z.shape[1] + 1)

    def criterion(log_ratio: np.ndarray) -> tuple[float, float]:
        coefficients = base.copy()
        coefficients[diagonal, diagonal] += np.repeat(np.exp(-log_ratio), levels)
        factor = cho_factor(coefficients, lower=True, check_finite=False)
        residual = (y @ y - cho_solve(factor, rhs, check_finite=False) @ rhs) / (n - 1)
        return (
            (n - 1) * np.log(residual)
            + levels @ log_ratio
            + 2 * np.log(np.diag(factor[0])).sum(),
            residual,
        )

    best = min(
        (
            minimize(
                lambda r: criterion(r)[0],
                np.full(len(factors), at),
                method="L-BFGS-B",
                bounds=[(-20, 6)] * len(factors),
                options={"ftol": 1e-13, "gtol": 1e-9, "maxiter": 1000},
            )
            for at in (-1.0, -2.5, -4.0, -6.0)
        ),
        key=lambda fit: fit.fun,
    )
    residual = criterion(best.x)[1]
    return [*(float(v) for v in np.exp(best.x) * residual), float(residual)]


@dataclass(frozen=True)
class Components:
    """Variance components of a metric over configs, seeds and their interaction."""

    config: float
    seed: float
    config_seed: float
    residual: float

    @property
    def total(self) -> float:
        return self.config + self.seed + self.config_seed + self.residual

    def seeds_for(self, reliability: float) -> float:
        """Seeds, each played PER_SEED seat-matches, until the mean over them separates configs with this reliability: G(K) = c / (c + (cs + e / PER_SEED) / K)."""
        noise = self.config_seed + self.residual / PER_SEED
        return reliability / (1 - reliability) * noise / self.config


def components(
    seats: list[SeatMatch], metric: Callable[[SeatMatch], float]
) -> Components:
    return Components(
        *reml(
            np.array([metric(s) for s in seats]),
            [
                codes(s.config for s in seats),
                codes(s.seed for s in seats),
                codes((s.config, s.seed) for s in seats),
            ],
        )
    )


def fixed_position_slope(
    decisions: list[Decision], seeds: Seeds
) -> tuple[Estimate, float]:
    """The slope of points lost on effort step within (model, exact position) groups that two or more steps played, and its ratio to the raw slope within models."""
    groups: dict[tuple[str, str], list[Decision]] = defaultdict(list)
    for d in decisions:
        groups[d.model, d.position].append(d)
    rows, raw = [], defaultdict(lambda: np.zeros(5))
    for d in decisions:
        x, y = STEP[d.effort.split("/")[0]], d.lost
        raw[d.model] += (1, x, y, x * y, x * x)
    for group in groups.values():
        x = np.array([STEP[d.effort.split("/")[0]] for d in group], dtype=float)
        if x.min() == x.max():
            continue
        y = np.array([d.lost for d in group])
        x, y = x - x.mean(), y - y.mean()
        rows.append((min(d.seed for d in group), (x @ y, x @ x)))
    within = seeds.estimate(seeds.sums(rows, 2), lambda s: s[0] / s[1])
    cross = sum(r[3] - r[1] * r[2] / r[0] for r in raw.values())
    spread = sum(r[4] - r[1] ** 2 / r[0] for r in raw.values())
    return within, within.value / (cross / spread)


@dataclass(frozen=True, slots=True)
class Rates:
    """The self-shot rates of the models and of the search over the same shots, and the models' minus the search's."""

    models: Estimate
    search: Estimate
    gap: Estimate


def rates(shots: list[Shot], seeds: Seeds) -> Rates:
    sums = seeds.sums(((s.seed, (1, s.self_shot, s.search_self)) for s in shots), 3)
    return Rates(
        seeds.estimate(sums, lambda a: a[1] / a[0]),
        seeds.estimate(sums, lambda a: a[2] / a[0]),
        seeds.estimate(sums, lambda a: (a[1] - a[2]) / a[0]),
    )


def odds_label(odds: Fraction) -> str:
    return f"{odds.numerator}/{odds.denominator}"


def rounded(x: float, places: int = PLACES) -> float:
    return round(float(x), places)


def headline(decisions: list[Decision], shots: list[Shot], seeds: Seeds) -> dict:
    below = [s for s in shots if s.odds < EVEN]
    strong = [s for s in below if s.group == STRONG]
    all_below, all_strong = rates(below, seeds), rates(strong, seeds)
    missed = seeds.estimate(
        seeds.sums(((d.seed, (d.missed_item * d.lost, d.lost)) for d in decisions), 2),
        lambda a: a[0] / a[1],
    )
    slope, share = fixed_position_slope(decisions, seeds)
    return {
        "cleanShotsN": len(below),
        "modelRate": rounded(all_below.models.value),
        "searchRate": rounded(all_below.search.value),
        "gap": rounded(all_below.gap.value),
        "gapLo": rounded(all_below.gap.lo),
        "gapHi": rounded(all_below.gap.hi),
        "strongN": len(strong),
        "strongModelRate": rounded(all_strong.models.value),
        "strongSearchRate": rounded(all_strong.search.value),
        "strongGap": rounded(all_strong.gap.value),
        "strongGapLo": rounded(all_strong.gap.lo),
        "strongGapHi": rounded(all_strong.gap.hi),
        "missedItemLossShare": rounded(missed.value),
        "missedItemLossLo": rounded(missed.lo),
        "missedItemLossHi": rounded(missed.hi),
        "fixedPosEffortSlope": rounded(slope.value),
        "fixedPosEffortLo": rounded(slope.lo),
        "fixedPosEffortHi": rounded(slope.hi),
        "fixedPosEffortShareOfRaw": rounded(share),
    }


def curve(shots: list[Shot], seeds: Seeds) -> list[dict]:
    """The self-shot rate of models and of the search by group and chance the shell is live."""
    cells: dict[tuple[str, Fraction], list[Shot]] = defaultdict(list)
    for s in shots:
        cells[s.group, ODDS_BIN[s.odds]].append(s)
    rows = []
    for group in (STRONG, HAIKU, LUNA):
        for odds in sorted(o for g, o in cells if g == group):
            cell = cells[group, odds]
            r = rates(cell, seeds)
            rows.append(
                {
                    "group": group,
                    "pLive": rounded(float(odds)),
                    "pLabel": odds_label(odds),
                    "n": len(cell),
                    "modelRate": rounded(r.models.value),
                    "modelLo": rounded(r.models.lo),
                    "modelHi": rounded(r.models.hi),
                    "searchRate": rounded(r.search.value),
                    "searchLo": rounded(r.search.lo),
                    "searchHi": rounded(r.search.hi),
                }
            )
    return rows


def sonnet_effort(shots: list[Shot], seeds: Seeds) -> list[dict]:
    """Sonnet's clean shots below even, by effort."""
    rows = []
    for effort in SONNET_EFFORTS:
        cell = [
            s
            for s in shots
            if s.odds < EVEN and s.model == SONNET and s.effort == effort
        ]
        if cell:
            r = rates(cell, seeds)
            rows.append(
                {
                    "effort": effort,
                    "n": len(cell),
                    "modelRate": rounded(r.models.value),
                    "searchRate": rounded(r.search.value),
                    "gap": rounded(r.gap.value),
                    "gapLo": rounded(r.gap.lo),
                    "gapHi": rounded(r.gap.hi),
                }
            )
    return rows


def g_study(seats: list[SeatMatch]) -> dict:
    """Variance shares and the seeds needed for a reliability of each metric, over all the panel's configs and over those that lose few points."""
    mean_lost = {
        config: np.mean([s.lost for s in seats if s.config == config])
        for config in {s.config for s in seats}
    }
    top = [s for s in seats if mean_lost[s.config] <= TOP_LOST]
    metrics = {"rounds": lambda s: s.rounds, "regret": lambda s: s.lost}
    everyone = {name: components(seats, metric) for name, metric in metrics.items()}
    best = {name: components(top, metric) for name, metric in metrics.items()}
    out: dict = {
        "configs": len({s.config for s in seats}),
        "seeds": len({s.seed for s in seats}),
    }
    for name, c in everyone.items():
        out[name] = {
            "config": rounded(c.config / c.total),
            "seed": rounded(c.seed / c.total),
            "configSeed": rounded(c.config_seed / c.total),
            "residual": rounded(c.residual / c.total),
        }
    for level, label in zip(RELIABILITIES, ("seedsG80", "seedsG90")):
        out[label] = {
            name: rounded(c.seeds_for(level), 1) for name, c in everyone.items()
        }
    out["ratioAll"] = rounded(
        everyone["rounds"].seeds_for(RELIABILITIES[0])
        / everyone["regret"].seeds_for(RELIABILITIES[0]),
        1,
    )
    out["ratioTop14"] = rounded(
        best["rounds"].seeds_for(RELIABILITIES[0])
        / best["regret"].seeds_for(RELIABILITIES[0]),
        1,
    )
    return out


def build(db_path: str, regret_path: Path, knowledge_path: Path) -> dict:
    regret.run_of(regret_path)
    decisions, shots = load(regret_path, knowledge_path)
    seeds = Seeds(d.seed for d in decisions)
    return {
        "generated": date.today().isoformat(),
        "headline": headline(decisions, shots, seeds),
        "curve": curve(shots, seeds),
        "sonnetEffort": sonnet_effort(shots, seeds),
        "gStudy": g_study(seat_matches(db_path, regret_path, knowledge_path)),
    }


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__.split("\n")[0])
    parser.add_argument("--db", default=DB)
    parser.add_argument("--regret", type=Path, default=regret.PRODUCTION)
    parser.add_argument("--knowledge", type=Path, default=DERIVED / "knowledge.sqlite")
    parser.add_argument("--out", type=Path, default=REPO / "web/online/data/findings.json")
    args = parser.parse_args()
    require_current(args.db)
    findings = build(args.db, args.regret, args.knowledge)
    args.out.parent.mkdir(parents=True, exist_ok=True)
    args.out.write_text(json.dumps(findings, indent=2) + "\n", encoding="utf-8")


if __name__ == "__main__":
    main()
