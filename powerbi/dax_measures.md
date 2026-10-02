# DAX Measures and Build Notes — Power BI Model

The build reference for `valorant_recruitment.pbix` (repo root): model, measures, formats, the fields behind each visual, verification and open items. **For what each page shows and how to read it, with screenshots, see [`README.md`](README.md).** This file does not repeat that.

Sections 1–6 cover the Scouting model (T5), section 7 Roster Fit and Candidate Fit (T7), section 8 the Budget pages (T9). The numbers must agree with `sql/mart_scouting.sql`, `sql/mart_fit.sql` and `src/budget.py`.

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

---

## 7. Roster Fit and Candidate Fit (T7)

Added 2026-09-28. Companion to `sql/mart_fit.sql`. Pages are now **Scouting**, **Roster Fit**,
**Candidate Fit** and **QA**.

### Model additions

| Table | Source | Grain | Rows |
|---|---|---|---|
| `mart_fit` | `data/marts/mart_fit.csv` | candidate × SEN | 84 |
| `mart_team_profile` | `data/marts/mart_team_profile.csv` | SEN × map (2026) | 12 |
| `fit_weights` | `data/seeds/fit_weights.csv` | component | 3 — QA only, no relationship |

```
dim_player[player_id] → mart_fit[player_id]          1:*  single   (set by hand; Power BI offers 1:1 both)
dim_map[map_name]     → mart_team_profile[map_name]  1:*  single
```

`mart_fit[player_id]` and `mart_fit[player_name]` are hidden, so visuals can only use the
`dim_player` versions — drill-through needs those.

**Types.** `agent_overlap_pct` must be Decimal, not Whole Number. It is whole today only because
the slot has exactly 30 maps (18 + 9 + 3); after the S-14 re-snapshot it will not be, and Int64
would round it silently. `is_import_for_sen` is True/False; `contract_end_year` is Whole Number
with 71 nulls.

### Measures

Read from the mart, never recalculated:

```dax
Baseline Player ID = 34057          -- Jerrwin (S-16). The only place the baseline is set.

Fit Score        = SELECTEDVALUE( mart_fit[fit_score] )
Fit Perf Pct     = SELECTEDVALUE( mart_fit[pct_performance] )
Agent Overlap %  = SELECTEDVALUE( mart_fit[agent_overlap_pct] )
Map Fit Pct      = SELECTEDVALUE( mart_fit[pct_map_fit] )
Map Coverage %   = SELECTEDVALUE( mart_fit[map_coverage_pct] )
Map ADR Delta    = SELECTEDVALUE( mart_fit[map_adr_delta] )
Δ FKPR           = SELECTEDVALUE( mart_fit[delta_fkpr] )
Δ Opening Win %  = SELECTEDVALUE( mart_fit[delta_opening_win_pct] )
Δ DPR            = SELECTEDVALUE( mart_fit[delta_dpr] )          -- negative = better
Δ CV ADR         = SELECTEDVALUE( mart_fit[delta_cv_adr_2026] )  -- negative = better

Fit Band =                                   -- S-18: a band, not a position
VAR Pool = ALL( mart_fit )
VAR N = COUNTROWS( Pool )
VAR S = [Fit Score]
VAR R = IF( NOT ISBLANK( S ), COUNTROWS( FILTER( Pool, mart_fit[fit_score] > S ) ) + 1 )
RETURN SWITCH( TRUE(), ISBLANK( R ), BLANK(),
    R <= 10, "Top 10 of " & N, R <= 25, "Top 25 of " & N,
    R <= N / 2, "Top half of " & N, "Bottom half of " & N )

Import Status =
VAR src = SELECTEDVALUE( mart_fit[import_source] )
VAR imp = SELECTEDVALUE( mart_fit[is_import_for_sen] )
RETURN SWITCH( TRUE(),
    ISBLANK( src ), "Import status unknown",
    imp, "Import · " & src & " · SEN's import slot is taken (S-10)",
    "Resident · " & src )

Fit Pool Note =
IF( ISBLANK( [Fit Score] ), "Roster fit is scored only for the 84 eligible duelists.", "" )
```

