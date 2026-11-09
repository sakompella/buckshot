#!/usr/bin/env python3
"""Round win rate and mean regret per config, by round number.

Round winners come from the public lines of events.jsonl in the analysis database, read as web/src/arena-viewer/analysis.ts
reads them. Regret comes from the regret and knowledge databases, as in regret.py. All three are opened read-only. With
--doc FILE the tables replace the text between the by-round markers of that file. A config is a model with its effort.
Matches with a DeepSeek seat and unfinished matches are left out. A match whose prizes do not add up to the final cash stops the run.

    python3 tools/arena/analysis/by_round.py [--db PATH] [--regret PATH] [--knowledge PATH] [--depth 6] [--budget 20000] [--reload static] [--samples 256] [--doc docs/arena/analysis/regret.md]
"""

import argparse
import json
import re
from collections import defaultdict
from dataclasses import dataclass, replace
from pathlib import Path

import regret
from docs import splice_between_markers
from fmt import pct, table
from load import DB, SKIPPED_MODEL, connect, require_current
from regret import DERIVED, EFFORTS, Decision, points

ROUNDS = (1, 2, 3)

BEGINS = re.compile(r"^Round (\d+) begins\.")
WINS = re.compile(r"^Player (\w+) wins the round and \$([\d,]+)\.")


@dataclass(frozen=True)
class RoundResult:
    model: str
    effort: str
    round: int
    won: bool


def round_winners(match: str, lines: list[str], cash: dict[str, int]) -> dict[int, str]:
    """Round number to the winner's letter. Raises when the round log and the final cash disagree, naming the match and the lines and cash that disagree.

    The last round's win line may be missing; then the one player with cash left over won it.
    """

    def disagree(why: str) -> ValueError:
        shown = [line for line in lines if BEGINS.match(line) or WINS.match(line)]
        return ValueError(f"match {match}: {why}; final cash {cash}; round lines {shown}")

    current = 0
    won: dict[int, tuple[str, int]] = {}
    for line in lines:
        if begins := BEGINS.match(line):
            current = int(begins[1])
        elif (wins := WINS.match(line)) and current not in won:
            won[current] = (wins[1], int(wins[2].replace(",", "")))
    if not won or any(round not in won for round in range(1, current)):
        raise disagree("a round has no winner line")
    left = dict(cash)
    for winner, prize in won.values():
        left[winner] = left.get(winner, 0) - prize
    if current not in won:
        ahead = [player for player, rest in left.items() if rest > 0]
        if len(ahead) != 1:
            raise disagree("the last round has no winner line and the cash left over does not name one")
        won[current] = (ahead[0], left[ahead[0]])
        left[ahead[0]] = 0
    if any(rest != 0 for rest in left.values()):
        raise disagree("the prizes do not add up to the final cash")
    return {round: winner for round, (winner, _) in won.items()}


def public_lines(db) -> dict[str, list[str]]:
    """Match id to the public lines of the longest log any player was shown, in order."""
    logs: dict[tuple[str, str], dict[int, list[str]]] = defaultdict(dict)
    for match, raw in db.execute(
        """SELECT f.match_id, r.raw FROM source_files f JOIN source_records r ON r.path = f.path AND r.current = 1
           WHERE f.path LIKE '%/events.jsonl' AND r.raw LIKE '%"kind":"delivered"%'"""
    ):
        event = json.loads(raw)
        logs[match, event["player"]][event["from"]] = event["entries"]
    longest: dict[str, list[str]] = {}
    for (match, _), by_start in logs.items():
        lines = [line for start in sorted(by_start) for line in by_start[start]]
        if len(lines) > len(longest.get(match, [])):
            longest[match] = lines
    return longest


def read_winners(db_path: str, matches: list[str]) -> dict[str, dict[int, str]]:
    """Round number to winner's letter for each match."""
    db = connect(db_path)
    cash = defaultdict(dict)
    for match, player, total in db.execute("SELECT match_id, player, cash FROM match_seats"):
        cash[match][player] = total
    lines = public_lines(db)
    return {match: round_winners(match, lines.get(match, []), cash[match]) for match in matches}


def load_results(db_path: str, knowledge_path: Path) -> list[RoundResult]:
    """Both seats of every round of the finished matches, with the seat's config and whether it won."""
    knowledge = connect(str(knowledge_path))
    seats = defaultdict(dict)
    for match, player, model, effort in knowledge.execute(
        """SELECT p.match_id, p.player, p.model, p.effort FROM players p JOIN matches m ON m.match_id = p.match_id AND m.status = 'completed'
           WHERE p.model IS NOT NULL AND p.match_id NOT IN (SELECT match_id FROM players WHERE model LIKE ?)""",
        (f"%{SKIPPED_MODEL}%",),
    ):
        seats[match][player] = (model, effort)
    results = []
    for match, winners in read_winners(db_path, list(seats)).items():
        results += [RoundResult(model, effort, round, winner == player) for round, winner in winners.items() for player, (model, effort) in seats[match].items()]
    return results


def cell(values: list[float], show) -> str:
    return f"{show(sum(values) / len(values))} ({len(values):,})" if values else "-"


def by_round(results: list[RoundResult], decisions: list[Decision]) -> str:
    """Models from the lowest mean regret to the highest, each with its efforts from off to max (or "all", first). Counts in brackets."""
    key = lambda config: (config[0], EFFORTS.index(config[1]) if config[1] in EFFORTS else -1)
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
    parser.add_argument("--regret", type=Path, default=DERIVED / "regret.sqlite")
    parser.add_argument("--knowledge", type=Path, default=DERIVED / "knowledge.sqlite")
    parser.add_argument("--depth", type=int, default=6)
    parser.add_argument("--budget", type=int, default=20000)
    parser.add_argument("--reload", choices=["static", "expected-deal", "sampled"], default="static")
    parser.add_argument("--samples", type=int, help="deals per leaf of a sampled run, 256 by default")
    parser.add_argument("--doc", type=Path)
    args = parser.parse_args()
    require_current(args.db)
    text = report(load_results(args.db, args.knowledge), regret.load(args.regret, args.knowledge, args.depth, args.budget, args.reload, regret.run_samples(args.reload, args.samples)).decisions)
    if args.doc is None:
        print(text)
    else:
        splice_between_markers(args.doc, "by-round", text)


if __name__ == "__main__":
    main()
