"""Certain-mistake rates per config: shots that the deciding player's own information proves worse than the other shot.

Each certain mistake is counted over its own opportunities, the agent decisions where the player's own information proves it:

- Shot itself on a proven live. Shooting the opponent instead leaves every rule state the same except whose health falls.
- Shot the opponent, giving up a guaranteed win. The chamber is a proven blank and the next shell a proven live that kills the opponent,
  so shooting itself wins the round on every line, while after the opponent shot the opponent can kill the player with its next move.

A proven blank with a proven live next and a jammed opponent hides the opponent's health, so it is excluded and counted. Every other proven
blank is the fact pattern "proven blank, gave the turn away". Keeping the move is not proven better there, so it never enters a
certain-mistake rate. Its decisions are split by what the depth-limited search of the regret database scored.

"Proves" is the knowledge database (web/scripts/arena-knowledge.ts): the Bend belief over the player's own log. Matches with a DeepSeek
seat, unfinished matches and fallback moves are left out. With --doc FILE the tables replace the text between the tables markers of that file.

    python3 tools/arena/analysis/certain_mistakes.py [--knowledge PATH] [--regret PATH] [--doc docs/arena/analysis/certain-mistakes.md] [--opportunities PATH]
"""

import argparse
import json
import random
import sqlite3
from collections.abc import Callable
from dataclasses import dataclass
from enum import Enum
from pathlib import Path

from boot import interval, weights
from fmt import pct, table
from load import SKIPPED_MODEL, connect
from regret import DERIVED, EFFORTS, END, START

RESAMPLES = 2000
FEWEST_FOR_INTERVAL = 20
WIN = 1_000_000


class Pattern(Enum):
    SELF_ON_LIVE = "shot itself on a proven live"
    GAVE_UP_GUARANTEED_WIN = "shot the opponent, giving up a guaranteed win"
    HIDDEN_HEALTH = "proven blank, proven live next, opponent jammed"
    GAVE_TURN_AWAY = "proven blank, gave the turn away"


class Outcome(Enum):
    MISTAKE = "mistake"
    NOT_A_MISTAKE = "not a mistake"
    EXCLUDED = "excluded"
    FACT_PATTERN = "fact pattern"


class Search(Enum):
    """What the depth-limited search scored for the two shots at a proven blank."""

    OPPONENT_SHOT_HIGHER = "search scores the opponent shot higher"
    SETTLED_FOR_SELF_SHOT = "search settles the self shot as a win and the opponent shot as a loss"
    OTHER = "the rest"
    UNSEARCHED = "no search"


@dataclass(frozen=True)
class Decision:
    """An agent decision at which the player's own information proves the chambered shell. `chose` is the move its pattern counts."""

    match: str
    ordinal: int
    player: str
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


def guaranteed_win(own_health: int, opponent_health: int, own_saw: bool, opponent_saw: bool) -> bool:
    """With the next shell a proven live, a self shot on the proven blank keeps the move and the live kills the opponent; an opponent shot hands it a move that can kill the player."""
    return opponent_health <= kill_damage(own_saw) and own_health <= kill_damage(opponent_saw)


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


def decision(match, ordinal, player, model, effort, block, chamber, source, shot, health, known, own_items, opponent_items, remaining, values) -> Decision:
    own, opponent = json.loads(health)
    opponent_health = opponent.get("health")
    if chamber == "Live":
        pattern, chose = Pattern.SELF_ON_LIVE, shot == "self"
    else:
        next_live = "2L" in (known or "").split()
        if next_live and opponent_health is None:
            pattern = Pattern.HIDDEN_HEALTH
        elif next_live and guaranteed_win(own["health"], opponent_health, "Saw" in json.loads(own_items), "Saw" in json.loads(opponent_items)):
            pattern = Pattern.GAVE_UP_GUARANTEED_WIN
        else:
            pattern = Pattern.GAVE_TURN_AWAY
        chose = shot == "opponent"
    return Decision(match, ordinal, player, model, effort, block, pattern, chose, source, remaining == 1, opponent_health is None, search_of(values))


