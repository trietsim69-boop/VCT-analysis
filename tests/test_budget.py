"""Budget model tests: the worked cases in budget_model.md §8, plus seed and mart checks
(build first: python -m src.marts)."""

import csv
import re
from pathlib import Path

import duckdb
import pytest

from src.budget import evaluate, half_up, load_scenarios

S = load_scenarios()
BASE = S["base"]
INPUTS = "'data/marts/mart_budget_inputs.csv'"


# case: (scenario, overrides, partner, years_left, is_import) -> (npv, u_star, k_star_pct, payback, max_upfront, decision)
CASES = {
    "1 Derke base": (("base", {}, True, 0, True), (-68715, 262267, 23.8, 3.0, 81285, "Stay")),
    "2 OXY base": (("base", {}, True, 2, False), (-218715, 354535, 32.2, 6.0, 81285, "Stay")),
    "3 Timotino non-partner": (("base", {}, False, 1, False), (-263800, 262267, 52.5, None, 0, "Stay")),
    "4 Meiy downside": (("downside", {}, True, 1, True), (-1330840, 948194, 395.1, None, 0, "Stay")),
    "5 primmie upside": (("upside", {}, True, 0, True), (1939463, 55000, 1.6, 0.0, 1939463, "Sign")),
    "6 resident FA r=0": (("base", {"F-11": 0}, True, 0, False), (100000, 170000, 15.5, 0.0, 100000, "Sign")),
    "7 OXY r=0": (("base", {"F-11": 0}, True, 2, False), (-200000, 320000, 29.1, 6.0, 100000, "Stay")),
    "8 Derke Y=1": (("base", {"F-04": 1}, True, 0, True), (-106522, 342500, 31.1, 3.0, 43478, "Stay")),
}


def run(scenario, overrides, partner, years_left, is_import):
    return evaluate({**S[scenario], **overrides}, years_left, is_import, partner)


@pytest.mark.parametrize("case", CASES)
def test_worked_cases_match_spec(case):
    args, expected = CASES[case]
    r = run(*args)
    assert (r["npv"], r["u_star"], r["k_star_pct"], r["payback_years"], r["max_upfront"], r["decision"]) == expected


def test_total_costs_match_spec():
    assert (run(*CASES["1 Derke base"][0])["tac"], run(*CASES["1 Derke base"][0])["incremental_cost"]) == (590000, 490000)
    assert (run(*CASES["2 OXY base"][0])["tac"], run(*CASES["2 OXY base"][0])["incremental_cost"]) == (740000, 640000)
    assert run(*CASES["4 Meiy downside"][0])["tac"] == 1695000
    assert run(*CASES["5 primmie upside"][0])["tac"] == 210000


def test_flags():
    """Case 1 pays back in 3 years on a 2-year deal; case 4 needs 395% credit."""
    assert not run(*CASES["1 Derke base"][0])["payback_within_contract"]
    assert run(*CASES["5 primmie upside"][0])["payback_within_contract"]
    assert run(*CASES["4 Meiy downside"][0])["cannot_break_even"]
    assert not run(*CASES["1 Derke base"][0])["cannot_break_even"]


def test_blank_not_zero_when_no_swing_value():
    r = evaluate({**BASE, "F-08": 0, "F-09": 0, "F-10": 0}, 0, False)
    assert r["k_star_pct"] is None and r["payback_years"] is None


def test_unknown_import_counts_as_resident():
    assert evaluate(BASE, 0, None)["npv"] == evaluate(BASE, 0, False)["npv"]


def test_half_up_not_bankers():
    assert (half_up(0.5), half_up(2.5), half_up(0.25, 1)) == (1, 3, 0.3)


def test_monotonic():
    base = evaluate(BASE, 1, True)
    assert evaluate({**BASE, "F-02": 300000}, 1, True)["u_star"] > base["u_star"]  # salary up -> break-even up
    assert evaluate({**BASE, "F-14": 0.3}, 1, True)["npv"] > base["npv"]  # more credit -> NPV up
    gaining = {**BASE, "F-14": 0.3}  # G > 0
    assert evaluate({**gaining, "F-11": 0.25}, 1, True)["npv"] < evaluate(gaining, 1, True)["npv"]  # r up -> NPV down


def test_break_even_is_incremental_cost_over_years_at_r0():
    for years_left in (0, 1, 2, 3):
        r = evaluate({**BASE, "F-11": 0}, years_left, True)
        assert r["u_star"] == pytest.approx(r["incremental_cost"] / 2, abs=1)