Map heatmap. `[ADR]`, `[Maps Played]` and `[Rounds Played]` are the T5 measures, so the
per-metric denominator rule carries over unchanged:

```dax
ADR Rounds = CALCULATE( [Rounds Played], NOT ISBLANK( fact_player_map[adr_all] ) )

Pool ADR =                 -- round-weighted ADR of the 84-player pool on the map in context
CALCULATE( [ADR], REMOVEFILTERS( dim_player ), TREATAS( ALL( mart_fit[player_id] ), fact_player_map[player_id] ) )

ADR vs Pool = [ADR] - [Pool ADR]

Baseline ADR =
VAR b = [Baseline Player ID]
RETURN CALCULATE( [ADR], REMOVEFILTERS( dim_player ), dim_player[player_id] = b )

SEN Games  = SUM( mart_team_profile[games] )
SEN Rounds = SUM( mart_team_profile[rounds] )
SEN Win %  = DIVIDE( SUM( mart_team_profile[wins] ), [SEN Games] )
```

`REMOVEFILTERS( dim_player )` is required in every baseline measure. Without it the drill-through
filter on `dim_player[player_id]` stays in place and the result is blank for everyone but Jerrwin.

Agent matrix and duel chart:

```dax
Slot Maps =                -- Jerrwin's maps on SEN, per agent (S-17)
VAR b = [Baseline Player ID]
RETURN CALCULATE( [Maps Played], REMOVEFILTERS( dim_player ), dim_player[player_id] = b, fact_player_map[team_id] = 2 )

Agent Overlap % (check) =  -- recomputes mart_fit.agent_overlap_pct; the matrix total must equal the card
DIVIDE( SUMX( VALUES( dim_agent[agent] ), IF( [Maps Played] >= 3, [Slot Maps] ) ),
        CALCULATE( [Slot Maps], REMOVEFILTERS( dim_agent ) ) ) * 100

Candidate Percentile = AVERAGE( mart_percentiles[percentile] )
Baseline Percentile =
VAR b = [Baseline Player ID]
RETURN CALCULATE( AVERAGE( mart_percentiles[percentile] ), REMOVEFILTERS( dim_player ), dim_player[player_id] = b )

Fit Score (check) =        -- QA only; ±0.1 from the mart because the components are rounded
VAR wP = LOOKUPVALUE( fit_weights[weight], fit_weights[component], "performance" )
VAR wA = LOOKUPVALUE( fit_weights[weight], fit_weights[component], "agent_overlap" )
VAR wM = LOOKUPVALUE( fit_weights[weight], fit_weights[component], "map_fit" )
RETURN DIVIDE( wP * [Fit Perf Pct] + wA * [Agent Overlap %] + wM * [Map Fit Pct], wP + wA + wM )

Rounds Played (card) = FORMAT( [Rounds Played], "0" )   -- the card auto-scales 1182 to "1K"
```

Formats: 1 decimal for fit components, ADR and percentiles; **3 decimals for the four Δ
measures** (at 2, a +0.055 opening-win edge reads 0.06 and small deltas round to 0); SEN Win %
as a percentage.

### Why two pages

The candidate is chosen by drilling through, not by a slicer. A slicer on `dim_player` on the
same page as a drill-through filter on the same table ANDs with it and blanks the page when the
two disagree. And if the ranking sat on the drill-through page, drilling in would filter it to
one row. So the ranking lives on **Roster Fit** and the candidate view on **Candidate Fit**.

### Roster Fit page

| Visual | Fields | Notes |
|---|---|---|
| Fit ranking | `dim_player[player_id]`, `dim_player[player_name]`, Fit Band, Fit Score, Fit Perf Pct, Agent Overlap %, Map Fit Pct, Map Coverage %, Maps Played, Rounds Played, Import Status | Sorted by Fit Score desc, totals off. Right-click → Drill through → Candidate Fit |
| SEN map pool | Column chart, `dim_map[map_name]` × SEN Games; tooltips SEN Win %, SEN Rounds | Edit interactions: ⊘ on the ranking, or clicking a map re-scopes Maps Played in the table |
| Note | Fit formula (S-18), "ranked by band", not chemistry/communication, unofficial fan analysis | — |

