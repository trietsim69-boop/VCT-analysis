# Implementation Plan: Valorant Player Recruitment & Roster Budget Dashboard

## Overview

A portfolio project that pairs data analysis with business analysis. It answers one question:

> **Which player should a team shortlist for a vacant role, and what acquisition cost could that player justify under different performance and revenue assumptions?**

You'll deliver:

1. A cleaned, tested analytical dataset (a star schema).
2. A three-page **Power BI** report: Scouting, Roster Fit and Budget Scenarios.
3. A **Tableau Public** story that presents the scouting findings to a general audience.
4. Business-analysis documents: a brief, a KPI dictionary, an assumptions log and a recommendation memo.

**Starting scope (decided 2026-09-17, see `docs/business_brief.md`):**
- **Team:** Sentinels (VCT Americas), analysed from a hypothetical GM's point of view as an unofficial portfolio piece.
- **Vacancy:** the slot stand-ins covered in 2026. Its role is confirmed in T2.
- **Data window:** 2026 is the main scouting window and 2025 is used for consistency. The data comes from VCT Reference, with Kaggle as a cross-check.
- **Candidates:** top-tier players only; Challengers are phase 2. Roster-swap prediction is a stretch goal and must show uncertainty ranges.

## Architecture Decisions

| Decision | Choice | Rationale |
|---|---|---|
| Primary dataset | **VCT Reference DuckDB** (`vct.duckdb`), filtered to **2026 completed matches** (2025 for the consistency check) | It's a single direct download with no login, rebuilt daily, and free to use including commercially. It already has the `player_map` grain (rating, ACS, ADR, KAST, duels, clutches) plus `kill_matrix`. See [Data Sources](#data-sources). |
| Cross-check dataset | Kaggle "Valorant 2025 – All Events International + Regional" | A second vlr.gg-derived source for spot-checking totals in T2. Its file and column layout still needs confirming. |
| Processing stack | Python (pandas) + DuckDB SQL | DuckDB reads and writes CSV directly, the SQL is portable, and it's free. |
| Hand-off to BI tools | Star-schema **CSV** files in `data/marts/` | Power BI and Tableau read the same files, so their numbers match. CSV everywhere — openable in Excel, diffable, and no format the user has to learn. |
| Data model | `fact_player_map` plus the dimensions `dim_player`, `dim_team`, `dim_agent` (with role), `dim_map`, `dim_event` and `dim_date` | This is a standard star schema. Power BI relationships and Tableau relationships both handle it well. |
| Weighting | Rate metrics are **weighted by rounds**, not averaged across maps | A simple average of per-map ACS gives short maps too much weight. |
| Missing data | Missing values stay NULL and are never replaced with 0. Every visual shows its sample size (maps and rounds). | Both dataset docs warn about gaps: China economy data, and loadouts from Masters Toronto 2025 onward. |
| Role assignment | Agent → role lookup. A player's primary role is the role played on ≥ 60% of their maps. | The dataset has no explicit role field. The rule is transparent and can be tuned. |
| Tool split | **Power BI** is the full analyst tool: 3 pages with what-if parameters. **Tableau** is a public storytelling version of the Scouting and Roster Fit findings. | Each tool plays to its strengths, and you avoid building the same dashboard twice. |
| Financial inputs | All money inputs are editable parameters labelled "assumption". Esports Earnings prize money is shown only as a reference. | Prize earnings are not salaries or market values. |
| Language guardrail | No metric is labelled "communication". KAST and trade stats keep their literal names. | This keeps the claims honest. |

## Data Sources

Researched on 2026-09-17. "Verified" means I read the source's own page. For Kaggle, only titles and descriptions were visible (the pages render client-side), so their files must be confirmed in T2.

### A. Performance data (scouting and roster fit)

