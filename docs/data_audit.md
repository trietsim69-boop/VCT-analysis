# Data Audit — Task 2 findings

Snapshot: `data/raw/vct-fe27a11e.duckdb`, the VCT Reference build downloaded **2026-09-18**. The machine-generated schema profile (every table, column, null rate and distinct count) is in `docs/data_profile.md`.

> **Revised 2026-09-18 (v0.2).** The first pass counted *scheduled* Valorant Champions 2026 fixtures as delivered data. Every count below is now restricted to completed matches. See §0 and §6.

## Verdict: **GO** with the VCT Reference database

The data supports every KPI in `docs/kpi_dictionary.md` at the player × map grain. The 2026 window is usable **but stops before Champions 2026**, which had not been played at the snapshot date.

## 0. The mandatory filter: `matches.status = 'final'`

The snapshot contains rows for matches that have not happened yet. They are not partial data — they are placeholders with every stat column NULL — but they are **not excluded by `maps.performance_available`**, which is `TRUE` on all of them.

**Every query in this project must filter `matches.status = 'final'`.** Gating on `performance_available` alone is not sufficient.

| 2026 | Matches | Maps |
|---|---|---|
| In snapshot | 622 | 1,608 |
| **Completed (`status = 'final'`)** | **588** | **1,502** |
| Scheduled placeholders | 34 | 106 |

Without the filter, 80 players each gain **+3 phantom maps** in `maps_played`. That inflates the sample-size label CLAUDE.md requires on every visual, and it dilutes role share (the denominator grows with no role attributed), which can push a borderline player into "Flex". The eligible-pool count happens to survive at 84 either way, so a smoke test will not catch this.

## 1. Coverage

| Season | Matches (final) |
|---|---|
| 2021 | 446 |
| 2022 | 599 |
| 2023 | 331 |
| 2024 | 434 |
| 2025 | 498 |
| **2026** | **588** |

2026 covers Kickoff, Stage 1 and Stage 2 for all four leagues, plus **Masters Santiago** (59 maps) and **Masters London** (65 maps).

**Valorant Champions 2026 is not in the window.** Its 34 matches run **2026-09-24 → 2026-10-18**, after the snapshot date. All are `Upcoming`/`TBD`. Assumption **S-05 is revised**: the 2026 window is usable, but it is a *pre-Champions* window.

### Stat availability, 2026 completed maps

| Region | Maps | Performance stats | Economy stats |
|---|---|---|---|
| Americas | 332 | 100% | 100% |
| EMEA | 334 | 100% | 100% |
| Pacific | 340 | 99.4% | 99.4% |
| International | 124 | 100% | 100% |
| **China** | **372** | **0%** | **0%** |

**Consequence:** Chinese league players only have stats from international events. With Champions excluded, that means Masters Santiago and Masters London only — smaller samples than the first pass assumed, drawn from a tougher field. They must carry a warning flag in the candidate table, not be silently compared like-for-like.

## 2. The vacant slot is the **duelist** slot

SEN player-maps in 2026 (completed matches), by inferred role. SEN played no Champions fixtures, so these figures are unchanged by the §0 correction.

| Player | Duelist | Controller | Initiator | Sentinel | Active |
|---|---|---|---|---|---|
| Reduxx | 23 | 17 | — | — | Jan–Aug |
| cortezia | — | 21 | — | 19 | Jan–Aug |
| johnqt | 3 | 27 | 2 | 5 | Jan–Aug |
| JonahP | — | — | 32 | — | Apr–Aug |
| **Jerrwin** | **30** | — | — | — | **Apr–Aug** |
| N4RRATE | 7 | — | — | 1 | Jan–Feb |
| Kyu | — | — | 8 | — | Jan–Feb |
| Victor (stand-in) | 2 | — | — | — | Apr only |
| Marved (stand-in) | — | 3 | — | — | Jul only |

The turnover sits in one slot: **N4RRATE (Jan–Feb) → Victor as stand-in (Apr) → Jerrwin (Apr–Aug)**, all duelist. With Jerrwin reportedly exploring options, the vacancy for 2027 is the **duelist** slot. Assumption **S-03 is resolved: duelist.**

Three things to carry forward:

- **SEN are flex-heavy.** Reduxx splits duelist and controller, cortezia splits controller and sentinel, and johnqt plays four roles. The 60% primary-role rule (S-08) makes several SEN players "Flex", which is the correct result for them, and the T6 agent-overlap comparison should use the *slot's* agents (neon, waylay, raze), not a player's label.
- **Marved's 3 controller maps in July** covered johnqt or cortezia, not the duelist slot, so he isn't part of the slot baseline.
- **The contract database does not corroborate the vacancy.** Jerrwin's listed contract end is **2028** and his roster status is **Active** (§5). The premise rests on vlr.gg reporting alone. T11 must not state the vacancy as fact.