### Candidate Fit page

Drill-through field `dim_player[player_id]`. **Keep all filters Off** — otherwise Scouting's
map and event slicers follow the player in and cut the heatmap to one map. Cross-report Off.
`player_id` was added to the Scouting candidate table so it can drill: `dim_player` has 4
duplicate names (Klaus, Laz, Zeus, adi), and Zeus is a fit candidate, so names are not a safe key.

| Visual | Fields | Notes |
|---|---|---|
| Header cards | Candidate, Fit Band, Fit Score, Maps Played, Rounds Played (card); Fit Perf Pct, Agent Overlap %, Map Fit Pct, Map ADR Delta, Map Coverage % | — |
| Import / pool | Import Status; Fit Pool Note | Pool note fires only for non-duelists drilled from Scouting |
| Map heatmap | Matrix, rows `dim_map[map_name]`: SEN Games, SEN Win %, ADR, ADR Maps, ADR Rounds, Pool ADR, Baseline ADR, ADR vs Pool | Sorted by SEN Games. ADR vs Pool diverging background centred on 0. ADR font grey when **ADR Maps** < 3 (rule on ADR, based on ADR Maps) |
| Agent matrix | Rows `dim_agent[agent]`: Maps Played ("Candidate maps"), Slot Maps ("Jerrwin maps (SEN)"), Agent Overlap % (check) | Subtotal on — it is the overlap % and must equal the card |
| Duel & consistency | Clustered bar, `mart_percentiles[metric]` filtered to fkpr, opening_win, dpr, consistency; Candidate vs Baseline Percentile | X constant line at 25 = replacement level (duelist P25, S-16). DPR and CV are pre-inverted, so higher is better on every bar |
| Δ vs Jerrwin | Matrix, values on rows: the four Δ measures | Column headers off |

A candidate's own team map win % is deliberately not shown as a fit input; it was earned with
four other players (`kpi_dictionary.md` § D).

### Verification (2026-09-28)

| Player | Fit | Band | Perf / Overlap / Map fit | Map ADR Δ | Δ FKPR / Open / DPR / CV |
|---|---|---|---|---|---|
| Meiy (6672) | 94.9 | Top 10 of 84 | 95.2 / 100 / 89.2 | +3.0 | −0.017 / 0.055 / −0.028 / 0.036 |
| Jemkin (24895) | 73.5 | Top 25 of 84 | 91.6 / 100 / 10.8 | −3.9 | −0.025 / 0.041 / −0.102 / −0.004 |
| Jerrwin (34057) | 61.7 | Top half of 84 | — / 100 / — | — | all 0.000; ADR = Baseline ADR on every map |

All match `mart_fit.csv`. Also checked:

- Slot agents: neon 18, waylay 9, raze 3 (30).
- Meiy heatmap: Breeze 147.9 on 102 rounds (pool 138.9, Jerrwin 136.7, SEN 8 games 50%); Split 178.6 on 160 (pool 138.8, Jerrwin 137.4, SEN 6 games 33.3%); Summit 20 rounds, greyed.
- Meiy agents: jett 19, neon 14, raze 10, waylay 8, yoru 4 → overlap 100.
- Band boundary: Wo0t and Timotino (78.3) read Top 10; aspas (78.0) reads Top 25.
- Drill-through: Scouting → Candidate Fit, Roster Fit → Candidate Fit, Back from both; a non-duelist shows blank fit and the pool note; a Breeze selection on Scouting does not carry over.

### Open items (T7)

- **Import status by nationality** (`import_source` = proxy) is still unconfirmed for the
  shortlist — T11 (S-19).
- **Meiy leads on fit, not on every duel metric.** His opening win % is far above Jerrwin's
  (96th vs 55th percentile) but he takes slightly fewer opening duels (FKPR 81st vs 93rd) and
  his ADR swings more map to map (consistency 33rd vs 75th). Worth a line in the T11 memo.
- **S-14:** re-verify this table after the post-Champions re-snapshot, alongside the QA page.

