# Budget Model — Specification (T8)

> **Unofficial fan/portfolio analysis.** Not affiliated with Sentinels or Riot Games. **Every input in this model is an assumption**; none is a known SEN contract term. Salaries and buyouts are not public in VALORANT. Prize money is prize money, **never salary**.

| | |
|---|---|
| **Status** | v1.0, 2026-09-29. Decisions settled in the T8 grilling session (Q1–Q22). |
| **Answers** | D2 (how much can SEN justify paying?) and D3 (sign, or stay with a minimum-salary stand-in?) from `business_brief.md` |
| **Implemented in** | `src/budget.py` (reference calculation), `tests/test_budget.py`; T9 rebuilds it in DAX and must match to the rounding rules in §7 |
| **Research** | `docs/budget_cost_research.md`. Source numbers `[n]` below refer to that file's source list |
| **Supersedes** | `kpi_dictionary.md` § E, whose formulas this replaces (see §6.4 for what changed) |

---

## 1. What the model answers

- **D3: sign or stay?** Signing a candidate is compared with keeping a stand-in on the league minimum salary. The model computes the net present value (NPV) of the *difference* between the two. **Sign** if NPV ≥ 0 in the **Base** scenario; the Downside and Upside results are shown alongside.
- **D2: what is it worth paying?** The **maximum justifiable upfront spend** is the most SEN could pay up front (buyout + freeing the import slot) and still reach NPV ≥ 0.
- **The headline number is the break-even, not the NPV.** Revenue uplift is the weakest input, so the most robust output is *how much uplift the signing must bring to pay for itself*. It is expressed two ways: as dollars per year, and as the **share of SEN's results improvement the signing must be credited with**.

What the model does **not** do: predict SEN's results, value the organisation, or say what a player is actually paid.

## 2. Scenarios

There is **one axis, from worst case to best case for signing**:

| Scenario | Meaning |
|---|---|
| **Downside** | Costs high, uplift low, discount rate high. The signing looks as bad as the plausible range allows. |
| **Base** | Central values. The recommendation (D3) is read here. |
| **Upside** | Costs low, uplift high, discount rate low. |

The T9 page selector shows Downside / Base / Upside. It maps to the "low / base / high" wording in `todo.md`.

Two things are **not** scenario variables:
- **Contract length (F-04)** is the GM's choice: 2 years by default, editable from 1 to 3.
- **2027 partner status (F-06)** is a separate toggle. Whether Riot keeps SEN as a partner has nothing to do with who SEN signs. 2027 cuts Americas partners from 11 to 8 [Sheep Esports], and SEN finished 10th in 2026, so the toggle matters.

The T9 sensitivity table (salary × uplift) covers the combinations a single axis leaves out.

## 3. Timing convention

- **t = 0 (signing date):** buyout and import-slot cost are paid.
- **End of each contract year t = 1 … Y:** salary, agent fee and revenue uplift are counted.
- Everything is discounted at rate *r*. At *r* = 0 every formula reduces to a simple sum.
- **Currency:** USD. EUR and KRW figures in the research were converted at ECB rates for 29 Sep 2026.

## 4. Inputs

All values are USD and listed as **Downside / Base / Upside**. Each input is labelled **"Assumption"** on the dashboard with its ID. The IDs are recorded in `assumptions_log.md`.

