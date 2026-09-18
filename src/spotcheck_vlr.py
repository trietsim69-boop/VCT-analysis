"""Cross-check the snapshot against the live vlr.gg match pages (the upstream source).

Usage:
    python -m src.spotcheck_vlr data/raw/vct-fe27a11e.duckdb 729757 724645

Compares every player x map overview stat (both-sides value) and writes data/audit/08_vlr_spotcheck.csv.
"""

import sys
import urllib.request

import duckdb
import pandas as pd
from bs4 import BeautifulSoup

COLS = {"rating2": "rating_all", "acs": "acs_all", "kills": "kills_all", "deaths": "deaths_all",
        "assists": "assists_all", "kast": "kast_all", "adr": "adr_all", "hsp": "hs_pct_all",
        "fb": "fk_all", "fd": "fd_all"}


def scrape(vlr_id: str) -> list[dict]:
    req = urllib.request.Request(f"https://www.vlr.gg/{vlr_id}", headers={"User-Agent": "Mozilla/5.0"})
    soup = BeautifulSoup(urllib.request.urlopen(req).read(), "html.parser")
    rows = []
    for game in soup.select("div.vm-stats-game[data-game-id]"):
        if not game["data-game-id"].isdigit():  # skip the "All Maps" aggregate
            continue
        for name in game.select(".ovw-player-name"):
            row = name.find_parent(class_="mod-player").parent
            rec = {"game_id": game["data-game-id"], "player_name": name.get_text(strip=True)}
            for col, db_col in COLS.items():
                cell = row.select_one(f'[data-col="{col}"] .mod-both')
                txt = cell.get_text(strip=True).rstrip("%") if cell else ""
                rec[db_col] = float(txt) if txt not in ("", "-") else None
            rows.append(rec)
    return rows


db, ids = sys.argv[1], sys.argv[2:]
web = pd.DataFrame([r for i in ids for r in scrape(i)]).melt(["game_id", "player_name"], var_name="stat", value_name="vlr")
con = duckdb.connect(db, read_only=True)
snap = con.execute(f"""SELECT pm.game_id, p.player_name, {', '.join(COLS.values())}
    FROM player_map pm JOIN players p USING (player_id)
    WHERE pm.game_id IN (SELECT unnest(?))""", [list(web.game_id.unique())]).df()
snap = snap.melt(["game_id", "player_name"], var_name="stat", value_name="snapshot")
out = web.merge(snap, on=["game_id", "player_name", "stat"], how="outer")
out["match"] = (out.vlr - out.snapshot).abs().fillna(99) < 0.005
out.to_csv("data/audit/08_vlr_spotcheck.csv", index=False)
print(f"{out.match.sum()}/{len(out)} cells match")
print(out[~out.match].to_string(index=False) if (~out.match).any() else "no mismatches")
