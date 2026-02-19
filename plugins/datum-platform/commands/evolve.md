---
name: evolve
description: >
  Analyze review findings and session learnings to extract patterns, update
  the pattern registry, and automatically promote high-confidence patterns
  to agent runbooks. Run periodically to keep runbooks current.
tools: Read, Write, Edit, Grep, Glob, Bash
model: opus
disable-model-invocation: true
context: fork
agent: general-purpose
argument-hint: "[--dry-run|--since <days>|--pattern <name>|--agent <name>]"
---

# Evolve Command

Extracts patterns from accumulated findings and evolves agent runbooks with learned knowledge.

## Usage

```
/evolve                    Full analysis and promotion
/evolve --dry-run          Show what would be promoted without making changes
/evolve --since <days>     Only analyze findings from last N days
/evolve --pattern <name>   Analyze specific pattern only
/evolve --agent <name>     Only update runbooks for specific agent
```

## Workflow

### Phase 1: Data Collection

1. **Load review findings**
   ```bash
   # Read all findings
   cat .claude/review-findings.jsonl
   ```

2. **Load session learnings**
   ```bash
   # Read agent-contributed learnings
   cat .claude/session-learnings.jsonl
   ```

3. **Load user corrections**
   ```bash
   # Read user correction signals
   cat .claude/user-corrections.jsonl
   ```

4. **Load existing pattern registry**
   ```bash
   cat .claude/patterns/patterns.json
   ```

### Phase 2: Pattern Analysis

For each finding and correction:

1. **Assign source type and weight**
   - User corrections (explicit): weight 1.0
   - User corrections (implicit): weight 0.8
   - Review findings (blocking): weight 0.7
   - Review findings (warning): weight 0.5
   - Session learnings: weight 0.4
   - Review findings (nit): weight 0.3

2. **Extract or infer pattern name**
   - Use explicit `pattern` or `pattern_inferred` field if present
   - Otherwise infer from description keywords:
     - "missing validation" → `unvalidated-input`
     - "race condition" → `concurrency-race`
     - "status condition" → `missing-status-condition`
     - "nil pointer" → `nil-dereference`
     - "hardcoded" → `hardcoded-value`
   - For corrections, also infer from correction type:
     - `approach_rejection` → check for pattern keywords
     - `code_completeness` → "missing-*" patterns
     - `preference_conflict` → convention patterns

3. **Group by pattern and track sources**
   - Count occurrences
   - Track source breakdown (by source type)
   - Track affected services
   - Track affected agents
   - Collect code examples

4. **Calculate confidence score with source weighting**
   ```
   confidence = (
     0.35 * min(count/10, 1.0) +     # Occurrence frequency
     0.25 * severity_score +          # Severity weight
     0.15 * recency_score +           # Recent patterns matter more
     0.10 * consistency_score +       # Cross-service patterns
     0.15 * source_quality_score      # Source reliability weight
   )

   source_quality_score = weighted_avg(source_weights × source_counts)
   ```

5. **Detect trends**
   - Compare current 30-day window to previous 30-day window
   - Flag increasing (50%+ more), decreasing (50%+ fewer), or stable

### Phase 3: Pattern Registry Update

Update `.claude/patterns/patterns.json`:

```json
{
  "patterns": {
    "pattern-name": {
      "name": "pattern-name",
      "description": "What this pattern represents",
      "category": "correctness|security|convention|completeness|performance",
      "severity": "blocking|warning|nit",
      "occurrences": [...],
      "count": 7,
      "first_seen": "2024-11-01",
      "last_seen": "2025-01-15",
      "trend": "stable|increasing|decreasing|new|resolved",
      "confidence": 0.85,
      "source_breakdown": {
        "explicit_user_correction": 2,
        "implicit_user_correction": 1,
        "blocking_review": 3,
        "warning_review": 1
      },
      "source_quality_score": 0.72,
      "affected_agents": ["api-dev", "code-reviewer"],
      "fix_template": "How to fix this issue",
      "promoted_to_runbook": false
    }
  },
  "meta": {
    "last_analysis": "2025-01-15T10:30:00Z",
    "total_findings_analyzed": 142,
    "total_corrections_analyzed": 24,
    "total_patterns": 23
  }
}
```

### Phase 4: Runbook Promotion

For patterns meeting promotion criteria:
- Count >= 3
- Confidence >= 0.6
- Not already promoted

