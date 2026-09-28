# Task List: Valorant Player Recruitment & Roster Budget Dashboard

The plan is in `tasks/plan.md`. Work through the tasks in order and stop at each checkpoint for review.

---

## Phase 0 — Scope & Data Risk

### Task 1: Business brief, stakeholder and KPI dictionary — ✅ **signed off 2026-09-18**

**Description:** Write the business-analysis foundation. This covers the problem statement, the stakeholder (a team GM or head coach), the decisions the dashboard supports, what's in and out of scope, and a KPI dictionary. For each KPI, the dictionary gives the name, formula, grain, weighting, minimum sample and what the KPI does *not* measure.

**Acceptance criteria:**
- [x] `docs/business_brief.md` states the business question, stakeholder, 3 decisions supported, scope and non-goals
- [x] `docs/kpi_dictionary.md` defines ≥ 8 KPIs: Rating, ACS, ADR, KPR, APR, KAST, FK/FD per round, FK−FD differential, consistency (CV of per-map ADR), maps and rounds played
- [x] `docs/assumptions_log.md` is started with the financial assumptions marked "to be sourced"

**Verification:**
- [x] Manual check: every KPI names its source column (placeholders are fine until T2) and its weighting rule
- [x] Manual check: no KPI is labelled as "communication"

**Dependencies:** None
**Files:** `docs/business_brief.md`, `docs/kpi_dictionary.md`, `docs/assumptions_log.md`
**Scope:** S

---

### Task 2: Acquire and audit the data; confirm the role — ⚠️ **audit revised 2026-09-18 (v0.3); one decision open (S-14)**

> Findings in `docs/data_audit.md`, schema profile in `docs/data_profile.md`. Verdict: **GO**. The vacant slot is the **duelist** slot, and 84 duelists are eligible.
>
> **v0.2 correction:** the first pass counted scheduled Champions 2026 fixtures as data. 2026 has **588 completed matches**, not 622, and Champions 2026 (2026-09-24 → 2026-10-18) is outside the window. `maps.performance_available` is TRUE on unplayed fixtures, so `matches.status = 'final'` is a mandatory filter in T3 onward.

**Description:** Download `https://vct-reference.com/dataset/vct.duckdb` (source A1 in the plan) into `data/raw/vct_YYYY-MM-DD.duckdb` (now `vct_2026-09-18.duckdb`) and don't modify it. Filter to 2026 completed matches (`matches.status = 'final'`). Download the Kaggle 2025 all-events dataset (A2) as a cross-check. Download the VCT Global Contract Database sheet (B2) as `gcd_YYYY-MM-DD.xlsx` via its `pub?output=xlsx` export URL. Profile every file: grain, keys, row counts, null rates, event and region coverage, and the agent list. Confirm that the KPI dictionary's metrics exist at the player-map grain. Count eligible players per region × role and choose the scope.

**Acceptance criteria:**
- [x] `docs/data_profile.md` lists each table with row counts, types, null % and distinct counts; `docs/data_audit.md` adds the grain, keys and KPI mapping
- [x] Known gaps documented: China has 0% performance and economy data (S-12), and clutch attempts don't exist
- [x] 2026 coverage confirmed (S-05) — **revised**: 588 *completed* matches; Champions 2026 is unplayed and excluded. Every query must filter `matches.status = 'final'`.
- [x] The vacant slot's role inferred as **duelist** (S-03)
- [x] Eligibility counted: 84 duelists with ≥ 15 maps in 2026 (S-13)
- [x] Coverage flags profiled by region (`performance_available`, `economy_available`)
- [x] Go/no-go decided: **GO** on VCT Reference
- [x] ~~Reconcile 10 rows against Kaggle A2~~ → replaced by a vlr.gg spot-check (the actual upstream source)
- [x] SEN's import status checked in the Global Contract Database workbook (S-10) — **the import slot is already taken by johnqt**; signing an import is a two-slot decision
- [ ] **Champions 2026 re-snapshot (S-14)** — open until 2026-10-18. Decided approach: build everything on the pre-Champions snapshot now, then take a second dated snapshot after Champions ends and rerun the pipeline. Does **not** block Checkpoint A.

