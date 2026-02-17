# Learning Engine Schemas

JSON schemas for all learning engine data files.

## Review Findings Schema

File: `.claude/review-findings.jsonl`

Each line is a JSON object:

```json
{
  "date": "2025-01-15",
  "pr": "123",
  "service": "compute-api",
  "category": "security|correctness|convention|completeness|performance",
  "file": "pkg/registry/snapshot/strategy.go:42",
  "finding": "Missing input validation on snapshot name field",
  "severity": "blocking|warning|nit",
  "pattern": "unvalidated-input",
  "context": "Optional additional context about the finding",
  "suggested_fix": "Add validation using apimachineryvalidation.NameIsDNSSubdomain"
}
```

### Required Fields

| Field | Type | Description |
|-------|------|-------------|
| `date` | string | ISO date (YYYY-MM-DD) |
| `category` | enum | One of: security, correctness, convention, completeness, performance |
| `file` | string | File path with optional line number |
| `finding` | string | Description of the finding |
| `severity` | enum | One of: blocking, warning, nit |

### Optional Fields

| Field | Type | Description |
|-------|------|-------------|
| `pr` | string | Pull request number |
| `service` | string | Service name (inferred from repo if not provided) |
| `pattern` | string | Pattern identifier (snake_case) |
| `context` | string | Additional context |
| `suggested_fix` | string | How to fix the issue |

### Pattern Naming Conventions

Use snake_case identifiers that are:
- Descriptive: `missing-status-condition` not `msc`
- Consistent: Same pattern = same name across findings
- Reusable: Generic enough to apply to similar issues

Common patterns:

| Pattern | Use When |
|---------|----------|
| `unvalidated-input` | Missing input validation |
| `missing-status-condition` | Status conditions not updated |
| `concurrency-race` | Race condition detected |
| `nil-dereference` | Potential nil pointer |
| `unhandled-error` | Error not checked or handled |
| `hardcoded-value` | Magic numbers or hardcoded strings |
| `missing-test-coverage` | Insufficient test coverage |
| `import-ordering` | Import groups not ordered correctly |
| `missing-error-context` | Errors without context wrapping |
| `tenant-isolation-gap` | Multi-tenant isolation issue |
| `storage-init-race` | Storage initialization race |
| `missing-deepcopy-tag` | Kubernetes types missing deepcopy |

## Session Learnings Schema

File: `.claude/session-learnings.jsonl`

Each line is a JSON object:

```json
{
  "date": "2025-01-15",
  "agent": "api-dev",
  "feature_id": "feat-042",
  "type": "pattern|anti-pattern|tip",
  "name": "use-sync-once-for-storage",
  "description": "Use sync.Once for lazy storage initialization to avoid race conditions",
  "context": "Discovered while implementing snapshot storage backend",
  "code_example": "func (r *REST) getStore() storage.Interface {\n  r.storeOnce.Do(func() { r.store = newBackend() })\n  return r.store\n}",
  "confidence": "high|medium|low",
  "applicable_to": ["api-dev", "test-engineer"],
  "source_file": "pkg/registry/snapshot/storage.go"
}
```

### Required Fields

| Field | Type | Description |
|-------|------|-------------|
| `date` | string | ISO date (YYYY-MM-DD) |
| `agent` | string | Agent that contributed this learning |
| `type` | enum | pattern, anti-pattern, or tip |
| `name` | string | Identifier for this learning (kebab-case) |
| `description` | string | What was learned |

### Optional Fields

| Field | Type | Description |
|-------|------|-------------|
| `feature_id` | string | Feature ID if from pipeline work |
| `context` | string | When/where this was discovered |
| `code_example` | string | Code demonstrating the learning |
| `confidence` | enum | high, medium, low |
| `applicable_to` | array | Agents that should learn this |
| `source_file` | string | File where learning originated |

## Pattern Registry Schema

File: `.claude/patterns/patterns.json`

```json
{
  "patterns": {
    "pattern-name": {
      "name": "pattern-name",
      "description": "Human-readable description of the pattern",
      "category": "security|correctness|convention|completeness|performance",
      "severity": "blocking|warning|nit",
      "occurrences": [
        {
          "date": "2025-01-15",
          "service": "compute-api",
          "file": "pkg/apis/vm/v1alpha1/types.go:142",
          "pr": "234",
          "context": "VM resource missing Ready condition"
        }
      ],
      "count": 12,
      "first_seen": "2024-11-01",
      "last_seen": "2025-01-15",
      "trend": "stable|increasing|decreasing|new|resolved",
      "confidence": 0.85,
      "affected_agents": ["api-dev", "code-reviewer"],
      "affected_services": ["compute-api", "network-api"],
      "fix_template": "Add status condition update:\nmeta.SetStatusCondition(...)",
      "promoted_to_runbook": true,
      "runbook_agents": ["api-dev"],
      "promoted_date": "2024-12-15"
    }
  },
  "meta": {
    "last_analysis": "2025-01-15T10:30:00Z",
    "total_findings_analyzed": 142,
    "total_patterns": 23,
    "services_analyzed": ["compute-api", "network-api", "storage-api"],
    "analysis_window_days": 30
  }
}
```

