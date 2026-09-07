# Research questions and stakeholder interpretation

The SQL research explores questions for a UK pharmaceutical/biotechnology portfolio strategy team, with clinical-operations and reporting uses. The analysis informs what to investigate; it does not demonstrate a stakeholder implemented a recommendation.

## Question-to-analysis map

| Query | Stakeholder question | Analysis and intended use | Report connection |
| --- | --- | --- | --- |
| [1. Trial activity](../sql/03_portfolio_analysis.sql#L82) | How has trial-start activity changed? | Year counts and year-on-year change; benchmark activity. | Trial Overview |
| [2. Phase mix](../sql/03_portfolio_analysis.sql#L183) | Which phases account for changes in activity? | Phase/year comparisons; understand portfolio composition. | Trial Overview |
| [3. Sponsor concentration](../sql/03_portfolio_analysis.sql#L311) | Who accounts for the most activity? | Sponsor ranks and cumulative shares; broaden competitive benchmarking. | Supporting portfolio research |
| [4. Enrollment](../sql/03_portfolio_analysis.sql#L453) | How does recorded enrollment differ by phase? | Medians and upper percentiles; frame recruitment capacity. | Portfolio & Delivery |
| [5. Sites and geography](../sql/03_portfolio_analysis.sql#L565) | How large are delivery networks by phase? | Site/country distributions; frame coordination requirements. | Portfolio & Delivery |
| [6. Completed duration](../sql/03_portfolio_analysis.sql#L719) | Which phases have longer completed-trial timelines? | Completed-trial duration distributions; inform schedule assumptions. | Portfolio & Delivery, with a different duration scope |
| [7. UK participation](../sql/03_portfolio_analysis.sql#L836) | How does UK participation change by start year? | UK share among known-geography trials; review geographic assumptions. | Geographic & Reporting |
| [8. Country shifts](../sql/03_portfolio_analysis.sql#L1016) | Which markets gained or lost participation? | 2015/2025 country comparisons; identify feasibility questions. | Geographic & Reporting |
| [9. Recorded discontinuation](../sql/03_portfolio_analysis.sql#L1211) | Where are terminated/withdrawn outcomes more common? | Resolved-outcome rates; prioritise descriptive portfolio review. | Portfolio & Delivery, with a different numerator |
| [10. Reported stop reasons](../sql/03_portfolio_analysis.sql#L1385) | What reasons do sponsors record? | Inspect raw free text before categorisation; avoid assumed causes. | Supporting delivery research |
| [11. Stop-reason categories](../sql/03_portfolio_analysis.sql#L1468) | What recurring themes appear in reported reasons? | Ordered keyword classification; distinguish recruitment, business and other themes. | Supporting delivery research |
| [12. Results visibility](../sql/03_portfolio_analysis.sql#L1674) | Where are public results less available? | Coverage among mature completed trials; guide evidence-availability follow-up. | Geographic & Reporting |

## Findings used in the portfolio write-up

The README uses final-export values verified offline: Phase 3 median enrollment/sites **312/24**, versus Phase 1 **36/1**; UK participation **17.6% in 2015** versus **12.8% in 2025** among known-geography trials; mature results coverage **18.2% in Phase 1** versus **71.3% in Phase 3**. These support recruitment/site planning, geographic review and public-evidence monitoring respectively. [Denominators and QA](methodology.md).

The wider research adds sponsor benchmarking and inspection of recorded stop reasons. These remain useful analytical work even though they do not have standalone dashboard visuals. Sponsor names are not consolidated corporate groups; free-text categories are heuristic, order-dependent and not verified causes. Avoid presenting either as investment guidance or causal evidence.

## Earlier SQL results are not the final dashboard refresh

The research file retains original numerical comments and all query logic. Those comments are historical recorded outputs, not newly executed database results. For example, older comments record Phase 3 median enrollment/sites of **308/30**, UK 2025 share of **12.9%**, and Phase 1 results eligibility of **9,810**. The final export uses **312/24**, **12.8%**, and **9,815** respectively. Different snapshots and query filters prevent direct substitution.

- Query 1 includes starts up to `CURRENT_DATE`; queries 2–11 generally restrict starts to 2015–2025. Query 8 compares 2015 and 2025 and retains countries with at least 100 trials in either year.
- Query 6 uses completed trials with valid non-negative dates. Dashboard duration includes ongoing/planned trials with valid dates.
- Query 9 uses **terminated + withdrawn** divided by **completed + terminated + withdrawn**, and phase groups with at least 100 resolved trials. Dashboard DAX uses **terminated only** in the numerator. Neither measures clinical failure probability.
- Queries 10–11 inspect terminated/withdrawn trials in Phase 2, Phase 1/2, Phase 2/3 and Phase 3. Query 10 excludes empty reasons; query 11 retains a not-reported category. Keyword matches do not establish root causes.
- Query 12 uses completed trials with a primary-completion reporting window of at least 18 months and phase groups with at least 100 eligible trials. Dashboard coverage includes small phase groups too. Coverage does not establish regulatory compliance.

Each query is independently executable against AACT. Read its filters before comparing outputs. [Source access, evidence and execution](sources-and-validation.md).
