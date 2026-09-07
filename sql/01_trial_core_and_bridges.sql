-- ============================================================
-- DAY 11: CLINICAL TRIAL CORE AND BRIDGES
-- Project: Clinical Trial Portfolio & Delivery Intelligence
--
-- Locked cohort:
-- Industry-led interventional DRUG/BIOLOGICAL studies
-- with start dates from 2015 onwards.
--
-- Core grain:
-- ONE ROW PER NCT_ID
-- ============================================================


-- Query 1: Build the one-row-per-study trial core
-- Grain: one row per nct_id

SELECT
    s.nct_id,
    s.brief_title,
    s.overall_status,
    s.study_type,
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
    );
    
 -- Result / purpose:
-- Creates the logical trial_core cohort at one row per clinical trial.
-- Uses EXISTS rather than joining child tables directly, which avoids
-- multiplying trial rows when a study has multiple sponsors/interventions.
-- Cohort filters:
--   - INTERVENTIONAL studies
--   - Industry lead sponsor
--   - DRUG or BIOLOGICAL intervention
--   - Start date from 2015 onwards
-- nct_id is the primary analytical key for the trial-level warehouse.
    
-- Query 2: Validate trial_core grain
-- Expected: 46,905 rows, 46,905 unique nct_ids, 0 duplicates

WITH trial_core AS (

    SELECT
        s.nct_id,
        s.brief_title,
        s.overall_status,
        s.study_type,
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
)

SELECT
    COUNT(*) AS row_count,
    COUNT(DISTINCT nct_id) AS unique_trial_count,
    COUNT(*) - COUNT(DISTINCT nct_id) AS duplicate_count

FROM trial_core;

-- row_count          = 46,905
-- unique_trial_count = 46,905
-- duplicate_count    = 0

-- Query 3: Build intervention bridge
-- Grain: one row per trial-intervention record

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
)

SELECT
    i.nct_id,
    i.intervention_type,
    i.name AS intervention_name

FROM ctgov.interventions AS i

INNER JOIN trial_core AS tc
    ON i.nct_id = tc.nct_id

WHERE i.intervention_type IN ('DRUG', 'BIOLOGICAL');

-- Result / purpose:
-- Creates the intervention bridge at one row per trial-intervention record.
-- Repeated nct_id values are expected because one clinical trial can contain
-- multiple qualifying DRUG/BIOLOGICAL interventions.
-- Keeping interventions separate from trial_core prevents child-table rows
-- from multiplying the one-row-per-trial parent table.

-- Query 4: Validate intervention bridge
-- Check row count, trial coverage and foreign-key integrity

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

intervention_bridge AS (

    SELECT
        i.nct_id,
        i.intervention_type,
        i.name AS intervention_name

    FROM ctgov.interventions AS i

    INNER JOIN trial_core AS tc
        ON i.nct_id = tc.nct_id

    WHERE i.intervention_type IN ('DRUG', 'BIOLOGICAL')
)

SELECT
    COUNT(*) AS bridge_row_count,
    COUNT(DISTINCT nct_id) AS unique_trials_represented,

    (
        SELECT COUNT(*)
        FROM trial_core
    ) AS trial_core_count,

    (
        SELECT COUNT(*)
        FROM intervention_bridge AS ib
        LEFT JOIN trial_core AS tc
            ON ib.nct_id = tc.nct_id
        WHERE tc.nct_id IS NULL
    ) AS invalid_foreign_keys,

    (
        SELECT COUNT(*)
        FROM trial_core AS tc
        LEFT JOIN intervention_bridge AS ib
            ON tc.nct_id = ib.nct_id
        WHERE ib.nct_id IS NULL
    ) AS trials_without_intervention

FROM intervention_bridge;

-- Result:
-- Bridge rows: 101,476
-- Unique trials represented: 46,905
-- Trial core count: 46,905
-- Invalid foreign keys: 0
-- Trials without qualifying interventions: 0
--
-- Confirms all trial_core studies are represented in the intervention bridge
-- and every bridge record links back to a valid parent trial.
-- The higher bridge row count is expected because trials can have
-- multiple DRUG/BIOLOGICAL interventions.

-- Query 5: Build condition bridge
-- Grain: one row per trial-condition

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
)

SELECT DISTINCT
    c.nct_id,
    c.name AS condition_name

FROM ctgov.conditions AS c

INNER JOIN trial_core AS tc
    ON c.nct_id = tc.nct_id;

