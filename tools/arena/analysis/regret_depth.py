"""Draws the stratified sample of two-seat agent decisions that the regret-depth run scores again with a deeper search, and summarises the run.

The deep run searches to depth 8 with ten times the node budget of the production run (depth 6, 20,000 nodes), under the same static reload rule.
`sample` cuts the sample into lists of "<match id> <ordinal>" lines for `web/scripts/arena-regret.ts --decisions`. Each list holds an equal share of every
stratum (shells left in the gun, shot or item move, model), so a list that finishes early is still a stratified random sample.

    python3 tools/arena/analysis/regret_depth.py sample --out DIR [--lists 24] [--seed N]
    python3 tools/arena/analysis/regret_depth.py report [--deep PATH] [--doc docs/arena/analysis/regret.md]

`report` reads the deep run and the production static run it is compared with, both read only, and prints markdown tables, or with --doc rewrites the
ones between the regret-depth markers of that file.
"""

import argparse
import json
import math
import random
from collections import Counter
from collections.abc import Callable, Mapping
from dataclasses import dataclass
from pathlib import Path

from fmt import pct, table
from load import connect
from regret import DERIVED, POINT
from reload_bias import Decision, Estimate, population, split_evenly

DEPTH, BUDGET = 6, 20_000
DEEP_DEPTH, DEEP_BUDGET = 8, 200_000

# Decisions to draw for each (shells left, shot) cell, spread equally over the models. Searches with few shells left already finish depth 6 inside the
# budget, so a deeper search can change little there. The quota grows with the shells left, where the budget stops most searches.
QUOTA = {(1, True): 140, (2, True): 200, (3, True): 280, (4, True): 280, (5, True): 280, (6, True): 260,
         (1, False): 140, (2, False): 200, (3, False): 280, (4, False): 280, (5, False): 280, (6, False): 260}  # fmt: skip


def draw(decisions: list[Decision], per_cell: Mapping[tuple[int, bool], int], lists: int, seed: int) -> list[list[Decision]]:
    """`per_cell` decisions for each (shells left, shot) cell, spread equally over the models, dealt into `lists` lists that each hold an equal share of every stratum."""
    rng = random.Random(seed)
    out: list[list[Decision]] = [[] for _ in range(lists)]
    turn = 0
    for cell in sorted(per_cell):
        by_model: dict[str, list[Decision]] = {}
        for decision in decisions:
            if (decision.shells_left, decision.shot) == cell:
                by_model.setdefault(decision.model, []).append(decision)
        shares = split_evenly(per_cell[cell], {model: len(group) for model, group in by_model.items()})
        for model in sorted(by_model):
            for decision in rng.sample(by_model[model], shares[model]):
                out[turn % lists].append(decision)
                turn += 1
    return out


# Summary
# =======

Stratum = tuple[int, bool, str]  # shells left, shot, model


@dataclass(frozen=True)
class Pair:
    """One decision scored by the production search and the deep one, in percentage points of the round win chance."""

    shells_left: int
    shot: bool
    model: str
    regret: float  # production
    deep_regret: float
    depth: int  # decisions each search finished
    deep_depth: int
    limited: bool  # the budget stopped the search
    deep_limited: bool
    best_changed: bool  # the two searches pick a different best move
    best_loses: float  # points the deep search says the production best move gives up against its own best: 0 for a tie

    @property
    def stratum(self) -> Stratum:
        return (self.shells_left, self.shot, self.model)


