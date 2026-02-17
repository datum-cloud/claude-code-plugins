---
handoff:
  id: feat-XXX
  from: architect
  to: [api-dev, frontend-dev, sre, test-engineer]
  created: YYYY-MM-DDTHH:MM:SSZ

  context_summary: |
    [1-3 sentence summary of the architecture approach and key design decisions]

  decisions_made:
    - decision: "[Key architecture decision]"
      rationale: "[Why this approach was chosen]"
      alternatives_considered:
        - "[Alternative architecture]"
        - "[Alternative architecture]"

  open_questions:
    - question: "[Implementation detail question]"
      context: "[Why this affects implementation]"
      blocking: false
      suggested_owner: api-dev

  assumptions:
    - assumption: "[Technical assumption]"
      confidence: high
      validation_needed: false

  dependencies:
    upstream:
      - artifact: "specs/feat-XXX-{name}.md"
        relationship: "derived_from"
      - artifact: "pricing/feat-XXX-{name}.md"
        relationship: "references"
    downstream:
      - artifact: "code changes"
        relationship: "enables"

  platform_capabilities:
    quota:
      applies: true
      rationale: "[Integration approach defined below]"
    insights:
      applies: true
      rationale: "[Integration approach defined below]"
    telemetry:
      applies: true
      rationale: "[Integration approach defined below]"
    activity:
      applies: true
      rationale: "[Integration approach defined below]"
---

# Architecture Design: [Feature Name]

**ID**: feat-XXX
**Date**: YYYY-MM-DD
**Author**: [Architect]
**Status**: Draft | In Review | Approved

## Overview

[High-level description of the architecture approach]

### Goals

- [Goal 1]
- [Goal 2]

### Non-Goals

- [Non-goal 1]
- [Non-goal 2]

## Architecture Overview

### System Context

```
[ASCII diagram or description of how this feature fits into the broader system]
```

### Component Diagram

```
┌─────────────────────────────────────────────────────────────┐
│                      [Component Name]                        │
├─────────────────────────────────────────────────────────────┤
│  [Subcomponent 1]  │  [Subcomponent 2]  │  [Subcomponent 3] │
└─────────────────────────────────────────────────────────────┘
          │                    │                    │
          ▼                    ▼                    ▼
    [Dependency 1]       [Dependency 2]       [Dependency 3]
```

## API Design

### Resource Types

#### [ResourceName]

```go
// +kubebuilder:object:root=true
// +kubebuilder:subresource:status
// +kubebuilder:printcolumn:name="Status",type="string",JSONPath=".status.phase"
type ResourceName struct {
    metav1.TypeMeta   `json:",inline"`
    metav1.ObjectMeta `json:"metadata,omitempty"`

    Spec   ResourceNameSpec   `json:"spec,omitempty"`
    Status ResourceNameStatus `json:"status,omitempty"`
}

type ResourceNameSpec struct {
    // Field description
    // +kubebuilder:validation:Required
    Field string `json:"field"`
}

type ResourceNameStatus struct {
    // Phase of the resource
    Phase string `json:"phase,omitempty"`

    // Conditions for the resource
    Conditions []metav1.Condition `json:"conditions,omitempty"`
}
```

### API Endpoints

| Method | Path | Description | Request | Response |
|--------|------|-------------|---------|----------|
| POST | `/apis/{group}/v1alpha1/namespaces/{ns}/{resources}` | Create | ResourceName | ResourceName |
| GET | `/apis/{group}/v1alpha1/namespaces/{ns}/{resources}/{name}` | Get | - | ResourceName |
| PUT | `/apis/{group}/v1alpha1/namespaces/{ns}/{resources}/{name}` | Update | ResourceName | ResourceName |
| DELETE | `/apis/{group}/v1alpha1/namespaces/{ns}/{resources}/{name}` | Delete | - | - |
| GET | `/apis/{group}/v1alpha1/namespaces/{ns}/{resources}` | List | - | ResourceNameList |

### Validation Rules

| Field | Rule | Error Message |
|-------|------|---------------|
| `spec.field` | Required, non-empty | "field is required" |
| `spec.field` | Max length 253 | "field must be at most 253 characters" |

## Storage Design

### Storage Backend

[Description of storage approach: etcd, external database, etc.]

### Schema

```sql
-- If using external storage
CREATE TABLE resource_names (
    id UUID PRIMARY KEY,
    namespace VARCHAR(253) NOT NULL,
    name VARCHAR(253) NOT NULL,
    spec JSONB NOT NULL,
    status JSONB,
    created_at TIMESTAMP NOT NULL,
    updated_at TIMESTAMP NOT NULL,
    UNIQUE(namespace, name)
);
```