-- Result / purpose:
-- Creates the condition bridge at one row per trial-condition.
-- A clinical trial can study multiple conditions, so repeated nct_id
-- values are expected within this bridge.
-- Conditions remain separate from trial_core to preserve the
-- one-row-per-trial parent grain.

-- Query 6: Validate condition bridge
-- Check row count, trial coverage and foreign-key integrity

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

condition_bridge AS (

    SELECT DISTINCT
        c.nct_id,
        c.name AS condition_name

    FROM ctgov.conditions AS c

    INNER JOIN trial_core AS tc
        ON c.nct_id = tc.nct_id
)

SELECT
    COUNT(*) AS bridge_row_count,
    COUNT(DISTINCT nct_id) AS unique_trials_represented,

    (
        SELECT COUNT(*)
        FROM trial_core
    ) AS trial_core_count,

    (
        SELECT COUNT(*)
        FROM condition_bridge AS cb
        LEFT JOIN trial_core AS tc
            ON cb.nct_id = tc.nct_id
        WHERE tc.nct_id IS NULL
    ) AS invalid_foreign_keys,

    (
        SELECT COUNT(*)
        FROM trial_core AS tc
        LEFT JOIN condition_bridge AS cb
            ON tc.nct_id = cb.nct_id
        WHERE cb.nct_id IS NULL
    ) AS trials_without_condition

FROM condition_bridge;

-- Result:
-- Bridge rows: 71,446
-- Unique trials represented: 46,905
-- Trial core count: 46,905
-- Invalid foreign keys: 0
-- Trials without condition: 0
--
-- Confirms full condition coverage across trial_core.
-- The higher bridge row count is expected because some trials
-- are associated with multiple conditions.

-- Query 7: Build country bridge
-- Grain: one row per trial-country

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
)

SELECT DISTINCT
    c.nct_id,
    c.name AS country_name

FROM ctgov.countries AS c

INNER JOIN trial_core AS tc
    ON c.nct_id = tc.nct_id

WHERE c.removed = FALSE
   OR c.removed IS NULL;

-- Result / purpose:
-- Creates the country bridge at one row per trial-country.
-- Repeated nct_id values are expected because multinational trials
-- can operate across several countries.
-- Removed country records are excluded.
-- Keeping geography separate preserves the one-row-per-trial
-- grain of trial_core and enables later UK participation analysis.

-- Query 8: Validate country bridge
-- Check row count, trial coverage and foreign-key integrity

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

country_bridge AS (

    SELECT DISTINCT
        c.nct_id,
        c.name AS country_name

    FROM ctgov.countries AS c

    INNER JOIN trial_core AS tc
        ON c.nct_id = tc.nct_id

    WHERE c.removed = FALSE
       OR c.removed IS NULL
)

SELECT
    COUNT(*) AS bridge_row_count,
    COUNT(DISTINCT nct_id) AS unique_trials_represented,

    (
        SELECT COUNT(*)
        FROM trial_core
    ) AS trial_core_count,

    (
        SELECT COUNT(*)
        FROM country_bridge AS cb
        LEFT JOIN trial_core AS tc
            ON cb.nct_id = tc.nct_id
        WHERE tc.nct_id IS NULL
    ) AS invalid_foreign_keys,

    (
        SELECT COUNT(*)
        FROM trial_core AS tc
        LEFT JOIN country_bridge AS cb
            ON tc.nct_id = cb.nct_id
        WHERE cb.nct_id IS NULL
    ) AS trials_without_country

FROM country_bridge;

-- Result:
-- Unique trials represented: 44,040
-- Trial core count: 46,905
-- Invalid foreign keys: 0
-- Trials without country: 2,865
--
-- Country relationships are structurally valid, but some trials
-- have no retained country record.
-- Geography-based analyses must therefore account for missing
-- country coverage when defining denominators.


-- Query 9: Build facility bridge
-- Grain: one row per clinical-trial facility/site record

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
)

SELECT
    f.nct_id,
    f.id AS facility_id,
    f.name AS facility_name,
    f.status AS facility_status,
    f.city,
    f.state,
    f.country,
    f.latitude,
    f.longitude

FROM ctgov.facilities AS f

INNER JOIN trial_core AS tc
    ON f.nct_id = tc.nct_id;

-- Result / purpose:
-- Creates the facility bridge at one row per trial-site record.
-- Repeated nct_id values are expected because trials can operate
-- across multiple facilities.
-- Some facility_status values are NULL, reflecting source-field
-- missingness rather than invalid trial-site relationships.
-- facility_id identifies individual AACT facility records.

