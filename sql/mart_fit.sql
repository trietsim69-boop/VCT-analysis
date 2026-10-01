SET VARIABLE sen = 2;
SET VARIABLE baseline = 34057;  -- baseline is Jerrwin

CREATE OR REPLACE TEMP VIEW f26 AS
SELECT * FROM 'data/processed/fact_player_map.csv' WHERE season = 2026;

-- Candidates: the 84 eligible duelists.
CREATE OR REPLACE TEMP VIEW pool AS
SELECT * FROM 'data/marts/mart_scouting.csv' WHERE primary_role = 'duelist' AND is_eligible;

-- SEN's 2026 map pool.
CREATE OR REPLACE TEMP VIEW sen_maps AS
SELECT map_name, count(*) AS games, count(*) FILTER (WHERE map_won) AS wins,
       sum(rounds) AS rounds, round(100.0 * count(*) FILTER (WHERE map_won) / count(*), 1) AS win_pct
FROM (SELECT DISTINCT game_id, map_name, rounds, map_won FROM f26 WHERE team_id = getvariable('sen'))  -- DISTINCT: 5 player rows = 1 game
GROUP BY map_name;

-- agent_overlap: the share of the slot's map agent that has been played >= 3 times
CREATE OR REPLACE TEMP VIEW slot_agents AS
SELECT agent, count(*) AS maps FROM f26
WHERE player_id = getvariable('baseline') AND team_id = getvariable('sen') GROUP BY agent;  -- Jerrwin's agents on SEN

CREATE OR REPLACE TEMP VIEW agent_overlap AS
SELECT p.player_id,
       100.0 * coalesce(sum(s.maps) FILTER (WHERE c.n >= 3), 0) / (SELECT sum(maps) FROM slot_agents)  -- map-weighted; 0 = measured no overlap
           AS agent_overlap_pct
FROM pool p CROSS JOIN slot_agents s  -- every candidate x every slot agent
LEFT JOIN (SELECT player_id, agent, count(*) AS n FROM f26 GROUP BY ALL) c  -- LEFT: unplayed agent keeps its row
       ON c.player_id = p.player_id AND c.agent = s.agent
GROUP BY p.player_id;

-- map_fit: is he stronger on SEN's picked maps than on his own average map? (overall level is in performance)
CREATE OR REPLACE TEMP VIEW cand_map AS
SELECT player_id, map_name,
       sum(adr_all * rounds) / sum(rounds) FILTER (WHERE adr_all IS NOT NULL) AS adr,  -- round-weighted
       sum(rounds) FILTER (WHERE adr_all IS NOT NULL) AS adr_rounds
FROM f26 JOIN pool USING (player_id) GROUP BY ALL;

CREATE OR REPLACE TEMP VIEW pool_map AS
SELECT map_name, sum(adr * adr_rounds) / sum(adr_rounds) AS pool_adr FROM cand_map GROUP BY map_name;  -- pool ADR per map

CREATE OR REPLACE TEMP VIEW map_fit AS
SELECT c.player_id,
       sum(s.games * c.adr_rounds * (c.adr - pm.pool_adr)) / sum(s.games * c.adr_rounds)  -- gap vs pool, weighted to SEN's maps
           - sum(c.adr_rounds * (c.adr - pm.pool_adr)) / sum(c.adr_rounds) AS map_adr_delta,  -- minus his usual gap (else r=0.96 with ADR)
       100.0 * sum(s.games) / (SELECT sum(games) FROM sen_maps) AS map_coverage_pct  -- share of SEN games on maps he's played
FROM cand_map c LEFT JOIN sen_maps s USING (map_name) JOIN pool_map pm USING (map_name)  -- LEFT: his non-SEN maps feed his average
GROUP BY c.player_id;

-- fit_pct: each component on 0–100 so they can be added. TABLE, not view: as a view DuckDB 1.5 runs out of memory.
CREATE OR REPLACE TEMP TABLE fit_pct AS
SELECT p.player_id,
       100 * percent_rank() OVER (ORDER BY p.composite) AS performance,  -- percentile: composite is relative
       a.agent_overlap_pct AS agent_overlap,  -- as-is: already 0–100; 30 tie at 100, percentile would say 65
       100 * percent_rank() OVER (ORDER BY m.map_adr_delta) AS map_fit  -- percentile: ADR gap has no fixed scale
