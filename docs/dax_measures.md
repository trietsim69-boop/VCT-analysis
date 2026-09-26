# DAX Measures — Power BI Scouting Model

Task 5 deliverable. Companion to `sql/mart_scouting.sql`, which this model must agree with.

File: `valorant_recruitment.pbix` (repo root). Pages: **Scouting**, **QA**.

---

## 1. Model structure

Import mode. Seven tables.

| Table | Source | Grain | Rows |
|---|---|---|---|
| `fact_player_map` | `data/processed/fact_player_map.csv` | player × map × match, all seasons | 73,116 |
| `dim_player` | `data/processed/dim_player.csv` | player | — |
| `dim_team` | `data/processed/dim_team.csv` | team | — |
| `dim_event` | `data/processed/dim_event.csv` | event | 112 |
| `dim_map` | `data/processed/dim_map.csv` | map | — |
| `dim_agent` | `data/processed/dim_agent.csv` | agent | — |
| `mart_scouting` | `data/marts/mart_scouting.csv` | player (2026) | 384 |
| `mart_percentiles` | reference of `mart_scouting`, unpivoted | player × metric | ~2,000 |
| `_Measures` | empty table (`Enter data`) | — | measures only |

`mart_scouting_by_map.csv` is deliberately **not** imported. With the fact table in the model, map-level rates come from DAX under the map slicer. That mart belongs to T6.

### Relationships

All **single direction**, dimension → fact. Nothing filters back up.

```
dim_player[player_id]   → fact_player_map[player_id]    1:*  single
dim_event[event_id]     → fact_player_map[event_id]     1:*  single
dim_team[team_id]       → fact_player_map[team_id]      1:*  single
dim_map[map_name]       → fact_player_map[map_name]     1:*  single
dim_agent[agent]        → fact_player_map[agent]        1:*  single
dim_player[player_id]   → mart_percentiles[player_id]   1:*  single
dim_player[player_id]   → mart_scouting[player_id]      1:1  (both — forced by Power BI)
```

**`fact_player_map[opponent_id]` has no relationship.** Autodetect creates a second inactive
link from `dim_team`; it is deleted. T6 will need a role-playing dimension or `USERELATIONSHIP`.

**Autodetect is turned off** (Options → Current File → Data Load). It twice produced wrong
relationships during the T5 build, including putting `mart_percentiles` on the one side.

### Why single direction matters here

The composite and the percentiles were computed once, in SQL, over the eligible pool across
the whole 2026 season. They are not meaningful re-scoped to one tournament.

Because every dim→fact relationship is single-direction, an event or map slicer filters
`fact_player_map` but cannot propagate back through `dim_player` to `mart_scouting`. So the
rates, map counts and round counts move under a slicer and the composite does not. This is
the intended behaviour, and the page carries a text box saying so.

### Page filters

| Filter | Scope | Why |
|---|---|---|
| `fact_player_map[season]` is 2026 | All pages | The fact table holds 2022–2026; the marts are 2026 only |
| `dim_event[season]` is 2026 | Scouting page | `dim_event` holds all seasons, so the event slicer would otherwise list 2023 tournaments that resolve to zero fact rows |

---

## 2. Data type note

Power BI's CSV connector inferred `rating_all`, `rating_atk`, `rating_def`, `acs_atk` and
`adr_atk` as **Text** from the first 200 rows, which turned their nulls into empty strings and
broke every measure referencing them. Fixed in Power Query by retyping to Decimal Number.

`match_id` and `game_id` are `VARCHAR` in the DuckDB source and must be typed **text**, not
Int64. Nothing in T5 joins on them; T6 might.

If the marts are ever rebuilt, re-check these types before trusting any number.

---

## 3. Measures

All live in `_Measures`. `Column1` is hidden.

### Sample size

```dax
Maps Played = COUNTROWS( fact_player_map )

Rounds Played = SUM( fact_player_map[rounds] )

ADR Maps  = CALCULATE( COUNTROWS( fact_player_map ), NOT ISBLANK( fact_player_map[adr_all] ) )
KAST Maps = CALCULATE( COUNTROWS( fact_player_map ), NOT ISBLANK( fact_player_map[kast_all] ) )
FK Maps   = CALCULATE( COUNTROWS( fact_player_map ), NOT ISBLANK( fact_player_map[fk_all] ) )
```

`Maps Played` and `ADR Maps` differ whenever a stat line is partly missing. ZmjjKK: 85 maps,
77 with an ADR. Both are shown on the candidate table so the gap is visible rather than
implied.

`Rounds Played` is only valid per player. Ten players share one map's rounds, so a grand total
across players triple-counts. **Totals are switched off on the candidate table** for this reason.

### Ranking metrics

Each mirrors `sql/mart_scouting.sql` exactly, including the **per-metric denominator**: the
divisor counts only the rounds from maps where that stat exists.

