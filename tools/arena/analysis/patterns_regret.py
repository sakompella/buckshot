#!/usr/bin/env python3
"""Mean regret of the decisions each choice pattern matches, against the other decisions where the pattern could have applied.

Reads the regret table (tools/arena/score_regret.py writes it) and the knowledge database (web/scripts/arena-knowledge.ts) read-only,
joined on (match_id, ordinal), and prints one markdown table. With --doc FILE the table replaces the text between the
patterns markers of that file. Regret is in percentage points of the deciding player's chance to win the round. Matches
with a DeepSeek seat, unfinished matches and forced or fallback moves are left out.

    python3 tools/arena/analysis/patterns_regret.py [--regret PATH] [--knowledge PATH] [--doc docs/arena/analysis/patterns.md]
"""

import argparse
import json
import sqlite3
from collections import defaultdict
from collections.abc import Callable
from dataclasses import dataclass
from pathlib import Path

from docs import splice_between_markers
from fmt import table
from load import SKIPPED_MODEL, connect
from regret import DERIVED, POINT, PRODUCTION, run_of


@dataclass(frozen=True)
class Move:
    """One scored agent decision with what the deciding player knew. Shot and item are the moves it chose, if any."""

    config: str
    regret: int
    shells_left: int
    chamber: str | None  # "Live" or "Blank" when the player's own log proves the shell
    source: str | None  # where that certainty came from: public, glass, phone or combined
    live_count: int | None  # the live shells left, when the log fixes it
    sawed: bool
    shot: str | None  # "self" or "opponent"
    item: str | None
    stolen: bool  # the item was taken with adrenaline
    legal_items: frozenset[str]
    opponent_items: frozenset[str]
    full_health: bool
    shoots_self_next: bool  # the same player's next move is a shot at itself

    def can_use(self, item: str) -> bool:
        return item in self.legal_items or f"steal {item}" in self.legal_items

    @property
    def unknown_count_known(self) -> bool:
        return self.shot is not None and self.chamber is None and self.live_count is not None and not self.sawed


@dataclass(frozen=True)
class Pattern:
    name: str
    applies: Callable[[Move], bool]  # decisions where the pattern could have happened
    matches: Callable[[Move], bool]  # the ones where it did


def is_luna(move: Move) -> bool:
    return move.config.startswith("gpt-6-luna ")


PATTERNS = [
    Pattern("Invert the last shell and shoot yourself, known live", lambda m: m.chamber == "Live" and m.shells_left == 1 and "Inverter" in m.legal_items, lambda m: m.item == "Inverter" and m.shoots_self_next),
    Pattern("Smoke at full health, outside Luna", lambda m: m.full_health and "Cigarettes" in m.legal_items and not is_luna(m), lambda m: m.item == "Cigarettes" and not m.stolen),
    Pattern("Smoke at full health, outside Luna, opponent holds adrenaline", lambda m: m.full_health and "Cigarettes" in m.legal_items and not is_luna(m) and "Adrenaline" in m.opponent_items, lambda m: m.item == "Cigarettes" and not m.stolen),
    Pattern("Smoke at full health, Luna", lambda m: m.full_health and "Cigarettes" in m.legal_items and is_luna(m), lambda m: m.item == "Cigarettes" and not m.stolen),
    Pattern("Shoot yourself, unknown chamber, under half live", lambda m: m.unknown_count_known and 2 * (m.live_count or 0) < m.shells_left, lambda m: m.shot == "self"),
    Pattern("Shoot yourself on a certain live, from the count", lambda m: m.shot is not None and m.chamber == "Live" and m.source == "public", lambda m: m.shot == "self"),
    Pattern("Shoot yourself on a certain live, from the glass", lambda m: m.shot is not None and m.chamber == "Live" and m.source == "glass", lambda m: m.shot == "self"),
    Pattern("Shoot yourself on a certain live, from the phone", lambda m: m.shot is not None and m.chamber == "Live" and m.source == "phone", lambda m: m.shot == "self"),
    Pattern("Shoot the opponent on a certain blank, not the last shell", lambda m: m.shot is not None and m.chamber == "Blank" and m.shells_left > 1, lambda m: m.shot == "opponent"),
    Pattern("Shoot the opponent on a certain blank, last shell", lambda m: m.shot is not None and m.chamber == "Blank" and m.shells_left == 1, lambda m: m.shot == "opponent"),
    Pattern("Use the phone with two or fewer shells left", lambda m: m.shells_left <= 2 and m.can_use("Phone"), lambda m: m.item == "Phone"),
    Pattern("Shoot yourself at exactly half live, no saw", lambda m: m.unknown_count_known and 2 * (m.live_count or 0) == m.shells_left, lambda m: m.shot == "self"),
    Pattern("Shoot yourself with the gun sawed", lambda m: m.shot is not None and m.sawed, lambda m: m.shot == "self"),
    Pattern("Saw an unknown chamber (not a pattern)", lambda m: m.chamber is None and not m.sawed and m.can_use("Saw"), lambda m: m.item == "Saw"),
    Pattern("Saw a certain live (not a pattern)", lambda m: m.chamber == "Live" and not m.sawed and m.can_use("Saw"), lambda m: m.item == "Saw"),
    Pattern("Beer a certain live (not a pattern)", lambda m: m.chamber == "Live" and m.can_use("Beer"), lambda m: m.item == "Beer"),
]


