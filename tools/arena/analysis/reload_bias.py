"""Draws the stratified sample of two-seat agent decisions that the reload-bias run scores, and summarises the run (#17).

The sample is cut into lists of "<match id> <ordinal>" lines. Each list holds an equal share of every
stratum (shells left in the gun, shot or item move, model), so a list that finishes early is still a stratified random sample.

    python3 tools/arena/analysis/reload_bias.py sample --out DIR [--lists 16] [--seed N] [--exclude LIST ...]
    python3 tools/arena/analysis/reload_bias.py report [--sampled PATH] [--samples 64] [--doc docs/arena/analysis/regret.md]

`sample` writes one list per file. The run was scored with the Bend player's `web/scripts/arena-regret.ts --decisions LIST --reload sampled`, removed on 2026-11-08, so it cannot be rerun as written. `report` reads the sampled run
and the static run it is compared with, both read only, and prints markdown tables, or with --doc rewrites the ones between the reload-bias markers of that file.
"""

import argparse
import json
import math
import random
from collections import Counter
from collections.abc import Callable, Mapping
from dataclasses import dataclass
from pathlib import Path

from docs import splice_between_markers
from fmt import pct, table
from load import SKIPPED_MODEL, connect
from regret import DERIVED
from rules import POINT

# Decisions to draw for each (shells left, shot, reachable) cell. Where a line can empty the gun, a scored decision costs seconds to minutes, more with more
# shells left and for item moves, so the quotas shrink with the distance. Where none can, the two rules score alike by construction: a check only.
QUOTA = {
    (1, True, True): 300, (2, True, True): 550, (3, True, True): 550, (4, True, True): 180, (5, True, True): 80, (6, True, True): 15,
    (1, False, True): 200, (2, False, True): 350, (3, False, True): 240, (4, False, True): 90, (5, False, True): 45, (6, False, True): 5,
    (4, True, False): 35, (5, True, False): 35, (6, True, False): 35, (4, False, False): 35, (5, False, False): 35, (6, False, False): 35,
}  # fmt: skip


@dataclass(frozen=True)
class Decision:
    match_id: str
    ordinal: int
    shells_left: int
    shot: bool
    model: str
    depth: int  # decisions the static search finished

    @property
    def reachable(self) -> bool:
        """The gun holds no more shells than decisions the static search finished, so a line can empty it and reach a reload."""
        return self.shells_left <= self.depth

    @property
    def stratum(self) -> tuple[int, bool, str, bool]:
        return (self.shells_left, self.shot, self.model, self.reachable)


def population(regret_path: Path, knowledge_path: Path, depth: int = 6, budget: int = 20000) -> list[Decision]:
    """The searched static decisions of finished two-seat matches with no DeepSeek seat, as regret.py reads them."""
    db = connect(str(regret_path))
    db.execute("ATTACH DATABASE ? AS k", (f"file:{knowledge_path}?mode=ro",))
    rows = db.execute(
        """SELECT r.match_id, r.ordinal, d.remaining, d.choice, p.model, r.depth
           FROM regret r
           JOIN k.matches m ON m.match_id = r.match_id AND m.status = 'completed'
           JOIN k.decisions d ON d.match_id = r.match_id AND d.ordinal = r.ordinal AND d.by_whom = 'agent'
           JOIN k.players p ON p.match_id = d.match_id AND p.player = d.player
           WHERE r.max_depth = ? AND r.budget = ? AND r.reload = 'static' AND r.status = 'searched'
             AND (SELECT COUNT(*) FROM k.players q WHERE q.match_id = r.match_id) = 2
             AND r.match_id NOT IN (SELECT match_id FROM k.players WHERE model LIKE ?)
           ORDER BY r.match_id, r.ordinal""",
        (depth, budget, f"%{SKIPPED_MODEL}%"),
    ).fetchall()
    return [Decision(match, ordinal, remaining, choice.startswith("Shoot"), model, finished) for match, ordinal, remaining, choice, model, finished in rows]


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


def draw(decisions: list[Decision], per_cell: dict[tuple[int, bool, bool], int], lists: int, seed: int) -> list[list[Decision]]:
    """`per_cell` decisions for each (shells left, shot, reachable) cell, spread equally over the models, dealt into `lists` lists that each hold an equal share of every stratum."""
    rng = random.Random(seed)
    out: list[list[Decision]] = [[] for _ in range(lists)]
    turn = 0
    for cell in sorted(per_cell):
        by_model: dict[str, list[Decision]] = {}
        for decision in decisions:
            if (decision.shells_left, decision.shot, decision.reachable) == cell:
                by_model.setdefault(decision.model, []).append(decision)
        shares = split_evenly(per_cell[cell], {model: len(group) for model, group in by_model.items()})
        for model in sorted(by_model):
            for decision in rng.sample(by_model[model], shares[model]):
                out[turn % lists].append(decision)
                turn += 1
    return out


# Summary
# =======


