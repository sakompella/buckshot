"""Scored two-player matches from the analysis database, with the cohort each belongs to and who started round 1.

Only the columns the analysis needs are read: never match_seats.provenance_json, which holds account ids.
"""

import json
import re
import sqlite3
from dataclasses import dataclass
from hashlib import sha256
from pathlib import Path

REPO = Path(__file__).resolve().parents[3]
DB = str(REPO / "_work/arena/analysis/buckshot.sqlite")

# Its free tier refused requests, so its scored games are not a random sample of what was scheduled: every analysis skips them.
# An engine or bot entrant has no model.
SKIPPED_MODEL = "deepseek"

STARTS = re.compile(r"Round 1 begins\. Everyone has \d+ health; Player (\w) starts\.")


@dataclass(frozen=True)
class Game:
    """One scored match. `first` sat at position 1 and `second` at 2, each named by its seat label; `share_first` is position 1's win share (1, 0.5 or 0)."""

    block: str
    cohort: str
    tournament: str
    code: str
    seed: int
    first: str
    second: str
    share_first: float
    pot_first: float  # position 1's cash over the match's total cash
    starter: int  # the position, 1 or 2, whose player opens round 1
    first_shot: int  # the position of the first player to shoot in the match


def connect(path: str = DB) -> sqlite3.Connection:
    return sqlite3.connect(f"file:{path}?mode=ro", uri=True)


def require_current(path: str) -> None:
    """Stops unless every validated match in the analysis database was replayed by this checkout's importer, replay and rules code.

    The hash is web/src/analysis/importer-hash.ts's: the SHA-256 of the JSON object mapping each file the importer records to its SHA-256.
    """
    db = connect(path)
    row = db.execute("SELECT value FROM metadata WHERE key = 'importer_files'").fetchone()
    if row is None:
        raise SystemExit(f"{path} records no importer files; re-import it")
    files = {name: sha256((REPO / name).read_bytes()).hexdigest() for name in json.loads(row[0])}
    current = sha256(json.dumps(files, separators=(",", ":")).encode()).hexdigest()
    stale = db.execute("SELECT name, validated_with FROM matches WHERE replay_status = 'validated' AND validated_with IS NOT ? LIMIT 3", (current,)).fetchall()
    db.close()
    if stale:
        raise SystemExit(f"{path} was validated by other replay or rules code (now {current}); re-import it. Such as: {stale}")


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
        """SELECT s.match_id, s.position, s.player, s.win_share, s.cash, s.label, e.model, e.effort
           FROM match_seats s JOIN entrants e ON e.id = s.entrant_id JOIN matches m ON m.id = s.match_id
           WHERE m.status = 'completed' ORDER BY s.match_id, s.position"""
    ).fetchall()
    by_match: dict[str, list[tuple]] = {}
    for row in seats:
        by_match.setdefault(row[0], []).append(row)
    games = []
    for match, tournament, block, seed, code, cohort in db.execute(
        "SELECT m.id, t.name, m.seed_block_id, m.seed, m.code_hash, m.cohort FROM matches m JOIN tournaments t ON t.id = m.tournament_id WHERE m.status = 'completed' ORDER BY m.id"
    ):
        (_, _, letter_a, share_a, cash_a, a, model_a, effort_a), (_, _, letter_b, _, cash_b, b, model_b, effort_b) = by_match[match]
        if SKIPPED_MODEL in (model_a or "") or SKIPPED_MODEL in (model_b or ""):
            continue
        letter_of = {letter_a: 1, letter_b: 2}
        games.append(
            Game(block, cohort, tournament, code, seed, a, b, share_a, cash_a / (cash_a + cash_b), letter_of[starters[match]], shooters[match])
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