```dax
ADR =
DIVIDE(
    SUMX( fact_player_map, fact_player_map[adr_all] * fact_player_map[rounds] ),
    CALCULATE( SUM( fact_player_map[rounds] ), NOT ISBLANK( fact_player_map[adr_all] ) )
)

KAST % =
DIVIDE(
    SUMX( fact_player_map, fact_player_map[kast_all] * fact_player_map[rounds] ),
    CALCULATE( SUM( fact_player_map[rounds] ), NOT ISBLANK( fact_player_map[kast_all] ) )
)

APR  = DIVIDE( SUM( fact_player_map[assists_all] ), CALCULATE( SUM( fact_player_map[rounds] ), NOT ISBLANK( fact_player_map[assists_all] ) ) )
DPR  = DIVIDE( SUM( fact_player_map[deaths_all]  ), CALCULATE( SUM( fact_player_map[rounds] ), NOT ISBLANK( fact_player_map[deaths_all]  ) ) )
FKPR = DIVIDE( SUM( fact_player_map[fk_all]      ), CALCULATE( SUM( fact_player_map[rounds] ), NOT ISBLANK( fact_player_map[fk_all]      ) ) )

Opening Win % = DIVIDE( SUM( fact_player_map[fk_all] ), SUM( fact_player_map[fk_all] ) + SUM( fact_player_map[fd_all] ) )

FK-FD per Round = [FKPR] - [FDPR]
```

`SUMX` skips blank rows, because `BLANK() * n` is `BLANK()`. That is what makes the numerator
exclude maps with a missing stat, matching SQL's `sum(adr_all * rounds)`.

`DIVIDE` returns **blank** on a zero or blank denominator. Never add a third argument — a `0`
there would turn "no data" into "zero performance", which `CLAUDE.md` prohibits.

### Display-only metrics (S-09)

Shown, never ranked on. No weight in the composite; a test in `tests/test_marts.py` enforces this.

```dax
KPR  = DIVIDE( SUM( fact_player_map[kills_all] ), CALCULATE( SUM( fact_player_map[rounds] ), NOT ISBLANK( fact_player_map[kills_all] ) ) )
FDPR = DIVIDE( SUM( fact_player_map[fd_all]    ), CALCULATE( SUM( fact_player_map[rounds] ), NOT ISBLANK( fact_player_map[fd_all]    ) ) )

ACS =
DIVIDE(
    SUMX( fact_player_map, fact_player_map[acs_all] * fact_player_map[rounds] ),
    CALCULATE( SUM( fact_player_map[rounds] ), NOT ISBLANK( fact_player_map[acs_all] ) )
)

Rating =
DIVIDE(
    SUMX( fact_player_map, fact_player_map[rating_all] * fact_player_map[rounds] ),
    CALCULATE( SUM( fact_player_map[rounds] ), NOT ISBLANK( fact_player_map[rating_all] ) )
)

HS % =
DIVIDE(
    SUMX( fact_player_map, fact_player_map[hs_pct_all] * fact_player_map[rounds] ),
    CALCULATE( SUM( fact_player_map[rounds] ), NOT ISBLANK( fact_player_map[hs_pct_all] ) )
)
```

`clutches_per_100r` is not implemented in DAX. Its SQL denominator filters on
`performance_available`, and it is display-only. Add it if the page ever needs it.

### Composite and band

```dax
Composite = SELECTEDVALUE( mart_scouting[composite] )
```

Read from the mart, never recalculated. `SELECTEDVALUE` returns blank when more than one
player is in context, so no meaningless total renders.

```dax
Composite Band =
VAR Role = SELECTEDVALUE( mart_scouting[primary_role] )
VAR Pool = FILTER( ALL( mart_scouting ), mart_scouting[primary_role] = Role && mart_scouting[is_eligible] = TRUE() )
VAR N    = COUNTROWS( Pool )
VAR C    = SELECTEDVALUE( mart_scouting[composite] )
VAR R    = IF( NOT ISBLANK( C ), COUNTROWS( FILTER( Pool, mart_scouting[composite] > C ) ) + 1 )
RETURN
SWITCH( TRUE(),
    ISBLANK( R ), BLANK(),
    R <= 10, "Top 10 of " & N,
    R <= 25, "Top 25 of " & N,
    R <= N / 2, "Top half of " & N,
    "Bottom half of " & N
)
```

**T4.4 carry-forward: a band, not a position.** The page must never print "8th best". The
composite is a weighted mean of percentiles with no uncertainty estimate; the gap between
rank 8 and rank 11 is not evidence of anything. Verified at the boundary: splash (74.60) is
rank 10 and reads "Top 10 of 84"; swagzor (73.60) is rank 11 and flips to "Top 25 of 84".

The pool size is baked into the label so the reader always sees the denominator.

### Eligibility and the minimum-maps control

```dax
Sample Warning = IF( SELECTEDVALUE( mart_scouting[is_eligible] ) = FALSE(), "⚠ under 15 maps" )

Meets Min Maps = IF( NOT ISBLANK( [Maps Played] ) && [Maps Played] >= [Min Maps Value], 1, 0 )
```