Generate runbook entry:

```markdown
### {Pattern Name} (Auto-generated)

**Confidence**: {score} | **Occurrences**: {count} | **Trend**: {trend}

**Context**: {When this pattern appears}

**Anti-Pattern**: {What to avoid}

**Instead**: {What to do}

**Example**:
```go
{Code example}
```

**Learned from**: {PR references}

*Auto-generated on {date}*
```

Append to `.claude/skills/runbooks/{agent}/RUNBOOK.md` for each affected agent.

### Phase 5: Generate Reports

**Trend alerts** (written to `.claude/patterns/trends.json`):

```json
{
  "alerts": [
    {
      "type": "increasing_pattern",
      "pattern": "unvalidated-input",
      "message": "Input validation issues increased 150% this month"
    }
  ]
}
```

**Cross-service alerts**:
- When pattern from ServiceA likely exists in ServiceB
- Based on similar code structures and dependencies

## Output

```
=== EVOLVE ANALYSIS ===

Data sources analyzed (last 30 days):
  Review findings:    35
  User corrections:   12  (8 explicit, 4 implicit)
  Session learnings:   8

Patterns identified: 12
New patterns: 2
Updated patterns: 8

=== SOURCE QUALITY ===

High-confidence sources (weight >= 0.7):
  Explicit user corrections:  8  (weight 1.0)
  Blocking review findings:  15  (weight 0.7)

Medium-confidence sources (weight 0.4-0.6):
  Implicit user corrections:  4  (weight 0.8)
  Warning review findings:   12  (weight 0.5)
  Session learnings:          8  (weight 0.4)

Low-confidence sources (weight < 0.4):
  Nit review findings:        8  (weight 0.3)

=== PATTERN SUMMARY ===

HIGH CONFIDENCE (>= 0.8):
  missing-status-condition    [12 occurrences] [stable]     → Promoted to: api-dev
  unvalidated-input          [8 occurrences]  [increasing] → Promoted to: api-dev

MEDIUM CONFIDENCE (0.6-0.8):
  storage-init-race          [4 occurrences]  [stable]     → Promoted to: api-dev
  missing-error-context      [3 occurrences]  [new]        → Promoted to: api-dev

LOW CONFIDENCE (< 0.6):
  import-ordering            [2 occurrences]  [stable]     → Tracking only

=== TREND ALERTS ===

⚠️  INCREASING: unvalidated-input (+150% vs last month)
    Consider: Team training on input validation patterns

✅ DECREASING: hardcoded-value (-60% vs last month)
    Team may be improving on this pattern

=== RUNBOOK UPDATES ===

Updated: .claude/skills/runbooks/api-dev/RUNBOOK.md
  + Added: missing-status-condition (anti-pattern)
  + Added: unvalidated-input (anti-pattern)
  + Added: storage-init-race (anti-pattern)

Updated: .claude/skills/runbooks/code-reviewer/RUNBOOK.md
  + Added: missing-status-condition (check priority)
  + Added: unvalidated-input (check priority)

=== CROSS-SERVICE ALERTS ===

⚠️  Pattern 'storage-init-race' found in compute-api
    May also exist in: network-api, storage-api
    Check: pkg/registry/*/storage.go

=== NEXT STEPS ===

1. Review auto-generated runbook entries
2. Address increasing pattern: unvalidated-input
3. Investigate cross-service alert for storage-init-race
```

## Error Handling

**No findings file:**
```
No findings found at .claude/review-findings.jsonl
Run code reviews to generate findings, then try again.
```

**No new patterns:**
```
No new patterns detected since last analysis.
Pattern registry is up to date.
```

## Integration

After `/evolve` completes:
- Agents will read updated runbooks in their next invocation
- Code-reviewer will prioritize high-confidence patterns
- Pattern trends inform team process improvements

## Scheduling

Recommended schedule:
- **After each code review**: Incremental finding capture (automatic)
- **Weekly**: Full `/evolve` analysis
- **Monthly**: Review auto-generated entries for accuracy

## Skills Referenced

- `learning-engine/SKILL.md` — Overview of learning system
- `learning-engine/analysis.md` — Pattern analysis algorithms
- `learning-engine/promotion.md` — Runbook promotion rules
- `user-corrections/SKILL.md` — User correction detection and logging
- `user-corrections/schemas.md` — User corrections data schema
- `runbooks/SKILL.md` — Runbook structure and conventions
