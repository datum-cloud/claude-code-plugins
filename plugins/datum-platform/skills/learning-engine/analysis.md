# Pattern Analysis

Detailed algorithms for extracting and analyzing patterns from findings.

## Pattern Extraction

### Step 1: Load Raw Findings

Read all finding sources:

```bash
# Review findings from code-reviewer
cat .claude/review-findings.jsonl

# Session learnings from any agent
cat .claude/session-learnings.jsonl

# User corrections from all agents
cat .claude/user-corrections.jsonl

# Incident reports (if tracking production issues)
cat .claude/incidents.jsonl
```

### Step 2: Normalize Findings

Convert all findings to a common format:

```json
{
  "id": "unique-id",
  "source": "review|session|incident|correction",
  "source_type": "explicit_user_correction|implicit_user_correction|blocking_review|warning_review|session_learning|nit_review",
  "date": "ISO-8601",
  "agent": "agent-name",
  "service": "service-name",
  "category": "security|correctness|convention|completeness|performance",
  "severity": "blocking|warning|nit",
  "pattern": "pattern-name",
  "file": "file:line",
  "description": "finding description",
  "context": "additional context",
  "pr": "PR number if applicable"
}
```

### Source Type Mapping

Map raw data sources to source types with weights:

| Data Source | Source Type | Weight |
|-------------|-------------|--------|
| user-corrections.jsonl (explicit) | `explicit_user_correction` | 1.0 |
| user-corrections.jsonl (implicit) | `implicit_user_correction` | 0.8 |
| review-findings.jsonl (blocking) | `blocking_review` | 0.7 |
| review-findings.jsonl (warning) | `warning_review` | 0.5 |
| session-learnings.jsonl | `session_learning` | 0.4 |
| review-findings.jsonl (nit) | `nit_review` | 0.3 |

### Step 3: Group by Pattern

Group findings by `pattern` field:

```python
# Pseudocode
patterns = {}
for finding in findings:
    pattern_name = finding.pattern or infer_pattern(finding)
    if pattern_name not in patterns:
        patterns[pattern_name] = {
            "name": pattern_name,
            "occurrences": [],
            "categories": set(),
            "severities": set(),
            "agents": set(),
            "services": set()
        }
    patterns[pattern_name]["occurrences"].append(finding)
    patterns[pattern_name]["categories"].add(finding.category)
    patterns[pattern_name]["severities"].add(finding.severity)
    patterns[pattern_name]["agents"].add(finding.agent)
    patterns[pattern_name]["services"].add(finding.service)
```

### Step 4: Pattern Inference

When findings lack explicit pattern names, infer from:

1. **File path patterns**: `types.go` → type-related patterns
2. **Description keywords**: "missing", "unvalidated", "race condition"
3. **Category + severity**: security + blocking → security vulnerability patterns
4. **Code structure**: Similar AST patterns across findings

Common pattern name conventions:

| Keyword in Finding | Inferred Pattern |
|-------------------|------------------|
| "missing validation" | `unvalidated-input` |
| "missing status" | `missing-status-condition` |
| "race condition" | `concurrency-race` |
| "nil pointer" | `nil-dereference` |
| "error not handled" | `unhandled-error` |
| "hardcoded" | `hardcoded-value` |
| "missing test" | `insufficient-test-coverage` |
| "import order" | `import-ordering` |

## Frequency Analysis

### Time Windows

Analyze patterns across time windows:

```
all_time:     Total occurrences ever
last_90_days: Occurrences in last 90 days
last_30_days: Occurrences in last 30 days
last_7_days:  Occurrences in last 7 days
```

### Trend Calculation

```python
def calculate_trend(occurrences, window_days=30):
    now = datetime.now()
    current_window = [o for o in occurrences
                      if (now - o.date).days <= window_days]
    previous_window = [o for o in occurrences
                       if window_days < (now - o.date).days <= window_days * 2]

    current_count = len(current_window)
    previous_count = len(previous_window)

    if previous_count == 0:
        return "new" if current_count > 0 else "none"

    if current_count == 0:
        return "resolved"

    ratio = current_count / previous_count

    if ratio >= 1.5:
        return "increasing"
    elif ratio <= 0.5:
        return "decreasing"
    else:
        return "stable"
```

### Severity Distribution

