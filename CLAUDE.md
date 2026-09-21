# CLAUDE.md

Guidance for any Claude session working in this repo.

## What this is

A portfolio project in data analysis and business analysis: **which player should Sentinels sign for its vacant 2027 slot, and what is that signing worth paying?** The outputs are a three-page Power BI report, a Tableau Public story and a written recommendation.

It is an **unofficial fan analysis**. It is not affiliated with Sentinels or Riot Games, and every page says so.

The folder is named "football analysis" for historical reasons. The project is VALORANT.

## Read first

| File | What it holds |
|---|---|
| `tasks/plan.md` | Architecture decisions, the full data-source list (A1–A8, B1–B7), the dependency graph and risks |
| `tasks/todo.md` | The 13 tasks in order, each with acceptance criteria and verification. **This is the source of truth for what to do next.** |
| `docs/business_brief.md` | The problem, the stakeholder, the three decisions (D1–D3), scope and success criteria |
| `docs/kpi_dictionary.md` | Every metric: formula, weighting, and what it does **not** measure |
| `docs/assumptions_log.md` | Every non-measured number, with IDs (S-xx scope, F-xx financial, C-xx context) |

Start any session by reading `tasks/todo.md` and working the first unchecked task. Stop at each checkpoint for the user's review.

## Decided scope (settled 2026-09-17; reopen only if the user asks)

- **Team:** Sentinels, VCT Americas, seen from a hypothetical GM's point of view.
- **Vacancy:** the slot stand-ins covered in 2026. Its role is inferred from agent picks in T2.
- **Window:** 2026 for ranking, 2025 for the consistency check.
- **Candidates:** top-tier VCT only. Challengers are phase 2.
- **Data:** VCT Reference `vct.duckdb` is the main source, with Kaggle VCT 2025 as a cross-check.

## Rules for the analysis

- **Missing values stay NULL.** Never fill a missing stat with 0; use `DIVIDE()` in DAX and averages that ignore blanks.
- **Rates are weighted by rounds:** Σ numerator ÷ Σ rounds. Never average per-map rates.
- **Every visual shows its sample size** (maps and rounds played). Players below the eligibility bar are shown greyed out.
- **Rank on transparent metrics only.** vlr.gg's Rating and ACS are displayed, never used for ranking.
- **Describe metrics literally.** KAST is rounds with a kill, assist, survival or traded death. It is not "communication" or "teamwork".
- **Label every financial input "Assumption"** and give it an ID from the assumptions log. Prize money is prize money, never salary.
- **State ranges, not point predictions,** for anything about future performance.
- **Record new numbers in `docs/assumptions_log.md`** with their status: decided, sourced, illustrative or to verify.

## Working method

- Data pipeline: **Python + DuckDB** → CSV in `data/processed/` → BI-ready CSV in `data/marts/`. Power BI and Tableau both read `data/marts/`, which keeps them consistent.
- Every mart gets a `pytest` data test. Verify with tests and spot-checks against vlr.gg, not by eye.
- `data/raw/` is git-ignored: keep the dated `vct.duckdb` snapshot there and never re-download it mid-project.
- Power BI Desktop and Tableau run on the user's Windows machine. A session in the cloud workspace can build the data and the documents, but cannot open a `.pbix` or `.twbx`.

## Repo

- Remote: `https://github.com/trietsim69-boop/VCT-analysis.git`, branch `main`.
- The user commits and pushes. Cloud sessions usually can't reach this repo; write files to the folder and tell the user what to commit.
