#!/usr/bin/env python3
"""The arena leaderboard of docs/arena/results.md: one table per cohort, as the viewer shows them.

Ratings are the pooled Bradley-Terry fits over every scored match, on win shares and on pot shares, so a config has
one rating in every table. Win share, pot share and matches count only the cohort's own matches. Intervals are in
matchups.md. Tournament 3 and tournament 4 have no table of their own: their matches are in the first one. With --doc FILE the tables replace the text between the leaderboard markers of that file.

    python3 tools/arena/analysis/leaderboard.py [--db PATH] [--doc docs/arena/results.md]
"""

import argparse

import bt
from fmt import pct, signed, table
from load import CROSS_MODEL, CROSS_SAMPLES, TOURNAMENT_5_COHORT, Game, cohorts, connect, scored_games

START, END = "<!-- leaderboard:start -->", "<!-- leaderboard:end -->"

TITLES = {
    CROSS_MODEL: "Cross-model games (tournament 1)",
    "opus-effort": "Opus efforts (tournament 2)",
    TOURNAMENT_5_COHORT: "Tournament 5",
}


def title_of(cohort: str) -> str:
    return TITLES.get(cohort) or cohort.removeprefix("cpa-tiers sweep ") + " efforts (tournament 1)"


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
    return table(["config", "matches", "win share", "pot share", "rating (Elo)", "cash rating (Elo)"], rows)


def leaderboard(games: list[Game]) -> str:
    names = {n for g in games for n in (g.first, g.second)}
    wins = bt.fit(bt.cells_of(games), entrants=names).elo()
    cash = bt.fit(bt.cells_of(games, share=lambda g: g.pot_first), entrants=names).elo()
    parts = [f"### All configs\n\n{len(games)} scored matches.\n\n{cohort_table(games, wins, cash)}"]
    for cohort, cohort_games in sorted(cohorts(games).items(), key=lambda item: -len(item[1])):
        if cohort in (CROSS_SAMPLES, "tournament 3"):
            continue
        parts.append(f"### {title_of(cohort)}\n\n{len(cohort_games)} scored matches.\n\n{cohort_table(cohort_games, wins, cash)}")
    return "\n\n".join(parts)


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--db")
    parser.add_argument("--doc")
    args = parser.parse_args()
    text = leaderboard(scored_games(connect(args.db) if args.db else connect()))
    if args.doc:
        doc = open(args.doc).read()
        head, rest = doc.split(START)
        _, tail = rest.split(END)
        open(args.doc, "w").write(f"{head}{START}\n{text}\n{END}{tail}")
    else:
        print(text)


if __name__ == "__main__":
    main()