Track severity distribution per pattern:

```json
{
  "severity_distribution": {
    "blocking": 5,
    "warning": 12,
    "nit": 3
  },
  "dominant_severity": "warning",
  "severity_score": 0.65
}
```

## Confidence Scoring

### Algorithm

```python
def calculate_confidence(pattern):
    # Occurrence score: more occurrences = higher confidence
    # Caps at 10 occurrences (score of 1.0)
    occurrence_score = min(pattern.count / 10, 1.0)

    # Severity score: based on dominant severity
    severity_scores = {"blocking": 1.0, "warning": 0.6, "nit": 0.3}
    severity_score = severity_scores[pattern.dominant_severity]

    # Recency score: patterns seen recently are more relevant
    days_since_last = (now - pattern.last_seen).days
    recency_score = max(0, 1.0 - (days_since_last / 90))

    # Consistency score: patterns across multiple services are more significant
    service_count = len(pattern.services)
    consistency_score = min(service_count / 3, 1.0)

    # Source quality score: weight by data source reliability
    source_quality_score = calculate_source_quality(pattern)

    # Weighted average with source quality
    confidence = (
        0.35 * occurrence_score +
        0.25 * severity_score +
        0.15 * recency_score +
        0.10 * consistency_score +
        0.15 * source_quality_score
    )

    return round(confidence, 2)


def calculate_source_quality(pattern):
    """Calculate weighted average of source quality across occurrences."""
    source_weights = {
        "explicit_user_correction": 1.0,
        "implicit_user_correction": 0.8,
        "blocking_review": 0.7,
        "warning_review": 0.5,
        "session_learning": 0.4,
        "nit_review": 0.3
    }

    total_weight = 0
    weighted_sum = 0

    for source_type, count in pattern.source_breakdown.items():
        weight = source_weights.get(source_type, 0.5)
        weighted_sum += weight * count
        total_weight += count

    if total_weight == 0:
        return 0.5  # Default for patterns without source tracking

    return weighted_sum / total_weight
```

### Source Quality Weights

User corrections receive the highest weight because they represent direct feedback:

| Source Type | Weight | Rationale |
|-------------|--------|-----------|
| `explicit_user_correction` | 1.0 | User directly corrected Claude |
| `implicit_user_correction` | 0.8 | User action implies correction |
| `blocking_review` | 0.7 | Reviewer identified blocking issue |
| `warning_review` | 0.5 | Reviewer identified notable issue |
| `session_learning` | 0.4 | Agent self-observed pattern |
| `nit_review` | 0.3 | Minor convention finding |

### Confidence Thresholds

| Confidence | Interpretation | Action |
|------------|----------------|--------|
| 0.8 - 1.0 | High confidence | Auto-promote to runbook, prioritize in reviews |
| 0.6 - 0.8 | Medium confidence | Promote to runbook draft, suggest in reviews |
| 0.4 - 0.6 | Low confidence | Track, don't promote yet |
| 0.0 - 0.4 | Very low | May be noise, continue tracking |

## Correction Merging

User corrections are merged with review findings during pattern analysis:

### Merging Algorithm

```python
def merge_corrections_with_findings(findings, corrections):
    """Merge user corrections into the findings stream."""
    merged = []

    # Add all findings with source type
    for finding in findings:
        finding["source_type"] = map_finding_source_type(finding)
        merged.append(finding)

    # Convert corrections to finding format
    for correction in corrections:
        merged.append({
            "id": f"correction-{correction.timestamp}",
            "source": "correction",
            "source_type": f"{correction.source}_user_correction",
            "date": correction.date,
            "agent": correction.agent,
            "service": correction.context.get("service"),
            "category": map_correction_category(correction.correction_type),
            "severity": correction.severity,
            "pattern": correction.pattern_inferred,
            "file": correction.ai_action.get("file"),
            "description": correction.user_correction.summary,
            "context": correction.context.get("task")
        })

    return merged


def map_correction_category(correction_type):
    """Map correction types to pattern categories."""
    mapping = {
        "code_quality": "correctness",
        "code_completeness": "completeness",
        "approach_rejection": "convention",
        "expectation_mismatch": "convention",
        "communication_gap": "convention",
        "preference_conflict": "convention"
    }
    return mapping.get(correction_type, "convention")
```

