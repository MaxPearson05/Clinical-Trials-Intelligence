# Dashboard measures

Analytical formulas retained from the original measure documentation. They were not extracted from or executed in the PBIX model during this review. See [methodology](methodology.md) for definitions, denominators and interpretation.

### Total Trials

```dax
Total Trials =
DISTINCTCOUNT(FactTrials[nct_id])
```

### Completed Trials

```dax
Completed Trials =
CALCULATE(
    DISTINCTCOUNT(FactTrials[nct_id]),
    FactTrials[overall_status] = "COMPLETED"
)
```

### Terminated Trials

```dax
Terminated Trials =
CALCULATE(
    DISTINCTCOUNT(FactTrials[nct_id]),
    FactTrials[overall_status] = "TERMINATED"
)
```

### Terminated Share

```dax
Terminated Share =
DIVIDE(
    [Terminated Trials],
    [Total Trials]
)
```

### Trials by Country

```dax
Trials by Country =
DISTINCTCOUNT(BridgeTrialCountry[nct_id])
```

### Median Enrollment

```dax
Median Enrollment =
MEDIAN(FactTrials[enrollment])
```

### 75th Percentile Enrollment

```dax
75th Percentile Enrollment =
PERCENTILEX.INC(
    FactTrials,
    FactTrials[enrollment],
    0.75
)
```

### Median Sites

```dax
Median Sites =
MEDIAN(FactTrials[site_count])
```

### Median Countries

```dax
Median Countries =
MEDIAN(FactTrials[country_count])
```

### Median Duration Months

```dax
Median Duration Months =
DIVIDE(
    MEDIAN(FactTrials[duration_days]),
    30.4375
)
```

### Final Outcome Trials

```dax
Final Outcome Trials =
CALCULATE(
    DISTINCTCOUNT(FactTrials[nct_id]),
    FactTrials[overall_status]
        IN {
            "COMPLETED",
            "TERMINATED",
            "WITHDRAWN"
        }
)
```

### Discontinuation Rate

```dax
Discontinuation Rate =
DIVIDE(
    [Terminated Trials],
    [Final Outcome Trials]
)
```

### UK Trials

```dax
UK Trials =
CALCULATE(
    DISTINCTCOUNT(FactTrials[nct_id]),
    FactTrials[uk_participation] = TRUE()
)
```

### Known Geography Trials

```dax
Known Geography Trials =
CALCULATE(
    DISTINCTCOUNT(FactTrials[nct_id]),
    FactTrials[country_count] > 0
)
```

### UK Participation Share

```dax
UK Participation Share =
DIVIDE(
    [UK Trials],
    [Known Geography Trials]
)
```

### Mature Eligible Trials

```dax
Mature Eligible Trials =
CALCULATE(
    DISTINCTCOUNT(FactTrials[nct_id]),
    FactTrials[mature_results_eligible] = TRUE()
)
```

### Posted Results Trials

```dax
Posted Results Trials =
CALCULATE(
    DISTINCTCOUNT(FactTrials[nct_id]),
    FactTrials[mature_results_eligible] = TRUE(),
    FactTrials[results_posted] = TRUE()
)
```

### Results Coverage

```dax
Results Coverage =
DIVIDE(
    [Posted Results Trials],
    [Mature Eligible Trials]
)
```

### Not Posted Results

```dax
Not Posted Results =
[Mature Eligible Trials] - [Posted Results Trials]
```