| # | Source | What's in it | Access / licence | Use in project | Status |
|---|---|---|---|---|---|
| A1 | **[VCT Reference dataset](https://vct-reference.com/dataset)**, direct file: `https://vct-reference.com/dataset/vct.duckdb` | 8 tables: `matches`, `maps`, `rounds` (with economy snapshots), `player_map` (rating, ACS, ADR, KAST, HS%, K/D/A, duels, multikills, clutches), `kill_matrix` (player-vs-player kills, opening kills), `notables`, `players`, `teams`. Tier-1 VCT from 2021 onward, rebuilt daily (last build 2026-09-16). | Free, including commercial use, no warranty; attribution appreciated | **Primary source.** T2–T6. `kill_matrix` supports trade and opening-duel analysis. | Verified |
| A2 | [Kaggle – Valorant 2025: All Events International + Regional](https://www.kaggle.com/datasets/piyush86kumar/valorant-vct-2025-all-events) (piyush86kumar) | All VCT 2025 international and regional events, scraped from vlr.gg | Kaggle login; check the licence on the page | Cross-check totals in T2. It's the fallback if A1 is unavailable. | Title verified; files TBC |
| A3 | [Kaggle – VCT 2025 Stage 2, All Regions](https://www.kaggle.com/datasets/piyush86kumar/valorant-stage-2-2025-all-regions) | Stage 2 across all regions | Kaggle login | Optional: a smaller slice if you want a quick prototype | Title verified; files TBC |
| A4 | [Kaggle – Valorant Champions 2025 Paris](https://www.kaggle.com/datasets/piyush86kumar/valorant-champions-tour-2025-paris) | Player and match data for Champions 2025, from vlr.gg | Kaggle login | Optional: the Tableau story's "big stage" view | Title verified; files TBC |
| A5 | [Kaggle – Valorant Champion Tour 2021–2026](https://www.kaggle.com/datasets/ryanluong1/valorant-champion-tour-2021-2023-data) (Ryan Luong) | Multiple seasons of matches, agents and players, including picks/bans and round economy | Kaggle login | Stretch goal: multi-season trends. Known gap: round loadout values are missing from Masters Toronto 2025 onward. | Title verified; files TBC |
| A6 | [vlr.gg event stats](https://www.vlr.gg/event/stats/2283/valorant-champions-2025) | Public stats pages per event | Website (no bulk export) | Manual spot-checks in T2 and T4 | Verified |
| A7 | [vlrggapi](https://github.com/axsddlr/vlrggapi) | Unofficial REST API over vlr.gg (stats, matches, rankings) | MIT. The public instance is **down**, so you'd have to self-host. 600 requests/min. | Not needed (A1 covers it). Only use it if a field is missing. | Verified |
| A8 | [GRID VALORANT Data Portal](https://grid.gg/get-valorant/) | Official granular in-game data | Application required. Free only for pro teams; research and media use is paid. | Out of scope for v1 | Verified |

### B. Business and financial context (budget scenarios)

| # | Source | What's in it | Access | Use in project | Status |
|---|---|---|---|---|---|
| B1 | [Esports Earnings – VALORANT](https://www.esportsearnings.com/games/646-valorant) and its [API](https://www.esportsearnings.com/apidocs) | Recorded prize earnings per player and tournament. The Valorant game ID is **646** (from the URL). | Free API key (register in the Development Area); at most 1 request per second | T8 `prize_reference.csv`. Label it **"prize money, not salary"**. | Verified |
| B2 | [VCT Global Contract Database](https://docs.google.com/spreadsheets/d/e/2PACX-1vRmmWiBmMMD43m5VtZq54nKlmj0ZtythsA1qCpegwx-iRptx2HEsG0T3cQlG1r2AIiKxBWnaurJZQ9Q/pubhtml) (Riot, published Google Sheet; [explainer](https://www.hotspawn.com/valorant/news/valorant-vct-global-contract-database)) | League, team, handle, **contract end date (usually year only)**, resident/import status, active/inactive. **No salaries.** | Public | T4/T5: add a "contract ends this year" flag and a resident/import flag (import slots are limited). T8: a shorter remaining term suggests a lower buyout. | Verified via the explainer |
| B3 | Riot minimum salaries, 2023 partnered leagues ([Dexerto](https://www.dexerto.com/esports/vct-2023-roster-regulations-explained-minimum-salaries-import-rules-roster-sizes-1944581/)) | Americas **$50,000**, EMEA **€50,000**, Pacific **₩67,000,000** base salary. Max 1 import; rosters of 6–10 players. | Public article (2023 rules; may have changed) | T8: the salary floor for the "low" scenario | Verified (2023) |
| B4 | VCT 2025 revenue share ([Hotspawn](https://www.hotspawn.com/valorant/news/vct-2025-100m-rev-share), Riot announcement 2025-12-16) | **$105.2M** shared with partner teams in 2025, **$86M** of it from digital goods. No per-team split published. | Public article | T8: context for team-capsule revenue. Divide by the number of partner teams only as an explicitly labelled rough average. | Verified |
| B5 | VCT 2027 partnership terms ([THESPIKE](https://www.thespike.gg/valorant/news/partnered-vct-2027-teams-to-receive-up-to-5-million-per-year-under-new-format/7963)) | Partner teams receive **$600K–$5M per year** (base payment + performance bonus + capsules), depending on results and skin sales. Covers North America, Brazil and the rest of Latin America. | Public article | T8: the range for team revenue in the low and high scenarios, and the link between "performance → bonus" | Verified |
| B6 | [Esports Charts – VCT 2025](https://escharts.com/news/vct-2025-stage-1-global-viewership) (e.g. [Americas Stage 1](https://escharts.com/tournaments/valorant/vct-2025-americas-stage-1)) | Peak and average viewers and hours watched per event | Website (the API is paid) | T8: a proxy for sponsorship and exposure value in the scenario narrative. Record a few numbers by hand. | Search results only |
| B7 | [Liquipedia API](https://liquipedia.net/api) | Transfers, rosters and results | Free for open-source educational projects (limited time); paid tiers from $49/month | Optional: transfer history for T11 context | Verified |

### Handling rules
- **Filter A1 to the 2026 season and `matches.status = 'final'`.** The snapshot carries placeholder rows for unplayed fixtures; the status filter is the only thing that removes them (`docs/data_audit.md` §0). All regions are in scope — the team is fixed (Sentinels), not the region.
- **`performance_available` / `economy_available` gate vlr.gg's Performance and Economy tabs only** (multi-kills, clutches, `kill_matrix`, loadouts) — *not* the ranking stats. Use them for the display-only metrics; never for the ranking, or all 372 Chinese league maps are silently dropped (§1).
- **Divide each rate by the rounds of the maps where that metric is non-NULL.** China is missing ADR on ~15% of rows; a shared denominator understates those players (§4).
- **Salaries and buyouts are never presented as data.** B3–B5 only set scenario ranges, and every value is listed in `docs/assumptions_log.md` with its source.
- **Attribution:** credit VCT Reference, Esports Earnings and Riot in the README (T13).

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
- [ ] T2: Acquire and audit the VCT Reference dataset, then confirm the vacant slot's role

### Checkpoint A — Data go/no-go
- [ ] The data supports the per-map player metrics that the KPI dictionary needs
- [ ] The role is confirmed and the candidate pool is big enough: **≥ 15 maps in 2026** (S-07), giving 84 eligible duelists
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
├── data/processed/            cleaned fact/dim CSV files
├── data/marts/                BI-ready CSV files
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
| VCT Reference changes its schema or goes offline (it's a community project, rebuilt daily) | High | Save a dated copy of `vct.duckdb` in `data/raw/` and never re-download mid-project, except for the one planned Champions re-snapshot below. Kaggle A2 is the fallback. |
| The 2026-09-18 snapshot predates Champions 2026 (2026-09-24 → 2026-10-18), the biggest event of the window | High | **Planned:** take a second dated snapshot after 2026-10-18 and rerun the pipeline (S-14). Everything is built on the pre-Champions snapshot until then; `python -m src.export` and `sql/audit.sql` regenerate every audit figure, so the refresh is a rerun, not a rewrite. Numbers in `docs/` are restated once, and the snapshot date is shown on every page (S-11). |
| The Champions re-snapshot changes the shortlist after the dashboards are built | Med | Treat the pre-Champions run as the draft. Freeze headline numbers only after the refresh, and keep both snapshots in `data/raw/` so the two runs can be compared. |
| Small samples for some players | High | Set a minimum-maps threshold, show a sample-size column on every visual, and use percentiles only inside the eligible pool. |
| Missing values treated as zero | High | Data tests assert that NULLs are preserved. Measures use AVERAGE or DIVIDE, which ignore blanks. |
| Role inference is wrong for flex players | Med | Use the 60% rule plus a "Flex" bucket. List flex players explicitly in the audit. |
| Budget outputs look authoritative but rest on invented numbers | Med | Label every input as an assumption, show defaults with sources, and add a scenario toggle (low/base/high). |
| Readers take a roster-swap prediction as fact | Med | The model is a stretch goal only, with confidence intervals and a written caveat that the data can't show teammate effects. |
| Power BI and Tableau disagree | Low | Both read the same mart files. T10 includes a parity check. |
| Scope creep (more regions, roles or seasons) | Med | Stay with one region and one role until Checkpoint D. Everything else is a follow-up. |

## Open Questions

1. ~~Region and role~~ **Decided:** Sentinels (Americas). The role of the vacant slot is inferred in T2.
2. **Tool split:** should Tableau be a storytelling companion (the current plan), or a full duplicate of the Power BI report to compare the tools?
3. **Environment:** do you have Power BI Desktop (Windows) and Tableau Public/Desktop installed, plus Python 3.11+? The main dataset needs no login. A Kaggle account is only needed for the cross-check, and an Esports Earnings API key only for T8.
4. **Folder:** the connected folder is named "football analysis". Should the project live there, or in a new folder?
5. ~~Audience~~ **Decided:** a portfolio piece and personal learning.
