-- Scouting marts. Run: python -m src.marts

-- f: the fact with player name, primary role and region attached.
CREATE OR REPLACE TEMP VIEW f AS
SELECT f.*, p.player_name, p.primary_role, e.region
FROM 'data/processed/fact_player_map.csv' f
JOIN 'data/processed/dim_player.csv' p USING (player_id)
JOIN 'data/processed/dim_event.csv' e USING (event_id);

-- cv: std ÷ mean, so a high scorer isn't punished for bigger absolute swings. Lower = steadier.
CREATE OR REPLACE TEMP MACRO cv(col) AS stddev_samp(col) / nullif(avg(col), 0);  -- nullif: no divide by 0

-- agg: one row per player, 2026; every headline rate is computed here.
CREATE OR REPLACE TEMP VIEW agg AS
SELECT player_id, any_value(player_name) AS player_name, any_value(primary_role) AS primary_role,
       string_agg(DISTINCT region ORDER BY region) AS regions,
       bool_or(region = 'China') AS china_league,  -- flags the league with stat gaps (S-12)
       count(*) AS maps_played,
       sum(rounds) AS rounds_played,
       count(*) >= 15 AS is_eligible,  -- S-07: all maps count, even with a partly missing stat line
       -- ranking metrics: Σ(stat × rounds) ÷ Σ rounds; FILTER keeps each denominator to maps with that stat
       sum(adr_all * rounds) / sum(rounds) FILTER (WHERE adr_all IS NOT NULL) AS adr,
       sum(kast_all * rounds) / sum(rounds) FILTER (WHERE kast_all IS NOT NULL) AS kast_pct,
       sum(assists_all) / sum(rounds) FILTER (WHERE assists_all IS NOT NULL) AS apr,  -- counts: plain Σ ÷ Σ rounds
       sum(deaths_all) / sum(rounds) FILTER (WHERE deaths_all IS NOT NULL) AS dpr,
       sum(fk_all) / sum(rounds) FILTER (WHERE fk_all IS NOT NULL) AS fkpr,
       sum(fk_all) / nullif(sum(fk_all) + sum(fd_all), 0) AS opening_win_pct,  -- won ÷ all opening duels
       -- sample size per metric, shown beside every rate
       count(adr_all) AS adr_maps,  -- count(col) skips NULLs
       count(kast_all) AS kast_maps,
       count(fk_all) AS fk_maps,
       -- display only (S-09): never weighted
       sum(kills_all) / sum(rounds) FILTER (WHERE kills_all IS NOT NULL) AS kpr,
       sum(fd_all) / sum(rounds) FILTER (WHERE fd_all IS NOT NULL) AS fdpr,
       sum(acs_all * rounds) / sum(rounds) FILTER (WHERE acs_all IS NOT NULL) AS acs,
       sum(rating_all * rounds) / sum(rounds) FILTER (WHERE rating_all IS NOT NULL) AS rating,
       sum(hs_pct_all * rounds) / sum(rounds) FILTER (WHERE hs_pct_all IS NOT NULL) AS hs_pct,
       100 * sum(coalesce(clutch_1v1, 0) + coalesce(clutch_1v2, 0) + coalesce(clutch_1v3, 0)
                 + coalesce(clutch_1v4, 0) + coalesce(clutch_1v5, 0))  -- 0 inside a tracked map = no clutch
           / sum(rounds) FILTER (WHERE performance_available) AS clutches_per_100r,  -- only maps that track clutches
       cv(adr_all) AS cv_adr_2026
FROM f WHERE season = 2026 GROUP BY player_id;

-- cv2: CV over 2025–26; NULL without real 2025 history, so newer players are blank, not penalised.
CREATE OR REPLACE TEMP VIEW cv2 AS
SELECT player_id,
       count(adr_all) FILTER (WHERE season = 2025) AS adr_maps_2025,
       count(adr_all) AS cv_maps_2025_26,
       CASE WHEN count(adr_all) FILTER (WHERE season = 2025) >= 5 AND count(adr_all) >= 10  -- else it's the 2026 CV relabelled
            THEN cv(adr_all) END AS cv_adr_2025_26
FROM f WHERE season IN (2025, 2026) GROUP BY player_id;

