"""Certain-mistake rates per config: shots that the deciding player's own information proves worse than the other shot.

Two mistake types, each over its own opportunities, the agent decisions at which the player's own log proves the chambered shell:

- Self on a proven live: the player shot itself, where shooting the opponent leaves every rule state the same except whose health falls.
- Opponent on a proven blank: the player shot the opponent, where shooting itself leaves every rule state the same except that it keeps the move.
  Decisions where the opponent shows as jammed are excluded and counted, because there the two shots also leave different jam states.

"Proves" is the chamber column of the knowledge database (web/scripts/arena-knowledge.ts), from the Bend belief over the player's own log.
Matches with a DeepSeek seat, unfinished matches and fallback moves are left out. With --doc FILE the tables replace the text between the
tables markers of that file.

    python3 tools/arena/analysis/certain_mistakes.py [--knowledge PATH] [--doc docs/arena/analysis/certain-mistakes.md]
"""

import argparse
import json
import random
from dataclasses import dataclass
from enum import Enum
from pathlib import Path

from boot import interval, weights
from fmt import pct, table
from load import SKIPPED_MODEL, connect
from regret import DERIVED, EFFORTS, END, START

RESAMPLES = 2000


class Kind(Enum):
    SELF_ON_LIVE = "Live"
    OPPONENT_ON_BLANK = "Blank"


class Verdict(Enum):
    MISTAKE = "mistake"
    SOUND = "sound"
    EXCLUDED = "excluded"


@dataclass(frozen=True)
class Decision:
    """An agent decision at which the player's own information proves the chambered shell."""

    model: str
    effort: str
    block: str
    kind: Kind
    source: str  # public, glass, phone or combined
    shot: str | None  # self, opponent, or None for an item move
    opponent_jammed: bool
    last_shell: bool


def judge(decision: Decision) -> Verdict:
    match decision.kind:
        case Kind.SELF_ON_LIVE:
            return Verdict.MISTAKE if decision.shot == "self" else Verdict.SOUND
        case Kind.OPPONENT_ON_BLANK:
            if decision.opponent_jammed:
                return Verdict.EXCLUDED
            return Verdict.MISTAKE if decision.shot == "opponent" else Verdict.SOUND


def load(knowledge_path: Path) -> list[Decision]:
    db = connect(str(knowledge_path))
    rows = db.execute(
        """SELECT p.model, p.effort, m.seed_block_id, d.chamber, d.source, d.shot, d.health_json, d.remaining
           FROM decisions d
           JOIN matches m ON m.match_id = d.match_id AND m.status = 'completed'
           JOIN players p ON p.match_id = d.match_id AND p.player = d.player
           WHERE d.by_whom = 'agent' AND d.chamber IS NOT NULL
             AND d.match_id NOT IN (SELECT match_id FROM players WHERE model LIKE ?)
           ORDER BY d.match_id, d.ordinal""",
        (f"%{SKIPPED_MODEL}%",),
    ).fetchall()
    db.close()
    return [
        Decision(model, effort, block, Kind(chamber), source, shot, json.loads(health)[1]["_tag"] == "Jammed", remaining == 1)
        for model, effort, block, chamber, source, shot, health, remaining in rows
    ]


@dataclass(frozen=True)
class Rate:
    opportunities: int
    excluded: int
    mistakes: int
    interval: tuple[float, float] | None

    @property
    def counted(self) -> int:
        return self.opportunities - self.excluded

    def cell(self) -> str:
        if self.counted == 0:
            return "–"
        bounds = "" if self.interval is None else f" [{pct(self.interval[0])}, {pct(self.interval[1])}]"
        return f"{pct(self.mistakes / self.counted)} ({self.mistakes}/{self.counted}){bounds}"


def rate(decisions: list[Decision], rng: random.Random) -> Rate:
    """Mistakes over the counted opportunities, with a 95% interval from resampling whole seed blocks."""
    verdicts = [judge(d) for d in decisions]
    per_block: dict[str, list[int]] = {}
    for decision, verdict in zip(decisions, verdicts):
        if verdict is not Verdict.EXCLUDED:
            tally = per_block.setdefault(decision.block, [0, 0])
            tally[0] += 1
            tally[1] += verdict is Verdict.MISTAKE
    blocks = sorted(per_block)
    replicates = []
    for _ in range(RESAMPLES if blocks else 0):
        drawn = weights(blocks, rng)
        counted = sum(per_block[b][0] * n for b, n in drawn.items())
        replicates.append(sum(per_block[b][1] * n for b, n in drawn.items()) / counted)
    return Rate(len(decisions), verdicts.count(Verdict.EXCLUDED), verdicts.count(Verdict.MISTAKE), interval(replicates))


def by_config(decisions: list[Decision]) -> str:
    rng = random.Random(0)
    configs = sorted({(d.model, d.effort) for d in decisions}, key=lambda c: (c[0], EFFORTS.index(c[1])))
    rows = []
    for model, effort in configs:
        mine = [d for d in decisions if (d.model, d.effort) == (model, effort)]
        live = rate([d for d in mine if d.kind is Kind.SELF_ON_LIVE], rng)
        blank = rate([d for d in mine if d.kind is Kind.OPPONENT_ON_BLANK], rng)
        rows.append([model, effort, f"{live.opportunities:,}", live.cell(), f"{blank.opportunities:,}", f"{blank.excluded:,}", blank.cell()])
    return table(
        ["model", "effort", "proven live", "shot itself", "proven blank", "excluded, opponent jammed", "shot the opponent"],
        rows,
    )


def breakdown(decisions: list[Decision]) -> str:
    rng = random.Random(0)
    groups = [(source, lambda d, source=source: d.source == source) for source in ("public", "glass", "phone", "combined")]
    groups += [("last shell", lambda d: d.last_shell), ("earlier shells", lambda d: not d.last_shell)]
    rows = []
    for kind, label in ((Kind.SELF_ON_LIVE, "shot itself on a proven live"), (Kind.OPPONENT_ON_BLANK, "shot the opponent on a proven blank")):
        rows.append([label] + [rate([d for d in decisions if d.kind is kind and keep(d)], rng).cell() for _, keep in groups])
    return table(["mistake"] + [name for name, _ in groups], rows)


def report(decisions: list[Decision]) -> str:
    return f"### By config\n\n{by_config(decisions)}\n\n### By source of the proof and shells left, all configs\n\n{breakdown(decisions)}\n"


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__.split("\n")[0])
    parser.add_argument("--knowledge", type=Path, default=DERIVED / "knowledge.sqlite")
    parser.add_argument("--doc", type=Path)
    args = parser.parse_args()
    text = report(load(args.knowledge))
    if args.doc is None:
        print(text)
    else:
        head, rest = args.doc.read_text().split(START)
        tail = rest.split(END)[1]
        args.doc.write_text(f"{head}{START}\n{text}{END}{tail}")


if __name__ == "__main__":
    main()