@dataclass(frozen=True)
class Pair:
    """One decision scored under both reload rules, in percentage points of the round win chance."""

    shells_left: int
    shot: bool
    model: str
    static_regret: float
    sampled_regret: float
    reachable: bool
    reloads: bool  # some move's score differs between the rules, so a line of the search reached a reload
    best_moved: bool  # the rules disagree on the best move
    same_tree: bool  # both searches expanded the same nodes to the same depth, as the rules promise


def pairs(sampled_path: Path, regret_path: Path, knowledge_path: Path, depth: int = 6, budget: int = 20000, samples: int = 256) -> list[Pair]:
    """The sampled run's searched decisions with the static run's score of the same decision, matched by match, ordinal, depth and budget.

    The evaluator column is not compared: a build of the player made after the reload rules were added has a different hash, because the reload-leaf source changed, though its static path is meant to score the same.
    """
    db = connect(str(sampled_path))
    db.execute("ATTACH DATABASE ? AS s", (f"file:{regret_path}?mode=ro",))
    db.execute("ATTACH DATABASE ? AS k", (f"file:{knowledge_path}?mode=ro",))
    rows = db.execute(
        """SELECT d.remaining, d.choice, p.model, t.regret, r.regret, t.values_json, r.values_json, t.best, r.best, t.nodes, r.nodes, t.depth, r.depth
           FROM regret r
           JOIN s.regret t ON t.match_id = r.match_id AND t.ordinal = r.ordinal AND t.max_depth = r.max_depth AND t.budget = r.budget AND t.reload = 'static' AND t.status = 'searched'
           JOIN k.decisions d ON d.match_id = r.match_id AND d.ordinal = r.ordinal AND d.by_whom = 'agent'
           JOIN k.players p ON p.match_id = d.match_id AND p.player = d.player
           WHERE r.max_depth = ? AND r.budget = ? AND r.reload = 'sampled' AND r.samples = ? AND r.status = 'searched'
           ORDER BY r.match_id, r.ordinal""",
        (depth, budget, samples),
    ).fetchall()
    scores = lambda text: [move["score"] for move in json.loads(text)]
    return [
        Pair(remaining, choice.startswith("Shoot"), model, static / POINT, sampled / POINT, remaining <= static_depth, scores(static_values) != scores(sampled_values), static_best != sampled_best, static_nodes == sampled_nodes and static_depth == sampled_depth)
        for remaining, choice, model, static, sampled, static_values, sampled_values, static_best, sampled_best, static_nodes, sampled_nodes, static_depth, sampled_depth in rows
    ]


@dataclass(frozen=True)
class Estimate:
    mean: float
    half_width: float  # of a 95% interval


def estimate(sample: list[Pair], value: Callable[[Pair], float], sizes: Mapping[tuple[int, bool, str, bool], int]) -> Estimate:
    """The population mean of `value` over the strata (shells left, shot, model, reachable) present in `sample`, each weighted by its size in the whole run."""
    strata: dict[tuple[int, bool, str, bool], list[float]] = {}
    for pair in sample:
        strata.setdefault((pair.shells_left, pair.shot, pair.model, pair.reachable), []).append(value(pair))
    total = sum(sizes[key] for key in strata)
    mean = variance = 0.0
    for key, values in strata.items():
        weight = sizes[key] / total
        centre = sum(values) / len(values)
        mean += weight * centre
        if len(values) > 1:
            variance += weight**2 * sum((v - centre) ** 2 for v in values) / (len(values) - 1) / len(values)
    return Estimate(mean, 1.96 * math.sqrt(variance))


# Tables
# ======

Sizes = Mapping[tuple[int, bool, str, bool], int]


def sizes_of(run: list[Decision]) -> Sizes:
    """How many decisions the whole run holds in each stratum."""
    return Counter(d.stratum for d in run)


def two_places(value: float) -> str:
    return f"{value:.2f}"


def signed(e: Estimate) -> str:
    return f"{round(e.mean, 2) + 0.0:+.2f} ± {e.half_width:.2f}"


def by_cell(sample: list[Pair], run: list[Decision], sizes: Sizes) -> str:
    """Shots and item moves apart, by shells left in the gun and pooled over it. Regrets are in percentage points of the round win chance."""
    rows = []
    for shot, kind in ((True, "shot"), (False, "item move")):
        for left in [*sorted({d.shells_left for d in run}), None]:
            scored = [p for p in sample if p.shot == shot and left in (None, p.shells_left)]
            everyone = [d for d in run if d.shot == shot and left in (None, d.shells_left)]
            if not scored:
                continue
            mean = lambda value: estimate(scored, value, sizes)
            rows.append(
                [
                    kind,
                    "all" if left is None else str(left),
                    f"{len(everyone):,}",
                    pct(sum(d.shells_left <= d.depth for d in everyone) / len(everyone)),
                    f"{len(scored):,}",
                    pct(mean(lambda p: p.reloads).mean),
                    two_places(mean(lambda p: p.static_regret).mean),
                    two_places(mean(lambda p: p.sampled_regret).mean),
                    signed(mean(lambda p: p.sampled_regret - p.static_regret)),
                    pct(mean(lambda p: p.best_moved).mean),
                ]
            )
    return table(["kind", "shells left", "decisions", "reload within depth", "scored", "score changed", "static regret", "sampled regret", "sampled minus static", "best move changed"], rows)