**Verification:**
- [x] Every audit query ran without errors, and the top of the duelist pool returns plausible 2026 names
- [x] Totals for 2 matches match their vlr.gg match pages — **600/600 cells** (SEN vs KRÜ, JDG vs TYLOO), `python -m src.spotcheck_vlr`

**Dependencies:** T1
**Files:** `data/raw/*`, `sql/audit.sql`, `src/export.py`, `src/spotcheck_vlr.py`, `data/audit/*.csv`, `docs/data_audit.md`
**Scope:** M

## ✅ Checkpoint A — Data go/no-go — **passed 2026-09-21**
- [x] The KPIs in T1 can be computed from the data in T2 — every ranking column mapped and 0% null outside China (`data_audit.md` §4); clutch success % dropped for lack of an attempts column
- [x] The role is confirmed (duelist, S-03) and the pool is large enough: **84 eligible duelists** (S-13)
- [x] **Human review** — signed off 2026-09-21. S-14 (Champions re-snapshot after 2026-10-18) stays open and does not block.

---

## Phase 1 — Thin Slice: Scouting

### Task 3: Clean the fact and dimension tables and add the role mapping — ✅ **done 2026-09-21**

> `python -m src.clean` → `data/processed/`: `fact_player_map` (73,116 rows, all seasons, completed matches only) plus `dim_player` (with `primary_role`), `dim_team`, `dim_agent`, `dim_event`, `dim_map`. 9 tests pass.

**Description:** Build a repeatable pipeline that turns the raw files into `fact_player_map` plus the dimensions (player, team, agent with role, map, event, date), written as CSV. Add the agent → role seed file and the primary-role rule (≥ 60% of maps, otherwise "Flex").

**Acceptance criteria:**
- [x] `python -m src.clean` writes the CSV files to `data/processed/` and can be re-run safely (every `COPY` overwrites)
- [x] `fact_player_map` has one row per player × map × match, with no duplicates — 73,116 rows, 73,116 distinct keys
- [x] Missing values stay NULL (they are never filled with 0) — 3,600 NULL ADR rows kept; zero rows have `adr_all = 0`

**Verification:**
- [x] `pytest tests/test_clean.py` passes — 9 tests: key uniqueness, no unplayed fixtures leaked, 2026 row count vs the audit, NULL preservation, every agent mapped, agent is scalar, and 3 primary roles
- [x] 3 known players have the expected primary role: Jerrwin duelist (30/30), JonahP initiator (32/32), Reduxx **Flex** (57% duelist, below the 60% bar)

**Dependencies:** T2
**Files:** `src/clean.py`, `sql/model.sql`, `src/__init__.py`, `data/seeds/agent_roles.csv`, `tests/test_clean.py`
**Scope:** M

---

### Task 4: Scouting metrics mart

**Description:** Aggregate `fact_player_map` to one row per player for the 2026 window. Round-weighted rates with per-metric denominators, percentiles within the role pool, a consistency score, an eligibility flag and a role-weighted composite.

**Scope decided 2026-09-21: all five roles, not duelist only.** The SQL costs the same, percentiles are computed within `primary_role` either way, and it makes the Scouting page's role slicer real. The duelist pool (S-03, 84 players) stays the focus of the recommendation.

#### T4.1 — Metric weights seed · S — ✅ **done 2026-09-21**
`data/seeds/metric_weights.csv` with `role, metric, weight`, 29 rows across 5 roles. No YAML dependency. Table and reasoning in `docs/kpi_dictionary.md` § Composite weights.
- [x] Weights are data, not code — changing one does not touch SQL
- [x] Verify: weights per role sum to 1 — `pytest tests/test_marts.py`, 4 tests
- [x] **7 metrics weighted, not 10.** KPR and ACS dropped: they correlate with ADR at 0.95 and 0.97 over the 2026 pool, so weighting all three counts one signal three times. FK−FD per round dropped as a third view of the duel data. FKPR and opening-duel win % both kept — they correlate at only 0.41, so entry volume and entry success are separate questions, which is exactly the question for this slot.
- [x] A test asserts no display-only metric (rating, ACS, HS%) can reach the composite (S-09)

