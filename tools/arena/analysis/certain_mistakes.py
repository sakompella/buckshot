"""Certain-mistake rates per config: shots that the deciding player's own information proves worse than the other shot.

Each certain mistake is counted over its own opportunities, the agent decisions where the player's own information proves it:

- Shot itself on a proven live. Shooting the opponent instead leaves every rule state the same except whose health falls.
- Shot the opponent, giving up a guaranteed win. The chamber is a proven blank and the next shell a proven live that kills the opponent,
  so shooting itself wins the round on every line, while after the opponent shot the opponent can kill the player with its next move.

Every other proven blank is the fact pattern "proven blank, gave the turn away". Keeping the move is not proven better there, so it never
enters a certain-mistake rate. Its decisions are split by what the depth-limited search of the regret database scored.

"Proves" is the knowledge database (web/scripts/arena-knowledge.ts): the Bend belief over the player's own log. Matches with a DeepSeek
seat, unfinished matches and fallback moves are left out. With --doc FILE the tables replace the text between the tables markers of that file.

    python3 tools/arena/analysis/certain_mistakes.py [--knowledge PATH] [--regret PATH] [--doc docs/arena/analysis/certain-mistakes.md]
"""

import argparse
import json
import random
from collections.abc import Callable
from dataclasses import dataclass
from enum import Enum
from pathlib import Path

from boot import interval, weights
from fmt import pct, table
from load import SKIPPED_MODEL, connect
from regret import DERIVED, EFFORTS, END, START

RESAMPLES = 2000
WIN = 1_000_000


class Pattern(Enum):
    SELF_ON_LIVE = "shot itself on a proven live"
    GAVE_UP_GUARANTEED_WIN = "shot the opponent, giving up a guaranteed win"
    GAVE_TURN_AWAY = "proven blank, gave the turn away"


class Search(Enum):
    """What the depth-limited search scored for the two shots at a proven blank."""

    OPPONENT_SHOT_HIGHER = "search scores the opponent shot higher"
    SETTLED_FOR_SELF_SHOT = "search settles the self shot as a win and the opponent shot as a loss"
    OTHER = "search scores the self shot higher or equal, not both settled"
    UNSEARCHED = "no search"


@dataclass(frozen=True)
class Decision:
    """An agent decision at which the player's own information proves the chambered shell. `chose` is the move its pattern counts."""

    model: str
    effort: str
    block: str
    pattern: Pattern
    chose: bool
    source: str  # public, glass, phone or combined
    last_shell: bool
    opponent_jammed: bool
    search: Search


def kill_damage(holds_saw: bool) -> int:
    """The most damage a player can do with its next shot: the saw is always free again after a shot."""
    return 2 if holds_saw else 1


def guaranteed_win(next_live: bool, own_health: int, opponent_health: int | None, own_saw: bool, opponent_saw: bool) -> bool:
    """A self shot on the proven blank keeps the move, then the proven live kills the opponent; an opponent shot hands it a move that can kill the player."""
    return next_live and opponent_health is not None and opponent_health <= kill_damage(own_saw) and own_health <= kill_damage(opponent_saw)


def search_of(values: str | None) -> Search:
    if values is None:
        return Search.UNSEARCHED
    scores = {v["label"]: v["score"] for v in json.loads(values)}
    own = scores["Shoot yourself"]
    [other] = [score for label, score in scores.items() if label.startswith("Shoot Player")]
    if other > own:
        return Search.OPPONENT_SHOT_HIGHER
    if (own, other) == (WIN, 0):
        return Search.SETTLED_FOR_SELF_SHOT
    return Search.OTHER


def decision(model, effort, block, chamber, source, shot, health, known, own_items, opponent_items, remaining, values) -> Decision:
    own, opponent = json.loads(health)
    opponent_health = opponent.get("health")
    if chamber == "Live":
        pattern, chose = Pattern.SELF_ON_LIVE, shot == "self"
    else:
        next_live = "2L" in (known or "").split()
        win = guaranteed_win(next_live, own["health"], opponent_health, "Saw" in json.loads(own_items), "Saw" in json.loads(opponent_items))
        pattern, chose = (Pattern.GAVE_UP_GUARANTEED_WIN if win else Pattern.GAVE_TURN_AWAY), shot == "opponent"
    return Decision(model, effort, block, pattern, chose, source, remaining == 1, opponent_health is None, search_of(values))


