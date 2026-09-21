# KPI Dictionary

v0.3, 2026-09-18. Columns confirmed against the 2026-09-18 snapshot. The full mapping and null rates are in `docs/data_audit.md` §4 — ranking metrics are complete outside China; China has gaps of up to ~20%, handled by per-metric denominators below.

**Base fact:** `player_map` joined to `matches` (date, event, region, status) and `maps` (availability flags), keyed by `player_id` + `game_id`. **Rounds come from the `rounds` table**, counted per `game_id`.

**Gates:** every query filters `matches.status = 'final'` — the snapshot holds placeholder rows for unplayed fixtures (`data_audit.md` §0). **Ranking KPIs are not gated on `maps.performance_available`**: that flag covers vlr.gg's Performance tab only (multi-kills, clutches, `kill_matrix`), so it gates the display-only metrics in section C and the op-kill colour, nothing else.

**Per-metric denominators:** each rate divides by the rounds of the maps where *that* metric is non-NULL. Chinese league maps are missing ADR on ~15% of rows; dividing by all rounds would understate them, which is the NULL-as-zero error in disguise. Every rate is shown with its own map count.

**Integer storage:** `adr_all` is `SMALLINT` and `kast_all` is `TINYINT`, so raw damage and raw KAST rounds are not available. Round-weighted values are reconstructed as Σ(metric × rounds) ÷ Σ rounds and carry up to ±0.5 per map of rounding. This is accurate enough for ranking, but the formulas below are reconstructions, not exact sums.

## Conventions

- **Grain:** the base fact is one row per **player × map × match** (`fact_player_map`).
- **Window:** the ranking uses **2026 only**, and consistency uses **2025–2026**. Every KPI is filtered to top-tier VCT.
- **Weighting:** per-round rates are always **Σ numerator ÷ Σ rounds** across maps. Never average per-map rates.
- **Eligibility:** a player is ranked only with **≥ 15 maps in 2026** (`is_eligible`). This counts **all maps played**, including maps whose stats are partly missing — a missing stat is a NULL to skip, not a reason to drop the map from the sample count. Each rate then reports its own map count (see per-metric denominators above).
- **Percentiles:** computed within the role pool of eligible players only (0–100, higher = better; for "lower is better" KPIs the percentile is inverted).
- **Missing values:** NULL stays NULL. In DAX, use `DIVIDE()` and averages that ignore blanks.
- **Role:** a player's `primary_role` is the role of the agents they played on ≥ 60% of their maps; otherwise it's "Flex".
- **Import status:** Global Contract Database residency → `is_import` (a flag, not a filter).

## A. Sample and eligibility

| KPI | Definition / formula | Grain | Use | Does NOT measure |
|---|---|---|---|---|
| `maps_played` | Count of distinct maps played | Player × window | Eligibility and trust label on every visual | Quality of opposition |
| `rounds_played` | Σ rounds on those maps | Player × window | Denominator for all per-round rates | — |
| `is_eligible` | `maps_played_2026 ≥ 15`, counting all maps played | Player | Filter for ranking and percentiles | Whether the player *could* be signed, or whether every one of those maps has a full stat line |

## B. Scouting: ranking KPIs (transparent)

| KPI | Formula | Direction | Source column | Does NOT measure |
|---|---|---|---|---|
| **ADR**: average damage per round | Σ(`adr_all` × rounds) ÷ Σ rounds | ↑ | `player_map.adr_all` (reconstructed — see above) | Whether the damage led to kills or round wins |
| **KPR**: kills per round | Σ kills ÷ Σ rounds | ↑ | `player_map` kills | Kill value or timing |
| **APR**: assists per round | Σ assists ÷ Σ rounds | ↑ | `player_map` assists | Quality of utility |
| **DPR**: deaths per round | Σ deaths ÷ Σ rounds | ↓ | `player_map` deaths | Whether a death was a useful trade |
| **KAST %** | Rounds with a Kill, Assist, Survival or being Traded ÷ rounds (round-weighted from per-map KAST) | ↑ | `player_map` KAST | Communication or teamwork. It's a per-round involvement flag only. |
| **FKPR**: first kills per round | Σ first kills ÷ Σ rounds | ↑ (role-dependent) | `player_map` / `kill_matrix` opening kills | Whether the entry was part of a planned play |
| **FDPR**: first deaths per round | Σ first deaths ÷ Σ rounds | ↓ (role-dependent) | same | — |
| **Opening duel win %** | FK ÷ (FK + FD) | ↑ | derived | How many opening duels the player *should* take |
| **FK–FD per round** | (FK − FD) ÷ Σ rounds | ↑ | derived | — |
| **Consistency (ADR CV)** | Standard deviation of per-map ADR ÷ mean per-map ADR, across 2025–2026 maps | ↓ | derived | Consistency over time *within* a map |

