-- Clinical-trials stakeholder research: 12 original queries.
-- Numerical comments record the earlier SQL run, not the final PBIX refresh.
-- See docs/research.md for scope differences and current dashboard findings.
-- No query calculations or cohort filters were changed during packaging.
/*
PROJECT: Clinical Trial Portfolio & Delivery Intelligence

STAKEHOLDER:
UK-focused pharmaceutical / biotechnology portfolio strategy
and clinical operations teams.

OVERALL BUSINESS QUESTION:
How has the industry-sponsored drug and biological clinical-trial
landscape changed since 2015, and what does this imply for portfolio
planning, operational capacity, geographic strategy, delivery risk
and reporting governance?


1. PORTFOLIO LANDSCAPE

Business question:
How is industry clinical-development activity changing, and what
parts of the portfolio are driving those changes?

Query 1 - Annual trial activity trend
Query 2 - Phase mix and drivers of the 2021 activity increase
Query 3 - Sponsor concentration / competitive landscape


2. OPERATIONAL CAPACITY

Business question:
How much do recruitment requirements, site networks and delivery
timelines increase as programmes progress through development?

Query 4 - Enrollment burden by phase
Query 5 - Site and geographic footprint by phase
Query 6 - Completed-trial duration by phase


3. GEOGRAPHIC STRATEGY

Business question:
Is the UK gaining or losing relative importance, and which global
markets should be considered when reviewing future trial strategy?

Query 7 - UK participation trend
Query 8 - Country participation shifts and diversification opportunities


4. PORTFOLIO AND DELIVERY RISK

Business question:
Which development stages show the greatest historical discontinuation,
and what factors appear to contribute to those outcomes?

Query 9  - Discontinuation risk by phase
Query 10 - Raw reported stop reasons
Query 11 - Categorised discontinuation reasons / hypothesis test


5. REPORTING GOVERNANCE

Business question:
Where are the largest gaps in publicly posted clinical-trial results?

Query 12 - Results-posting coverage by phase


ANALYTICAL PRINCIPLES:

- Preserve the correct analytical grain.
- Use appropriate denominators and report missingness.
- Prefer medians and percentiles where distributions are skewed.
- Separate observed relationships from causal interpretation.
- Follow important findings with targeted drill-down analysis.
- Translate findings into practical business decisions without
  overstating what registry data can prove.
*/


-- Query 1: Clinical-Trial activity trend by start year
-- Business question:
-- How has industry-sponsored drug/biological trial activity changed since 2015?

