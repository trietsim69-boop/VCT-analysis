# Data Audit (auto-generated)

Source: `data/raw/vct-fe27a11e.duckdb` (VCT Reference build downloaded 2026-09-18)
Generated: 2026-09-18

Task 2 adds the interpretation: coverage decisions, the region/role scope and the go/no-go.

## kill_matrix — 150,140 rows

| column | type | null % | distinct |
|---|---|---|---|
| `match_id` | VARCHAR | 0.0 | 2,390 |
| `game_id` | VARCHAR | 0.0 | 6,006 |
| `row_player_id` | INTEGER | 0.0 | 956 |
| `col_player_id` | INTEGER | 0.0 | 1,013 |
| `kills` | TINYINT | 0.0 | 15 |
| `deaths` | TINYINT | 0.0 | 15 |
| `op_kills` | TINYINT | 0.0 | 9 |
| `op_deaths` | TINYINT | 0.0 | 7 |
| `fk_kills` | TINYINT | 0.0 | 8 |
| `fk_deaths` | TINYINT | 0.0 | 9 |

## maps — 7,418 rows

| column | type | null % | distinct |
|---|---|---|---|
| `match_id` | VARCHAR | 0.0 | 2,930 |
| `game_id` | VARCHAR | 0.0 | 7,418 |
| `map_name` | VARCHAR | 1.4 | 13 |
| `picked_by_team` | TINYINT | 20.0 | 2 |
| `duration` | VARCHAR | 0.0 | 2,519 |
| `score0` | TINYINT | 1.4 | 25 |
| `score1` | TINYINT | 1.4 | 24 |
| `performance_available` | BOOLEAN | 0.0 | 2 |
| `economy_available` | BOOLEAN | 0.0 | 2 |

## matches — 2,930 rows

| column | type | null % | distinct |
|---|---|---|---|
| `match_id` | VARCHAR | 0.0 | 2,930 |
| `url` | VARCHAR | 0.0 | 2,930 |
| `event` | VARCHAR | 0.0 | 108 |
| `event_url` | VARCHAR | 0.0 | 187 |
| `event_id` | INTEGER | 0.0 | 113 |
| `event_slug` | VARCHAR | 0.0 | 108 |
| `series_text` | VARCHAR | 0.0 | 189 |
| `series_stage` | VARCHAR | 0.0 | 18 |
| `series_round` | VARCHAR | 0.0 | 82 |
| `date_text` | VARCHAR | 0.0 | 2,837 |
| `ts_et` | VARCHAR | 0.0 | 2,834 |
| `utc_timestamp` | TIMESTAMP | 0.0 | 2,834 |
| `patch` | VARCHAR | 19.1 | 57 |
| `team0_id` | INTEGER | 0.9 | 200 |
| `team1_id` | INTEGER | 0.9 | 212 |
| `score0` | TINYINT | 1.2 | 4 |
| `score1` | TINYINT | 1.2 | 4 |
| `status` | VARCHAR | 1.2 | 1 |
| `listing_status` | VARCHAR | 0.0 | 3 |
| `format` | VARCHAR | 0.0 | 3 |
| `veto` | VARCHAR[] | 8.1 | 2,669 |
| `fetched_overview` | BOOLEAN | 0.0 | 1 |
| `fetched_performance` | BOOLEAN | 0.0 | 2 |
| `fetched_economy` | BOOLEAN | 0.0 | 2 |
| `is_international` | BOOLEAN | 0.0 | 2 |
| `region` | VARCHAR | 16.2 | 4 |
| `is_showmatch` | BOOLEAN | 0.0 | 1 |

## notables — 237,018 rows

| column | type | null % | distinct |
|---|---|---|---|
| `player_id` | INTEGER | 0.0 | 1,050 |
| `match_id` | VARCHAR | 0.0 | 2,390 |
| `game_id` | VARCHAR | 0.0 | 6,004 |
| `player_team_idx` | TINYINT | 0.0 | 2 |
| `stat_type` | VARCHAR | 0.0 | 9 |
| `round_num` | TINYINT | 0.0 | 48 |
| `opponents` | STRUCT("name" VARCHAR, agent VARCHAR)[] | 0.0 | 110,278 |

## player_map — 73,356 rows

