# T8 Review — Budget Model

2026-10-01. A review of T8 (budget model spec, `src/budget.py`, the budget marts and tests) after the build on 2026-09-29. It combines two independent reviews and records what was fixed on `budget_model`, what was decided, and what is still open. The spec is `docs/budget_model.md` (now v1.1).

## 1. What was checked and holds

| Check | Result |
|---|---|
| `budget.py` against the spec formulas (§6) | Every row of `mart_budget_reference.csv` (84 players × 3 scenarios × partner on/off = 504) was recomputed independently: **0 mismatches** |
| Seed values against the assumptions log | All 12 inputs match |
| Tests | Cover the 8 worked cases, blanks staying blank (not 0), monotonicity, NPV = 0 at the break-even, the seed's worst-to-best order and the link to the assumptions log |
| Research claims, re-checked at the source on 2026-10-01 | Riot's 2027 non-partner payments of $100k / $200k / $400k ([Riot, 2026-06-18](https://valorantesports.com/en-US/news/no-guaranteed-paths-inside-the-new-vct-2027)); SEN revenue $6.44M (2025) and $5.79M (2024), net loss $4.28M, cash $209k, ≈ $12M owed to JAG ([SEC Form C-AR](https://www.sec.gov/Archives/edgar/data/1982921/000198292126000003/form_car.pdf)). The partner range ($600K–$5M, THESPIKE) and the Americas Stage 2 2026 prizes were confirmed on 2026-09-29 |
| Prize money seed | Consistent with the research; not re-checked, because Esports Earnings blocks automated fetches |

## 2. Findings and what was done

| # | Finding | Severity | Done |
|---|---|---|---|
| 1 | **Contract handles that differ from the vlr.gg name were missed.** Riot lists dgzin as "dgz" (Evil Geniuses, to 2027), spike as "spikeziN" (Leviatán, to 2027) and Dantedeu5 as "Dante" (KRÜ, to 2028); each was confirmed by legal name in the contract workbook and against [esports.gg](https://esports.gg/news/valorant/evil-geniuses-valorant-2026-c0m/) and vlr.gg. All three fell back to the full 2-year buyout. dgzin is on the shortlist: his Base break-even was 32.2 points and is **23.8**. The error started in `t8_handoff.md` ("dgzin: not in any tab"), and a test had locked it in | **High** (wrong number on the shortlist) | ✅ `data/seeds/gcd_handle_aliases.csv` (player_id → Riot handle), used by `sql/mart_budget.sql` and `sql/mart_fit.sql`. The T6 import source for the three is now "contract database". The dgzin test was corrected and a new test fails if any alias stops matching. Marts rebuilt; 50 tests pass |
| 2 | **F-13 was a gross cost.** Freeing johnqt's slot has three money effects: the payout (counted), his salary saved (not counted) and his replacement's salary (not counted) | Medium | ✅ Redefined as a **net** cost. The uplift assumes the rest of the roster plays as now, and johnqt is SEN's IGL ([Hotspawn](https://www.hotspawn.com/valorant/news/sentinels-2026-roster)), so the replacement is **like-for-like**: the two salary terms cancel and net ≈ payout. **Values unchanged.** A minimum-salary replacement would make imports look almost free by counting the saving from losing the IGL but not the loss, so it is not used |
| 3 | **F-14 mixed two questions:** how much more likely top 3 is with the player, and how much of it is his doing | Medium | ✅ Reworded as the **added chance of a top-3 season (percentage points)**. Comparing sign with stay already isolates his contribution. Break-even now reads: "Derke must add 24 points to SEN's top-3 chance." **Values unchanged; Base level is open (§3)** |
| 4 | **The scenario decides the answer.** Signs across 84 candidates: Downside 0, Base 4 (jawgemo, Sato, tkzin, seven: resident free agents, none shortlisted), Upside 84 | Framing | ✅ `budget_model.md` §1 "How to read it": argue from the break-even bars, not the NPV sign. T9 in `todo.md` now puts the break-even next to F-14 as the headline |
| 5 | **The money side separates players only by contract and import status.** At Base the break-even takes 5 values across 84 players (15.5 / 23.8 / 32.2 / 40.6 / 49.0) and is essentially uncorrelated with fit (r ≈ −0.12). Max upfront spend is the same for everyone | Design consequence | ✅ Stated in §1. Not a bug: salary, fees and revenue were set equal for every candidate on purpose (no salary data; prize money may not be a proxy) |
| 6 | **Same cost per year whatever the quality;** free agents save the buyout but will likely ask for more salary | Limitation | ✅ §10 |
| 7 | **Revenue counts in full from year 1,** although bonuses and sponsorship usually follow a season of results (flatters signing) | Limitation | ✅ §10 |
| 8 | **The partner slot after 2028 is outside the 2-year window** (understates signing). $600K is the reported minimum *total* partner payment, not a base; non-partners still earn F-15; the signing can't affect SEN's 2027 status | Limitation | ✅ §10; an argument for T11 |
| 9 | **SEN keeps only part of the prize money (F-09);** players take a share. F-09 is ≈ 14% of the Base swing value | Limitation | ✅ §10 and the F-09 note |
| 10 | **F-10 overlaps F-08:** the sponsorship anchor (SEN's revenue growth) contains digital goods and prizes | Labelling | ✅ F-10 now says "excluding capsules and prize money"; anchor described as context only |
| 11 | Prize seed mixes dates (top five to 2026-07-12, the rest 2026-09-29) | Minor | ✅ Noted in §9 |
| 12 | `t8_handoff.md` had an out-of-date checklist under "Done", and the dgzin row | Minor | ✅ Tidied; a status banner says this review wins where they disagree |
| 13 | CN contract tab dates from 2026-07-02; Dantedeu5 was reported in Sep 2026 as leaving KRÜ despite a 2028 contract | Data age | ✅ Caveats in §5 |

Net effect on the conclusion: items 6 and 7 make Base slightly generous; item 8 makes it slightly strict. **Base "stay, narrowly" still holds for every shortlisted player**, and the memo should argue from the break-even bars.

## 3. Open

- ✅ **Decided 2026-10-01: F-14 Base stays at 20 points.** The question was 20 or 15. Under the new wording, 20 points from one duelist joining a 10th-place team is generous. **This matters more than it looks:** at 15, the expected uplift is 15% × $1.1M = $165k/yr, just below the extra salary cost of $170k/yr, so the yearly gain turns negative for *every* candidate. Base would then sign nobody (today: 4), and payback and max upfront spend go blank for all. The break-even bars do not change. T9 exposes F-14 as a slider (default 20), so a lower judgement can be tested live.
- **Spreadsheet check by hand** of case 1 (Derke, Base): the last T8 verification box.
- **14 pool players are still unmatched** in the contract database and get the full buyout (none on the shortlist). Some may be on non-partner teams and effectively free agents.
- **Import status by nationality** for non-Americas players is still a proxy (S-19), confirmed by hand in T11.
- **S-14:** rerun everything after the post-Champions re-snapshot (after 2026-10-18).

## 4. Numbers after the fix (Base, partner, Y = 2, r = 15%, F-14 = 20%)

| Shortlisted players | Upfront | NPV | Break-even top-3 chance | Payback |
|---|---|---|---|---|
| Derke, ZmjjKK, primmie, BuZz, Wo0t (free-agent imports), dgzin, Timotino | $150,000 | −$68,715 | 23.8 points | 3.0 yrs (not within contract) |
| Meiy, swagzor, OXY | $300,000 | −$218,715 | 32.2 points | 6.0 yrs (not within contract) |

All Stay. Max upfront spend is $81,285 for everyone.
