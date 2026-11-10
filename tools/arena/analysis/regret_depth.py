"""Draws the stratified sample of two-seat agent decisions that the regret-depth run scores again with a deeper search, and summarises the run.

The deep run searches to depth 8 with ten times the node budget of the production run (depth 6, 20,000 nodes), under the same static reload rule.
`sample` cuts the sample into lists of "<match id> <ordinal>" lines. The deep run was scored with the Bend player's `web/scripts/arena-regret.ts --decisions`, removed on 2026-11-08, so it cannot be rerun as written. Each list holds an equal share of every
stratum (shells left in the gun, shot or item move, model), so a list that finishes early is still a stratified random sample.

    python3 tools/arena/analysis/regret_depth.py sample --out DIR [--lists 24] [--seed N]
    python3 tools/arena/analysis/regret_depth.py report [--deep PATH] [--lists 24] [--seed N] [--doc docs/arena/analysis/regret.md]

`report` reads the deep run and the production static run it is compared with, both read only. It fails unless both runs are of one evaluator build and the deep run holds exactly the decisions `sample` draws with the same --lists and --seed. It prints markdown tables, or with --doc rewrites the
ones between the regret-depth markers of that file.
"""

import argparse
import json
import math
import random
from collections import Counter
from collections.abc import Callable, Mapping
from dataclasses import dataclass
from itertools import chain
from pathlib import Path

from docs import splice_between_markers
from fmt import pct, table
from load import connect
from regret import DERIVED
from rules import POINT
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

    match_id: str
    ordinal: int
    shells_left: int
    shot: bool
    model: str
    regret: float  # production
    deep_regret: float
    depth: int  # decisions each search finished
    deep_depth: int
    limited: bool  # the budget stopped the search
    deep_limited: bool
    best_label_changed: bool  # the label of the chosen best move differs; a tie between several best moves can switch the label with nothing lost
    best_loses: float  # points the deep search says the production chosen best move gives up against its own best: 0 for a tie

    @property
    def stratum(self) -> Stratum:
        return (self.shells_left, self.shot, self.model)