#### T4.2 — `mart_scouting.csv` · M — ✅ **done 2026-09-21**
One row per player, 2026 window. Rates are `SUM(stat × rounds) / SUM(rounds) FILTER (WHERE stat IS NOT NULL)` — the per-metric denominator rule (`data_audit.md` §4).
- [x] Every KPI from dictionary section B, plus the display-only ones from section C
- [x] Carries `maps_played`, `rounds_played`, per-metric map counts (`adr_maps`, `kast_maps`, `fk_maps`), `primary_role`, `regions`, `is_eligible` and `china_league`
- [x] No metric is an average of per-map rates
- [x] Verify: Jerrwin's weighted ADR recomputed with pandas matches the SQL; ZmjjKK's ADR divides by 77 maps, not his 85 `maps_played`
- [x] **384 rows, 289 eligible**

#### T4.3 — Consistency score · S — ✅ **done 2026-09-21**
CV of per-map ADR. **Only 50 of the 84 eligible duelists have ≥ 5 maps in 2025**, so a 2025–26 score alone would be blank or noisy for the rest and would penalise newer players.
- [x] `cv_adr_2026` is the primary; `cv_adr_2025_26` is a second column; `cv_maps_2025_26` and `adr_maps_2025` are reported alongside
- [x] NULL unless the player has **≥ 5 maps in 2025** and ≥ 10 across both. The first cut (≥ 10 maps across both seasons) was wrong — a 2026-only player clears it and gets the 2026 CV wearing a two-season label. Caught on the first build.
- [x] Verify: 35 of the 84 eligible duelists have a NULL two-season CV and a valid 2026 one; a test asserts no row has a two-season CV without 2025 history

#### T4.4 — Percentiles and composite · M — ✅ **done 2026-09-21**
Percentiles within `primary_role`, over eligible players only, 0–100, inverted for DPR, FDPR and CV. Composite = weighted sum of percentiles using T4.1.
- [x] Rating and ACS are **excluded** from the composite (S-09) — a test blocks any display-only metric from reaching the weights
- [x] Verify: all percentiles fall in 0–100; ineligible players have NULL composite, never 0; all 289 eligible have one
- [x] Verify: weight sensitivity — the composite correlates **0.978** with flat equal weights, asserted > 0.9 in `tests/test_marts.py`
- [x] The composite renormalises over the weights actually used, so a missing metric does not silently score 0
- [x] **Carried to T5:** present the composite as a **band, not a position** (`kpi_dictionary.md` § Composite weights) — the page shows "top 10 of 84", never "8th best"

#### T4.5 — `mart_scouting_by_map.csv` · S — ✅ **done 2026-09-21**
Player × `map_name`, same weighting and map counts. Feeds the T6 map-pool comparison.
- [x] Verify: Σ rounds by map equals `rounds_played` in the main mart, for every player (3,390 rows)
- [x] Also carries `map_win_pct` per player × map, which T6 needs

#### T4.6 — `tests/test_marts.py` · S — ✅ **done 2026-09-21**
- [x] 11 tests covering the weights seed and both marts; 19 tests pass across the suite
- [x] Manual check: the top of the duelist board is primmie, Kachoww, t3xture, marteen, Meiy — plausible 2026 names, and the same set the T2 audit spot-check surfaced
- [ ] **Open:** Kachoww ranks 2nd on 16 maps, the minimum. The composite does not shrink small samples towards the mean; T5 must show `maps_played` beside every rate (CLAUDE.md) so this is visible rather than hidden

