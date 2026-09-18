"""Dump the raw DuckDB to CSV (+ schema.sql) and re-run the audit checks in sql/audit.sql.

Usage:
    python -m src.export data/raw/vct-fe27a11e.duckdb

Writes:
    data/raw/csv/    every table as CSV, plus schema.sql and load.sql (git-ignored, ~raw data)
    data/audit/      the audit results as small CSVs (committed)
"""

import sys
from pathlib import Path

import duckdb

con = duckdb.connect(sys.argv[1], read_only=True)
con.execute("EXPORT DATABASE 'data/raw/csv' (FORMAT csv, HEADER)")
Path("data/audit").mkdir(parents=True, exist_ok=True)
con.execute(Path("sql/audit.sql").read_text(encoding="utf-8"))

# Snapshot check: must match data_audit.md §4. A different number means a new snapshot or a broken filter.
rows = con.execute("SELECT count(*) FROM pm26").fetchone()[0]
assert rows == 15_020, f"pm26 has {rows:,} rows, data_audit.md says 15,020"
print(f"ok: {rows:,} player-map rows; see data/audit/ and data/raw/csv/")
