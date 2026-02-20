---
handoff:
  id: feat-002
  from: product-discovery
  to: product-planner
  created: 2026-02-20T12:15:00Z
  context_summary: "Add commit-conventions skill to datum-platform plugin"
  decisions_made:
    - "Implement as a skill, not a hook - agents internalize conventions before committing"
    - "Adopt the seven rules from cbea.ms/git-commit as foundation"
    - "Follow Conventional Commits format with simplified syntax (no scope)"
    - "Include commit body best practices (when to use, what to include)"
    - "Include Co-Authored-By trailer guidance for Claude agents"
    - "Commit messages must explain WHY changes are made, not just what"
    - "Agents must prompt users when commit purpose is unclear"
  open_questions:
    - "Should the skill include a commitlint.config.js template?"
    - "Should breaking changes require specific notation (feat!: or BREAKING CHANGE footer)?"
  assumptions:
    - "CI-level validation (commitlint) will catch violations in PRs"
    - "Existing repo commit history already follows this format"
---

# Discovery Brief: Commit Message Conventions

**Feature ID**: feat-002
**Date**: 2026-02-20
**Source**: [GitHub Issue #2](https://github.com/datum-cloud/claude-code-plugins/issues/2)

## Problem Statement

Commit message conventions are duplicated across CLAUDE.md files in multiple Datum Cloud repositories. When conventions change, each repository's CLAUDE.md must be updated manually. This leads to:

- **Drift**: Repositories diverge as updates are applied inconsistently
- **Maintenance burden**: N repositories × M convention changes = significant overhead
- **Onboarding friction**: New contributors must find the right CLAUDE.md for each repo

The datum-platform plugin should provide a single source of truth for commit conventions, following the same pattern as existing skills like `go-conventions`.

## Target Users

| User Type | Context | Frequency |
|-----------|---------|-----------|
| Claude Code agents | When generating commits after implementing changes | Every commit |
| Human developers | When writing manual commits to follow team standards | Every commit |
| Code reviewers | When verifying commits follow conventions | Every PR review |

## Key Decisions

### 1. Implement as a Skill (Not a Hook)

- PostToolUse hooks on `git commit` are awkward since the commit has already happened
- Agents should internalize conventions by reading the skill before committing
- CI-level validation (commitlint) catches violations in PRs
- This matches how `go-conventions` works for code style

### 2. Follow the Seven Rules of Commit Messages

Based on [How to Write a Git Commit Message](https://cbea.ms/git-commit/):

| Rule | Guidance |
|------|----------|
| 1. Separate subject from body with blank line | Required for multi-line commits |
| 2. Limit subject line to 50 characters | 50 is target, 72 is hard limit |
| 3. Capitalize the subject line | Begin with capital letter |
| 4. Do not end subject with a period | Conserves space, cleaner |
| 5. Use imperative mood | "Add feature" not "Added feature" |
| 6. Wrap body at 72 characters | Allows Git indentation in diffs |
| 7. Use body to explain what and why, not how | Code shows how; commit explains why |

### 3. Conventional Commits Format

- Format: `<type>: <subject>` (no scope for simplicity)
- Types: `feat`, `fix`, `docs`, `refactor`, `test`, `chore`
- Subject follows the seven rules above
- Test: "If applied, this commit will [subject]" should read naturally

### 4. Commit Body Best Practices

- Single-line commits acceptable for trivial changes (typos, obvious fixes)
- For non-trivial changes, include body explaining:
  - The problem being solved
  - Why this approach was chosen
  - Any relevant context for future maintainers
- Use bullet points with hyphens for lists
- Place issue references at body's end: `Resolves: #123`

### 5. Agent Behavior Requirements

- Agents must clarify their understanding of the purpose if uncertain
- Agents must prompt users to confirm details when context is unclear
- Write for future maintainers who need context months later

### 6. Include Co-Authored-By Trailer Guidance

- Claude agents already add this per system instructions
- Should be explicit in the skill for consistency
- Format: `Co-Authored-By: Claude <agent>@anthropic.com`

## Scope

### In Scope

- Create `commit-conventions` skill in `plugins/datum-platform/skills/`
- Document the seven rules of commit messages (subject/body separation, length limits, capitalization, imperative mood, etc.)
- Document Conventional Commits format with types
- Document commit body best practices (when to use, what to include, formatting)
- Document Co-Authored-By trailer for Claude agents
- Emphasize explaining "why" over "what" in commit messages
- Define agent behavior: prompt users when commit purpose is unclear
- Provide examples of good and bad commits (including why-focused examples)
- Include example commit structure template
- Reference skill from relevant agents (api-dev, frontend-dev, sre, etc.)

### Out of Scope (Future Consideration)

- Commitlint config file templates
- Enforcement hooks in Claude Code
- Pre-commit git hooks

## Platform Capabilities

None required. This is documentation/guidance, not a resource feature requiring Quota, Insights, Activity, or Telemetry integration.

## Success Criteria

1. Single source of truth for commit conventions across all Datum Cloud repos
2. Claude Code agents produce consistently formatted commits
3. Commit messages explain the purpose/rationale of changes, not just what changed
4. Agents ask clarifying questions when commit purpose is uncertain
5. Human developers can reference conventions without searching CLAUDE.md files
6. Reduced maintenance burden when conventions evolve

## Open Questions (Non-blocking)

1. **Commitlint template**: Should the skill include a standard `commitlint.config.js` for repos to adopt?
2. **Breaking changes**: Should breaking changes require specific notation (`feat!:` or `BREAKING CHANGE:` footer)?

## Recommendation

Proceed to implementation. This is a straightforward documentation task:

1. Create `plugins/datum-platform/skills/commit-conventions/SKILL.md`
2. Update agent definitions to reference the new skill
3. Bump plugin version (minor: new skill)
4. Update CHANGELOG.md

The skill content is well-defined by the GitHub issue and Conventional Commits spec. No further planning required.
