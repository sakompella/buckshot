#!/usr/bin/env python3
"""Mean and 90th-percentile regret per config, and where regret sits relative to the next reload.

Reads the regret table (web/scripts/arena-regret.ts) and the knowledge database (web/scripts/arena-knowledge.ts)
read-only and prints markdown tables. With --doc FILE the tables replace the text between the tables markers of
that file. A config is a model with its effort. Regret is in percentage points of the deciding player's chance to win the
round. Matches with a DeepSeek seat, unfinished matches and forced or fallback moves are left out.

    python3 tools/arena/analysis/regret.py [--regret PATH] [--knowledge PATH] [--depth 6] [--budget 20000] [--doc docs/arena/analysis/regret.md]
"""

import argparse
import math
import sqlite3
from dataclasses import dataclass
from itertools import groupby
from pathlib import Path

from fmt import pct, table
from load import SKIPPED_MODEL, connect

DERIVED = Path("/home/aditya/repos/projects/buckshot/_work/arena/analysis/derived")

START, END = "<!-- tables:start -->", "<!-- tables:end -->"

EFFORTS = ["off", "minimal", "low", "medium", "high", "xhigh", "max"]

# Scores are in millionths of a round win.
POINT = 10_000


@dataclass(frozen=True)
class Decision:
    model: str
    effort: str
    shells_left: int
    shot: bool
    regret: int
    exact: bool
    limited: bool


@dataclass(frozen=True)
class Loaded:
    decisions: list[Decision]
    unsearched: int
    unscored: int


@dataclass(frozen=True)
class Summary:
    count: int
    mean: float
    p90: float
    exact: float


def percentile(values: list[float], share: float) -> float:
    """Linear interpolation between the closest ranks."""
    ordered = sorted(values)
    rank = share * (len(ordered) - 1)
    low = math.floor(rank)
    high = min(low + 1, len(ordered) - 1)
    return ordered[low] + (ordered[high] - ordered[low]) * (rank - low)


def summarise(decisions: list[Decision]) -> Summary:
    regrets = [d.regret for d in decisions]
    return Summary(len(regrets), sum(regrets) / len(regrets), percentile(regrets, 0.9), sum(d.exact for d in decisions) / len(decisions))


def load(regret_path: Path, knowledge_path: Path, depth: int, budget: int) -> Loaded:
    """The scored agent decisions of finished matches, with the deciding player's config and the shells left in the gun."""
    db = connect(str(regret_path))
    db.row_factory = sqlite3.Row
    db.execute("ATTACH DATABASE ? AS k", (f"file:{knowledge_path}?mode=ro",))
    rows = db.execute(
        """SELECT p.model, p.effort, d.remaining, d.choice, r.status, r.regret, r.exact, r.limited, r.evaluator
           FROM regret r
           JOIN k.matches m ON m.match_id = r.match_id AND m.status = 'completed'
           JOIN k.decisions d ON d.match_id = r.match_id AND d.ordinal = r.ordinal AND d.by_whom = 'agent'
           JOIN k.players p ON p.match_id = d.match_id AND p.player = d.player
           WHERE r.max_depth = ? AND r.budget = ? AND r.match_id NOT IN (SELECT match_id FROM k.players WHERE model LIKE ?)""",
        (depth, budget, f"%{SKIPPED_MODEL}%"),
    ).fetchall()
    if len({row["evaluator"] for row in rows}) > 1:
        raise SystemExit(f"{regret_path} holds rows of several evaluators at depth {depth} and budget {budget}; they must not be mixed.")
    unscored = db.execute(
        """SELECT COUNT(*) FROM k.decisions d JOIN k.matches m ON m.match_id = d.match_id AND m.status = 'completed'
           WHERE d.by_whom = 'agent' AND d.match_id NOT IN (SELECT match_id FROM k.players WHERE model LIKE ?)
             AND NOT EXISTS (SELECT 1 FROM regret r WHERE r.match_id = d.match_id AND r.ordinal = d.ordinal AND r.max_depth = ? AND r.budget = ?)""",
        (f"%{SKIPPED_MODEL}%", depth, budget),
    ).fetchone()[0]
    searched = [row for row in rows if row["status"] == "searched"]
    return Loaded(
        [Decision(r["model"], r["effort"], r["remaining"], r["choice"].startswith("Shoot"), r["regret"], bool(r["exact"]), bool(r["limited"])) for r in searched],
        len(rows) - len(searched),
        unscored,
    )


def points(millionths: float) -> str:
    return f"{millionths / POINT:.1f}"


def by_config(decisions: list[Decision]) -> str:
    """Models from the lowest mean regret to the highest, each with its efforts from off to max."""
    key = lambda d: (d.model, EFFORTS.index(d.effort))
    models = {model: summarise(list(group)).mean for model, group in groupby(sorted(decisions, key=key), lambda d: d.model)}
    rows = []
    for (model, effort), group in groupby(sorted(decisions, key=lambda d: (models[d.model], *key(d))), lambda d: (d.model, d.effort)):
        s = summarise(list(group))
        rows.append([model, effort, f"{s.count:,}", points(s.mean), points(s.p90), pct(s.exact)])
    everyone = summarise(decisions)
    rows.append(["all", "", f"{everyone.count:,}", points(everyone.mean), points(everyone.p90), pct(everyone.exact)])
    return table(["model", "effort", "decisions", "mean regret", "90th percentile", "exact"], rows)


def by_shells_left(decisions: list[Decision]) -> str:
    """Shots and item moves apart, by shells left in the gun when the player chose. Most searches with many shells left are stopped by the node budget."""
    rows = []
    for left in sorted({d.shells_left for d in decisions}):
        at = [d for d in decisions if d.shells_left == left]
        row = [str(left), pct(sum(d.limited for d in at) / len(at))]
        for shot in (True, False):
            s = summarise([d for d in at if d.shot == shot])
            row += [f"{s.count:,}", points(s.mean), points(s.p90)]
        rows.append(row)
    return table(["shells left", "stopped by budget", "shots", "mean", "90th percentile", "item moves", "mean", "90th percentile"], rows)


def report(loaded: Loaded) -> str:
    decisions = loaded.decisions
    return (
        f"{len(decisions):,} searched decisions; {loaded.unsearched:,} left out for having no search; {loaded.unscored:,} agent decisions with no row.\n\n"
        f"### Regret by config\n\n{by_config(decisions)}\n\n"
        f"### Regret by shells left in the gun\n\n{by_shells_left(decisions)}\n"
    )


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__.split("\n")[0])
    parser.add_argument("--regret", type=Path, default=DERIVED / "regret.sqlite")
    parser.add_argument("--knowledge", type=Path, default=DERIVED / "knowledge.sqlite")
    parser.add_argument("--depth", type=int, default=6)
    parser.add_argument("--budget", type=int, default=20000)
    parser.add_argument("--doc", type=Path)
    args = parser.parse_args()
    text = report(load(args.regret, args.knowledge, args.depth, args.budget))
    if args.doc is None:
        print(text)
    else:
        head, rest = args.doc.read_text().split(START)
        tail = rest.split(END)[1]
        args.doc.write_text(f"{head}{START}\n{text}{END}{tail}")


if __name__ == "__main__":
    main()
