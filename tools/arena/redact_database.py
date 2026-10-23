"""Writes a shareable copy of the arena analysis database with every email and account id removed.

Usage: python3 tools/arena/redact_database.py <buckshot.sqlite> <out.sqlite>

match_seats.provenance_json is emptied, and every JSON string containing "@" in the match manifests, tournament
configs and raw source records becomes "[redacted]" (account ids embed the email). The copy is vacuumed, so no
deleted text survives in free pages. The source database is never written.
"""

import os
import re
import shutil
import sqlite3
import sys
import tempfile

EMAIL_STRING = re.compile(r'"[^"\\]*@[^"\\]*"')
COLUMNS = [("matches", "id", "manifest_json"), ("tournaments", "id", "config_json"), ("source_records", "id", "raw")]


def main(source: str, out: str) -> None:
    if os.path.exists(out):
        sys.exit(f"{out} exists; remove it first")
    work = tempfile.NamedTemporaryFile(dir=os.path.dirname(os.path.abspath(out)), suffix=".sqlite", delete=False).name
    shutil.copyfile(source, work)
    db = sqlite3.connect(work)
    db.execute("UPDATE match_seats SET provenance_json = NULL")
    for table, key, column in COLUMNS:
        rows = db.execute(f"SELECT {key}, {column} FROM {table} WHERE {column} LIKE '%@%'").fetchall()
        db.executemany(f"UPDATE {table} SET {column} = ? WHERE {key} = ?", [(EMAIL_STRING.sub('"[redacted]"', value), row) for row, value in rows])
    db.commit()
    db.execute("VACUUM INTO ?", (out,))
    db.close()
    os.remove(work)
    print(f"wrote {out}")


if __name__ == "__main__":
    if len(sys.argv) != 3:
        sys.exit(__doc__)
    main(sys.argv[1], sys.argv[2])
