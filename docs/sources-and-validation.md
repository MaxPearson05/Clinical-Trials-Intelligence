# Data sourcing, ingestion and validation

## Dashboard source: AACT

The dashboard analysis uses ClinicalTrials.gov data in AACT's PostgreSQL `ctgov` schema. The two CSV exports contain the archived dashboard dataset. The final snapshot identifier and extraction timestamp were not recorded. The repository does not identify whether the database was accessed through AACT's hosted service or restored locally.

To reproduce the analysis, use an existing AACT connection or obtain a PostgreSQL snapshot from the [official downloads page](https://aact.ctti-clinicaltrials.org/downloads), following its restoration instructions. [Official cloud-access instructions](https://aact.ctti-clinicaltrials.org/connect) describe the hosted alternative. Record the snapshot identifier, extraction time and analysis date before re-exporting. Keep raw database dumps and personal connection configuration outside the repository.

## PostgreSQL execution and evidence

1. [Source profiling](../sql/00_source_profile.sql): source count, cohort, date range and multiplication from child joins.
2. [Trial core and bridges](../sql/01_trial_core_and_bridges.sql): cohort `EXISTS` logic, bridge grains, parent-key coverage and missingness checks.
3. [Curated outputs](../sql/02_curated_views.sql): run **query 1** for `fact_trials_powerbi.csv` and **query 5** for `bridge_trial_country.csv`; the other queries profile and validate the curated layer. Export UTF-8 CSV with headers to `data/`.
4. [Portfolio research](../sql/03_portfolio_analysis.sql): run numbered queries separately to investigate the [analytical questions](research.md).
5. Inspect the saved PBIX and validate any refresh using the [Power BI checklist](methodology.md).

These are SELECT/CTE packs, not migrations that create persistent tables/views. They require AACT source tables; the two exported CSVs alone do not supply those tables.

Historical evidence records **46,905** unique AACT cohort trials and **101,476** rows after joining sponsor and intervention records. [Cohort result](evidence/01_cohort_reconciliation.png) · [Join-multiplication result](evidence/02_bridge_row_multiplication.png). Bridge-check comments document zero invalid foreign keys and condition/intervention coverage for that earlier cohort. The final **46,955**-trial CSV checks are described in [methodology](methodology.md) and reproducible with [verify_exports.py](../scripts/verify_exports.py).

## Supporting API ingestion: 200-study sample

The [ingestion notebook](../notebooks/clinicaltrials_api_ingestion.ipynb) demonstrates ClinicalTrials.gov API pagination, capped downloading, JSON/manifest creation, nested-table normalisation, and parent-child assertions. It is project-specific supporting work, **not the extraction of the full dashboard cohort**.

The [original manifest](../data/development/extract-manifest.json) records **2026-08-26T23:54:40.652302+01:00**, four pages of 50 studies and 200 downloaded records. Saved source-notebook output records **46,911 API matches**, not 46,911 downloaded records. Structural checks of the archived CSVs on **8 September 2026** confirm 200 unique trial IDs, 450 interventions, 309 conditions and 3,534 locations, with no blank or duplicate parent IDs and no orphan child rows; 188 trials have locations. [Archived sample validation summary](evidence/ingestion-qa.png). These checks do not validate date conversion or reproduce the API extraction. The [four sample CSVs](../data/development/README.md) are retained as compact development evidence, separate from the final exports.

The original raw JSON named in the sample manifest is not included, so its recorded SHA-256 hash cannot be checked from this repository. The archived CSVs support structural inspection; rerunning the API notebook creates a new sample.

**Date handling:** The notebook parses dates once using `format="mixed"`. Validation of the revised parsing against the original raw dates remains outstanding. The revised notebook has not yet been rerun.

To generate a new API sample, install pandas, requests and Jupyter/ipykernel, create `data/raw/`, and run the ingestion notebook from `notebooks/` so relative paths resolve. Execution retrieves live records and may return a different sample. Regenerated CSVs are written to `data/processed/`; `data/development/` contains the archived sample. A new extraction does not reproduce or validate the missing historical raw input.

## Supporting BigQuery checks

[NDJSON preparation](../notebooks/prepare_bigquery_sample.ipynb) converts the API JSON to one study per line. [BigQuery queries](../sql/supporting/bigquery_sample_checks.sql) check parent IDs and UNNEST interventions/locations. Historical comments report 200 unique parents, 450 interventions and 3,534 locations, with 188 located trials. These are structural checks on the 200-study sample, not completed independent reconciliation of full-cohort portfolio metrics.

Load the NDJSON into a BigQuery table named `raw_trials_200` and replace `YOUR_PROJECT.YOUR_DATASET` in the SQL with that table's project and dataset. The original raw sample is not included; run the API notebook first to generate a new input if needed.