**Not in T4:** the import and contract flag. `dim_player` has no link to the Global Contract Database, which is keyed by tournament handle and needs a fuzzy name match. It belongs to T6, where S-10 bites.

**Dependencies:** T3
**Files:** `sql/mart_scouting.sql`, `src/marts.py`, `data/seeds/metric_weights.csv`, `tests/test_marts.py`
**Scope:** M

---

### Task 5: Power BI Scouting page — ✅ **done 2026-09-24, reviewed 2026-09-26**

> `valorant_recruitment.pbix` (repo root). Model, measures and verification in `docs/dax_measures.md`. QA page reconciles Jerrwin, ZmjjKK and Kachoww against `mart_scouting.csv`, 39/39 cells.

**Description:** Import the marts and dimensions into Power BI, set up the star-schema relationships and a DAX measures table, and build the Scouting page. It needs a candidate table with sample sizes, a percentile radar or bar chart, a scatter plot (for example ADR vs FK−FD) and slicers for event, map and minimum maps.

**Acceptance criteria:**
- [x] The model uses single-direction relationships from the dimensions to the fact table, and measures live in a dedicated table
- [x] Every visual shows or tooltips the maps and rounds played, and ineligible players are visually flagged or filtered
- [x] Blank values show as blank, not 0

**Verification:**
- [x] Manual check: KPIs for 3 players in Power BI match `mart_scouting.csv` exactly
- [x] Manual check: each slicer changes every visual as expected

**Dependencies:** T4
**Files:** `valorant_recruitment.pbix`, `docs/dax_measures.md`
**Scope:** M

## ✅ Checkpoint B — First slice end to end — **passed 2026-09-26**
- [x] Raw → processed → mart → Power BI runs cleanly
- [x] All pytest data tests pass — 19 pass
- [x] **Human review of the scouting page before continuing**

---

## Phase 2 — Roster Fit and Budget

### Task 6: Roster-fit mart — ✅ **done 2026-09-26**

> `python -m src.marts` → `mart_team_profile.csv` (SEN × map, 12 rows) and `mart_fit.csv` (84 eligible duelists). `python -m src.clean` now also writes `dim_contract_americas.csv` from the contract workbook. Definitions in `kpi_dictionary.md` § D; decisions S-16 to S-19.

**Description:** For a selected target team, build its profile: map pool win rates, agent coverage and the metrics of the outgoing player in the vacant role. Then compare each eligible candidate's agent pool and map performance against the team's needs.

**Scope decided 2026-09-26:** SEN only, not every team — "the vacant slot" is only defined for SEN. Baseline is Jerrwin (S-16); a replacement-level line is a BI-side reference, not a mart column. Map fit uses the player's own per-map ADR, never his team's win rate.

**Acceptance criteria:**
- [x] `mart_team_profile.csv` holds SEN × map games, wins, rounds and win %; `mart_fit.csv` holds candidate × SEN with agent overlap %, map fit, map coverage %, KPI deltas against Jerrwin and the import flag
- [x] The fit-score formula is documented (`kpi_dictionary.md` § D), and its weights live in one seed file, `data/seeds/fit_weights.csv` (CSV, not YAML, as in T4.1)
- [x] **Map fit rebuilt once:** the first cut correlated 0.96 with overall ADR (double counting); now measured against the player's own average, r = −0.03, test-guarded
- [x] Import flag uses Riot's contract database first, nationality second — Jerrwin is Indian and an Americas Resident, so nationality alone is wrong (S-19)

**Verification:**
- [x] `pytest tests/test_fit.py` passes — 8 tests; 27 across the suite. The known-overlap case: Jerrwin against himself scores 100% overlap and every delta 0; primmie's 30% recomputed by hand
- [x] Manual check: SEN's map records match vlr.gg — **19/19 event × map cells** (Kickoff, Stage 1, Stage 2). vlr.gg's unfiltered page shows 61 maps because it includes non-VCT events
- [ ] **Open:** the shortlist's import status that rests on nationality (`import_source` = proxy) is confirmed by hand in T11

