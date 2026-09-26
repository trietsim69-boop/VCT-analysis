-- Roster-fit marts for SEN's vacant duelist slot (T6). Run: python -m src.marts
-- Reads mart_scouting.csv, so it runs after sql/mart_scouting.sql.
--
-- Decisions (docs/kpi_dictionary.md § D):
--   the baseline is Jerrwin, the slot's 2026 incumbent — every delta is candidate − Jerrwin
--   the slot's agents are Jerrwin's agents on SEN (neon, waylay, raze)
--   map fit uses the candidate's OWN per-map ADR, never his team's map win rate: a win rate
--   was earned with four other players and says nothing about winning maps for SEN
--   candidates are the eligible duelist pool from the scouting mart (84)

SET VARIABLE sen = 2;
SET VARIABLE baseline = 34057;  -- Jerrwin

CREATE OR REPLACE TEMP VIEW f26 AS
SELECT * FROM 'data/processed/fact_player_map.csv' WHERE season = 2026;

CREATE OR REPLACE TEMP VIEW pool AS
SELECT * FROM 'data/marts/mart_scouting.csv' WHERE primary_role = 'duelist' AND is_eligible;

-- sen_maps: SEN's 2026 map pool. The fact has one row per player, so games are deduplicated
-- first — otherwise every count is five times too big.
CREATE OR REPLACE TEMP VIEW sen_maps AS
SELECT map_name, count(*) AS games, count(*) FILTER (WHERE map_won) AS wins,
       sum(rounds) AS rounds, round(100.0 * count(*) FILTER (WHERE map_won) / count(*), 1) AS win_pct
FROM (SELECT DISTINCT game_id, map_name, rounds, map_won FROM f26 WHERE team_id = getvariable('sen'))
GROUP BY map_name;

-- agent_overlap: the share of the slot's maps (Jerrwin on SEN, by agent) that were on agents
-- the candidate has played >= 3 times in 2026. Map-weighted, so neon (18 maps) counts for more
-- than raze (3). 0 here is a measured "no overlap", not a missing value.
CREATE OR REPLACE TEMP VIEW slot_agents AS
SELECT agent, count(*) AS maps FROM f26
WHERE player_id = getvariable('baseline') AND team_id = getvariable('sen') GROUP BY agent;

CREATE OR REPLACE TEMP VIEW agent_overlap AS
SELECT p.player_id,
       100.0 * coalesce(sum(s.maps) FILTER (WHERE c.n >= 3), 0) / (SELECT sum(maps) FROM slot_agents)
           AS agent_overlap_pct
FROM pool p CROSS JOIN slot_agents s
LEFT JOIN (SELECT player_id, agent, count(*) AS n FROM f26 GROUP BY ALL) c
       ON c.player_id = p.player_id AND c.agent = s.agent
GROUP BY p.player_id;

-- map_fit: is he stronger on SEN's maps than he is in general? Per map, his ADR minus the
-- duelist pool's ADR there (so a high-damage map does not flatter him). That gap is averaged
-- twice — weighted by SEN games × his rounds, and by his rounds alone — and the second is
-- subtracted. What is left is map-specific: his overall level is already in `performance`.
-- The first cut (the SEN-weighted gap alone) correlated 0.96 with overall ADR — one signal
-- counted twice. Coverage is the share of SEN's games on maps he has played at all.
CREATE OR REPLACE TEMP VIEW cand_map AS
SELECT player_id, map_name,
       sum(adr_all * rounds) / sum(rounds) FILTER (WHERE adr_all IS NOT NULL) AS adr,
       sum(rounds) FILTER (WHERE adr_all IS NOT NULL) AS adr_rounds
FROM f26 JOIN pool USING (player_id) GROUP BY ALL;

CREATE OR REPLACE TEMP VIEW pool_map AS
SELECT map_name, sum(adr * adr_rounds) / sum(adr_rounds) AS pool_adr FROM cand_map GROUP BY map_name;

CREATE OR REPLACE TEMP VIEW map_fit AS
SELECT c.player_id,
       sum(s.games * c.adr_rounds * (c.adr - pm.pool_adr)) / sum(s.games * c.adr_rounds)
           - sum(c.adr_rounds * (c.adr - pm.pool_adr)) / sum(c.adr_rounds) AS map_adr_delta,
       100.0 * sum(s.games) / (SELECT sum(games) FROM sen_maps) AS map_coverage_pct
FROM cand_map c LEFT JOIN sen_maps s USING (map_name) JOIN pool_map pm USING (map_name)
GROUP BY c.player_id;