| column | type | null % | distinct |
|---|---|---|---|
| `player_id` | INTEGER | 0.0 | 1,226 |
| `match_id` | VARCHAR | 0.0 | 2,904 |
| `game_id` | VARCHAR | 0.0 | 7,336 |
| `team_idx` | TINYINT | 0.0 | 2 |
| `agents` | VARCHAR[] | 0.3 | 29 |
| `rating_all` | DOUBLE | 11.7 | 254 |
| `rating_atk` | DOUBLE | 11.7 | 347 |
| `rating_def` | DOUBLE | 11.7 | 351 |
| `acs_all` | SMALLINT | 0.7 | 443 |
| `acs_atk` | SMALLINT | 11.6 | 594 |
| `acs_def` | SMALLINT | 7.7 | 596 |
| `adr_all` | SMALLINT | 5.2 | 292 |
| `adr_atk` | SMALLINT | 11.6 | 382 |
| `adr_def` | SMALLINT | 7.7 | 391 |
| `kills_all` | TINYINT | 0.3 | 47 |
| `kills_atk` | TINYINT | 7.0 | 26 |
| `kills_def` | TINYINT | 7.0 | 29 |
| `deaths_all` | TINYINT | 0.3 | 40 |
| `deaths_atk` | TINYINT | 7.0 | 23 |
| `deaths_def` | TINYINT | 7.0 | 22 |
| `assists_all` | TINYINT | 0.3 | 31 |
| `assists_atk` | TINYINT | 7.0 | 20 |
| `assists_def` | TINYINT | 7.0 | 21 |
| `fk_all` | TINYINT | 4.9 | 14 |
| `fk_atk` | TINYINT | 7.0 | 10 |
| `fk_def` | TINYINT | 7.0 | 9 |
| `fd_all` | TINYINT | 5.0 | 14 |
| `fd_atk` | TINYINT | 7.0 | 12 |
| `fd_def` | TINYINT | 7.0 | 12 |
| `kast_all` | TINYINT | 11.1 | 81 |
| `kast_atk` | TINYINT | 11.4 | 73 |
| `kast_def` | TINYINT | 11.4 | 69 |
| `hs_pct_all` | TINYINT | 5.0 | 79 |
| `hs_pct_atk` | TINYINT | 7.3 | 91 |
| `hs_pct_def` | TINYINT | 7.2 | 89 |
| `two_k` | TINYINT | 24.7 | 12 |
| `three_k` | TINYINT | 55.7 | 8 |
| `four_k` | TINYINT | 87.6 | 4 |
| `five_k` | TINYINT | 98.4 | 2 |
| `clutch_1v1` | TINYINT | 85.2 | 4 |
| `clutch_1v2` | TINYINT | 91.9 | 3 |
| `clutch_1v3` | TINYINT | 97.8 | 3 |
| `clutch_1v4` | TINYINT | 99.6 | 1 |
| `clutch_1v5` | TINYINT | 100.0 | 1 |
| `econ` | SMALLINT | 18.2 | 162 |
| `plants` | TINYINT | 18.2 | 15 |
| `defuses` | TINYINT | 18.2 | 6 |

## players — 1,226 rows

| column | type | null % | distinct |
|---|---|---|---|
| `player_id` | INTEGER | 0.0 | 1,226 |
| `player_name` | VARCHAR | 0.0 | 1,222 |
| `country` | VARCHAR | 0.0 | 68 |
| `player_url` | VARCHAR | 0.0 | 1,226 |

## rounds — 154,959 rows

| column | type | null % | distinct |
|---|---|---|---|
| `match_id` | VARCHAR | 0.0 | 2,896 |
| `game_id` | VARCHAR | 0.0 | 7,311 |
| `round_num` | TINYINT | 0.0 | 48 |
| `winner_team` | TINYINT | 0.0 | 2 |
| `side` | VARCHAR | 0.0 | 2 |
| `outcome` | VARCHAR | 0.0 | 4 |
| `loadout_t0` | USMALLINT | 17.8 | 593 |
| `loadout_t1` | USMALLINT | 17.8 | 599 |
| `bank_t0` | USMALLINT | 17.8 | 424 |
| `bank_t1` | USMALLINT | 17.8 | 426 |

## teams — 225 rows

| column | type | null % | distinct |
|---|---|---|---|
| `team_id` | INTEGER | 0.0 | 225 |
| `team_name` | VARCHAR | 0.0 | 222 |
| `team_url` | VARCHAR | 0.0 | 225 |
| `country` | VARCHAR | 0.0 | 32 |
