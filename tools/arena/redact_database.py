"""Writes a shareable copy of the arena analysis database with every email and account id removed.

Usage: python3 tools/arena/redact_database.py <buckshot.sqlite> <out.sqlite>

match_seats.provenance_json is emptied, and every email address in any text column becomes "[redacted]". Account
ids embed the email, so they go with it, also where they sit inside escaped JSON, such as a raw record's quoted line
or an error that quotes an auth file name. The copy is a SQLite backup, so it holds what is committed in the
source's WAL, and it is vacuumed, so no deleted text survives in free pages. It then scans every column again and
stops, naming the cells, if an email is left. The source database is never written.
"""

import os
import re
import sqlite3
import sys
import tempfile

EMAIL = re.compile(r"[A-Za-z0-9._%+-]+@[A-Za-z0-9-]+(?:\.[A-Za-z0-9-]+)+")


def redact(text: str) -> str:
    return EMAIL.sub("[redacted]", text)


def columns(db: sqlite3.Connection) -> list[tuple[str, str]]:
    tables = [table for (table,) in db.execute("SELECT name FROM sqlite_master WHERE type = 'table'")]
    return [(table, row[1]) for table in tables for row in db.execute(f'PRAGMA table_info("{table}")')]


def email_cells(db: sqlite3.Connection) -> list[tuple[str, str, int, int]]:
    """(table, column, rowid, emails) for every cell holding an email. Values are read as text, not raw bytes: a record header byte can be an `@`."""
    cells = []
    for table, column in columns(db):
        query = f'SELECT rowid, CAST("{column}" AS TEXT) FROM "{table}" WHERE CAST("{column}" AS TEXT) LIKE \'%@%\''
        cells += [(table, column, rowid, len(EMAIL.findall(value))) for rowid, value in db.execute(query) if EMAIL.search(value)]
    return cells


def main(source: str, out: str) -> None:
    if os.path.exists(out):
        sys.exit(f"{out} exists; remove it first")
    work = tempfile.NamedTemporaryFile(dir=os.path.dirname(os.path.abspath(out)), suffix=".sqlite", delete=False).name
    db = sqlite3.connect(work)
    src = sqlite3.connect(f"file:{source}?mode=ro", uri=True)
    src.backup(db)
    src.close()
    db.create_function("redact", 1, redact, deterministic=True)
    db.execute("UPDATE match_seats SET provenance_json = NULL")
    for table, column in columns(db):
        db.execute(f'UPDATE "{table}" SET "{column}" = redact("{column}") WHERE typeof("{column}") = \'text\' AND "{column}" LIKE \'%@%\'')
    db.commit()
    left = email_cells(db)
    if left:
        db.close()
        os.remove(work)
        sys.exit(f"emails left after redacting (table, column, rowid, emails): {left[:20]}")
    db.execute("VACUUM INTO ?", (out,))
    db.close()
    os.remove(work)
    print(f"wrote {out}")


if __name__ == "__main__":
    if len(sys.argv) != 3:
        sys.exit(__doc__)
    main(sys.argv[1], sys.argv[2])
