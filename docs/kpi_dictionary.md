# KPI Dictionary

Draft v0.1, 2026-09-17. Source column names are marked **TBC**: Task 2 maps each KPI to the actual VCT Reference columns (`player_map`, `maps`, `kill_matrix`).

## Conventions

- **Grain:** the base fact is one row per **player × map × match** (`fact_player_map`).
- **Window:** the ranking uses **2026 only**, and consistency uses **2025–2026**. Every KPI is filtered to top-tier VCT.
- **Weighting:** per-round rates are always **Σ numerator ÷ Σ rounds** across maps. Never average per-map rates.
- **Eligibility:** a player is ranked only with **≥ 15 maps in 2026** (`is_eligible`).
- **Percentiles:** computed within the role pool of eligible players only (0–100, higher = better; for "lower is better" KPIs the percentile is inverted).
- **Missing values:** NULL stays NULL. In DAX, use `DIVIDE()` and averages that ignore blanks.
- **Role:** a player's `primary_role` is the role of the agents they played on ≥ 60% of their maps; otherwise it's "Flex".
- **Import status:** Global Contract Database residency → `is_import` (a flag, not a filter).

## A. Sample and eligibility

| KPI | Definition / formula | Grain | Use | Does NOT measure |
|---|---|---|---|---|
| `maps_played` | Count of distinct maps played | Player × window | Eligibility and trust label on every visual | Quality of opposition |
| `rounds_played` | Σ rounds on those maps | Player × window | Denominator for all per-round rates | — |
| `is_eligible` | `maps_played_2026 ≥ 15` | Player | Filter for ranking and percentiles | Whether the player *could* be signed |

## B. Scouting: ranking KPIs (transparent)

| KPI | Formula | Direction | Source (TBC) | Does NOT measure |
|---|---|---|---|---|
| **ADR**: average damage per round | Σ damage ÷ Σ rounds | ↑ | `player_map` damage (or ADR × rounds) | Whether the damage led to kills or round wins |
| **KPR**: kills per round | Σ kills ÷ Σ rounds | ↑ | `player_map` kills | Kill value or timing |
| **APR**: assists per round | Σ assists ÷ Σ rounds | ↑ | `player_map` assists | Quality of utility |
| **DPR**: deaths per round | Σ deaths ÷ Σ rounds | ↓ | `player_map` deaths | Whether a death was a useful trade |
| **KAST %** | Rounds with a Kill, Assist, Survival or being Traded ÷ rounds (round-weighted from per-map KAST) | ↑ | `player_map` KAST | Communication or teamwork. It's a per-round involvement flag only. |
| **FKPR**: first kills per round | Σ first kills ÷ Σ rounds | ↑ (role-dependent) | `player_map` / `kill_matrix` opening kills | Whether the entry was part of a planned play |
| **FDPR**: first deaths per round | Σ first deaths ÷ Σ rounds | ↓ (role-dependent) | same | — |
| **Opening duel win %** | FK ÷ (FK + FD) | ↑ | derived | How many opening duels the player *should* take |
| **FK–FD per round** | (FK − FD) ÷ Σ rounds | ↑ | derived | — |
| **Consistency (ADR CV)** | Standard deviation of per-map ADR ÷ mean per-map ADR, across 2025–2026 maps | ↓ | derived | Consistency over time *within* a map |

The ranking combines these KPIs as a **role-weighted composite of percentiles**. The weights live in the config and are set in T4, with defaults written down there. For example, a duelist weights FKPR and opening duel % more heavily, and a controller weights KAST and APR more heavily.

## C. Scouting: display-only KPIs

| KPI | Formula | Why display-only |
|---|---|---|
| **Rating** (third-party) | As provided by the source | A proprietary composite that we can't break down, so it's shown for recognition only |
| **ACS**: average combat score | Round-weighted ACS | Overlaps with ADR and KPR, and Riot's scoring formula isn't under our control |
| **HS %** | Headshot hits ÷ total hits | A mechanics indicator with a weak link to winning rounds |
| **Clutch success %** | Clutches won ÷ clutch attempts (if attempts are available, TBC) | Samples are tiny, so it always shows the count next to the % |

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

## Open items for Task 2

- [ ] Map each "TBC" source to real column names.
- [ ] Confirm whether clutch *attempts* exist; drop Clutch % if they don't.
- [ ] Confirm how first kills and first deaths are stored (in `player_map` or derived from `kill_matrix`).
- [ ] Record the agent → role seed list (the current agent roster at the time of the Task 2 snapshot).
