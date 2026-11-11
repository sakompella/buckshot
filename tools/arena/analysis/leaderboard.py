#!/usr/bin/env python3
"""The arena leaderboard of docs/arena/results.md: one table per cohort.

The rating is the luck-adjusted Round Elo (docs/arena/analysis/matchups.md#luck-adjusted-round-elo), one pooled fit over every scored
match, so a config has the same rating in every table. Win share, pot share and matches count only the cohort's own matches. Intervals
are in matchups.md. Tournament 3 and tournament 4 have no table of their own: their matches are in the first one. With --doc FILE the
scope line and the tables replace the text between the leaderboard markers of that file.

    python3 tools/arena/analysis/leaderboard.py [--db PATH] [--luck PATH] [--doc docs/arena/results.md]
"""

from pathlib import Path
import argparse

import bt
from docs import splice_between_markers
from fmt import pct, signed, table
from load import DB, Game, cohorts, connect, round_winners, scored_games, require_current
from regret import DERIVED

# Cohorts are named by the importer (web/src/analysis/import.ts); a "tournament N" cohort is titled as is.
TITLES = {
    "tiers cross-model": "Cross-model games (tournament 1)",
    "opus-effort": "Opus efforts (tournament 2)",
}


def title_of(cohort: str) -> str:
    if cohort in TITLES:
        return TITLES[cohort]
    if cohort.startswith("tiers sweep "):
        return cohort.removeprefix("tiers sweep ") + " efforts (tournament 1)"
    return cohort[0].upper() + cohort[1:]


def luck_adjusted_elo(db, luck_path: Path) -> dict[str, float]:
    """The luck-adjusted Round Elo of every config: bt.round_elo over each match's rounds, the first config's round wins plus its luck correction."""
    luck = {(match, player): correction for match, player, correction in connect(str(luck_path)).execute("SELECT match_id, player, correction FROM luck")}
    winners = round_winners(db)
    seats: dict[str, list[tuple[str, str]]] = {}
    for match, player, label in db.execute(
        """SELECT s.match_id, s.player, s.label FROM match_seats s JOIN matches m ON m.id = s.match_id
           WHERE m.status = 'completed' AND m.disposition IS NULL ORDER BY s.match_id, s.position"""
    ):
        seats.setdefault(match, []).append((player, label))
    rows = [
        (first, second, len(winners[match]), sum(w == a for w in winners[match].values()) + luck[(match, a)])
        for match, ((a, first), (_, second)) in seats.items()
        if winners[match]
    ]
    return bt.round_elo(rows, {label for pair in seats.values() for _, label in pair})


def cohort_table(games: list[Game], elo: dict[str, float]) -> str:
    seats: dict[str, list[float]] = {}
    for g in games:
        for config, win, pot in ((g.first, g.share_first, g.pot_first), (g.second, 1 - g.share_first, 1 - g.pot_first)):
            row = seats.setdefault(config, [0.0, 0.0, 0.0])
            row[0] += 1
            row[1] += win
            row[2] += pot
    rows = [
        [config, f"{n:g}", pct(won / n), pct(pot / n), signed(elo[config])]
        for config, (n, won, pot) in sorted(seats.items(), key=lambda item: -elo[item[0]])
    ]
    return table(["config", "matches", "win share", "pot share", "Round Elo (luck-adjusted)"], rows)


def leaderboard(games: list[Game], elo: dict[str, float]) -> str:
    last = max(int(cohort.removeprefix("tournament ")) for cohort in cohorts(games) if cohort.startswith("tournament "))
    scope = f"Scope: {len(games):,} scored matches of tournaments 1 to {last}."
    parts = [f"{scope}\n\n### All configs\n\n{len(games)} scored matches.\n\n{cohort_table(games, elo)}"]
    for cohort, cohort_games in sorted(cohorts(games).items(), key=lambda item: -len(item[1])):
        if cohort in ("tournament 3", "tournament 4"):
            continue
        parts.append(f"### {title_of(cohort)}\n\n{len(cohort_games)} scored matches.\n\n{cohort_table(cohort_games, elo)}")
    return "\n\n".join(parts)


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--db")
    parser.add_argument("--luck", type=Path, default=DERIVED / "luck.sqlite")
    parser.add_argument("--doc")
    args = parser.parse_args()
    require_current(args.db or DB)
    db = connect(args.db) if args.db else connect()
    text = leaderboard(scored_games(db), luck_adjusted_elo(db, args.luck))
    if args.doc:
        splice_between_markers(Path(args.doc), "leaderboard", text)
    else:
        print(text)


if __name__ == "__main__":
    main()