| ID | Input | Symbol | Downside | Base | Upside | Status | Anchor / source |
|---|---|---|---|---|---|---|---|
| F-01 | Stand-in (baseline) salary per year | S₀ | 50,000 | 50,000 | 50,000 | sourced (2023 rule); **to verify (2027 rules)** | Riot VCT 2023 Americas minimum $50k [1][3]; no change found for 2024–26; Riot declined to say whether 2027 has a minimum [9]. It is a rule, not a market price, so it doesn't vary by scenario. |
| F-02 | Candidate salary per year | S | 400,000 | 200,000 | 100,000 | **illustrative** | Bracketed by: NA $240–360k before the 2024 cuts [7]; pay cuts since [15]; LEC median ≈ $187k, average ≈ $273k [12]; SEN CEO base pay $360k while the team runs at a loss [16]. No credible salary exists for any shortlisted player. |
| F-03 | Buyout, full value (2 contract years left) | B_full | 750,000 | 300,000 | 100,000 | **illustrative** | EG turned down $100k for two reigning champions (2023) [15]; TenZ went for $1.25M (2021, the market peak before franchising: noted as an outlier, not used) [19]. Scaled by years left (§5). |
| F-04 | Contract length (years) | Y | 2 | 2 | 2 | decided (GM choice, editable 1–3) | The 2027–28 partnership cycle [9] |
| F-05 | Agent fee, % of candidate salary, **paid by the team** | a | 15% | 10% | 5% | **illustrative** (industry figure / analogy) | 10–15% commission is typical in Europe [27]; FIFA caps agents at 5% of pay ≤ $200k/yr (analogy only) [30]. Players usually pay their own agent; this input assumes SEN covers it on top of salary. |
| F-06 | 2027 partner status | P | toggle | toggle | toggle | decided (toggle, default **Partner**) | 8 partners per region in 2027, down from 11 in Americas; not yet announced |
| F-07 | Partner payment range per year | — | — | — | — | sourced (reported) — **reference only, not an input** | $600K–$5M/yr made up of base payment + performance bonus + team capsules [9] (THESPIKE citing Riot's meetings with teams); structure confirmed by Riot [42] |
| F-08 | *Partner:* extra bonus + capsule money per year from finishing top-3 instead of 10th | V_partner | 200,000 | 700,000 | 2,000,000 | range reported; split **illustrative** | Within the F-07 range; capsules share 50% after costs [34]; SEN capsule sales #1 in Americas in 2024 → #3 in 2025 [35] |
| F-15 | *Non-partner:* extra Riot qualification payments per year | V_open | 0 | 100,000 | 300,000 | sourced (Riot) | Riot pays non-partners $100k for Kickoff or a Cup, $200k for Masters, $400k for Champions [10]. Downside = nothing extra; Base = reaches Kickoff; Upside = Kickoff + Masters. |
| F-09 | Extra prize money per year (10th → top-3) | V_prize | 40,000 | 150,000 | 600,000 | sourced (2026 prize pools); **to verify (2027 pools)** | 10th in Americas earns $0; Stage 2 2026 pays $100k/65k/40k to the top 3 [47]; Masters $1M pools [48]; Champions $2.25M [50]. 2027 pools are "over $6M a year" [42]. |
| F-10 | Extra sponsorship + content revenue per year | V_spon | 0 | 250,000 | 750,000 | **illustrative** | SEN revenue: $2.92M (2023) [55] → $5.79M (2024, Masters title year) → $6.44M (2025) [16]. It can't be separated from results or Riot's digital-goods share. |
| F-11 | Discount rate | r | 25% | 15% | 10% | **illustrative** (anchored) | Listed entertainment cost of capital 7.1% as the floor [60]; SEN is loss-making, held $209k cash and owed $12M to its backer at end-2025 [16]; late-stage startup returns of 25–35% [61] as the ceiling reference |
| F-13 | Import-slot cost (one-off, **imports only**) | I | 400,000 | 150,000 | 0 | **illustrative** | SEN's single import slot is held by johnqt (Non-Resident, contract to 2028: S-10). Downside = pay out 2 years at ≈ $200k; Base = settle about half; Upside = sell or loan him out. No public payout figures exist. |
| F-14 | Share of the results improvement credited to the signing | k | 10% | 20% | 35% | **illustrative — the weakest assumption in the model** | Base = one of five players; Downside = a new player is only part of any improvement; Upside = a star duelist carries more than an equal share |
| F-12 | Currency | — | USD | USD | USD | decided | — |

**Rules carried over from 2026, all "to verify (2027 rules)":**
- the $50k minimum (F-01)
- the one-import limit (behind F-13)
- the $600K–$5M partner range (F-07/F-08)

If any of these changes, the memo (T11) must say how the recommendation moves.

## 5. Inputs that differ by candidate

Salary, agent fee, discount rate and revenue are **the same for every candidate**. There is no public salary data for any player, and scaling salary by prize earnings would bring prize money back as a salary proxy. Only two inputs vary by candidate:

**Years left on the contract**, from Riot's Global Contract Database (`data/raw/gcd_2026-09-14.xlsx`, all four league tabs):

```
years_left = max(0, contract_end_year − 2026)      -- a contract ending in 2026 → free agent for 2027
years_left = 2 if the player is not in the database -- unknown → full value
B          = B_full × years_left ÷ 2                -- no cap: a 2029 contract (3 years left) costs 1.5 × B_full
```

**Import flag** (`is_import_for_sen`, from `mart_fit.csv`, rule S-19): I = F-13 if the candidate is an import for SEN, otherwise 0.

### The shortlist (T7 fit score, "Top 10 of 84" band)

| Player | Contract team (database tab) | Ends | Years left | Import for SEN | Upfront (B + I): Downside / Base / Upside |
|---|---|---|---|---|---|
| Meiy | DetonatioN FocusMe (Pacific) | 2027 | 1 | yes | 775,000 / 300,000 / 50,000 |
| swagzor | Nova Esports (CN) | 2027 | 1 | yes | 775,000 / 300,000 / 50,000 |
| Derke | Team Vitality (EMEA) | 2026 | 0 | yes | 400,000 / 150,000 / 0 |
| ZmjjKK | EDward Gaming (CN) | 2026 | 0 | yes | 400,000 / 150,000 / 0 |
| primmie | Full Sense (Pacific) | 2026 | 0 | yes | 400,000 / 150,000 / 0 |
| BuZz | T1 (Pacific) | 2026 | 0 | yes | 400,000 / 150,000 / 0 |
| dgzin | *not in database* | — | 2 (assumed) | no | 750,000 / 300,000 / 100,000 |
| OXY | Cloud9 (Americas) | 2028 | 2 | no | 750,000 / 300,000 / 100,000 |
| Wo0t | Team Heretics (EMEA) | 2026 | 0 | yes | 400,000 / 150,000 / 0 |
| Timotino | 100 Thieves (Americas) | 2027 | 1 | no | 375,000 / 150,000 / 50,000 |

Caveats:
- The database tabs were last updated on different dates: CN 2026-07-02, EMEA 2026-08-11, Americas 2026-09-14 and Pacific 2026-09-17. A player listed as ending in 2026 may have re-signed since.
- The import flag for non-Americas players rests on nationality (S-19) and is confirmed by hand in T11.

## 6. Formulas

### 6.1 Intermediate quantities

| Symbol | Name | Formula |
|---|---|---|
| AF | Annuity factor | Σₜ₌₁..Y 1 ÷ (1 + r)ᵗ  (= Y when r = 0) |
| C₀ | Upfront cost | B + I |
| ΔS | Extra salary cost per year | S × (1 + a) − S₀ |
| V | Value per year of finishing top-3 instead of 10th | P × V_partner + (1 − P) × V_open + V_prize + V_spon, where P = 1 if partner, else 0 |
| U | Revenue uplift per year credited to the signing | k × V |
| G | Net gain per year | U − ΔS |

### 6.2 Outputs

| Output | Formula | Notes |
|---|---|---|
| **Total acquisition cost (TAC)** | C₀ + S × (1 + a) × Y | Undiscounted, for display |
| **Baseline cost** | S₀ × Y | Undiscounted |
| **Incremental cost** | TAC − Baseline cost | Undiscounted |
| **NPV of signing vs staying** | G × AF − C₀ | The D3 test |
| **Break-even uplift per year** (U\*) | ΔS + C₀ ÷ AF | The U at which NPV = 0. At r = 0 it equals Incremental cost ÷ Y. |
| **Break-even credit share** (k\*) | U\* ÷ V | Blank if V = 0. Values over 100% are shown with the flag "cannot break even at this swing value". |
| **Payback (years)** | C₀ ÷ G if G > 0; 0 if C₀ = 0 and G > 0 | Simple (undiscounted). **Blank if G ≤ 0.** Flagged **"not within contract"** if payback > Y. |
| **Maximum justifiable upfront spend** (D2) | max(0, G × AF) | The largest C₀ at which NPV ≥ 0. It is 0 when the yearly gain is negative: no upfront spend is justified. |
| **Decision** (D3) | "Sign" if NPV ≥ 0, else "Stay" | Read in Base; shown for all three scenarios |

### 6.3 Edge cases

- **Zero buyout** (free agent), resident: C₀ = 0, so payback = 0 whenever G > 0.
- **Revenue below cost** (G ≤ 0): payback blank, max upfront spend = 0, decision Stay, k\* can exceed 100%.
- **Non-partner:** V uses V_open instead of V_partner. Every other input is unchanged.
- **Y = 1:** AF = 1 ÷ (1 + r). All formulas still hold.
- **Missing contract data:** years_left = 2 (full buyout). **Missing import flag:** treat as not an import, and show "Import status unknown" as T7 does.

### 6.4 Changes from `kpi_dictionary.md` § E (v0.1)

- **Payback** was Incremental cost ÷ annual uplift, which treated salary paid every year as if it were paid upfront. Now it is upfront cost ÷ net gain per year.
- **Break-even** was Incremental cost ÷ Y, which ignored discounting. Now it is ΔS + C₀ ÷ AF, and it equals the old formula when r = 0.
- **Max justifiable spend** was the baseline cost plus Y years of uplift, a *total*. Now it is the maximum *upfront* amount (buyout + import-slot cost), which is the number the GM negotiates.
- **Added:** F-13 (import-slot cost), F-14 (credit share), F-15 (non-partner payments), the break-even credit share and the not-within-contract flag.
- **Agent fee** stays a percentage of candidate salary paid by the team. ΔS applies it to the candidate's salary only, not to the stand-in's.

## 7. Rounding (so DAX can match pytest exactly)

- Compute at full precision and **round only the outputs**, using round-half-up to match DAX `ROUND`. Python's built-in `round` rounds halves to even, so use `decimal.Decimal` with `ROUND_HALF_UP`.
- Money is rounded to whole dollars, payback to 0.1 years and the break-even credit share to 0.1 percentage points.
- AF is never rounded.

## 8. Reference results (Base, SEN a partner, Y = 2, r = 15%)

AF = 1.625709 · V = 700k + 150k + 250k = 1,100,000 · U = 20% × V = 220,000/yr · ΔS = 200k × 1.10 − 50k = 170,000/yr · G = 50,000/yr

| Group | Upfront C₀ | NPV | Break-even uplift | Break-even credit share | Payback | Max upfront | Decision |
|---|---|---|---|---|---|---|---|
| Free-agent imports (Derke, ZmjjKK, primmie, BuZz, Wo0t) and Timotino | 150,000 | −68,715 | 262,267 | 23.8% | 3.0 yrs (not within contract) | 81,285 | Stay |
| OXY, dgzin, Meiy, swagzor | 300,000 | −218,715 | 354,535 | 32.2% | 6.0 yrs (not within contract) | 81,285 | Stay |

**Reading:** at Base values the model says **stay, narrowly**. It flips to **sign** once the signing is credited with about a quarter (free agents) to a third (players still under contract) of a 10th → top-3 improvement. Neither contract status nor fit changes the yearly economics. The contract only decides how much has to be paid up front.

### Worked cases (these are the expected values for `tests/test_budget.py`)

| # | Case | Inputs that differ from Base | NPV | U\* | k\* | Payback | Max upfront | Decision |
|---|---|---|---|---|---|---|---|---|
| 1 | Derke, Base, partner | years_left 0, import | −68,715 | 262,267 | 23.8% | 3.0 | 81,285 | Stay |
| 2 | OXY, Base, partner | years_left 2, resident | −218,715 | 354,535 | 32.2% | 6.0 | 81,285 | Stay |
| 3 | Timotino, Base, **non-partner** | years_left 1, resident; V = 500,000 | −263,800 | 262,267 | 52.5% | blank (G = −70,000) | 0 | Stay |
| 4 | Meiy, **Downside**, partner (**revenue below cost**) | years_left 1, import; C₀ = 775,000; AF = 1.44 | −1,330,840 | 948,194 | 395.1% (cannot break even) | blank (G = −386,000) | 0 | Stay |
| 5 | primmie, **Upside**, partner (**zero buyout**) | years_left 0, import, I = 0; AF = 1.735537 | 1,939,463 | 55,000 | 1.6% | 0.0 | 1,939,463 | Sign |
| 6 | Synthetic resident free agent, Base, **r = 0** | C₀ = 0; AF = 2 | 100,000 | 170,000 | 15.5% | 0.0 | 100,000 | Sign |
| 7 | OXY, Base, **r = 0** (simple sums) | AF = 2 | −200,000 | 320,000 (= 640,000 ÷ 2) | 29.1% | 6.0 | 100,000 | Stay |
| 8 | Derke, Base, **Y = 1** | AF = 0.869565 | −106,522 | 342,500 | 31.1% | 3.0 | 43,478 | Stay |

Also expected:
- Case 1: TAC 590,000; incremental cost 490,000.
- Case 2: TAC 740,000; incremental cost 640,000.
- Case 4: TAC 1,695,000.
- Case 5: TAC 210,000.

Case 1 is the one to work by hand in a spreadsheet (T8 verification).

## 9. Prize reference (**prize money, not salary**)

These are players' career VALORANT prize earnings from Esports Earnings (game ID 646), data to 2026-07-12 [54]. They are **reference only**. They don't feed any formula and must be labelled "prize money, not salary" wherever they appear. They go into `data/seeds/prize_reference.csv`.

| Player | Career prize money (USD) | Esports Earnings rank |
|---|---|---|
| ZmjjKK | 305,234 | #6 |
| Derke | 295,483 | #11 |
| Wo0t | 255,633 | #20 |
| BuZz | 185,715 | #37 |
| Timotino | 120,000 | #68 |
| dgzin | 17,079 (VALORANT only; his page total of 143,079 includes CrossFire) | — |
| primmie | 9,118 | — |
| OXY | 8,230 | — |
| Meiy | 3,989 | — |
| swagzor | blank: no Esports Earnings page found (< 78,796, outside the top 100) | — |

The last five come from each player's page, accessed 2026-09-29. All ten are in `data/seeds/prize_reference.csv`.

For context: SEN's lifetime VALORANT prize money is $1,058,000, and SEN won nothing listed in 2026 [52][53].

## 10. Limits

- **The uplift is an assumption, not a prediction.** No link from a player to results is modelled (assumptions log § D). F-14 is the weakest input, which is why break-even is the headline output.
- **Moving johnqt costs performance as well as money.** Only the money (F-13) is modelled; T11 discusses the rest.
- **Jerrwin is the performance baseline (S-16) but not the cost baseline.** His contract runs to 2028 and his salary is unknown, so the "stay" option is a minimum-salary stand-in, as the business brief frames D3.
- **2027 rules are unpublished.** The minimum salary, import limit and partner payments are all carried over from 2026 and marked "to verify".
- **Contract data can be stale** (see the tab update dates in §5).
