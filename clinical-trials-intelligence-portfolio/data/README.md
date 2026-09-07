# Supporting data

These are the supplied final AACT-derived **study-level and trial-country exports**, not patient-level data. They are retained byte-for-byte to support offline inspection and preserve the PBIX source schema. No large raw AACT snapshot or participant records are included. Final extraction date: unconfirmed; see [methodology](../docs/methodology.md).

| File | Grain | Rows |
| --- | --- | ---: |
| [fact_trials_powerbi.csv](fact_trials_powerbi.csv) | One trial per `nct_id` | 46,955 |
| [bridge_trial_country.csv](bridge_trial_country.csv) | One retained trial-country pair (including one blank country row) | 146,859 |

## Fact fields

| Fields | Meaning |
| --- | --- |
| `nct_id`, `brief_title` | Registry identifier and public trial title |
| `overall_status`, `phase` | Recorded status/phase; literal `NA` is not applicable, empty is missing |
| `start_date`, `start_year` | Recorded start and derived year, including future planned dates |
| `primary_completion_date`, `completion_date` | Recorded primary/final completion dates; estimated/actual type not retained |
| `duration_days` | Completion minus start when non-negative, otherwise empty |
| `enrollment` | Recorded enrollment, without enrollment type |
| `lead_sponsor` | Distinct qualifying lead names concatenated with ` | ` |
| `country_count`, `uk_participation` | Non-null retained country count and UK presence flag |
| `site_count` | Distinct facility ID count |
| `why_stopped` | Public registry free text, often empty |
| `results_first_posted_date`, `results_posted` | Posted-date value and its non-null flag |
| `mature_results_eligible` | Frozen export-time eligibility flag; [rule](../docs/methodology.md) |

The bridge contains `nct_id`, `phase`, `overall_status`, `start_year`, `country_name`, `is_uk`. Repeated trial IDs across countries are expected. Count distinct trial IDs for country participation, and exclude the blank country when counting named countries.

Both files are UTF-8 CSV. Read booleans explicitly, preserve `NA` as text, and treat empty numeric/date fields as missing. In pandas use `keep_default_na=False` before converting numeric/date columns. These exports cannot independently prove cohort membership against omitted source tables.

Source acknowledgement: [Aggregate Analysis of ClinicalTrials.gov (AACT), Clinical Trials Transformation Initiative (CTTI)](https://aact.ctti-clinicaltrials.org/), using public ClinicalTrials.gov records. AACT reference page accessed for packaging on 7 September 2026; this is not the extraction date. No additional data licence or ownership claim is asserted by this packaging.
