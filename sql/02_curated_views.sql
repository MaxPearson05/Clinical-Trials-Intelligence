-- Query 1: Curated trial-level analytical view
-- Grain: one row per nct_id

WITH trial_core AS (
    SELECT
        s.nct_id,
        s.brief_title,
        s.overall_status,
        s.phase,
        s.start_date,
        s.primary_completion_date,
        s.completion_date,
        s.enrollment,
        s.why_stopped,
        s.results_first_posted_date
    FROM ctgov.studies AS s
    WHERE s.study_type = 'INTERVENTIONAL'
        AND s.start_date >= DATE '2015-01-01'
        AND EXISTS (
            SELECT 1
            FROM ctgov.sponsors AS sp
            WHERE sp.nct_id = s.nct_id
                AND sp.lead_or_collaborator = 'lead'
                AND sp.agency_class = 'INDUSTRY'
        )
        AND EXISTS (
            SELECT 1
            FROM ctgov.interventions AS i
            WHERE i.nct_id = s.nct_id
                AND i.intervention_type IN ('DRUG', 'BIOLOGICAL')
        )
),

lead_sponsor AS (
    SELECT
        sp.nct_id,
        STRING_AGG(
            DISTINCT sp.name,
            ' | '
            ORDER BY sp.name
        ) AS lead_sponsor
    FROM ctgov.sponsors AS sp
    WHERE sp.lead_or_collaborator = 'lead'
        AND sp.agency_class = 'INDUSTRY'
    GROUP BY sp.nct_id
),

country_summary AS (
    SELECT
        c.nct_id,
        COUNT(DISTINCT c.name) AS country_count,
        BOOL_OR(c.name = 'United Kingdom') AS uk_participation
    FROM ctgov.countries AS c
    WHERE c.removed = FALSE
       OR c.removed IS NULL
    GROUP BY c.nct_id
),

site_summary AS (
    SELECT
        f.nct_id,
        COUNT(DISTINCT f.id) AS site_count
    FROM ctgov.facilities AS f
    GROUP BY f.nct_id
)

SELECT
    tc.nct_id,

    REPLACE(
        REPLACE(tc.brief_title, CHR(13), ' '),
        CHR(10),
        ' '
    ) AS brief_title,

    tc.overall_status,
    tc.phase,
    tc.start_date,
    EXTRACT(YEAR FROM tc.start_date)::INT AS start_year,
    tc.primary_completion_date,
    tc.completion_date,

    CASE
        WHEN tc.completion_date >= tc.start_date
        THEN tc.completion_date - tc.start_date
    END AS duration_days,

    tc.enrollment,

    REPLACE(
        REPLACE(ls.lead_sponsor, CHR(13), ' '),
        CHR(10),
        ' '
    ) AS lead_sponsor,

    COALESCE(cs.country_count, 0) AS country_count,
    COALESCE(cs.uk_participation, FALSE) AS uk_participation,
    COALESCE(ss.site_count, 0) AS site_count,

    REPLACE(
        REPLACE(tc.why_stopped, CHR(13), ' '),
        CHR(10),
        ' '
    ) AS why_stopped,

    tc.results_first_posted_date,

    CASE
        WHEN tc.results_first_posted_date IS NOT NULL THEN TRUE
        ELSE FALSE
    END AS results_posted,

    CASE
        WHEN tc.overall_status = 'COMPLETED'
         AND tc.primary_completion_date IS NOT NULL
         AND tc.primary_completion_date
             <= (CURRENT_DATE - INTERVAL '18 months')::DATE
        THEN TRUE
        ELSE FALSE
    END AS mature_results_eligible

FROM trial_core AS tc
LEFT JOIN lead_sponsor AS ls
    ON tc.nct_id = ls.nct_id
LEFT JOIN country_summary AS cs
    ON tc.nct_id = cs.nct_id
LEFT JOIN site_summary AS ss
    ON tc.nct_id = ss.nct_id
ORDER BY
    tc.start_date,
    tc.nct_id;
-- Result / purpose:
-- Creates a curated trial-level analytical output at one row per nct_id.
-- Sponsor, country and facility data are pre-aggregated before joining
-- so one-to-many child records do not multiply the trial-level grain.
-- LEFT JOINs preserve trials with missing sponsor, country or site data.
-- Adds analyst-friendly fields including start year, lead sponsor,
-- country count, UK participation flag and site count for downstream
-- SQL analysis and Power BI reporting.