def pairs(deep_path: Path, regret_path: Path, knowledge_path: Path) -> list[Pair]:
    """The deep run's searched decisions with the production score of the same decision, matched by match and ordinal."""
    db = connect(str(deep_path))
    db.execute("ATTACH DATABASE ? AS s", (f"file:{regret_path}?mode=ro",))
    db.execute("ATTACH DATABASE ? AS k", (f"file:{knowledge_path}?mode=ro",))
    rows = db.execute(
        """SELECT d.remaining, d.choice, p.model, s.regret, t.regret, s.depth, t.depth, s.limited, t.limited, s.best, t.best, t.best_score, t.values_json
           FROM regret t
           JOIN s.regret s ON s.match_id = t.match_id AND s.ordinal = t.ordinal AND s.max_depth = ? AND s.budget = ? AND s.reload = 'static' AND s.status = 'searched'
           JOIN k.decisions d ON d.match_id = t.match_id AND d.ordinal = t.ordinal AND d.by_whom = 'agent'
           JOIN k.players p ON p.match_id = d.match_id AND p.player = d.player
           WHERE t.max_depth = ? AND t.budget = ? AND t.reload = 'static' AND t.status = 'searched'
           ORDER BY t.match_id, t.ordinal""",
        (DEPTH, BUDGET, DEEP_DEPTH, DEEP_BUDGET),
    ).fetchall()

    def loses(values_json: str, production_best: str, deep_best_score: int) -> float:
        score = next(move["score"] for move in json.loads(values_json) if move["label"] == production_best)
        return (deep_best_score - score) / POINT

    return [
        Pair(remaining, choice.startswith("Shoot"), model, regret / POINT, deep_regret / POINT, depth, deep_depth, bool(limited), bool(deep_limited), best != deep_best, loses(values, best, deep_score))
        for remaining, choice, model, regret, deep_regret, depth, deep_depth, limited, deep_limited, best, deep_best, deep_score, values in rows
    ]


def estimate(sample: list[Pair], value: Callable[[Pair], float], sizes: Mapping[Stratum, int]) -> Estimate:
    """The population mean of `value` over the strata present in `sample`, each weighted by its size in the whole run."""
    strata: dict[Stratum, list[float]] = {}
    for pair in sample:
        strata.setdefault(pair.stratum, []).append(value(pair))
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

START, END = "<!-- regret-depth:start -->", "<!-- regret-depth:end -->"


def sizes_of(run: list[Decision]) -> Mapping[Stratum, int]:
    """How many decisions the whole run holds in each stratum."""
    return Counter((d.shells_left, d.shot, d.model) for d in run)


def two_places(value: float) -> str:
    return f"{value:.2f}"


def signed(e: Estimate) -> str:
    return f"{round(e.mean, 2) + 0.0:+.2f} ± {e.half_width:.2f}"


def by_cell(sample: list[Pair], run: list[Decision], sizes: Mapping[Stratum, int]) -> str:
    """Shots and item moves apart, by shells left in the gun and pooled over it."""
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
                    f"{len(scored):,}",
                    pct(mean(lambda p: p.limited).mean),
                    pct(mean(lambda p: p.deep_limited).mean),
                    two_places(mean(lambda p: p.deep_depth - p.depth).mean),
                    two_places(mean(lambda p: p.regret).mean),
                    two_places(mean(lambda p: p.deep_regret).mean),
                    signed(mean(lambda p: p.deep_regret - p.regret)),
                    pct(mean(lambda p: p.best_changed).mean),
                    pct(mean(lambda p: p.best_loses > 0).mean),
                ]
            )
    return table(["kind", "shells left", "decisions", "scored", "depth 6 limited", "depth 8 limited", "extra depth", "regret at 6", "regret at 8", "8 minus 6", "best move changed", "best move strictly worse at 8"], rows)


def by_limit(sample: list[Pair], sizes: Mapping[Stratum, int]) -> str:
    """Decisions the production search finished depth 6 on and decisions its budget stopped, apart."""
    rows = []
    for limited, name in ((False, "reached depth 6"), (True, "stopped by the budget")):
        scored = [p for p in sample if p.limited == limited]
        if not scored:
            continue
        mean = lambda value: estimate(scored, value, sizes)
        rows.append([name, f"{len(scored):,}", two_places(mean(lambda p: p.regret).mean), two_places(mean(lambda p: p.deep_regret).mean), signed(mean(lambda p: p.deep_regret - p.regret)), pct(mean(lambda p: p.best_changed).mean), pct(mean(lambda p: p.deep_limited).mean)])
    return table(["production search", "scored", "regret at 6", "regret at 8", "8 minus 6", "best move changed", "depth 8 limited"], rows)