### Pattern Object Fields

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `name` | string | Yes | Pattern identifier |
| `description` | string | Yes | What this pattern represents |
| `category` | enum | Yes | Pattern category |
| `severity` | enum | Yes | Dominant severity |
| `occurrences` | array | Yes | Individual occurrence records |
| `count` | integer | Yes | Total occurrence count |
| `first_seen` | string | Yes | Date first detected |
| `last_seen` | string | Yes | Date most recently seen |
| `trend` | enum | Yes | Current trend |
| `confidence` | number | Yes | Confidence score (0.0-1.0) |
| `affected_agents` | array | Yes | Agents involved |
| `affected_services` | array | No | Services affected |
| `fix_template` | string | No | How to fix |
| `promoted_to_runbook` | boolean | No | Whether promoted |
| `runbook_agents` | array | No | Agents with runbook entry |
| `promoted_date` | string | No | When promoted |

## Trends Schema

File: `.claude/patterns/trends.json`

```json
{
  "generated": "2025-01-15T10:30:00Z",
  "window_days": 30,
  "current_window": {
    "start": "2024-12-16",
    "end": "2025-01-15"
  },
  "previous_window": {
    "start": "2024-11-16",
    "end": "2024-12-15"
  },
  "summary": {
    "total_patterns": 23,
    "total_findings_current": 35,
    "total_findings_previous": 28,
    "change_percent": 25,
    "by_trend": {
      "increasing": 3,
      "decreasing": 5,
      "stable": 12,
      "new": 2,
      "resolved": 1
    },
    "by_severity": {
      "blocking": 18,
      "warning": 12,
      "nit": 5
    }
  },
  "alerts": [
    {
      "type": "increasing_pattern|new_pattern|cross_service|threshold_exceeded",
      "severity": "high|medium|low",
      "pattern": "unvalidated-input",
      "previous_count": 2,
      "current_count": 5,
      "change_percent": 150,
      "message": "Input validation issues increasing significantly",
      "recommended_action": "Review api-dev runbook, consider team training"
    }
  ],
  "top_patterns": [
    {
      "name": "missing-status-condition",
      "count": 12,
      "trend": "stable",
      "confidence": 0.85
    }
  ],
  "service_breakdown": {
    "compute-api": {
      "total_findings": 15,
      "blocking": 8,
      "top_pattern": "missing-status-condition"
    }
  },
  "improvements": [
    {
      "pattern": "hardcoded-value",
      "previous_count": 5,
      "current_count": 2,
      "change_percent": -60,
      "message": "Team improving on avoiding hardcoded values"
    }
  ]
}
```

## Promotion Log Schema

File: `.claude/patterns/promotion-log.jsonl`

```json
{
  "date": "2025-01-15T10:30:00Z",
  "pattern": "missing-status-condition",
  "confidence": 0.85,
  "occurrences": 7,
  "promoted_to": ["api-dev", "code-reviewer"],
  "entry_type": "anti-pattern|pattern|tip",
  "trigger": "evolve_command|threshold|manual",
  "runbook_section": "## Anti-Patterns"
}
```

## Directory Structure

```
.claude/
├── review-findings.jsonl        # Code reviewer findings
├── session-learnings.jsonl      # Agent-contributed learnings
├── patterns/
│   ├── patterns.json            # Pattern registry
│   ├── trends.json              # Trend analysis
│   └── promotion-log.jsonl      # Promotion history
└── skills/
    └── runbooks/
        ├── api-dev/
        │   └── RUNBOOK.md       # Auto-updated
        ├── code-reviewer/
        │   └── RUNBOOK.md       # Auto-updated
        └── ...
```

## Validation

Before writing to any learning engine file:

1. Validate JSON structure matches schema
2. Ensure required fields are present
3. Validate enum values are allowed
4. Check date formats are ISO-8601
5. Ensure pattern names are kebab-case
6. Verify confidence scores are 0.0-1.0