### Composite weights (T4.1, set 2026-09-21)

The ranking is a **role-weighted composite of percentiles**. Weights live in `data/seeds/metric_weights.csv` — data, not code — and each role's weights sum to 1.

| Metric | duelist | initiator | controller | sentinel | Flex |
|---|---|---|---|---|---|
| `adr` | 0.25 | 0.20 | 0.15 | 0.20 | 0.20 |
| `apr` | — | 0.20 | 0.25 | 0.15 | 0.15 |
| `kast_pct` | 0.15 | 0.25 | 0.30 | 0.25 | 0.20 |
| `fkpr` | 0.20 | — | — | — | 0.10 |
| `opening_win_pct` | 0.20 | 0.10 | — | — | 0.10 |
| `dpr` ↓ | 0.10 | 0.10 | 0.15 | 0.20 | 0.15 |
| `cv_adr` ↓ | 0.10 | 0.15 | 0.15 | 0.20 | 0.10 |

↓ = lower is better; the percentile is inverted in T4.4. Direction lives in the mart SQL, not the seed, so it is defined once.

**Only 6–7 of the section B metrics are weighted, not all 10.** Measured over the 2026 pool (≥ 15 maps, n = 289):
**Only 6–7 of the section B metrics are weighted, not all 10.** Measured over the 2026 pool (≥ 15 maps):

- **KPR and ACS are dropped.** They correlate with ADR at **0.95** and **0.97** — weighting all three is one metric counted three times. ADR is the transparent one, so it carries the output signal alone. (ACS is display-only anyway, S-09.)

  ![ADR against KPR and ACS, 2026 pool](metric_correlations.png)

  *Each dot is one player with ≥ 15 maps in 2026, n = 289.*
- **FKPR and opening-duel win % are both kept**: they correlate at only **0.41**, so entry *volume* and entry *success* are genuinely different things. That distinction is the whole question for the vacant duelist slot — Jerrwin's baseline is high volume at a near-break-even win rate (`data_audit.md` §2).
- **KAST and DPR are near-independent of ADR** (0.17 and 0.20), so they add real information about staying alive and being useful in rounds without fragging.
- **FK−FD per round is dropped** as a third view of the same duel data.
- APR is weighted for the support roles only; for a duelist it mostly measures the team's utility, not the player's.

**The weight values themselves are a judgement call, not a measurement.** The correlations above justify *which* metrics are weighted; they say nothing about why duelist ADR is 0.25 rather than 0.20. The stated rationale is only this: for the vacant duelist slot, entry play (FKPR + opening-win, 0.40 combined) is the thing SEN needs and is weighted above raw output (ADR, 0.25); support roles shift that weight onto KAST and APR.

**Sensitivity check (2026 duelist pool, n = 84).** The composite was recomputed under three weightings — the table above, flat equal weights, and a deliberately lopsided one putting 0.50 on ADR:

| | Correlation of composite scores |
|---|---|
| Table above vs equal weights | **0.978** |
| Table above vs ADR-heavy | **0.969** |
| Equal weights vs ADR-heavy | 0.932 |

Top-10 overlap: 8/10 and 7/10 respectively, with the same player first under all three.

**What this means, and the limit on how the ranking may be read:**

- **Shortlist membership is robust.** Who reaches the top of the pool is driven by the percentiles, not by the weighting. A reader who disagrees with every weight in the table still gets substantially the same candidates.
- **Rank order within the shortlist is not.** Jemkin ranks 8th under these weights and 22nd under the ADR-heavy set; splash moves between 6th and 15th. So the composite must be presented as a **band, not a position** — "top 10 of 84", never "the 8th best duelist". T4.4 and T11 both depend on this.