-- Query 2: Validate curated trial-level grain
-- Confirm one row per nct_id after joining aggregated child data

WITH trial_core AS (

    SELECT
        s.nct_id,
        s.brief_title,
        s.overall_status,
        s.phase,
        s.start_date,
        s.completion_date,
        s.enrollment

    FROM ctgov.studies AS s

    WHERE s.study_type = 'INTERVENTIONAL'
        AND s.start_date >= DATE '2015-01-01'

        AND EXISTS (
            SELECT 1
            FROM ctgov.sponsors AS sp
            WHERE sp.nct_id = s.nct_id
                AND sp.lead_or_collaborator = 'lead'
                AND sp.agency_class = 'INDUSTRY'
        )

        AND EXISTS (
            SELECT 1
            FROM ctgov.interventions AS i
            WHERE i.nct_id = s.nct_id
                AND i.intervention_type IN ('DRUG', 'BIOLOGICAL')
        )
),

lead_sponsor AS (

    SELECT
        sp.nct_id,
        STRING_AGG(
            DISTINCT sp.name,
            ' | '
            ORDER BY sp.name
        ) AS lead_sponsor

    FROM ctgov.sponsors AS sp

    WHERE sp.lead_or_collaborator = 'lead'
        AND sp.agency_class = 'INDUSTRY'

    GROUP BY sp.nct_id
),

country_summary AS (

    SELECT
        c.nct_id,
        COUNT(DISTINCT c.name) AS country_count,
        BOOL_OR(c.name = 'United Kingdom') AS uk_participation

    FROM ctgov.countries AS c

    WHERE c.removed = FALSE
       OR c.removed IS NULL

    GROUP BY c.nct_id
),

site_summary AS (

    SELECT
        f.nct_id,
        COUNT(DISTINCT f.id) AS site_count

    FROM ctgov.facilities AS f

    GROUP BY f.nct_id
),

curated_trials AS (

    SELECT
        tc.nct_id,
        tc.brief_title,
        tc.overall_status,
        tc.phase,
        tc.start_date,
        EXTRACT(YEAR FROM tc.start_date)::INT AS start_year,
        tc.completion_date,
        tc.enrollment,
        ls.lead_sponsor,
        COALESCE(cs.country_count, 0) AS country_count,
        COALESCE(cs.uk_participation, FALSE) AS uk_participation,
        COALESCE(ss.site_count, 0) AS site_count

    FROM trial_core AS tc

    LEFT JOIN lead_sponsor AS ls
        ON tc.nct_id = ls.nct_id

    LEFT JOIN country_summary AS cs
        ON tc.nct_id = cs.nct_id

    LEFT JOIN site_summary AS ss
        ON tc.nct_id = ss.nct_id
)

SELECT
    COUNT(*) AS row_count,
    COUNT(DISTINCT nct_id) AS unique_trial_count,
    COUNT(*) - COUNT(DISTINCT nct_id) AS duplicate_count

FROM curated_trials;

-- Result:
-- Row count: 46,905
-- Unique trials: 46,905
-- Duplicate count: 0
--
-- Confirms that the curated trial-level output preserves
-- exactly one row per nct_id after adding aggregated sponsor,
-- country and facility information.
-- No trial duplication was introduced.

-- Query 3: Curated intervention-type analytical output
-- Grain: one row per trial-intervention type

WITH trial_core AS (

    SELECT
        s.nct_id,
        s.phase,
        s.overall_status,
        s.start_date

    FROM ctgov.studies AS s

    WHERE s.study_type = 'INTERVENTIONAL'
        AND s.start_date >= DATE '2015-01-01'

        AND EXISTS (
            SELECT 1
            FROM ctgov.sponsors AS sp
            WHERE sp.nct_id = s.nct_id
                AND sp.lead_or_collaborator = 'lead'
                AND sp.agency_class = 'INDUSTRY'
        )

        AND EXISTS (
            SELECT 1
            FROM ctgov.interventions AS i
            WHERE i.nct_id = s.nct_id
                AND i.intervention_type IN ('DRUG', 'BIOLOGICAL')
        )
)

SELECT DISTINCT
    tc.nct_id,
    tc.phase,
    tc.overall_status,
    EXTRACT(YEAR FROM tc.start_date)::INT AS start_year,
    i.intervention_type

FROM trial_core AS tc

INNER JOIN ctgov.interventions AS i
    ON tc.nct_id = i.nct_id

WHERE i.intervention_type IN ('DRUG', 'BIOLOGICAL')