FROM pool p JOIN agent_overlap a USING (player_id) LEFT JOIN map_fit m USING (player_id);

-- fit: weighted mean of the components, weights from data/seeds/fit_weights.csv.
CREATE OR REPLACE TEMP VIEW fit AS
SELECT l.player_id, sum(w.weight * l.pct) / sum(w.weight) AS fit_score  -- ÷ weights used: a missing component isn't scored 0
FROM (UNPIVOT fit_pct ON COLUMNS(* EXCLUDE player_id) INTO NAME component VALUE pct) l  -- long form to join weights
JOIN 'data/seeds/fit_weights.csv' w USING (component)
GROUP BY l.player_id;

-- mart_team_profile.csv: SEN's 2026 record per map.
COPY (
    SELECT getvariable('sen') AS team_id, * FROM sen_maps ORDER BY games DESC, map_name
) TO 'data/marts/mart_team_profile.csv' (HEADER);

-- mart_fit.csv: one row per candidate; deltas and import flag are context, not in the fit score.
COPY (
    SELECT p.player_id, p.player_name, p.regions, p.maps_played, p.rounds_played, p.composite,
           round(a.agent_overlap_pct, 1) AS agent_overlap_pct,
           round(m.map_adr_delta, 1) AS map_adr_delta,
           round(m.map_coverage_pct, 1) AS map_coverage_pct,
           round(x.performance, 1) AS pct_performance,
           round(x.map_fit, 1) AS pct_map_fit,
           round(fit.fit_score, 1) AS fit_score,
           round(p.adr - b.adr, 1) AS delta_adr,  -- deltas: candidate − Jerrwin
           round(p.kast_pct - b.kast_pct, 1) AS delta_kast_pct,
           round(p.fkpr - b.fkpr, 3) AS delta_fkpr,
           round(p.opening_win_pct - b.opening_win_pct, 3) AS delta_opening_win_pct,
           round(p.dpr - b.dpr, 3) AS delta_dpr,  -- negative = better
           round(p.cv_adr_2026 - b.cv_adr_2026, 3) AS delta_cv_adr_2026,  -- negative = better
           CASE WHEN g.resident_status IS NOT NULL THEN g.resident_status = 'Non-Resident'  -- Riot's list first
                WHEN d.country IS NULL OR d.country = 'un' THEN NULL  -- unknown stays NULL
                ELSE d.country NOT IN ('us', 'ca', 'mx', 'br', 'ar', 'cl', 'pe', 'co', 'uy', 've',  -- else nationality proxy
                                       'ec', 'py', 'bo', 'do', 'pr', 'gt', 'cr', 'pa', 'sv', 'hn',
                                       'ni', 'cu')
           END AS is_import_for_sen,
           CASE WHEN g.resident_status IS NOT NULL THEN 'contract database'
                WHEN d.country IS NOT NULL AND d.country <> 'un' THEN 'nationality (proxy)'
           END AS import_source,  -- says which rule set the flag
           d.country, g.team AS contract_team, g.contract_end_year
    FROM pool p
    JOIN pool b ON b.player_id = getvariable('baseline')  -- b = Jerrwin's row, on every candidate
    JOIN agent_overlap a ON a.player_id = p.player_id
    LEFT JOIN map_fit m ON m.player_id = p.player_id
    JOIN fit_pct x ON x.player_id = p.player_id
    JOIN fit ON fit.player_id = p.player_id
    JOIN 'data/processed/dim_player.csv' d ON d.player_id = p.player_id
    LEFT JOIN 'data/seeds/gcd_handle_aliases.csv' al ON al.player_id = p.player_id  -- Riot's handle differs (dgzin = dgz)
    LEFT JOIN 'data/processed/dim_contract_americas.csv' g  -- LEFT: most candidates aren't in the Americas tab
           ON lower(g.handle) = lower(coalesce(al.gcd_handle, p.player_name)) AND g.gcd_role = 'PLAYER'  -- case-insensitive handle match
    ORDER BY fit_score DESC, p.player_id  -- player_id: stable order across rebuilds
) TO 'data/marts/mart_fit.csv' (HEADER);
