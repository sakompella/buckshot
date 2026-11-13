#!/usr/bin/env python3
"""Round win rate and mean regret per config, by round number.

Round winners come from the replayed events in the analysis database. Regret comes from the regret and knowledge databases, as
in regret.py. All three are opened read-only. With --doc FILE the tables replace the text between the by-round markers of that
file. A config is a model with its effort. Excluded matches (matches.disposition, as the importer sets it) and unfinished
matches are left out.

    python3 tools/arena/analysis/by_round.py [--db PATH] [--regret PATH] [--knowledge PATH] [--doc docs/arena/analysis/regret.md]
"""

import argparse
from collections import defaultdict
from dataclasses import dataclass, replace
from pathlib import Path

import regret
from docs import splice_between_markers
from fmt import pct, table
from load import DB, connect, require_current, round_winners
from configs import EFFORTS, config_effort, effort_rank
from regret import DERIVED, PRODUCTION, Decision, points
from rules import ROUNDS


@dataclass(frozen=True)
class RoundResult:
    model: str
    effort: str
    round: int
    won: bool


def load_results(db_path: str, knowledge_path: Path) -> list[RoundResult]:
    """Both seats of every round of the finished matches, with the seat's config and whether it won."""
    knowledge = connect(str(knowledge_path))
    seats = defaultdict(dict)
    for match, player, model, effort in knowledge.execute(
        """SELECT p.match_id, p.player, p.model, p.effort FROM players p
           JOIN matches m ON m.match_id = p.match_id AND m.status = 'completed' AND m.disposition IS NULL WHERE p.model IS NOT NULL"""
    ):
        seats[match][player] = (model, config_effort(model, effort))
    results = []
    winners_of = round_winners(connect(db_path))
    for match in seats:
        winners = winners_of[match]
        results += [RoundResult(model, effort, round, winner == player) for round, winner in winners.items() for player, (model, effort) in seats[match].items()]
    return results


def cell(values: list[float], show) -> str:
    return f"{show(sum(values) / len(values))} ({len(values):,})" if values else "-"


def by_round(results: list[RoundResult], decisions: list[Decision]) -> str:
    """Models from the lowest mean regret to the highest, each with its efforts from off to max (or "all", first). Counts in brackets."""
    key = lambda config: (config[0], effort_rank(config[1]) if config[1].split("/")[0] in EFFORTS else -1)
    wins: dict[tuple[str, str, int], list[float]] = defaultdict(list)
    regrets: dict[tuple[str, str, int], list[float]] = defaultdict(list)
    for r in results:
        wins[r.model, r.effort, r.round].append(r.won)
    for d in decisions:
        regrets[d.model, d.effort, d.round].append(d.regret)
    configs = sorted({k[:2] for k in wins}, key=key)
    model_mean = {m: sum(d.regret for d in decisions if d.model == m) / sum(d.model == m for d in decisions) for m, _ in configs}
    header = ["model", "effort"] + [f"round {n} {what}" for n in ROUNDS for what in ("win rate", "mean regret")]
    rows = [
        [model, effort] + [c for n in ROUNDS for c in (cell(wins[model, effort, n], pct), cell(regrets[model, effort, n], points))]
        for model, effort in sorted(configs, key=lambda c: (model_mean[c[0]], *key(c)))
    ]
    everyone = ["all", ""]
    for n in ROUNDS:
        everyone += ["-", cell([d.regret for d in decisions if d.round == n], points)]
    return table(header, rows + [everyone])


def by_move_kind(decisions: list[Decision]) -> str:
    """All configs together, shots and item moves apart."""
    rows = []
    for n in ROUNDS:
        row = [str(n), cell([d.regret for d in decisions if d.round == n], points)]
        for shot in (True, False):
            row.append(cell([d.regret for d in decisions if d.round == n and d.shot == shot], points))
        rows.append(row)
    return table(["round", "all moves", "shots", "item moves"], rows)


def pooled_over_efforts(results: list[RoundResult], decisions: list[Decision]) -> tuple[list[RoundResult], list[Decision]]:
    return [replace(r, effort="all") for r in results], [replace(d, effort="all") for d in decisions]


def report(results: list[RoundResult], decisions: list[Decision]) -> str:
    return (
        f"{len(results) // 2:,} rounds of finished matches.\n\n"
        f"### Win rate and regret by round, per model\n\n{by_round(*pooled_over_efforts(results, decisions))}\n\n"
        f"### Mean regret by round and kind of move\n\n{by_move_kind(decisions)}\n\n"
        f"### Win rate and regret by round, per config\n\n{by_round(results, decisions)}\n"
    )


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__.split("\n")[0])
    parser.add_argument("--db", default=DB)
    parser.add_argument("--regret", type=Path, default=PRODUCTION)
    parser.add_argument("--knowledge", type=Path, default=DERIVED / "knowledge.sqlite")
    parser.add_argument("--doc", type=Path)
    args = parser.parse_args()
    require_current(args.db)
    text = report(load_results(args.db, args.knowledge), regret.load(args.regret, args.knowledge).decisions)
    if args.doc is None:
        print(text)
    else:
        splice_between_markers(args.doc, "by-round", text)


if __name__ == "__main__":
    main()
