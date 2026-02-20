---
handoff:
  id: feat-001
  from: architect
  to: tech-writer
  created: 2026-02-20T00:00:00Z
  context_summary: "Implementation plan for Kubernetes feature gates documentation in k8s-apiserver-patterns skill"
  decisions_made:
    - "Feature gates recommended for experimental features, not required for all"
    - "PascalCase naming without suffix (e.g., EventsProxy, not EventsProxyFeature)"
    - "No scaffolding scripts in initial implementation"
    - "Document full graduation lifecycle with code examples at each stage"
  open_questions: []
  assumptions:
    - "Milo's feature gates implementation is the canonical reference"
---

# Architecture Plan: Kubernetes Feature Gates Pattern (feat-001)

## Executive Summary

Add `feature-gates.md` documentation to the `k8s-apiserver-patterns` skill with complete guidance on feature definition, usage, configuration, and lifecycle graduation (Alpha → Beta → GA → Removal).

## Files to Create/Modify

| File | Action | Description |
|------|--------|-------------|
| `plugins/datum-platform/skills/k8s-apiserver-patterns/feature-gates.md` | CREATE | Main documentation file |
| `plugins/datum-platform/skills/k8s-apiserver-patterns/SKILL.md` | MODIFY | Add to Key Files table |
| `plugins/datum-platform/skills/k8s-apiserver-patterns/server-config.md` | MODIFY | Add integration section |

## Reference Implementation

Primary source: `/Users/scotwells/repos/datum-cloud/milo/pkg/features/features.go`

```go
const (
    // EventsProxy enables forwarding Kubernetes Events to Activity service.
    // owner: @datum-cloud/platform
    // alpha: v0.1.0
    EventsProxy featuregate.Feature = "EventsProxy"

    // Sessions enables Session virtual API.
    // owner: @datum-cloud/platform
    // alpha: v0.1.0
    // ga: v0.2.0
    Sessions featuregate.Feature = "Sessions"
)

var defaultFeatureGates = map[featuregate.Feature]featuregate.FeatureSpec{
    EventsProxy:    {Default: false, PreRelease: featuregate.Alpha},
    Sessions:       {Default: true, PreRelease: featuregate.GA},
}
```

---

## Document Structure: feature-gates.md

### 1. Overview
- Purpose of feature gates
- When to use them (decision criteria)
- Link to upstream k8s.io/component-base documentation

### 2. Feature Definition
- File location: `pkg/features/features.go`
- Feature constant declaration with documentation comments
- FeatureSpec configuration

### 3. Feature Gate Registration
- Using `init()` pattern
- Blank import in server main

### 4. Checking Feature Enablement
- In Config methods
- In REST handlers
- In controllers

### 5. CLI Configuration
- `--feature-gates=FeatureName=true` syntax
- Environment variable alternatives

### 6. Feature Lifecycle Stages

| Stage | Default | Can Disable | Characteristics |
|-------|---------|-------------|-----------------|
| Alpha | `false` | N/A (off) | Experimental, may be removed |
| Beta | `true` | Yes | Stable API, enabled by default |
| GA | `true` | No | Production-ready, locked |
| Deprecated | `false` | N/A | Scheduled for removal |

### 7. Feature Graduation (DETAILED)

This section documents the complete lifecycle of graduating a feature.

#### 7.1 Alpha → Beta Graduation

**Criteria:**
- Feature has been tested in production environments
- API is stable (no breaking changes expected)
- Documentation is complete
- No critical bugs outstanding

**Code Changes:**

```go
// BEFORE (Alpha)
var defaultFeatureGates = map[featuregate.Feature]featuregate.FeatureSpec{
    MyFeature: {
        Default:    false,           // Disabled by default
        PreRelease: featuregate.Alpha,
    },
}

// AFTER (Beta)
var defaultFeatureGates = map[featuregate.Feature]featuregate.FeatureSpec{
    MyFeature: {
        Default:    true,            // Now enabled by default
        PreRelease: featuregate.Beta,
    },
}
```

**Documentation Comment Update:**

```go
// BEFORE
// MyFeature enables the experimental feature.
// owner: @datum-cloud/platform
// alpha: v0.1.0

// AFTER
// MyFeature enables the feature.
// owner: @datum-cloud/platform
// alpha: v0.1.0
// beta: v0.3.0
```

**Migration Notes:**
- Announce in release notes that feature is now Beta
- Operators who explicitly disabled it will continue to have it disabled
- New deployments get the feature enabled by default

#### 7.2 Beta → GA Graduation

**Criteria:**
- Feature has been Beta for at least one release cycle
- No API changes required
- Proven stable in production
- Performance characteristics understood

**Code Changes:**

```go
// BEFORE (Beta)
var defaultFeatureGates = map[featuregate.Feature]featuregate.FeatureSpec{
    MyFeature: {
        Default:    true,
        PreRelease: featuregate.Beta,
    },
}

// AFTER (GA)
var defaultFeatureGates = map[featuregate.Feature]featuregate.FeatureSpec{
    MyFeature: {
        Default:    true,
        PreRelease: featuregate.GA,  // Empty string internally
    },
}
```

**Documentation Comment Update:**