**Dependencies:** T3, T4
**Files:** `sql/mart_fit.sql`, `sql/model.sql`, `src/marts.py`, `src/clean.py`, `data/seeds/fit_weights.csv`, `tests/test_fit.py`
**Scope:** M

---

### Task 7: Power BI Roster Fit page — ✅ **done 2026-09-28**

> Two pages in `valorant_recruitment.pbix`: **Roster Fit** (ranking of the 84 + SEN map pool) and **Candidate Fit** (drill-through on `dim_player[player_id]`). Model, measures and checks in `docs/dax_measures.md` § 7. Meiy and Jemkin reconcile against `mart_fit.csv`; Jerrwin self-check passes.

**Description:** Build a page with a candidate selector (SEN is the only team — T6 scope), a map-pool heatmap, an agent coverage matrix, opening-duel and consistency comparisons against the outgoing player, and a fit-score ranking.

**Acceptance criteria:**
- [x] Selecting a candidate updates every fit visual, and drill-through from the Scouting page opens a candidate's fit view — the candidate is selected by drilling through (from the Roster Fit ranking or the Scouting table); a separate slicer was dropped because it conflicts with the drill-through filter on the same column
- [x] Sample sizes appear alongside every map-level cell — heatmap carries ADR Maps and ADR Rounds, SEN games in every row, SEN rounds in the map-chart tooltip; ADR greys out under 3 maps

**Verification:**
- [x] Manual check: the fit scores for 2 candidates match `mart_fit.csv` — Meiy (94.9) and Jemkin (73.5), every card and Δ; Jerrwin self-check (61.7, all Δ = 0, ADR = baseline on every map)
- [x] Manual check: drill-through works in both directions — read as Scouting → Candidate Fit → Back and Roster Fit → Candidate Fit → Back. A drill-through *into* Scouting was not added: it would leave Scouting stuck on one player. Keep all filters is Off, so Scouting's map/event slicers do not carry over (tested with Breeze)
- [x] Non-duelist drilled from Scouting shows blank fit cards and the Fit Pool Note

**Dependencies:** T5, T6
**Files:** `valorant_recruitment.pbix`, `docs/dax_measures.md`
**Scope:** S

---

### Task 8: Budget model spec and reference calculation

**Description:** Define the financial logic before building it in Power BI.

**Inputs** (all assumptions):
- annual salary
- buyout fee
- contract years
- agent fee %
- current player's salary, or the replacement baseline
- expected revenue sources: prize-money uplift, sponsorship uplift, content/merch uplift
- discount rate (optional)

**Outputs:**
- total acquisition cost
- incremental cost versus the baseline
- break-even annual revenue
- payback period
- low, base and high scenarios

**Acceptance criteria:**
- [ ] `docs/budget_model.md` lists the formulas, input definitions and default values, with a source or "illustrative" label for each
- [ ] `src/budget.py` implements the formulas, and `tests/test_budget.py` covers ≥ 5 cases (including zero buyout, and revenue below cost)
- [ ] The Esports Earnings prize history for the shortlisted players (B1, game ID 646) is included as a reference only, and is labelled "not salary"
- [ ] Scenario ranges are anchored to sources: the minimum-salary floor (B3), the revenue-share total (B4), the partnership payment range (B5) and viewership (B6). The contract end year (B2) informs the buyout assumption.

**Verification:**
- [ ] `pytest tests/test_budget.py` passes
- [ ] Manual check: one case is also worked by hand in a spreadsheet and matches

**Dependencies:** T4 (shortlist)
**Files:** `docs/budget_model.md`, `src/budget.py`, `tests/test_budget.py`, `data/seeds/prize_reference.csv`
**Scope:** M

---

### Task 9: Power BI Budget Scenarios page

**Description:** Use what-if parameters for every T8 input, plus a scenario selector (low/base/high). Show KPI cards (total cost, incremental cost, break-even revenue, payback), a cost-vs-revenue waterfall and a sensitivity table comparing salary with revenue uplift.

