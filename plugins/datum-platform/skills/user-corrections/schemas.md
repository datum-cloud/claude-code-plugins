# User Corrections Schema

JSON schema for user correction data files.

## User Corrections Schema

File: `.claude/user-corrections.jsonl`

Each line is a JSON object representing a user correction:

```json
{
  "date": "2025-01-15",
  "timestamp": "2025-01-15T10:30:00Z",
  "agent": "api-dev",
  "session_id": "uuid-for-session-grouping",
  "correction_type": "code_quality",
  "ai_action": {
    "summary": "What Claude did",
    "tool_used": "Write",
    "file": "pkg/registry/snapshot/storage.go:42"
  },
  "user_correction": {
    "summary": "What user changed/said",
    "verbatim": "Exact user text if explicit feedback"
  },
  "pattern_inferred": "missing-error-handling",
  "pattern_confidence": "high",
  "context": {
    "task": "Implementing snapshot storage backend",
    "feature_id": "feat-042",
    "service": "compute-api"
  },
  "severity": "medium",
  "source": "explicit"
}
```

## Required Fields

| Field | Type | Description |
|-------|------|-------------|
| `date` | string | ISO date (YYYY-MM-DD) |
| `timestamp` | string | Full ISO-8601 timestamp |
| `agent` | string | Agent that was corrected (api-dev, frontend-dev, etc.) |
| `correction_type` | enum | Type of correction (see below) |
| `ai_action` | object | What Claude did that was corrected |
| `user_correction` | object | What the user changed or said |
| `source` | enum | `explicit` or `implicit` |

## Optional Fields

| Field | Type | Description |
|-------|------|-------------|
| `session_id` | string | UUID for grouping corrections in same session (use `uuidgen` or equivalent) |
| `pattern_inferred` | string | Pattern identifier (kebab-case) |
| `pattern_confidence` | enum | `high`, `medium`, or `low` |
| `context` | object | Additional context about the work |
| `severity` | enum | `high`, `medium`, or `low` |

## Field Details

### `correction_type` Values

| Value | Description | Detection Source |
|-------|-------------|------------------|
| `code_quality` | User fixes bugs, style, logic errors | Implicit: user edits code |
| `code_completeness` | User adds code Claude missed | Implicit: user extends code |
| `approach_rejection` | User rejects overall approach | Explicit: "let's try X instead" |
| `expectation_mismatch` | Claude did something unexpected | Explicit: "I didn't ask for that" |
| `communication_gap` | Claude misunderstood request | User rephrases same request |
| `preference_conflict` | User prefers different pattern | Explicit: "I prefer X over Y" |

### `ai_action` Object

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `summary` | string | Yes | Brief description of what Claude did |
| `tool_used` | string | No | Tool name (Write, Edit, Bash, etc.) |
| `file` | string | No | File path with optional line number |

### `user_correction` Object

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `summary` | string | Yes | Brief description of what user changed/said |
| `verbatim` | string | No | Exact user text for explicit feedback |

### `context` Object

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `task` | string | No | What was being worked on |
| `feature_id` | string | No | Feature ID if pipeline work (feat-XXX) |
| `service` | string | No | Service name |

### `source` Values

| Value | Description | Weight Multiplier |
|-------|-------------|-------------------|
| `explicit` | User directly stated correction | 1.0 (full weight) |
| `implicit` | Correction inferred from user action | 0.8 (reduced weight) |

### `severity` Values

| Value | Score | Description |
|-------|-------|-------------|
| `high` | 1.0 | Blocked progress, caused errors, significant rework |
| `medium` | 0.6 | Required user intervention but not blocking |
| `low` | 0.3 | Minor adjustment, preference-based |

## Pattern Naming Conventions

Use kebab-case identifiers that are:
- Descriptive: `missing-error-handling` not `meh`
- Consistent: Same correction type = same pattern name
- Reusable: Generic enough to apply to similar corrections

```
Good:  missing-error-handling, use-existing-patterns, scope-creep
Bad:   missingErrorHandling, MissingErrorHandling, MISSING_ERROR_HANDLING
```

### Common Correction Patterns

| Pattern | Correction Type | Description |
|---------|-----------------|-------------|
| `missing-error-handling` | code_completeness | Claude skipped error handling |
| `overly-complex-solution` | approach_rejection | User wanted simpler approach |
| `wrong-api-usage` | code_quality | Claude used API incorrectly |
| `missing-validation` | code_completeness | Claude skipped input validation |
| `style-mismatch` | preference_conflict | User prefers different style |
| `scope-creep` | expectation_mismatch | Claude did more than asked |
| `incomplete-implementation` | code_completeness | Claude stopped before done |
| `misunderstood-requirement` | communication_gap | Claude solved wrong problem |

## Example Corrections

### Explicit Correction (High Confidence)

```json
{
  "date": "2025-01-15",
  "timestamp": "2025-01-15T10:30:00Z",
  "agent": "api-dev",
  "session_id": "abc123",
  "correction_type": "approach_rejection",
  "ai_action": {
    "summary": "Implemented storage using direct SQL queries",
    "tool_used": "Write",
    "file": "pkg/registry/snapshot/storage.go"
  },
  "user_correction": {
    "summary": "User requested using the existing storage interface pattern",
    "verbatim": "Let's use the storage interface pattern like the other resources instead"
  },
  "pattern_inferred": "use-existing-patterns",
  "pattern_confidence": "high",
  "context": {
    "task": "Implementing snapshot storage",
    "feature_id": "feat-042",
    "service": "compute-api"
  },
  "severity": "high",
  "source": "explicit"
}
```

### Implicit Correction (Medium Confidence)

```json
{
  "date": "2025-01-15",
  "timestamp": "2025-01-15T11:45:00Z",
  "agent": "api-dev",
  "session_id": "abc123",
  "correction_type": "code_completeness",
  "ai_action": {
    "summary": "Implemented Create method without error wrapping",
    "tool_used": "Write",
    "file": "pkg/registry/snapshot/storage.go:67"
  },
  "user_correction": {
    "summary": "User added error context wrapping to all error returns"
  },
  "pattern_inferred": "missing-error-context",
  "pattern_confidence": "medium",
  "context": {
    "task": "Implementing snapshot storage",
    "service": "compute-api"
  },
  "severity": "medium",
  "source": "implicit"
}
```

## Directory Structure

```
.claude/
├── review-findings.jsonl        # Code reviewer findings
├── session-learnings.jsonl      # Agent-contributed learnings
├── user-corrections.jsonl       # User correction signals    ← NEW
├── incidents.jsonl              # Production incidents
└── patterns/
    ├── patterns.json            # Pattern registry (includes correction-sourced patterns)
    ├── trends.json              # Trend analysis
    └── promotion-log.jsonl      # Promotion history
```

## Validation

Before writing to `.claude/user-corrections.jsonl`:

1. Validate JSON structure matches schema
2. Ensure required fields are present
3. Validate enum values are allowed:
   - `correction_type`: code_quality, code_completeness, approach_rejection, expectation_mismatch, communication_gap, preference_conflict
   - `source`: explicit, implicit
   - `severity`: high, medium, low
   - `pattern_confidence`: high, medium, low
4. Check date formats are ISO-8601
5. Ensure pattern names are kebab-case
