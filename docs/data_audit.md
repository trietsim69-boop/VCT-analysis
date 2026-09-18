# Data Audit — Task 2 findings

Snapshot: `data/raw/vct-fe27a11e.duckdb`, the VCT Reference build downloaded **2026-09-18**. The machine-generated schema profile (every table, column, null rate and distinct count) is in `docs/data_profile.md`.

## Verdict: **GO** with the VCT Reference database

The data supports every KPI in `docs/kpi_dictionary.md` at the player × map grain, and 2026 is fully covered.

## 1. Coverage

| Season | Matches |
|---|---|
| 2021 | 446 |
| 2022 | 599 |
| 2023 | 331 |
| 2024 | 434 |
| 2025 | 498 |
| **2026** | **622** |

2026 includes every stage of all four leagues (Kickoff, Stage 1, Stage 2), Masters Santiago, Masters London and **Valorant Champions 2026**. Assumption **S-05 is confirmed**: the 2026 window is usable.

### Stat availability, 2026 maps

| Region | Maps | Performance stats | Economy stats |
|---|---|---|---|
| Americas | 332 | 100% | 100% |
| EMEA | 334 | 100% | 100% |
| Pacific | 340 | 99.4% | 99.4% |
| International | 230 | 100% | 100% |
| **China** | **372** | **0%** | **0%** |

**Consequence:** Chinese league players only have stats from international events, so their samples are much smaller and are drawn from a tougher field. They must carry a warning flag in the candidate table, not be silently compared like-for-like. All queries gate on `maps.performance_available`.

## 2. The vacant slot is the **duelist** slot

SEN player-maps in 2026, by inferred role:

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

Two things to carry forward:

- **SEN are flex-heavy.** Reduxx splits duelist and controller, cortezia splits controller and sentinel, and johnqt plays four roles. The 60% primary-role rule (S-08) makes several SEN players "Flex", which is the correct result for them, and the T6 agent-overlap comparison should use the *slot's* agents (neon, waylay, raze), not a player's label.
- **Marved's 3 controller maps in July** covered johnqt or cortezia, not the duelist slot, so he isn't part of the slot baseline.

### Slot baseline for T6 and T8 (simple per-map averages, to be recomputed round-weighted in T4)

| Player | Duelist maps | ADR | KAST % | FK/map | FD/map |
|---|---|---|---|---|---|
| Jerrwin | 30 | 125.8 | 65.7 | 4.20 | 3.93 |
| Reduxx | 23 | 133.6 | 69.3 | 3.22 | 3.00 |
| N4RRATE | 7 | 119.9 | 68.6 | 2.57 | 3.29 |
| Victor | 2 | 121.0 | 55.5 | 5.00 | 4.50 |

Jerrwin's opening-duel balance is near break-even (FK 4.20 vs FD 3.93) on high volume. That's the gap a signing has to beat.

## 3. Candidate pool

With the 2026 window, ≥ 15 maps, and ≥ 60% of maps on duelist agents:

- **84 eligible duelists** (out of 289 players with ≥ 15 maps in 2026).

A sanity check of the top of the pool by ADR returns exactly the kind of names you'd expect from 2026 (marteen, primmie, splash, Meiy, ZmjjKK, Derke), which suggests the joins and the role mapping are sound.

## 4. KPI → column mapping (replaces the "TBC" entries)

Base fact: `player_map` (73,356 rows) joined to `matches` for the date, event and region, and to `maps` for the availability flags. Grain is player × map, keyed by `player_id` + `game_id`.

| KPI | Column(s) | Null % | Note |
|---|---|---|---|
| ADR | `adr_all` (plus `_atk` / `_def`) | 5.2 | Attack and defence splits come free |
| Kills, deaths, assists | `kills_all`, `deaths_all`, `assists_all` | 0.3 | |
| KAST | `kast_all` | 11.1 | Stored as a per-map percentage, so it needs round weighting |
| First kills / deaths | `fk_all`, `fd_all` | 4.9 / 5.0 | Also per-player in `kill_matrix` (`fk_kills`, `fk_deaths`) |
| ACS (display) | `acs_all` | 0.7 | |
| Rating (display) | `rating_all` | 11.7 | Third-party composite |
| Headshot % | `hs_pct_all` | 5.0 | |
| Multi-kills | `two_k` … `five_k` | 24.7 → 98.4 | High nulls are the expected sparsity; keep as NULL |
| Clutches | `clutch_1v1` … `1v5` | 85.2 → 100 | **Only clutches won, with no attempts column.** See the decision below. |
| Operator kills | `kill_matrix.op_kills` | 0 | Useful colour for a duelist |
| Agent | `agents` (array, one entry per map) | 0.3 | 240 rows have no agent and are excluded from role counts |
| Rounds | `rounds` table, per `game_id` | — | The denominator for every rate |
| Economy | `rounds.loadout_*`, `bank_*` | 17.8 | Absent for all of China |

### Decisions this forces

1. **Drop clutch success %** from the KPI dictionary. The database stores clutches won but not attempts, so a rate can't be computed. Clutches won per 100 rounds replaces it as display-only.
2. **Rounds come from the `rounds` table** (154,959 rows), counted per `game_id`, since `player_map` has no rounds column.
3. **Attack/defence splits are available** for ADR, ACS, KAST and first kills. That's a free extra for the Roster Fit page, but not part of v1 ranking.
4. **Consistency uses `adr_all` across 2025–26 maps**, as planned, since ADR has the lowest null rate of the ranking metrics.

## 5. Data-quality notes

- `matches.region` is NULL for 474 matches. These are the international events, and are labelled "International" rather than treated as missing.
- `maps.map_name` is null on 1.4% of maps, and `matches.patch` on 19.1%. Neither is needed for v1.
- 29 agents appear in 2026. Two (`veto`, a sentinel, and `miks`, a controller) are 2026 releases and are now in `data/seeds/agent_roles.csv`.
- `player_map` has 1,226 distinct players; `teams` has 225.

## 6. Open items

- [ ] The Kaggle 2025 cross-check is now **optional**. The single-source risk is covered better by spot-checking a few matches against vlr.gg, which is the actual upstream, so T2 closes with a vlr.gg spot-check instead.
- [ ] Load the Global Contract Database workbook (downloaded, `VALORANT Champions Tour Global Contract Database.xlsx`) and attach contract end year and import status to the candidate pool.
