---
name: deploy
description: >
  Trigger deployment workflow for a feature. Invokes the SRE agent to handle
  deployment configuration, staging rollout, and production promotion.
tools: Read, Grep, Glob, Bash
model: sonnet
disable-model-invocation: true
context: fork
agent: general-purpose
argument-hint: "<feature-id> [--promote|--hotfix]"
---

# Deploy Command

Orchestrate deployment through the pipeline with proper gates and validation.

## Usage

```
/deploy <feature-id>                  Deploy feature to staging
/deploy <feature-id> --promote        Promote from staging to production
/deploy <feature-id> --hotfix         Abbreviated pipeline for urgent fixes
```

## Prerequisites

Before deployment:
- Review gate must be approved: `/pipeline approve <id> review`
- All blocking findings must be resolved
- Tests must pass

## Workflow

### `/deploy <feature-id>`

1. **Validate prerequisites**
   - Check review gate is approved
   - Verify no blocking findings
   - Confirm tests pass (check CI status)

2. **Load deployment context**
   - Read design artifact for infrastructure requirements
   - Read service profile for deployment targets
   - Check FluxCD configuration requirements

3. **Invoke SRE agent**
   - Generate/update Kustomize overlays
   - Configure staging deployment
   - Set up monitoring and alerts

4. **Update pipeline state**
   - Mark deploy stage as in_progress
   - Record deployment timestamp

### `/deploy <feature-id> --promote`

1. **Validate staging success**
   - Check staging deployment is healthy
   - Verify staging tests pass
   - Confirm metrics are nominal

2. **Invoke SRE agent for production**
   - Update production overlay
   - Configure canary/rollout strategy
   - Set up production alerts

3. **Trigger document and announce stages**
   - These can run in parallel with production monitoring

### `/deploy <feature-id> --hotfix`

Abbreviated path for urgent fixes:

1. **Skip normal gates** (with audit trail)
2. **Direct to production** with canary rollout
3. **Require post-deploy review** within 24 hours
4. **Auto-create follow-up tasks** for documentation

## Deployment Context Template

```markdown
## Deployment Context

**Feature**: {id} - {name}
**Target**: {staging|production}
**Review Status**: Approved on {date}

### Infrastructure Requirements

{From design artifact}

### Deployment Configuration

{From service profile and kustomize patterns}

### Rollout Strategy

- Canary: {percentage}
- Rollout duration: {time}
- Rollback trigger: {conditions}

### Monitoring

- Key metrics to watch
- Alert thresholds
- Dashboard links
```

## Output

```
Deployment initiated: feat-042-vm-snapshot-management
Target: staging
Review gate: Approved (2025-01-15)

[Invokes SRE agent]

Deployment configured.
Kustomize overlay: config/overlays/staging/feat-042/
FluxCD will reconcile within 5 minutes.

Monitor: /deploy status feat-042
Promote to production: /deploy feat-042 --promote
```

## Error Handling

**Review not approved:**
```
Cannot deploy feat-042: review gate not approved.
Action: Run /pipeline approve feat-042 review after resolving findings.
```

**Blocking findings exist:**
```
Cannot deploy feat-042: 2 blocking findings unresolved.
Findings:
  - missing-status-condition in pkg/apis/snapshots/v1alpha1/types.go
  - unvalidated-input in pkg/registry/snapshot/strategy.go
Action: Resolve blocking findings and request re-review.
```

**Tests failing:**
```
Cannot deploy feat-042: CI tests failing.
Failed jobs: unit-tests, integration-tests
Action: Fix failing tests before deployment.
```
