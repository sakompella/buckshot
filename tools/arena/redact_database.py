"""Writes a shareable copy of the arena analysis database with every email and account id removed.

Usage: python3 tools/arena/redact_database.py <buckshot.sqlite> <out.sqlite>

match_seats.provenance_json is emptied, and every email address in the match manifests, tournament configs, raw
source records and call errors becomes "[redacted]". Account ids embed the email, so they go with it, also where
they sit inside escaped JSON, such as a raw record's quoted line or an error that quotes an auth file name. The copy
is vacuumed, so no deleted text survives in free pages. The source database is never written.
"""

import os
import re
import shutil
import sqlite3
import sys
import tempfile

EMAIL = re.compile(r"[A-Za-z0-9._%+-]+@[A-Za-z0-9-]+(?:\.[A-Za-z0-9-]+)+")
COLUMNS = [("matches", "id", "manifest_json"), ("tournaments", "id", "config_json"), ("source_records", "id", "raw"), ("calls", "id", "error")]


def redact(text: str) -> str:
    return EMAIL.sub("[redacted]", text)


def main(source: str, out: str) -> None:
    if os.path.exists(out):
        sys.exit(f"{out} exists; remove it first")
    work = tempfile.NamedTemporaryFile(dir=os.path.dirname(os.path.abspath(out)), suffix=".sqlite", delete=False).name
    shutil.copyfile(source, work)
    db = sqlite3.connect(work)
    db.execute("UPDATE match_seats SET provenance_json = NULL")
    for table, key, column in COLUMNS:
        rows = db.execute(f"SELECT {key}, {column} FROM {table} WHERE {column} LIKE '%@%'").fetchall()
        db.executemany(f"UPDATE {table} SET {column} = ? WHERE {key} = ?", [(redact(value), row) for row, value in rows])
    db.commit()
    db.execute("VACUUM INTO ?", (out,))
    db.close()
    os.remove(work)
    print(f"wrote {out}")


if __name__ == "__main__":
    if len(sys.argv) != 3:
        sys.exit(__doc__)
    main(sys.argv[1], sys.argv[2])
