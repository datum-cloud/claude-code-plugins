---
name: pipeline-conductor
description: Covers pipeline orchestration for feature development including stages, handoffs, and artifact management. Use when coordinating work through the discovery to deployment pipeline.
---

# Pipeline Conductor

This skill covers pipeline orchestration for feature development.

## Slash Commands

Use these commands to orchestrate the pipeline:

| Command | Description |
|---------|-------------|
| `/pipeline start <name>` | Start a new feature pipeline |
| `/pipeline status <id>` | Check current stage and blockers |
| `/pipeline next <id>` | Advance to next stage |
| `/pipeline list` | Show all active pipelines |
| `/discover <description>` | Quick-start feature discovery |
| `/review [feature-id]` | Invoke code review |
| `/deploy <id>` | Trigger deployment workflow |

See `commands/` directory for detailed command documentation.

## Pipeline Stages

```
request → discovery → spec → pricing → design → ui-patterns →
  implementation → test → review → deploy → document → announce
```

## Parallel Execution

Some stages can run in parallel:

```
discovery
    ├── spec ──────────┐
    └── pricing ───────┼── design
                       │
implementation:        │
    ├── api-dev ───────┤ (parallel)
    ├── frontend-dev ──┤
    └── sre ───────────┘
                       │
post-deploy:           │
    ├── document ──────┤ (parallel)
    └── announce ──────┘
```

## Stage Routing

| Input Type | Starting Stage |
|------------|----------------|
| Feature idea | discovery |
| Clear requirements | spec |
| Bug fix | implementation |
| Doc update | document |
| Hotfix | implementation → deploy |

## Human Gates

Approval required after:
- **spec**: Requirements confirmed
- **pricing**: Commercial model approved
- **review**: Code quality verified
- **announce**: Content approved

Approve with: `/pipeline approve <id> <gate>`

## Pipeline Artifacts

All artifacts live in `.claude/pipeline/`:

```
.claude/pipeline/
├── requests/       # Feature requests
├── briefs/         # Discovery briefs
├── specs/          # Specifications
├── pricing/        # Pricing briefs
├── designs/        # Architecture designs
├── ui-patterns/    # UI specifications
├── triage/         # Support triage docs
└── comms/          # GTM content
```

## Artifact Naming

Pattern: `{id}-{name}.md`

Example: `feat-001-vm-snapshots.md`

## Stage Handoffs

Each agent reads upstream artifacts and writes downstream:

| Agent | Reads | Writes |
|-------|-------|--------|
| product-discovery | requests/ | briefs/ |
| product-planner | briefs/ | specs/ |
| commercial-strategist | briefs/, specs/ | pricing/ |
| architect | specs/, pricing/ | designs/ |
| api-dev | designs/ | code |
| code-reviewer | designs/, code | findings |

## Handoff Headers

All pipeline artifacts MUST include structured handoff headers. See `handoff-format.md` for the complete schema.

Key fields:
- `context_summary`: What this artifact represents
- `decisions_made`: Key decisions with rationale
- `open_questions`: Unresolved items (blocking vs non-blocking)
- `assumptions`: What was assumed, with confidence levels
- `platform_capabilities`: Quota, insights, telemetry, activity decisions

## Templates

See `templates/` for stage-specific templates with handoff headers:
- `templates/discovery-brief.md` - Discovery phase output
- `templates/spec.md` - Specification document
- `templates/pricing-brief.md` - Commercial strategy output
- `templates/design.md` - Architecture design document

## Artifact Requirements

### Discovery Brief

Required sections:
- Problem Statement
- Target Users
- Scope Boundaries
- Success Criteria
- Platform Capability Assessment
- Open Questions

### Specification

Required sections:
- Overview
- User Stories
- Functional Requirements
- Non-Functional Requirements
- API Changes
- Data Model Changes

### Design

Required sections:
- Architecture Overview
- Component Changes
- API Design
- Storage Design
- Platform Integrations
- Migration Plan
