---
handoff:
  id: feat-003
  from: product-discovery
  to: implementation
  created: 2026-02-20T12:35:00Z
  context_summary: "Add pr-conventions skill to datum-platform plugin"
  decisions_made:
    - "Create separate skill (pr-conventions) rather than combining with commit-conventions"
    - "Provide general PR conventions for all PRs, not just pipeline features"
    - "Never include tool attribution or watermarks in PR descriptions"
    - "Agents must prompt for context when PR purpose is unclear"
  open_questions: []
  assumptions:
    - "PR conventions complement but don't replace handoff-format for pipeline features"
---

# Discovery Brief: Pull Request Description Conventions

**Feature ID**: feat-003
**Date**: 2026-02-20
**Source**: Conversation during feat-002 implementation

## Problem Statement

Pull request descriptions lack standardization across Datum Cloud repositories. Without conventions:

- PRs may lack essential context for reviewers
- Test plans are inconsistently documented
- Breaking changes may not be clearly called out
- Tool attribution (watermarks) clutters professional PRs

The datum-platform plugin should provide a `pr-conventions` skill as a single source of truth for PR descriptions.

## Target Users

| User Type | Context | Frequency |
|-----------|---------|-----------|
| Claude Code agents | When creating PRs after implementation | Every PR |
| Human developers | When writing PR descriptions | Every PR |
| Code reviewers | When evaluating PR completeness | Every PR review |

## Key Decisions

### 1. Separate Skill

Create `pr-conventions` as a standalone skill rather than combining with `commit-conventions`:
- PRs and commits serve different audiences
- PRs require higher-level narrative; commits are atomic history
- Cleaner separation of concerns

### 2. General Conventions for All PRs

Apply to all PRs, not just pipeline features. The handoff-format guidance for pipeline PRs is complementary, not replaced.

### 3. No Tool Attribution

Never include Claude Code watermarks or similar tool attribution in PR descriptions. PRs should be clean and professional.

### 4. Essential Sections

| Section | Required | Purpose |
|---------|----------|---------|
| Summary | Yes | Brief description of what and why (2-4 bullets) |
| Changes | Optional | Detailed breakdown for complex PRs |
| Test plan | Yes | How changes were/should be tested |
| Breaking changes | Conditional | Required if changes break compatibility |
| Related issues | Optional | Links to issues this PR addresses |

### 5. Agent Behavior

- Prompt for context when PR purpose is unclear
- Ask about test plan if not obvious from changes
- Confirm breaking changes explicitly

## Scope

### In Scope

- Create `pr-conventions` skill in `plugins/datum-platform/skills/`
- Document PR title conventions (similar to commit subject)
- Document required and optional sections
- Document breaking change callouts
- Provide good/bad examples
- Define agent behavior for prompting
- Reference from relevant agents

### Out of Scope

- PR templates (GitHub's PULL_REQUEST_TEMPLATE.md)
- CI/CD integration
- Automated PR validation

## Success Criteria

1. Single source of truth for PR conventions across repos
2. Claude Code agents produce consistently formatted PRs
3. PRs include test plans and breaking change callouts
4. No tool attribution in generated PRs
5. Agents prompt when context is insufficient

## Recommendation

Proceed to implementation. Create:

1. `plugins/datum-platform/skills/pr-conventions/SKILL.md`
2. Bump plugin version to 1.5.0
3. Update CHANGELOG.md
