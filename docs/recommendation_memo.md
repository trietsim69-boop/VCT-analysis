# Recommendation Memo — Sentinels 2027 Duelist Signing

> **Unofficial fan analysis.** Not affiliated with Sentinels or Riot Games. Team facts come from public data. **Every financial number is an assumption**, not a known contract term.

| | |
|---|---|
| **To** | General Manager, Sentinels VALORANT (hypothetical) |
| **From** | Triet Le |
| **Date** | 2026-10-03 |
| **Data** | VCT 2026 before Champions (snapshot 2026-09-18). 84 duelists with at least 15 maps |

## Recommendation

1. **Shortlist Meiy, swagzor and Derke.** They have the three highest fit scores for this slot, all in the top fit band.
2. **On the Base assumptions, do not sign.** Stay with a stand-in unless you judge that the signing adds at least **23.8 points** to SEN's chance of a top-3 season. At the Base belief of 20 points (Assumption F-14), Derke falls $68,715 short over two years, and Meiy and swagzor $218,715.
3. **If you do sign, approach Derke first and Meiy second.** Derke's contract ends in 2026, so there is no buyout and his bar is the lowest. Meiy is the better fit, but his buyout raises the bar by 8.4 points. swagzor costs the same as Meiy for a lower fit score on a thinner record.
4. **Free a roster slot first.** All three are imports for SEN, and johnqt holds the import slot.

## The three candidates