### Data Flow

1. [Step 1 of data flow]
2. [Step 2 of data flow]
3. [Step 3 of data flow]

## Component Changes

### New Components

| Component | Purpose | Owner |
|-----------|---------|-------|
| [Component] | [Purpose] | api-dev |

### Modified Components

| Component | Change | Owner |
|-----------|--------|-------|
| [Component] | [Change description] | api-dev |

### File Changes

| File | Change Type | Description |
|------|-------------|-------------|
| `pkg/apis/{group}/v1alpha1/types.go` | Add | New resource types |
| `pkg/registry/{resource}/strategy.go` | Add | Storage strategy |
| `pkg/apis/{group}/v1alpha1/validation.go` | Add | Validation logic |

## Platform Integrations

### Quota Integration

**Bucket**: `{resource}-limits`
**Dimensions**:
- `{resource}.count`: Number of resources per project

**Implementation**:
1. Check quota before resource creation
2. Increment on successful creation
3. Decrement on deletion
4. Handle quota exceeded error with clear message

See `capability-quota/implementation.md` for patterns.

### Insights Integration

**Detector**: `{resource}-health`
**Conditions**:
- Orphaned resources (no parent reference)
- Stale resources (not updated in X days)

**Implementation**:
1. Register InsightPolicy for the resource type
2. Implement CEL conditions for detection
3. Provide remediation suggestions

See `capability-insights/implementation.md` for patterns.

### Telemetry Integration

**Metrics**:
- `{resource}_total`: Total count by namespace
- `{resource}_operations_total`: Operations by type (create/update/delete)
- `{resource}_operation_duration_seconds`: Operation latency histogram

**Implementation**:
1. Register metrics in registry
2. Instrument storage operations
3. Add namespace and operation labels

See `capability-telemetry/implementation.md` for patterns.

### Activity Integration

**Events**:
- `{resource}.created`: Resource created
- `{resource}.updated`: Resource updated
- `{resource}.deleted`: Resource deleted

**Implementation**:
1. Emit events from storage strategy
2. Include actor, resource reference, summary
3. Support activity timeline queries

See `capability-activity/implementation.md` for patterns.

## Migration Plan

### Schema Migration

[Description of any schema changes and migration approach]

### Data Migration

[Description of any data migration needed]

### Rollback Plan

[How to rollback if deployment fails]

## Security Considerations

### Authentication

[How authentication is handled]

### Authorization

| Action | Required Permission |
|--------|---------------------|
| Create | `{resource}.create` |
| Get | `{resource}.get` |
| Update | `{resource}.update` |
| Delete | `{resource}.delete` |
| List | `{resource}.list` |

### Data Protection

[Encryption, PII handling, etc.]

## Testing Strategy

### Unit Tests

| Component | Test Focus |
|-----------|------------|
| Types | Validation, defaulting |
| Strategy | CRUD operations, error handling |
| Quota | Limit enforcement, edge cases |

### Integration Tests

| Scenario | Description |
|----------|-------------|
| [Scenario] | [Description] |

### E2E Tests

| User Flow | Steps |
|-----------|-------|
| [Flow] | [Steps] |

## Performance Considerations

### Expected Load

| Metric | Expected | Peak |
|--------|----------|------|
| Requests/sec | [value] | [value] |
| Storage size | [value] | [value] |

### Optimization Opportunities

- [Optimization 1]
- [Optimization 2]

## Implementation Phases

### Phase 1: Core Implementation

- [ ] Resource types and validation
- [ ] Storage strategy
- [ ] Basic CRUD operations
- [ ] Unit tests

**Owner**: api-dev

### Phase 2: Platform Integration

- [ ] Quota integration
- [ ] Activity events
- [ ] Telemetry metrics

**Owner**: api-dev

### Phase 3: Insights

- [ ] InsightPolicy rules
- [ ] Detector implementation

**Owner**: api-dev

### Phase 4: UI

- [ ] List view
- [ ] Detail view
- [ ] Create/Edit forms

**Owner**: frontend-dev

### Phase 5: Infrastructure

- [ ] Kustomize configuration
- [ ] Deployment manifests
- [ ] Monitoring dashboards

**Owner**: sre

## Next Steps

- [ ] Implementation by api-dev, frontend-dev, sre (parallel)
- [ ] Testing by test-engineer
- [ ] Review by code-reviewer
