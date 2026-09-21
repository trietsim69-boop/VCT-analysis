"""Dump the raw DuckDB to CSV (+ schema.sql) and re-run the audit checks in sql/audit.sql.

Usage:
    python -m src.export [path/to/vct_YYYY-MM-DD.duckdb]   # defaults to the newest snapshot

Writes:
    data/raw/csv/    every table as CSV, plus schema.sql and load.sql (git-ignored, ~raw data)
    data/audit/      the audit results as small CSVs (committed)
"""

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

# The one check: unplayed fixtures are all-NULL rows, so a leak shows up as a NULL kill count
# (data_audit.md §0). Fails if the status filter in sql/audit.sql is dropped. Snapshot-independent.
rows, leaked = con.execute("SELECT count(*), count(*) FILTER (WHERE kills_all IS NULL) FROM pm26").fetchone()
assert leaked == 0, f"{leaked} placeholder rows leaked into pm26 — check the status filter"
print(f"ok: {rows:,} player-map rows; see data/audit/ and data/raw/csv/")
