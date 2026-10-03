from pathlib import Path

import duckdb

from src.budget import write_reference

Path("data/marts").mkdir(parents=True, exist_ok=True)
con = duckdb.connect()
for sql in ("sql/mart_scouting.sql", "sql/mart_fit.sql", "sql/mart_budget.sql"):
    con.execute(Path(sql).read_text(encoding="utf-8"))
write_reference()
con.execute(Path("sql/mart_tableau.sql").read_text(encoding="utf-8"))  # after the reference: it reads the Base break-even

for mart in ("mart_scouting", "mart_scouting_by_map", "mart_team_profile", "mart_fit",
             "mart_budget_inputs", "mart_budget_reference",
             "tableau_candidates", "tableau_maps", "tableau_percentiles"):
    rows = con.execute(f"SELECT count(*) FROM 'data/marts/{mart}.csv'").fetchone()[0]
    print(f"{mart}: {rows:,} rows")
