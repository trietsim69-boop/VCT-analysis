# T8 Handoff — Budget Model Implementation

Written 2026-09-29 at the end of the planning session for Task 8. It carries all the context from that session so someone else can write the code. **The spec is `docs/budget_model.md`**. This file explains how it got there and exactly what is left to build.

> **Status 2026-10-01: built, then reviewed.** The code landed on `budget_model` on 2026-09-29. The review in `docs/t8_review.md` corrected this handoff in two places: dgzin *is* in the contract database (as "dgz"), and F-14 now reads as the added top-3 chance rather than a credit share. Where this file and `t8_review.md` disagree, the review wins.

---

## 1. Project in one paragraph

A portfolio project in data analysis and business analysis (unofficial fan analysis, not affiliated with Sentinels or Riot). The question: **which duelist should Sentinels (SEN, VCT Americas) sign for its vacant 2027 slot, and what is that signing worth paying?** The pipeline is Python + DuckDB, turning the raw files into `data/processed/` and then into BI-ready CSVs in `data/marts/`. It feeds a Power BI report (`valorant_recruitment.pbix`) and, later, a Tableau story. `tasks/todo.md` is the source of truth for tasks. T1–T7 are done: Checkpoints A and B have passed, and the Scouting, Roster Fit, Candidate Fit and QA pages are built. **T8 is in progress: the spec is written, the code isn't.**

## 2. Where things are

- **Repo:** it lives at **`D:\VCT`** on the owner's machine. It used to be `D:\football analysis`; `CLAUDE.md` still has the old name and an old status line, so update it. Remote: `https://github.com/trietsim69-boop/VCT-analysis.git`, branch `main`. The owner commits and pushes.
- **Read first:** `tasks/todo.md` (T8 and T9 sections), `docs/budget_model.md` (the spec), `docs/budget_cost_research.md` (sources `[n]` used in the spec), `docs/assumptions_log.md`, `docs/kpi_dictionary.md` § E (superseded by the spec), `CLAUDE.md` (analysis rules).
- **Useful existing files:**
  - `data/marts/mart_fit.csv`: 84 eligible duelists. Columns include `player_id`, `player_name`, `fit_score`, `is_import_for_sen`, `import_source`, `country`, `contract_team`, `contract_end_year`. **The contract columns are Americas-only today.**
  - `sql/model.sql`: writes `data/processed/dim_contract_americas.csv` from the AMERICAS tab of `data/raw/gcd_2026-09-14.xlsx` (via `read_xlsx`, header on row 2, `all_varchar`).
  - `src/__init__.py`: `newest_snapshot(pattern)` finds the newest dated file in `data/raw/`.
  - `src/clean.py` runs `sql/model.sql`; `src/marts.py` runs `sql/mart_scouting.sql` then `sql/mart_fit.sql`.
  - `data/seeds/*.csv`: weights live in CSV seeds, not YAML (a project convention).
  - `tests/test_fit.py`, `tests/test_marts.py`, `tests/test_clean.py`: 27 tests pass today.
- **Run order:** `python -m src.clean`, then `python -m src.marts`, then `pytest`.

## 3. Decisions made in this session (all confirmed by the owner)

Round 1, structure:

| # | Decision | Why |
|---|---|---|
| Q1 | Scenarios are **one axis from worst to best case for signing: Downside / Base / Upside**. Downside means high costs, low uplift and a high discount rate. | The old low/base/high columns paired cheap costs with low revenue, so no column was a real worst case. The T9 sensitivity table covers the cross-combinations. |
| Q2 | **The same salary, agent fee, discount rate and revenue for every candidate.** Only the buyout (from years left on the contract) and the import-slot cost vary by candidate. | There is no per-player salary data, and scaling salary by prize earnings would smuggle prize money in as a salary proxy, which CLAUDE.md forbids. |
| Q3 | **The "stay" option is a stand-in on the $50k minimum.** Jerrwin remains the *performance* baseline (S-16) but not the cost baseline. | His contract runs to 2028 and his salary is unknown; the business brief frames D3 against a minimum-salary stand-in. |
| Q4 | **2027 partner status is a separate toggle** (default Partner), with its own revenue input for each state. | Riot keeps 8 of 11 Americas partners in 2027 and SEN finished 10th. That doesn't depend on who SEN signs. |
| Q5 | Add **F-13, the import-slot cost**: one-off, imports only. It assumes the one-import rule carries into 2027. johnqt's lost performance isn't modelled; the T11 memo covers it. | 7 of the top 10 are imports, including the top 5, and johnqt holds SEN's only import slot (Non-Resident, contract to 2028; S-10). Filtering imports out would drop the best candidates; ignoring the slot would understate their cost. |
| Q6 | **Agent fee = % of the candidate's salary, paid by the team** on top of salary. | One input that DAX can reproduce exactly. Players usually pay their own agent, so the label says the team covers it. |
| Q7 | **Buyout and import cost at t = 0; salary and revenue at the end of each year; every output is discounted.** Payback = upfront ÷ net gain per year. Break-even = the uplift that makes NPV = 0. D2 = the maximum *upfront* spend with NPV ≥ 0. | The old payback treated salary paid every year as an upfront cost, and the old break-even ignored discounting. |
| Q8 | 2026 rules are assumed for 2027: the $50k minimum, the one-import limit and the $600K–$5M partner range. All are logged as **"to verify (2027 rules)"**. | No 2027 rulebook has been published. |