-- pct: 0–100 rank within role, eligible only, so different units can be averaged. 100 = best.
-- ponytail: a NULL rate still occupies a row in its partition, slightly deflating percentiles; filtered rank if it matters.
CREATE OR REPLACE TEMP VIEW pct AS
SELECT player_id, primary_role,
       100 * percent_rank() OVER (PARTITION BY primary_role ORDER BY adr) AS adr,  -- within role: duelists vs duelists
       100 * percent_rank() OVER (PARTITION BY primary_role ORDER BY kast_pct) AS kast_pct,
       100 * percent_rank() OVER (PARTITION BY primary_role ORDER BY apr) AS apr,
       100 * percent_rank() OVER (PARTITION BY primary_role ORDER BY fkpr) AS fkpr,
       100 * percent_rank() OVER (PARTITION BY primary_role ORDER BY opening_win_pct) AS opening_win_pct,
       100 * percent_rank() OVER (PARTITION BY primary_role ORDER BY dpr DESC) AS dpr,  -- DESC: fewer deaths = better
       100 * percent_rank() OVER (PARTITION BY primary_role ORDER BY cv_adr_2026 DESC) AS cv_adr  -- DESC: steadier = better
FROM agg WHERE is_eligible;

-- composite: weighted mean of percentiles; only seed metrics count, which keeps Rating and ACS out (S-09).
CREATE OR REPLACE TEMP VIEW composite AS
SELECT l.player_id, sum(w.weight * l.pct) / sum(w.weight) AS composite  -- ÷ weights used: a missing metric isn't scored 0
FROM (UNPIVOT pct ON COLUMNS(* EXCLUDE (player_id, primary_role)) INTO NAME metric VALUE pct) l  -- long form to join weights
JOIN pct USING (player_id)
JOIN 'data/seeds/metric_weights.csv' w ON w.role = pct.primary_role AND w.metric = l.metric
WHERE l.pct IS NOT NULL
GROUP BY l.player_id;

-- mart_scouting.csv: one row per player; ineligible players kept with NULL percentiles and composite.
COPY (
    SELECT a.player_id, a.player_name, a.primary_role, a.regions, a.china_league,
           a.maps_played, a.rounds_played, a.is_eligible,
           round(c.composite, 1) AS composite,
           round(a.adr, 1) AS adr, round(a.kast_pct, 1) AS kast_pct, round(a.apr, 3) AS apr,
           round(a.dpr, 3) AS dpr, round(a.fkpr, 3) AS fkpr,
           round(a.opening_win_pct, 3) AS opening_win_pct,
           round(a.cv_adr_2026, 3) AS cv_adr_2026,
           round(v.cv_adr_2025_26, 3) AS cv_adr_2025_26, v.cv_maps_2025_26, v.adr_maps_2025,
           a.adr_maps, a.kast_maps, a.fk_maps,
           round(a.kpr, 3) AS kpr, round(a.fdpr, 3) AS fdpr, round(a.acs, 1) AS acs,
           round(a.rating, 2) AS rating, round(a.hs_pct, 1) AS hs_pct,
           round(a.clutches_per_100r, 2) AS clutches_per_100r,
           round(p.adr, 1) AS pct_adr, round(p.kast_pct, 1) AS pct_kast,
           round(p.apr, 1) AS pct_apr, round(p.dpr, 1) AS pct_dpr,
           round(p.fkpr, 1) AS pct_fkpr,
           round(p.opening_win_pct, 1) AS pct_opening_win,
           round(p.cv_adr, 1) AS pct_consistency
    FROM agg a
    LEFT JOIN cv2 v USING (player_id)
    LEFT JOIN pct p USING (player_id)  -- LEFT: ineligible players stay in the mart
    LEFT JOIN composite c USING (player_id)
    ORDER BY a.primary_role, c.composite DESC NULLS LAST, a.player_id  -- player_id: stable order across rebuilds
) TO 'data/marts/mart_scouting.csv' (HEADER);

-- mart_scouting_by_map.csv: the same rates per map, plus the player's map win rate.
COPY (
    SELECT player_id, any_value(player_name) AS player_name,
           any_value(primary_role) AS primary_role, map_name,
           count(*) AS maps_played, sum(rounds) AS rounds_played,
           round(sum(adr_all * rounds) / sum(rounds) FILTER (WHERE adr_all IS NOT NULL), 1) AS adr,
           round(sum(kast_all * rounds) / sum(rounds) FILTER (WHERE kast_all IS NOT NULL), 1) AS kast_pct,
           round(sum(fk_all) / sum(rounds) FILTER (WHERE fk_all IS NOT NULL), 3) AS fkpr,
           round(sum(fk_all) / nullif(sum(fk_all) + sum(fd_all), 0), 3) AS opening_win_pct,
           round(100.0 * count(*) FILTER (WHERE map_won) / count(*), 1) AS map_win_pct  -- his team's result: display only
    FROM f WHERE season = 2026 GROUP BY player_id, map_name ORDER BY player_id, map_name
) TO 'data/marts/mart_scouting_by_map.csv' (HEADER);
