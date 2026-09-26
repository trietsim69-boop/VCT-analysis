"""Data tests for the roster-fit marts (build first: python -m src.marts)."""

import duckdb
import pytest

FIT = "'data/marts/mart_fit.csv'"
TEAM = "'data/marts/mart_team_profile.csv'"
FACT = "'data/processed/fact_player_map.csv'"
JERRWIN, SEN = 34057, 2


@pytest.fixture(scope="module")
def con():
    return duckdb.connect()


def q(con, sql):
    return con.execute(sql).fetchone()[0]


def test_fit_weights_sum_to_one_and_name_real_components(con):
    rows = dict(con.execute("SELECT component, weight FROM 'data/seeds/fit_weights.csv'").fetchall())
    assert round(sum(rows.values()), 4) == 1.0
    assert set(rows) == {"performance", "agent_overlap", "map_fit"}


def test_one_row_per_eligible_duelist(con):
    assert q(con, f"SELECT count(*) = count(DISTINCT player_id) FROM {FIT}")
    assert q(con, f"SELECT count(*) FROM {FIT}") == q(con, """SELECT count(*) FROM
        'data/marts/mart_scouting.csv' WHERE primary_role = 'duelist' AND is_eligible""")
    assert q(con, f"SELECT count(*) FROM {FIT} WHERE fit_score NOT BETWEEN 0 AND 100") == 0


def test_baseline_compared_with_itself_is_zero(con):
    """Jerrwin is the baseline: every delta is 0, and he covers his own agents fully."""
    row = con.execute(f"""SELECT delta_adr, delta_kast_pct, delta_fkpr, delta_opening_win_pct,
        delta_dpr, delta_cv_adr_2026, agent_overlap_pct FROM {FIT} WHERE player_id = {JERRWIN}""").fetchone()
    assert row == (0, 0, 0, 0, 0, 0, 100)


def test_agent_overlap_matches_hand_calculation(con):
    """primmie, by hand: slot maps are Jerrwin's on SEN by agent; count those on agents
    primmie has played >= 3 times."""
    slot = dict(con.execute(f"""SELECT agent, count(*) FROM {FACT}
        WHERE season = 2026 AND player_id = {JERRWIN} AND team_id = {SEN} GROUP BY 1""").fetchall())
    his = dict(con.execute(f"""SELECT agent, count(*) FROM {FACT} WHERE season = 2026
        AND player_id = (SELECT player_id FROM {FIT} WHERE player_name = 'primmie') GROUP BY 1""").fetchall())
    by_hand = 100 * sum(n for a, n in slot.items() if his.get(a, 0) >= 3) / sum(slot.values())
    assert q(con, f"SELECT agent_overlap_pct FROM {FIT} WHERE player_name = 'primmie'") == round(by_hand, 1)


def test_map_fit_is_not_overall_adr_again(con):
    """The first cut correlated 0.96 with overall ADR, double-counting it (kpi_dictionary § D)."""
    assert abs(q(con, f"SELECT corr(map_adr_delta, delta_adr) FROM {FIT}")) < 0.5


def test_import_flag_uses_contract_database_first(con):
    """Jerrwin is Indian but Americas Resident per Riot: nationality must not override that."""
    assert con.execute(f"""SELECT is_import_for_sen, import_source FROM {FIT}
        WHERE player_id = {JERRWIN}""").fetchone() == (False, "contract database")
    assert q(con, f"SELECT count(*) FROM {FIT} WHERE (is_import_for_sen IS NULL) <> (import_source IS NULL)") == 0


def test_team_profile_counts_each_game_once(con):
    """The fact has five SEN rows per game; the profile must count the game, not the rows."""
    games = q(con, f"SELECT count(DISTINCT game_id) FROM {FACT} WHERE season = 2026 AND team_id = {SEN}")
    assert q(con, f"SELECT sum(games) FROM {TEAM}") == games
    assert q(con, f"SELECT count(*) FROM {TEAM} WHERE wins > games") == 0


def test_fit_is_not_sensitive_to_the_weights(con):
    r = q(con, f"""SELECT corr(fit_score, (pct_performance + agent_overlap_pct + pct_map_fit) / 3.0)
        FROM {FIT}""")
    assert r > 0.9, f"fit correlates only {r:.3f} with equal weights"