Rounds 2 and 3, values (Downside / Base / Upside):

| # | Input | Value |
|---|---|---|
| Q9 | F-04 contract years | 2 / 2 / 2, the GM's choice, editable 1–3 |
| Q10 | F-02 candidate salary per year | 400k / 200k / 100k |
| Q11 | F-01 stand-in salary | 50k in all three |
| Q12 | F-03 buyout (full value = 2 years left) | 750k / 300k / 100k; 0 if the contract ends in 2026 |
| Q13 | F-05 agent fee | 15% / 10% / 5% |
| Q14 | F-13 import-slot cost | 400k / 150k / 0 |
| Q15 | F-11 discount rate | 25% / 15% / 10% |
| Q16 | Add **F-14, the share of the 10th → top-3 improvement credited to the signing**. Uplift = swing value × share. | The weakest assumption, kept separate and visible so readers can challenge it |
| Q17 | Buyout = F-03 × years_left ÷ 2; years_left = contract end year − 2026 (minimum 0); unknown → 2 | Makes the contract end year (source B2) inform the buyout, as T8's acceptance criteria require |
| Q18 | F-08 partner: extra bonus + capsule money per year | 200k / 700k / 2M |
| Q19 | **F-15 (new) non-partner: extra Riot qualification payments per year** | 0 / 100k / 300k |
| Q20 | F-09 extra prize money per year | 40k / 150k / 600k (both partner states) |
| Q21 | F-10 extra sponsorship + content per year | 0 / 250k / 750k (both partner states) |
| Q22 | F-14 credit share | 10% / 20% / 35% |

Also decided:
- **Shortlist** = the T7 fit-score "Top 10 of 84" band: Meiy, swagzor, Derke, ZmjjKK, primmie, BuZz, dgzin, OXY, Wo0t, Timotino.
- **Rounding:** money to whole dollars, payback to 0.1 years, share to 0.1 percentage points, round-half-up, outputs only.
- **Agent fee correction.** During the session the preview used ΔS = (S − S₀) × (1 + a), giving 165k. That conflicts with Q6, which puts the fee on the candidate's salary. The spec uses **ΔS = S × (1 + a) − S₀ = 170k**. The Base preview therefore moved from NPV −61k / −211k to **−68,715 / −218,715**.
- **No cap on years_left**, implementer's call made while writing the spec. A 2029 contract (3 years left) gives 1.5 × F-03. No shortlisted player is affected, but some pool players have 2029 contracts.

## 4. What to build

### 4.1 Contract table for all leagues (`sql/model.sql`)

- **Keep** `dim_contract_americas.csv` unchanged. `mart_fit.sql` uses it for the SEN import flag, which must stay Americas-only: residency is judged against SEN's league.
- **Add** `data/processed/dim_contract_all.csv`. Union the four tabs AMERICAS, CN, EMEA and PACIFIC, with the same `read_xlsx(..., range='A2:I500', all_varchar=true)` pattern.
  - Columns: `league`, `team`, `handle`, `gcd_role`, `contract_end_year`, `resident_status`, `roster_status`, `tab_last_update`.
  - **Do not select the legal names or contact columns** (personal data, not needed).
