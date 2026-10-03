-- Tableau-ready files (T10). Tableau can't reuse the Power BI DAX, so the bands, the long-format
-- percentiles and the Base break-even are computed here. Everything is read from the tested marts,
-- so Tableau and Power BI agree by construction. Runs after mart_fit.sql on the same connection and
-- reuses its views pool, cand_map, pool_map and sen_maps.

-- A band, not a position (kpi_dictionary.md): the same rule as the DAX Composite Band and Fit Band.
CREATE OR REPLACE TEMP MACRO band(r, n) AS
    CASE WHEN r <= 10 THEN 'Top 10 of ' || n
         WHEN r <= 25 THEN 'Top 25 of ' || n
         WHEN r <= n / 2 THEN 'Top half of ' || n
         ELSE 'Bottom half of ' || n END;

-- cand: one row per eligible duelist with everything the story needs.
CREATE OR REPLACE TEMP TABLE cand AS
SELECT p.player_id, p.player_name, p.regions, f.country,
       p.maps_played, p.rounds_played, p.adr, p.adr_maps, p.kast_pct, p.fkpr, p.fdpr,
       round(p.fkpr - p.fdpr, 3) AS fk_fd_per_round,  -- opening kills minus opening deaths, per round
       p.opening_win_pct, p.dpr, p.cv_adr_2026,
       p.composite,
       band(rank() OVER (ORDER BY p.composite DESC), count(*) OVER ()) AS composite_band,
       f.fit_score,
       band(rank() OVER (ORDER BY f.fit_score DESC), count(*) OVER ()) AS fit_band,
       f.pct_performance, f.agent_overlap_pct, f.pct_map_fit, f.map_adr_delta, f.map_coverage_pct,
       -- points each component adds to the fit score, for a stacked bar (they sum to fit_score ± rounding)
       round(f.pct_performance * (SELECT weight FROM 'data/seeds/fit_weights.csv' WHERE component = 'performance'), 1) AS fit_pts_performance,
       round(f.agent_overlap_pct * (SELECT weight FROM 'data/seeds/fit_weights.csv' WHERE component = 'agent_overlap'), 1) AS fit_pts_agent_overlap,
       round(f.pct_map_fit * (SELECT weight FROM 'data/seeds/fit_weights.csv' WHERE component = 'map_fit'), 1) AS fit_pts_map_fit,
       f.is_import_for_sen, f.import_source,
       b.contract_team, b.contract_end_year, b.years_left, b.contract_match,
       r.upfront::BIGINT AS upfront_base,  -- Base scenario, SEN a partner (budget_model.md)
       r.k_star_pct AS break_even_base,  -- points of top-3 chance the signing must add
       CASE WHEN b.contract_match <> 'matched' THEN 'Contract unknown (2 years assumed)'
            WHEN b.years_left = 0 THEN 'Free agent'
            ELSE 'Under contract, ' || b.years_left || CASE WHEN b.years_left = 1 THEN ' year left' ELSE ' years left' END END
         || CASE WHEN f.is_import_for_sen THEN ' · needs the import slot' ELSE ' · resident' END AS cost_group,
       p.player_id = getvariable('baseline') AS is_baseline  -- Jerrwin
FROM pool p
JOIN 'data/marts/mart_fit.csv' f USING (player_id)
JOIN 'data/marts/mart_budget_inputs.csv' b USING (player_id)
JOIN 'data/marts/mart_budget_reference.csv' r ON r.player_id = p.player_id AND r.scenario = 'base' AND r.partner;

-- tableau_candidates.csv: 84 duelists. is_shortlist = the top-10 fit band (S-20).
COPY (
    SELECT *, fit_band LIKE 'Top 10 of%' AS is_shortlist FROM cand ORDER BY fit_score DESC, player_id
) TO 'data/marts/tableau_candidates.csv' (HEADER);

-- tableau_maps.csv: every candidate x every SEN map, blank where he hasn't played it.
COPY (
    SELECT c.player_id, c.player_name, c.fit_band, c.fit_band LIKE 'Top 10 of%' AS is_shortlist, c.is_baseline,
           s.map_name, s.games AS sen_games, s.win_pct AS sen_win_pct, s.rounds AS sen_rounds,
           round(m.adr, 1) AS adr, m.adr_maps, m.adr_rounds,  -- sample size beside the rate
           round(pm.pool_adr, 1) AS pool_adr,  -- round-weighted ADR of the 84 on that map
           round(m.adr - pm.pool_adr, 1) AS adr_vs_pool,
           m.adr_maps < 3 AS low_sample  -- greyed in Power BI under 3 maps
    FROM cand c CROSS JOIN sen_maps s
    LEFT JOIN cand_map m ON m.player_id = c.player_id AND m.map_name = s.map_name  -- LEFT: unplayed map keeps its row
    JOIN pool_map pm ON pm.map_name = s.map_name
    ORDER BY c.fit_score DESC, c.player_id, s.games DESC, s.map_name
) TO 'data/marts/tableau_maps.csv' (HEADER);

-- tableau_percentiles.csv: the percentile profile in long form (Tableau wants one row per bar).
COPY (
    SELECT c.player_id, c.player_name, c.fit_band, c.fit_band LIKE 'Top 10 of%' AS is_shortlist, c.is_baseline,
           l.metric, x.label AS metric_label, l.percentile,
           w.weight AS composite_weight  -- NULL = shown, not weighted for duelists
    FROM (UNPIVOT (SELECT player_id, COLUMNS('^pct_') FROM pool)
          ON COLUMNS('^pct_') INTO NAME metric VALUE percentile) l
    JOIN cand c USING (player_id)
    JOIN (VALUES ('pct_adr', 'adr', 'Damage per round (ADR)'),
                 ('pct_kast', 'kast_pct', 'KAST %'),
                 ('pct_fkpr', 'fkpr', 'Opening kills per round'),
                 ('pct_opening_win', 'opening_win_pct', 'Opening duel win %'),
                 ('pct_dpr', 'dpr', 'Deaths per round (fewer = higher)'),
                 ('pct_consistency', 'cv_adr', 'Consistency of ADR (steadier = higher)'),
                 ('pct_apr', 'apr', 'Assists per round')) x(metric, weight_key, label) USING (metric)
    LEFT JOIN 'data/seeds/metric_weights.csv' w ON w.role = 'duelist' AND w.metric = x.weight_key
    ORDER BY c.fit_score DESC, c.player_id, w.weight DESC NULLS LAST, l.metric
) TO 'data/marts/tableau_percentiles.csv' (HEADER);
