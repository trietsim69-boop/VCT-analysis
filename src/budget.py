"""Budget model reference calculation (docs/budget_model.md §6–§7). T9's DAX must match it.

Usage:
    python -m src.budget       # rewrites data/marts/mart_budget_reference.csv (src.marts also does this)

Every input is an assumption from data/seeds/budget_scenarios.csv (assumptions_log.md § B).
"""

import csv
from decimal import ROUND_HALF_UP, Decimal

SCENARIOS = ("downside", "base", "upside")


def load_scenarios(path="data/seeds/budget_scenarios.csv"):
    """{scenario: {input_id: value}}, e.g. s["base"]["F-02"] == 200000."""
    with open(path, newline="", encoding="utf-8") as f:
        rows = list(csv.DictReader(f))
    return {s: {r["input_id"]: float(r[s]) for r in rows} for s in SCENARIOS}


def half_up(x, places=0):
    """Round half up like DAX ROUND (Python's round() goes half to even); None stays None."""
    if x is None:
        return None
    d = Decimal(repr(x)).quantize(Decimal(1).scaleb(-places), ROUND_HALF_UP)
    return int(d) if places == 0 else float(d)


def evaluate(inp, years_left, is_import, partner=True):
    """Sign vs stay for one candidate. inp = one scenario from load_scenarios(); override a
    value with {**inp, "F-11": 0}. is_import None counts as not an import (§6.3)."""
    S0, S, B_full, a, r, k = inp["F-01"], inp["F-02"], inp["F-03"], inp["F-05"], inp["F-11"], inp["F-14"]
    Y = int(inp["F-04"])

    AF = sum(1 / (1 + r) ** t for t in range(1, Y + 1))  # annuity factor, = Y at r = 0
    C0 = B_full * years_left / 2 + (inp["F-13"] if is_import else 0)  # upfront: buyout + import slot
    dS = S * (1 + a) - S0  # agent fee on the candidate's salary only
    V = (inp["F-08"] if partner else inp["F-15"]) + inp["F-09"] + inp["F-10"]  # value of 10th -> top-3
    U = k * V
    G = U - dS  # net gain per year

    tac = C0 + S * (1 + a) * Y
    u_star = dS + C0 / AF
    k_star = u_star / V if V else None  # blank, not 0
    payback = C0 / G if G > 0 else None  # never pays back = blank
    npv = G * AF - C0
    return {
        "AF": AF, "C0": C0, "dS": dS, "V": V, "U": U, "G": G,
        "tac": half_up(tac),
        "baseline_cost": half_up(S0 * Y),
        "incremental_cost": half_up(tac - S0 * Y),
        "npv": half_up(npv),
        "u_star": half_up(u_star),
        "k_star_pct": half_up(k_star * 100, 1) if k_star is not None else None,
        "payback_years": half_up(payback, 1),
        "max_upfront": half_up(max(0, G * AF)),
        "decision": "Sign" if npv >= 0 else "Stay",
        "payback_within_contract": payback is not None and payback <= Y,
        "cannot_break_even": k_star is None or k_star > 1,
    }


def write_reference(path="data/marts/mart_budget_reference.csv"):
    """Every candidate x scenario x partner state: the parity target for T9's DAX."""
    scen = load_scenarios()
    with open("data/marts/mart_budget_inputs.csv", newline="", encoding="utf-8") as f:
        cands = list(csv.DictReader(f))
    out = []
    for c in cands:
        imp = {"true": True, "false": False}.get(c["is_import_for_sen"])  # blank -> None
        for s in SCENARIOS:
            for partner in (True, False):
                res = evaluate(scen[s], int(c["years_left"]), imp, partner)
                out.append({"player_id": c["player_id"], "player_name": c["player_name"], "scenario": s,
                            "partner": partner,
                            **{k: v for k, v in res.items() if k not in ("AF", "C0", "dS", "V", "U", "G")}})
    with open(path, "w", newline="", encoding="utf-8") as f:
        w = csv.DictWriter(f, fieldnames=out[0])
        w.writeheader()
        w.writerows(out)  # None -> empty cell, not 0
    return len(out)


if __name__ == "__main__":
    print(f"mart_budget_reference: {write_reference():,} rows")
