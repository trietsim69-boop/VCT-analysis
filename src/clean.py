import sys
from pathlib import Path

import duckdb

from src import newest_snapshot

db = sys.argv[1] if len(sys.argv) > 1 else newest_snapshot()
Path("data/processed").mkdir(parents=True, exist_ok=True)
con = duckdb.connect(db, read_only=True)
con.execute("SET VARIABLE gcd = ?", [newest_snapshot("gcd_*.xlsx")])
con.execute(Path("sql/model.sql").read_text(encoding="utf-8"))

rows = con.execute("SELECT count(*) FROM 'data/processed/fact_player_map.csv'").fetchone()[0]
print(f"snapshot: {db}\nfact_player_map: {rows:,} rows -> data/processed/")
