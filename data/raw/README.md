# data/raw — download instructions

Everything in this folder is git-ignored. Downloaded files are **never edited**; the pipeline only reads them.

## 1. VCT Reference database (main source, A1)

- **Link:** https://vct-reference.com/dataset/vct.duckdb
- **Save as:** `data/raw/vct_YYYY-MM-DD.duckdb`, using the date you downloaded it (e.g. `vct_2026-09-18.duckdb`).
- **Why the date:** the source is rebuilt daily. Freezing one dated copy keeps every number in the report reproducible. Do not re-download mid-project, with one planned exception: a second snapshot after Champions 2026 ends on 2026-10-18 (S-14). Keep both files; the scripts use the newest.
- Free to use, including commercially, with no warranty. Credit vct-reference.com in the README.

## 2. VCT Global Contract Database (contracts and residency, B2)

This is a "published to web" sheet, so it has no File menu. Use the export URL.

- **Download (all four regions, one workbook):** https://docs.google.com/spreadsheets/d/e/2PACX-1vRmmWiBmMMD43m5VtZq54nKlmj0ZtythsA1qCpegwx-iRptx2HEsG0T3cQlG1r2AIiKxBWnaurJZQ9Q/pub?output=xlsx
- **Save as:** `data/raw/gcd_YYYY-MM-DD.xlsx`, dated from the sheet's own "Last Update" cell. Currently `gcd_2026-09-14.xlsx`. The Americas tab is the one this project uses.
- **View in a browser:** the same link ending in `/pubhtml`, which has tabs for Americas, China, EMEA and Pacific.
- `output=csv` exports the first tab only, so the xlsx is safer.
- Fields: league, team, handle, contract end date, resident/import, roster status. No salaries.

## 3. Kaggle cross-check (optional, A2)

- **Link:** https://www.kaggle.com/datasets/piyush86kumar/valorant-vct-2025-all-events
- Needs a Kaggle login. **Save as:** `data/raw/kaggle_vct2025/`.
- Used only to reconcile ~10 player-map rows against source 1.

## After downloading

```bash
pip install -r requirements.txt
python src/audit.py data/raw/vct_2026-09-18.duckdb docs/data_profile.md   # schema profile
python -m src.export          # CSV dump + data/audit/*.csv (picks the newest vct_*.duckdb)
python -m src.spotcheck_vlr 729757 724645                        # cross-check vs vlr.gg
```

Then continue with Task 2 in `tasks/todo.md`: the interpretation, coverage decisions and go/no-go.
