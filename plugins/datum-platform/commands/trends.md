---
name: trends
description: >
  Show pattern trends over time and generate alerts for concerning changes.
  Helps identify areas where the team is improving or struggling.
tools: Read, Grep, Glob
model: sonnet
argument-hint: "[--window <days>|--compare|--alerts|--service <name>]"
---

# Trends Command

Analyze pattern trends and generate actionable insights.

## Usage

```
/trends                       Show current trend summary
/trends --window <days>       Use different analysis window (default: 30)
/trends --compare             Compare current window to previous
/trends --alerts              Show only actionable alerts
/trends --service <name>      Show trends for specific service
```

## Workflow

### `/trends` (default)

1. Read `.claude/patterns/trends.json`
2. Display summary of pattern trends
3. Highlight alerts and recommendations

**Output format:**

```
=== PATTERN TRENDS ===

Analysis window: Last 30 days (2024-12-16 to 2025-01-15)
Previous window: 30 days prior (2024-11-16 to 2024-12-15)

SUMMARY:
  Total patterns tracked:  23
  Increasing:              3  ⚠️
  Decreasing:              5  ✓
  Stable:                  12
  New:                     2
  Resolved:                1  ✓

=== ALERTS ===

🔴 HIGH PRIORITY:

  unvalidated-input [security] [blocking]
  ├─ Trend: +150% (2 → 5 occurrences)
  ├─ Affected: api-dev in compute-api, network-api
  └─ Action: Consider team training on input validation patterns

  missing-status-condition [correctness] [blocking]
  ├─ Trend: +100% (3 → 6 occurrences)
  ├─ Affected: api-dev across all services
  └─ Action: Review status condition checklist in api-dev runbook

🟡 WATCH:

  storage-init-race [correctness] [warning]
  ├─ Trend: new (0 → 3 occurrences)
  ├─ Affected: api-dev in compute-api
  └─ Action: Monitor; may indicate new pattern emerging

=== IMPROVEMENTS ===

✅ hardcoded-value
   ├─ Trend: -60% (5 → 2 occurrences)
   └─ Team is improving on avoiding hardcoded values

✅ import-ordering
   ├─ Trend: resolved (3 → 0 occurrences)
   └─ Convention now consistently followed

=== CROSS-SERVICE INSIGHTS ===

Services with most findings:
  1. compute-api:  15 findings (8 patterns)
  2. network-api:  10 findings (6 patterns)
  3. storage-api:   5 findings (4 patterns)

Pattern correlation:
  - missing-status-condition appears across ALL services
  - storage-init-race concentrated in compute-api (investigate)

=== RECOMMENDATIONS ===

1. Address unvalidated-input trend
   - Add validation examples to api-dev runbook
   - Consider pre-commit validation hook

2. Investigate storage-init-race
   - New pattern in compute-api
   - Check if network-api/storage-api have similar code

3. Celebrate improvements
   - hardcoded-value and import-ordering trending down
   - Team learning is working
```

### `/trends --compare`

Detailed comparison between windows:

```
=== WINDOW COMPARISON ===

                        Previous    Current     Change
                        (30 days)   (30 days)
──────────────────────────────────────────────────────
Total findings          28          35          +25%
Unique patterns         18          21          +17%
Blocking findings       12          18          +50% ⚠️
Warning findings        10          12          +20%
Nit findings            6           5           -17%

PATTERN MOVEMENTS:

  Got worse (↑):
    unvalidated-input          2 → 5    (+150%)
    missing-status-condition   3 → 6    (+100%)
    concurrency-race           1 → 2    (+100%)

  Improved (↓):
    hardcoded-value            5 → 2    (-60%)
    missing-test-coverage      4 → 2    (-50%)
    import-ordering            3 → 0    (-100%) ✓

  Stable (→):
    missing-error-context      2 → 2    (0%)
    tenant-isolation-gap       1 → 1    (0%)

  New patterns:
    storage-init-race          0 → 3    (new)
    missing-deepcopy-tag       0 → 1    (new)

  Resolved:
    nil-dereference            2 → 0    (resolved)
```

### `/trends --alerts`

Show only actionable items:

```
=== ACTIONABLE ALERTS ===

IMMEDIATE ACTION REQUIRED:

1. unvalidated-input is increasing rapidly
   Severity: blocking | Trend: +150%

   Recommended actions:
   - Review recent PRs for validation patterns
   - Update api-dev runbook with validation checklist
   - Consider adding validation to PR template

2. missing-status-condition spreading across services
   Severity: blocking | Trend: +100%

   Recommended actions:
   - Add status condition check to code-reviewer priority list
   - Create shared utility for status condition updates
   - Add to api-dev workflow checklist

MONITOR:

3. storage-init-race is a new pattern
   Severity: warning | Occurrences: 3

   Recommended actions:
   - Document pattern in api-dev runbook
   - Check other services for similar code
   - Consider adding to validation scripts
```

### `/trends --service <name>`

Service-specific trends:

```
=== TRENDS FOR: compute-api ===

Analysis window: Last 30 days

FINDINGS:
  Total: 15
  Blocking: 8
  Warning: 5
  Nit: 2

TOP PATTERNS IN THIS SERVICE:
  missing-status-condition    5 occurrences  [stable]
  storage-init-race           3 occurrences  [new]
  unvalidated-input           2 occurrences  [increasing]
  hardcoded-value             2 occurrences  [decreasing]
  missing-error-context       2 occurrences  [stable]
  import-ordering             1 occurrence   [stable]

COMPARISON TO PLATFORM AVERAGE:
  - Higher than average: storage-init-race (3x platform average)
  - Lower than average: hardcoded-value (0.5x platform average)

RECOMMENDATIONS FOR THIS SERVICE:
  - Focus on storage initialization patterns
  - Investigate why storage-init-race is concentrated here
```

## Data Sources

Trends are calculated from:
- `.claude/patterns/patterns.json` - Pattern registry
- `.claude/review-findings.jsonl` - Raw findings
- `.claude/patterns/trends.json` - Cached trend analysis

## No Data Handling

```
No trend data available.

To generate trend data:
1. Run code reviews to accumulate findings
2. Run /evolve to analyze patterns
3. Run /trends to view analysis

Minimum data needed: 5+ findings over 2+ weeks
```