### Pattern Matching Across Sources

When the same pattern appears in both corrections and findings:

1. **Combine occurrences** — Merge occurrence lists
2. **Track source breakdown** — Count by source type
3. **Boost confidence** — Patterns from multiple sources are more reliable
4. **Prefer user wording** — Use correction descriptions when clearer

```python
def combine_pattern_sources(pattern_from_findings, pattern_from_corrections):
    """Combine patterns found in both sources."""
    combined = pattern_from_findings.copy()

    # Merge occurrences
    combined["occurrences"].extend(pattern_from_corrections["occurrences"])
    combined["count"] = len(combined["occurrences"])

    # Update source breakdown
    for source_type, count in pattern_from_corrections["source_breakdown"].items():
        combined["source_breakdown"][source_type] = (
            combined["source_breakdown"].get(source_type, 0) + count
        )

    # Use correction description if more specific
    if len(pattern_from_corrections["description"]) > len(combined["description"]):
        combined["description"] = pattern_from_corrections["description"]

    # Recalculate confidence with updated data
    combined["confidence"] = calculate_confidence(combined)
    combined["source_quality_score"] = calculate_source_quality(combined)

    return combined
```

## Cross-Service Analysis

### Service Similarity

Calculate which services are likely to share patterns:

```python
def service_similarity(service_a, service_b):
    # Shared patterns
    shared_patterns = patterns_in(service_a) & patterns_in(service_b)

    # Shared dependencies (from go.mod, package.json, etc.)
    shared_deps = dependencies_of(service_a) & dependencies_of(service_b)

    # Similar file structures
    structure_similarity = compare_file_trees(service_a, service_b)

    return weighted_average(
        len(shared_patterns) / max_patterns,
        len(shared_deps) / max_deps,
        structure_similarity
    )
```

### Pattern Propagation Alerts

When a pattern is found in ServiceA, check ServiceB:

```python
def check_pattern_propagation(pattern, source_service):
    similar_services = get_similar_services(source_service)

    alerts = []
    for service in similar_services:
        if has_similar_code_structure(service, pattern):
            if pattern not in patterns_found_in(service):
                alerts.append({
                    "service": service,
                    "pattern": pattern,
                    "reason": f"Pattern '{pattern.name}' found in {source_service} may exist here",
                    "check_files": get_similar_files(service, pattern)
                })

    return alerts
```

## Output Generation

### Pattern Registry Update

After analysis, update `.claude/patterns/patterns.json`:

```python
def update_pattern_registry(patterns):
    registry = load_existing_registry()

    for pattern in patterns:
        if pattern.name in registry["patterns"]:
            # Update existing pattern
            existing = registry["patterns"][pattern.name]
            existing["occurrences"].extend(pattern.new_occurrences)
            existing["count"] = len(existing["occurrences"])
            existing["last_seen"] = pattern.last_seen
            existing["trend"] = calculate_trend(existing["occurrences"])
            existing["confidence"] = calculate_confidence(existing)
        else:
            # Add new pattern
            registry["patterns"][pattern.name] = pattern.to_dict()

    registry["meta"]["last_analysis"] = now()
    registry["meta"]["total_findings_analyzed"] += len(new_findings)

    save_registry(registry)
```

### Trend Report Generation

Generate `.claude/patterns/trends.json`:

```json
{
  "generated": "2025-01-15T10:30:00Z",
  "window": "30_days",
  "summary": {
    "total_patterns": 23,
    "increasing": 3,
    "decreasing": 5,
    "stable": 12,
    "new": 2,
    "resolved": 1
  },
  "alerts": [
    {
      "type": "increasing_pattern",
      "pattern": "unvalidated-input",
      "previous_count": 2,
      "current_count": 5,
      "message": "Input validation issues increasing - consider team training"
    },
    {
      "type": "cross_service",
      "pattern": "storage-init-race",
      "source_service": "compute-api",
      "target_service": "network-api",
      "message": "Pattern from compute-api may exist in network-api"
    }
  ],
  "top_patterns": [
    {"name": "missing-status-condition", "count": 12, "trend": "stable"},
    {"name": "unvalidated-input", "count": 8, "trend": "increasing"},
    {"name": "hardcoded-value", "count": 6, "trend": "decreasing"}
  ]
}
```
