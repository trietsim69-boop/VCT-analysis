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

#### T4.2 — `mart_scouting.csv` · M — the core ticket
One row per player, 2026 window. Rates are `SUM(stat × rounds) / SUM(rounds) FILTER (WHERE stat IS NOT NULL)` — the per-metric denominator rule (`data_audit.md` §4).
- [ ] Every KPI from dictionary section B, plus the display-only ones from section C
- [ ] Carries `maps_played`, `rounds_played`, a per-metric map count (`adr_maps`, `kast_maps`, …), `primary_role`, `is_eligible` (≥ 15 maps, counting all maps — S-07) and a `china_league` flag (S-12)
- [ ] No metric is an average of per-map rates
- [ ] Verify: hand-calculated weighted ADR for 1 player matches; a China player's ADR divides by fewer maps than `maps_played`

#### T4.3 — Consistency score · S
CV of per-map ADR. **Only 50 of the 84 eligible duelists have ≥ 5 maps in 2025**, so a 2025–26 score alone would be blank or noisy for the rest and would penalise newer players.
- [ ] `cv_adr_2026` is the primary; `cv_adr_2025_26` is a second column; `cv_maps` is reported alongside
- [ ] NULL when `cv_maps < 10` rather than publishing a CV from 4 maps
- [ ] Verify: the 34 duelists without 2025 history have a NULL combined CV and a non-NULL 2026 CV

#### T4.4 — Percentiles and composite · M
Percentiles within `primary_role`, over eligible players only, 0–100, inverted for DPR, FDPR and CV. Composite = weighted sum of percentiles using T4.1.
- [ ] Rating and ACS are **excluded** from the composite (S-09) — display only
- [ ] Verify: all percentiles fall in 0–100; ineligible players have NULL percentiles, never 0; the composite is unchanged when `rating_all` is scrambled
- [ ] Verify: a weight-sensitivity test — the composite under the seed weights correlates > 0.9 with flat equal weights. Guards against a silly edit, and is the evidence that shortlist membership does not hinge on the weighting (measured 0.978 at T4.1)
- [ ] Present the composite as a **band, not a position** (`kpi_dictionary.md` § Composite weights): rank order inside the shortlist moves by up to 14 places under different weights, so the page shows "top 10 of 84", never "8th best"

#### T4.5 — `mart_scouting_by_map.csv` · S
Player × `map_name`, same weighting and map counts. Feeds the T6 map-pool comparison.
- [ ] Verify: Σ rounds by map equals `rounds_played` in the main mart

#### T4.6 — `tests/test_marts.py` · S
- [ ] The checks above, plus: row count equals the eligible pool, no rate is computed on zero rounds, and NULL never becomes 0
- [ ] Manual check: the top 5 by composite look plausible against public rankings

**Not in T4:** the import and contract flag. `dim_player` has no link to the Global Contract Database, which is keyed by tournament handle and needs a fuzzy name match. It belongs to T6, where S-10 bites.

**Dependencies:** T3
**Files:** `sql/mart_scouting.sql`, `src/marts.py`, `data/seeds/metric_weights.csv`, `tests/test_marts.py`
**Scope:** M

---

### Task 5: Power BI Scouting page

**Description:** Import the marts and dimensions into Power BI, set up the star-schema relationships and a DAX measures table, and build the Scouting page. It needs a candidate table with sample sizes, a percentile radar or bar chart, a scatter plot (for example ADR vs FK−FD) and slicers for event, map and minimum maps.

**Acceptance criteria:**
- [ ] The model uses single-direction relationships from the dimensions to the fact table, and measures live in a dedicated table
- [ ] Every visual shows or tooltips the maps and rounds played, and ineligible players are visually flagged or filtered
- [ ] Blank values show as blank, not 0

**Verification:**
- [ ] Manual check: KPIs for 3 players in Power BI match `mart_scouting.csv` exactly
- [ ] Manual check: each slicer changes every visual as expected

**Dependencies:** T4
**Files:** `powerbi/valorant_recruitment.pbix`, `docs/dax_measures.md`
**Scope:** M

## ✅ Checkpoint B — First slice end to end
- [ ] Raw → processed → mart → Power BI runs cleanly
- [ ] All pytest data tests pass
- [ ] **Human review of the scouting page before continuing**

---

## Phase 2 — Roster Fit and Budget

### Task 6: Roster-fit mart

**Description:** For a selected target team, build its profile: map pool win rates, agent coverage and the metrics of the outgoing player in the vacant role. Then compare each eligible candidate's agent pool and map performance against the team's needs.

**Acceptance criteria:**
- [ ] `mart_team_profile.csv` holds team × map win rate and rounds, and `mart_fit.csv` holds candidate × team with agent-overlap %, map-pool overlap and KPI deltas against the outgoing player
- [ ] The fit-score formula is documented, and its weights can be changed in one config file

**Verification:**
- [ ] `pytest tests/test_fit.py` passes, including a toy example with a known overlap %
- [ ] Manual check: one team's map win rates match its published record

**Dependencies:** T3, T4
**Files:** `sql/mart_fit.sql`, `src/marts.py`, `config/fit_weights.yaml`, `tests/test_fit.py`
**Scope:** M

---

### Task 7: Power BI Roster Fit page

**Description:** Build a page with a team selector and a candidate selector, a map-pool heatmap, an agent coverage matrix, opening-duel and consistency comparisons against the outgoing player, and a fit-score ranking.

**Acceptance criteria:**
- [ ] Choosing a team updates the fit ranking, and drill-through from the Scouting page opens a candidate's fit view
- [ ] Sample sizes appear alongside every map-level cell

**Verification:**
- [ ] Manual check: the fit scores for 2 candidates match `mart_fit.csv`
- [ ] Manual check: drill-through works in both directions

**Dependencies:** T5, T6
**Files:** `powerbi/valorant_recruitment.pbix`
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
**Files:** `powerbi/valorant_recruitment.pbix`, `docs/dax_measures.md`
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
