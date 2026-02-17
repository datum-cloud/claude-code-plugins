# Learning Engine

This skill provides automatic pattern extraction and knowledge accumulation from review findings, session learnings, and cross-service insights.

## Overview

The learning engine transforms raw findings into reusable knowledge:

```
findings → pattern detection → frequency analysis → confidence scoring → runbook updates
```

## Data Flow

```
┌─────────────────────────────────────────────────────────────┐
│                     DATA SOURCES                            │
├─────────────────────────────────────────────────────────────┤
│  .claude/review-findings.jsonl    (code-reviewer output)    │
│  .claude/session-learnings.jsonl  (any agent learnings)     │
│  .claude/incidents.jsonl          (production incidents)    │
└─────────────────────────────────────────────────────────────┘
                            │
                            ▼
┌─────────────────────────────────────────────────────────────┐
│                   PATTERN ANALYSIS                          │
├─────────────────────────────────────────────────────────────┤
│  Pattern extraction    → Group similar findings             │
│  Frequency counting    → Track occurrences over time        │
│  Confidence scoring    → Weight by severity and recurrence  │
│  Trend detection       → Identify increasing/decreasing     │
└─────────────────────────────────────────────────────────────┘
                            │
                            ▼
┌─────────────────────────────────────────────────────────────┐
│                   KNOWLEDGE OUTPUT                          │
├─────────────────────────────────────────────────────────────┤
│  .claude/patterns/patterns.json      (pattern registry)     │
│  .claude/patterns/trends.json        (trend analysis)       │
│  .claude/skills/runbooks/*/RUNBOOK.md (auto-updated)        │
└─────────────────────────────────────────────────────────────┘
```

## Commands

| Command | Description |
|---------|-------------|
| `/evolve` | Analyze findings and update runbooks |
| `/patterns` | Show top patterns with statistics |
| `/trends` | Show pattern trends over time |

## Pattern Schema

Patterns are stored in `.claude/patterns/patterns.json`:

```json
{
  "patterns": {
    "missing-status-condition": {
      "name": "missing-status-condition",
      "description": "Resource types missing status condition updates",
      "category": "correctness",
      "severity": "blocking",
      "occurrences": [
        {
          "date": "2025-01-15",
          "service": "compute-api",
          "file": "pkg/apis/vm/v1alpha1/types.go",
          "pr": "123",
          "context": "VM resource missing Ready condition"
        }
      ],
      "count": 7,
      "first_seen": "2024-11-01",
      "last_seen": "2025-01-15",
      "trend": "stable",
      "confidence": 0.85,
      "affected_agents": ["api-dev", "code-reviewer"],
      "fix_template": "Add status condition update in reconcile loop",
      "promoted_to_runbook": true,
      "runbook_agents": ["api-dev"]
    }
  },
  "meta": {
    "last_analysis": "2025-01-15T10:30:00Z",
    "total_findings_analyzed": 142,
    "total_patterns": 23,
    "services_analyzed": ["compute-api", "network-api", "storage-api"]
  }
}
```

## Confidence Scoring

Pattern confidence is calculated as:

```
confidence = (
  occurrence_weight * min(count / 10, 1.0) +
  severity_weight * severity_score +
  recency_weight * recency_score +
  consistency_weight * consistency_score
) / total_weight

Where:
- occurrence_weight = 0.4 (how often it appears)
- severity_weight = 0.3 (blocking > warning > nit)
- recency_weight = 0.2 (recent patterns weighted higher)
- consistency_weight = 0.1 (appears across multiple services)
```

Severity scores:
- blocking: 1.0
- warning: 0.6
- nit: 0.3

## Auto-Promotion Rules

Patterns are automatically promoted to runbooks when:

1. **Frequency threshold**: Count >= 3 occurrences
2. **Confidence threshold**: Confidence >= 0.6
3. **Actionability**: Has a clear fix template
4. **Not already promoted**: Avoids duplicates

## Trend Detection

Trends are calculated over 30-day windows:

| Trend | Definition |
|-------|------------|
| `increasing` | 50%+ more occurrences than previous window |
| `decreasing` | 50%+ fewer occurrences than previous window |
| `stable` | Within 50% of previous window |
| `new` | First appeared in current window |
| `resolved` | No occurrences in current window after previous activity |

## Cross-Service Pattern Matching

When a pattern is detected in one service, the engine checks other services for:

1. **Similar code structures** - Same file patterns, similar function names
2. **Same dependencies** - Services using same libraries/patterns
3. **Historical correlation** - Patterns that co-occur across services

Alerts are generated when:
- A pattern from ServiceA's history matches code in ServiceB
- A new service adopts patterns that have caused issues elsewhere

## Integration with Agents

### During Context Discovery

Agents load pattern awareness:

```markdown
## Context Discovery

...
N. Read `.claude/patterns/patterns.json` for known patterns
N+1. Check if any high-confidence patterns apply to current work
```

### Pattern-Aware Review

Code-reviewer prioritizes checks based on pattern frequency:

```markdown
## Review Priority

1. Check for patterns with confidence > 0.8 first
2. Run validation scripts for high-frequency patterns
3. Log findings with pattern names for tracking
```

### Learning Feedback Loop

After agent completes work:

```markdown
## Session Learning

If you discovered a reusable insight:
1. Log to `.claude/session-learnings.jsonl`
2. Include context, pattern name, and suggested fix
3. Reference the work that led to the learning
```

## Session Learning Schema

Agents can contribute learnings via `.claude/session-learnings.jsonl`:

```json
{
  "date": "2025-01-15",
  "agent": "api-dev",
  "feature_id": "feat-042",
  "type": "pattern|anti-pattern|tip",
  "name": "use-sync-once-for-storage",
  "description": "Use sync.Once for lazy storage initialization to avoid race conditions",
  "context": "Discovered while implementing snapshot storage",
  "code_example": "func (r *REST) getStore() storage.Interface { r.storeOnce.Do(func() { ... }) }",
  "confidence": "high",
  "applicable_to": ["api-dev", "test-engineer"]
}
```

## Runbook Update Format

When promoting patterns to runbooks, use this format:

```markdown
### [Pattern Name] (Auto-generated)

**Confidence**: [score] | **Occurrences**: [count] | **Last seen**: [date]

**Context**: [When this pattern applies]

**Pattern**: [What to do or avoid]

**Example**:
```[language]
[Code example from findings]
```

**Why this matters**: [Impact description]

**Learned from**: [List of PRs/features]

*This entry was auto-generated by the learning engine on [date]. Review and refine as needed.*
```

## Files

| File | Purpose |
|------|---------|
| `SKILL.md` | This overview |
| `analysis.md` | Pattern analysis algorithms |
| `promotion.md` | Runbook promotion rules |
| `schemas.md` | JSON schemas for data files |