```go
// MyFeature enables the feature.
// owner: @datum-cloud/platform
// alpha: v0.1.0
// beta: v0.3.0
// ga: v0.5.0
```

**Migration Notes:**
- Announce GA in release notes
- Feature can no longer be disabled via flag (warn in docs)
- Begin planning gate removal timeline

#### 7.3 GA → Gate Removal

**Criteria:**
- Feature has been GA for at least two release cycles
- No operators depend on disabling the feature
- Removal announced in advance

**Code Changes:**

```go
// BEFORE (GA with gate)
const (
    MyFeature featuregate.Feature = "MyFeature"
)

var defaultFeatureGates = map[featuregate.Feature]featuregate.FeatureSpec{
    MyFeature: {Default: true, PreRelease: featuregate.GA},
}

// Check in code
if utilfeature.DefaultFeatureGate.Enabled(features.MyFeature) {
    // feature code
}

// AFTER (Gate removed)
// 1. Remove the constant
// 2. Remove from defaultFeatureGates map
// 3. Remove all Enabled() checks - code runs unconditionally
// 4. Keep the feature code, just remove the conditional
```

**Process:**
1. Announce gate removal in release notes (N-1 release)
2. Remove gate in target release (N)
3. Clean up all `Enabled()` checks throughout codebase

#### 7.4 Deprecation Path (Alternative to GA)

For features that will be removed rather than graduated:

```go
const (
    // LegacyFeature enables the legacy behavior.
    // owner: @datum-cloud/platform
    // alpha: v0.1.0
    // deprecated: v0.4.0 (use NewFeature instead)
    LegacyFeature featuregate.Feature = "LegacyFeature"
)

var defaultFeatureGates = map[featuregate.Feature]featuregate.FeatureSpec{
    LegacyFeature: {
        Default:    false,
        PreRelease: featuregate.Deprecated,
    },
}
```

#### 7.5 Complete Lifecycle Example

```go
// Version 0.1.0 - Alpha
// MyFeature enables experimental widget support.
// owner: @datum-cloud/platform
// alpha: v0.1.0
MyFeature featuregate.Feature = "MyFeature"
// Spec: {Default: false, PreRelease: featuregate.Alpha}

// Version 0.3.0 - Beta (after production validation)
// MyFeature enables widget support.
// owner: @datum-cloud/platform
// alpha: v0.1.0
// beta: v0.3.0
// Spec: {Default: true, PreRelease: featuregate.Beta}

// Version 0.5.0 - GA (after stability period)
// MyFeature enables widget support.
// owner: @datum-cloud/platform
// alpha: v0.1.0
// beta: v0.3.0
// ga: v0.5.0
// Spec: {Default: true, PreRelease: featuregate.GA}

// Version 0.7.0 - Gate Removed
// No constant, no spec, no Enabled() checks
// Widget support code runs unconditionally
```

### 8. Naming Conventions

| Convention | Example | Anti-Pattern |
|------------|---------|--------------|
| PascalCase | `EventsProxy` | `eventsProxy` |
| No suffix | `Sessions` | `SessionsFeature` |
| Descriptive | `UserIdentities` | `UI` |

### 9. When to Use Feature Gates

**Use feature gates when:**
- Feature changes storage backend behavior
- Feature integrates with external systems
- Feature is experimental and may be removed
- Operators need runtime control

**Skip feature gates when:**
- Simple API additions with no behavioral changes
- Bug fixes
- Internal refactoring
- Features gated by other mechanisms (RBAC, admission)

### 10. Integration with Server Configuration

Link to `server-config.md` and show how feature checks integrate with:
- Options pattern
- CompletedConfig pattern
- Conditional storage provider initialization

---

## Updates to SKILL.md

Add to Key Files table:

```markdown
| `feature-gates.md` | Feature lifecycle management |
```

Add to Related Files:

```markdown
- `feature-gates.md` — Feature lifecycle patterns
```

---

## Updates to server-config.md

Add new section after "Options":

```markdown
## Feature Gates Integration

For managing experimental features with runtime toggles, see `feature-gates.md`.

Import features package to register gates via init():

\`\`\`go
import (
    _ "go.example.com/myservice/pkg/features"
)
\`\`\`

Check feature enablement in Config methods:

\`\`\`go
func (c *Config) Complete() CompletedConfig {
    if utilfeature.DefaultFeatureGate.Enabled(features.MyFeature) {
        // Initialize feature-specific configuration
    }
    return CompletedConfig{&completedConfig{c}}
}
\`\`\`
```

---

## Validation Criteria

Implementation is complete when:

1. `feature-gates.md` contains all 10 sections above
2. Feature graduation section includes code examples for each transition
3. Complete lifecycle example shows same feature at all stages
4. `SKILL.md` references feature-gates.md in table and related files
5. `server-config.md` includes Feature Gates Integration section
6. All code examples are self-contained and copy-pasteable

---

## Implementation Notes for Tech Writer

1. Use Milo's `pkg/features/features.go` as the reference for all examples
2. Adapt examples to use generic names (`MyFeature`, `MyService`) for documentation
3. Keep consistent code style with existing skill files
4. Cross-reference between files using relative links
5. Include the `LockToDefault` field in FeatureSpec documentation (used for truly immutable features)
