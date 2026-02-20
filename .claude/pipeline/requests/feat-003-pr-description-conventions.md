---
handoff:
  id: feat-003
  from: user
  to: product-discovery
  created: 2026-02-20T12:30:00Z
  context_summary: "Add pull request description conventions to datum-platform plugin"
  decisions_made:
    - "Never include Claude Code watermark in PR descriptions"
  open_questions:
    - "What sections should a PR description include?"
    - "Should this be a skill or integrated into commit-conventions?"
    - "What makes a good PR description vs a bad one?"
  assumptions: []
---

# Feature Request: Pull Request Description Conventions

**Requested by**: scotwells
**Date**: 2026-02-20
**Source**: Conversation during feat-002 implementation

## Initial Description

Add pull request description formatting standards to the datum-platform plugin. Similar to commit conventions, this provides a single source of truth for PR descriptions across all Datum Cloud repositories.

### Known Requirements

- Never include Claude Code watermark in PR descriptions
- PR descriptions should be human-friendly and descriptive
- Should explain the purpose and context of changes

### Context

Discovered while creating PR #3 for commit conventions. The user explicitly rejected the Claude Code watermark, indicating a preference for clean, professional PR descriptions without tool attribution.

## Notes

This request is awaiting discovery. The product-discovery agent will:
- Define what makes an effective PR description
- Identify standard sections (Summary, Changes, Test plan, etc.)
- Determine relationship to commit-conventions skill
- Produce a discovery brief
