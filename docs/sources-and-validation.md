# Data sourcing, ingestion and validation

## Dashboard source: AACT

The dashboard uses ClinicalTrials.gov data represented in AACT's PostgreSQL `ctgov` schema. The supplied SQL proves use of that relational source and the CSV exports provide the final dashboard inputs. The files do **not** establish whether the original database was accessed in the cloud or restored locally, nor identify the final snapshot download, restore command, checksum or extraction timestamp. No full extraction/restore was rerun during packaging.

For a future reproduction, use an existing AACT connection or obtain a PostgreSQL snapshot from the [official downloads page](https://aact.ctti-clinicaltrials.org/downloads), following its restoration instructions. [Official cloud-access instructions](https://aact.ctti-clinicaltrials.org/connect) provide the alternative. These are access routes, not claims about Max's historical setup. Record the snapshot identifier, extraction time and analysis date before re-exporting. Raw database dumps and personal connection configuration do not belong in this repository.

## PostgreSQL execution and evidence

1. [Source profiling](../sql/00_source_profile.sql): source count, cohort, date range and multiplication from child joins.
2. [Trial core and bridges](../sql/01_trial_core_and_bridges.sql): cohort `EXISTS` logic, bridge grains, parent-key coverage and missingness checks.
3. [Curated outputs](../sql/02_curated_views.sql): run **query 1** for `fact_trials_powerbi.csv` and **query 5** for `bridge_trial_country.csv`; the other queries profile and validate the curated layer. Export UTF-8 CSV with headers to `data/`.
4. [Portfolio research](../sql/03_portfolio_analysis.sql): run numbered queries separately to investigate the [stakeholder questions](research.md).
5. Inspect the saved PBIX and validate any refresh using the [Power BI checklist](methodology.md).

These are SELECT/CTE packs, not migrations that create persistent tables/views. They require AACT source tables; the two exported CSVs alone do not supply those tables.

Original evidence records **46,905** unique AACT cohort trials and **101,476** joined rows in the naive join. [Cohort result](evidence/01_cohort_reconciliation.png) · [Join-multiplication result](evidence/02_bridge_row_multiplication.png). Bridge-check comments document zero invalid foreign keys and condition/intervention coverage for that earlier cohort. These are original recorded checks, not newly executed SQL. The final **46,955**-trial CSV checks are described in [methodology](methodology.md) and reproducible with [verify_exports.py](../scripts/verify_exports.py).

## Supporting API ingestion: 200-study sample

The [ingestion notebook](../notebooks/clinicaltrials_api_ingestion.ipynb) demonstrates ClinicalTrials.gov API pagination, capped downloading, JSON/manifest creation, nested-table normalisation, and parent-child assertions. It is project-specific supporting work, **not the extraction of the full dashboard cohort**.

The [original manifest](../data/development/extract-manifest.json) records **2026-08-26T23:54:40.652302+01:00**, four pages of 50 studies and 200 downloaded records. Saved source-notebook output records **46,911 API matches**, not 46,911 downloaded records. Original QA reports 200 unique trial IDs, 450 interventions, 309 conditions and 3,534 locations, with no invalid child keys; 188 trials have locations. [Original QA screenshot](evidence/ingestion-qa.png). The [four sample CSVs](../data/development/README.md) are retained as compact development evidence, separate from the final exports.

The manifest names a raw JSON absent from the supplied ZIP. A source NDJSON was present, but cannot establish the byte hash of that missing JSON. No claim is made that the original raw-file hash has been verified. Large/raw nested content is omitted; it is unnecessary for viewing the dashboard.

**Date handling:** Dates are parsed once using `format="mixed"`. The earlier duplicate conversion has been removed. The revised notebook has not yet been rerun, so validation against the original input dates remains pending.

To deliberately rerun the optional API route, first agree the date-handling correction; use pandas, requests and Jupyter/ipykernel, create `data/raw/` and `data/processed/`, and launch from `notebooks/` so relative paths resolve. Execution makes live requests and can return a different sample. Outputs/counts were cleared in the published notebooks; analytical cells were preserved and no new API execution is claimed.

## Supporting BigQuery checks

[NDJSON preparation](../notebooks/prepare_bigquery_sample.ipynb) converts the development JSON to one study per line. [BigQuery queries](../sql/supporting/bigquery_sample_checks.sql) check parent IDs and UNNEST interventions/locations. Original comments report 200 unique parents, 450 interventions and 3,534 locations, with 188 located trials. This is **limited author-reported sample structural validation**, not completed independent reconciliation of full-cohort portfolio metrics. It was not rerun here.

The original personal cloud project identifier was replaced with `YOUR_PROJECT.YOUR_DATASET`; supply your own destination only if executing this optional route. No credentials are included. Preparing NDJSON still requires the missing original JSON or an intentionally regenerated sample.

## Scope of this review

The clinical-trials source notes, project contract, grain map, SQL, notebook code and saved outputs, manifests, CSVs and dashboard artefacts were inspected. The broader repository was searched for clinical-trials/AACT material. Generic Excel/financial exercises, general Python/pandas/window-function drills and environment troubleshooting remain excluded. The original planned condition/facility questions are not claimed as completed dashboard analyses where no corresponding finished result is supplied.

Final-export offline checks are new packaging QA, separate from historical checks. Readable delivered code, notebook content, text and CSVs were scanned for common credentials and private-path patterns. Notebook outputs were inspected before clearing, and the personal BigQuery identifier was removed. The compressed PBIX model was not decoded: embedded connection settings and refresh still require local review. No Excel validation, full-cohort BigQuery reconciliation or measured stakeholder impact is claimed.
