# Internal Enablement Brief: Feature Gates Pattern Documentation

**Feature ID**: feat-001  
**Date**: 2026-02-20  
**Audience**: Platform team, API developers

---

## What Was Added

New documentation file `feature-gates.md` in the `k8s-apiserver-patterns` skill. This documents the standard Kubernetes pattern for managing feature lifecycle in aggregated API servers.

**Location**: `plugins/datum-platform/skills/k8s-apiserver-patterns/feature-gates.md`

---

## Who Should Use This

**Primary**: Developers building or extending Datum aggregated API servers who need to:
- Introduce experimental features safely
- Provide runtime toggles for operators
- Graduate features through Alpha -> Beta -> GA lifecycle

**Secondary**: SREs and operators who need to understand feature maturity signals and how to enable/disable features via CLI flags.

---

## Key Patterns to Know

### 1. Feature Definition Location

All features go in `pkg/features/features.go`:

```go
const (
    // EventsProxy enables forwarding Events to Activity service.
    // owner: @datum-cloud/platform
    // alpha: v0.1.0
    EventsProxy featuregate.Feature = "EventsProxy"
)
```

### 2. Lifecycle Stages

| Stage | Default | Can Disable | Use Case |
|-------|---------|-------------|----------|
| Alpha | `false` | N/A | Experimental, testing in production |
| Beta | `true` | Yes | Stable API, ready for wider adoption |
| GA | `true` | No | Production-ready, locked |
| Deprecated | `false` | N/A | Scheduled for removal |

### 3. Checking Enablement

```go
if utilfeature.DefaultFeatureGate.Enabled(features.EventsProxy) {
    // Feature-specific code path
}
```

### 4. CLI Configuration

```bash
./myservice --feature-gates=EventsProxy=true,Sessions=false
```

### 5. When to Use Feature Gates

**Use when:**
- Feature changes storage backend behavior
- Feature integrates with external systems
- Feature is experimental and may be removed
- Operators need runtime control

**Skip when:**
- Simple API field additions
- Bug fixes
- Internal refactoring
- Features already gated by RBAC or admission

---

## Quick Reference

| Need | Section |
|------|---------|
| Define a new feature | "Feature Definition" |
| Register features at startup | "Feature Gate Registration" |
| Check if feature is enabled | "Checking Feature Enablement" |
| Graduate feature to Beta | "Alpha to Beta Graduation" |
| Remove a feature gate | "GA to Gate Removal" |
| Deprecate a feature | "Deprecation Path" |

---

## Related Documentation

- `server-config.md` - Server configuration patterns (Options, Config, CompletedConfig)
- Upstream: [k8s.io/component-base/featuregate](https://pkg.go.dev/k8s.io/component-base/featuregate)

---

## Questions?

Reach out to @datum-cloud/platform for clarification on feature gate patterns or to review feature graduation proposals.
