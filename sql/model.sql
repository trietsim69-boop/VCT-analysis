-- Builds the star schema in data/processed/ from the raw snapshot.
-- Run:  python -m src.clean
--
-- Rules enforced here (docs/data_audit.md):
--   §0  matches.status = 'final' — the snapshot carries placeholder rows for unplayed fixtures
--   §4  NULL stays NULL; nothing is filled with 0
--   §4  agents[1] is read directly; never unnest (it would double-count maps in role share)

CREATE OR REPLACE TEMP TABLE roles AS FROM read_csv('data/seeds/agent_roles.csv');

-- One row per player x map x match, all seasons. The window filter lives in the marts, not here.
CREATE OR REPLACE TEMP VIEW fact AS
SELECT pm.* EXCLUDE (agents, team_idx),
       lower(pm.agents[1]) AS agent,
       m.event_id,
       year(m.utc_timestamp) AS season,
       m.utc_timestamp::DATE AS match_date,
       CASE WHEN pm.team_idx = 0 THEN m.team0_id ELSE m.team1_id END AS team_id,
       CASE WHEN pm.team_idx = 0 THEN m.team1_id ELSE m.team0_id END AS opponent_id,
       mp.map_name,
       rc.rounds,
       CASE WHEN pm.team_idx = 0 THEN mp.score0 > mp.score1 ELSE mp.score1 > mp.score0 END AS map_won,
       mp.performance_available,
       mp.economy_available
FROM player_map pm
JOIN matches m ON m.match_id = pm.match_id
JOIN maps mp ON mp.game_id = pm.game_id
LEFT JOIN (SELECT game_id, count(*) AS rounds FROM rounds GROUP BY 1) rc ON rc.game_id = pm.game_id
WHERE m.status = 'final';

COPY (FROM fact) TO 'data/processed/fact_player_map.csv' (HEADER);

-- primary_role: the role played on >= 60% of a player's 2026 maps, else Flex (S-08).
COPY (
    SELECT p.player_id, p.player_name, p.country,
           s.maps_2026, s.top_role, s.top_share,
           CASE WHEN s.maps_2026 IS NULL THEN NULL
                WHEN s.top_share >= 0.6 THEN s.top_role
                ELSE 'Flex' END AS primary_role
    FROM players p
    LEFT JOIN (
        SELECT player_id, sum(n) AS maps_2026,
               arg_max(role, n) AS top_role,
               max(n) / sum(n) AS top_share
        FROM (SELECT f.player_id, r.role, count(*) AS n
              FROM fact f LEFT JOIN roles r ON r.agent = f.agent
              WHERE f.season = 2026 AND r.role IS NOT NULL
              GROUP BY 1, 2)
        GROUP BY 1
    ) s USING (player_id)
) TO 'data/processed/dim_player.csv' (HEADER);

COPY (FROM teams) TO 'data/processed/dim_team.csv' (HEADER);
COPY (FROM roles) TO 'data/processed/dim_agent.csv' (HEADER);

COPY (
    SELECT DISTINCT m.event_id, m.event, m.event_slug,
           coalesce(m.region, 'International') AS region,
           m.is_international, year(m.utc_timestamp) AS season
    FROM matches m WHERE m.status = 'final'
) TO 'data/processed/dim_event.csv' (HEADER);

COPY (SELECT DISTINCT map_name FROM fact WHERE map_name IS NOT NULL ORDER BY 1)
TO 'data/processed/dim_map.csv' (HEADER);
