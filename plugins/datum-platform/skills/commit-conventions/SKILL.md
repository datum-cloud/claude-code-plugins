---
name: commit-conventions
description: Covers commit message conventions including format, structure, and content guidelines. Use when writing commits to ensure consistent, meaningful commit history across Datum Cloud repositories.
---

# Commit Conventions

This skill covers commit message conventions for all Datum Cloud repositories.

## Overview

Write commit messages for future maintainers who need context months or years later. A well-crafted commit history enables effective use of `git log`, `blame`, `revert`, and `rebase`.

## The Seven Rules

Based on [How to Write a Git Commit Message](https://cbea.ms/git-commit/):

| Rule | Guidance |
|------|----------|
| 1. Separate subject from body with blank line | Required for multi-line commits |
| 2. Limit subject line to 50 characters | 50 is target, 72 is hard limit |
| 3. Capitalize the subject line | Begin with capital letter after type prefix |
| 4. Do not end subject with a period | Conserves space, cleaner appearance |
| 5. Use imperative mood | "Add feature" not "Added feature" |
| 6. Wrap body at 72 characters | Allows Git indentation in diffs |
| 7. Use body to explain what and why | Code shows how; commit explains why |

## Format

Use Conventional Commits format:

```
<type>: <subject>

<body>

<trailers>
```

### Types

| Type | Use When |
|------|----------|
| `feat` | Adding new functionality |
| `fix` | Fixing a bug |
| `docs` | Documentation only changes |
| `refactor` | Code change that neither fixes a bug nor adds a feature |
| `test` | Adding or updating tests |
| `chore` | Maintenance tasks, dependencies, tooling |

### Subject Line

- Start with type prefix: `feat:`, `fix:`, etc.
- Capitalize first letter after the colon
- Use imperative mood: "Add" not "Added" or "Adds"
- No period at the end
- Keep under 50 characters (72 hard limit)

**Imperative mood test**: "If applied, this commit will [subject]"

```
feat: Add user authentication endpoint     ✓ reads naturally
feat: Added user authentication endpoint   ✗ awkward phrasing
feat: Adding user authentication endpoint  ✗ awkward phrasing
```

## When to Include a Body

**Single-line commits** are acceptable for:
- Typo fixes
- Obvious bug fixes
- Simple, self-explanatory changes

**Include a body** for:
- Non-trivial changes
- Changes requiring context
- Anything where "why" isn't obvious from the diff

## Body Content

Focus on **why**, not **what** (the diff shows what changed).

Answer these questions:
- What problem does this solve?
- Why was this approach chosen over alternatives?
- What context will future maintainers need?

### Formatting

- Wrap at 72 characters
- Use blank lines between paragraphs
- Use bullet points with hyphens for lists
- Place issue references at the end

## Examples

### Good: Simple Change

```
fix: Correct typo in error message
```

### Good: With Context

```
feat: Add rate limiting to API endpoints

The public API was vulnerable to abuse from automated clients
making excessive requests. This adds a token bucket rate limiter
with configurable limits per endpoint.

Default limits are set conservatively (100 req/min) and can be
adjusted via environment variables.

Resolves: #234
```

### Good: Explaining Why

```
refactor: Extract validation logic into separate package

Validation rules were duplicated across three controllers. Moving
them to a shared package reduces maintenance burden and ensures
consistent behavior.

This is a pure refactor with no behavior changes.
```

### Bad: No Context

```
fix: Fix the bug
```

Why is this bad? Which bug? What was wrong? Future maintainers have no context.

### Bad: Describes What, Not Why

```
refactor: Move function to different file
```

Why is this bad? The diff already shows this. Why was it moved?

### Bad: Too Long

```
feat: add new user authentication endpoint that validates credentials and returns JWT tokens
```

Why is this bad? Exceeds 72 characters. Use body for details.

## Agent Behavior

When generating commit messages:

1. **Clarify purpose** — If uncertain why changes are being made, ask the user before committing
2. **Confirm details** — When context is unclear, prompt for clarification
3. **Write for humans** — Messages should be descriptive and readable
4. **Include rationale** — Explain why changes were made, not just what changed

## Co-Authored-By Trailer

Claude Code agents include the Co-Authored-By trailer:

```
feat: Add resource quota enforcement

Implements quota checking at resource creation time to prevent
tenants from exceeding their allocated limits.

Co-Authored-By: Claude <claude@anthropic.com>
```

## Commit Structure Template

```
<type>: <Subject line under 50 chars>

<Explain the problem this solves. Wrap at 72 characters. Focus on
the motivation and context, not the implementation details.>

<If relevant, explain why this approach was chosen over alternatives.>

<Bullet points are acceptable:>
- Point one
- Point two

Resolves: #<issue-number>

Co-Authored-By: Claude <claude@anthropic.com>
```