### Slot baseline for T6 and T8 — round-weighted

Σ numerator ÷ Σ rounds, per the KPI dictionary. These supersede the per-map averages in v0.1.

| Player | Maps | Rounds | ADR | KAST % | FK/100r | FD/100r | Opening-duel win % |
|---|---|---|---|---|---|---|---|
| **Jerrwin** | 30 | 658 | 127.0 | 65.8 | 19.15 | 17.93 | 51.6 |
| Reduxx | 23 | 520 | 135.2 | 69.5 | 14.23 | 13.27 | 51.7 |
| N4RRATE | 7 | 164 | 119.7 | 68.5 | 10.98 | 14.02 | 43.9 |
| johnqt | 3 | 65 | 163.7 | 76.6 | 4.62 | 3.08 | 60.0 |
| Victor | 2 | 43 | 121.2 | 55.6 | 23.26 | 20.93 | 52.6 |

Jerrwin is the incumbent baseline: high opening volume (19.15 FK/100r) at a near-break-even win rate (51.6%). That is the gap a signing has to beat. johnqt's 3 duelist maps are late-August emergency cover, shown for completeness only — the sample is far too small to use.

## 3. Candidate pool

With the 2026 completed-match window, ≥ 15 maps, and ≥ 60% of maps on duelist agents:

- **84 eligible duelists**, out of 289 players with ≥ 15 maps in 2026.
- At a ≥ 20-map bar the pool is **75**. (`tasks/plan.md` Checkpoint A still says ≥ 20; S-07 and the KPI dictionary say ≥ 15. Reconcile in T3.)

A sanity check of the top of the pool by ADR returns exactly the kind of names you'd expect from 2026 (marteen, primmie, splash, Meiy, ZmjjKK, Derke), which suggests the joins and the role mapping are sound.

## 4. KPI → column mapping

Base fact: `player_map` (73,356 rows all-time; **15,020 rows in the 2026 completed window**) joined to `matches` for date, event, region and **status**, and to `maps` for the availability flags. Grain is player × map, keyed by `player_id` + `game_id`.

Null rates are given **on the working slice** (2026, `status = 'final'`, `performance_available`). The whole-table rates in `docs/data_profile.md` are much higher because they span 2021–2026 and include the scheduled placeholders; they are not the rates this project faces.

| KPI | Column(s) | Null % (working slice) | Whole table | Note |
|---|---|---|---|---|
| ADR | `adr_all` (plus `_atk` / `_def`) | **0.0** | 5.2 | `SMALLINT` — see the rounding note below |
| Kills, deaths, assists | `kills_all`, `deaths_all`, `assists_all` | **0.0** | 0.3 | |
| KAST | `kast_all` | **0.0** | 11.1 | `TINYINT` percentage — needs round weighting |
| First kills / deaths | `fk_all`, `fd_all` | **0.0** | 4.9 / 5.0 | Also per-player in `kill_matrix` (`fk_kills`, `fk_deaths`) |
| ACS (display) | `acs_all` | **0.0** | 0.7 | |
| Rating (display) | `rating_all` | **0.0** | 11.7 | Third-party composite |
| Headshot % | `hs_pct_all` | **0.0** | 5.0 | |
| Multi-kills | `two_k` … `five_k` | 8.2 → 97.9 | 24.7 → 98.4 | Expected sparsity; keep as NULL |
| Clutches | `clutch_1v1` … `1v5` | 82.0 → 100 | 85.2 → 100 | **Only clutches won, with no attempts column.** See the decision below. |
| Operator kills | `kill_matrix.op_kills` | 0 | 0 | Useful colour for a duelist |
| Agent | `agents` (array) | **0.0** | 0.3 | Exactly one entry per row in the window — see below |
| Rounds | `rounds` table, per `game_id` | **0.0** | — | The denominator for every rate |
| Economy | `rounds.loadout_*`, `bank_*` | 0 outside China | 17.8 | Absent for all of China |

**Every core ranking metric is 100% populated on the working slice.** The gaps the v0.1 audit reported were the scheduled-fixture placeholders and older seasons.

### Decisions this forces

