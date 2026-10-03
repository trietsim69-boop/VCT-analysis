# data/raw — download instructions

Everything in this folder is git-ignored. Downloaded files are **never edited**; the pipeline only reads them.

## 1. VCT Reference database (main source)

- **Link:** https://vct-reference.com/dataset/vct.duckdb
- **Save as:** `data/raw/vct_YYYY-MM-DD.duckdb`, using the date you downloaded it (e.g. `vct_2026-09-18.duckdb`).
- **Why the date:** the source is rebuilt daily. Freezing one dated copy keeps every number in the report reproducible. Do not re-download mid-project, with one planned exception: a second snapshot after Champions 2026 ends on 2026-10-18 (S-14). Keep both files; the scripts use the newest.
- Free to use, including commercially, with no warranty. Credited in the main README.

## 2. VCT Global Contract Database (contracts and residency)

This is a "published to web" sheet, so it has no File menu. Use the export URL.

- **Download (all four regions, one workbook):** https://docs.google.com/spreadsheets/d/e/2PACX-1vRmmWiBmMMD43m5VtZq54nKlmj0ZtythsA1qCpegwx-iRptx2HEsG0T3cQlG1r2AIiKxBWnaurJZQ9Q/pub?output=xlsx
- **Save as:** `data/raw/gcd_YYYY-MM-DD.xlsx`, dated from the sheet's own "Last Update" cell. Currently `gcd_2026-09-14.xlsx`. The Americas tab is the one this project uses.
- **View in a browser:** the same link ending in `/pubhtml`, which has tabs for Americas, China, EMEA and Pacific.
- `output=csv` exports the first tab only, so the xlsx is safer.
- Fields: league, team, handle, contract end date, resident/import, roster status. No salaries.

## After downloading

```bash
pip install -r requirements.txt
python -m src.clean      # raw snapshot -> star schema in data/processed/
python -m src.marts      # data/processed/ -> BI-ready files in data/marts/
pytest                   # 61 data tests
```

Optional audit steps:

```bash
python src/audit.py data/raw/vct_2026-09-18.duckdb    # schema profile -> data/audit/data_profile.md
python -m src.export                                   # CSV dump + data/audit/*.csv (newest vct_*.duckdb)
python -m src.spotcheck_vlr 729757 724645              # cross-check two matches against vlr.gg
```

The findings from these steps are in [`docs/data_audit.md`](../../docs/data_audit.md).
