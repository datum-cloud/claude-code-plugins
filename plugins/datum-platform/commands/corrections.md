---
name: corrections
description: >
  Display user correction statistics and patterns. Shows recent corrections,
  their types, affected agents, and emerging patterns from user feedback.
tools: Read, Grep, Glob
model: sonnet
argument-hint: "[--agent <name>|--type <type>|--analyze|--since <days>]"
---

# Corrections Command

View and analyze user corrections to identify learning opportunities.

## Usage

```
/corrections                     Show recent corrections summary
/corrections --all               Show all corrections
/corrections --agent <name>      Filter by agent
/corrections --type <type>       Filter by correction type
/corrections --analyze           Run pattern extraction on corrections
/corrections --since <days>      Only show corrections from last N days
/corrections <pattern-name>      Show details for inferred pattern
```

## Workflow

### `/corrections` (default)

1. Read `.claude/user-corrections.jsonl`
2. Group by correction type and agent
3. Display summary with recent examples

**Output format:**

```
=== USER CORRECTIONS SUMMARY ===

Period: Last 30 days
Total corrections: 24

BY TYPE:
  code_quality         8   ████████░░   33%
  code_completeness    6   ██████░░░░   25%
  approach_rejection   4   ████░░░░░░   17%
  preference_conflict  3   ███░░░░░░░   12%
  expectation_mismatch 2   ██░░░░░░░░    8%
  communication_gap    1   █░░░░░░░░░    4%

BY AGENT:
  api-dev             12   ████████████  50%
  frontend-dev         7   ███████░░░░░  29%
  sre                  3   ███░░░░░░░░░  12%
  test-engineer        2   ██░░░░░░░░░░   8%

BY SEVERITY:
  high                 5   (21%)
  medium              14   (58%)
  low                  5   (21%)

BY SOURCE:
  explicit            15   (62%)  ← Direct user feedback
  implicit             9   (38%)  ← Inferred from behavior

RECENT CORRECTIONS:

Date        Agent        Type                 Summary
─────────────────────────────────────────────────────────────
2025-01-15  api-dev      approach_rejection   Used SQL instead of storage interface
2025-01-15  api-dev      code_completeness    Missing error context wrapping
2025-01-14  frontend-dev preference_conflict  Used inline styles instead of tokens
2025-01-14  sre          code_quality         Incorrect security context config
2025-01-13  api-dev      expectation_mismatch Added tests before implementation was done

TOP INFERRED PATTERNS:

Pattern                    Count  Confidence
───────────────────────────────────────────
use-existing-patterns      4      high
missing-error-context      3      high
scope-creep                2      medium
style-mismatch             2      medium

Run '/corrections --analyze' to extract patterns for /evolve.
Run '/corrections <pattern>' for pattern details.
```

### `/corrections --agent <name>`

Filter corrections by agent:

```
=== CORRECTIONS FOR: api-dev ===

Period: Last 30 days
Corrections: 12

BY TYPE:
  code_quality         5   ██████████░░  42%
  code_completeness    3   ██████░░░░░░  25%
  approach_rejection   2   ████░░░░░░░░  17%
  expectation_mismatch 2   ████░░░░░░░░  17%

EXPLICIT VS IMPLICIT:
  explicit             8   (67%)
  implicit             4   (33%)

SEVERITY BREAKDOWN:
  high                 3   (25%)
  medium               7   (58%)
  low                  2   (17%)

RECENT CORRECTIONS:

2025-01-15  approach_rejection   Used SQL instead of storage interface
            ai_action: Wrote pkg/registry/snapshot/storage.go with direct SQL
            user_said: "Let's use the storage interface like other resources"
            severity: high | source: explicit

2025-01-15  code_completeness    Missing error context wrapping
            ai_action: Wrote Create method without fmt.Errorf wrapping
            user_did: Added error context to all error returns
            severity: medium | source: implicit

INFERRED PATTERNS:
  use-existing-patterns     3 occurrences
  missing-error-context     2 occurrences

LEARNING OPPORTUNITIES:
  → High severity explicit corrections suggest api-dev should:
    - Check existing patterns before implementing
    - Always wrap errors with context
```

### `/corrections --type <type>`

Filter by correction type:

```
=== CORRECTIONS: approach_rejection ===

Total: 4 corrections

These indicate the user rejected Claude's overall approach.

DETAILS:

2025-01-15  api-dev
  ai_action:  Implemented storage using direct SQL queries
  user_said:  "Let's use the storage interface pattern instead"
  pattern:    use-existing-patterns
  severity:   high

2025-01-13  frontend-dev
  ai_action:  Created custom form validation logic
  user_said:  "Actually, let's use React Hook Form with Zod"
  pattern:    use-existing-patterns
  severity:   medium

2025-01-10  sre
  ai_action:  Added inline patches in base kustomization
  user_said:  "No, patches should go in overlays, not base"
  pattern:    wrong-abstraction-layer
  severity:   medium

2025-01-08  api-dev
  ai_action:  Implemented manual validation functions
  user_said:  "Use kubebuilder markers instead of manual validation"
  pattern:    use-existing-patterns
  severity:   high

COMMON THEME:
  75% of approach rejections involve using existing patterns/tools
  instead of custom implementations.

RECOMMENDATION:
  Agents should check existing patterns before implementing:
  - Read existing code first
  - Check skill documentation for recommended patterns
  - Ask if unsure about approach
```

### `/corrections --analyze`

Extract patterns from corrections for `/evolve`:

