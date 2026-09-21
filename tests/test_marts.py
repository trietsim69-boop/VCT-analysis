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
