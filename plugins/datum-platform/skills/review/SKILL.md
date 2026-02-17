---
name: review
description: >
  Invoke code review on the current branch or a specific feature. Runs the
  code-reviewer agent with appropriate context from the pipeline.
tools: Read, Grep, Glob, Bash
model: sonnet
disable-model-invocation: true
context: fork
agent: general-purpose
argument-hint: "[feature-id|--diff <base>]"
---

# Review Command

Quick-start code review with automatic context loading from the pipeline.

## Usage

```
/review                     Review current branch changes
/review <feature-id>        Review changes for a specific feature
/review --diff <base>       Review diff against a specific base branch
```

## Arguments

Feature ID or diff options: $ARGUMENTS

## Workflow

### `/review` (current branch)

1. **Detect context**
   - Run `git branch --show-current` to get branch name
   - Parse feature ID from branch name if present (e.g., `feat-042-vm-snapshots`)
   - Fall back to reviewing all uncommitted changes

2. **Load pipeline context** (if feature ID found)
   - Read design artifact: `.claude/pipeline/designs/{id}.md`
   - Read spec artifact: `.claude/pipeline/specs/{id}.md`
   - Load service profile: `.claude/service-profile.md`

3. **Invoke code-reviewer agent**
   - Pass design context for architecture validation
   - Pass diff of changes to review
   - Agent produces findings and logs to `.claude/review-findings.jsonl`

### `/review <feature-id>`

1. **Load pipeline context**
   - Read all artifacts for the feature
   - Identify expected changes from design

2. **Determine review scope**
   - Find commits associated with this feature
   - Or review all changes since design was written

3. **Invoke code-reviewer agent**

### `/review --diff <base>`

1. **Generate diff**
   - Run `git diff <base>...HEAD`

2. **Invoke code-reviewer agent**
   - Review without pipeline context
   - General code quality review

## Review Context Template

When invoking code-reviewer, provide this context:

```markdown
## Review Context

**Feature**: {id} - {name}
**Branch**: {branch-name}
**Design**: .claude/pipeline/designs/{id}.md
**Spec**: .claude/pipeline/specs/{id}.md

### Expected Changes (from design)

{Summary of expected changes from design artifact}

### Actual Changes

{Git diff or changed file list}

### Platform Integrations Expected

{From service profile: quota, insights, telemetry, activity requirements}
```

## Output

```
Review started for: feat-042-vm-snapshot-management
Branch: feat-042-vm-snapshots
Design context loaded: .claude/pipeline/designs/feat-042-vm-snapshot-management.md

[Invokes code-reviewer agent]

Review complete.
Findings logged to: .claude/review-findings.jsonl
Summary:
  - Blocking: 0
  - Warning: 2
  - Nit: 5

To approve: /pipeline approve feat-042 review
```

## Integration with Pipeline

After review completes:
- If no blocking findings: Ready for `/pipeline approve <id> review`
- If blocking findings: Must resolve before approval
- Findings are logged for pattern analysis

## Error Handling

**No changes to review:**
```
No changes detected on current branch.
Use /review --diff <base> to specify a comparison base.
```

**Feature not found:**
```
Feature feat-042 not found in pipeline.
Proceeding with general code review (no design context).
```
