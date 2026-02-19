# Skills and Runbooks

Skills are knowledge modules that agents read during their context discovery phase. Runbooks accumulate learned knowledge from past features. Together, they enable agents to work with service-specific patterns rather than general knowledge.

## Table of Contents

- [What Skills Are](#what-skills-are)
- [What Runbooks Are](#what-runbooks-are)
- [The Learning Loop](#the-learning-loop)
- [Running /evolve](#running-evolve)
- [Viewing Patterns](#viewing-patterns)
- [Viewing Trends](#viewing-trends)
- [Viewing Corrections](#viewing-corrections)

---

## What Skills Are

Skills are knowledge modules that agents read during their context discovery phase. They contain patterns, implementation guides, and reference material specific to a domain. Agents load the skills relevant to their current task.

**Skills in `datum-platform`:**

| Skill | Content |
|:------|:--------|
| `k8s-apiserver-patterns` | Aggregated API server storage, types, validation, server config |
| `controller-runtime-patterns` | Controller design with Milo multi-cluster runtime |
| `kustomize-patterns` | Kustomize base, components, overlays |
| `fluxcd-deployment` | OCI Repository, Flux Kustomization, infra repo structure |
| `datum-ci` | GitHub Actions, task files, container security |
| `go-conventions` | Go code style, testing patterns, import ordering |
| `milo-iam` | ProtectedResource, Roles, PolicyBinding, permission inheritance |
| `capability-quota` | Resource metering and quota enforcement |
| `capability-activity` | Event emission and activity tracking |
| `capability-insights` | Detector patterns and insight generation |
| `capability-telemetry` | Observability setup, metrics, tracing |
| `design-tokens` | Frontend token architecture and pattern registry |
| `pipeline-conductor` | Pipeline stages, handoff format, templates |
| `learning-engine` | Pattern extraction and runbook promotion |
| `user-corrections` | User correction detection and logging |

**Skills in `datum-gtm`:**

| Skill | Content |
|:------|:--------|
| `commercial-models` | Pricing frameworks, tier design |
| `discover` | Feature discovery methodology |
| `gtm-templates` | Blog post, changelog, enablement templates |

---

## What Runbooks Are

Runbooks accumulate learned knowledge from past features. Each agent has a companion runbook stored in the service repository at:

```
.claude/skills/runbooks/
├── api-dev/RUNBOOK.md
├── code-reviewer/RUNBOOK.md
├── sre/RUNBOOK.md
├── test-engineer/RUNBOOK.md
└── ...
```

When an agent starts work, it reads its runbook to load patterns from past experience on this specific service — what has worked, what has caused problems, and what mistakes to avoid.

### Runbook Structure

Each runbook contains:

| Section | Purpose |
|:--------|:--------|
| Patterns | Common issues seen during reviews with examples |
| Anti-patterns | Approaches that have caused problems |
| Service-specific notes | Quirks of this particular codebase |
| Recent learnings | Automatically promoted from `/evolve` |

---

## The Learning Loop

The learning system feeds on three sources:

1. **Review findings**: Every code-reviewer finding logged to `.claude/review-findings.jsonl` with a structured pattern name
2. **Session learnings**: Any agent can log insights to `.claude/session-learnings.jsonl` during implementation
3. **User corrections**: When users correct agent outputs, agents log to `.claude/user-corrections.jsonl`

```mermaid
flowchart LR
    subgraph Input Sources
        review[Code Review] --> findings[review-findings.jsonl]
        agents[Any Agent] --> learnings[session-learnings.jsonl]
        user[User Corrections] --> corrections[user-corrections.jsonl]
    end

    subgraph Analysis
        findings --> evolve[/evolve command]
        learnings --> evolve
        corrections --> evolve
        evolve --> patterns[Pattern Analysis]
    end

    subgraph Output
        patterns -->|confidence >= 0.6| runbooks[Agent Runbooks]
        runbooks --> future[Future Agent Sessions]
    end

    future -.->|improved behavior| review
    future -.->|fewer corrections| user

    style evolve fill:#ff9,stroke:#333
    style runbooks fill:#9f9,stroke:#333
    style corrections fill:#f9f,stroke:#333
```

The cycle is self-improving: findings and corrections become patterns, patterns update runbooks, and agents reading runbooks produce fewer findings and need fewer corrections.

### Source Quality Weighting

Not all learning sources are equal. User corrections carry the highest weight because they represent direct feedback:

| Source | Weight | Description |
|:-------|:-------|:------------|
| Explicit user correction | 1.0 | User directly stated what was wrong |
| Implicit user correction | 0.8 | User edited code or re-requested differently |
| Blocking review finding | 0.7 | Code reviewer flagged a blocking issue |
| Warning review finding | 0.5 | Code reviewer flagged a warning |
| Session learning | 0.4 | Agent self-reported insight |
| Nit review finding | 0.3 | Minor convention issue |

These weights affect how quickly patterns reach the promotion threshold.

### Finding Format

Each finding in `.claude/review-findings.jsonl` includes:

```json
{
  "timestamp": "2025-01-15T14:30:00Z",
  "feature_id": "feat-042",
  "pattern": "missing-status-condition",
  "severity": "warning",
  "file": "pkg/apis/compute/v1alpha1/types.go",
  "description": "VirtualMachine type missing Ready condition",
  "agent": "code-reviewer"
}
```

### Session Learning Format

Agents log insights to `.claude/session-learnings.jsonl`:

```json
{
  "timestamp": "2025-01-15T15:00:00Z",
  "feature_id": "feat-042",
  "agent": "api-dev",
  "insight": "Storage initialization must use sync.Once to prevent race conditions during concurrent reconciliation",
  "context": "Discovered when tests failed intermittently under parallel execution"
}
```

---

## Running /evolve

```bash
/evolve                     # Full analysis and runbook promotion
/evolve --dry-run           # Show what would change without making changes
/evolve --since 14          # Analyze only the last 14 days of findings
/evolve --agent api-dev     # Only update api-dev runbook
```

`/evolve` reads all findings and session learnings, groups them by pattern name, calculates a confidence score based on frequency and severity, detects trends (increasing, decreasing, stable, new, resolved), and promotes high-confidence patterns to runbooks.

### Promotion Criteria

For a pattern to be promoted to a runbook:

| Criterion | Threshold |
|:----------|:----------|
| Occurrence count | >= 3 |
| Confidence score | >= 0.6 |

### Example Output

```
ANALYSIS COMPLETE
═══════════════════════════════════════════════════════════════

Findings analyzed: 47
Session learnings: 12
Patterns identified: 18

HIGH CONFIDENCE (>= 0.8):
  missing-status-condition    [12 occurrences] [stable]     → Promoted to: api-dev
  missing-input-validation    [8 occurrences]  [increasing] → Promoted to: api-dev

MEDIUM CONFIDENCE (0.6-0.8):
  inefficient-list-watch      [4 occurrences]  [new]        → Promoted to: api-dev

LOW CONFIDENCE (< 0.6):
  inconsistent-error-message  [2 occurrences]  [new]        → Not promoted (below threshold)

TRENDS:
  ↑ INCREASING: missing-input-validation (was 3, now 8)
  ↓ DECREASING: incorrect-import-order (was 15, now 2)
  ✓ RESOLVED: missing-finalizer (no occurrences in 30 days)
```

### Recommended Schedule

| Frequency | Action |
|:----------|:-------|
| Weekly | Run `/evolve` on active services |
| Monthly | Review auto-generated runbook entries for accuracy |
| Quarterly | Prune resolved patterns from runbooks |

---

## Viewing Patterns

```bash
/patterns                          # Top 10 patterns by occurrence
/patterns --all                    # All patterns
/patterns --agent api-dev          # Patterns affecting api-dev
/patterns --trend increasing       # Patterns getting worse
/patterns --category security      # Security patterns only
/patterns missing-status-condition # Details on a specific pattern
```

### Example Output

```
TOP PATTERNS (last 30 days)
═══════════════════════════════════════════════════════════════

 #  Pattern                      Count  Trend      Category    Agents
 1  missing-status-condition     12     stable     api         api-dev
 2  missing-input-validation     8      increasing security    api-dev, frontend-dev
 3  incorrect-import-order       5      decreasing convention  api-dev
 4  missing-error-handling       4      stable     correctness api-dev
 5  hardcoded-color-value        4      new        convention  frontend-dev
```

### Pattern Details

```bash
/patterns missing-status-condition
```

```
PATTERN: missing-status-condition
═══════════════════════════════════════════════════════════════

Category: api
Severity: warning
Trend: stable (12 occurrences, consistent over 30 days)
Agents affected: api-dev

Description:
  API types are missing standard status conditions (Ready, Progressing, etc.)

Examples:
  - feat-039: VirtualMachine missing Ready condition
  - feat-041: Snapshot missing Progressing condition
  - feat-042: NetworkPolicy missing Ready condition

Runbook entry:
  Location: .claude/skills/runbooks/api-dev/RUNBOOK.md
  Added: 2025-01-10
```

---

## Viewing Trends

```bash
/trends                     # Current trend summary with alerts
/trends --compare           # Compare current window to previous 30 days
/trends --alerts            # Actionable alerts only
/trends --service compute-api  # Trends for a specific service
```

### Example Output

```
TREND ANALYSIS (30-day window)
═══════════════════════════════════════════════════════════════

ALERTS:
  ⚠️  missing-input-validation is INCREASING (3 → 8 occurrences)
      Action: Review api-dev runbook entry, consider adding to checklist

IMPROVING:
  ✓  incorrect-import-order is DECREASING (15 → 2 occurrences)
      The team is following import conventions more consistently

RESOLVED:
  ✓  missing-finalizer has no occurrences in 30 days
      Consider removing from active monitoring

STABLE:
  •  missing-status-condition (12 occurrences, no change)
  •  missing-error-handling (4 occurrences, no change)
```

Trends highlight patterns that are increasing (need attention) and patterns that are resolving (team improvement to recognize).

---

## Viewing Corrections

```bash
/corrections                          # Recent corrections summary
/corrections --agent api-dev          # Corrections for specific agent
/corrections --type approach_rejection # Corrections of specific type
/corrections --analyze                # Extract patterns from corrections
```

User corrections are logged when agents detect that users are correcting their outputs — either through explicit statements ("that's wrong", "use X instead") or implicit actions (user edits code the agent just wrote).

### Example Output

```
USER CORRECTIONS (last 30 days)
═══════════════════════════════════════════════════════════════

Total: 24 corrections

BY TYPE:
  code_quality         8   (33%)  User fixed bugs or logic errors
  code_completeness    6   (25%)  User added code agent missed
  approach_rejection   4   (17%)  User rejected overall approach
  preference_conflict  3   (12%)  User preferred different pattern
  expectation_mismatch 2   (8%)   Agent did something unexpected
  communication_gap    1   (4%)   Agent misunderstood request

BY AGENT:
  api-dev             12   (50%)
  frontend-dev         7   (29%)
  sre                  3   (12%)
  test-engineer        2   (8%)

TOP INFERRED PATTERNS:
  use-existing-patterns      4 occurrences  (high confidence)
  missing-error-context      3 occurrences  (high confidence)
  scope-creep                2 occurrences  (medium confidence)
```

### Correction Types

| Type | Description |
|:-----|:------------|
| `code_quality` | User fixes bugs, style, or logic errors in agent output |
| `code_completeness` | User adds code the agent missed (error handling, validation) |
| `approach_rejection` | User rejects the overall approach and requests alternative |
| `expectation_mismatch` | Agent did something the user didn't ask for |
| `communication_gap` | Agent misunderstood the request |
| `preference_conflict` | User prefers a different pattern or style |

### Integration with /evolve

When you run `/evolve`, corrections are analyzed alongside review findings and session learnings. Because user corrections carry higher source weight (1.0 for explicit, 0.8 for implicit), patterns from corrections reach the promotion threshold faster than patterns from code review nits.