-- Query 10: Validate facility bridge
-- Check site volume, trial coverage and foreign-key integrity

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

facility_bridge AS (

    SELECT
        f.nct_id,
        f.id AS facility_id,
        f.name AS facility_name,
        f.status AS facility_status,
        f.city,
        f.state,
        f.country,
        f.latitude,
        f.longitude

    FROM ctgov.facilities AS f

    INNER JOIN trial_core AS tc
        ON f.nct_id = tc.nct_id
)

SELECT
    COUNT(*) AS facility_row_count,
    COUNT(DISTINCT facility_id) AS unique_facility_records,
    COUNT(DISTINCT nct_id) AS unique_trials_represented,

    (
        SELECT COUNT(*)
        FROM trial_core
    ) AS trial_core_count,

    (
        SELECT COUNT(*)
        FROM facility_bridge AS fb
        LEFT JOIN trial_core AS tc
            ON fb.nct_id = tc.nct_id
        WHERE tc.nct_id IS NULL
    ) AS invalid_foreign_keys,

    (
        SELECT COUNT(*)
        FROM trial_core AS tc
        LEFT JOIN facility_bridge AS fb
            ON tc.nct_id = fb.nct_id
        WHERE fb.nct_id IS NULL
    ) AS trials_without_facility

FROM facility_bridge;

-- Result:
-- Facility rows: 1,006,909
-- Unique facility records: 1,006,909
-- Unique trials represented: 44,040
-- Trial core count: 46,905
-- Invalid foreign keys: 0
-- Trials without facility: 2,865
--
-- Confirms all facility records link to valid trial_core studies.
-- Site data is highly one-to-many, with over one million facility
-- records across the analytical cohort.
-- 2,865 trials have no facility record and must remain in trial_core
-- rather than being lost through an INNER JOIN in later analysis.

-- Query 11: Build lead sponsor bridge
-- Grain: one row per trial-lead sponsor

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
)

SELECT DISTINCT
    sp.nct_id,
    sp.name AS sponsor_name,
    sp.agency_class AS sponsor_class

FROM ctgov.sponsors AS sp

INNER JOIN trial_core AS tc
    ON sp.nct_id = tc.nct_id

WHERE sp.lead_or_collaborator = 'lead'
    AND sp.agency_class = 'INDUSTRY';

-- Result / purpose:
-- Creates the lead sponsor bridge for the locked analytical cohort.
-- Only INDUSTRY lead sponsors are retained because this is part
-- of the project cohort definition.
-- Sponsor data is kept separate from trial_core to preserve
-- one-row-per-trial grain and support sponsor-level analysis.

-- Query 12: Validate lead sponsor bridge
-- Check trial coverage, foreign-key integrity and sponsor multiplicity

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

sponsor_bridge AS (

    SELECT DISTINCT
        sp.nct_id,
        sp.name AS sponsor_name,
        sp.agency_class AS sponsor_class

    FROM ctgov.sponsors AS sp

    INNER JOIN trial_core AS tc
        ON sp.nct_id = tc.nct_id

    WHERE sp.lead_or_collaborator = 'lead'
        AND sp.agency_class = 'INDUSTRY'
)

SELECT
    COUNT(*) AS sponsor_row_count,
    COUNT(DISTINCT nct_id) AS unique_trials_represented,

    (
        SELECT COUNT(*)
        FROM trial_core
    ) AS trial_core_count,

    (
        SELECT COUNT(*)
        FROM sponsor_bridge AS sb
        LEFT JOIN trial_core AS tc
            ON sb.nct_id = tc.nct_id
        WHERE tc.nct_id IS NULL
    ) AS invalid_foreign_keys,

    (
        SELECT COUNT(*)
        FROM trial_core AS tc
        LEFT JOIN sponsor_bridge AS sb
            ON tc.nct_id = sb.nct_id
        WHERE sb.nct_id IS NULL
    ) AS trials_without_sponsor,

    (
        SELECT COUNT(*)
        FROM (
            SELECT
                nct_id
            FROM sponsor_bridge
            GROUP BY nct_id
            HAVING COUNT(*) > 1
        ) AS multiple_sponsors
    ) AS trials_with_multiple_lead_sponsors

FROM sponsor_bridge;

-- Result:
-- Lead sponsor coverage reconciles to trial_core.
-- Invalid foreign keys: 0
-- Trials without qualifying INDUSTRY lead sponsor: 0
--
-- Confirms sponsor relationships are complete for the locked cohort.
-- Sponsor analysis can therefore be performed without changing the
-- one-row-per-trial grain of trial_core.