`Min Maps Value` comes from a numeric-range what-if parameter (0–100, step 1, default 15).

The `NOT ISBLANK` guard is **required**. `BLANK() >= 0` evaluates to TRUE in DAX, so without
it every player in `dim_player` who never played a 2026 map passes the filter whenever the
slider sits at 0. This bug shipped in the first build and put 1szaqt and 2GE at the top of
the candidate list.

`Sample Warning` tests `= FALSE()` rather than `<> TRUE()` so it cannot fire on a blank
context such as a total row.

### Formats

| Decimals | Measures |
|---|---|
| 0 | Maps Played, Rounds Played, ADR Maps, KAST Maps, FK Maps |
| 1 | ADR, KAST %, ACS, HS %, Composite |
| 2 | Rating |
| 3 | APR, DPR, FKPR, FDPR, KPR, Opening Win %, FK-FD per Round |

Match these to the mart's rounding or a comparison will look like a mismatch when it isn't.

---

## 4. Scouting page

| Visual | Fields | Visual filter |
|---|---|---|
| Candidate table | `player_name`, Composite Band, Composite, Maps Played, Rounds Played, ADR, ADR Maps, KAST %, FKPR, Opening Win %, Sample Warning | `Meets Min Maps` = 1 |
| Percentile profile | Clustered bar. Y `mart_percentiles[metric]`, X **Average** of `percentile`. Tooltip: Maps Played | — |
| Opening duels vs damage | Scatter. X `ADR`, Y `FK-FD per Round`, Values `player_name`, **Size `Maps Played`**. Tooltips: Rounds Played, Composite Band | `Meets Min Maps` = 1 |
| Slicers | `dim_player[primary_role]` (buttons, blank excluded, default **duelist**), `dim_event[event]`, `dim_map[map_name]`, `Min Maps` (default 15) | — |

Sorted by Composite descending.

The percentile chart's X must be **Average**, not Sum. Summed, it stacks 84 players'
percentiles and every bar pegs at ~4,000. With no player selected it shows the pool mean,
which is ~50 for every metric by construction — it is meant to be read after clicking a player.

Size-by-maps on the scatter is doing analytical work, not decoration: it is what makes
Kachoww's 16 maps visible next to splash's 71 without reading a column.

**Edit interactions:** the candidate table is set to ⊘ against all three slicers. Slicers
drive the page; they are never driven by it.

---

## 5. QA page

Holds the three-player reconciliation table from the T5 gate: `player_id`, `player_name` and
all 13 measures, filtered to Jerrwin, ZmjjKK and Kachoww. This is the standing evidence for
Checkpoint B's "KPIs for 3 players in Power BI match `mart_scouting.csv` exactly".

Verified 2026-09-23, all 39 cells:

| | Jerrwin (34057) | ZmjjKK (3520) | Kachoww (58496) |
|---|---|---|---|
| Maps / Rounds | 30 / 658 | 85 / 1763 | 16 / 352 |
| ADR | 126.98 | **152.50** | 166.95 |
| KAST % | 65.76 | 70.28 | 75.60 |
| APR | 0.204 | 0.172 | 0.210 |
| DPR | 0.766 | 0.740 | 0.730 |
| FKPR | 0.191 | 0.194 | 0.182 |
| Opening Win % | 0.516 | 0.540 | 0.610 |
| KPR | 0.675 | 0.842 | 0.929 |
| FDPR | 0.179 | 0.165 | 0.116 |
| ACS | 194.79 | 239.07 | 260.01 |
| Rating | 0.85 | 1.05 | 1.17 |
| HS % | 20.53 | 23.83 | 37.89 |

ZmjjKK is the load-bearing case. 85 maps and 1,763 rounds, but only 77 maps carry an ADR.
152.50 is only reachable if the denominator counts the rounds from those 77 maps. Divide by
all 1,763 and the number drops — which is the single most likely way this model could
silently disagree with the mart.

---

## 6. Open items

- **Composite is not comparable across roles.** Each role uses its own weights from
  `data/seeds/metric_weights.csv` and its own percentile pool, so a mixed-role sort ranks
  a 93.9-of-60 initiator above an 86.1-of-84 duelist as though they competed. The role
  slicer defaults to duelist and the band label always names the pool. Leaving the slicer
  cleared is a misreading trap, not a feature.
- **Kachoww ranks 2nd on 16 maps**, the eligibility minimum (T4.6). The composite does not
  shrink small samples toward the mean. The page exposes this through `Maps Played`,
  `ADR Maps` and the scatter's bubble size, but it does not correct for it. A shrinkage
  estimator is the honest fix if the shortlist survives to T11.
- **`opponent_id` is unmodelled.** T6's team-fit work needs it.
- **`clutches_per_100r`** not implemented in DAX.
- **S-14**: everything here is built on the pre-Champions snapshot. Re-run after 2026-10-18
  and re-verify the QA page — it is the fastest end-to-end check that a re-snapshot
  reproduced cleanly.
