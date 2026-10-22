"""Scored two-player matches from the analysis database, with the cohort each belongs to and who started round 1.

Only the columns the analysis needs are read: never match_seats.provenance_json, which holds account ids.
"""

import re
import sqlite3
from dataclasses import dataclass

DB = "/home/aditya/repos/projects/buckshot/_work/arena/analysis/buckshot.sqlite"

# Its free tier refused requests, so its scored games are not a random sample of what was scheduled: every analysis skips them.
SKIPPED_MODEL = "deepseek"

STARTS = re.compile(r"Round 1 begins\. Everyone has \d+ health; Player (\w) starts\.")


@dataclass(frozen=True)
class Game:
    """One scored match. `first` sat at position 1; `share_first` is its win share (1, 0.5 or 0)."""

    block: str
    cohort: str
    tournament: str
    code: str
    seed: int
    first: str
    second: str
    share_first: float
    starter: int  # the position, 1 or 2, whose player opens round 1
    first_shot: int  # the position of the first player to shoot in the match


def connect(path: str = DB) -> sqlite3.Connection:
    return sqlite3.connect(f"file:{path}?mode=ro", uri=True)


def cohort_of(tournament: str, model_a: str, model_b: str, effort_a: str, effort_b: str) -> str:
    """Matches are compared only inside a cohort: a model's own effort levels, medium across models, or one tournament."""
    if tournament == "cpa-tiers":
        if model_a == model_b:
            return f"cpa-tiers sweep {model_a}"
        if effort_a == effort_b == "medium":
            return "cpa-tiers medium cross-model"
    elif tournament == "opus-effort":
        return "opus-effort"
    elif tournament == "astra-vs-opus-xhigh":
        return "tournament 3"
    raise ValueError(f"no cohort for {tournament}: {model_a} {effort_a} vs {model_b} {effort_b}")


def round_one_starters(db: sqlite3.Connection) -> dict[str, str]:
    """Match id to the letter of the player who opens round 1, read from the public lines of events.jsonl."""
    rows = db.execute(
        """SELECT f.match_id, r.raw FROM source_files f JOIN source_records r ON r.path = f.path AND r.current = 1
           WHERE f.path LIKE '%/events.jsonl' AND r.raw LIKE '%Round 1 begins%'"""
    )
    letters: dict[str, set[str]] = {}
    for match, raw in rows:
        for found in STARTS.findall(raw):
            letters.setdefault(match, set()).add(found)
    for match, found in letters.items():
        if len(found) != 1:
            raise ValueError(f"match {match} names {len(found)} round 1 starters")
    return {match: next(iter(found)) for match, found in letters.items()}


def first_shooters(db: sqlite3.Connection) -> dict[str, int]:
    """Match id to the position of the first accepted shot, from the decisions."""
    rows = db.execute("SELECT match_id, position, MIN(ordinal) FROM decisions WHERE label LIKE 'Shoot%' GROUP BY match_id")
    return {match: position for match, position, _ in rows}


def scored_games(db: sqlite3.Connection) -> list[Game]:
    starters, shooters = round_one_starters(db), first_shooters(db)
    seats = db.execute(
        """SELECT s.match_id, s.position, s.player, s.win_share, e.name, e.model, e.effort
           FROM match_seats s JOIN entrants e ON e.id = s.entrant_id JOIN matches m ON m.id = s.match_id
           WHERE m.status = 'completed' ORDER BY s.match_id, s.position"""
    ).fetchall()
    by_match: dict[str, list[tuple]] = {}
    for row in seats:
        by_match.setdefault(row[0], []).append(row)
    games = []
    for match, tournament, block, seed, code in db.execute(
        "SELECT m.id, t.name, m.seed_block_id, m.seed, m.code_hash FROM matches m JOIN tournaments t ON t.id = m.tournament_id WHERE m.status = 'completed' ORDER BY m.id"
    ):
        (_, _, letter_a, share_a, a, model_a, effort_a), (_, _, letter_b, _, b, model_b, effort_b) = by_match[match]
        if SKIPPED_MODEL in model_a or SKIPPED_MODEL in model_b:
            continue
        letter_of = {letter_a: 1, letter_b: 2}
        games.append(
            Game(block, cohort_of(tournament, model_a, model_b, effort_a, effort_b), tournament, code, seed, a, b, share_a, letter_of[starters[match]], shooters[match])
        )
    return games


def cohorts(games: list[Game]) -> dict[str, list[Game]]:
    out: dict[str, list[Game]] = {}
    for game in games:
        out.setdefault(game.cohort, []).append(game)
    return dict(sorted(out.items()))


def blocks_of(games: list[Game]) -> dict[str, list[Game]]:
    out: dict[str, list[Game]] = {}
    for game in games:
        out.setdefault(game.block, []).append(game)
    return out