-- fit_pct: each component on a 0–100 scale so they can be added. Performance and map fit are
-- percentiles within the pool. Agent overlap is used as-is: it is already a 0–100 share, and
-- 30 of 84 candidates tie at 100%, which percent_rank would score 65 rather than 100. Performance is the scouting composite, which already holds every
-- ranking KPI — the deltas vs Jerrwin below are its readable form, not a fourth component.
-- A TABLE, not a view: joined back to its own UNPIVOT as a view, DuckDB 1.5 runs out of memory.
CREATE OR REPLACE TEMP TABLE fit_pct AS
SELECT p.player_id,
       100 * percent_rank() OVER (ORDER BY p.composite) AS performance,
       a.agent_overlap_pct AS agent_overlap,
       100 * percent_rank() OVER (ORDER BY m.map_adr_delta) AS map_fit
FROM pool p JOIN agent_overlap a USING (player_id) LEFT JOIN map_fit m USING (player_id);

-- fit: weighted mean of the component percentiles, weights from the seed, renormalised over
-- the components present (same rule as the scouting composite).
CREATE OR REPLACE TEMP VIEW fit AS
SELECT l.player_id, sum(w.weight * l.pct) / sum(w.weight) AS fit_score
FROM (UNPIVOT fit_pct ON COLUMNS(* EXCLUDE player_id) INTO NAME component VALUE pct) l
JOIN 'data/seeds/fit_weights.csv' w USING (component)
GROUP BY l.player_id;

-- mart_team_profile.csv: SEN's 2026 record per map. Feeds the T7 heatmap.
COPY (
    SELECT getvariable('sen') AS team_id, * FROM sen_maps ORDER BY games DESC, map_name
) TO 'data/marts/mart_team_profile.csv' (HEADER);

-- mart_fit.csv: one row per eligible duelist. Import status comes from Riot's contract
-- database when the player is listed in the Americas tab; otherwise nationality stands in,
-- which is a proxy (import_source says which). SEN's one import slot is taken (S-10), so an
-- import candidate means moving johnqt as well.
COPY (
    SELECT p.player_id, p.player_name, p.regions, p.maps_played, p.rounds_played, p.composite,
           round(a.agent_overlap_pct, 1) AS agent_overlap_pct,
           round(m.map_adr_delta, 1) AS map_adr_delta,
           round(m.map_coverage_pct, 1) AS map_coverage_pct,
           round(x.performance, 1) AS pct_performance,
           round(x.map_fit, 1) AS pct_map_fit,
           round(fit.fit_score, 1) AS fit_score,
           round(p.adr - b.adr, 1) AS delta_adr,
           round(p.kast_pct - b.kast_pct, 1) AS delta_kast_pct,
           round(p.fkpr - b.fkpr, 3) AS delta_fkpr,
           round(p.opening_win_pct - b.opening_win_pct, 3) AS delta_opening_win_pct,
           round(p.dpr - b.dpr, 3) AS delta_dpr,
           round(p.cv_adr_2026 - b.cv_adr_2026, 3) AS delta_cv_adr_2026,
           CASE WHEN g.resident_status IS NOT NULL THEN g.resident_status = 'Non-Resident'
                WHEN d.country IS NULL OR d.country = 'un' THEN NULL
                ELSE d.country NOT IN ('us', 'ca', 'mx', 'br', 'ar', 'cl', 'pe', 'co', 'uy', 've',
                                       'ec', 'py', 'bo', 'do', 'pr', 'gt', 'cr', 'pa', 'sv', 'hn',
                                       'ni', 'cu')
           END AS is_import_for_sen,
           CASE WHEN g.resident_status IS NOT NULL THEN 'contract database'
                WHEN d.country IS NOT NULL AND d.country <> 'un' THEN 'nationality (proxy)'
           END AS import_source,
           d.country, g.team AS contract_team, g.contract_end_year
    FROM pool p
    JOIN pool b ON b.player_id = getvariable('baseline')
    JOIN agent_overlap a ON a.player_id = p.player_id
    LEFT JOIN map_fit m ON m.player_id = p.player_id
    JOIN fit_pct x ON x.player_id = p.player_id
    JOIN fit ON fit.player_id = p.player_id
    JOIN 'data/processed/dim_player.csv' d ON d.player_id = p.player_id
    LEFT JOIN 'data/processed/dim_contract_americas.csv' g
           ON lower(g.handle) = lower(p.player_name) AND g.gcd_role = 'PLAYER'
    ORDER BY fit_score DESC, p.player_id
) TO 'data/marts/mart_fit.csv' (HEADER);