---

## 8. Budget Overview and Budget (T9)

Added 2026-10-02. Companion to `src/budget.py` and `docs/budget_model.md` (formulas §6, rounding §7).
**Slim scope:** only F-14 is live in DAX. Every other number is read from
`mart_budget_reference.csv` for the selected scenario and partner state.

### Model additions

| Table | Source | Grain | Rows |
|---|---|---|---|
| `mart_budget_reference` | `data/marts/mart_budget_reference.csv` | candidate × scenario × partner | 504 |
| `mart_budget_inputs` | `data/marts/mart_budget_inputs.csv` | candidate | 84 |
| `budget_assumptions` | `data/seeds/budget_scenarios.csv`, **unpivoted** | input × scenario | 36 |
| `dim_scenario` | Enter data: `scenario`, `sort`, `label` | scenario | 3 |
| `F14` | What-if parameter, `GENERATESERIES( 0, 50, 1 )`, default 20 | points | 51 |

`budget_assumptions`: in Power Query select `downside`, `base`, `upside` → **Unpivot Columns**,
rename `Attribute` → `scenario` and `Value` → `value` (Decimal). `dim_scenario[label]` is sorted by
`sort`, so slicers read Downside, Base, Upside.

```
dim_player[player_id]   → mart_budget_reference[player_id]   1:*  single
dim_player[player_id]   → mart_budget_inputs[player_id]      1:*  single   (set by hand; Power BI offers 1:1 both)
dim_scenario[scenario]  → mart_budget_reference[scenario]    1:*  single
dim_scenario[scenario]  → budget_assumptions[scenario]       1:*  single
```

**Types.** `partner`, `payback_within_contract`, `cannot_break_even` True/False. `k_star_pct`,
`payback_years` and the six component columns (`buyout`, `import_cost`, `upfront`, `af`,
`extra_salary`, `swing_value`) Decimal: `payback_years` is blank when the yearly gain is negative
and must load as null, not 0; `af` must keep full precision. Money columns Whole Number.

### Controls

| Control | Field | Setting |
|---|---|---|
| Scenario | `dim_scenario[label]` | Single select, Tile; default Base |
| SEN is a 2027 partner (Assumption F-06) | `mart_budget_reference[partner]` | Single select, Tile; default True |
| Your judgement (Assumption F-14) | `F14[F14]` slider | 0–50 points, default 20 |

All three are **synced** between Budget Overview and Budget (View → Sync slicers).

**The F-14 slider is one value for every scenario.** The scenarios vary costs and the swing value;
F-14 is the GM's judgement, not a scenario setting. A card shows what the scenario would suggest
(10 / 20 / 35). So the Downside and Upside NPVs equal the mart's `npv` only when the slider is set
to 10 or 35.

### Measures

Read from the mart (one row is in context once a candidate, a scenario and a partner state are set):

```dax
Budget Candidate        = SELECTEDVALUE( dim_player[player_name] )

Break-even Top-3 Chance = SELECTEDVALUE( mart_budget_reference[k_star_pct] )   -- points, not %
Break-even Uplift       = SELECTEDVALUE( mart_budget_reference[u_star] )
Buyout                  = SELECTEDVALUE( mart_budget_reference[buyout] )       -- F-03 × years left ÷ 2
Import Slot Cost        = SELECTEDVALUE( mart_budget_reference[import_cost] )  -- F-13, imports only
Upfront Cost            = SELECTEDVALUE( mart_budget_reference[upfront] )      -- = Buyout + Import Slot Cost

Break-even Note =
IF( SELECTEDVALUE( mart_budget_reference[cannot_break_even] ), "Cannot break even at this swing value" )

Contract Years Left     = SELECTEDVALUE( mart_budget_inputs[years_left] )
```

From the seed, for the selected scenario:

```dax
Scenario F14 =
CALCULATE( SELECTEDVALUE( budget_assumptions[value] ), budget_assumptions[input_id] = "F-14" ) * 100

Contract Years =
CALCULATE( SELECTEDVALUE( budget_assumptions[value] ), budget_assumptions[input_id] = "F-04" )

Assumption Value =            -- one display column for usd, fraction and years
VAR v = SELECTEDVALUE( budget_assumptions[value] )
VAR u = SELECTEDVALUE( budget_assumptions[unit] )
RETURN SWITCH( u,
    "usd", FORMAT( v, "$#,##0" ),
    "fraction", FORMAT( v, "0%" ),
    "years", FORMAT( v, "0" ) & " years" )
```

Live, from the slider (`F14 Value` is created by the what-if parameter). These follow
`budget_model.md` §6: U = k × V, G = U − ΔS, NPV = G × AF − C₀.

```dax
Net Gain per Year =
VAR v  = SELECTEDVALUE( mart_budget_reference[swing_value] )
VAR ds = SELECTEDVALUE( mart_budget_reference[extra_salary] )
RETURN IF( NOT ISBLANK( v ), [F14 Value] / 100 * v - ds )

NPV Live =
VAR g  = [Net Gain per Year]
VAR af = SELECTEDVALUE( mart_budget_reference[af] )
VAR c0 = SELECTEDVALUE( mart_budget_reference[upfront] )
RETURN IF( NOT ISBLANK( g ), ROUND( g * af - c0, 0 ) )

Decision Live =               -- on the unrounded NPV, as in budget.py
VAR g  = [Net Gain per Year]
VAR af = SELECTEDVALUE( mart_budget_reference[af] )
VAR c0 = SELECTEDVALUE( mart_budget_reference[upfront] )
RETURN IF( NOT ISBLANK( g ), IF( g * af - c0 >= 0, "Sign", "Stay" ) )

Payback Years =               -- simple (undiscounted); blank when the yearly gain is not positive
VAR g  = [Net Gain per Year]
VAR c0 = SELECTEDVALUE( mart_budget_reference[upfront] )
RETURN IF( g > 0, ROUND( DIVIDE( c0, g ), 1 ) )

Payback Note =
VAR g = [Net Gain per Year]
VAR p = [Payback Years]
RETURN SWITCH( TRUE(),
    ISBLANK( g ), BLANK(),
    g <= 0, "Never pays back: the yearly gain is negative",
    p > [Contract Years], "Not within contract",
    "Within contract" )

Max Upfront Spend =
VAR g  = [Net Gain per Year]
VAR af = SELECTEDVALUE( mart_budget_reference[af] )
RETURN IF( NOT ISBLANK( g ), ROUND( MAX( 0, g * af ), 0 ) )
```

DAX `ROUND` rounds halves away from zero, the same as `half_up` in `src/budget.py`, so the two
agree to the dollar.

**Payback is undiscounted and NPV is not**, so they can disagree near the bar: Meiy at F-14 = 32
pays back in 1.6 years ("Within contract") and is still Stay, because at 15% the two discounted
years fall $4,121 short of the upfront cost.

Formats: break-even 1 decimal (points); money Currency, 0 decimals; Payback Years 1 decimal.

### Budget Overview page

Not a drill-through page. It lists the shortlist; it sits before Budget.

| Visual | Fields | Notes |
|---|---|---|
| Shortlist table | `dim_player[player_id]`, `dim_player[player_name]`, Fit Band, Contract Years Left, Fit Score, Import Status, Upfront Cost, Break-even Top-3 Chance, NPV Live, Decision Live | Visual filter **Fit Band is "Top 10 of 84"**; sorted by Fit Score desc; totals off. Right-click → Drill through → Budget |
| Controls | F-14 slider, Scenario, Partner | Synced with Budget |
| Note | Every number is an assumption; candidates differ on cost only by contract years left and the import slot | — |

### Budget page

Drill-through field `dim_player[player_id]`, **Keep all filters Off**, Cross-report Off — the same
setup as Candidate Fit.

