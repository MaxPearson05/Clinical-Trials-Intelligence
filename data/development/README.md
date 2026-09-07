# API development sample

Public ClinicalTrials.gov-derived tables from the original 200-study development extraction. These are supporting ingestion/structural evidence and **not** the dashboard dataset. See [sources and limitations](../../docs/sources-and-validation.md), including the notebook date-parsing issue and missing original raw JSON.

| File | Grain | Rows |
| --- | --- | ---: |
| [trials_dev_200.csv](trials_dev_200.csv) | Study | 200 |
| [interventions_dev_200.csv](interventions_dev_200.csv) | Study-intervention record | 450 |
| [conditions_dev_200.csv](conditions_dev_200.csv) | Study-condition record | 309 |
| [locations_dev_200.csv](locations_dev_200.csv) | Study-location record | 3,534 |

[Extraction manifest](extract-manifest.json). All child trial IDs belong to the 200 parent IDs; those structural checks were repeated during packaging. They do not validate the sample's analytical date conversions.
