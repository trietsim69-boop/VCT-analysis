# Implementation Plan: Valorant Player Recruitment & Roster Budget Dashboard

## Overview

A portfolio project that pairs data analysis with business analysis. It answers one question:

> **Which player should a team shortlist for a vacant role, and what acquisition cost could that player justify under different performance and revenue assumptions?**

You'll deliver:

1. A cleaned, tested analytical dataset (a star schema).
2. A three-page **Power BI** report: Scouting, Roster Fit and Budget Scenarios.
3. A **Tableau Public** story that presents the scouting findings to a general audience.
4. Business-analysis documents: a brief, a KPI dictionary, an assumptions log and a recommendation memo.

**Starting scope (from the brief):** the VCT 2025 Kaggle dataset, one region and one role. Roster-swap prediction is a stretch goal and must show uncertainty ranges.

## Architecture Decisions

| Decision | Choice | Rationale |
|---|---|---|
| Primary dataset | VCT 2025 (International + Regional), Kaggle | Covers a single season at a manageable size, with stats per match and per map. |
| Fallback dataset | VCT Reference DuckDB (8 linked tables) | Use it if the Kaggle files lack the needed grain, such as opening duels per map. It also demonstrates SQL well. |
| Processing stack | Python (pandas) + DuckDB SQL | DuckDB reads CSV and Parquet directly, the SQL is portable, and it's free. |
| Hand-off to BI tools | Star-schema CSV/Parquet files in `data/marts/` | Power BI and Tableau read the same files, so their numbers match. |
| Data model | `fact_player_map` plus the dimensions `dim_player`, `dim_team`, `dim_agent` (with role), `dim_map`, `dim_event` and `dim_date` | This is a standard star schema. Power BI relationships and Tableau relationships both handle it well. |
| Weighting | Rate metrics are **weighted by rounds**, not averaged across maps | A simple average of per-map ACS gives short maps too much weight. |
| Missing data | Missing values stay NULL and are never replaced with 0. Every visual shows its sample size (maps and rounds). | Both dataset docs warn about gaps: China economy data, and loadouts from Masters Toronto 2025 onward. |
| Role assignment | Agent → role lookup. A player's primary role is the role played on ≥ 60% of their maps. | The dataset has no explicit role field. The rule is transparent and can be tuned. |
| Tool split | **Power BI** is the full analyst tool: 3 pages with what-if parameters. **Tableau** is a public storytelling version of the Scouting and Roster Fit findings. | Each tool plays to its strengths, and you avoid building the same dashboard twice. |
| Financial inputs | All money inputs are editable parameters labelled "assumption". Esports Earnings prize money is shown only as a reference. | Prize earnings are not salaries or market values. |
| Language guardrail | No metric is labelled "communication". KAST and trade stats keep their literal names. | This keeps the claims honest. |

## Dependency Graph

```
Business brief + KPI dictionary (T1)
        │
Data acquisition + audit (T2) ── go/no-go gate: region, role, fallback dataset?
        │
Clean fact/dim tables + role mapping (T3)
        │
        ├── Scouting mart (T4) ──► PBI Scouting page (T5) ──┐
        │                                                    ├──► Tableau story (T10)
        ├── Roster-fit mart (T6) ──► PBI Roster Fit page (T7) ┘
        │
        └── (shortlist from T4) ──► Budget model spec + reference calc (T8) ──► PBI Budget page (T9)
                                                                                     │
                                      Recommendation memo (T11) ◄────────────────────┘
                                      Stretch: map-win model with uncertainty (T12)
                                      README / portfolio packaging (T13)
```

## Task List

The detailed tasks are in `tasks/todo.md`.

### Phase 0 — Scope & Data Risk (fail fast)
- [ ] T1: Business brief, stakeholder and KPI dictionary
- [ ] T2: Acquire and audit the VCT 2025 dataset, then choose the region and role

### Checkpoint A — Data go/no-go
- [ ] The data supports the per-map player metrics that the KPI dictionary needs
- [ ] The region and role are chosen, with ≥ 15 candidates who each have ≥ 20 maps (thresholds can be tuned)
- [ ] Human review before any modelling starts

