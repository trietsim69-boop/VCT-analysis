"""Data tests for data/marts/ (build it first: python -m src.marts)."""

import duckdb
import pytest

WEIGHTS = "'data/seeds/metric_weights.csv'"

# Column names the marts must produce. A typo in the seed fails here, not silently at percentile time.
METRICS = {"adr", "kast_pct", "apr", "dpr", "fkpr", "opening_win_pct", "cv_adr"}
ROLES = {"duelist", "initiator", "controller", "sentinel", "Flex"}


@pytest.fixture(scope="module")
def con():
    return duckdb.connect()


def q(con, sql):
    return con.execute(sql).fetchone()[0]


def test_weights_sum_to_one_per_role(con):
    bad = con.execute(f"""SELECT role, round(sum(weight), 4) FROM {WEIGHTS}
        GROUP BY 1 HAVING round(sum(weight), 4) <> 1.0""").fetchall()
    assert not bad, f"weights do not sum to 1: {bad}"


def test_weights_cover_every_role(con):
    assert {r for (r,) in con.execute(f"SELECT DISTINCT role FROM {WEIGHTS}").fetchall()} == ROLES


def test_weight_metrics_are_known(con):
    used = {m for (m,) in con.execute(f"SELECT DISTINCT metric FROM {WEIGHTS}").fetchall()}
    assert used <= METRICS, f"unknown metric in the seed: {used - METRICS}"


def test_no_display_only_metric_is_weighted(con):
    """Rating and ACS are display-only (S-09) and must never reach the composite."""
    used = {m for (m,) in con.execute(f"SELECT DISTINCT metric FROM {WEIGHTS}").fetchall()}
    assert not used & {"rating", "rating_all", "acs", "acs_all", "hs_pct"}


MART = "'data/marts/mart_scouting.csv'"
BY_MAP = "'data/marts/mart_scouting_by_map.csv'"


def test_weighted_adr_matches_hand_calculation(con):
    """Recompute one player's ADR with pandas instead of the mart SQL."""
    fact = con.execute("""SELECT adr_all, rounds FROM 'data/processed/fact_player_map.csv'
        WHERE season = 2026 AND player_id = (SELECT player_id FROM """ + MART + """
        WHERE player_name = 'Jerrwin')""").df().dropna()
    by_hand = (fact.adr_all * fact.rounds).sum() / fact.rounds.sum()
    assert q(con, f"SELECT adr FROM {MART} WHERE player_name = 'Jerrwin'") == round(by_hand, 1)


def test_adr_ignores_maps_without_adr(con):
    """A China player's ADR divides by its own maps, not maps_played (the NULL rule)."""
    maps, adr_maps = con.execute(f"""SELECT maps_played, adr_maps FROM {MART}
        WHERE player_name = 'ZmjjKK'""").fetchone()
    assert adr_maps < maps


def test_percentiles_in_range_and_eligible_only(con):
    assert q(con, f"""SELECT count(*) FROM {MART}
        WHERE pct_adr NOT BETWEEN 0 AND 100 OR pct_consistency NOT BETWEEN 0 AND 100""") == 0
    # ineligible players get NULL, never 0
    assert q(con, f"SELECT count(*) FROM {MART} WHERE NOT is_eligible AND composite IS NOT NULL") == 0
    assert q(con, f"SELECT count(*) FROM {MART} WHERE is_eligible AND composite IS NULL") == 0


def test_two_season_cv_needs_real_2025_history(con):
    """Without 2025 maps it would just be the 2026 CV relabelled, so it must be NULL."""
    assert q(con, f"""SELECT count(*) FROM {MART}
        WHERE cv_adr_2025_26 IS NOT NULL AND coalesce(adr_maps_2025, 0) < 5""") == 0
    assert q(con, f"SELECT count(*) FROM {MART} WHERE is_eligible AND cv_adr_2025_26 IS NULL") > 0


def test_by_map_rounds_sum_to_the_main_mart(con):
    assert q(con, f"""SELECT count(*) FROM (
        SELECT player_id, sum(rounds_played) r FROM {BY_MAP} GROUP BY 1) b
        JOIN {MART} m USING (player_id) WHERE b.r <> m.rounds_played""") == 0


def test_composite_is_not_sensitive_to_the_weights(con):
    """Shortlist membership must not hinge on the weighting (kpi_dictionary.md § Composite weights)."""
    r = q(con, f"""SELECT corr(composite, (pct_adr + pct_kast + pct_fkpr + pct_opening_win
            + pct_dpr + pct_consistency) / 6.0)
        FROM {MART} WHERE primary_role = 'duelist' AND is_eligible""")
    assert r > 0.9, f"composite correlates only {r:.3f} with equal weights"
