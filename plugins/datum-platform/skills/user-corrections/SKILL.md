---
name: user-corrections
description: Captures and learns from direct user corrections to Claude Code's outputs. Complements the code-reviewer-driven learning system with user-driven feedback for continuous improvement.
---

# User Correction Learning

This skill captures and learns from direct user corrections to agent outputs, enabling continuous improvement through user-driven feedback.

## Overview

User corrections are a high-value learning signal. When a user corrects Claude's output, it indicates a gap between expected and actual behavior that should inform future work.

```
User corrects Claude → Agent detects correction → Logs to user-corrections.jsonl
                                                          ↓
                                    /evolve analyzes alongside review-findings
                                                          ↓
                                    High-confidence corrections → runbooks
                                                          ↓
                                    /corrections command for periodic review
```

## Data Flow

```
┌─────────────────────────────────────────────────────────────┐
│                     DATA SOURCES                            │
├─────────────────────────────────────────────────────────────┤
│  .claude/review-findings.jsonl    (code-reviewer output)    │
│  .claude/session-learnings.jsonl  (any agent learnings)     │
│  .claude/user-corrections.jsonl   (user correction signals) │ ← NEW
│  .claude/incidents.jsonl          (production incidents)    │
└─────────────────────────────────────────────────────────────┘
                            │
                            ▼
┌─────────────────────────────────────────────────────────────┐
│                   PATTERN ANALYSIS                          │
├─────────────────────────────────────────────────────────────┤
│  Pattern extraction    → Group similar corrections          │
│  Source weighting      → Weight by correction source        │
│  Frequency counting    → Track occurrences over time        │
│  Confidence scoring    → Combine all signals                │
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

## Correction Types

| Type | Definition | Example |
|------|------------|---------|
| `code_quality` | User fixes bugs, style, or logic | User fixes off-by-one error Claude introduced |
| `code_completeness` | User adds code Claude missed | User adds error handling Claude skipped |
| `approach_rejection` | User rejects overall approach | "Let's try a different approach" |
| `expectation_mismatch` | Claude did something unexpected | "I didn't ask for that" |
| `communication_gap` | Claude misunderstood request | User rephrases same request |
| `preference_conflict` | User prefers different pattern | "I prefer X over Y" |

## Commands

| Command | Description |
|---------|-------------|
| `/corrections` | Show recent corrections summary |
| `/corrections --agent <name>` | Filter by agent |
| `/corrections --type <type>` | Filter by correction type |
| `/corrections --analyze` | Run pattern extraction |
| `/evolve` | Analyze corrections alongside findings |

## Source Weighting

Corrections are weighted differently based on source quality:

| Source | Weight | Rationale |
|--------|--------|-----------|
| Explicit user correction | 1.0 | Direct feedback, highest confidence |
| Implicit user correction | 0.8 | User action indicates issue |
| Blocking review finding | 0.7 | Code reviewer found issue |
| Warning review finding | 0.5 | Less severe but notable |
| Session learning | 0.4 | Agent self-observation |
| Nit review finding | 0.3 | Minor conventions |

These weights apply to the `source_quality_score` component of confidence calculation.

## Integration with Agents

### During Session Work

Agents detect corrections in real-time:

```markdown
## Correction Detection

When a user corrects your output:
1. Detect explicit signals ("wrong", "no", "actually...")
2. Detect implicit signals (user edits your code, re-requests differently)
3. Log correction to `.claude/user-corrections.jsonl`
4. Continue with corrected approach
```

### During Context Discovery

Agents check for patterns from corrections:

```markdown
## Context Discovery

...
N. Read `.claude/patterns/patterns.json` for known patterns
N+1. Note patterns with high correction-based confidence
N+2. Apply lessons from user corrections to current work
```

## Session Learning Integration

User corrections feed into the same learning engine as review findings:

1. **Raw correction** → `.claude/user-corrections.jsonl`
2. **Pattern extraction** → `/evolve` groups similar corrections
3. **Confidence scoring** → Weighted by source quality
4. **Runbook promotion** → High-confidence patterns added to runbooks

## Files

| File | Purpose |
|------|---------|
| `SKILL.md` | This overview |
| `schemas.md` | JSON schema for user-corrections.jsonl |
| `detection.md` | How agents detect and log corrections |

## Related Skills

- `learning-engine` — Pattern analysis and runbook promotion
- `runbooks` — Where learned patterns are stored