```
=== CORRECTION PATTERN ANALYSIS ===

Analyzing 24 corrections from last 30 days...

PATTERN EXTRACTION:

Pattern: use-existing-patterns
  Occurrences: 4
  Types: approach_rejection (3), preference_conflict (1)
  Agents: api-dev (3), frontend-dev (1)
  Severity: high (3), medium (1)
  Confidence: 0.85 (high)
  → READY FOR PROMOTION

Pattern: missing-error-context
  Occurrences: 3
  Types: code_completeness (3)
  Agents: api-dev (3)
  Severity: medium (3)
  Confidence: 0.72 (medium)
  → READY FOR PROMOTION

Pattern: scope-creep
  Occurrences: 2
  Types: expectation_mismatch (2)
  Agents: api-dev (1), test-engineer (1)
  Severity: low (2)
  Confidence: 0.48 (low)
  → TRACKING (needs more occurrences)

Pattern: style-mismatch
  Occurrences: 2
  Types: preference_conflict (2)
  Agents: frontend-dev (2)
  Severity: low (2)
  Confidence: 0.45 (low)
  → TRACKING (needs more occurrences)

PROMOTION CANDIDATES:
  2 patterns ready for runbook promotion
  2 patterns need more data

Run '/evolve' to promote patterns to runbooks.

SOURCE QUALITY BREAKDOWN:
  explicit_user_correction: 15 (weight 1.0)
  implicit_user_correction:  9 (weight 0.8)

  Effective correction weight: 21.2 (vs 24 raw count)
```

### `/corrections <pattern-name>`

Show details for a specific inferred pattern:

```
=== PATTERN: use-existing-patterns ===

Inferred from: 4 user corrections
Correction types: approach_rejection (3), preference_conflict (1)

DESCRIPTION:
  Users corrected Claude for implementing custom solutions when
  existing patterns or tools were available.

OCCURRENCES:

2025-01-15  api-dev  approach_rejection  HIGH
  ai_action:  Implemented storage using direct SQL queries
  user_said:  "Let's use the storage interface pattern instead"
  context:    Implementing snapshot storage for compute-api

2025-01-13  frontend-dev  approach_rejection  MEDIUM
  ai_action:  Created custom form validation logic
  user_said:  "Actually, let's use React Hook Form with Zod"
  context:    Adding validation to resource creation form

2025-01-10  api-dev  approach_rejection  MEDIUM
  ai_action:  Implemented manual validation functions
  user_said:  "Use kubebuilder markers instead"
  context:    Adding validation to VM types

2025-01-08  api-dev  preference_conflict  HIGH
  ai_action:  Used custom error type
  user_said:  "I prefer using apierrors from k8s.io/apimachinery"
  context:    Error handling in storage backend

PATTERN CONFIDENCE: 0.85 (high)
  - 4 occurrences (0.4 × 0.4 = 0.16)
  - High severity average (0.3 × 0.83 = 0.25)
  - Recent (0.2 × 1.0 = 0.20)
  - Multiple agents (0.1 × 0.67 = 0.07)
  - Source quality (0.15 × 1.0 = 0.15)

RECOMMENDED RUNBOOK ENTRY:

### Check Existing Patterns First (User Correction)

**Confidence**: 0.85 | **Corrections**: 4 | **Last seen**: 2025-01-15

**Context**: Before implementing new functionality

**Anti-Pattern**: Implementing custom solutions without checking existing patterns

**Instead**: Before implementing:
1. Read existing code for similar functionality
2. Check skill documentation for recommended patterns
3. Use established libraries and interfaces
4. Ask if unsure whether custom implementation is needed

**Examples of existing patterns to prefer**:
- Storage interface pattern (not direct SQL)
- React Hook Form + Zod (not custom validation)
- kubebuilder markers (not manual validation)
- apimachinery error types (not custom errors)

**Learned from**: User corrections on 2025-01-08, 2025-01-10, 2025-01-13, 2025-01-15
```

## Correction Types

| Type | Description |
|------|-------------|
| `code_quality` | User fixes bugs, style, logic errors |
| `code_completeness` | User adds code Claude missed |
| `approach_rejection` | User rejects overall approach |
| `expectation_mismatch` | Claude did something unexpected |
| `communication_gap` | Claude misunderstood request |
| `preference_conflict` | User prefers different pattern |

## No Data Handling

```
No correction data found at .claude/user-corrections.jsonl

User corrections are logged during agent sessions when:
- User explicitly corrects Claude's output
- User edits code Claude just wrote
- User rejects an approach and requests alternative

To start collecting corrections:
1. Agents detect correction signals during work
2. Log corrections to .claude/user-corrections.jsonl
3. Run /corrections to view accumulated data
4. Run /evolve to promote patterns to runbooks

See user-corrections/detection.md for signal detection details.
```

## Integration with Learning Engine

Corrections feed into the same learning engine as review findings:

```
user-corrections.jsonl  ──┐
                          ├──→  /evolve  ──→  patterns.json  ──→  runbooks
review-findings.jsonl   ──┤
session-learnings.jsonl ──┘
```

The `/evolve` command weights corrections by source:
- Explicit user corrections: 1.0 (highest weight)
- Implicit user corrections: 0.8
- Review findings: 0.3-0.7 (by severity)

## Skills Referenced

- `user-corrections/SKILL.md` — Overview of correction learning
- `user-corrections/schemas.md` — JSON schema for correction data
- `user-corrections/detection.md` — How agents detect corrections
- `learning-engine/analysis.md` — Pattern analysis with source weighting