ORDER BY
    tc.nct_id,
    i.intervention_type;

-- Result / purpose:
-- Creates an analyst-friendly intervention-type output.
-- Grain is one row per trial-intervention type rather than one row
-- per individual intervention record.
-- DISTINCT prevents multiple drugs of the same type within one trial
-- from unnecessarily duplicating that trial-intervention category.
-- Supports later analysis of DRUG versus BIOLOGICAL activity by
-- year, phase and trial status.

-- Query 4: Curated condition analytical output
-- Grain: one row per trial-condition

WITH trial_core AS (

    SELECT
        s.nct_id,
        s.phase,
        s.overall_status,
        s.start_date

    FROM ctgov.studies AS s

    WHERE s.study_type = 'INTERVENTIONAL'
        AND s.start_date >= DATE '2015-01-01'

        AND EXISTS (
            SELECT 1
            FROM ctgov.sponsors AS sp
            WHERE sp.nct_id = s.nct_id
                AND sp.lead_or_collaborator = 'lead'
                AND sp.agency_class = 'INDUSTRY'
        )

        AND EXISTS (
            SELECT 1
            FROM ctgov.interventions AS i
            WHERE i.nct_id = s.nct_id
                AND i.intervention_type IN ('DRUG', 'BIOLOGICAL')
        )
)

SELECT DISTINCT
    tc.nct_id,
    tc.phase,
    tc.overall_status,
    EXTRACT(YEAR FROM tc.start_date)::INT AS start_year,
    c.name AS condition_name

FROM trial_core AS tc

INNER JOIN ctgov.conditions AS c
    ON tc.nct_id = c.nct_id

ORDER BY
    tc.nct_id,
    c.name;

-- Result / purpose:
-- Creates an analyst-friendly condition-level output.
-- Grain is one row per trial-condition.
-- Repeated nct_id values are expected because a clinical trial
-- can study multiple conditions.
-- DISTINCT prevents duplicate trial-condition combinations.
-- Supports later analysis of trial activity by condition,
-- year, phase and overall status.

-- Query 5: Curated country analytical output
-- Grain: one row per trial-country

WITH trial_core AS (

    SELECT
        s.nct_id,
        s.phase,
        s.overall_status,
        s.start_date

    FROM ctgov.studies AS s

    WHERE s.study_type = 'INTERVENTIONAL'
        AND s.start_date >= DATE '2015-01-01'

        AND EXISTS (
            SELECT 1
            FROM ctgov.sponsors AS sp
            WHERE sp.nct_id = s.nct_id
                AND sp.lead_or_collaborator = 'lead'
                AND sp.agency_class = 'INDUSTRY'
        )

        AND EXISTS (
            SELECT 1
            FROM ctgov.interventions AS i
            WHERE i.nct_id = s.nct_id
                AND i.intervention_type IN ('DRUG', 'BIOLOGICAL')
        )
)

SELECT DISTINCT
    tc.nct_id,
    tc.phase,
    tc.overall_status,
    EXTRACT(YEAR FROM tc.start_date)::INT AS start_year,
    c.name AS country_name,

    CASE
        WHEN c.name = 'United Kingdom' THEN TRUE
        ELSE FALSE
    END AS is_uk

FROM trial_core AS tc

INNER JOIN ctgov.countries AS c
    ON tc.nct_id = c.nct_id

WHERE c.removed = FALSE
   OR c.removed IS NULL

ORDER BY
    tc.nct_id,
    c.name;

-- Result / purpose:
-- Creates an analyst-friendly geography output at one row
-- per trial-country.
-- Repeated nct_id values are expected because multinational
-- trials can operate in multiple countries.
-- Removed country records are excluded.
-- Adds an is_uk flag to simplify later UK participation analysis.
-- Supports country comparisons, geographic footprint analysis
-- and UK-focused portfolio questions.

-- Query 6: Curated site-count and delivery output
-- Grain: one row per clinical trial

WITH trial_core AS (

    SELECT
        s.nct_id,
        s.phase,
        s.overall_status,
        s.start_date,
        s.enrollment

    FROM ctgov.studies AS s

    WHERE s.study_type = 'INTERVENTIONAL'
        AND s.start_date >= DATE '2015-01-01'

        AND EXISTS (
            SELECT 1
            FROM ctgov.sponsors AS sp
            WHERE sp.nct_id = s.nct_id
                AND sp.lead_or_collaborator = 'lead'
                AND sp.agency_class = 'INDUSTRY'
        )

        AND EXISTS (
            SELECT 1
            FROM ctgov.interventions AS i
            WHERE i.nct_id = s.nct_id
                AND i.intervention_type IN ('DRUG', 'BIOLOGICAL')
        )
)

