# Datum Cloud Claude Code Plugin

A Claude Code plugin providing specialized agents and skills for Datum Cloud platform development. This plugin extends Claude Code with domain-specific knowledge about Kubernetes aggregated API servers, platform capabilities, and established development workflows.

## Overview

This plugin provides:

- **10 specialized agents** for different development roles (backend, frontend, SRE, documentation, etc.)
- **17 skill modules** containing platform-specific patterns, conventions, and integration guides
- **Pipeline orchestration** for structured feature development from discovery to deployment

## Installation

### Option 1: Local Development

Run Claude Code with the plugin directory:

```bash
claude --plugin-dir /path/to/claude-code-plugin
```

### Option 2: Project Configuration

Add to your project's `.claude/settings.json`:

```json
{
  "plugins": [
    {
      "name": "datum-cloud",
      "url": "file:///path/to/claude-code-plugin"
    }
  ]
}
```

### Option 3: Git-based Installation

If hosted on GitHub:

```json
{
  "plugins": [
    {
      "name": "datum-cloud",
      "url": "https://github.com/datum-cloud/claude-code-plugin"
    }
  ]
}
```

## Agents

| Agent | Purpose | Model |
|-------|---------|-------|
| `api-dev` | Go backend implementation for Kubernetes aggregated API servers | sonnet |
| `frontend-dev` | React/TypeScript UI implementation | sonnet |
| `sre` | Infrastructure, deployments, Kustomize, CI/CD | sonnet |
| `test-engineer` | Go unit tests, integration tests, test patterns | sonnet |
| `code-reviewer` | Post-implementation quality gate (read-only) | opus |
| `tech-writer` | API documentation, guides, README updates | sonnet |
| `product-discovery` | Problem discovery and requirements clarification | opus |
| `commercial-strategist` | Pricing and monetization strategy | opus |
| `gtm-comms` | Go-to-market communications and announcements | sonnet |
| `support-triage` | Customer issue categorization and routing | sonnet |

Each agent includes context discovery steps, workflow guidelines, quality checklists, and anti-patterns to avoid.

## Skills

Skills provide reusable knowledge that agents reference during their work.

### Platform Knowledge

| Skill | Description |
|-------|-------------|
| `platform-knowledge` | High-level Datum Cloud architecture |
| `milo-iam` | Identity and access management patterns |
| `commercial-models` | Pricing tiers and tier structures |

### Platform Capabilities

| Skill | Description |
|-------|-------------|
| `capability-quota` | Resource quota enforcement |
| `capability-insights` | Proactive issue detection |
| `capability-telemetry` | Observability integration |
| `capability-activity` | Activity timelines, audit logs, and event processing |
| `capability-index` | Capability overview and routing |

### Development Patterns

| Skill | Description |
|-------|-------------|
| `k8s-apiserver-patterns` | Storage, types, validation for aggregated API servers |
| `go-conventions` | Go code style, testing, error handling |
| `kustomize-patterns` | Kubernetes deployment patterns |
| `datum-ci` | CI/CD pipeline conventions |
| `design-tokens` | UI design system tokens |

### Process

| Skill | Description |
|-------|-------------|
| `pipeline-conductor` | Feature development pipeline orchestration |
| `gtm-templates` | Document templates for announcements and releases |
| `runbooks` | Accumulated learnings and operational procedures |

## Pipeline Workflow

The plugin supports a structured development pipeline:

```
request → discovery → spec → pricing → design → ui-patterns →
  implementation → test → review → deploy → document → announce
```

Pipeline artifacts are stored in `.claude/pipeline/` with stage-specific directories for requests, briefs, specs, designs, and communications.

Human approval gates occur after spec, pricing, review, and announce stages.

### Pipeline Commands

Orchestrate the pipeline with slash commands:

| Command | Description |
|---------|-------------|
| `/pipeline start <name>` | Start a new feature pipeline |
| `/pipeline status <id>` | Check current stage and blockers |
| `/pipeline next <id>` | Advance to next stage |
| `/pipeline list` | Show all active pipelines |
| `/pipeline approve <id> <gate>` | Approve a human gate |
| `/discover <description>` | Quick-start feature discovery |
| `/review [feature-id]` | Invoke code review |
| `/deploy <id>` | Trigger deployment workflow |

### Structured Handoff Headers

All pipeline artifacts include structured YAML frontmatter for context passing between agents:

```yaml
---
handoff:
  id: feat-001
  from: product-discovery
  to: [product-planner, commercial-strategist]
  context_summary: "Brief description of the work"
  decisions_made:
    - decision: "Key decision"
      rationale: "Why this was decided"
  open_questions:
    - question: "Unresolved question"
      blocking: true
      suggested_owner: architect
  platform_capabilities:
    quota:
      applies: true
      rationale: "Why quota is needed"
---
```

This ensures downstream agents understand context, decisions, and open questions without re-discovery.

## Directory Structure

```
claude-code-plugin/
├── .claude-plugin/
│   └── plugin.json          # Plugin manifest
├── agents/                   # Agent definitions
│   ├── api-dev.md
│   ├── code-reviewer.md
│   └── ...
├── commands/                 # Slash commands
│   ├── pipeline.md          # Pipeline orchestration
│   ├── discover.md          # Quick-start discovery
│   ├── review.md            # Code review
│   └── deploy.md            # Deployment workflow
├── skills/                   # Skill modules
│   ├── platform-knowledge/
│   ├── k8s-apiserver-patterns/
│   ├── capability-quota/
│   ├── pipeline-conductor/
│   │   ├── SKILL.md
│   │   ├── handoff-format.md  # Handoff header schema
│   │   └── templates/         # Artifact templates
│   └── ...
└── .claude/
    └── settings.local.json  # Permission configuration
```

## Usage

After installation, agents become available through Claude Code's agent system. Skills are automatically referenced by agents during context discovery.

### Invoking Agents

Agents are invoked through Claude Code's Task tool or agent selection interface. Each agent follows a consistent pattern:

1. Read `CLAUDE.md` for project context
2. Read relevant pipeline artifacts
3. Read applicable skill files
4. Read agent-specific runbook if it exists
5. Execute the work

### Agent Handoffs

Agents pass work through the pipeline by writing artifacts that downstream agents consume:

| Agent | Reads From | Writes To |
|-------|------------|-----------|
| product-discovery | requests/ | briefs/ |
| commercial-strategist | briefs/, specs/ | pricing/ |
| api-dev | designs/ | code |
| code-reviewer | designs/, code | findings |
| tech-writer | code | docs/ |

## Configuration

The `.claude/settings.local.json` file configures permissions:

```json
{
  "permissions": {
    "allow": [
      "Bash(wc:*)",
      "Bash(find:*)",
      "Bash(grep:*)"
    ]
  }
}
```

Customize permissions based on your security requirements.

## Contributing

When adding new agents or skills:

1. Follow the existing frontmatter format for agents
2. Include context discovery, workflow, pipeline contract, and anti-patterns sections
3. Reference existing skills where applicable
4. Add validation scripts for deterministic checks
