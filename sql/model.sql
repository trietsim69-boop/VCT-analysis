-- Builds the star schema in data/processed/ from the raw snapshot.
-- Run:  python -m src.clean
--
-- Rules enforced here (docs/data_audit.md):
--   §0  matches.status = 'final' — the snapshot carries placeholder rows for unplayed fixtures
--   §4  NULL stays NULL; nothing is filled with 0
--   §4  agents[1] is read directly; never unnest (it would double-count maps in role share)

-- roles: the agent -> role lookup, hand-maintained. The source data has no role field, so
-- this seed is what makes any role analysis possible. A new agent must be added here.
CREATE OR REPLACE TEMP TABLE roles AS FROM read_csv('data/seeds/agent_roles.csv');

-- fact: one row per player x map, all seasons, completed matches only. Flattens the agent
-- array to a scalar, attaches the round count that every rate divides by, and works out which
-- side the player was on. Deliberately unfiltered by season — the marts pick their own window.
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

-- fact_player_map.csv: the main analysis table everything else is built from.
COPY (FROM fact) TO 'data/processed/fact_player_map.csv' (HEADER);

-- dim_player.csv: one row per player, carrying primary_role — the role played on >= 60% of
-- their 2026 maps, else Flex (S-08). top_role and top_share are kept so the call is auditable.
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

-- dim_team.csv: every team, straight from the source. Joins on both team_id and opponent_id.
COPY (FROM teams) TO 'data/processed/dim_team.csv' (HEADER);

-- dim_agent.csv: the agent -> role seed above, published so the BI tools can slice by role.
COPY (FROM roles) TO 'data/processed/dim_agent.csv' (HEADER);

-- dim_event.csv: one row per event. Region is where 'International' comes from — the source
-- leaves it NULL on international events rather than recording a region.
COPY (
    SELECT DISTINCT m.event_id, m.event, m.event_slug,
           coalesce(m.region, 'International') AS region,
           m.is_international, year(m.utc_timestamp) AS season
    FROM matches m WHERE m.status = 'final'
) TO 'data/processed/dim_event.csv' (HEADER);

-- dim_contract_americas.csv: Riot's Global Contract Database, Americas tab (B2), one row per
-- listed handle. Residency here is Riot's own call — it is NOT nationality (Jerrwin is Indian
-- and Resident). Header is on row 2; blank spacer rows are dropped. Newest gcd_*.xlsx is used.
COPY (
    SELECT "Team" AS team, "Official Tournament Handle" AS handle, "Role" AS gcd_role,
           try_cast(try_cast("End Date (Month Day, Year)" AS DOUBLE) AS INT) AS contract_end_year,
           "Resident Status" AS resident_status, "Roster Status" AS roster_status
    FROM read_xlsx(getvariable('gcd'), sheet = 'AMERICAS', range = 'A2:I500', all_varchar = true)
    WHERE "Official Tournament Handle" IS NOT NULL
) TO 'data/processed/dim_contract_americas.csv' (HEADER);

-- dim_map.csv: the 13 map names, for slicers.
COPY (SELECT DISTINCT map_name FROM fact WHERE map_name IS NOT NULL ORDER BY 1)
TO 'data/processed/dim_map.csv' (HEADER);
