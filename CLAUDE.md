# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Repository Overview

This is a Claude Code plugin marketplace containing two plugins for Datum Cloud:

- **datum-platform**: Kubernetes platform engineering automation (aggregated API servers, controller patterns, GitOps deployment)
- **datum-gtm**: Go-to-market automation (commercial strategy, product discovery, customer support)

## Validation Commands

```bash
# Validate marketplace and plugin structure
claude plugin validate .

# Or from within Claude Code
/plugin validate .
```

## Repository Structure

```
.claude-plugin/
  marketplace.json          # Marketplace catalog listing plugins

plugins/
  datum-platform/
    .claude-plugin/
      plugin.json           # Plugin manifest
    agents/                 # Agent definitions (markdown)
    skills/                 # Knowledge modules (SKILL.md + topic files)
    commands/               # Slash command definitions
    hooks/hooks.json        # Automation hooks (PostToolUse)
    scripts/                # Utility scripts (auto-validate.sh)

  datum-gtm/
    .claude-plugin/
      plugin.json           # Plugin manifest
    agents/
    skills/
    commands/

docs/                       # User documentation
```

## Key Concepts

### Agents

Specialized agents with narrow expertise. Each agent has:
- A markdown file in `agents/` with YAML front matter (name, description, tools, model)
- A specific role in the pipeline (discovery → design → implementation → review → deploy)
- Skills they load based on task

**datum-platform agents**: plan, api-dev, frontend-dev, sre, test-engineer, code-reviewer, tech-writer
**datum-gtm agents**: product-discovery, commercial-strategist, gtm-comms, support-triage

### Skills

Knowledge modules agents read during context discovery. Each skill has:
- `SKILL.md` as the entry point
- Additional topic files (e.g., `implementation.md`, `concepts.md`)
- Optional scripts for validation or scaffolding

### Commands

Slash commands users invoke (e.g., `/discover`, `/review`, `/deploy`). Defined in markdown files under `commands/`.

### Hooks

Automation hooks in `hooks/hooks.json`. Currently uses `PostToolUse` to run validation after Write/Edit operations.

### Pipeline

Features flow through stages: `request → discovery → spec → pricing → design → ui-patterns → implementation → test → review → deploy → document → announce`

Pipeline artifacts live in `.claude/pipeline/` in the target repository (not this plugin repo).

## Plugin Development

### Adding a New Agent

1. Create `plugins/{plugin}/agents/{name}.md` with YAML front matter:
   ```yaml
   ---
   name: agent-name
   description: >
     When and how to use this agent
   tools: Read, Write, Edit, Grep, Glob, Bash
   model: sonnet
   ---
   ```
2. Document workflow, skills to reference, and pipeline contract

### Adding a New Skill

1. Create directory `plugins/{plugin}/skills/{skill-name}/`
2. Add `SKILL.md` as entry point
3. Add supporting files for specific topics
4. Reference skill in relevant agent definitions

### Adding a New Command

Create `plugins/{plugin}/commands/{command}.md` defining the slash command behavior.

## Path References

Use `${CLAUDE_PLUGIN_ROOT}` for dynamic path resolution in hooks and scripts. This resolves to the plugin's installation directory at runtime.

## Versioning and Releases

When making changes to plugins, follow these requirements:

### Version Bumps

**Always bump the version** in `plugins/{plugin}/.claude-plugin/plugin.json` when making changes:
- **Patch** (1.0.x): Bug fixes, typo corrections, minor documentation fixes
- **Minor** (1.x.0): New features, new skills, new agents, significant documentation additions
- **Major** (x.0.0): Breaking changes, major restructuring

### Changelog

Maintain `CHANGELOG.md` at the repo root. For each release:
- Use format `## [X.Y.Z] - YYYY-MM-DD`
- Keep entries concise and user-focused (what value does this provide?)
- Avoid implementation details - focus on capabilities added

Example:
```markdown
## [1.3.0] - 2026-02-20

### Added

- **Feature gates pattern** (`k8s-apiserver-patterns`) — Guidance for safely introducing experimental features with Alpha/Beta/GA lifecycle stages.
```

### README Updates

Update the version table in `README.md` to match `plugin.json`:
```markdown
| [datum-platform](./plugins/datum-platform/) | ... | 1.3.0 |
```

### Release Checklist

1. Bump version in `plugins/{plugin}/.claude-plugin/plugin.json`
2. Add entry to `CHANGELOG.md` with date
3. Update version in `README.md` table
4. Commit with conventional commit message: `feat(plugin-name): description`
5. Push to main (plugins auto-update from main branch)
