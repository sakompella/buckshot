"""Test databases built from the production DDL, so a test fails when the schema drops or renames a column an analysis reads."""

import json
import sqlite3
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[3]
sys.path.insert(0, str(ROOT / "tools" / "arena"))
from score_regret import CREATE_REGRET

ANALYSIS = (ROOT / "web" / "src" / "analysis" / "schema.sql").read_text()
KNOWLEDGE = (ROOT / "web" / "src" / "analysis" / "knowledge.sql").read_text()
REGRET = CREATE_REGRET + ";"
PLACEHOLDER = {"INTEGER": 0, "REAL": 0.0}


def database(path: Path, *ddl: str) -> sqlite3.Connection:
    db = sqlite3.connect(path)
    for script in ddl:
        db.executescript(script)
    db.execute("PRAGMA foreign_keys = OFF")  # schema.sql turns them on; a test fills only the tables it reads
    return db


def insert(db: sqlite3.Connection, table: str, **cols) -> None:
    """One row; NOT NULL columns the test leaves out get a placeholder of their type."""
    for _, name, kind, notnull, default, _ in db.execute(f"PRAGMA table_info({table})"):
        if notnull and default is None and name not in cols:
            cols[name] = PLACEHOLDER.get(kind.upper(), "")
    db.execute(f"INSERT INTO {table} ({', '.join(cols)}) VALUES ({', '.join('?' * len(cols))})", tuple(cols.values()))


def events(db: sqlite3.Connection, match_id: str, *played: tuple[str, dict]) -> None:
    """A match's replayed events in order, each its kind and fields; seats are sockets."""
    for idx, (kind, fields) in enumerate(played):
        insert(db, "events", match_id=match_id, idx=idx, kind=kind, json=json.dumps({"_tag": kind, **fields}))


def rounds(*winners: int, first: int = 0) -> list[tuple[str, dict]]:
    """Events of a match whose rounds the sockets `winners` win in turn, each round opened by `first` shooting socket 1."""
    played = []
    for round, winner in enumerate(winners):
        played += [("RoundBegan", {"round": round, "health": 3, "first": first}), ("Fired", {"shooter": first, "target": 1, "shell": "Live"}), ("RoundWon", {"seat": winner})]
    return played
