#duckdb to csv
import sys
from pathlib import Path

import duckdb

from src import newest_snapshot


db = sys.argv[1] if len(sys.argv) > 1 else newest_snapshot()
print(f"snapshot: {db}")
con = duckdb.connect(db, read_only=True)
con.execute("EXPORT DATABASE 'data/raw/csv' (FORMAT csv, HEADER)")
Path("data/audit").mkdir(parents=True, exist_ok=True)
con.execute(Path("sql/audit.sql").read_text(encoding="utf-8"))

rows, leaked = con.execute("SELECT count(*), count(*) FILTER (WHERE kills_all IS NULL) FROM pm26").fetchone()
assert leaked == 0, f"{leaked} placeholder rows leaked into pm26 — check the status filter"
print(f"ok: {rows:,} player-map rows; see data/audit/ and data/raw/csv/")