@dataclass(frozen=True)
class Row:
    pattern: str
    matched: int
    matched_mean: float
    others: int
    others_mean: float
    others_mean_same_configs: float | None


def load(regret_path: Path, knowledge_path: Path) -> list[Move]:
    """The searched agent decisions of finished matches. Full health is the round's highest health seen in any decision of it, which equals the health every seat starts the round with. The health list starts with the deciding player."""
    run_of(regret_path)
    db = connect(str(regret_path))
    db.row_factory = sqlite3.Row
    db.execute("ATTACH DATABASE ? AS k", (f"file:{knowledge_path}?mode=ro",))
    rows = db.execute(
        """WITH seen AS (
             SELECT match_id, ordinal, player, by_whom, round, remaining, chamber, source, private_live_min, private_live_max, sawed, shot, item, item_stolen,
                    legal_items_json, opponent_items_json, json_extract(health_json, '$[0].health') AS own_health, json_extract(health_json, '$[1].health') AS other_health,
                    LEAD(player) OVER later AS next_player, LEAD(shot) OVER later AS next_shot
             FROM k.decisions WINDOW later AS (PARTITION BY match_id ORDER BY ordinal)
           ), healthy AS (
             SELECT *, MAX(MAX(COALESCE(own_health, 0), COALESCE(other_health, 0))) OVER (PARTITION BY match_id, round) AS round_best
             FROM seen
           )
           SELECT p.model || ' ' || p.effort AS config, r.regret, d.remaining, d.chamber, d.source, d.private_live_min, d.private_live_max, d.sawed, d.shot, d.item, d.item_stolen,
                  d.legal_items_json, d.opponent_items_json, d.next_player, d.next_shot, d.player,
                  d.own_health = d.round_best AS full_health
           FROM regret r
           JOIN k.matches m ON m.match_id = r.match_id AND m.status = 'completed'
           JOIN healthy d ON d.match_id = r.match_id AND d.ordinal = r.ordinal AND d.by_whom = 'agent'
           JOIN k.players p ON p.match_id = d.match_id AND p.player = d.player
           WHERE r.status = 'searched'
             AND r.match_id NOT IN (SELECT match_id FROM k.players WHERE model LIKE ?)""",
        (f"%{SKIPPED_MODEL}%",),
    ).fetchall()
    return [
        Move(
            r["config"], r["regret"], r["remaining"], r["chamber"], r["source"],
            r["private_live_min"] if r["private_live_min"] == r["private_live_max"] else None,
            bool(r["sawed"]), r["shot"], r["item"], bool(r["item_stolen"]),
            frozenset(json.loads(r["legal_items_json"])), frozenset(json.loads(r["opponent_items_json"])),
            bool(r["full_health"]), r["next_player"] == r["player"] and r["next_shot"] == "self",
        )
        for r in rows
    ]  # fmt: skip


def mean(moves: list[Move]) -> float:
    return sum(m.regret for m in moves) / len(moves)


def evaluate(pattern: Pattern, moves: list[Move]) -> Row | None:
    """The matches against the other applicable decisions, and against those same configs' other applicable decisions, so the model mix cannot explain the gap."""
    applicable = [m for m in moves if pattern.applies(m)]
    matched = [m for m in applicable if pattern.matches(m)]
    others = [m for m in applicable if not pattern.matches(m)]
    if not matched or not others:
        return None
    other_by_config: dict[str, list[Move]] = defaultdict(list)
    for m in others:
        other_by_config[m.config].append(m)
    comparable = [m for m in matched if m.config in other_by_config]
    same_configs = sum(mean(other_by_config[m.config]) for m in comparable) / len(comparable) if comparable else None
    return Row(pattern.name, len(matched), mean(matched), len(others), mean(others), same_configs)


def points(millionths: float | None) -> str:
    return "n/a" if millionths is None else f"{millionths / POINT:.1f}"


def report(moves: list[Move]) -> str:
    rows = [row for pattern in PATTERNS if (row := evaluate(pattern, moves))]
    return (
        f"{len(moves):,} searched decisions.\n\n"
        + table(
            ["pattern", "matched", "mean regret", "other applicable", "mean regret", "same configs"],
            [[r.pattern, f"{r.matched:,}", points(r.matched_mean), f"{r.others:,}", points(r.others_mean), points(r.others_mean_same_configs)] for r in rows],
        )
        + "\n"
    )


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__.split("\n")[0])
    parser.add_argument("--regret", type=Path, default=PRODUCTION)
    parser.add_argument("--knowledge", type=Path, default=DERIVED / "knowledge.sqlite")
    parser.add_argument("--doc", type=Path)
    args = parser.parse_args()
    text = report(load(args.regret, args.knowledge))
    if args.doc is None:
        print(text)
    else:
        splice_between_markers(args.doc, "regret", text)


if __name__ == "__main__":
    main()