| | Meiy | swagzor | Derke | Jerrwin (2026 baseline) |
|---|---|---|---|---|
| Fit score and band | 94.9, Top 10 of 84 | 88.6, Top 10 of 84 | 85.8, Top 10 of 84 | 61.7, Top half of 84 |
| Performance band (composite) | Top 10 of 84 | Top 25 of 84 | Top 25 of 84 | Bottom half of 84 |
| ADR | 153.0 | 154.0 | 147.4 | 127.0 |
| Opening duel win % | 57.1 | 52.9 | 54.1 | 51.6 |
| KAST % | 73.1 | 71.0 | 71.7 | 65.8 |
| Maps on the slot's agents (overlap) | 100% | 100% | 100% | baseline |
| ADR edge over the pool on SEN's maps, against his usual edge | +3.0 | +2.0 | +2.0 | baseline |
| Sample: maps, rounds | 55, 1,182 | 33, 701 | 71, 1,488 | 30, 658 |
| Where he played in 2026 | Pacific | China | EMEA and international | Americas |
| Contract (Riot's database) | Detonation FocusMe, to 2027 | Nova Esports, to 2027 | Team Vitality, ends 2026 | Sentinels, to 2028 |

*Source: Power BI Scouting, Roster Fit and Candidate Fit pages; Tableau story points 2 to 4; `mart_fit.csv`, `tableau_candidates.csv`.*

- **Meiy** wins 57.1% of his opening duels (96th percentile of the pool) and is above the pool's ADR on all four of SEN's most-played maps. He is first on fit under all three weightings tested (S-18). His ADR swings more from map to map than Jerrwin's (consistency at the 33rd percentile against the 75th).
- **swagzor** takes the most opening kills per round in the pool, but his deaths per round sit at the 10th percentile (fewer deaths rank higher). His record is the thinnest of the three: 33 maps, with ADR recorded on 27.
- **Derke** has the largest sample and the only one with international events. He is steady on deaths and KAST (78th percentile on both), but his ADR is the least consistent of the three (5th percentile).

## What each would cost

SEN as a 2027 partner team. "Upfront" is the buyout plus the cost of freeing the import slot. "Bar" is the break-even: the points of top-3 chance the signing must add to pay for itself against a minimum-salary stand-in.

| | Downside | Base | Upside |
|---|---|---|---|
| **Meiy, swagzor:** upfront | $775,000 | $300,000 | $50,000 |
| Two-year total cost | $1,695,000 | $740,000 | $260,000 |
| Bar (points) | cannot break even | 32.2 | 2.5 |
| NPV at the scenario's belief (10 / 20 / 35 points) | −$1,330,840 | −$218,715 | +$1,889,463 |
| **Derke:** upfront | $400,000 | $150,000 | $0 |
| Two-year total cost | $1,320,000 | $590,000 | $210,000 |
| Bar (points) | cannot break even | 23.8 | 1.6 |
| NPV at the scenario's belief | −$955,840 | −$68,715 | +$1,939,463 |
| **Most SEN can justify paying upfront** | $0 | $81,285 | $1,939,463 |

*Source: Power BI Budget Overview and Budget pages; `mart_budget_reference.csv`. Inputs F-01 to F-15 are in `docs/assumptions_log.md` § B.*

At Base, each extra point of belief justifies about $17,900 more upfront. Meiy's extra $150,000 is therefore worth paying only if you believe he adds at least 8.4 points more than Derke would.

## What would change the answer

| If | Then |
|---|---|
| You believe the signing adds 23.8 points or more | Derke reads Sign. At 32.2 or more, Meiy and swagzor do too |
| Freeing an import slot costs nothing | The bars fall to 15.5 (Derke) and 23.8 (Meiy, swagzor). Derke reads Sign at the Base belief, with an NPV of +$81,285 |
| SEN is not a 2027 partner | The Base bars rise to 52.5 (Derke) and 70.9 (Meiy, swagzor). Stay |
| Costs and revenue land at the Downside | No candidate can break even: the bar is above 100 points |
| Costs and revenue land at the Upside | Sign any of the three |
| The post-Champions data changes the fit scores | The shortlist may change. Champions 2026 is not in the data; everything is rerun after it ends on 2026-10-18 |

## The import slot

- **All three are imports for SEN.** Checked by hand on 2026-10-03: Meiy is Japanese, swagzor Russian and Derke Finnish, and none has a record of residency in the Americas [1].
- **Under the 2026 rule, SEN has one import slot and johnqt holds it** (Non-Resident, contract to 2028). Signing any of the three means moving him. The model prices only the money (Assumption F-13: $400,000 / $150,000 / $0). johnqt is SEN's in-game leader, and the cost of losing that is not in the model, so the true bar is higher than shown.
- **The 2027 rule is reported to change.** Riot says most regions will need at least 3 of 5 players from the team's own region, with the Americas split into North America, Latin America North, Latin America South and Brazil [2]. A sourced report says the same applies to partner teams, with existing rosters kept and new signings required to comply [3]. Two things to confirm with Riot before any approach:
  - If only johnqt counts as an import, SEN would have a free second slot, and the second row of the table above applies.
  - If cortezia (Brazilian) also counts as an import on a North American team, both slots are taken and the cost stays. dgzin (Brazilian) would then stop being a resident option.
- **If freeing a slot is not acceptable,** the shortlist has three players who are residents under the 2026 rule, all in the top fit band and all under contract: dgzin (fit 79.4, bar 23.8), OXY (78.9, bar 32.2) and Timotino (78.3, bar 23.8).

## Limitations

- **Sample size.** Scores rest on 33 to 71 maps. The composite does not shrink small samples toward the average, so swagzor's numbers are the least certain. Scores are shown as bands for this reason.
- **Data gaps.** Chinese league maps have missing stats: swagzor's ADR covers 27 of his 33 maps, Meiy's 53 of 55. Missing values are left blank, never treated as zero. Contract data can be stale: the China tab of Riot's database dates from 2026-07-02.
- **No adjustment for league strength.** Percentiles pool all four leagues. Meiy's and swagzor's maps are all from one league each, with no international events.
- **No teammate-effect evidence.** Nothing here measures how a player would perform with SEN's roster, or his communication. The fit score says who has played well, on the right agents, on SEN's maps.
- **The finances are assumptions.** No salary or buyout is public. Every candidate is given the same salary and the same revenue effect, so the model cannot rank players: only contract length and the import slot move the cost. The added top-3 chance (F-14) is the weakest input, which is why the break-even is the headline and not the NPV. The minimum salary, import limit and partner payments are carried over from 2026, because the 2027 rules are not published.
- **The vacancy is reported, not confirmed.** Jerrwin was reportedly allowed to explore options on 2026-09-15 [4], but Riot's database still lists him as active to 2028.

## Sources

Numbers come from the project's marts and the two dashboards: the [Power BI report](../powerbi/README.md) and the [Tableau story](../tableau/README.md). Method and inputs are in [`budget_model.md`](budget_model.md) and [`assumptions_log.md`](assumptions_log.md).

1. Player profiles on [Liquipedia](https://liquipedia.net/valorant/Meiy) and vlr.gg ([swagzor](https://www.vlr.gg/player/45492/swagzor), [Derke](https://www.vlr.gg/player/5022/derke)); Riot's Global Contract Database, EMEA and Pacific tabs. Accessed 2026-10-03.
2. Riot Games, [Get ready for VCT 2027 Open Qualifiers](https://valorantesports.com/en-US/news/get-ready-for-vct-2027-open-qualifiers), 2026-09-08.
3. Sheep Esports, [Riot Games set to end VCT academy rosters in 2027](https://www.sheepesports.com/en/articles/sources-riot-games-set-to-end-vct-academy-rosters-in-2027-game-changers-teams-still-allowed/en), 2026-09-10, citing Riot's Leo Faria.
4. vlr.gg, [Sentinels allow Jerrwin to explore options](https://www.vlr.gg/756240/sentinels-allow-jerrwin-to-explore-options), 2026-09-15.
