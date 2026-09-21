-- Re-derives every figure in docs/data_audit.md and writes each result to data/audit/*.csv.
-- Run from the repo root:  python -m src.export
-- Open the CSVs in Excel, or paste any query below into DuckDB/DBeaver to explore.

CREATE OR REPLACE TEMP TABLE roles AS FROM read_csv('data/seeds/agent_roles.csv');

-- The working fact: one row per player x map, 2026, completed matches only (data_audit.md §0).
CREATE OR REPLACE TEMP VIEW pm26 AS
SELECT m.match_id, pm.game_id, m.url AS match_url, m.utc_timestamp::DATE AS match_date, m.event,
       COALESCE(m.region, 'International') AS region, mp.map_name,
       pm.player_id, p.player_name, t.team_name AS team, o.team_name AS opponent,
       pm.agents[1] AS agent, r.role, rc.rounds,
       CASE WHEN pm.team_idx = 0 THEN mp.score0 > mp.score1 ELSE mp.score1 > mp.score0 END AS map_won,
       mp.performance_available,
       pm.rating_all, pm.acs_all, pm.adr_all, pm.kills_all, pm.deaths_all, pm.assists_all,
       pm.kast_all, pm.fk_all, pm.fd_all, pm.hs_pct_all
FROM player_map pm
JOIN matches m ON m.match_id = pm.match_id
JOIN maps mp ON mp.game_id = pm.game_id
JOIN players p ON p.player_id = pm.player_id
LEFT JOIN teams t ON t.team_id = CASE WHEN pm.team_idx = 0 THEN m.team0_id ELSE m.team1_id END
LEFT JOIN teams o ON o.team_id = CASE WHEN pm.team_idx = 0 THEN m.team1_id ELSE m.team0_id END
LEFT JOIN roles r ON r.agent = lower(pm.agents[1])
LEFT JOIN (SELECT game_id, count(*) AS rounds FROM rounds GROUP BY 1) rc ON rc.game_id = pm.game_id
WHERE m.status = 'final' AND year(m.utc_timestamp) = 2026;

COPY (FROM pm26 ORDER BY match_date, match_id, game_id, team, player_name)
TO 'data/audit/player_map_2026.csv' (HEADER);

-- §0/§1 matches per season, all vs completed
COPY (SELECT year(utc_timestamp) AS season, count(*) AS matches,
             count(*) FILTER (WHERE status = 'final') AS completed
      FROM matches GROUP BY 1 ORDER BY 1)
TO 'data/audit/01_matches_by_season.csv' (HEADER);

-- §0 the unplayed fixtures the status filter removes
COPY (SELECT match_id, event, utc_timestamp::DATE AS scheduled, listing_status, url
      FROM matches WHERE year(utc_timestamp) = 2026 AND status IS DISTINCT FROM 'final' ORDER BY 3)
TO 'data/audit/02_unplayed_2026.csv' (HEADER);

-- §1 stat availability by region, 2026 completed maps
COPY (SELECT COALESCE(m.region, 'International') AS region, count(*) AS maps,
             round(100 * avg(mp.performance_available::INT), 1) AS performance_pct,
             round(100 * avg(mp.economy_available::INT), 1) AS economy_pct
      FROM maps mp JOIN matches m USING (match_id)
      WHERE m.status = 'final' AND year(m.utc_timestamp) = 2026 GROUP BY 1 ORDER BY 1)
TO 'data/audit/03_coverage_by_region.csv' (HEADER);

-- §2 SEN maps per player per role
COPY (SELECT player_name, role, count(*) AS maps, min(match_date) AS first_map, max(match_date) AS last_map
      FROM pm26 WHERE team = 'Sentinels' GROUP BY 1, 2 ORDER BY 1, 3 DESC)
TO 'data/audit/04_sen_roles.csv' (HEADER);

-- §2 slot baseline, round-weighted
COPY (SELECT player_name, count(*) AS maps, sum(rounds) AS rounds,
             round(sum(adr_all * rounds) / sum(rounds), 1) AS adr,
             round(sum(kast_all * rounds) / sum(rounds), 1) AS kast_pct,
             round(100 * sum(fk_all) / sum(rounds), 2) AS fk_per_100r,
             round(100 * sum(fd_all) / sum(rounds), 2) AS fd_per_100r,
             round(100 * sum(fk_all) / (sum(fk_all) + sum(fd_all)), 1) AS opening_win_pct
      FROM pm26 WHERE team = 'Sentinels' AND role = 'duelist' GROUP BY 1 ORDER BY 2 DESC)
TO 'data/audit/05_sen_slot_baseline.csv' (HEADER);

-- §3 duelist pool: every player with >= 60% duelist maps.
-- Each rate's denominator only counts rounds on maps where that stat exists (NULL stays NULL, data_audit.md §4).
COPY (SELECT player_name, string_agg(DISTINCT team, ' / ') AS teams, any_value(region) AS region,
             count(*) AS maps, sum(rounds) AS rounds,
             count(adr_all) AS adr_maps,
             round(avg((role = 'duelist')::INT), 2) AS duelist_share,
             count(*) >= 15 AS eligible,
             round(sum(adr_all * rounds) / sum(rounds) FILTER (WHERE adr_all IS NOT NULL), 1) AS adr,
             round(sum(kast_all * rounds) / sum(rounds) FILTER (WHERE kast_all IS NOT NULL), 1) AS kast_pct,
             round(sum(kills_all) / sum(rounds) FILTER (WHERE kills_all IS NOT NULL), 3) AS kpr,
             round(100 * sum(fk_all) / sum(rounds) FILTER (WHERE fk_all IS NOT NULL), 2) AS fk_per_100r,
             round(100 * sum(fd_all) / sum(rounds) FILTER (WHERE fd_all IS NOT NULL), 2) AS fd_per_100r
      FROM pm26 GROUP BY player_id, player_name
      HAVING avg((role = 'duelist')::INT) >= 0.6
      ORDER BY eligible DESC, adr DESC NULLS LAST)
TO 'data/audit/06_duelist_pool.csv' (HEADER);

-- §4 null % of the ranking columns by region. performance_available is NOT used: it flags
-- vlr.gg's Performance tab (multi-kills, clutches, kill_matrix), not these overview stats.
COPY (SELECT region, count(*) AS rows,
             round(100 * avg((kills_all IS NULL)::INT), 1) AS kills_all,
             round(100 * avg((acs_all IS NULL)::INT), 1) AS acs_all,
             round(100 * avg((adr_all IS NULL)::INT), 1) AS adr_all,
             round(100 * avg((kast_all IS NULL)::INT), 1) AS kast_all,
             round(100 * avg((fk_all IS NULL)::INT), 1) AS fk_all,
             round(100 * avg((rating_all IS NULL)::INT), 1) AS rating_all,
             round(100 * avg((agent IS NULL)::INT), 1) AS agent,
             round(100 * avg((rounds IS NULL)::INT), 1) AS rounds,
             round(100 * avg((NOT performance_available)::INT), 1) AS no_performance_tab
      FROM pm26 GROUP BY ROLLUP (region) ORDER BY region NULLS LAST)
TO 'data/audit/07_null_rates.csv' (HEADER);
