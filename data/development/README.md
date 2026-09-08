# API development sample

These four ClinicalTrials.gov tables contain the archived 200-study API sample. They demonstrate normalisation and parent-child relationships and are separate from the dashboard dataset. The original raw JSON is not included, and the revised notebook date parsing remains unverified against that input. See [sources and limitations](../../docs/sources-and-validation.md).

| File | Grain | Rows |
| --- | --- | ---: |
| [trials_dev_200.csv](trials_dev_200.csv) | Study | 200 |
| [interventions_dev_200.csv](interventions_dev_200.csv) | Study-intervention record | 450 |
| [conditions_dev_200.csv](conditions_dev_200.csv) | Study-condition record | 309 |
| [locations_dev_200.csv](locations_dev_200.csv) | Study-location record | 3,534 |

[Extraction manifest](extract-manifest.json). All child trial IDs belong to the 200 parent IDs. These structural checks do not validate the sample's analytical date conversions.
