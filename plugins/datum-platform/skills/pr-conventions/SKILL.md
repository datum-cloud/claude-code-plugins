---
name: pr-conventions
description: Covers pull request description conventions including structure, sections, and content guidelines. Use when creating PRs to ensure consistent, informative descriptions across Datum Cloud repositories.
---

# Pull Request Conventions

This skill covers pull request description conventions for all Datum Cloud repositories.

## Overview

Write PR descriptions for reviewers who need context to understand and evaluate changes. A well-crafted PR description accelerates review, documents decisions, and serves as a reference for future maintainers.

## PR Title

Follow the same format as commit messages:

```
<type>: <subject>
```

Or with scope for larger changes:

```
<type>(<scope>): <subject>
```

| Rule | Guidance |
|------|----------|
| Use type prefix | `feat:`, `fix:`, `docs:`, `refactor:`, `test:`, `chore:` |
| Imperative mood | "Add feature" not "Added feature" |
| Capitalize after colon | Begin with capital letter |
| No period at end | Cleaner appearance |
| Keep concise | Under 72 characters |

## Required Sections

### Summary

Brief description of what changes and why. Use 2-4 bullet points.

```markdown
## Summary

- Adds rate limiting to public API endpoints
- Prevents abuse from automated clients making excessive requests
- Default limits set to 100 req/min, configurable via environment
```

Focus on:
- What problem this solves
- Why this approach was chosen
- Key outcomes or behaviors

### Test Plan

How changes were tested or should be tested. Use a checklist.

```markdown
## Test plan

- [ ] Unit tests pass locally
- [ ] Manual testing of rate limit behavior
- [ ] Verified error responses match API spec
```

For complex changes, include:
- Specific scenarios tested
- Edge cases considered
- Performance implications verified

## Conditional Sections

### Breaking Changes

Required when changes break backward compatibility.

```markdown
## Breaking changes

- `GET /api/users` now requires authentication
- Response format changed from array to paginated object
- Environment variable `API_KEY` renamed to `AUTH_TOKEN`
```

Include:
- What breaks
- Migration path for consumers
- Version implications

### Changes

For complex PRs, provide detailed breakdown.

```markdown
## Changes

- **New**: `RateLimiter` middleware with token bucket algorithm
- **Modified**: `APIHandler` to integrate rate limiting
- **Removed**: Legacy throttling code (unused since v2.1)
```

## Optional Sections

### Related Issues

Link to issues this PR addresses.

```markdown
Closes #123
Fixes #456
Related to #789
```

Use appropriate keywords:
- `Closes` / `Fixes` — automatically closes issue when merged
- `Related to` — references without closing

### Screenshots

For UI changes, include before/after screenshots.

```markdown
## Screenshots

| Before | After |
|--------|-------|
| ![before](url) | ![after](url) |
```

### Notes for Reviewers

Call out areas needing particular attention.

```markdown
## Notes for reviewers

- The caching logic in `cache.go` is the most complex part
- Consider if the error handling in `handler.go:45` is sufficient
```

## Structure Template

```markdown
## Summary

- <What this PR does>
- <Why it's needed>
- <Key implementation decisions>

## Changes

- **<category>**: <description>

## Test plan

- [ ] <Test scenario 1>
- [ ] <Test scenario 2>

## Breaking changes

<If applicable, describe what breaks and migration path>

Closes #<issue-number>
```

## Examples

### Good: Feature Addition

```markdown
## Summary

- Adds user activity timeline to dashboard
- Surfaces recent actions for quick context on user behavior
- Uses existing Activity API with client-side pagination

## Test plan

- [ ] Timeline renders with mock data
- [ ] Pagination loads additional items
- [ ] Empty state displays correctly
- [ ] Error state handles API failures gracefully

Closes #234
```

### Good: Bug Fix

```markdown
## Summary

- Fixes race condition in connection pool cleanup
- Connections were being reused after closure under high load
- Root cause: missing mutex in `releaseConnection()`

## Test plan

- [ ] Added regression test for concurrent connection release
- [ ] Load tested with 1000 concurrent requests
- [ ] No connection errors in 10-minute soak test

Fixes #567
```

### Bad: No Context

```markdown
## Summary

Fixed the bug.

## Test plan

Tested locally.
```

Why is this bad? No context on what bug, what was wrong, or how it was tested.

### Bad: Implementation Details Only

```markdown
## Summary

- Changed line 45 in handler.go
- Added new function in utils.go
- Updated imports

## Test plan

- [ ] Tests pass
```

Why is this bad? Describes what changed (visible in diff) but not why.

## Agent Behavior

When creating PR descriptions:

1. **Explain purpose** — If uncertain why changes are being made, ask before creating PR
2. **Include test plan** — Always include specific test scenarios, not just "tests pass"
3. **Call out breaking changes** — Explicitly confirm if changes break compatibility
4. **No tool attribution** — Never include watermarks like "Generated with [Tool]"
5. **Keep it professional** — Clean, focused descriptions without unnecessary flair

## What to Avoid

| Avoid | Why |
|-------|-----|
| Tool attribution/watermarks | Clutters PR, unprofessional |
| Emoji overuse | Distracting, inconsistent |
| Vague test plans | "Tested locally" provides no value |
| Implementation details only | Diff shows what; PR explains why |
| Empty sections | Omit optional sections rather than leaving empty |

## Relationship to Commit Conventions

PR descriptions and commit messages serve different purposes:

| Aspect | Commit Message | PR Description |
|--------|---------------|----------------|
| Audience | Git history readers | PR reviewers |
| Scope | Single atomic change | All changes in branch |
| Detail | Concise (50/72 char limits) | Comprehensive |
| Test info | Not included | Required section |
| Breaking changes | Footer notation | Dedicated section |

A PR may contain multiple commits. The PR description provides the high-level narrative; individual commits document atomic changes.