### Phase 1 — Thin end-to-end slice: Scouting
- [ ] T3: Clean the fact and dimension tables and add the role mapping, with data tests
- [ ] T4: Build the scouting metrics mart (round-weighted rates, percentiles, consistency)
- [ ] T5: Build the Power BI Scouting page

### Checkpoint B — First slice works
- [ ] Raw data → mart → Power BI all run, and the numbers match for 3 spot-checked players
- [ ] Data tests pass

### Phase 2 — Roster Fit and Budget
- [ ] T6: Build the roster-fit mart (team gaps against the candidate's agent and map profile)
- [ ] T7: Build the Power BI Roster Fit page
- [ ] T8: Write the budget model spec and a reference calculation with test cases
- [ ] T9: Build the Power BI Budget Scenarios page (what-if parameters)

### Checkpoint C — Analyst tool complete
- [ ] All 3 Power BI pages work with cross-filtering
- [ ] Budget outputs match the reference calculation for every test case

### Phase 3 — Storytelling and Delivery
- [ ] T10: Build the Tableau Public story (Scouting and Roster Fit)
- [ ] T11: Write the shortlist and recommendation memo
- [ ] T12 (stretch): Build a map-win probability model with bootstrap uncertainty
- [ ] T13: Write the README, methodology and limitations, and package the portfolio

### Checkpoint D — Complete
- [ ] Every acceptance criterion is met
- [ ] Tableau and Power BI show the same headline numbers
- [ ] Human review of the memo and dashboards

## Proposed Folder Layout

```
D:\football analysis\          (consider renaming it to valorant-recruitment)
├── data/raw/                  original downloads, read-only, git-ignored
├── data/processed/            cleaned fact/dim Parquet files
├── data/marts/                BI-ready CSV/Parquet files
├── src/                       Python pipeline (ingest.py, clean.py, marts.py, budget.py)
├── sql/                       DuckDB model and mart SQL
├── tests/                     pytest data tests
├── notebooks/                 audit and exploratory analysis
├── powerbi/                   valorant_recruitment.pbix
├── tableau/                   valorant_recruitment.twbx
├── docs/                      brief, KPI dictionary, data audit, assumptions, memo
└── tasks/                     plan.md, todo.md
```

## Risks and Mitigations

| Risk | Impact | Mitigation |
|---|---|---|
| The Kaggle files lack per-map opening kills and deaths, or player–team links | High | T2 audits this first. The fallback is the VCT Reference DuckDB. |
| Small samples for some players | High | Set a minimum-maps threshold, show a sample-size column on every visual, and use percentiles only inside the eligible pool. |
| Missing values treated as zero | High | Data tests assert that NULLs are preserved. Measures use AVERAGE or DIVIDE, which ignore blanks. |
| Role inference is wrong for flex players | Med | Use the 60% rule plus a "Flex" bucket. List flex players explicitly in the audit. |
| Budget outputs look authoritative but rest on invented numbers | Med | Label every input as an assumption, show defaults with sources, and add a scenario toggle (low/base/high). |
| Readers take a roster-swap prediction as fact | Med | The model is a stretch goal only, with confidence intervals and a written caveat that the data can't show teammate effects. |
| Power BI and Tableau disagree | Low | Both read the same mart files. T10 includes a parity check. |
| Scope creep (more regions, roles or seasons) | Med | Stay with one region and one role until Checkpoint D. Everything else is a follow-up. |

## Open Questions

1. **Region and role:** the defaults are *Americas + Duelist*, the richest stats for a first version. Controller or Initiator would be more distinctive. T2's sample-size check settles the final choice.
2. **Tool split:** should Tableau be a storytelling companion (the current plan), or a full duplicate of the Power BI report to compare the tools?
3. **Environment:** do you have Power BI Desktop (Windows) and Tableau Public/Desktop installed, plus Python 3.11+? Do you have a Kaggle account or API key for the download?
4. **Folder:** the connected folder is named "football analysis". Should the project live there, or in a new folder?
5. **Audience:** is this for a portfolio/job applications or a course submission? The answer changes how much polish T13 needs.
