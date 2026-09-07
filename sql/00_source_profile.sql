-- Query 1: Count validation

SELECT COUNT(*)
FROM ctgov.studies;

-- Count = 600,377
-- Plan is to apply our project contract - > interventional, industry-led, drug/biological, start date>=2015 
-- This will give us our actual project cohort
-- Doing this by reproducing yesterdays API cohort definition in sql

-- Query 2: Count studies matching the locked project cohort
-- Grain: one distinct clinical study/ nct_id

select 
 COUNT(distinct s.nct_id) as project_cohort_count
from ctgov.studies as s

inner join ctgov.sponsors as sp
	on s.nct_id = sp.nct_id

inner join ctgov.interventions as i
	on s.nct_id = i.nct_id

where s.study_type = 'INTERVENTIONAL'
 
 and sp.lead_or_collaborator = 'lead'
 and sp.agency_class = 'INDUSTRY'
 
 and i.intervention_type in('DRUG', 'BIOLOGICAL')
 
 and s.start_date >= DATE '2015-01-01';
 
-- AACT project cohort count: 46,905
-- ClinicalTrials.gov API count from 26 Aug 2026: 46,911
-- Difference: 6 studies
-- Small difference retained and documented because the API is live
-- while AACT represents a dated relational registry snapshot.
 
 -- Query 3: Demonstrate row multiplication after joing child tables
 -- Compare total joined rows with unique clinical trials
 
select 
	count(*) as joined_row_count,
	count(distinct s.nct_id) as unique_trial_count
from ctgov.studies as s

inner join ctgov.sponsors as sp
	on s.nct_id= sp.nct_id

inner join ctgov.interventions as i
	on s.nct_id = i.nct_id
	
where s.study_type = 'INTERVENTIONAL'
	and sp.lead_or_collaborator = 'lead'
	and sp.agency_class = 'INDUSTRY'
	and i.intervention_type in ('DRUG', 'BIOLOGICAL')
	and s.start_date>= DATE '2015-01-01';

-- Result:
-- Joined rows: 101,476
-- Unique trials: 46,905
--
-- The join produces multiple rows per trial because a single study
-- can contain multiple qualifying interventions.
-- Therefore COUNT(*) would overstate the number of clinical trials.
-- COUNT(DISTINCT nct_id) preserves the intended one-study grain.

-- Query 4: Profile the locked project cohort
-- Grain: one row per unique clinical trial / nct_id

WITH project_cohort AS(

	SELECT DISTINCT
		s.nct_id,
		s.start_date
	
	FROM ctgov.studies AS s
	
	INNER JOIN ctgov.sponsors AS sp
		ON s.nct_id=sp.nct_id
	
	INNER JOIN ctgov.interventions AS i
		ON s.nct_id = i.nct_id
	
	WHERE s.study_type = 'INTERVENTIONAL'
		and sp.lead_or_collaborator ='lead'
		and sp.agency_class = 'INDUSTRY'
		and i.intervention_type in ('DRUG', 'BIOLOGICAL')
		and s.start_date >= DATE '2015-01-01')

SELECT
    COUNT(*) AS trial_count,
    MIN(start_date) AS earliest_start_date,
    MAX(start_date) AS latest_start_date,
    COUNT(*) FILTER (WHERE start_date IS NULL) AS missing_start_dates
    
FROM project_cohort;

-- Result:
-- Trial count: 46,905
-- Earliest start date: 2015-01-01
-- Latest start date: 2050-01-31
-- Missing start dates: 0
--
-- Future planned start dates can exist in registry records,
-- so date range is documented rather than automatically treated as an error.
	
	
	