def by_model(sample: list[Pair], sizes: Mapping[Stratum, int]) -> str:
    """Each model's mean regret at both depths, and its rank at each (1 is lowest)."""
    models = sorted({p.model for p in sample})
    mean = lambda model, value: estimate([p for p in sample if p.model == model], value, sizes)
    shallow = {m: mean(m, lambda p: p.regret).mean for m in models}
    deep = {m: mean(m, lambda p: p.deep_regret).mean for m in models}
    rank = lambda means: {m: 1 + sum(means[other] < means[m] for other in models) for m in models}
    shallow_rank, deep_rank = rank(shallow), rank(deep)
    rows = [[m, str(sum(p.model == m for p in sample)), two_places(shallow[m]), str(shallow_rank[m]), two_places(deep[m]), str(deep_rank[m]), signed(mean(m, lambda p: p.deep_regret - p.regret))] for m in sorted(models, key=shallow.__getitem__)]
    return table(["model", "scored", "regret at 6", "rank", "regret at 8", "rank", "8 minus 6"], rows)


def report(sample: list[Pair], run: list[Decision]) -> str:
    sizes = sizes_of(run)
    mean = lambda value: estimate(sample, value, sizes)
    lines = [
        f"{len(sample):,} decisions scored at depth {DEEP_DEPTH} with {DEEP_BUDGET:,} nodes and at depth {DEPTH} with {BUDGET:,}, drawn from the run's {len(run):,}.",
        f"Over the run the best move changes in {pct(mean(lambda p: p.best_changed).mean)} of decisions, and in {pct(mean(lambda p: p.best_loses > 0).mean)} the deep search scores the old best move strictly lower than its own. Mean regret goes from {two_places(mean(lambda p: p.regret).mean)} to {two_places(mean(lambda p: p.deep_regret).mean)} points ({signed(mean(lambda p: p.deep_regret - p.regret))}).",
        f"The budget still stops {pct(mean(lambda p: p.deep_limited).mean)} of the depth 8 searches, against {pct(mean(lambda p: p.limited).mean)} at depth 6.",
    ]
    return "\n".join(lines) + f"\n\n### By shells left in the gun\n\n{by_cell(sample, run, sizes)}\n\n### By how the production search ended\n\n{by_limit(sample, sizes)}\n\n### By model\n\n{by_model(sample, sizes)}\n"


def replace_between(path: Path, text: str) -> None:
    head, rest = path.read_text().split(START)
    tail = rest.split(END)[1]
    path.write_text(f"{head}{START}\n{text}{END}{tail}")


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__.split("\n")[0])
    parser.add_argument("--regret", type=Path, default=DERIVED / "regret.sqlite")
    parser.add_argument("--knowledge", type=Path, default=DERIVED / "knowledge.sqlite")
    commands = parser.add_subparsers(dest="command", required=True)
    sampling = commands.add_parser("sample")
    sampling.add_argument("--out", type=Path, required=True)
    sampling.add_argument("--lists", type=int, default=24)
    sampling.add_argument("--seed", type=int, default=20261029)
    reporting = commands.add_parser("report")
    reporting.add_argument("--deep", type=Path, default=DERIVED / "regret-depth.sqlite")
    reporting.add_argument("--doc", type=Path)
    args = parser.parse_args()
    run = population(args.regret, args.knowledge, DEPTH, BUDGET)
    if args.command == "sample":
        lists = draw(run, QUOTA, args.lists, args.seed)
        args.out.mkdir(parents=True, exist_ok=True)
        for index, chosen in enumerate(lists):
            (args.out / f"list-{index:02d}.txt").write_text("".join(f"{d.match_id} {d.ordinal}\n" for d in chosen))
        print(f"{sum(map(len, lists)):,} decisions in {args.lists} lists of {len(lists[0])} or {len(lists[-1])}")
        return
    text = report(pairs(args.deep, args.regret, args.knowledge), run)
    if args.doc is None:
        print(text)
    else:
        replace_between(args.doc, text)


if __name__ == "__main__":
    main()