def load(knowledge_path: Path, regret_path: Path, depth: int = 6, budget: int = 20000) -> list[Decision]:
    db = connect(str(knowledge_path))
    db.execute("ATTACH DATABASE ? AS r", (f"file:{regret_path}?mode=ro",))
    rows = db.execute(
        """SELECT p.model, p.effort, m.seed_block_id, d.chamber, d.source, d.shot, d.health_json, d.private_known,
                  d.own_items_json, d.opponent_items_json, d.remaining, g.values_json
           FROM decisions d
           JOIN matches m ON m.match_id = d.match_id AND m.status = 'completed'
           JOIN players p ON p.match_id = d.match_id AND p.player = d.player
           LEFT JOIN r.regret g ON g.match_id = d.match_id AND g.ordinal = d.ordinal AND g.max_depth = ? AND g.budget = ?
                                   AND g.reload = 'static' AND g.status = 'searched'
           WHERE d.by_whom = 'agent' AND d.chamber IS NOT NULL
             AND d.match_id NOT IN (SELECT match_id FROM players WHERE model LIKE ?)
           ORDER BY d.match_id, d.ordinal""",
        (depth, budget, f"%{SKIPPED_MODEL}%"),
    ).fetchall()
    db.close()
    return [decision(*row) for row in rows]


@dataclass(frozen=True)
class Rate:
    decisions: int
    chose: int
    interval: tuple[float, float] | None

    def cell(self) -> str:
        if self.decisions == 0:
            return "–"
        bounds = "" if self.interval is None else f" [{pct(self.interval[0])}, {pct(self.interval[1])}]"
        return f"{pct(self.chose / self.decisions)} ({self.chose}/{self.decisions}){bounds}"


def rate(decisions: list[Decision], rng: random.Random) -> Rate:
    """The share that chose the pattern's move, with a 95% interval from resampling whole seed blocks."""
    per_block: dict[str, list[int]] = {}
    for d in decisions:
        tally = per_block.setdefault(d.block, [0, 0])
        tally[0] += 1
        tally[1] += d.chose
    blocks = sorted(per_block)
    replicates = []
    for _ in range(RESAMPLES if blocks else 0):
        drawn = weights(blocks, rng)
        replicates.append(sum(per_block[b][1] * n for b, n in drawn.items()) / sum(per_block[b][0] * n for b, n in drawn.items()))
    return Rate(len(decisions), sum(d.chose for d in decisions), interval(replicates))


def by_config(decisions: list[Decision]) -> str:
    rng = random.Random(0)
    configs = sorted({(d.model, d.effort) for d in decisions}, key=lambda c: (c[0], EFFORTS.index(c[1])))
    rows = []
    for config in configs:
        mine = [d for d in decisions if (d.model, d.effort) == config]
        rows.append(list(config) + [rate([d for d in mine if d.pattern is pattern], rng).cell() for pattern in Pattern])
    return table(["model", "effort"] + [pattern.value for pattern in Pattern], rows)


def rows_by(decisions: list[Decision], groups: list[tuple[str, Callable[[Decision], bool]]], patterns: list[Pattern]) -> list[list[str]]:
    rng = random.Random(0)
    return [[pattern.value] + [rate([d for d in decisions if d.pattern is pattern and keep(d)], rng).cell() for _, keep in groups] for pattern in patterns]


def by_source(decisions: list[Decision]) -> str:
    groups = [(source, lambda d, source=source: d.source == source) for source in ("public", "glass", "phone", "combined")]
    groups += [("last shell", lambda d: d.last_shell), ("earlier shells", lambda d: not d.last_shell)]
    return table(["pattern"] + [name for name, _ in groups], rows_by(decisions, groups, list(Pattern)))


def turn_given_away(decisions: list[Decision]) -> str:
    groups: list[tuple[str, Callable[[Decision], bool]]] = [("opponent jammed", lambda d: d.opponent_jammed)]
    groups += [(search.value, lambda d, search=search: not d.opponent_jammed and d.search is search) for search in Search]
    return table(["pattern"] + [name for name, _ in groups], rows_by(decisions, groups, [Pattern.GAVE_TURN_AWAY]))


def report(decisions: list[Decision]) -> str:
    return (
        f"### By config\n\n{by_config(decisions)}\n\n"
        f"### Proven blank, gave the turn away, by what the search scored, all configs\n\n{turn_given_away(decisions)}\n\n"
        f"### By source of the proof and shells left, all configs\n\n{by_source(decisions)}\n"
    )


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__.split("\n")[0])
    parser.add_argument("--knowledge", type=Path, default=DERIVED / "knowledge.sqlite")
    parser.add_argument("--regret", type=Path, default=DERIVED / "regret.sqlite")
    parser.add_argument("--doc", type=Path)
    args = parser.parse_args()
    text = report(load(args.knowledge, args.regret))
    if args.doc is None:
        print(text)
    else:
        head, rest = args.doc.read_text().split(START)
        tail = rest.split(END)[1]
        args.doc.write_text(f"{head}{START}\n{text}{END}{tail}")


if __name__ == "__main__":
    main()
