---
handoff:
  id: feat-002
  from: user
  to: product-discovery
  created: 2026-02-20T12:10:00Z
  context_summary: "Add commit message formatting standards to datum-platform plugin"
  decisions_made: []
  open_questions:
    - "What problem does this solve?"
    - "Who are the target users?"
    - "Should this be a skill, hook, or both?"
    - "How should this integrate with existing git commit workflows?"
  assumptions: []
---

# Feature Request: Commit Message Conventions

**Requested by**: scotwells (GitHub issue #2)
**Date**: 2026-02-20
**Source**: https://github.com/datum-cloud/claude-code-plugins/issues/2

## Initial Description

Add commit message formatting standards to the datum-platform plugin so they apply consistently across all Datum Cloud repositories.

### Proposed Conventions

Format: `<type>: <description>`

- Use imperative mood: "add feature" not "added feature"
- Keep it concise: one line, under 72 characters
- Types: `feat:`, `fix:`, `docs:`, `refactor:`, `test:`, `chore:`

Examples:
- `feat: add activity timeline component`
- `fix: include UI image in dev setup`
- `refactor: simplify CEL expression parsing`

### Context

Currently discovered while working in the activity repo. These standards should be shared across all repos rather than duplicated in each CLAUDE.md.

## Notes

This request is awaiting discovery. The product-discovery agent will:
- Clarify the problem being solved (duplication vs. consistency)
- Identify target users (developers, agents)
- Assess scope boundaries (just formatting, or also hooks/validation?)
- Evaluate platform capability requirements
- Produce a discovery brief