- Things to watch:
  - The **CN tab stores end dates as `"2027 Season End"`**; the others store `2026` or `'2026.0'`. Parse the first 4-digit year, e.g. `regexp_extract(col, '(\d{4})')`.
  - The CN tab's roles read `ACTIVE PLAYER`, not `PLAYER`.
  - Row 1 (0-based 0) holds `Last Update: <timestamp>` and differs per tab: CN 2026-07-02, EMEA 2026-08-11, AMERICAS 2026-09-14, PACIFIC 2026-09-17. Capture it as `tab_last_update` if it's easy, otherwise hard-code it in the docs.
  - **Handle case differs** from `dim_player` (`Zmjjkk`, `Buzz`, `Primmie`), so match on `lower(trim(handle))`.
  - `dim_player` has 4 duplicate names (Klaus, Laz, Zeus, adi), and Zeus is in the fit pool. If a handle matches more than one contract row or player, don't pick one silently: flag it (e.g. `contract_match = 'ambiguous'`) and fall back to years_left = 2.
- Expected shortlist matches (checked by hand from the workbook):

| Player | Tab | Team | End |
|---|---|---|---|
| Meiy | PACIFIC | DETONATION FOCUSME | 2027 |
| swagzor | CN | NOVA ESPORTS | 2027 Season End |
| Derke | EMEA | TEAM VITALITY | 2026 |
| ZmjjKK | CN | EDWARD GAMING | 2026 Season End |
| primmie | PACIFIC | FULL SENSE | 2026 |
| BuZz | PACIFIC | T1 | 2026 |
| Wo0t | EMEA | TEAM HERETICS | 2026 |
| OXY | AMERICAS | CLOUD9 | 2028 |
| Timotino | AMERICAS | 100 THIEVES | 2027 |
| dgzin | AMERICAS | EVIL GENIUSES (as "dgz") | 2027 — *corrected in the review; originally listed here as not found* |

### 4.2 Budget inputs mart (for T9): `data/marts/mart_budget_inputs.csv`

One row per candidate in `mart_fit.csv` (84), built in a new `sql/mart_budget.sql` run from `src/marts.py`:

`player_id, player_name, fit_score, is_import_for_sen, import_source, contract_league, contract_team, contract_end_year, years_left, contract_match`

- `years_left = greatest(0, contract_end_year − 2026)`, or 2 when unmatched.
- Keep the money out of this mart. Scenario values live in a seed (4.3) so T9's what-if parameters can override them.

### 4.3 Scenario seed: `data/seeds/budget_scenarios.csv`

Long format, consistent with the other seeds: `input_id, input, unit, downside, base, upside, status`. One row per input from `budget_model.md` §4:

- **Included:** F-01 to F-05, F-08 to F-11, F-13 to F-15.
- **Not rows:** F-06 is a toggle, F-07 is reference only and F-12 is the currency.

Percentages are stored as fractions (0.15, not 15). `budget.py` reads this seed; nothing is hard-coded twice.

### 4.4 `src/budget.py`

- Pure functions with no I/O in the core. For example:
  - `annuity_factor(r, years)`
  - `evaluate(inputs, years_left, is_import, partner=True, years=2) -> dict`, returning every output in `budget_model.md` §6.2 plus the intermediates AF, C₀, ΔS, V, U and G
  - a helper that loads the seed into a `{scenario: inputs}` dict
- Rounding per §7: `decimal.Decimal(repr(x)).quantize(..., ROUND_HALF_UP)`, applied to outputs only. Return `None` (not 0) for payback when G ≤ 0 and for k\* when V = 0. **Never fill blanks with 0**, per the CLAUDE.md rule.
- Also return `payback_within_contract` (bool) and `cannot_break_even` (k\* > 100%).
- Optional CLI: `python -m src.budget` prints the shortlist × 3 scenarios table (Partner on). Writing it to `data/marts/mart_budget_reference.csv` would give T9 a parity target.

### 4.5 `tests/test_budget.py`

At least 5 cases are required; the spec has 8 with exact expected values in `budget_model.md` §8. **The owner must hand-check case 1 (Derke, Base) in a spreadsheet** (T8 verification). Also add:

- **Monotonicity:** a higher salary raises U\*; a higher k raises NPV; a higher r lowers NPV when G > 0.
- **r = 0 identity:** U\* == incremental cost ÷ Y.
- **Round trip:** plugging k = k\* (unrounded) back in gives NPV ≈ 0.
- **Seed checks:**
  - Downside ≤ Base ≤ Upside in the "good for signing" direction: costs and r fall, revenue and k rise.
  - Every F-id in the seed appears in `assumptions_log.md`.
- **Mart checks:**
  - `mart_budget_inputs` has 84 rows with unique `player_id`.
  - The shortlist contract years match the table in 4.1 (all 10, after the alias fix).
