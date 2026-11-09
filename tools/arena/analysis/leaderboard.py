#!/usr/bin/env python3
"""The arena leaderboard of docs/arena/results.md: one table per cohort.

Ratings are the pooled Bradley-Terry fits over every scored match, one per match on its win share and one on its pot share, so a config has
one rating in every table. They are not the viewer's Round Elo, which fits round shares (bt.round_elo). Win share, pot share and matches count only the cohort's own matches. Intervals are in
matchups.md. Tournament 3 and tournament 4 have no table of their own: their matches are in the first one. With --doc FILE the tables replace the text between the leaderboard markers of that file.

    python3 tools/arena/analysis/leaderboard.py [--db PATH] [--doc docs/arena/results.md]
"""

from pathlib import Path
import argparse

import bt
from docs import splice_between_markers
from fmt import pct, signed, table
from load import DB, Game, cohorts, connect, scored_games, require_current

# Cohorts are named by the importer (web/src/analysis/import.ts); a "tournament N" cohort is titled as is.
TITLES = {
    "cpa-tiers cross-model": "Cross-model games (tournament 1)",
    "opus-effort": "Opus efforts (tournament 2)",
}


def title_of(cohort: str) -> str:
    if cohort in TITLES:
        return TITLES[cohort]
    if cohort.startswith("cpa-tiers sweep "):
        return cohort.removeprefix("cpa-tiers sweep ") + " efforts (tournament 1)"
    return cohort[0].upper() + cohort[1:]


def cohort_table(games: list[Game], wins: dict[str, float], cash: dict[str, float]) -> str:
    seats: dict[str, list[float]] = {}
    for g in games:
        for config, win, pot in ((g.first, g.share_first, g.pot_first), (g.second, 1 - g.share_first, 1 - g.pot_first)):
            row = seats.setdefault(config, [0.0, 0.0, 0.0])
            row[0] += 1
            row[1] += win
            row[2] += pot
    rows = [
        [config, f"{n:g}", pct(won / n), pct(pot / n), signed(wins[config]), signed(cash[config])]
        for config, (n, won, pot) in sorted(seats.items(), key=lambda item: -wins[item[0]])
    ]
    return table(["config", "matches", "win share", "pot share", "match rating (Elo)", "cash rating (Elo)"], rows)


def leaderboard(games: list[Game]) -> str:
    names = {n for g in games for n in (g.first, g.second)}
    wins = bt.fit(bt.cells_of(games), entrants=names).elo()
    cash = bt.fit(bt.cells_of(games, share=lambda g: g.pot_first), entrants=names).elo()
    parts = [f"### All configs\n\n{len(games)} scored matches.\n\n{cohort_table(games, wins, cash)}"]
    for cohort, cohort_games in sorted(cohorts(games).items(), key=lambda item: -len(item[1])):
        if cohort in ("tournament 3", "tournament 4"):
            continue
        parts.append(f"### {title_of(cohort)}\n\n{len(cohort_games)} scored matches.\n\n{cohort_table(cohort_games, wins, cash)}")
    return "\n\n".join(parts)


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--db")
    parser.add_argument("--doc")
    args = parser.parse_args()
    require_current(args.db or DB)
    text = leaderboard(scored_games(connect(args.db) if args.db else connect()))
    if args.doc:
        splice_between_markers(Path(args.doc), "leaderboard", text)
    else:
        print(text)


if __name__ == "__main__":
    main()