| Row | Cards |
|---|---|
| Header | Candidate; Scenario; Partner |
| Bar vs belief | Break-even Top-3 Chance; F14 Value ("Your judgement (F-14)"); F-14 slider; Scenario F14 ("This scenario suggests") |
| Outcome | Decision Live; NPV Live; Payback Years + Payback Note; Max Upfront Spend |
| Costs | Upfront Cost; Buyout (Assumption F-03); Import Slot Cost (Assumption F-13); Break-even Uplift; Break-even Note |
| Assumptions | Table: `budget_assumptions[input_id]`, `[input]`, Assumption Value, `[status]` — 12 rows for the selected scenario |
| Disclaimer | Text box |

### Why two pages

The same reason as §7. A shortlist table on the drill-through page would be cut to one row by the
drill filter, so the list lives on Budget Overview and the candidate view on Budget.

### Lessons from the build

- **Use a measure, not the column, for years left.** With `mart_budget_inputs[years_left]` as a
  table column, every player appeared four times (0, 1, 2, 3): the other measures do not depend on
  that column, so Power BI paired each player with every value. `Contract Years Left` fixes it.
- **The assumptions table needs the Scenario slicer on its page.** Without a scenario in context,
  `SELECTEDVALUE` is blank for every input whose three values differ; only F-01 and F-04 showed.
- **Cards abbreviate money** ($150K, ($69K)). This version of the card visual has no Display units
  setting. Exact dollars are read from a table visual; the shortlist table shows them in full.
- **Refresh after a mart rebuild.** `mart_fit` in the file predated the handle-alias fix until
  Home → Refresh; dgzin's import status then changed from "nationality (proxy)" to "contract
  database". The folder was renamed to `D:\VCT`, so old source paths may need Data source settings →
  Change Source.

### Verification (2026-10-02)

Budget Overview, Base, partner True — exact, read from the table:

| F-14 | Meiy, swagzor, OXY ($300,000 upfront, bar 32.2) | Derke, ZmjjKK, primmie, BuZz, dgzin, Wo0t, Timotino ($150,000 upfront, bar 23.8) |
|---|---|---|
| 20 | −$218,715 · Stay | −$68,715 · Stay |
| 24 | −$147,183 · Stay | $2,817 · **Sign** |

The F-14 = 20 row equals `npv` in `mart_budget_reference.csv` for all ten players, which are worked
cases 1 and 2 of `budget_model.md` §8. Contract years left: Meiy 1, swagzor 1, Derke 0, ZmjjKK 0,
primmie 0, BuZz 0, dgzin 1, OXY 2, Wo0t 0, Timotino 1.

Also checked:

- **Flip at the bar.** Derke: Stay at 23, Sign at 24 (bar 23.8). Meiy: Stay at 32, Sign at 33 (bar 32.2).
- **Budget page, Derke, Base, partner:** break-even 23.8; upfront $150K = $0 buyout + $150K import
  slot; at F-14 = 20 Stay, payback 3.0 "Not within contract", max upfront $81K; at 38 Sign,
  NPV $253K (253,176 by hand), payback 0.6, max upfront $403K.
- **Budget page, Meiy, Base, partner:** break-even 32.2; upfront $300K = $150K + $150K; at 24 Stay,
  NPV ($147K), payback 3.2, max upfront $153K, uplift needed $355K.
- **Assumptions table, Base:** 12 rows, values equal `budget_scenarios.csv`.
- **Drill-through:** Roster Fit → Budget carries the candidate (Derke, Meiy); Back works. The slider and scenario stay in sync between Budget Overview and Budget (both read 24 / Base).

### Open items (T9)

- **Cases 3–5 of `budget_model.md` §8 are not yet recorded here:** Timotino, Base, partner False,
  F-14 = 20 (−$263,800, payback blank); Meiy, Downside, F-14 = 10 (−$1,330,840, "cannot break
  even"); primmie, Upside, F-14 = 35 ($1,939,463, Sign, payback 0.0). Pytest covers all three; the
  page check is a formality but belongs in this table.
- **The two Budget pages do not carry the "unofficial fan analysis, not affiliated with Sentinels
  or Riot Games" line** that CLAUDE.md asks for on every page. Their notes say "every number is an
  assumption" only.
- **Payback Note overlaps the Payback card.**
- **S-14:** after the post-Champions re-snapshot, rerun the pipeline, Refresh, and re-check the
  verification table above; the shortlist may change.