## C. Scouting: display-only KPIs

| KPI | Formula | Why display-only |
|---|---|---|
| **Rating** (third-party) | As provided by the source | A proprietary composite that we can't break down, so it's shown for recognition only |
| **ACS**: average combat score | Round-weighted ACS | Overlaps with ADR and KPR, and Riot's scoring formula isn't under our control |
| **HS %** | Headshot hits ÷ total hits | A mechanics indicator with a weak link to winning rounds |
| **Clutches won per 100 rounds** | (`clutch_1v1` + … + `clutch_1v5`) ÷ rounds × 100 | The database stores clutches won but no attempts, so a success *rate* can't be computed. Always shown with the raw count. |

## D. Roster fit

| KPI | Formula | Grain | Does NOT measure |
|---|---|---|---|
| **Role share %** | Maps on agents of role R ÷ maps played | Player | Proficiency on each agent |
| **Agent pool size** | Distinct agents with ≥ 3 maps in the window | Player | Whether the player could learn a new agent |
| **Agent overlap %** | The share of SEN's needed agents for the vacant slot (the agents that slot played in 2026) that the candidate has played ≥ 3 maps on | Candidate × SEN | Performance on those agents (see the next row) |
| **Map-pool ADR delta** | Candidate's ADR on map M − role-pool average ADR on map M | Candidate × map | Team context on that map |
| **SEN map win %** | SEN maps won ÷ maps played, per map (2026) | Team × map | Why SEN won or lost those maps |
| **KPI delta vs slot baseline** | Candidate KPI − the 2026 KPI of the players who filled the vacant slot (Jerrwin + stand-ins, round-weighted) | Candidate | The expected change in results. That needs the stretch model and its ranges. |
| **Fit score** | Weighted mix of agent overlap %, map-pool ADR delta and the KPI delta. Weights live in `config/fit_weights.yaml`. | Candidate × SEN | Chemistry, language or communication |
| **Import flag** | `is_import` from the Global Contract Database | Candidate | Eligibility beyond the one-import rule |

## E. Budget scenarios (all inputs are assumptions)

Input values are in `assumptions_log.md`. Money is in USD; `Y` = contract years.

| KPI | Formula |
|---|---|
| **Total acquisition cost (TAC)** | Buyout + (Salary × Y) + AgentFee% × (Salary × Y) |
| **Baseline cost** | StandInSalary × Y |
| **Incremental cost** | TAC − Baseline cost |
| **Expected annual revenue uplift** | PartnerStatus × ΔPartnershipPerformancePayment + ΔPrizeMoney + SponsorshipContentUplift |
| **Break-even annual uplift** | Incremental cost ÷ Y |
| **Payback (years)** | Incremental cost ÷ Expected annual revenue uplift (blank if the uplift is ≤ 0) |
| **Max justifiable spend (D2)** | Baseline cost + (Expected annual revenue uplift × Y), discounted at rate *r* when *r* > 0 |
| **Sign-or-stay signal (D3)** | "Sign" if Expected annual uplift ≥ Break-even annual uplift in the **base** scenario; the result is also shown for low and high |

**Does NOT measure:** actual salaries, actual buyouts or the real value of the organisation. Every output depends on the assumptions and is labelled that way.

## Closed in Task 2 (2026-09-18)

- [x] Columns mapped: `adr_all`, `kast_all`, `fk_all`, `fd_all`, `acs_all`, `rating_all`, `hs_pct_all`, `agents`.
- [x] Clutch attempts don't exist → clutch success % replaced by clutches won per 100 rounds.
- [x] First kills and deaths sit in `player_map` (`fk_all`, `fd_all`) and per-opponent in `kill_matrix`.
- [x] Agent → role seed written to `data/seeds/agent_roles.csv` (29 agents, including the 2026 releases veto and miks).
- [x] Attack/defence splits exist for ADR, ACS, KAST and first kills. Kept out of v1 ranking, available for Roster Fit.
