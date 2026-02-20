---
handoff:
  id: feat-001
  from: user
  to: product-discovery
  created: 2026-02-20T00:00:00Z
  context_summary: "Add Kubernetes feature gates pattern to platform skills for standardized feature lifecycle management"
  decisions_made: []
  open_questions:
    - "What problem does this solve?"
    - "Who are the target users?"
    - "Which skills need updates?"
    - "What examples should be included?"
  assumptions: []
  source: https://github.com/datum-cloud/claude-code-plugins/issues/1
---

# Feature Request: Kubernetes Feature Gates Pattern

**Requested by**: User (scotwells via GitHub issue #1)
**Date**: 2026-02-20

## Initial Description

Add documentation for Kubernetes feature gates as a standardized pattern to platform skills. This pattern should be incorporated into `datum-platform:api-dev` and `datum-platform:k8s-apiserver-patterns` skills.

## Background

During development of the Events proxy feature in Milo, the team moved away from individual boolean flags toward the standard Kubernetes feature gates pattern via `k8s.io/component-base/featuregate`.

## Recommended Implementation Components

1. **Feature Definition**
   - Create feature constants in `pkg/features/features.go`
   - Include metadata: owner, release stage, description

2. **Feature Usage**
   - Check enablement via `utilfeature.DefaultFeatureGate.Enabled()` calls
   - Support runtime toggling

3. **Configuration**
   - CLI flags: `--feature-gates=EventsProxy=true`
   - Environment variables

## Feature Lifecycle Stages

- **Alpha**: Disabled by default, experimental
- **Beta**: Enabled by default, can be disabled
- **GA**: Enabled permanently

## Reference Implementation

Milo repository contains a reference implementation in the feature gates file.

## Scope

Two platform skills require updates to incorporate this guidance.

## Notes

This request is awaiting discovery. The product-discovery agent will:
- Clarify the problem being solved
- Identify target users (API developers, SREs)
- Assess scope boundaries
- Evaluate platform capability requirements
- Produce a discovery brief