def test_break_even_share_gives_zero_npv():
    r = evaluate(BASE, 2, True)
    k_star = (r["dS"] + r["C0"] / r["AF"]) / r["V"]  # unrounded
    assert abs(evaluate({**BASE, "F-14": k_star}, 2, True)["npv"]) <= 1


def test_seed_runs_worst_to_best_for_signing():
    costs = ("F-01", "F-02", "F-03", "F-05", "F-11", "F-13")  # fall from downside to upside
    gains = ("F-08", "F-09", "F-10", "F-14", "F-15")  # rise
    for i in costs:
        assert S["downside"][i] >= S["base"][i] >= S["upside"][i], i
    for i in gains:
        assert S["downside"][i] <= S["base"][i] <= S["upside"][i], i
    assert set(BASE) == set(costs + gains + ("F-04",))


def test_every_seed_input_is_in_assumptions_log():
    logged = set(re.findall(r"^\| (F-\d\d) \|", Path("docs/assumptions_log.md").read_text(encoding="utf-8"), re.M))
    assert set(BASE) <= logged


@pytest.fixture(scope="module")
def mart():
    con = duckdb.connect()
    return {r[0]: r[1:] for r in con.execute(
        f"SELECT player_name, contract_end_year, years_left, contract_match FROM {INPUTS}").fetchall()}


def test_one_row_per_fit_candidate(mart):
    con = duckdb.connect()
    assert con.execute(f"SELECT count(*) = count(DISTINCT player_id) FROM {INPUTS}").fetchone()[0]
    assert len(mart) == con.execute("SELECT count(*) FROM 'data/marts/mart_fit.csv'").fetchone()[0]


def test_shortlist_contracts_match_workbook(mart):
    """Checked by hand in gcd_2026-09-14.xlsx; CN writes '2027 Season End'.
    dgzin is listed as 'dgz', so he is matched through the alias seed."""
    by_hand = {"Meiy": 2027, "swagzor": 2027, "Derke": 2026, "ZmjjKK": 2026, "primmie": 2026,
               "BuZz": 2026, "Wo0t": 2026, "OXY": 2028, "Timotino": 2027, "dgzin": 2027}
    assert {p: mart[p][0] for p in by_hand} == by_hand
    assert mart["dgzin"] == (2027, 1, "matched")


def test_handle_aliases_resolve_in_both_marts(mart):
    """Every alias must hit a contract row; otherwise the player silently gets the full buyout."""
    con = duckdb.connect()
    aliases = con.execute("SELECT player_id, player_name FROM 'data/seeds/gcd_handle_aliases.csv'").fetchall()
    assert aliases
    for pid, name in aliases:
        assert mart[name][2] == "matched", name
        src = con.execute(f"SELECT import_source FROM 'data/marts/mart_fit.csv' WHERE player_id = {pid}").fetchone()
        assert src == ("contract database",), name


def test_unmatched_contracts_fall_back_to_full_buyout(mart):
    for end, years_left, match in mart.values():
        assert years_left == (max(0, end - 2026) if end is not None else 2)
        assert match == "matched" or end is None


def test_prize_seed_is_labelled_not_salary():
    with open("data/seeds/prize_reference.csv", newline="", encoding="utf-8") as f:
        rows = list(csv.DictReader(f))
    assert len(rows) == 10
    assert not any("salary" in c for c in rows[0] if c != "label")
    assert {r["label"] for r in rows} == {"prize money, not salary"}
    assert all(r["career_prize_usd"] != "0" for r in rows)  # unknown = blank, never 0


def test_reference_components_rebuild_the_outcome():
    """T9's DAX recomputes NPV from these columns and the F-14 slider; at the scenario's own F-14
    the result must equal the mart's rounded npv on every row (budget_model.md §6)."""
    with open("data/marts/mart_budget_reference.csv", newline="", encoding="utf-8") as f:
        rows = list(csv.DictReader(f))
    assert len(rows) == 504
    for r in rows:
        upfront, af, ds, v = (float(r[c]) for c in ("upfront", "af", "extra_salary", "swing_value"))
        assert upfront == float(r["buyout"]) + float(r["import_cost"])
        npv = (S[r["scenario"]]["F-14"] * v - ds) * af - upfront
        assert half_up(npv) == int(r["npv"]), (r["player_name"], r["scenario"], r["partner"])
