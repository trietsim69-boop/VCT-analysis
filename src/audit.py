"""Profile a DuckDB file: tables, row counts, column types, null rates, distinct counts.

Usage:
    python src/audit.py data/raw/vct_2026-09-18.duckdb [out.md]   # default: data/audit/data_profile.md
    python src/audit.py --selftest
"""

import sys
from datetime import date
from pathlib import Path

import duckdb


def profile(db_path: str) -> str:
    con = duckdb.connect(db_path, read_only=True)
    out = [
        "# Data Audit (auto-generated)",
        "",
        f"Source: `{db_path}`",
        f"Generated: {date.today()}",
        "",
        "Machine-generated schema profile. The interpretation lives in `docs/data_audit.md`.",
    ]
    for (table,) in con.execute("SHOW TABLES").fetchall():
        rows = con.execute(f'SELECT count(*) FROM "{table}"').fetchone()[0]
        out += [
            "",
            f"## {table} — {rows:,} rows",
            "",
            "| column | type | null % | distinct |",
            "|---|---|---|---|",
        ]
        for _, name, typ, *_ in con.execute(f'PRAGMA table_info("{table}")').fetchall():
            nulls, distinct = con.execute(
                f'SELECT count(*) FILTER (WHERE "{name}" IS NULL), count(DISTINCT "{name}") FROM "{table}"'
            ).fetchone()
            pct = 100 * nulls / rows if rows else 0.0
            out.append(f"| `{name}` | {typ} | {pct:.1f} | {distinct:,} |")
    con.close()
    return "\n".join(out) + "\n"


def selftest() -> None:
    con = duckdb.connect("/tmp/_audit_selftest.duckdb")
    con.execute("CREATE OR REPLACE TABLE t AS SELECT * FROM (VALUES (1, 'a'), (2, NULL)) AS v(id, name)")
    con.close()
    report = profile("/tmp/_audit_selftest.duckdb")
    assert "t — 2 rows" in report, report
    assert "| `name` | VARCHAR | 50.0 | 1 |" in report, report
    print("selftest ok")


if __name__ == "__main__":
    if sys.argv[1:2] == ["--selftest"]:
        selftest()
    else:
        db = sys.argv[1]
        out_file = sys.argv[2] if len(sys.argv) > 2 else "data/audit/data_profile.md"
        Path(out_file).parent.mkdir(parents=True, exist_ok=True)
        Path(out_file).write_text(profile(db), encoding="utf-8")
        print(f"wrote {out_file}")
