"""Dump the raw DuckDB to CSV (+ schema.sql) and re-run the audit checks in sql/audit.sql.

Usage:
    python -m src.export [path/to/vct_YYYY-MM-DD.duckdb]   # defaults to the newest snapshot

Writes:
    data/raw/csv/    every table as CSV, plus schema.sql and load.sql (git-ignored, ~raw data)
    data/audit/      the audit results as small CSVs (committed)
"""

import pathlib
import sys
from pathlib import Path

import duckdb


def newest_snapshot() -> str:
    """The most recent data/raw/vct_YYYY-MM-DD.duckdb, so a new snapshot needs no code change."""
    snaps = sorted(pathlib.Path("data/raw").glob("vct_*.duckdb"))
    assert snaps, "no data/raw/vct_*.duckdb — see data/raw/README.md"
    return str(snaps[-1])


db = sys.argv[1] if len(sys.argv) > 1 else newest_snapshot()
print(f"snapshot: {db}")
con = duckdb.connect(db, read_only=True)
con.execute("EXPORT DATABASE 'data/raw/csv' (FORMAT csv, HEADER)")
Path("data/audit").mkdir(parents=True, exist_ok=True)
con.execute(Path("sql/audit.sql").read_text(encoding="utf-8"))

# Snapshot check: 15,020 is the 2026-09-18 pre-Champions figure (data_audit.md §4).
# The planned post-Champions snapshot (S-14) will exceed it; a DROP means a broken filter.
rows = con.execute("SELECT count(*) FROM pm26").fetchone()[0]
assert rows >= 15_020, f"pm26 has {rows:,} rows, fewer than the 15,020 in data_audit.md §4"
print(f"ok: {rows:,} player-map rows; see data/audit/ and data/raw/csv/")
