---
name: pipeline
description: >
  Orchestrate the Datum Cloud feature development pipeline. Use to start new features,
  check status, advance to the next stage, or route work to the appropriate agent.
tools: Read, Grep, Glob, Bash
model: sonnet
disable-model-invocation: true
context: fork
agent: general-purpose
argument-hint: "<command> [feature-id] [options]"
---

# Pipeline Orchestration Command

You are the pipeline orchestrator for Datum Cloud. Your job is to manage the flow of features through the development pipeline, routing work to the right agents at the right time.

## Usage

```
/pipeline start <name>              Start a new feature with discovery
/pipeline status <id>               Show current stage and next steps
/pipeline next <id>                 Advance to next stage (invokes appropriate agent)
/pipeline list                      Show all active pipeline items
/pipeline route <id> <stage>        Jump to a specific stage
```

## Arguments

Command and options: $ARGUMENTS

## Pipeline Stages

```
request → discovery → spec → pricing → design → ui-patterns →
  implementation → test → review → deploy → document → announce
```

## Stage-to-Agent Mapping

| Stage | Agent | Parallel With |
|-------|-------|---------------|
| discovery | product-discovery | - |
| spec | product-planner | pricing (after discovery) |
| pricing | commercial-strategist | spec (after discovery) |
| design | architect | - |
| ui-patterns | frontend-dev | - |
| implementation | api-dev, frontend-dev, sre | parallel execution |
| test | test-engineer | - |
| review | code-reviewer | - |
| deploy | sre | - |
| document | tech-writer | announce |
| announce | gtm-comms | document |

## Command Workflows

### `/pipeline start <name>`

1. Generate feature ID: `feat-{NNN}` where NNN is next sequential number
2. Create request artifact at `.claude/pipeline/requests/{id}-{name}.md`
3. Initialize pipeline state at `.claude/pipeline/state/{id}.json`
4. Suggest invoking product-discovery agent

**Output:**
```
Pipeline started: feat-001-{name}
Stage: request (ready for discovery)
Next: Invoke product-discovery to begin discovery phase
```

### `/pipeline status <id>`

1. Read pipeline state from `.claude/pipeline/state/{id}.json`
2. Check for artifacts in each stage directory
3. Identify current stage and blockers
4. Report next actions

**Output format:**
```
Feature: feat-001-vm-snapshots
Current Stage: spec (in progress)
Completed: [discovery, pricing]
Artifacts:
  - briefs/feat-001-vm-snapshots.md (complete)
  - pricing/feat-001-vm-snapshots.md (complete)
  - specs/feat-001-vm-snapshots.md (in progress)
Human Gates Passed: [spec: pending, pricing: approved]
Next: Complete spec, then await human approval
Blockers: None
```

### `/pipeline next <id>`

1. Read current pipeline state
2. Validate current stage is complete (artifact exists, gates passed)
3. Determine next stage(s) from dependency graph
4. Invoke appropriate agent(s)

**Validation checks:**
- Artifact exists for current stage
- Handoff header is complete (no unresolved open questions)
- Human gates passed if required

### `/pipeline list`

1. Scan `.claude/pipeline/state/` for all pipeline states
2. Group by status: active, blocked, completed
3. Show summary for each

### `/pipeline route <id> <stage>`

Route to a specific stage (for hotfixes, bug fixes, or manual overrides):

| Route | Use Case |
|-------|----------|
| `route <id> implementation` | Bug fix with clear requirements |
| `route <id> deploy` | Hotfix straight to deployment |
| `route <id> document` | Documentation-only change |

## Pipeline State Schema

```json
{
  "id": "feat-001",
  "name": "vm-snapshots",
  "created": "2025-01-15T10:00:00Z",
  "current_stage": "spec",
  "stages": {
    "discovery": {
      "status": "completed",
      "artifact": "briefs/feat-001-vm-snapshots.md",
      "completed_at": "2025-01-15T11:00:00Z"
    },
    "spec": {
      "status": "in_progress",
      "started_at": "2025-01-15T11:30:00Z"
    }
  },
  "gates": {
    "spec": "pending",
    "pricing": "approved",
    "review": "pending",
    "announce": "pending"
  },
  "parallel_enabled": ["spec", "pricing"]
}
```

## Dependency Graph

```
discovery
    ├── spec ──────────┐
    └── pricing ───────┼── design
                       │     └── ui-patterns
                       │           └── implementation (api-dev, frontend-dev, sre)
                       │                 └── test
                       │                       └── review [GATE]
                       │                             └── deploy
                       │                                   ├── document
                       │                                   └── announce [GATE]
```

## Human Gates

The following stages require explicit human approval before proceeding:

| Gate | Purpose | Command to Approve |
|------|---------|-------------------|
| spec | Requirements confirmed | `/pipeline approve <id> spec` |
| pricing | Commercial model approved | `/pipeline approve <id> pricing` |
| review | Code quality verified | `/pipeline approve <id> review` |
| announce | Communications approved | `/pipeline approve <id> announce` |

## Error Handling

**Missing artifact:**
```
Error: Cannot advance feat-001 from discovery to spec
Reason: No artifact found at briefs/feat-001-vm-snapshots.md
Action: Invoke product-discovery to complete discovery phase
```

**Unresolved handoff:**
```
Warning: Artifact has unresolved open questions
Open Questions:
  - Should snapshots count against storage quota?
  - What's the retention policy for automated snapshots?
Action: Resolve questions before advancing, or use --force to proceed
```

**Gate not approved:**
```
Blocked: feat-001 requires human approval at spec gate
Status: Spec artifact complete, awaiting approval
Action: Review spec and run `/pipeline approve feat-001 spec`
```

## Context Discovery

Before executing any command:

1. Read `.claude/pipeline/state/` to understand current pipeline states
2. Read relevant artifacts for the feature being operated on
3. Check `.claude/service-profile.md` for service context
4. Reference `pipeline-conductor/SKILL.md` for stage requirements

## Integration with Agents

When invoking agents, pass the feature context:

```
Invoke api-dev with:
- Feature ID: feat-001
- Design artifact: .claude/pipeline/designs/feat-001-vm-snapshots.md
- Service profile: .claude/service-profile.md
```

Agents should read the handoff header from upstream artifacts to understand context, decisions made, and open questions.
