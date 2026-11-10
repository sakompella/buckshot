"""Scored two-player matches from the analysis database, with the cohort each belongs to and who started round 1.

Only the columns the analysis needs are read: never match_seats.provenance_json, which holds account ids.
"""

import json
import sqlite3
from collections import defaultdict
from dataclasses import dataclass
from hashlib import sha256
from pathlib import Path

REPO = Path(__file__).resolve().parents[3]
DB = str(REPO / "_work/arena/analysis/buckshot.sqlite")

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


def connect(path: str = DB, **attached: str | Path) -> sqlite3.Connection:
    """Opens `path` read-only, with each keyword's database attached read-only under that schema name."""
    db = sqlite3.connect(f"file:{path}?mode=ro", uri=True)
    for schema, other in attached.items():
        db.execute(f"ATTACH DATABASE ? AS {schema}", (f"file:{other}?mode=ro",))
    return db


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
    """Match id to the letter of the player who opens round 1."""
    rows = db.execute(
        """SELECT e.match_id, s.player FROM events e JOIN match_seats s ON s.match_id = e.match_id AND s.socket = json_extract(e.json, '$.first')
           WHERE e.kind = 'RoundBegan' AND json_extract(e.json, '$.round') = 0"""
    )
    return dict(rows.fetchall())


def first_shooters(db: sqlite3.Connection) -> dict[str, int]:
    """Match id to the position of the first player to shoot in the match."""
    rows = db.execute(
        """SELECT e.match_id, s.position FROM (SELECT match_id, MIN(idx) AS idx FROM events WHERE kind = 'Fired' GROUP BY match_id) f
           JOIN events e ON e.match_id = f.match_id AND e.idx = f.idx JOIN match_seats s ON s.match_id = e.match_id AND s.socket = json_extract(e.json, '$.shooter')"""
    )
    return dict(rows.fetchall())


def round_winners(db: sqlite3.Connection) -> dict[str, dict[int, str]]:
    """Match id to each round's number, from 1, and the letter of its winner."""
    winners: dict[str, dict[int, str]] = defaultdict(dict)
    current = 0
    for match, kind, round, player in db.execute(
        """SELECT e.match_id, e.kind, json_extract(e.json, '$.round'), s.player FROM events e
           LEFT JOIN match_seats s ON s.match_id = e.match_id AND s.socket = json_extract(e.json, '$.seat')
           WHERE e.kind IN ('RoundBegan', 'RoundWon') ORDER BY e.match_id, e.idx"""
    ):
        if kind == "RoundBegan":
            current = round + 1
        else:
            winners[match][current] = player
    return dict(winners)


def scored_games(db: sqlite3.Connection) -> list[Game]:
    starters, shooters = round_one_starters(db), first_shooters(db)
    seats = db.execute(
        """SELECT s.match_id, s.position, s.player, s.win_share, s.cash, s.label
           FROM match_seats s JOIN matches m ON m.id = s.match_id
           WHERE m.status = 'completed' AND m.disposition IS NULL ORDER BY s.match_id, s.position"""
    ).fetchall()
    by_match: dict[str, list[tuple]] = {}
    for row in seats:
        by_match.setdefault(row[0], []).append(row)
    games = []
    for match, tournament, block, seed, code, cohort in db.execute(
        "SELECT m.id, t.name, m.seed_block_id, m.seed, m.code_hash, m.cohort FROM matches m JOIN tournaments t ON t.id = m.tournament_id"
        " WHERE m.status = 'completed' AND m.disposition IS NULL ORDER BY m.id"
    ):
        (_, _, letter_a, share_a, cash_a, a), (_, _, letter_b, _, cash_b, b) = by_match[match]
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