**Acceptance criteria:**
- [ ] Every input can be edited and is labelled "Assumption"
- [ ] The selected candidate carries through from the other pages

**Verification:**
- [ ] Manual check: all T8 test cases, entered in Power BI, reproduce the pytest outputs exactly
- [ ] Manual check: the sensitivity table changes direction correctly (a higher salary means a higher break-even)

**Dependencies:** T5, T8
**Files:** `valorant_recruitment.pbix`, `docs/dax_measures.md`
**Scope:** M

## ✅ Checkpoint C — Analyst tool complete
- [ ] All 3 Power BI pages work, with cross-filtering and drill-through
- [ ] The budget page matches the reference calculations
- [ ] **Human review before continuing**

---

## Phase 3 — Storytelling and Delivery

### Task 10: Tableau Public story

**Description:** Connect Tableau to the same mart files and build a 4–6 point story. It should cover the role landscape, the top candidates, a deep dive on the shortlist and the map/agent fit for the target team, with parameter-driven filters.

**Acceptance criteria:**
- [ ] The story is published to Tableau Public, and the `.twbx` is saved in the repo
- [ ] Each story point has a one-sentence takeaway and shows sample sizes

**Verification:**
- [ ] Parity check: 5 headline numbers match between Tableau and Power BI
- [ ] Manual check: the story is readable at 1366×768 and in mobile layout

**Dependencies:** T5, T7
**Files:** `tableau/valorant_recruitment.twbx`
**Scope:** M

---

### Task 11: Shortlist and recommendation memo

**Description:** Write a 1–2 page memo for the GM. It gives the top 3 candidates, the evidence for each, the fit, the cost range in each scenario, a recommendation, risks and limitations.

**Acceptance criteria:**
- [ ] Every claim references a dashboard view or a mart figure
- [ ] It includes a limitations section covering sample size, data gaps, no teammate-effect evidence and assumption-driven finances

**Verification:**
- [ ] Manual check: every number in the memo is cross-checked against the dashboards

**Dependencies:** T9, T10
**Files:** `docs/recommendation_memo.md` (or `.pdf`)
**Scope:** S

---

### Task 12 (stretch): Map-win probability with uncertainty

**Description:** Fit a simple, interpretable model (for example logistic regression on team-level round-weighted KPIs per map) and estimate the change in win probability when the outgoing player's stats are swapped for a candidate's. Report bootstrap confidence intervals and state the causal limits clearly.

**Acceptance criteria:**
- [ ] Holdout performance (log loss and AUC) is reported and compared with a baseline (the team's historical map win rate)
- [ ] Every scenario output is a range, never a single number
- [ ] The results are added to the Roster Fit page as an optional visual, labelled "exploratory"

**Verification:**
- [ ] `notebooks/05_win_model.ipynb` runs end to end, and calibration is checked with a reliability plot

**Dependencies:** T6, T7
**Files:** `notebooks/05_win_model.ipynb`, `data/marts/mart_win_scenarios.csv`
**Scope:** M

---

### Task 13: README and portfolio packaging

**Description:** Write a README covering the question, the data sources (with licences and links), a pipeline diagram, how to reproduce the work, screenshots, key findings, limitations and next steps.

**Acceptance criteria:**
- [ ] Following the README from a fresh clone reproduces the marts (`pip install -r requirements.txt`, then `python -m src.pipeline`)
- [ ] Screenshots of all 3 Power BI pages and the Tableau Public link are included

**Verification:**
- [ ] Manual check: a fresh run in a new environment rebuilds the marts and the tests pass

**Dependencies:** T11
**Files:** `README.md`, `requirements.txt`, `docs/images/*`
**Scope:** S

## ✅ Checkpoint D — Complete
- [ ] All acceptance criteria are met
- [ ] Power BI and Tableau match on headline numbers
- [ ] **Final human review**
