"""Data tests for the Tableau-ready files (build first: python -m src.marts).
They must agree with the marts Power BI reads, so the two tools show the same numbers."""

import duckdb
import pytest

CAND = "'data/marts/tableau_candidates.csv'"
MAPS = "'data/marts/tableau_maps.csv'"
PCT = "'data/marts/tableau_percentiles.csv'"
SHORTLIST = {"Meiy", "swagzor", "Derke", "ZmjjKK", "primmie", "BuZz", "dgzin", "OXY", "Wo0t", "Timotino"}


@pytest.fixture(scope="module")
def con():
    return duckdb.connect()


def band(rank, n):
    """The DAX rule (powerbi/dax_measures.md §3 and §7): a band, not a position."""
    if rank <= 10:
        return f"Top 10 of {n}"
    if rank <= 25:
        return f"Top 25 of {n}"
    return f"Top half of {n}" if rank <= n / 2 else f"Bottom half of {n}"


def test_one_row_per_fit_candidate(con):
    n, distinct = con.execute(f"SELECT count(*), count(DISTINCT player_id) FROM {CAND}").fetchone()
    assert n == distinct == con.execute("SELECT count(*) FROM 'data/marts/mart_fit.csv'").fetchone()[0]
    assert con.execute(f"SELECT count(*) FROM {CAND} WHERE is_baseline").fetchone()[0] == 1  # Jerrwin


@pytest.mark.parametrize("score, band_col", [("composite", "composite_band"), ("fit_score", "fit_band")])
def test_bands_follow_the_power_bi_rule(con, score, band_col):
    rows = con.execute(f"SELECT {score}, {band_col} FROM {CAND}").fetchall()
    scores = [s for s, _ in rows]
    for s, b in rows:
        assert b == band(sum(x > s for x in scores) + 1, len(rows))  # rank = players above + 1, so ties share a band


def test_band_boundaries_match_power_bi(con):
    """The cases checked by hand in Power BI: splash/swagzor (T5), Wo0t, Timotino/aspas (T7)."""
    got = dict(con.execute(f"""SELECT player_name, composite_band || ' | ' || fit_band FROM {CAND}
        WHERE player_name IN ('splash', 'swagzor', 'Wo0t', 'Timotino', 'aspas')""").fetchall())
    assert got["splash"].startswith("Top 10") and got["swagzor"].startswith("Top 25")
    assert got["Wo0t"].endswith("Top 10 of 84") and got["Timotino"].endswith("Top 10 of 84")
    assert got["aspas"].endswith("Top 25 of 84")


def test_shortlist_is_the_top_fit_band(con):
    assert {r[0] for r in con.execute(f"SELECT player_name FROM {CAND} WHERE is_shortlist").fetchall()} == SHORTLIST


def test_fit_points_add_up_to_the_fit_score(con):
    worst = con.execute(f"""SELECT max(abs(fit_pts_performance + fit_pts_agent_overlap + fit_pts_map_fit - fit_score))
        FROM {CAND}""").fetchone()[0]
    assert worst <= 0.15  # three components rounded to 0.1


def test_break_even_is_the_base_partner_reference(con):
    assert con.execute(f"""SELECT count(*) FROM {CAND} c JOIN 'data/marts/mart_budget_reference.csv' r
        ON r.player_id = c.player_id AND r.scenario = 'base' AND r.partner
        WHERE c.break_even_base <> r.k_star_pct OR c.upfront_base <> r.upfront""").fetchone()[0] == 0
    assert con.execute(f"SELECT break_even_base, upfront_base FROM {CAND} WHERE player_name = 'dgzin'").fetchone() == (23.8, 150000)


def test_maps_cover_every_candidate_and_sen_map(con):
    n_cand = con.execute(f"SELECT count(*) FROM {CAND}").fetchone()[0]
    assert con.execute(f"SELECT count(*), count(DISTINCT map_name) FROM {MAPS}").fetchone() == (n_cand * 12, 12)
    assert con.execute(f"SELECT DISTINCT sum(sen_games) FROM {MAPS} GROUP BY player_id").fetchall() == [(40,)]
    assert con.execute(f"SELECT count(*) FROM {MAPS} WHERE adr = 0 OR adr_maps = 0 AND adr IS NOT NULL").fetchone()[0] == 0  # blank, never 0


def test_map_numbers_match_the_power_bi_heatmap(con):
    """Meiy's rows as verified on Candidate Fit (powerbi/dax_measures.md §7)."""
    got = {r[0]: r[1:] for r in con.execute(f"""SELECT map_name, adr, adr_rounds, pool_adr, low_sample
        FROM {MAPS} WHERE player_name = 'Meiy' AND map_name IN ('Breeze', 'Split', 'Summit')""").fetchall()}
    assert got["Breeze"] == (147.9, 102, 138.9, False)
    assert got["Split"] == (178.6, 160, 138.8, False)
    assert got["Summit"][1] == 20 and got["Summit"][3] is True  # 1 map: greyed


def test_percentiles_are_the_scouting_mart_in_long_form(con):
    assert con.execute(f"SELECT count(*), count(DISTINCT metric) FROM {PCT}").fetchone() == (84 * 7, 7)
    assert con.execute(f"""SELECT count(*) FROM {PCT} l JOIN 'data/marts/mart_scouting.csv' s USING (player_id)
        WHERE l.metric = 'pct_adr' AND l.percentile <> s.pct_adr""").fetchone()[0] == 0
    weights = con.execute(f"SELECT sum(DISTINCT composite_weight), count(DISTINCT metric) FILTER (WHERE composite_weight IS NULL) FROM {PCT}").fetchone()
    assert con.execute(f"SELECT round(sum(composite_weight), 4) FROM {PCT} WHERE player_name = 'Meiy'").fetchone()[0] == 1.0
    assert weights[1] == 1  # assists per round: shown, not weighted for duelists
