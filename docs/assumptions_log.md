# Assumptions Log

Draft v0.1, 2026-09-17. Every number the dashboards use that isn't measured data lives here.

- **Status:** `decided` (agreed in scoping) · `sourced` (backed by a public source) · `illustrative` (a placeholder with no public source) · `to verify` (checked in the named task).
- **Rule:** any value marked `illustrative` must appear on the dashboard with an **"Assumption"** label.

## A. Scope and method

| ID | Assumption | Value | Status | Source / rationale | Used in |
|---|---|---|---|---|---|
| S-01 | Case study team | Sentinels (VCT Americas), hypothetical GM view | decided | Scoping round 1 | All |
| S-02 | Vacant slot | The slot covered by stand-ins in 2026 (Jerrwin → Victor → Marved) | decided / to verify (T2) | [vlr.gg news](https://www.vlr.gg/team/news/2/sentinels/) | T4–T9 |
| S-03 | Role of the vacant slot | **Duelist** | ✅ resolved (T2, 2026-09-18) | The slot ran N4RRATE → Victor → Jerrwin, all on duelist agents (neon, waylay, raze) | T4, T6 |
| S-04 | Scouting window | 2026 season (main); 2025 used for consistency only | decided | Recruiting for 2027 | T3–T5 |
| S-05 | 2026 data coverage in VCT Reference | **588 completed matches** — all four leagues (Kickoff, Stage 1, Stage 2) plus Masters Santiago and Masters London. **Champions 2026 is excluded**: its 34 fixtures run 2026-09-24 → 2026-10-18, after the snapshot. The window is *pre-Champions*. | ⚠️ revised (T2, 2026-09-18) | Snapshot `vct_2026-09-18.duckdb`; see `data_audit.md` §0–§1. Every query must filter `matches.status = 'final'` — `performance_available` is TRUE on unplayed fixtures. | T2 go/no-go, T3–T5 |
| S-06 | Candidate pool | Top-tier VCT only; Challengers in phase 2 | decided | Scoping round 1 | T4 |
| S-07 | Minimum sample | **≥ 15 maps in 2026**, counting all maps played. Maps with a partly missing stat line still count towards the sample; the missing values stay NULL and each rate is weighted over the maps that have that metric. | ✅ decided (2026-09-21) | A second "stat-bearing maps" threshold would drop only Youze, at the cost of a rule that contradicts the project's NULL handling. `tasks/plan.md` corrected from ≥ 20 to match. | T4 |
| S-08 | Primary role rule | ≥ 60% of maps on one role, otherwise "Flex" | decided | Transparent and adjustable | T3 |
| S-09 | Rating usage | Shown for recognition, excluded from ranking | decided | Proprietary composite | T4, T5 |
| S-10 | Import handling | **SEN's one import slot is already occupied by johnqt** (Non-Resident, contract to 2028). Import candidates are still flagged rather than filtered, but signing one requires moving johnqt — a two-slot decision, not one. | ✅ resolved (T2, 2026-09-18) | Global Contract Database, AMERICAS tab, updated 2026-09-14; see `data_audit.md` §5. Import rule per [Dexerto](https://www.dexerto.com/esports/vct-2023-roster-regulations-explained-minimum-salaries-import-rules-roster-sizes-1944581/) | T6, T7, T11 |
| S-11 | Roster facts snapshot | Facts frozen at the T2 snapshot date and shown on every page | decided | The roster may change | All |
| S-12 | Chinese league players | China league maps **have** the ranking stats (K/D/A, ACS, ADR, KAST, FK/FD, rating) but with gaps — ADR is NULL on 14.8% of rows, rating on 19.6%, mostly in Kickoff and Stage 2. They have **no** Performance or Economy tab (multi-kills, clutches, `kill_matrix`, loadouts). Chinese players are ranked on the core KPIs with per-metric map counts shown. | ⚠️ revised (T2 v0.3, 2026-09-18) | `data_audit.md` §1, §4; confirmed against vlr.gg (§8) | T4, T5 |
| S-13 | Eligible duelist pool | **84 players** meet ≥ 15 maps in 2026 and ≥ 60% duelist maps | ✅ measured (T2) | Snapshot query | T4 |
| S-14 | Champions 2026 handling | **Open until 2026-10-18.** Approach decided: continue on the pre-Champions snapshot, then take a second dated snapshot after Champions ends and rerun the pipeline with the added data. Does not block Checkpoint A. | approach decided (2026-09-21), execution pending | Champions runs 2026-09-24 → 2026-10-18. `sql/audit.sql` + `python -m src.export` regenerate every figure, so the refresh is a rerun. Recorded in `tasks/plan.md` as the one planned exception to "never re-download mid-project". | All |
| S-15 | Vacancy premise | The contract database lists **Jerrwin as Active with a contract to 2028**, so it does not corroborate the vacancy. The premise rests on vlr.gg reporting alone. | ⚠️ unverified | Global Contract Database vs [vlr.gg](https://www.vlr.gg/team/2/sentinels). The project is framed as a hypothetical GM exercise, so this is a framing caveat, not a blocker. | T11 |
| S-16 | Performance baseline for the slot | **Jerrwin** (30 maps, 2026). Every T6 KPI delta is candidate − Jerrwin. A replacement-level line (duelist pool 25th percentile) is a display reference only, computed in the BI tools. | decided (2026-09-26) | Victor (2 maps) and johnqt (3) are too thin to count; pooling the slot mostly dilutes Jerrwin. | T6, T7, T8 |
| S-17 | The slot's agents | Jerrwin's 2026 agents on SEN, map-weighted: neon 18, waylay 9, raze 3 | decided (2026-09-26) | Follows S-16. N4RRATE and Victor used the same three agents. | T6 |
| S-18 | Fit-score weights | performance 0.50 · agent overlap 0.25 · map fit 0.25 (`data/seeds/fit_weights.csv`) | decided — a judgement call | Top 10 is 9/10 the same under equal weights, but only 5/10 under a performance-heavy 0.70 / 0.15 / 0.15. Meiy is first under all three. The fit score is shown as a band, like the composite. | T6, T7 |
| S-19 | Import status for SEN | Riot's contract database (Americas tab) where the player is listed — 13 of 84; otherwise **nationality as a proxy** (Americas countries = resident) | to verify for the shortlist (T11) | Nationality is not residency: Jerrwin (Indian) and jawgemo (Cambodian) are Americas Residents per Riot. A long-term Americas resident playing abroad would be misflagged. `import_source` in `mart_fit.csv` says which rule applied. | T6, T7, T11 |

## B. Financial inputs (USD)

The Low / Base / High columns feed the scenario selector in T9.

| ID | Input | Low | Base | High | Status | Source / note |
|---|---|---|---|---|---|---|
| F-01 | Stand-in (baseline) salary per year | 50,000 | 50,000 | 50,000 | sourced (2023) / to verify | Riot's 2023 Americas minimum ([Dexerto](https://www.dexerto.com/esports/vct-2023-roster-regulations-explained-minimum-salaries-import-rules-roster-sizes-1944581/)). It may be outdated for 2027. |
| F-02 | Candidate salary per year | 150,000 | 300,000 | 500,000 | **illustrative** | No public salary data. To be refined in T8. |
| F-03 | Buyout fee (one-off) | 0 | 250,000 | 750,000 | **illustrative** | "Low = 0" represents a free agent or an expiring contract. The Global Contract Database end year informs which case applies. |
| F-04 | Contract length (years) | 1 | 2 | 3 | decided (base) | Base 2 matches the 2027–28 partnership cycle ([THESPIKE](https://www.thespike.gg/valorant/news/partnered-vct-2027-teams-to-receive-up-to-5-million-per-year-under-new-format/7963)) |
| F-05 | Agent fee (% of total salary) | 0% | 5% | 10% | **illustrative** | Industry-typical range, not sourced |
| F-06 | 2027 partner status | Not partner | Partner | Partner | decided (toggle) | Partners are selected after Champions 2026 |
| F-07 | Annual partnership payment range | 600,000 | — | 5,000,000 | sourced | [THESPIKE](https://www.thespike.gg/valorant/news/partnered-vct-2027-teams-to-receive-up-to-5-million-per-year-under-new-format/7963): made up of base + performance bonus + capsules |
| F-08 | Δ partnership payment from better results | 0 | 250,000 | 750,000 | **illustrative** | The split between the base and performance components isn't published, so this is a placeholder within the F-07 range |
| F-09 | Δ prize money per year | 0 | TBD | TBD | to source (T8) | From Esports Earnings (game 646): the typical prize gap between SEN's 2026 placement and a target placement |
| F-10 | Sponsorship and content uplift per year | 0 | 100,000 | 300,000 | **illustrative** | Viewership context from [Esports Charts](https://escharts.com/news/vct-2025-stage-1-global-viewership). No public sponsorship figures exist. |
| F-11 | Discount rate | 0% | 0% | 8% | **illustrative** | 0% keeps the base case simple; the high case shows sensitivity |
| F-12 | Currency | USD | USD | USD | decided | EUR and KRW minimums are not used |

## C. Context figures (not model inputs)

| ID | Fact | Value | Source |
|---|---|---|---|
| C-01 | VCT 2025 total revenue share to partner teams | $105.2M, of which $86M came from digital goods; no per-team split | [Hotspawn](https://www.hotspawn.com/valorant/news/vct-2025-100m-rev-share) (Riot, 2025-12-16) |
| C-02 | SEN 2026 results | 9th–10th at Kickoff and Stage 1; out in the Stage 2 play-ins; ~10th in North America | [vlr.gg](https://www.vlr.gg/team/2/sentinels) |
| C-03 | SEN total career winnings | $1,197,000 (vlr.gg figure) | [vlr.gg](https://www.vlr.gg/team/2/sentinels) |

## D. Explicitly *not* assumed

- **Performance → placement link:** no causal link is modelled in v1. The revenue uplift is a scenario input, not a prediction. The optional T12 model reports ranges only.
- **Fit → results link:** chemistry or communication effects from roster fit aren't assumed.
- **Accuracy of vlr.gg's "Rating":** not assumed to be accurate.

## Change log

| Date | Change |
|---|---|
| 2026-09-17 | v0.1 created from scoping rounds 1–2 |
| 2026-09-18 | S-03, S-05, S-12, S-13 updated from T2. |
| 2026-09-21 | S-07 settled (eligibility counts all maps played); S-14 approach decided (re-snapshot after 2026-10-18 and rerun). |
| 2026-09-18 | v0.3: S-12 revised — China is not stat-less; `performance_available` only flags vlr.gg's Performance tab. |
| 2026-09-26 | S-16 to S-19 added from T6 (baseline, slot agents, fit weights, import rule). |
| 2026-09-18 | v0.2 after the T2 audit correction: S-05 revised (Champions 2026 is unplayed; 588 completed matches, not 622). S-10 resolved — the import slot is taken. S-14 (Champions window decision) and S-15 (vacancy premise unverified) added. |
