---
handoff:
  id: feat-001
  from: product-discovery
  to: architect
  created: 2026-02-20T00:00:00Z
  context_summary: "Add Kubernetes feature gates pattern documentation to k8s-apiserver-patterns skill based on Milo Events proxy implementation"
  decisions_made:
    - "Target skill is k8s-apiserver-patterns (not separate api-dev skill)"
    - "Documentation will include self-contained examples from Milo reference"
    - "Pattern applies to all Datum aggregated API servers"
  open_questions:
    - "Should feature gates be required for all new features or optional?"
    - "What naming conventions for feature constants?"
  assumptions:
    - "Milo's feature gates implementation represents the canonical pattern"
    - "Developers are familiar with k8s.io/component-base packages"
  capabilities_required: []
---

# Discovery Brief: Kubernetes Feature Gates Pattern

**Feature ID**: feat-001
**Product Discovery Agent**: Claude
**Date**: 2026-02-20

## Problem Statement

Datum Cloud aggregated API servers currently lack standardized guidance for feature lifecycle management. During the Milo Events proxy feature development, the team discovered that individual boolean flags for experimental features create maintenance burden and lack the maturity signals (Alpha/Beta/GA) that operators expect from Kubernetes-style APIs.

**Core issue**: Developers don't have a documented pattern for:
- Safely introducing experimental features
- Managing feature lifecycle (Alpha → Beta → GA)
- Providing runtime feature toggles
- Communicating feature maturity to operators

## Target Users

**Primary**: API developers building Datum aggregated API servers
- Need to introduce new features safely
- Must communicate feature maturity
- Require runtime configuration options

**Secondary**: SREs and operators deploying Datum services
- Need to enable/disable experimental features
- Must understand feature stability guarantees
- Use CLI flags and environment variables for configuration

## Proposed Solution

Add a new `feature-gates.md` file to the `k8s-apiserver-patterns` skill documenting:

1. **Feature Definition Pattern**
   - Location: `pkg/features/features.go`
   - Structure: Feature constants with metadata (owner, stage, description)
   - Example from Milo Events proxy

2. **Feature Gate Integration**
   - Using `k8s.io/component-base/featuregate`
   - Checking enablement: `utilfeature.DefaultFeatureGate.Enabled()`
   - Registration and initialization

3. **Configuration Options**
   - CLI flags: `--feature-gates=FeatureName=true`
   - Environment variables
   - Integration with server Options pattern

4. **Lifecycle Stages**
   - Alpha (experimental, disabled by default)
   - Beta (stable, enabled by default, can disable)
   - GA (stable, always enabled, gate removed)

## Scope

### In Scope
- Documentation file `feature-gates.md` in k8s-apiserver-patterns skill
- Complete code examples from Milo reference implementation
- Integration with existing server-config.md patterns
- Update SKILL.md to reference feature gates

### Out of Scope
- Retrofitting existing services with feature gates (future work)
- Creating scaffolding scripts for feature gate setup
- Enforcement or linting for feature gate usage
- Feature gates for CRD-based controllers (different pattern)

## Success Criteria

1. Developers can implement feature gates without referencing Milo codebase
2. Pattern integrates with existing CompletedConfig pattern from server-config.md
3. Examples show full lifecycle: definition → usage → configuration
4. Clear guidance on when to use feature gates vs other approaches

## Platform Capability Assessment

**Quota**: Not applicable - documentation change
**Insights**: Not applicable - documentation change
**Telemetry**: Not applicable - documentation change
**Activity**: Not applicable - documentation change

## Implementation Notes

- Reference Milo's `pkg/features/features.go` for canonical example
- Ensure examples use consistent naming with existing patterns
- Link to upstream k8s.io/component-base documentation
- Consider adding feature gate example to architecture-decision.md

## Open Questions for Architecture Phase

1. Should we recommend feature gates for all new features or only experimental ones?
2. What naming convention for feature constants (e.g., `EventsProxy` vs `Events` vs `EventsProxyFeature`)?
3. Should feature gates be part of scaffolding scripts?

## Next Steps

Hand off to architect agent to:
- Design documentation structure
- Identify code examples to include
- Plan integration with existing skill files
- Create implementation plan for tech-writer
