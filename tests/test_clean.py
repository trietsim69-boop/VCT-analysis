"""Data tests for data/processed/ (build it first: python -m src.clean)."""

import duckdb
import pytest

FACT = "'data/processed/fact_player_map.parquet'"
PLAYER = "'data/processed/dim_player.parquet'"


@pytest.fixture(scope="module")
def con():
    return duckdb.connect()


def q(con, sql):
    return con.execute(sql).fetchone()[0]


def test_grain_is_unique(con):
    """One row per player x map."""
    assert q(con, f"SELECT count(*) - count(DISTINCT (player_id, game_id)) FROM {FACT}") == 0


def test_no_unplayed_fixtures_leaked(con):
    """Placeholder rows for scheduled matches are all-NULL (data_audit.md §0)."""
    assert q(con, f"SELECT count(*) FROM {FACT} WHERE kills_all IS NULL") == 0


def test_row_count_matches_audit(con):
    """15,020 player-maps in 2026, per data_audit.md §4. Later snapshots add Champions rows."""
    assert q(con, f"SELECT count(*) FROM {FACT} WHERE season = 2026") >= 15_020


def test_nulls_are_preserved_not_zeroed(con):
    """China is missing ADR on ~15% of rows; those must stay NULL, never 0."""
    assert q(con, f"SELECT count(*) FROM {FACT} WHERE season = 2026 AND adr_all IS NULL") > 0
    assert q(con, f"SELECT count(*) FROM {FACT} WHERE adr_all = 0") == 0


def test_every_agent_maps_to_a_role(con):
    unmapped = q(con, f"""SELECT count(DISTINCT f.agent) FROM {FACT} f
        LEFT JOIN 'data/processed/dim_agent.parquet' a ON a.agent = f.agent
        WHERE f.agent IS NOT NULL AND a.role IS NULL""")
    assert unmapped == 0


def test_agent_is_scalar(con):
    """agents[1] is read directly; a map with two agents would break role share (data_audit.md §4)."""
    assert q(con, f"SELECT count(*) FROM {FACT} WHERE season = 2026 AND agent IS NULL") == 0


@pytest.mark.parametrize("player,role", [
    ("Jerrwin", "duelist"),     # 30/30 duelist maps — the vacant slot
    ("JonahP", "initiator"),    # 32/32
    ("Reduxx", "Flex"),         # 57% duelist, below the 60% bar (S-08)
])
def test_primary_role(con, player, role):
    assert q(con, f"SELECT primary_role FROM {PLAYER} WHERE player_name = '{player}'") == role
