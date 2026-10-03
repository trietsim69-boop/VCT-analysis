# Tableau Public Story — Sentinels 2027 Duelist Signing

> **Unofficial fan analysis.** Not affiliated with Sentinels or Riot Games. Every financial number is an assumption.

**Status:** data files ready (T10.1, 2026-10-03). The story is not built yet; this page will gain the public link, screenshots and the parity table when it is (T10.6).

The story presents the scouting and fit findings to a general audience. The analyst tool, with slicers and the budget slider, is the Power BI report in [`../powerbi/`](../powerbi/README.md).

## Data files

Tableau can't reuse Power BI's DAX, so everything DAX computed is written to three flat files by `sql/mart_tableau.sql` (part of `python -m src.marts`). They are read from the same tested marts, so the two tools agree by construction. All three cover the **84 eligible duelists** of the 2026 season before Champions.

Connect to them in `data/marts/`:

| File | One row per | Rows | Feeds |
|---|---|---|---|
| `tableau_candidates.csv` | duelist | 84 | Story points 1, 2, 3 and 5 |
| `tableau_maps.csv` | duelist × SEN map | 1,008 | Story point 4 |
| `tableau_percentiles.csv` | duelist × metric | 588 | The percentile profile of one player |

All three share `player_id`, `player_name`, `fit_band`, `is_shortlist` and `is_baseline`, so they can also be related on `player_id`.

### `tableau_candidates.csv`

| Columns | Meaning |
|---|---|
| `maps_played`, `rounds_played`, `adr_maps` | Sample size. Show it beside every rate |
| `adr`, `kast_pct`, `fkpr`, `fdpr`, `opening_win_pct`, `dpr`, `cv_adr_2026` | 2026 rates, weighted by rounds |
| `fk_fd_per_round` | Opening kills minus opening deaths, per round |
| `composite`, `composite_band` | Scouting score and its band ("Top 10 of 84"). Show the band, not a rank |
| `fit_score`, `fit_band` | Fit for SEN's slot and its band |
| `fit_pts_performance`, `fit_pts_agent_overlap`, `fit_pts_map_fit` | Points each component adds to the fit score. Stack them; they sum to `fit_score` (± 0.1) |
| `pct_performance`, `agent_overlap_pct`, `pct_map_fit`, `map_adr_delta`, `map_coverage_pct` | The fit components before weighting |
| `is_import_for_sen`, `import_source` | Would he need SEN's import slot, and which rule says so |
| `contract_team`, `contract_end_year`, `years_left`, `contract_match` | From Riot's contract database |
| `upfront_base`, `break_even_base` | Base scenario, SEN a partner: upfront cost in USD, and the points of top-3 chance the signing must add to pay for itself. **Assumption-driven** |
| `cost_group` | Why the cost is what it is, in words: contract status and import slot |
| `is_shortlist` | The top-10 fit band |
| `is_baseline` | Jerrwin, who held the slot in 2026 |

### `tableau_maps.csv`

| Columns | Meaning |
|---|---|
| `map_name`, `sen_games`, `sen_win_pct`, `sen_rounds` | SEN's 2026 record on the map |
| `adr`, `adr_maps`, `adr_rounds` | The player's ADR there and its sample. Blank if he hasn't played it |
| `pool_adr`, `adr_vs_pool` | The 84 duelists' ADR on that map, and the player's gap to it |
| `low_sample` | True under 3 maps. Grey these out |

### `tableau_percentiles.csv`

| Columns | Meaning |
|---|---|
| `metric`, `metric_label` | The metric and a readable name |
| `percentile` | 0–100 within the 84. Higher is always better; deaths and consistency are already inverted |
| `composite_weight` | The metric's weight in the composite. Blank = shown but not weighted (assists) |

## Rules for the story

- Sample sizes on every view; bands, not rank numbers; blank means no data.
- The break-even is an assumption-driven bar, not a forecast. Say so where it appears.
- Rerun after the post-Champions re-snapshot (after 2026-10-18) and republish.