def load(knowledge_path: Path, regret_path: Path, depth: int = 6, budget: int = 20000) -> list[Decision]:
    db = connect(str(knowledge_path))
    db.execute("ATTACH DATABASE ? AS r", (f"file:{regret_path}?mode=ro",))
    rows = db.execute(
        """SELECT d.match_id, d.ordinal, d.player, p.model, p.effort, m.seed_block_id, d.chamber, d.source, d.shot, d.health_json, d.private_known,
                  d.own_items_json, d.opponent_items_json, d.remaining, g.values_json, g.evaluator
           FROM decisions d
           JOIN matches m ON m.match_id = d.match_id AND m.status = 'completed'
           JOIN players p ON p.match_id = d.match_id AND p.player = d.player
           LEFT JOIN r.regret g ON g.match_id = d.match_id AND g.ordinal = d.ordinal AND g.max_depth = ? AND g.budget = ?
                                   AND g.reload = 'static' AND g.samples = 0 AND g.status = 'searched'
           WHERE d.by_whom = 'agent' AND d.chamber IS NOT NULL
             AND d.match_id NOT IN (SELECT match_id FROM players WHERE model LIKE ?)
           ORDER BY d.match_id, d.ordinal""",
        (depth, budget, f"%{SKIPPED_MODEL}%"),
    ).fetchall()
    db.close()
    if len({row[-1] for row in rows if row[-1] is not None}) > 1:
        raise SystemExit(f"{regret_path} holds rows of several evaluators at depth {depth} and budget {budget}; they must not be mixed.")
    return [decision(*row[:-1]) for row in rows]


@dataclass(frozen=True)
class Rate:
    decisions: int
    chose: int
    interval: tuple[float, float] | None

    def bounds(self) -> tuple[float, float] | None:
        return self.interval if self.decisions >= FEWEST_FOR_INTERVAL else None

    def cell(self) -> str:
        if self.decisions == 0:
            return "–"
        if self.decisions < FEWEST_FOR_INTERVAL:
            return f"{self.chose}/{self.decisions}"
        bounds = "" if self.interval is None else f" [{pct(self.interval[0])}, {pct(self.interval[1])}]"
        return f"{pct(self.chose / self.decisions)} ({self.chose}/{self.decisions}){bounds}"


def rate(decisions: list[Decision]) -> Rate:
    """The share that chose the pattern's move, with a 95% interval from resampling whole seed blocks."""
    rng = random.Random(0)
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


def configs(decisions: list[Decision]) -> list[tuple[list[str], list[Decision]]]:
    """Each config's decisions, then every decision pooled."""
    keys = sorted({(d.model, d.effort) for d in decisions}, key=lambda c: (c[0], EFFORTS.index(c[1])))
    return [([model, effort], [d for d in decisions if (d.model, d.effort) == (model, effort)]) for model, effort in keys] + [(["all", ""], decisions)]


def of(decisions: list[Decision], pattern: Pattern) -> list[Decision]:
    return [d for d in decisions if d.pattern is pattern]


def outcome_of(d: Decision) -> Outcome:
    if d.pattern is Pattern.HIDDEN_HEALTH:
        return Outcome.EXCLUDED
    if d.pattern is Pattern.GAVE_TURN_AWAY:
        return Outcome.FACT_PATTERN if d.chose else Outcome.NOT_A_MISTAKE
    return Outcome.MISTAKE if d.chose else Outcome.NOT_A_MISTAKE


def rate_rows(decisions: list[Decision]) -> list[tuple]:
    *per_config, (_, pooled) = configs(decisions)
    groups = [("config", model, effort, mine) for [model, effort], mine in per_config]
    groups += [("model", model, "", [d for d in decisions if d.model == model]) for model in sorted({d.model for d in decisions})]
    groups.append(("all", "", "", pooled))
    rows = []
    for scope, model, effort, mine in groups:
        for pattern in Pattern:
            found = rate(of(mine, pattern))
            lo, hi = found.bounds() or (None, None)
            rows.append((scope, model, effort, pattern.name.lower(), found.chose, found.decisions, lo, hi))
    return rows


