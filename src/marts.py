"""Build the BI-ready marts in data/marts/ from data/processed/
(sql/mart_scouting.sql, then sql/mart_fit.sql, which reads the scouting mart).

Usage:
    python -m src.marts        # run python -m src.clean first

Safe to re-run: every COPY overwrites its CSV file.
"""

from pathlib import Path

import duckdb

Path("data/marts").mkdir(parents=True, exist_ok=True)
con = duckdb.connect()
for sql in ("sql/mart_scouting.sql", "sql/mart_fit.sql"):
    con.execute(Path(sql).read_text(encoding="utf-8"))

for mart in ("mart_scouting", "mart_scouting_by_map", "mart_team_profile", "mart_fit"):
    rows = con.execute(f"SELECT count(*) FROM 'data/marts/{mart}.csv'").fetchone()[0]
    print(f"{mart}: {rows:,} rows")
