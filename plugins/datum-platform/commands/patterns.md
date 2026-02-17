---
name: patterns
description: >
  Display pattern statistics from the learning engine. Shows top patterns,
  their frequency, trends, and which agents are affected.
tools: Read, Grep, Glob
model: sonnet
argument-hint: "[pattern-name|--all|--agent <name>|--trend <type>]"
---

# Patterns Command

View pattern statistics and insights from the learning engine.

## Usage

```
/patterns                     Show top 10 patterns by occurrence
/patterns --all               Show all patterns
/patterns --agent <name>      Show patterns affecting specific agent
/patterns --trend increasing  Show patterns with specific trend
/patterns --category security Show patterns in specific category
/patterns <pattern-name>      Show details for specific pattern
```

## Workflow

### `/patterns` (default)

1. Read `.claude/patterns/patterns.json`
2. Sort patterns by occurrence count (descending)
3. Display top 10 with summary statistics

**Output format:**

```
=== TOP PATTERNS ===

Last analysis: 2025-01-15 10:30:00

 #  Pattern                      Count  Trend       Confidence  Agents
 1  missing-status-condition     12     stable      0.85        api-dev, code-reviewer
 2  unvalidated-input            8      increasing  0.78        api-dev, code-reviewer
 3  hardcoded-value              6      decreasing  0.65        api-dev, sre
 4  storage-init-race            4      stable      0.62        api-dev
 5  missing-error-context        3      new         0.58        api-dev
 6  tenant-isolation-gap         3      stable      0.72        api-dev, code-reviewer
 7  nil-dereference              2      stable      0.45        api-dev, test-engineer
 8  import-ordering              2      stable      0.35        api-dev
 9  insufficient-test-coverage   2      stable      0.42        test-engineer
10  missing-deepcopy-tag         1      new         0.25        api-dev

Legend: ↑ increasing  ↓ decreasing  → stable  ★ new  ✓ resolved

Run '/patterns <name>' for details on a specific pattern.
Run '/evolve' to update patterns from recent findings.
```

### `/patterns <pattern-name>`

Show detailed information for a specific pattern:

```
=== PATTERN: missing-status-condition ===

Description:  Resource types missing status condition updates after operations
Category:     correctness
Severity:     blocking
Confidence:   0.85

STATISTICS:
  Total occurrences: 12
  First seen:        2024-11-01
  Last seen:         2025-01-15
  Trend:             stable (no significant change)

AFFECTED:
  Agents:   api-dev, code-reviewer
  Services: compute-api (5), network-api (4), storage-api (3)

RECENT OCCURRENCES:
  2025-01-15  compute-api  pkg/apis/vm/v1alpha1/types.go:142        PR #234
  2025-01-12  network-api  pkg/apis/network/v1alpha1/types.go:89    PR #231
  2025-01-08  storage-api  pkg/apis/volume/v1alpha1/types.go:67     PR #228

FIX TEMPLATE:
  Add status condition update in reconcile loop:

  ```go
  meta.SetStatusCondition(&obj.Status.Conditions, metav1.Condition{
      Type:    "Ready",
      Status:  metav1.ConditionTrue,
      Reason:  "ReconcileSuccess",
      Message: "Resource reconciled successfully",
  })
  ```

RUNBOOK STATUS:
  Promoted: Yes
  Agents:   api-dev, code-reviewer
  Date:     2024-12-15
```

### `/patterns --agent <name>`

Filter patterns by affected agent:

```
=== PATTERNS FOR: api-dev ===

Pattern                      Count  Trend       Confidence  Promoted
missing-status-condition     12     stable      0.85        Yes
unvalidated-input            8      increasing  0.78        Yes
hardcoded-value              6      decreasing  0.65        Yes
storage-init-race            4      stable      0.62        Yes
missing-error-context        3      new         0.58        Yes
nil-dereference              2      stable      0.45        No (low confidence)
import-ordering              2      stable      0.35        No (low confidence)

Total: 7 patterns
Promoted to runbook: 5
Tracking only: 2
```

### `/patterns --trend <trend>`

Filter patterns by trend:

```
=== INCREASING PATTERNS ===

Pattern                Count  30-day  Previous  Change
unvalidated-input      8      5       2         +150%
missing-test-coverage  3      2       0         new

⚠️ These patterns are becoming more frequent.
   Consider team training or process improvements.
```

### `/patterns --category <category>`

Filter patterns by category:

```
=== SECURITY PATTERNS ===

Pattern                Count  Trend       Confidence  Severity
unvalidated-input      8      increasing  0.78        blocking
tenant-isolation-gap   3      stable      0.72        blocking
hardcoded-secret       1      resolved    0.30        blocking

Total: 3 security patterns
```

## Pattern Categories

| Category | Description |
|----------|-------------|
| `security` | Security vulnerabilities, auth issues |
| `correctness` | Logic errors, missing functionality |
| `convention` | Style, naming, structure violations |
| `completeness` | Missing integrations, incomplete implementations |
| `performance` | Performance issues, inefficiencies |

## Trend Values

| Trend | Meaning |
|-------|---------|
| `increasing` | 50%+ more occurrences than previous 30 days |
| `decreasing` | 50%+ fewer occurrences than previous 30 days |
| `stable` | Within 50% of previous 30 days |
| `new` | First appeared in current 30-day window |
| `resolved` | No occurrences in current window after previous activity |

## No Data Handling

If no pattern registry exists:

```
No pattern data found.

To build pattern data:
1. Run code reviews with code-reviewer agent
2. Reviews log findings to .claude/review-findings.jsonl
3. Run /evolve to analyze findings and extract patterns
```
