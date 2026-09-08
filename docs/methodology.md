# Methodology and validation

## Cohort and model

The [fact query](../sql/02_curated_views.sql) selects `INTERVENTIONAL` studies starting on/after `2015-01-01`, with an `INDUSTRY` lead sponsor and at least one `DRUG` or `BIOLOGICAL` intervention. Recorded conditions are not an additional inclusion predicate. Sponsor, country and facility records are aggregated before joining; `EXISTS` avoids multiplying trials during cohort selection.

`FactTrials` contains **46,955 unique trials**. The [country query](../sql/02_curated_views.sql) produces **146,859 trial-country rows**, linked one-to-many by `nct_id`. Countries marked removed are excluded (`removed = FALSE OR IS NULL`). Relationship filter direction and interactive filtering remain to be verified in Power BI.

## Metric definitions

| Metric | Rule and verified value |
| --- | --- |
| Trials | Distinct fact `nct_id`: 46,955 |
| Completed / terminated | Recorded status `COMPLETED`: 24,633; `TERMINATED`: 4,609 |
| Terminated share | 4,609 / 46,955 = 9.8% |
| UK participation | Fact UK flag: 6,452; denominator is 44,091 trials with `country_count > 0`; share 14.6% |
| Country participation | Distinct bridge trial IDs per country; country totals overlap |
| Mature eligible | Completed, primary completion date present and at least 18 months before SQL execution date: 22,021 |
| Posted eligible / coverage | Eligible and `results_first_posted_date IS NOT NULL`: 9,513 / 22,021 = 43.2%; 12,508 eligible trials have no posted date |
| Enrollment | Recorded values; median and inclusive 75th percentile. Planned/actual enrollment type is absent |
| Sites / countries | Distinct facility IDs / non-null retained country names; zero when no matching records |
| Duration months | Median non-negative `(completion_date - start_date) / 30.4375`, including ongoing/planned trials with valid dates |
| Dashboard “Discontinuation Rate” | Terminated / (completed + terminated + withdrawn), in filter context; suspension is excluded |

Eligibility uses `(CURRENT_DATE - INTERVAL '18 months')::DATE`. The supplied flags match an observed primary-completion cutoff of **2025-03-01**; this does not prove the extraction date. Coverage counts posted results at any recorded date, not necessarily within 18 months. Across the whole cohort 12,462 trials have posted results; only 9,513 belong to the eligible denominator.

The existing discontinuation label means **terminated share among final-status trials**, not clinical failure probability. Earlier exploratory SQL included withdrawn trials in the numerator; that different definition was not substituted into the report. Duration is a recorded interval, not exclusively completed delivery time. Medians and country totals are non-additive.

## Findings and QA

The [verification script](../scripts/verify_exports.py) checks the archived CSV exports without modifying them. It validates identifier uniqueness, bridge relationships, derived fields and headline metrics. These checks are separate from the historical SQL checks and do not test the live AACT source or Power BI model.

- All ten headline figures reconcile. No duplicate/blank fact IDs, duplicate trial-country pairs or orphan bridge IDs were found. UK flags and nonblank country counts match the bridge.
- Results-date flags, start years, non-negative duration derivation and observed maturity rules agree across all rows. No negative exported enrollment, site, country or duration values were found.
- Missingness: 8 enrollment values, 91 completion dates, 99 durations and 3 phases. Eight completion dates precede start dates; their durations are blank under the existing SQL rule. Literal phase `NA` means “Not applicable” (811 trials), not missing.
- One blank country row belongs to `NCT07221149`, alongside 20 named countries. It is retained and does not alter UK or known-geography totals. Exclude blank country categories in geographic displays.
- UK trend denominators are **579 / 3,283** in 2015 and **514 / 4,003** in 2025. Eligible results coverage is **1,782 / 9,815** in Phase 1 and **3,252 / 4,559** in Phase 3. The gap is 53.2 percentage points using unrounded rates. Full-cohort median enrollment/sites are 36/1 and 312/24 respectively.

The final CSVs omit source study-type/intervention details, so the export checks cannot independently re-establish every cohort predicate. Static report inspection confirms three pages and historical-chart year exclusions; it does not test interactions or refresh. Full-cohort BigQuery reconciliation has not been completed.

## Source version and limitations

The final AACT snapshot identifier and extraction timestamp were not recorded. Earlier evidence contains **46,911 live API matches** and **46,905 AACT trials**; the dashboard exports contain **46,955 trials**. The missing historical ID sets prevent record-level reconciliation between these stages. The API sample timestamp is not the final dashboard extraction date.

Registry data is self-reported, mutable and may include estimated dates. Full-cohort starts range from 2015 to 2050; historical charts show 2015–2025. Observations are descriptive, not causal. Public results visibility does not establish legal compliance. Small phase groups can produce unstable rates.

Full [source access, research execution order and original validation evidence](sources-and-validation.md) are documented separately.

## Execution and Power BI checks

1. **Offline inspection:** open the saved PBIX before refresh and compare cards to the README. Run `python scripts/verify_exports.py` from the repository root using Python 3.10+ (standard library only).
2. **Optional source reproduction:** use an existing PostgreSQL AACT `ctgov` database. Run query 1 of `sql/02_curated_views.sql`, exporting its result to `data/fact_trials_powerbi.csv`; run query 5 of that file, exporting to `data/bridge_trial_country.csv`. Use UTF-8 CSV with headers. Both are SELECT queries, not database migrations. Exact historical reproduction requires the missing snapshot/run date; later execution changes source contents and maturity eligibility.
3. **Power BI:** inspect Power Query Source/Advanced Editor and Data source settings for paths, server details or private configuration. Repoint CSV sources in a working copy where appropriate, preserving table names and transformations. A PostgreSQL source cannot be assumed interchangeable without review. Check date/numeric/boolean types and preserve literal `NA`.
4. **Validate locally:** confirm one-to-many cardinality, filter direction, documented DAX, country/phase cross-filtering, page navigation, map loading, Top 8 totals and year filters. The supplied year charts exclude specific future-year values; review that list after refresh. Review discontinuation/duration labels before changing any calculation.

Power BI connection settings, refresh and interactions remain to be checked locally. Offline CSV validation does not inspect the embedded model or connection configuration.