- **Prize seed:** no salary column, and every row labelled not salary.

Expected values from the spec, for quick copy:

```
case  scenario  partner  Y  r      years_left import | NPV        U*       k*     payback  max_upfront  decision
1     Base      yes      2  0.15   0          yes    | -68715     262267   23.8   3.0      81285        Stay   (TAC 590000, incr 490000)
2     Base      yes      2  0.15   2          no     | -218715    354535   32.2   6.0      81285        Stay   (TAC 740000, incr 640000)
3     Base      no       2  0.15   1          no     | -263800    262267   52.5   None     0            Stay
4     Downside  yes      2  0.25   1          yes    | -1330840   948194   395.1  None     0            Stay   (TAC 1695000)
5     Upside    yes      2  0.10   0          yes    | 1939463    55000    1.6    0.0      1939463      Sign   (TAC 210000)
6     Base      yes      2  0.00   0          no     | 100000     170000   15.5   0.0      100000       Sign
7     Base      yes      2  0.00   2          no     | -200000    320000   29.1   6.0      100000       Stay
8     Base      yes      1  0.15   0          yes    | -106522    342500   31.1   3.0      43478        Stay
```

### 4.6 `data/seeds/prize_reference.csv`

Columns: `player_id, player_name, career_prize_usd, source, as_of, label`, where `label = "prize money, not salary"`, for the 10 shortlisted players.

- **Known** (Esports Earnings VALORANT top-players page, data to 2026-07-12): ZmjjKK 305,234 · Derke 295,483 · Wo0t 255,633 · BuZz 185,715 · Timotino 120,000.
- **To fetch:** Meiy, swagzor, primmie, dgzin and OXY are all under 78,796, outside the top 100. Get them from each player's Esports Earnings page (`esportsearnings.com/players/...`) or the free API (key required, at most 1 request per second, game ID 646).
- If a figure can't be found, leave it **blank**, not 0, and put "< 78,796" in a note column.

### 4.7 Documentation updates

> **Done 2026-09-29**, except ticking the remaining `todo.md` T8 boxes as the code lands. D2 in `business_brief.md` was also redefined to the maximum *upfront* spend, with total acquisition cost shown alongside.

Covered: the assumptions log § B, `kpi_dictionary.md` § E, the T8 boxes in `todo.md` and `CLAUDE.md`.

## 5. Rules that apply (from CLAUDE.md, restated for this task)

- Every financial input is labelled **"Assumption"** and carries its F-id.
- **Prize money is never salary.** It must not feed any formula.
- Missing values stay blank or NULL, never 0.
- State ranges, not point predictions. The three scenarios plus break-even are the range.
- Every new number goes in `assumptions_log.md` with a status: decided, sourced, illustrative or to verify.
- Tests over eyeballing; every mart gets a pytest data test.

## 6. Verification before calling T8 done

1. `python -m src.clean`, then `python -m src.marts`, then `pytest`: all old tests (27) plus the new budget tests pass.
2. Case 1 (Derke, Base) worked in a spreadsheet with formulas matches the pytest values. The owner does this.
3. `mart_budget_inputs.csv` has 84 rows, and the shortlist years_left values match 4.1.
4. `assumptions_log.md` has every F-id used in the seed, each with a status.

## 7. Open items passed to later tasks

- **T9 (Power BI):**
  - What-if parameters for every seed row.
  - A Downside / Base / Upside selector and a partner toggle.
  - The candidate carries over from the other pages via `dim_player[player_id]` → `mart_budget_inputs`.
  - Rounding must match §7 of the spec: DAX `ROUND` is half-up, so it matches.
  - Every card is labelled "Assumption".
- **T11 (memo):**
  - Confirm import status for the players flagged by nationality (S-19).
  - Discuss johnqt's lost performance, which F-13 doesn't model.
  - State which 2027 rule changes would flip the Base "stay, narrowly" result.
  - Note that the result flips to sign once the signing adds ≈ 24–32 points to SEN's top-3 chance (break-even bars; `t8_review.md`).
- **S-14:** after Champions 2026 ends (2026-10-18), re-snapshot and rerun. The fit shortlist may change, and the budget mart follows automatically.
- **Unverified facts** (see `budget_cost_research.md` "Could not verify"):
  - the 2027 minimum salary and import limit
  - the $600K–$5M range on a Riot page
  - any real VALORANT salary or fee