SELECT
    tc.nct_id,
    tc.phase,
    tc.overall_status,
    EXTRACT(YEAR FROM tc.start_date)::INT AS start_year,
    tc.enrollment,

    COUNT(DISTINCT f.id) AS site_count,

    COUNT(DISTINCT f.country)
        FILTER (WHERE f.country IS NOT NULL) AS site_country_count,

    COUNT(f.id)
        FILTER (WHERE f.status IS NULL) AS sites_missing_status

FROM trial_core AS tc

LEFT JOIN ctgov.facilities AS f
    ON tc.nct_id = f.nct_id

GROUP BY
    tc.nct_id,
    tc.phase,
    tc.overall_status,
    tc.start_date,
    tc.enrollment

ORDER BY
    tc.nct_id;

-- Result / purpose:
-- Creates a trial-level site and delivery summary.
-- Grain remains one row per nct_id because facility records
-- are aggregated before analytical use.
-- Calculates total site count, number of countries represented
-- by facility records and missing facility-status records.
-- LEFT JOIN preserves trials with no reported facilities,
-- allowing missing site coverage to remain visible rather than
-- excluding those trials from analysis.
-- Supports later analysis of trial scale, site footprint and delivery.

-- Query 7: Final curated-layer QA
-- Reconcile core trial count and check coverage across curated outputs

WITH trial_core AS (

    SELECT
        s.nct_id

    FROM ctgov.studies AS s

    WHERE s.study_type = 'INTERVENTIONAL'
        AND s.start_date >= DATE '2015-01-01'

        AND EXISTS (
            SELECT 1
            FROM ctgov.sponsors AS sp
            WHERE sp.nct_id = s.nct_id
                AND sp.lead_or_collaborator = 'lead'
                AND sp.agency_class = 'INDUSTRY'
        )

        AND EXISTS (
            SELECT 1
            FROM ctgov.interventions AS i
            WHERE i.nct_id = s.nct_id
                AND i.intervention_type IN ('DRUG', 'BIOLOGICAL')
        )
),

country_summary AS (

    SELECT
        c.nct_id

    FROM ctgov.countries AS c

    WHERE c.removed = FALSE
       OR c.removed IS NULL

    GROUP BY c.nct_id
),

facility_summary AS (

    SELECT
        f.nct_id

    FROM ctgov.facilities AS f

    GROUP BY f.nct_id
),

condition_summary AS (

    SELECT
        c.nct_id

    FROM ctgov.conditions AS c

    GROUP BY c.nct_id
),

intervention_summary AS (

    SELECT
        i.nct_id

    FROM ctgov.interventions AS i

    WHERE i.intervention_type IN ('DRUG', 'BIOLOGICAL')

    GROUP BY i.nct_id
)

SELECT
    COUNT(*) AS trial_core_count,

    COUNT(*) FILTER (
        WHERE cs.nct_id IS NOT NULL
    ) AS trials_with_country,

    COUNT(*) FILTER (
        WHERE fs.nct_id IS NOT NULL
    ) AS trials_with_facility,

    COUNT(*) FILTER (
        WHERE cos.nct_id IS NOT NULL
    ) AS trials_with_condition,

    COUNT(*) FILTER (
        WHERE ins.nct_id IS NOT NULL
    ) AS trials_with_intervention,

    COUNT(*) FILTER (
        WHERE cs.nct_id IS NULL
    ) AS trials_without_country,

    COUNT(*) FILTER (
        WHERE fs.nct_id IS NULL
    ) AS trials_without_facility

FROM trial_core AS tc

LEFT JOIN country_summary AS cs
    ON tc.nct_id = cs.nct_id

LEFT JOIN facility_summary AS fs
    ON tc.nct_id = fs.nct_id

LEFT JOIN condition_summary AS cos
    ON tc.nct_id = cos.nct_id

LEFT JOIN intervention_summary AS ins
    ON tc.nct_id = ins.nct_id;

-- Result / purpose:
-- Final reconciliation check across the curated analytical layer.
-- Confirms trial_core remains the authoritative denominator.
-- Intervention and condition coverage should reconcile fully to the cohort.
-- Country and facility outputs retain known source missingness rather than
-- dropping incomplete trials.
-- These checks define the appropriate denominators for later portfolio analysis.