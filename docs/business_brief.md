# Business Brief — SEN 2027 Roster Signing

> **Unofficial fan/portfolio analysis.** Not affiliated with, endorsed by, or produced for Sentinels or Riot Games. Team facts are drawn from public reporting (see Sources) and are re-verified in Task 2.

| | |
|---|---|
| **Status** | Draft v0.1 — 2026-09-17 |
| **Author** | triet |
| **Purpose** | Portfolio project and personal learning (data analysis + business analysis, Power BI + Tableau) |
| **Stakeholder (hypothetical)** | General Manager, Sentinels VALORANT (VCT Americas) |
| **Supporting users** | Head coach (roster fit), finance lead (budget) |

---

## 1. Problem statement

In 2026 Sentinels finished around 10th in North America. They were eliminated in the Stage 2 play-ins after 9th–10th finishes at Kickoff and Stage 1 [1]. They also had heavy roster turnover:

- N4RRATE departed in March [2].
- Jerrwin was signed in March, then covered first by stand-in Victor from April and by Marved from July [2].
- Jerrwin has reportedly been allowed to explore options [1].

Heading into 2027, the team needs a **permanent player for the slot the stand-ins have been covering**. The GM needs an evidence-based shortlist and a view of how much that signing is worth paying for.

**Business question:**
> *Which players should SEN shortlist for its vacant slot, how much can it justify spending on the top candidate, and is signing better than keeping a minimum-salary stand-in?*

## 2. Decisions this project supports

| # | Decision | Answered by | Output |
|---|---|---|---|
| D1 | **Who is on the shortlist?** (3–5 players) | Scouting page + Roster Fit page | A ranked candidate table with sample sizes and fit notes |
| D2 | **What is the maximum upfront spend** (buyout + import-slot cost) SEN can justify for a candidate? | Budget Scenarios page | The highest upfront spend with NPV ≥ 0 in the Downside, Base and Upside scenarios, shown next to the total acquisition cost (salary + buyout + fees). Redefined from "maximum total spend" in T8 (2026-09-29): salary is the same for every candidate, so the upfront amount is what the GM negotiates. See `budget_model.md` §6.4. |
| D3 | **Sign or stay?** Is a proven signing worth more than keeping a minimum-salary stand-in? | Budget Scenarios page + memo | A recommendation with its break-even condition stated |

Map and agent coverage is **not** a separate decision. It feeds D1 through the Roster Fit page.

## 3. Key questions

1. Which role does the vacant slot play? Task 2 infers it from the agents played in 2026.
2. Among eligible top-tier players in that role, who performs best in the 2026 window on transparent metrics, and who is consistent across 2025–26?
3. Which candidates match SEN's map pool and agent needs, and which would take up SEN's single import slot?
4. For a given candidate, what is the incremental cost compared with the stand-in baseline, and what yearly revenue uplift is needed to break even?
5. How sensitive is the answer to salary, buyout, contract length and SEN's 2027 partner status?

## 4. Scope

**In scope (v1)**
- **Data window:** the 2026 VCT season is the main scouting window. The 2025 season is used only for the consistency check.
- **Candidate pool:** players in top-tier VCT (partner-league and international events), across all regions.
- **Roles:** one vacant slot, whose role is confirmed in Task 2.
- **Deliverables:** a three-page Power BI report, a Tableau Public story and a recommendation memo.
- **Finance:** all amounts in USD, with every input an editable, labelled assumption.

**Out of scope / non-goals**
- **Challengers (second-tier) players.** This is the named phase-2 extension ("cheap rising talent").
- **Real salary or buyout figures.** None are public, so the project uses assumptions only.
- **Measuring communication, leadership or teamwork.** No metric claims to measure them.
- **Predicting exactly how a player will perform with new teammates.** The optional win model reports ranges only.
- **Coach or staff hiring, and changes to more than one slot.**

## 5. Constraints and rules

- **Import rule:** VCT Americas allows **one import** per team [3]. Import candidates are *flagged, not filtered*, and the trade-off is shown.
- **Eligibility:** a candidate needs **≥ 15 maps in the 2026 window** to be ranked. Players below that are shown greyed out.
- **Missing data:** missing stats stay blank and are never treated as 0. Every visual shows maps and rounds played.
- **Rating:** vlr.gg-style Rating is **shown but not used for ranking**, because it's a third-party composite whose formula we don't control.
- **Partner status:** SEN's 2027 partner status is **not assumed**. It's a scenario toggle, because Riot selects 2027 partners after Champions 2026 [4].

## 6. Success criteria

**For the stakeholder (the hypothetical GM):**
- The shortlist can be explained metric by metric, and every number traces to a source row.
- The budget page answers D2 and D3 for any candidate in under a minute, and assumptions can be changed live.
- The memo states a recommendation *and* the conditions under which it would flip.

**For the portfolio and learning goals:**
- The pipeline can be reproduced from a fresh clone, and the data tests pass.
- Power BI and Tableau show the same headline numbers.
- The work demonstrates:
  - SQL data modelling in DuckDB
  - a star schema
  - DAX measures and what-if parameters
  - Tableau storytelling
  - business-analysis documents: this brief, the KPI dictionary, the assumptions log and the memo

## 7. Deliverables → tasks

| Deliverable | Task |
|---|---|
| This brief, the KPI dictionary and the assumptions log | T1 |
| Data audit and final role confirmation | T2 |
| Power BI: Scouting / Roster Fit / Budget Scenarios | T5 / T7 / T9 |
| Tableau Public story | T10 |
| Recommendation memo | T11 |

## 8. Data (summary)

The full source list is in `tasks/plan.md` → Data Sources.

- **Performance data:** the VCT Reference DuckDB (2025–2026 filtered), with Kaggle VCT 2025 as a cross-check.
- **Contracts and residency:** the VCT Global Contract Database, which has contract end year and resident/import status but no salaries.
- **Finance context:**
  - Esports Earnings prize history
  - Riot's 2023 minimum salary
  - the VCT 2025 revenue share
  - VCT 2027 partnership payment ranges
  - Esports Charts viewership

## 9. Risks

| Risk | Mitigation |
|---|---|
| The roster situation changes before the project ends | Freeze the facts as of the Task 2 snapshot date and note that date on every page |
| The role of the vacant slot is ambiguous (flex player) | Task 2 infers it from agent share. If it's still unclear, the brief is updated to the role the stand-ins actually played |
| The budget page is mistaken for real financials | An "Assumption" label on every input, a disclaimer on the page, and Downside / Base / Upside scenarios |
| The 2026 data is incomplete in the source | Task 2 go/no-go. The fallback is Kaggle, or widening the window to include 2025 |

## Sources

1. [vlr.gg — Sentinels team profile](https://www.vlr.gg/team/2/sentinels) (2026 placements, roster, Jerrwin status)
2. [vlr.gg — Sentinels news](https://www.vlr.gg/team/news/2/sentinels/) · [Liquipedia — Sentinels](https://liquipedia.net/valorant/Sentinels) (2026 roster changes and stand-ins)
3. [Dexerto — VCT 2023 roster regulations](https://www.dexerto.com/esports/vct-2023-roster-regulations-explained-minimum-salaries-import-rules-roster-sizes-1944581/) (import rule, minimum salaries; 2023 rules)
4. [THESPIKE — VCT 2027 partnership terms](https://www.thespike.gg/valorant/news/partnered-vct-2027-teams-to-receive-up-to-5-million-per-year-under-new-format/7963)
