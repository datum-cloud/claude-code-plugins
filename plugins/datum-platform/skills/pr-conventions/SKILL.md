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

Describe the problem and solution in plain language. Start with prose that explains the context, then use bullet points only for key behaviors or outcomes that benefit from scannable formatting.

```markdown
## Summary

Public API endpoints were vulnerable to abuse from automated clients making excessive requests. This adds rate limiting to protect service availability.

Key behaviors:

- Requests exceeding 100/min receive 429 responses with retry headers
- Limits are configurable per-endpoint via environment variables
- Existing clients below the threshold see no change
```

Write for humans first. Focus on:
- What problem this solves (lead with this)
- Why this approach was chosen
- Key outcomes that reviewers should verify

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

## Writing Style

Write PR descriptions like you're explaining the change to a colleague. Use natural prose to provide context, and reserve bullet points for lists of discrete items.

| Use prose for | Use bullets for |
|---------------|-----------------|
| Problem description | List of key behaviors |
| Context and rationale | Test scenarios |
| How components relate | Breaking changes list |

Avoid starting the summary with bullet points. Lead with a sentence that orients the reader, then add bullets if needed for scannable details.

## Structure Template

```markdown
## Summary

<Describe the problem in 1-2 sentences. Then explain what this PR does and why.>

<Optional: Key behaviors or outcomes as bullets if they benefit from scanning.>

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

Users currently have no visibility into recent activity on their resources. This adds an activity timeline to the dashboard that surfaces recent actions, helping users quickly understand what changed and when.

The timeline uses the existing Activity API with client-side pagination, so no backend changes are required.

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

Under high load, connections were being reused after closure, causing intermittent failures for downstream requests. The root cause was a missing mutex in `releaseConnection()` that allowed concurrent access during cleanup.

This adds proper synchronization to the connection pool, ensuring connections are fully released before being returned to the pool.

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
| Bullet-point-only summaries | Feels robotic; lead with prose for context |
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
