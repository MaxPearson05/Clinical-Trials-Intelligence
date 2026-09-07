"""Offline packaging QA; standard library only. Reads exports without modifying them.

These checks validate the supplied extracts, not the omitted AACT source or PBIX.
The observed eligibility cutoff is diagnostic, not an asserted extraction date.
"""
from collections import Counter, defaultdict
from datetime import date
from pathlib import Path
from statistics import median
import csv
import hashlib
import json

ROOT = Path(__file__).resolve().parents[1]


def read_csv(name):
    with (ROOT / 'data' / name).open(encoding='utf-8-sig', newline='') as stream:
        return list(csv.DictReader(stream))


def flag(value):
    if value not in ('true', 'false'):
        raise ValueError(f'Unexpected boolean: {value!r}')
    return value == 'true'


def ratio(numerator, denominator):
    return round(100 * numerator / denominator, 1) if denominator else None


def main():
    facts = read_csv('fact_trials_powerbi.csv')
    bridge = read_csv('bridge_trial_country.csv')
    ids = {r['nct_id'] for r in facts}
    named_countries = defaultdict(set)
    for row in bridge:
        if row['country_name']:
            named_countries[row['nct_id']].add(row['country_name'])
    checks = {}
    checks['duplicate_fact_ids'] = len(facts) - len(ids)
    checks['blank_fact_ids'] = sum(not r['nct_id'] for r in facts)
    checks['invalid_nct_id_format'] = sum(
        not (len(i) == 11 and i.startswith('NCT') and i[3:].isdigit()) for i in ids
    )
    checks['duplicate_bridge_pairs'] = len(bridge) - len({(r['nct_id'], r['country_name']) for r in bridge})
    checks['bridge_orphans'] = sum(r['nct_id'] not in ids for r in bridge)
    checks['country_count_mismatches_excluding_blank'] = sum(
        int(r['country_count']) != len(named_countries[r['nct_id']]) for r in facts
    )
    checks['uk_flag_mismatches'] = sum(
        flag(r['uk_participation']) != ('United Kingdom' in named_countries[r['nct_id']]) for r in facts
    )
    checks['bridge_uk_flag_mismatches'] = sum(
        flag(r['is_uk']) != (r['country_name'] == 'United Kingdom') for r in bridge
    )
    checks['results_date_flag_mismatches'] = sum(
        flag(r['results_posted']) != bool(r['results_first_posted_date']) for r in facts
    )
    cutoff = '2025-03-01'
    checks['observed_eligibility_rule_mismatches'] = sum(
        flag(r['mature_results_eligible']) != (
            r['overall_status'] == 'COMPLETED'
            and bool(r['primary_completion_date'])
            and r['primary_completion_date'] <= cutoff
        ) for r in facts
    )
    checks['start_year_mismatches'] = sum(int(r['start_year']) != date.fromisoformat(r['start_date']).year for r in facts)
    checks['starts_before_2015'] = sum(r['start_date'] < '2015-01-01' for r in facts)
    duration_mismatches = 0
    reversed_dates = 0
    for r in facts:
        diff = (date.fromisoformat(r['completion_date']) - date.fromisoformat(r['start_date'])).days if r['completion_date'] else None
        reversed_dates += diff is not None and diff < 0
        expected = str(diff) if diff is not None and diff >= 0 else ''
        duration_mismatches += r['duration_days'] != expected
    checks['duration_rule_mismatches'] = duration_mismatches
    for field in ['enrollment', 'site_count', 'country_count', 'duration_days']:
        checks['negative_' + field] = sum(float(r[field]) < 0 for r in facts if r[field])
    statuses = Counter(r['overall_status'] for r in facts)
    eligible = [r for r in facts if flag(r['mature_results_eligible'])]
    posted = sum(flag(r['results_posted']) for r in eligible)
    uk = sum(flag(r['uk_participation']) for r in facts)
    known = sum(int(r['country_count']) > 0 for r in facts)
    metrics = {
        'total_trials': len(facts), 'completed': statuses['COMPLETED'],
        'terminated': statuses['TERMINATED'], 'terminated_share_pct': ratio(statuses['TERMINATED'], len(facts)),
        'uk_trials': uk, 'known_geography_trials': known, 'uk_participation_share_pct': ratio(uk, known),
        'mature_eligible_trials': len(eligible), 'posted_results_eligible': posted,
        'results_coverage_pct': ratio(posted, len(eligible)),
    }
    expected = dict(zip(metrics, [46955, 24633, 4609, 9.8, 6452, 44091, 14.6, 22021, 9513, 43.2]))
    checks['headline_metric_mismatches'] = sum(metrics[k] != expected[k] for k in expected)
    phase_findings = {}
    for phase in ['PHASE1', 'PHASE3']:
        rows = [r for r in facts if r['phase'] == phase]
        mature = [r for r in eligible if r['phase'] == phase]
        phase_findings[phase] = {
            'median_enrollment': median(float(r['enrollment']) for r in rows if r['enrollment']),
            'median_sites': median(int(r['site_count']) for r in rows),
            'eligible': len(mature), 'posted_eligible': sum(flag(r['results_posted']) for r in mature),
        }
        p = phase_findings[phase]
        p['coverage_pct'] = ratio(p['posted_eligible'], p['eligible'])
    a, b = phase_findings['PHASE1'], phase_findings['PHASE3']
    gap = round(100 * (b['posted_eligible']/b['eligible'] - a['posted_eligible']/a['eligible']), 1)
    uk_years = {}
    for year in ['2015', '2025']:
        rows = [r for r in facts if r['start_year'] == year]
        n, d = sum(flag(r['uk_participation']) for r in rows), sum(int(r['country_count']) > 0 for r in rows)
        uk_years[year] = {'uk': n, 'known_geography': d, 'share_pct': ratio(n, d)}
    country_counts = Counter()
    for countries in named_countries.values():
        country_counts.update(countries)
    result = {
        'scope': 'New offline packaging verification; not original-project QA or source reconstruction',
        'metrics': metrics,
        'zero_expected_checks': checks,
        'all_zero_expected_checks_pass': not any(checks.values()),
        'observations_not_automatic_failures': {
            'bridge_rows':len(bridge), 'bridge_represented_trials':len({r['nct_id'] for r in bridge}),
            'blank_country_rows':[r['nct_id'] for r in bridge if not r['country_name']],
            'missing_fields':{k:sum(r[k] == '' for r in facts) for k in facts[0]},
            'literal_NA_phase':sum(r['phase'] == 'NA' for r in facts),
            'completion_before_start':reversed_dates,
            'observed_eligibility_cutoff_not_extraction_date':cutoff,
            'all_posted_results':sum(flag(r['results_posted']) for r in facts),
            'not_posted_eligible':len(eligible)-posted,
            'status_counts':dict(statuses),
        },
        'findings':{'phase':phase_findings, 'uk_years':uk_years, 'coverage_gap_percentage_points_unrounded_inputs':gap},
        'top_eight_country_participation':dict(country_counts.most_common(8)),
        'sha256':{name:hashlib.sha256((ROOT/'data'/name).read_bytes()).hexdigest() for name in ['fact_trials_powerbi.csv','bridge_trial_country.csv']},
    }
    print(json.dumps(result, indent=2, ensure_ascii=False))
    return 0 if result['all_zero_expected_checks_pass'] else 1


if __name__ == '__main__':
    raise SystemExit(main())
