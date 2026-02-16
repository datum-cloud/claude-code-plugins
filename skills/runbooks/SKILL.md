# Runbooks

This skill explains the runbook system for accumulating learnings.

## Overview

Each agent has a companion runbook that accumulates learnings from past features:
- Patterns that worked
- Anti-patterns discovered
- Common mistakes
- Service-specific guidance

## Location

Runbooks live in service repositories:

```
.claude/skills/runbooks/
├── product-discovery/
│   └── RUNBOOK.md
├── api-dev/
│   └── RUNBOOK.md
├── code-reviewer/
│   └── RUNBOOK.md
└── ...
```

## Runbook Structure

```markdown
# [Agent Name] Runbook

Last updated: YYYY-MM-DD

## Patterns That Work

### [Pattern Name]

**Context**: When to use this pattern

**Pattern**: What to do

**Example**:
```go
// Code example
```

**Learned from**: [Feature/PR reference]

## Anti-Patterns

### [Anti-Pattern Name]

**Problem**: What went wrong

**Why it's bad**: Impact

**Instead**: What to do instead

**Learned from**: [Feature/PR reference]

## Service-Specific Notes

### [Topic]

[Service-specific guidance for this agent's work]

## Common Mistakes

- [Mistake 1]: [How to avoid]
- [Mistake 2]: [How to avoid]
```

## Updating Runbooks

After completing a feature or resolving an issue:

1. Identify reusable learnings
2. Categorize (pattern, anti-pattern, note)
3. Document with context
4. Reference the source (PR, issue)

## Agent Integration

Agents read their runbook during context discovery:

```markdown
## Context Discovery

...
5. Read your runbook at `.claude/skills/runbooks/{agent-name}/RUNBOOK.md` if it exists
```

## Review Finding Integration

The code-reviewer appends findings to `.claude/review-findings.jsonl`. These findings should be periodically reviewed and promoted to runbook entries.

## Cross-Agent Learning

Some learnings apply to multiple agents. These should be:
1. Documented in each relevant runbook
2. OR extracted to a shared skill

## Example Entry

```markdown
### Use sync.Once for Storage Initialization

**Context**: When creating REST storage handlers

**Pattern**: Use sync.Once to lazily initialize storage backends

**Example**:
```go
type REST struct {
    store     storage.Interface
    storeOnce sync.Once
}

func (r *REST) getStore() storage.Interface {
    r.storeOnce.Do(func() {
        r.store = newStorageBackend()
    })
    return r.store
}
```

**Learned from**: PR #123 - Race condition in storage initialization
```
