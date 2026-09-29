-- mart_budget_inputs.csv: per-candidate budget inputs (budget_model.md §5). Money lives in data/seeds/budget_scenarios.csv.

-- Player contracts per handle; n > 1 = the handle is on more than one row.
CREATE OR REPLACE TEMP VIEW gcd AS
SELECT lower(handle) AS h, count(*) AS n,
       any_value(league) AS league, any_value(team) AS team, any_value(contract_end_year) AS end_year
FROM 'data/processed/dim_contract_all.csv'
WHERE gcd_role LIKE '%PLAYER'  -- PLAYER, ACTIVE PLAYER, RESERVE PLAYER
GROUP BY 1;

-- Players sharing a name (Zeus, Klaus...): a contract can't be pinned to one of them.
CREATE OR REPLACE TEMP VIEW names AS
SELECT lower(trim(player_name)) AS h, count(*) AS n FROM 'data/processed/dim_player.csv' GROUP BY 1;

CREATE OR REPLACE TEMP VIEW matched AS
SELECT f.*,
       CASE WHEN g.h IS NULL THEN 'not found'
            WHEN g.n = 1 AND p.n = 1 THEN 'matched'
            ELSE 'ambiguous' END AS contract_match
FROM 'data/marts/mart_fit.csv' f
LEFT JOIN gcd g ON g.h = lower(trim(f.player_name))  -- case differs: Zmjjkk, Buzz, Primmie
JOIN names p ON p.h = lower(trim(f.player_name));

COPY (
    SELECT m.player_id, m.player_name, m.fit_score, m.is_import_for_sen, m.import_source,
           g.league AS contract_league, g.team AS contract_team, g.end_year AS contract_end_year,  -- NULL unless matched
           greatest(0, coalesce(g.end_year - 2026, 2)) AS years_left,  -- 2026 ends = free agent; unknown = 2 (full buyout). greatest() skips NULLs, so coalesce inside
           m.contract_match
    FROM matched m
    LEFT JOIN gcd g ON g.h = lower(trim(m.player_name)) AND m.contract_match = 'matched'
    ORDER BY m.fit_score DESC, m.player_id
) TO 'data/marts/mart_budget_inputs.csv' (HEADER);