def by_model(sample: list[Pair], sizes: Sizes) -> str:
    """Each model's mean regret under both rules, and its rank under each (1 is lowest)."""
    models = sorted({p.model for p in sample})
    mean = lambda model, value: estimate([p for p in sample if p.model == model], value, sizes).mean
    static = {m: mean(m, lambda p: p.static_regret) for m in models}
    sampled = {m: mean(m, lambda p: p.sampled_regret) for m in models}
    rank = lambda means: {m: 1 + sum(means[other] < means[m] for other in models) for m in models}
    static_rank, sampled_rank = rank(static), rank(sampled)
    rows = [[m, str(sum(p.model == m for p in sample)), two_places(static[m]), str(static_rank[m]), two_places(sampled[m]), str(sampled_rank[m])] for m in sorted(models, key=static.__getitem__)]
    return table(["model", "scored", "static regret", "rank", "sampled regret", "rank"], rows)


def report(sample: list[Pair], run: list[Decision], noise: tuple[int, Estimate] | None = None) -> str:
    sizes = sizes_of(run)
    inside = [p for p in sample if p.reachable]
    outside = [p for p in sample if not p.reachable]
    lines = [
        f"{len(sample):,} decisions scored under both rules, drawn from the run's {len(run):,}. {sum(not p.same_tree for p in sample):,} searched a different tree under the two rules.",
        f"A score changed in {sum(p.reloads for p in inside):,} of {len(inside):,} scored decisions where the gun held no more shells than the static search finished decisions, and in {sum(p.reloads for p in outside):,} of {len(outside):,} where it held more.",
    ]
    if noise is not None:
        lines.append(f"On {noise[0]:,} decisions scored with 256 samples as well, mean regret with 64 minus with 256 is {signed(noise[1])} points.")
    return "\n".join(lines) + f"\n\n### By shells left in the gun\n\n{by_cell(sample, run, sizes)}\n\n### By model\n\n{by_model(sample, sizes)}\n"


def noise_check(sampled_path: Path, samples: int, other: int, depth: int = 6, budget: int = 20000) -> tuple[int, Estimate] | None:
    """The mean regret of the decisions scored with both sample counts at once: `samples` minus `other`, in points, with a 95% interval. None if no decision has both.

    A sampled score is a mean over `samples` random deals, so choosing the best of several noisy scores adds a little regret that shrinks as the count grows.
    """
    db = connect(str(sampled_path))
    rows = db.execute(
        """SELECT a.regret, b.regret FROM regret a JOIN regret b ON b.match_id = a.match_id AND b.ordinal = a.ordinal AND b.max_depth = a.max_depth AND b.budget = a.budget
           WHERE a.reload = 'sampled' AND b.reload = 'sampled' AND a.samples = ? AND b.samples = ? AND a.max_depth = ? AND a.budget = ? AND a.status = 'searched' AND b.status = 'searched'""",
        (samples, other, depth, budget),
    ).fetchall()
    if not rows:
        return None
    gaps = [(a - b) / POINT for a, b in rows]
    mean = sum(gaps) / len(gaps)
    spread = sum((gap - mean) ** 2 for gap in gaps) / max(1, len(gaps) - 1)
    return len(gaps), Estimate(mean, 1.96 * math.sqrt(spread / len(gaps)))


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__.split("\n")[0])
    parser.add_argument("--regret", type=Path, default=DERIVED / "regret.sqlite")
    parser.add_argument("--knowledge", type=Path, default=DERIVED / "knowledge.sqlite")
    commands = parser.add_subparsers(dest="command", required=True)
    sampling = commands.add_parser("sample")
    sampling.add_argument("--out", type=Path, required=True)
    sampling.add_argument("--lists", type=int, default=16)
    sampling.add_argument("--seed", type=int, default=20261027)
    sampling.add_argument("--exclude", type=Path, action="append", default=[])
    reporting = commands.add_parser("report")
    reporting.add_argument("--sampled", type=Path, default=DERIVED / "reload-bias.sqlite")
    reporting.add_argument("--samples", type=int, default=64)
    reporting.add_argument("--doc", type=Path)
    args = parser.parse_args()
    run = population(args.regret, args.knowledge)
    if args.command == "sample":
        left_out = {tuple(line.split()) for path in args.exclude for line in path.read_text().splitlines() if line.strip()}
        lists = draw([d for d in run if (d.match_id, str(d.ordinal)) not in left_out], QUOTA, args.lists, args.seed)
        args.out.mkdir(parents=True, exist_ok=True)
        for index, chosen in enumerate(lists):
            (args.out / f"list-{index:02d}.txt").write_text("".join(f"{d.match_id} {d.ordinal}\n" for d in chosen))
        print(f"{sum(map(len, lists)):,} decisions in {args.lists} lists of {len(lists[0])} or {len(lists[-1])}")
        return
    text = report(pairs(args.sampled, args.regret, args.knowledge, samples=args.samples), run, noise_check(args.sampled, args.samples, 256))
    if args.doc is None:
        print(text)
    else:
        splice_between_markers(args.doc, "reload-bias", text)


if __name__ == "__main__":
    main()
