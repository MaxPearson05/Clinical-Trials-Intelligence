-- Supporting 200-study structural checks only, not full-cohort reconciliation.
-- Replace YOUR_PROJECT.YOUR_DATASET with your own BigQuery destination.
-- Result comments are original author-reported values; not re-executed here.
-- QA 1: Confirm parent trial count

SELECT
    COUNT(*) AS trial_records
FROM `YOUR_PROJECT.YOUR_DATASET.raw_trials_200`;

-- trial_records 200

-- QA 2: Confirm one unique ClinicalTrials.gov ID per parent record

SELECT
    COUNT(*) AS trial_records,
    COUNT(DISTINCT protocolSection.identificationModule.nctId) AS unique_nct_ids
FROM `YOUR_PROJECT.YOUR_DATASET.raw_trials_200`;

-- trial_records 200
-- unique_nct_ids 200

-- QA 3: UNNEST interventions
-- Grain after UNNEST: one row per trial-intervention

SELECT
    COUNT(*) AS intervention_rows,
    COUNT(DISTINCT protocolSection.identificationModule.nctId) AS unique_trials
FROM `YOUR_PROJECT.YOUR_DATASET.raw_trials_200`,
UNNEST(protocolSection.armsInterventionsModule.interventions) AS intervention;

-- Validation:
-- BigQuery UNNEST returned 450 intervention records,
-- reconciling exactly to the 450 interventions produced
-- independently by the development Python ingestion pipeline.

-- QA 4: UNNEST trial locations
-- Grain after UNNEST: one row per trial-location

SELECT
    COUNT(*) AS location_rows,
    COUNT(DISTINCT protocolSection.identificationModule.nctId) AS unique_trials
FROM `YOUR_PROJECT.YOUR_DATASET.raw_trials_200`,
UNNEST(protocolSection.contactsLocationsModule.locations) AS location;

-- Validation:
-- 3,534 location records reconciled exactly to the development Python extraction.
-- 188 of 200 parent trials contained at least one location record.
-- CROSS JOIN UNNEST excludes parent trials with empty/null location arrays.