1. **Drop clutch success %** from the KPI dictionary. The database stores clutches won but not attempts, so a rate can't be computed. Clutches won per 100 rounds replaces it as display-only.
2. **Rounds come from the `rounds` table** (154,959 rows), counted per `game_id`, since `player_map` has no rounds column. On the working slice **1,128 of 1,128 maps have round rows (100%)**. Rounds per map: min 13, mean 21.2, max 38.
3. **`agents` is always a single-element array in this window** (15,020 rows, all length 1). T3 should read `agents[1]` directly. Do **not** `unnest()` — if the upstream ever records mid-map agent swaps, an unnest would silently double-count maps in the role-share denominator. Assert length = 1 in `tests/test_clean.py`.
4. **ADR and KAST are stored as integers** (`SMALLINT` / `TINYINT`), so raw damage is not available. Round-weighted ADR is reconstructed as Σ(`adr_all` × rounds) ÷ Σ rounds and carries up to ±0.5 damage per map of rounding. Same for KAST. Record this in the KPI dictionary rather than implying raw damage exists.
5. **Attack/defence splits are available** for ADR, ACS, KAST and first kills. That's a free extra for the Roster Fit page, but not part of v1 ranking.
6. **Consistency uses `adr_all` across 2025–26 maps**, as planned.

## 5. Contract database (S-10 resolved)

`data/raw/VALORANT Champions Tour Global Contract Database.xlsx`, Riot's published sheet, self-reported last update **2026-09-14**. Tabs: AMERICAS, CN, EMEA, PACIFIC. Header is on row 2. No salaries.

SEN's listed roster:

| Handle | Role | Contract end | Residency | Status |
|---|---|---|---|---|
| reduxx | Player | 2028 | Resident | Active |
| cortezia | Player | 2028 | Resident | Active |
| Jerrwin | Player | 2028 | Resident | Active |
| **johnqt** | Player | 2028 | **Non-Resident** | Active |
| JonahP | Player | 2028 | Resident | Active |
| Marved | Player | **2026** | Resident | Active |
| Ewok | Head coach | 2028 | Non-Resident | Staff |

**SEN's single import slot is already occupied by johnqt.** This is stronger than S-10 assumed. An import candidate cannot simply be "flagged" — signing one requires moving johnqt, which turns a one-slot decision into a two-slot decision. T6/T7 must present it that way, and T11 must state it as a hard constraint on D1.

Marved's 2026 expiry is the only near-term one on the roster.

## 6. Data-quality notes

Once `status = 'final'` is applied, **every anomaly reported in v0.1 disappears.** They were all the same 34 scheduled Champions fixtures:

| v0.1 claim | Actual |
|---|---|
| "240 rows have no agent" | The 240 placeholder rows for unplayed Champions matches. Every stat column is NULL, not just `agents`. On the working slice, 0 rows lack an agent. |
| "`maps.map_name` is null on 1.4% of maps" | 0.0% on completed matches. |
| "`matches.region` is NULL for 474 matches" | 440 on completed matches, all international events. Labelled "International", not treated as missing. |
| Missing `rounds` rows | 100% coverage on completed maps. |

Remaining, genuine:

- `matches.patch` is NULL on 18.1% of completed matches. Not needed for v1.
- 29 agents appear in 2026. Two (`veto`, a sentinel, and `miks`, a controller) are 2026 releases. All 29 are mapped in `data/seeds/agent_roles.csv` — **no unmapped agents**.
- `player_map` holds 1,226 distinct players all-time and 384 in the 2026 completed window; `teams` has 225.

## 7. Open items

- [ ] **Window decision (for the user).** Champions 2026 runs 2026-09-24 → 2026-10-18 and would be the biggest event of the ranking window. Either accept a pre-Champions 2026 window and state it on every page, or plan a re-snapshot after 2026-10-18. `CLAUDE.md` currently says never re-download mid-project, and `tasks/plan.md` has no risk row for this. **Blocks Checkpoint A.**
- [ ] **vlr.gg spot-check.** Reconcile totals for 2 completed matches against their vlr.gg match pages. This replaces the Kaggle A2 cross-check, which is now optional — vlr.gg is the actual upstream, so checking against it is the stronger test of the single-source risk.
- [ ] **Re-derive script.** The figures in this document came from ad-hoc queries. `src/audit.py` only writes the schema profile. T3 should add a script that regenerates §0–§5 so the numbers are reproducible from a fresh clone.
- [ ] **Raw filenames** do not match `data/raw/README.md` (`vct-fe27a11e.duckdb`, not `vct_2026-09-18.duckdb`; the contract sheet keeps its browser default name). The repro command in that README fails as written.

## Change log

| Date | Version | Change |
|---|---|---|
| 2026-09-18 | v0.1 | First pass |
| 2026-09-18 | v0.2 | Added the `status = 'final'` filter (§0) and restated every count. Champions 2026 found to be unplayed. Null rates restated on the working slice. Slot baseline made round-weighted. S-10 resolved from the contract database (§5). Data-quality notes corrected (§6). |