def write_opportunities(decisions: list[Decision], path: Path) -> None:
    path.unlink(missing_ok=True)
    db = sqlite3.connect(path)
    with db:
        db.execute(
            """CREATE TABLE opportunities (match_id TEXT NOT NULL, ordinal INTEGER NOT NULL, player TEXT NOT NULL, type TEXT NOT NULL,
                                           outcome TEXT NOT NULL, source TEXT NOT NULL, PRIMARY KEY (match_id, ordinal)) WITHOUT ROWID"""
        )
        db.executemany(
            "INSERT INTO opportunities VALUES (?, ?, ?, ?, ?, ?)",
            [(d.match, d.ordinal, d.player, d.pattern.name.lower(), outcome_of(d).value, d.source) for d in decisions],
        )
        db.execute(
            """CREATE TABLE rates (scope TEXT NOT NULL, model TEXT NOT NULL, effort TEXT NOT NULL, type TEXT NOT NULL,
                                   chose INTEGER NOT NULL, opportunities INTEGER NOT NULL, lo REAL, hi REAL, PRIMARY KEY (scope, model, effort, type)) WITHOUT ROWID"""
        )
        db.executemany("INSERT INTO rates VALUES (?, ?, ?, ?, ?, ?, ?, ?)", rate_rows(decisions))
    db.close()


def certain(decisions: list[Decision]) -> str:
    rows = [
        names
        + [rate(of(mine, Pattern.SELF_ON_LIVE)).cell(), rate(of(mine, Pattern.GAVE_UP_GUARANTEED_WIN)).cell(), f"{len(of(mine, Pattern.HIDDEN_HEALTH)):,}"]
        for names, mine in configs(decisions)
    ]
    return table(["model", "effort", Pattern.SELF_ON_LIVE.value, Pattern.GAVE_UP_GUARANTEED_WIN.value, f"excluded: {Pattern.HIDDEN_HEALTH.value}"], rows)


def turn_away_by_config(decisions: list[Decision]) -> str:
    rows = [names + [rate(of(mine, Pattern.GAVE_TURN_AWAY)).cell()] for names, mine in configs(decisions)]
    return table(["model", "effort", "shot the opponent on a proven blank"], rows)


def turn_away_by_search(decisions: list[Decision]) -> str:
    groups: list[tuple[str, Callable[[Decision], bool]]] = [("opponent jammed", lambda d: d.opponent_jammed)]
    groups += [(search.value, lambda d, search=search: not d.opponent_jammed and d.search is search) for search in Search]
    away = of(decisions, Pattern.GAVE_TURN_AWAY)
    return table([name for name, _ in groups], [[rate([d for d in away if keep(d)]).cell() for _, keep in groups]])


def by_source(decisions: list[Decision]) -> str:
    groups = [(source, lambda d, source=source: d.source == source) for source in ("public", "glass", "phone", "combined")]
    groups += [("last shell", lambda d: d.last_shell), ("earlier shells", lambda d: not d.last_shell)]
    patterns = [Pattern.SELF_ON_LIVE, Pattern.GAVE_UP_GUARANTEED_WIN, Pattern.GAVE_TURN_AWAY]
    rows = [[pattern.value] + [rate([d for d in of(decisions, pattern) if keep(d)]).cell() for _, keep in groups] for pattern in patterns]
    return table(["pattern"] + [name for name, _ in groups], rows)


def report(decisions: list[Decision]) -> str:
    return (
        f"### Certain mistakes by config\n\n{certain(decisions)}\n\n"
        f"### Not a certain mistake: proven blank, gave the turn away, by config\n\n{turn_away_by_config(decisions)}\n\n"
        f"### Not a certain mistake: proven blank, gave the turn away, by what the search scored, all configs\n\n{turn_away_by_search(decisions)}\n\n"
        f"### By source of the proof and shells left, all configs\n\n{by_source(decisions)}\n"
    )


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__.split("\n")[0])
    parser.add_argument("--knowledge", type=Path, default=DERIVED / "knowledge.sqlite")
    parser.add_argument("--regret", type=Path, default=DERIVED / "regret.sqlite")
    parser.add_argument("--doc", type=Path)
    parser.add_argument("--opportunities", type=Path)
    args = parser.parse_args()
    decisions = load(args.knowledge, args.regret)
    if args.opportunities is not None:
        write_opportunities(decisions, args.opportunities)
    text = report(decisions)
    if args.doc is None:
        print(text)
    else:
        head, rest = args.doc.read_text().split(START)
        tail = rest.split(END)[1]
        args.doc.write_text(f"{head}{START}\n{text}{END}{tail}")


if __name__ == "__main__":
    main()