def pairs(deep_path: Path, regret_path: Path, knowledge_path: Path) -> list[Pair]:
    """The deep run's decisions with the production score of the same decision, matched by match and ordinal.

    Fails when a deep row of these settings has no searched production row or agent decision to match, or is not itself searched, or was scored by another evaluator build than its production row: the difference would be the evaluators' as much as the depth's."""
    db = connect(str(deep_path))
    db.execute("ATTACH DATABASE ? AS s", (f"file:{regret_path}?mode=ro",))
    db.execute("ATTACH DATABASE ? AS k", (f"file:{knowledge_path}?mode=ro",))
    deep_rows = db.execute("SELECT COUNT(*) FROM regret WHERE max_depth = ? AND budget = ? AND reload = 'static'", (DEEP_DEPTH, DEEP_BUDGET)).fetchone()[0]
    rows = db.execute(
        """SELECT t.match_id, t.ordinal, d.remaining, d.shot IS NOT NULL, p.model, s.regret, t.regret, s.depth, t.depth, s.limited, t.limited, s.best, t.best, t.best_score, t.values_json, s.evaluator, t.evaluator
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

    if len(rows) != deep_rows:
        raise ValueError(f"{deep_rows - len(rows):,} of the {deep_rows:,} deep rows are not searched or have no searched production row and agent decision to match")
    evaluators = Counter((row[-2], row[-1]) for row in rows)
    if any(production != deep for production, deep in evaluators):
        raise ValueError(f"deep rows ({deep_path}) and production rows ({regret_path}) come from different evaluators; (production, deep): number of decisions = {dict(evaluators)}")
    return [
        Pair(match_id, ordinal, remaining, bool(shot), model, regret / POINT, deep_regret / POINT, depth, deep_depth, bool(limited), bool(deep_limited), best != deep_best, loses(values, best, deep_score))
        for match_id, ordinal, remaining, shot, model, regret, deep_regret, depth, deep_depth, limited, deep_limited, best, deep_best, deep_score, values, _, _ in rows
    ]


def estimate(sample: list[Pair], value: Callable[[Pair], float], sizes: Mapping[Stratum, int], domain_size: int | None = None) -> Estimate:
    """The mean of `value` over a population made of the strata in `sizes`, each weighted by its size, with a 95% interval for the sample of decisions drawn from this fixed run.

    For a domain that cuts across strata (decisions the production search stopped), pass the whole sample, a `value` that is 0 outside the domain, and the domain's size in the run: the mean is then the estimated total over the domain divided by that size.

    The interval is the stratified normal one over decisions. It leaves out variation between matches, seed blocks, tournaments and future play, and the finite-population correction, which only makes it wider.
    Every stratum of `sizes` must hold at least two sampled decisions, or all of its decisions, and the sample may hold no other stratum: otherwise the mean would silently cover another population or a stratum would count as certain."""
    strata: dict[Stratum, list[float]] = {}
    for pair in sample:
        strata.setdefault(pair.stratum, []).append(value(pair))
    foreign = strata.keys() - sizes.keys()
    thin = [k for k, size in sizes.items() if size > 0 and len(strata.get(k, [])) < min(2, size)]
    if foreign or thin:
        raise ValueError(f"sample strata outside the population: {sorted(foreign)}; population strata with too few sampled decisions: {sorted(thin)}")
    total = domain_size or sum(sizes.values())
    mean = variance = 0.0
    for k, values in strata.items():
        weight = sizes[k] / total
        centre = sum(values) / len(values)
        mean += weight * centre
        if len(values) > 1:
            variance += weight**2 * sum((v - centre) ** 2 for v in values) / (len(values) - 1) / len(values)
    return Estimate(mean, 1.96 * math.sqrt(variance))


def check_sample(sample: list[Pair], expected: set[tuple[str, int]]) -> None:
    """The deep run must hold exactly the decisions the seeded sample draws from the run."""
    found = {(p.match_id, p.ordinal) for p in sample}
    if len(found) != len(sample):
        raise ValueError("a decision is scored twice")
    if found != expected:
        raise ValueError(f"deep run holds {len(found - expected):,} decisions outside the sample and lacks {len(expected - found):,} of it")


def run_limits(regret_path: Path, run: list[Decision]) -> dict[tuple[str, int], bool]:
    """Whether the production budget stopped the search, for each decision of `run`."""
    db = connect(str(regret_path))
    rows = db.execute("SELECT match_id, ordinal, limited FROM regret WHERE max_depth = ? AND budget = ? AND reload = 'static' AND status = 'searched'", (DEPTH, BUDGET))
    limited = {(match, ordinal): bool(flag) for match, ordinal, flag in rows}
    return {(d.match_id, d.ordinal): limited[d.match_id, d.ordinal] for d in run}


# Tables
# ======


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
            if not everyone:
                continue
            domain = {k: n for k, n in sizes.items() if k[1] == shot and left in (None, k[0])}
            mean = lambda value, scored=scored, domain=domain: estimate(scored, value, domain)
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
                    pct(mean(lambda p: p.best_label_changed).mean),
                    pct(mean(lambda p: p.best_loses > 0).mean),
                ]
            )
    return table(["kind", "shells left", "decisions", "scored", "depth 6 limited", "depth 8 limited", "extra depth", "regret at 6", "regret at 8", "8 minus 6", "best label changed", "chosen best strictly worse at 8"], rows)


def by_limit(sample: list[Pair], run: list[Decision], sizes: Mapping[Stratum, int], limits: Mapping[tuple[str, int], bool]) -> str:
    """Decisions the production search finished depth 6 on and decisions its budget stopped, apart. Each mean is the estimated total over those decisions in the run divided by their number, with the strata weighted by their size."""
    rows = []
    for limited, name in ((False, "reached depth 6"), (True, "stopped by the budget")):
        scored = [p for p in sample if p.limited == limited]
        in_domain = sum(limits[d.match_id, d.ordinal] == limited for d in run)
        mean = lambda value, limited=limited, in_domain=in_domain: estimate(sample, lambda p: value(p) * (p.limited == limited), sizes, in_domain)
        rows.append([name, f"{len(scored):,}", two_places(mean(lambda p: p.regret).mean), two_places(mean(lambda p: p.deep_regret).mean), signed(mean(lambda p: p.deep_regret - p.regret)), pct(mean(lambda p: p.best_label_changed).mean), pct(mean(lambda p: p.deep_limited).mean)])
    return table(["production search", "scored", "regret at 6", "regret at 8", "8 minus 6", "best label changed", "depth 8 limited"], rows)


def by_model(sample: list[Pair], sizes: Mapping[Stratum, int]) -> str:
    """Each model's mean regret at both depths, and its rank at each (1 is lowest)."""
    models = sorted({p.model for p in sample})
    mean = lambda model, value: estimate([p for p in sample if p.model == model], value, {k: n for k, n in sizes.items() if k[2] == model})
    shallow = {m: mean(m, lambda p: p.regret).mean for m in models}
    deep = {m: mean(m, lambda p: p.deep_regret).mean for m in models}
    rank = lambda means: {m: 1 + sum(means[other] < means[m] for other in models) for m in models}
    shallow_rank, deep_rank = rank(shallow), rank(deep)
    rows = [[m, str(sum(p.model == m for p in sample)), two_places(shallow[m]), str(shallow_rank[m]), two_places(deep[m]), str(deep_rank[m]), signed(mean(m, lambda p: p.deep_regret - p.regret))] for m in sorted(models, key=shallow.__getitem__)]
    return table(["model", "scored", "regret at 6", "rank", "regret at 8", "rank", "8 minus 6"], rows)


def report(sample: list[Pair], run: list[Decision], limits: Mapping[tuple[str, int], bool]) -> str:
    sizes = sizes_of(run)
    mean = lambda value: estimate(sample, value, sizes)
    lines = [
        f"{len(sample):,} decisions scored at depth {DEEP_DEPTH} with {DEEP_BUDGET:,} nodes and at depth {DEPTH} with {BUDGET:,}, drawn from the run's {len(run):,}.",
        f"Over the run the chosen best move's label changes in {pct(mean(lambda p: p.best_label_changed).mean)} of decisions, and in {pct(mean(lambda p: p.best_loses > 0).mean)} the deep search scores the old chosen best move strictly lower than its own. Mean regret goes from {two_places(mean(lambda p: p.regret).mean)} to {two_places(mean(lambda p: p.deep_regret).mean)} points ({signed(mean(lambda p: p.deep_regret - p.regret))}).",
        f"The budget still stops {pct(mean(lambda p: p.deep_limited).mean)} of the depth 8 searches, against {pct(mean(lambda p: p.limited).mean)} at depth 6.",
    ]
    return "\n".join(lines) + f"\n\n### By shells left in the gun\n\n{by_cell(sample, run, sizes)}\n\n### By how the production search ended\n\n{by_limit(sample, run, sizes, limits)}\n\n### By model\n\n{by_model(sample, sizes)}\n"


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
    reporting.add_argument("--lists", type=int, default=24)
    reporting.add_argument("--seed", type=int, default=20261029)
    args = parser.parse_args()
    run = population(args.regret, args.knowledge, DEPTH, BUDGET)
    if args.command == "sample":
        lists = draw(run, QUOTA, args.lists, args.seed)
        args.out.mkdir(parents=True, exist_ok=True)
        for index, chosen in enumerate(lists):
            (args.out / f"list-{index:02d}.txt").write_text("".join(f"{d.match_id} {d.ordinal}\n" for d in chosen))
        print(f"{sum(map(len, lists)):,} decisions in {args.lists} lists of {len(lists[0])} or {len(lists[-1])}")
        return
    limits = run_limits(args.regret, run)
    sample = pairs(args.deep, args.regret, args.knowledge)
    check_sample(sample, {(d.match_id, d.ordinal) for d in chain.from_iterable(draw(run, QUOTA, args.lists, args.seed))})
    text = report(sample, run, limits)
    if args.doc is None:
        print(text)
    else:
        splice_between_markers(args.doc, "regret-depth", text)


if __name__ == "__main__":
    main()