WITH trial_core AS (

    SELECT
        s.nct_id,
        s.start_date

    FROM ctgov.studies AS s

    WHERE s.study_type = 'INTERVENTIONAL'
        AND s.start_date >= DATE '2015-01-01'
        AND s.start_date <= CURRENT_DATE

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

annual_activity AS (

    SELECT
        EXTRACT(YEAR FROM start_date)::INT AS start_year,
        COUNT(*) AS trial_starts

    FROM trial_core

    GROUP BY
        EXTRACT(YEAR FROM start_date)::INT
)

SELECT
    start_year,
    trial_starts,

    LAG(trial_starts) OVER (
        ORDER BY start_year
    ) AS previous_year_trials,

    trial_starts
        - LAG(trial_starts) OVER (
            ORDER BY start_year
        ) AS annual_change,

    ROUND(
        100.0 *
        (
            trial_starts
            - LAG(trial_starts) OVER (
                ORDER BY start_year
            )
        )
        /
        NULLIF(
            LAG(trial_starts) OVER (
                ORDER BY start_year
            ),
            0
        ),
        1
    ) AS annual_change_pct

FROM annual_activity

ORDER BY start_year;

-- Result / purpose:
-- Measures annual trial-start activity for the locked clinical-trials cohort.
-- LAG compares each year's trial count with the previous year and calculates
-- both absolute and percentage year-on-year change.
-- Future planned start dates are excluded from the historical trend.
-- The current year is incomplete and should not be directly compared with
-- complete prior calendar years without that limitation being stated.

-- Analytical finding:
-- Trial-start activity was relatively stable but cyclical across the period.
-- Starts declined from 2015-2017, recovered through 2020 and then rose
-- sharply to a series high of 4,753 trials in 2021 (+22.2% YoY).
-- Activity subsequently declined through 2024 before recovering to
-- 4,287 starts in 2025 (+5.8% YoY).
--
-- 2021 represents a clear departure from the surrounding trend and warrants
-- further analysis to determine which phases or portfolio segments drove
-- the increase.
--
-- 2026 is an incomplete calendar year and its -30.2% apparent YoY change
-- must not be interpreted as a full-year decline.

-- Query 2: Trial activity and portfolio mix by phase
-- Business question:
-- Which development phases drove changes in industry trial activity,
-- particularly the 2021 increase?

WITH trial_core AS (

    SELECT
        s.nct_id,
        s.phase,
        EXTRACT(YEAR FROM s.start_date)::INT AS start_year

    FROM ctgov.studies AS s

    WHERE s.study_type = 'INTERVENTIONAL'
        AND s.start_date >= DATE '2015-01-01'
        AND s.start_date < DATE '2026-01-01'

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

phase_activity AS (

    SELECT
        start_year,
        COALESCE(phase, 'NOT_REPORTED') AS phase,
        COUNT(*) AS trial_starts

    FROM trial_core

    GROUP BY
        start_year,
        COALESCE(phase, 'NOT_REPORTED')
),

phase_metrics AS (

    SELECT
        start_year,
        phase,
        trial_starts,

        SUM(trial_starts) OVER (
            PARTITION BY start_year
        ) AS total_year_trials,

        LAG(trial_starts) OVER (
            PARTITION BY phase
            ORDER BY start_year
        ) AS previous_year_phase_trials

    FROM phase_activity
)

SELECT
    start_year,
    phase,
    trial_starts,

    ROUND(
        100.0 * trial_starts
        / NULLIF(total_year_trials, 0),
        1
    ) AS phase_share_pct,

    trial_starts
        - previous_year_phase_trials
        AS annual_phase_change,

    ROUND(
        100.0 *
        (trial_starts - previous_year_phase_trials)
        / NULLIF(previous_year_phase_trials, 0),
        1
    ) AS annual_phase_change_pct

FROM phase_metrics

ORDER BY
    start_year,
    trial_starts DESC;

-- Result / purpose:
-- Measures annual trial activity by development phase and separates
-- changes in absolute trial volume from changes in portfolio composition.
-- Phase share shows the proportion of each year's trial starts represented
-- by each development stage, while LAG identifies which phases drove
-- year-on-year increases or declines.
-- Only complete calendar years (2015-2025) are used so the incomplete
-- 2026 reporting year does not distort comparisons.
-- This directly investigates whether the unusual 2021 activity increase
-- was concentrated within particular phases.

-- Analytical finding:
-- The 2021 increase in trial activity was broad-based rather than
-- being driven by a single development phase.
--
-- Of the 864 additional trial starts versus 2020:
--   Phase 1 increased by 270 (+17.8%)
--   Phase 2 increased by 239 (+26.6%)
--   Phase 3 increased by 166 (+21.9%)
-- Together, these three phases accounted for approximately 78%
-- of the total year-on-year increase.
--
-- The longer-term phase mix also suggests some movement toward
-- earlier-stage development. Phase 1 represented 35.0% of starts
-- in 2015 versus 37.3% in 2025, reaching 40.7% in 2024, while
-- Phase 3 declined from 24.4% in 2015 to 20.6% in 2025.
-- Combined Phase 1/Phase 2 trials increased from 6.4% to 10.8%.
--
-- The subsequent 2022 decline was also broad-based, particularly
-- across Phase 2, Phase 1, Phase 4 and Phase 3.
-- These results describe portfolio composition and do not establish
-- the external causes of changes in trial activity.

-- Query 3: Sponsor activity and market concentration
-- Business question:
-- Which industry sponsors account for the largest share of trial activity,
-- and how concentrated is activity among the leading sponsors?

WITH trial_core AS (

    SELECT
        s.nct_id

    FROM ctgov.studies AS s

    WHERE s.study_type = 'INTERVENTIONAL'
        AND s.start_date >= DATE '2015-01-01'
        AND s.start_date < DATE '2026-01-01'

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

sponsor_trials AS (

    SELECT DISTINCT
        tc.nct_id,
        sp.name AS sponsor_name

    FROM trial_core AS tc

    INNER JOIN ctgov.sponsors AS sp
        ON tc.nct_id = sp.nct_id

    WHERE sp.lead_or_collaborator = 'lead'
        AND sp.agency_class = 'INDUSTRY'
),

sponsor_activity AS (

    SELECT
        sponsor_name,
        COUNT(DISTINCT nct_id) AS trial_count

    FROM sponsor_trials

    GROUP BY sponsor_name
),

ranked_sponsors AS (

    SELECT
        sponsor_name,
        trial_count,

        RANK() OVER (
            ORDER BY trial_count DESC
        ) AS sponsor_rank,

        SUM(trial_count) OVER (
            ORDER BY trial_count DESC, sponsor_name
            ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
        ) AS cumulative_trials

    FROM sponsor_activity
),

portfolio_total AS (

    SELECT
        COUNT(DISTINCT nct_id) AS total_trials

    FROM trial_core
)

SELECT
    rs.sponsor_rank,
    rs.sponsor_name,
    rs.trial_count,

    ROUND(
        100.0 * rs.trial_count
        / NULLIF(pt.total_trials, 0),
        2
    ) AS portfolio_share_pct,

    ROUND(
        100.0 * rs.cumulative_trials
        / NULLIF(pt.total_trials, 0),
        2
    ) AS cumulative_share_pct

FROM ranked_sponsors AS rs

CROSS JOIN portfolio_total AS pt

ORDER BY
    rs.sponsor_rank,
    rs.sponsor_name

LIMIT 20;

-- Result / purpose:
-- Ranks industry lead sponsors by the number of qualifying trials started
-- during complete calendar years 2015-2025.
-- Portfolio share measures each sponsor's contribution to total trial activity,
-- while cumulative share shows how concentrated activity is among the
-- largest sponsors.
-- Supports competitive-intelligence and portfolio-benchmarking decisions.
--
-- Sponsor names are taken directly from the registry and may contain naming
-- variations between related corporate entities, so company-level
-- concentration should be interpreted with that limitation.

-- Analytical finding:
-- Industry-sponsored drug/biological trial activity is highly fragmented
-- across lead sponsors rather than being dominated by a small group.
--
-- AstraZeneca ranked first with 889 qualifying trials (2.06% of activity),
-- closely followed by Pfizer with 888 (2.05%).
--
-- The top 5 sponsors accounted for only 9.58% of trial activity,
-- the top 10 for 16.20%, and even the top 20 for just 24.90%.
--
-- This suggests that the competitive clinical-development landscape extends
-- well beyond the largest multinational pharmaceutical companies and that
-- benchmarking only against the largest sponsors would omit most activity.
--
-- Sponsor names are registry-reported and may separate subsidiaries,
-- legacy company names or related corporate entities. Therefore these figures
-- describe concentration by registered sponsor name rather than consolidated
-- corporate-group market share.

-- Query 4: Recruitment burden by development phase
-- Business question:
-- Which development phases require the greatest participant recruitment,
-- and where should trial operations expect the highest recruitment burden?

WITH trial_core AS (

    SELECT
        s.nct_id,
        COALESCE(s.phase, 'NOT_REPORTED') AS phase,
        s.enrollment

    FROM ctgov.studies AS s

    WHERE s.study_type = 'INTERVENTIONAL'
        AND s.start_date >= DATE '2015-01-01'
        AND s.start_date < DATE '2026-01-01'

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
    phase,

    COUNT(*) AS total_trials,

    COUNT(enrollment) AS trials_with_enrollment,

    ROUND(
        100.0 * COUNT(enrollment) / COUNT(*),
        1
    ) AS enrollment_coverage_pct,

    ROUND(
        PERCENTILE_CONT(0.50)
        WITHIN GROUP (ORDER BY enrollment)
        FILTER (WHERE enrollment IS NOT NULL)::NUMERIC,
        0
    ) AS median_enrollment,

    ROUND(
        PERCENTILE_CONT(0.75)
        WITHIN GROUP (ORDER BY enrollment)
        FILTER (WHERE enrollment IS NOT NULL)::NUMERIC,
        0
    ) AS p75_enrollment,

    MAX(enrollment) AS maximum_enrollment

FROM trial_core

GROUP BY phase

ORDER BY median_enrollment DESC NULLS LAST;

-- Result / purpose:
-- Compares participant-recruitment requirements across development phases
-- using median and upper-quartile enrollment rather than relying on means
-- that may be distorted by very large trials.
--
-- Enrollment coverage is reported alongside the metrics so conclusions
-- can be interpreted in the context of registry missingness.
--
-- Business use:
-- Helps clinical operations and portfolio teams identify development stages
-- associated with greater recruitment requirements and anticipate where
-- additional recruitment capacity and operational planning may be required.
--
-- Registry enrollment values are self-reported and should be interpreted
-- as indicators of trial scale rather than direct measures of cost or
-- operational difficulty.

-- Analytical finding:
-- Recruitment requirements increase substantially as trials progress
-- into later development stages.
--
-- Median enrollment increased from 35 participants in Phase 1 to
-- 77 in Phase 2 and 308 in Phase 3. A typical Phase 3 trial therefore
-- enrolled approximately 8.8 times as many participants as a typical
-- Phase 1 trial.
--
-- The same pattern was present at the upper quartile:
-- Phase 1 P75 enrollment was 64 participants versus 580 in Phase 3,
-- a difference of approximately 9.1 times.
--
-- Enrollment coverage was effectively complete across all phases,
-- strengthening confidence in the comparison.
--
-- Business implication:
-- Portfolio progression into Phase 3 creates a substantial increase
-- in recruitment requirements. Clinical-operations planning should
-- therefore anticipate greater recruitment capacity, site-network and
-- delivery-resource requirements as programmes enter late-stage development.
--
-- Extreme enrollment values demonstrate why median and percentile
-- measures are more representative than the arithmetic mean.
-- Enrollment measures trial scale but does not directly measure cost
-- or operational difficulty.

-- Query 5: Site and geographic footprint by development phase
-- Business question:
-- How much larger do trial delivery networks become in later-stage
-- development, and where should Clinical Operations expect the
-- greatest site and geographic coordination requirements?

WITH trial_core AS (

    SELECT
        s.nct_id,
        COALESCE(s.phase, 'NOT_REPORTED') AS phase

    FROM ctgov.studies AS s

    WHERE s.study_type = 'INTERVENTIONAL'
        AND s.start_date >= DATE '2015-01-01'
        AND s.start_date < DATE '2026-01-01'

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

facility_summary AS (

    SELECT
        f.nct_id,
        COUNT(DISTINCT f.id) AS site_count,
        COUNT(DISTINCT f.country)
            FILTER (WHERE f.country IS NOT NULL) AS site_country_count

    FROM ctgov.facilities AS f

    GROUP BY f.nct_id
),

trial_footprint AS (

    SELECT
        tc.nct_id,
        tc.phase,
        fs.site_count,
        fs.site_country_count

    FROM trial_core AS tc

    LEFT JOIN facility_summary AS fs
        ON tc.nct_id = fs.nct_id
)

SELECT
    phase,

    COUNT(*) AS total_trials,

    COUNT(site_count) AS trials_with_site_data,

    ROUND(
        100.0 * COUNT(site_count)
        / NULLIF(COUNT(*), 0),
        1
    ) AS site_data_coverage_pct,

    ROUND(
        PERCENTILE_CONT(0.50)
        WITHIN GROUP (ORDER BY site_count)
        FILTER (WHERE site_count IS NOT NULL)::NUMERIC,
        0
    ) AS median_site_count,

    ROUND(
        PERCENTILE_CONT(0.75)
        WITHIN GROUP (ORDER BY site_count)
        FILTER (WHERE site_count IS NOT NULL)::NUMERIC,
        0
    ) AS p75_site_count,

    ROUND(
        PERCENTILE_CONT(0.50)
        WITHIN GROUP (ORDER BY site_country_count)
        FILTER (WHERE site_country_count IS NOT NULL)::NUMERIC,
        0
    ) AS median_country_count,

    ROUND(
        PERCENTILE_CONT(0.75)
        WITHIN GROUP (ORDER BY site_country_count)
        FILTER (WHERE site_country_count IS NOT NULL)::NUMERIC,
        0
    ) AS p75_country_count

FROM trial_footprint

GROUP BY phase

ORDER BY median_site_count DESC NULLS LAST;

-- Result / purpose:
-- Compares the operational footprint of trials across development phases
-- using typical and upper-quartile site and country counts.
--
-- Facility coverage is reported explicitly and trials without reported
-- facility data are retained as NULL rather than incorrectly treated
-- as trials with zero sites.
--
-- Business use:
-- Tests whether the substantially greater participant requirements found
-- in later-stage trials are accompanied by larger site networks and broader
-- geographic delivery footprints.
-- This can help Clinical Operations anticipate where additional site
-- management, country coordination and delivery capacity may be required.
--
-- Site and country counts describe registered trial footprint and should
-- not be interpreted as direct measures of cost or operational performance.

-- Analytical finding:
-- Trial delivery footprint increases substantially with development stage.
--
-- Median site count increased from 1 site in Phase 1 to 10 sites
-- in Phase 2 and 30 sites in Phase 3.
--
-- At the upper quartile, Phase 3 trials operated across 87 sites
-- and 12 countries, compared with 3 sites and 1 country for Phase 1.
--
-- Combined with Query 4, this shows that Phase 3 trials typically
-- require approximately 8.8x the participant enrollment of Phase 1
-- trials while also operating across substantially larger site networks.
--
-- Site-data coverage was approximately 95% across the major phases,
-- providing strong coverage for the comparison.
--
-- Business implication:
-- Clinical Operations should not plan delivery capacity using trial
-- counts alone. Programmes progressing into Phase 3 should trigger
-- materially greater site-management, country-coordination and
-- recruitment-capacity planning.
--
-- Phase and expected site footprint could therefore be used as
-- practical inputs when forecasting operational resource requirements.
--
-- Registry site counts describe reported trial footprint and do not
-- directly measure workload, cost or operational performance.

-- Query 6: Completed-trial duration by development phase
-- Business question:
-- Which development phases typically require the longest delivery timelines,
-- and where should portfolio planning allow greater schedule capacity?

WITH completed_trials AS (

    SELECT
        s.nct_id,
        COALESCE(s.phase, 'NOT_REPORTED') AS phase,
        s.start_date,
        s.completion_date,

        (s.completion_date - s.start_date) AS duration_days

    FROM ctgov.studies AS s

    WHERE s.study_type = 'INTERVENTIONAL'
        AND s.start_date >= DATE '2015-01-01'
        AND s.start_date < DATE '2026-01-01'
        AND s.overall_status = 'COMPLETED'

        AND s.start_date IS NOT NULL
        AND s.completion_date IS NOT NULL
        AND s.completion_date >= s.start_date

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
    phase,

    COUNT(*) AS completed_trials,

    ROUND(
        PERCENTILE_CONT(0.50)
        WITHIN GROUP (ORDER BY duration_days)::NUMERIC
        / 30.44,
        1
    ) AS median_duration_months,

    ROUND(
        PERCENTILE_CONT(0.75)
        WITHIN GROUP (ORDER BY duration_days)::NUMERIC
        / 30.44,
        1
    ) AS p75_duration_months,

    ROUND(
        PERCENTILE_CONT(0.90)
        WITHIN GROUP (ORDER BY duration_days)::NUMERIC
        / 30.44,
        1
    ) AS p90_duration_months

FROM completed_trials

GROUP BY phase

ORDER BY median_duration_months DESC NULLS LAST;

-- Result / purpose:
-- Compares observed start-to-completion timelines across development phases
-- using completed trials with valid start and completion dates.
--
-- Median duration represents a typical completed trial, while the 75th
-- and 90th percentiles show the longer-duration portion of each phase.
--
-- Business use:
-- Helps portfolio and clinical-operations teams identify development stages
-- associated with longer delivery timelines and build phase-specific schedule
-- assumptions and contingency buffers into programme planning.
--
-- Only completed trials are included, so these results describe observed
-- completion durations rather than planned timelines.
-- Recent cohorts may be biased toward faster-completing studies because
-- longer-running trials may still be ongoing; results are descriptive and
-- should not be interpreted as causal estimates of phase-driven delay.

-- Analytical finding:
-- Completed-trial duration varies substantially by development phase,
-- but does not increase in a simple linear relationship with trial scale.
--
-- Median duration increased from 7.1 months in Phase 1 to 19.4 months
-- in Phase 2 and 22.6 months in Phase 3. A typical completed Phase 3
-- trial therefore lasted approximately 3.2 times as long as Phase 1.
--
-- However, combined Phase 1/Phase 2 studies had the longest median
-- duration at 29.2 months, with a P90 duration of 68.3 months.
-- This indicates that development stage and operational scale alone
-- do not fully explain trial duration.
--
-- Business implication:
-- Portfolio planning should use phase-specific historical duration
-- distributions rather than applying one generic schedule assumption
-- or assuming later-stage programmes are always longest.
-- P75/P90 durations can provide additional contingency benchmarks
-- for programmes where schedule risk needs to be managed conservatively.
--
-- Duration is measured only for completed trials with valid dates.
-- Recent cohorts may be biased toward faster-completing studies because
-- longer-running trials can remain ongoing, and duration should not be
-- interpreted as a direct measure of operational performance or delay.

-- Query 7: UK participation trend and global portfolio share
-- Business question:
-- Is the UK gaining or losing relative importance within global
-- industry-sponsored drug/biological trials, and does this warrant
-- a review of geographic trial-delivery strategy?

WITH trial_core AS (

    SELECT
        s.nct_id,
        EXTRACT(YEAR FROM s.start_date)::INT AS start_year

    FROM ctgov.studies AS s

    WHERE s.study_type = 'INTERVENTIONAL'
        AND s.start_date >= DATE '2015-01-01'
        AND s.start_date < DATE '2026-01-01'

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

country_flags AS (

    SELECT
        c.nct_id,

        BOOL_OR(
            c.name = 'United Kingdom'
        ) AS uk_participation

    FROM ctgov.countries AS c

    WHERE c.removed = FALSE
       OR c.removed IS NULL

    GROUP BY c.nct_id
),

annual_geography AS (

    SELECT
        tc.start_year,

        COUNT(*) AS total_trials,

        COUNT(cf.nct_id) AS trials_with_country_data,

        COUNT(*) FILTER (
            WHERE cf.uk_participation = TRUE
        ) AS uk_trials

    FROM trial_core AS tc

    LEFT JOIN country_flags AS cf
        ON tc.nct_id = cf.nct_id

    GROUP BY tc.start_year
),

annual_metrics AS (

    SELECT
        start_year,
        total_trials,
        trials_with_country_data,
        uk_trials,

        ROUND(
            100.0 * trials_with_country_data
            / NULLIF(total_trials, 0),
            1
        ) AS country_data_coverage_pct,

        ROUND(
            100.0 * uk_trials
            / NULLIF(total_trials, 0),
            1
        ) AS uk_share_all_trials_pct,

        ROUND(
            100.0 * uk_trials
            / NULLIF(trials_with_country_data, 0),
            1
        ) AS uk_share_geo_known_pct

    FROM annual_geography
)

SELECT
    start_year,
    total_trials,
    trials_with_country_data,
    country_data_coverage_pct,
    uk_trials,
    uk_share_all_trials_pct,
    uk_share_geo_known_pct,

    LAG(uk_share_geo_known_pct) OVER (
        ORDER BY start_year
    ) AS previous_year_uk_share_pct,

    ROUND(
        uk_share_geo_known_pct
        - LAG(uk_share_geo_known_pct) OVER (
            ORDER BY start_year
        ),
        1
    ) AS uk_share_change_pp

FROM annual_metrics

ORDER BY start_year;

-- Result / purpose:
-- Measures UK participation within the global qualifying clinical-trial
-- portfolio across complete calendar years 2015-2025.
--
-- UK trial volume is assessed alongside its share of trials with known
-- geography so changes in global activity do not obscure changes in the
-- UK's relative position.
--
-- Country-data coverage is reported explicitly because trials with missing
-- geography cannot reliably be classified as UK or non-UK.
--
-- Year-on-year percentage-point change identifies whether the UK's
-- relative participation is strengthening or weakening over time.
--
-- Business use:
-- Provides evidence for reviewing UK site strategy and geographic
-- diversification. A sustained decline in UK share could justify deeper
-- benchmarking of alternative trial markets, while stable or increasing
-- participation could support continued UK capability investment.
--
-- Registry participation does not measure recruitment performance,
-- regulatory attractiveness, cost or commercial value, so geographic
-- investment decisions require additional operational evidence.

-- Analytical finding:
-- The UK's relative participation in industry-sponsored drug/biological
-- trials has declined materially over the analysis period.
--
-- Among trials with known geography, UK participation fell from 17.6%
-- in 2015 to 12.9% in 2025, a decline of 4.7 percentage points
-- (approximately 27% relative to the 2015 share).
--
-- The decline is larger from the 2017 peak of 18.6%, falling to 12.9%
-- by 2025 (-5.7 percentage points).
--
-- Over the same period, total qualifying trial starts increased from
-- 3,605 in 2015 to 4,287 in 2025, while UK-participating trials fell
-- from 579 to 514. This indicates that the UK has lost relative
-- participation despite growth in the wider portfolio.
--
-- Geographic coverage remained above 90% in every year, and the primary
-- share metric uses only trials with known geography to reduce bias from
-- missing country information.
--
-- Business implication:
-- Organisations with significant dependence on UK trial delivery should
-- review geographic concentration and benchmark alternative or complementary
-- trial markets. The observed decline supports evaluating diversification,
-- rather than assuming historic UK participation levels will persist.
--
-- The registry does not measure country-level recruitment performance,
-- regulatory attractiveness, cost or trial quality, so this finding alone
-- does not justify reducing UK investment.

-- Query 8: Country participation shifts and diversification opportunities
-- Business question:
-- Which major trial markets have gained or lost participation since 2015,
-- and which countries should be benchmarked when reviewing UK geographic strategy?

WITH trial_core AS (

    SELECT
        s.nct_id,
        EXTRACT(YEAR FROM s.start_date)::INT AS start_year

    FROM ctgov.studies AS s

    WHERE s.study_type = 'INTERVENTIONAL'
        AND s.start_date >= DATE '2015-01-01'
        AND s.start_date < DATE '2026-01-01'

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

country_participation AS (

    SELECT DISTINCT
        tc.nct_id,
        tc.start_year,
        c.name AS country_name

    FROM trial_core AS tc

    INNER JOIN ctgov.countries AS c
        ON tc.nct_id = c.nct_id

    WHERE (c.removed = FALSE OR c.removed IS NULL)
        AND tc.start_year IN (2015, 2025)
),

year_denominators AS (

    SELECT
        start_year,
        COUNT(DISTINCT nct_id) AS trials_with_country_data

    FROM country_participation

    GROUP BY start_year
),

denominator_summary AS (

    SELECT
        MAX(trials_with_country_data)
            FILTER (WHERE start_year = 2015) AS trials_2015_geo_known,

        MAX(trials_with_country_data)
            FILTER (WHERE start_year = 2025) AS trials_2025_geo_known

    FROM year_denominators
),

country_activity AS (

    SELECT
        country_name,

        COUNT(DISTINCT nct_id)
            FILTER (WHERE start_year = 2015) AS trials_2015,

        COUNT(DISTINCT nct_id)
            FILTER (WHERE start_year = 2025) AS trials_2025

    FROM country_participation

    GROUP BY country_name
),

country_metrics AS (

    SELECT
        ca.country_name,
        ca.trials_2015,
        ca.trials_2025,

        ROUND(
            100.0 * ca.trials_2015
            / NULLIF(ds.trials_2015_geo_known, 0),
            1
        ) AS share_2015_pct,

        ROUND(
            100.0 * ca.trials_2025
            / NULLIF(ds.trials_2025_geo_known, 0),
            1
        ) AS share_2025_pct

    FROM country_activity AS ca

    CROSS JOIN denominator_summary AS ds
)

SELECT
    country_name,
    trials_2015,
    trials_2025,

    trials_2025 - trials_2015
        AS trial_count_change,

    share_2015_pct,
    share_2025_pct,

    ROUND(
        share_2025_pct - share_2015_pct,
        1
    ) AS share_change_pp,

    RANK() OVER (
        ORDER BY trials_2025 DESC
    ) AS trial_volume_rank_2025

FROM country_metrics

WHERE trials_2015 >= 100
   OR trials_2025 >= 100

ORDER BY
    share_change_pp DESC,
    trials_2025 DESC;

-- Result / purpose:
-- Compares participation in major clinical-trial countries between
-- 2015 and 2025 using both absolute trial volume and each country's
-- share of trials with known geography.
--
-- The analysis focuses on countries with at least 100 qualifying trials
-- in either comparison year to avoid over-interpreting large percentage
-- changes in very small markets.
--
-- Business use:
-- Identifies major trial markets gaining relative participation and
-- provides a shortlist of countries that could be benchmarked when
-- reviewing UK site strategy and geographic diversification.
--
-- Country participation is not mutually exclusive because multinational
-- trials can operate in several countries simultaneously. These figures
-- therefore represent participation rates, not commercial market share.
--
-- Growth in registry participation alone does not establish that a country
-- is a superior trial location. Cost, recruitment performance, regulation,
-- therapeutic-area capability and operational quality would require
-- additional evidence before investment decisions are made.

-- Analytical finding:
-- The geographic distribution of industry-sponsored drug/biological
-- trials shifted materially between 2015 and 2025.
--
-- China showed the largest increase, rising from 229 qualifying trials
-- in 2015 to 1,559 in 2025. Its participation rate increased from
-- 7.0% to 39.0% of trials with known geography (+32.0 percentage points).
--
-- Other growing markets included Australia (+3.8pp), Brazil (+2.3pp),
-- Argentina (+2.3pp), India (+1.7pp) and Japan (+1.2pp).
--
-- In contrast, several established Western markets lost relative
-- participation, including the United States (-13.2pp), Germany (-5.7pp),
-- the United Kingdom (-4.7pp), Belgium (-4.4pp) and France (-3.3pp).
--
-- The United States remained the largest individual trial market by
-- absolute 2025 volume despite its lower relative participation share.
--
-- Business implication:
-- Companies relying heavily on traditional UK/Western European trial
-- networks should review whether their geographic strategy reflects the
-- changing global distribution of clinical-development activity.
-- Growing markets, particularly China and Australia, warrant deeper
-- feasibility benchmarking when considering future multinational programmes.
--
-- Country participation rates are not mutually exclusive because a single
-- multinational trial can operate in several countries.
-- Registry growth alone does not establish that a country is a superior
-- trial location; recruitment, cost, regulation, therapeutic capability
-- and operational quality require additional evidence.

-- Query 9: Trial discontinuation risk by development phase
-- Business question:
-- Which development phases show the highest historical rate of
-- terminated or withdrawn trials, and where should portfolio teams
-- prioritise delivery-risk monitoring?

WITH trial_core AS (

    SELECT
        s.nct_id,
        COALESCE(s.phase, 'NOT_REPORTED') AS phase,
        s.overall_status

    FROM ctgov.studies AS s

    WHERE s.study_type = 'INTERVENTIONAL'
        AND s.start_date >= DATE '2015-01-01'
        AND s.start_date < DATE '2026-01-01'

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

phase_outcomes AS (

    SELECT
        phase,

        COUNT(*) AS total_trials,

        COUNT(*) FILTER (
            WHERE overall_status IN (
                'COMPLETED',
                'TERMINATED',
                'WITHDRAWN'
            )
        ) AS resolved_trials,

        COUNT(*) FILTER (
            WHERE overall_status = 'COMPLETED'
        ) AS completed_trials,

        COUNT(*) FILTER (
            WHERE overall_status = 'TERMINATED'
        ) AS terminated_trials,

        COUNT(*) FILTER (
            WHERE overall_status = 'WITHDRAWN'
        ) AS withdrawn_trials,

        COUNT(*) FILTER (
            WHERE overall_status = 'SUSPENDED'
        ) AS suspended_trials

    FROM trial_core

    GROUP BY phase
),

phase_metrics AS (

    SELECT
        phase,
        total_trials,
        resolved_trials,
        completed_trials,
        terminated_trials,
        withdrawn_trials,

        terminated_trials + withdrawn_trials
            AS discontinued_trials,

        suspended_trials,

        ROUND(
            100.0 * resolved_trials
            / NULLIF(total_trials, 0),
            1
        ) AS resolved_share_pct,

        ROUND(
            100.0 * completed_trials
            / NULLIF(resolved_trials, 0),
            1
        ) AS completion_rate_pct,

        ROUND(
            100.0 * (terminated_trials + withdrawn_trials)
            / NULLIF(resolved_trials, 0),
            1
        ) AS discontinuation_rate_pct

    FROM phase_outcomes
)

SELECT
    phase,
    total_trials,
    resolved_trials,
    resolved_share_pct,
    completed_trials,
    terminated_trials,
    withdrawn_trials,
    discontinued_trials,
    suspended_trials,
    completion_rate_pct,
    discontinuation_rate_pct

FROM phase_metrics

WHERE resolved_trials >= 100

ORDER BY
    discontinuation_rate_pct DESC,
    resolved_trials DESC;

-- Result / purpose:
-- Compares historical trial outcomes across development phases and
-- identifies where terminated or withdrawn trials represent the
-- greatest share of resolved outcomes.
--
-- Only COMPLETED, TERMINATED and WITHDRAWN trials are included in the
-- final-outcome denominator so currently active trials are not incorrectly
-- treated as successful or unsuccessful.
--
-- SUSPENDED trials are reported separately because suspension represents
-- an unresolved risk state rather than a final outcome.
--
-- Business use:
-- Helps portfolio and clinical-operations teams identify development
-- stages where stronger risk monitoring, milestone review or contingency
-- planning may be warranted.
--
-- Outcome rates are descriptive rather than causal. Reasons for
-- discontinuation are not established by this query, and newer cohorts
-- have had less time to reach a final outcome.

-- Analytical finding:
-- Historical discontinuation rates vary materially across development phases.
--
-- Combined-phase trials showed the highest discontinuation rates among
-- resolved studies. Phase 1/Phase 2 trials had a 38.3% discontinuation
-- rate and Phase 2/Phase 3 trials 35.6%, compared with 14.0% in Phase 1,
-- 26.2% in Phase 2 and 17.8% in Phase 3.
--
-- Phase 1/Phase 2 trials therefore had approximately 2.7 times the
-- discontinuation rate observed in Phase 1.
--
-- This is notable alongside the duration analysis, where Phase 1/Phase 2
-- trials also had the longest median completed duration at 29.2 months.
--
-- Business implication:
-- Combined-phase programmes warrant greater portfolio attention when
-- allocating monitoring and contingency resources. Teams could use
-- development phase as one input when prioritising milestone reviews,
-- schedule contingency and delivery-risk oversight rather than applying
-- identical monitoring intensity across all trials.
--
-- These results are descriptive and do not establish that combined-phase
-- design causes discontinuation. Resolved-outcome coverage also differs
-- between phases, particularly for newer or ongoing studies.

-- Query 10: Inspect reported reasons for trial discontinuation
-- Business question:
-- Why are trials being discontinued around the Phase 2 / Phase 3
-- transition, and what explanations appear most frequently?

WITH discontinued_trials AS (

    SELECT
        s.nct_id,
        COALESCE(s.phase, 'NOT_REPORTED') AS phase,
        s.overall_status,
        TRIM(s.why_stopped) AS why_stopped

    FROM ctgov.studies AS s

    WHERE s.study_type = 'INTERVENTIONAL'
        AND s.start_date >= DATE '2015-01-01'
        AND s.start_date < DATE '2026-01-01'

        AND s.overall_status IN (
            'TERMINATED',
            'WITHDRAWN'
        )

        AND s.phase IN (
            'PHASE2',
            'PHASE1/PHASE2',
            'PHASE2/PHASE3',
            'PHASE3'
        )

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
    phase,
    why_stopped,
    COUNT(*) AS trial_count

FROM discontinued_trials

WHERE why_stopped IS NOT NULL
    AND why_stopped <> ''

GROUP BY
    phase,
    why_stopped

ORDER BY
    trial_count DESC,
    phase

LIMIT 100;

-- Result / purpose:
-- Inspects the raw registry-reported reasons for terminated and withdrawn
-- trials around the Phase 2 / Phase 3 development transition.
--
-- Free-text reasons are reviewed before creating categories so that the
-- classification used in the next analysis is based on the actual source
-- data rather than predetermined assumptions.
--
-- Business use:
-- Provides the evidence needed to test whether elevated Phase 2 and
-- combined-phase discontinuation appears associated with recruitment,
-- operational/resource, commercial/strategic, efficacy or safety factors.
--
-- Registry stop reasons are sponsor-reported free text and may be missing,
-- inconsistent or differently worded for similar underlying causes.

-- Query 11: Categorise reasons for trial discontinuation
-- Business question:
-- What factors are associated with discontinuation around the
-- Phase 2 / Phase 3 transition, and does the evidence indicate
-- a meaningful portfolio-selection point before later-stage development?

WITH discontinued_trials AS (

    SELECT
        s.nct_id,
        COALESCE(s.phase, 'NOT_REPORTED') AS phase,
        LOWER(TRIM(s.why_stopped)) AS why_stopped

    FROM ctgov.studies AS s

    WHERE s.study_type = 'INTERVENTIONAL'
        AND s.start_date >= DATE '2015-01-01'
        AND s.start_date < DATE '2026-01-01'

        AND s.overall_status IN (
            'TERMINATED',
            'WITHDRAWN'
        )

        AND s.phase IN (
            'PHASE2',
            'PHASE1/PHASE2',
            'PHASE2/PHASE3',
            'PHASE3'
        )

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

reason_categories AS (

    SELECT
        nct_id,
        phase,

  CASE

    WHEN why_stopped IS NULL
        OR why_stopped = ''
        THEN 'NOT_REPORTED'

    -- Explicit commercial / portfolio reasoning
    WHEN why_stopped LIKE '%business%'
        OR why_stopped LIKE '%strategic%'
        OR why_stopped LIKE '%portfolio priorit%'
        OR why_stopped LIKE '%business objective%'
        OR why_stopped LIKE '%r&d strategy%'
        OR why_stopped LIKE '%development program%'
        OR why_stopped LIKE '%corporate policy%'
        OR why_stopped LIKE '%business priorit%'
        THEN 'BUSINESS_OR_STRATEGIC'

    -- Recruitment / accrual problems
    WHEN why_stopped LIKE '%recruit%'
        OR why_stopped LIKE '%enroll%'
        OR why_stopped LIKE '%enrol%'
        OR why_stopped LIKE '%accrual%'
        THEN 'RECRUITMENT_OR_ENROLLMENT'

    -- Clinical efficacy, excluding explicit negations
    WHEN (
        why_stopped LIKE '%efficacy%'
        OR why_stopped LIKE '%futility%'
        OR why_stopped LIKE '%primary endpoint%'
    )
    AND why_stopped NOT LIKE '%not related to%efficacy%'
    AND why_stopped NOT LIKE '%unrelated to%efficacy%'
    AND why_stopped NOT LIKE '%not prompted by%efficacy%'
        THEN 'EFFICACY_OR_FUTILITY'

    -- Safety / benefit-risk, excluding explicit negations
    WHEN (
        why_stopped LIKE '%safety%'
        OR why_stopped LIKE '%toxicity%'
        OR why_stopped LIKE '%adverse%'
        OR why_stopped LIKE '%risk profile%'
        OR why_stopped LIKE '%benefit risk%'
    )
    AND why_stopped NOT LIKE '%not related to%safety%'
    AND why_stopped NOT LIKE '%unrelated to%safety%'
    AND why_stopped NOT LIKE '%not a safety%'
    AND why_stopped NOT LIKE '%not prompted by%safety%'
        THEN 'SAFETY_OR_BENEFIT_RISK'

    WHEN why_stopped LIKE '%bankrupt%'
        OR why_stopped LIKE '%chapter 11%'
        OR why_stopped LIKE '%funding%'
        OR why_stopped LIKE '%financial%'
        THEN 'FINANCIAL_OR_FUNDING'

    WHEN why_stopped LIKE '%administrative%'
        OR why_stopped LIKE '%protocol%'
        OR why_stopped LIKE '%covid%'
        OR why_stopped LIKE '%coronavirus%'
        OR why_stopped LIKE '%study agent%'
        THEN 'OPERATIONAL_OR_ADMINISTRATIVE'

    WHEN why_stopped LIKE '%sponsor decision%'
        OR why_stopped LIKE '%sponsor''s decision%'
        OR why_stopped LIKE '%company decision%'
        OR why_stopped LIKE '%internal company decision%'
        THEN 'SPONSOR_DECISION_UNSPECIFIED'

    ELSE 'OTHER'

END AS reason_category

    FROM discontinued_trials
),

category_counts AS (

    SELECT
        phase,
        reason_category,
        COUNT(*) AS trial_count

    FROM reason_categories

    GROUP BY
        phase,
        reason_category
)

SELECT
    phase,
    reason_category,
    trial_count,

    ROUND(
        100.0 * trial_count
        / SUM(trial_count) OVER (
            PARTITION BY phase
        ),
        1
    ) AS phase_discontinuation_share_pct

FROM category_counts

ORDER BY
    phase,
    trial_count DESC;

-- Result / purpose:
-- Standardises free-text registry stop reasons into transparent analytical
-- categories while retaining generic sponsor/company decisions as a separate
-- group rather than assuming they were commercially motivated.
--
-- Business use:
-- Tests whether elevated discontinuation around Phase 2 and combined-phase
-- development is predominantly associated with clinical evidence,
-- recruitment constraints, explicit strategic/business decisions or other
-- operational factors.
--
-- This analysis can indicate where portfolio risk controls should focus,
-- but registry stop reasons are self-reported and category assignment is
-- based on keyword rules rather than independently verified root causes.

-- Analytical finding:
-- Discontinuation around the Phase 2 / Phase 3 transition appears
-- multifactorial rather than being driven by a single cause.
--
-- Among categorised Phase 2 discontinuations, recruitment/enrollment
-- was the largest identifiable reason (18.9%), followed by explicit
-- business/strategic decisions (15.8%).
--
-- Business/strategic reasons were particularly prominent in combined
-- Phase 1/Phase 2 trials (20.9%), while Phase 2/Phase 3 trials showed
-- equal contributions from business/strategic and recruitment factors
-- (15.0% each).
--
-- This is relevant alongside earlier findings showing that progression
-- into Phase 3 is associated with substantially greater operational scale:
-- median enrollment rises from 77 in Phase 2 to 308 in Phase 3 and
-- median site footprint from 10 to 30 sites.
--
-- Business implication:
-- Phase 2 should be treated as an important portfolio and operational
-- readiness checkpoint before committing to later-stage development.
-- Sponsors may benefit from reviewing recruitment feasibility, site-network
-- capacity and portfolio priority before scaling programmes into Phase 3.
--
-- The analysis does not establish that anticipated Phase 3 cost or
-- infrastructure requirements cause Phase 2 discontinuation.
-- Stop reasons are sponsor-reported free text, approximately 25-33%
-- remain in the broad OTHER category, and unspecified sponsor decisions
-- were not assumed to be commercially motivated.

-- Query 12: Results-posting coverage by development phase
-- Business question:
-- Which development phases show the largest gap in publicly posted
-- summary results, and where should reporting/governance teams
-- prioritise follow-up?

WITH eligible_trials AS (

    SELECT
        s.nct_id,
        COALESCE(s.phase, 'NOT_REPORTED') AS phase,
        s.primary_completion_date,
        s.results_first_posted_date

    FROM ctgov.studies AS s

    WHERE s.study_type = 'INTERVENTIONAL'
        AND s.start_date >= DATE '2015-01-01'

        AND s.overall_status = 'COMPLETED'

        AND s.primary_completion_date IS NOT NULL

        -- Allow a mature post-completion reporting window
        AND s.primary_completion_date
            <= CURRENT_DATE - INTERVAL '18 months'

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

phase_results AS (

    SELECT
        phase,

        COUNT(*) AS eligible_completed_trials,

        COUNT(*) FILTER (
            WHERE results_first_posted_date IS NOT NULL
        ) AS trials_with_posted_results,

        COUNT(*) FILTER (
            WHERE results_first_posted_date IS NULL
        ) AS trials_without_posted_results

    FROM eligible_trials

    GROUP BY phase
)

SELECT
    phase,
    eligible_completed_trials,
    trials_with_posted_results,
    trials_without_posted_results,

    ROUND(
        100.0 * trials_with_posted_results
        / NULLIF(eligible_completed_trials, 0),
        1
    ) AS results_coverage_pct,

    ROUND(
        100.0 * trials_without_posted_results
        / NULLIF(eligible_completed_trials, 0),
        1
    ) AS results_gap_pct

FROM phase_results

WHERE eligible_completed_trials >= 100

ORDER BY
    results_gap_pct DESC,
    eligible_completed_trials DESC;

-- Result / purpose:
-- Measures publicly posted summary-results coverage among completed
-- trials with a mature reporting window.
--
-- Trials are included only when primary completion occurred at least
-- 18 months before the analysis date, reducing distortion from studies
-- that may have completed too recently for meaningful reporting assessment.
--
-- Business use:
-- Identifies development stages with the largest results-posting gaps
-- and provides a basis for prioritising reporting-governance monitoring
-- and follow-up across the portfolio.
--
-- results_first_posted_date indicates that summary results became publicly
-- available on ClinicalTrials.gov after quality-control review.
--
-- This analysis measures registry results-posting coverage, not legal
-- compliance. Reporting requirements vary between studies, and the dataset
-- does not establish whether every trial was legally required to post results.

-- Analytical finding:
-- Public results-posting coverage varies substantially by development phase
-- among completed trials with at least an 18-month reporting window.
--
-- Phase 1 showed only 18.2% results coverage, with 8,028 of 9,810
-- eligible completed trials having no recorded posted summary results.
--
-- Phase 3 showed substantially higher coverage at 71.3%, although
-- 28.7% of eligible completed Phase 3 trials still had no recorded
-- posted summary results.
--
-- The Phase 1 to Phase 3 difference was 53.1 percentage points,
-- indicating that public-results visibility is strongly associated
-- with development stage within this registry cohort.
--
-- Business implication:
-- Reporting/governance teams should not assume consistent public-results
-- coverage across the portfolio. Earlier-stage programmes may warrant
-- targeted monitoring of disclosure status, particularly where internal
-- transparency standards extend beyond minimum regulatory requirements.
--
-- This analysis measures ClinicalTrials.gov results-posting coverage,
-- not legal compliance. Reporting obligations differ between studies,
-- and absence of posted results does not demonstrate a regulatory breach.
