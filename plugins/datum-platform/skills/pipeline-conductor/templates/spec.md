---
handoff:
  id: feat-XXX
  from: product-planner
  to: [architect, commercial-strategist]
  created: YYYY-MM-DDTHH:MM:SSZ

  context_summary: |
    [1-3 sentence summary of the specification scope and key requirements]

  decisions_made:
    - decision: "[Key requirement decision]"
      rationale: "[Why this requirement was prioritized/shaped this way]"
      alternatives_considered:
        - "[Alternative approach]"

  open_questions:
    - question: "[Technical question for architect]"
      context: "[Why this affects the spec]"
      blocking: false
      suggested_owner: architect

  assumptions:
    - assumption: "[Assumption about user behavior or system constraints]"
      confidence: medium
      validation_needed: true

  dependencies:
    upstream:
      - artifact: "briefs/feat-XXX-{name}.md"
        relationship: "derived_from"
    downstream:
      - artifact: "designs/feat-XXX-{name}.md"
        relationship: "enables"

  platform_capabilities:
    quota:
      applies: false
      rationale: "[Inherited from discovery or refined]"
    insights:
      applies: false
      rationale: "[Inherited from discovery or refined]"
    telemetry:
      applies: false
      rationale: "[Inherited from discovery or refined]"
    activity:
      applies: false
      rationale: "[Inherited from discovery or refined]"
---

# Specification: [Feature Name]

**ID**: feat-XXX
**Date**: YYYY-MM-DD
**Author**: [Product planner]
**Status**: Draft | In Review | Approved

## Overview

[High-level description of what this feature does and why it matters]

## User Stories

### Primary User Story

**As a** [user type]
**I want to** [action]
**So that** [benefit]

### Additional User Stories

- As a [user], I want to [action] so that [benefit]
- As a [user], I want to [action] so that [benefit]

## Functional Requirements

### FR-1: [Requirement Name]

**Priority**: Must Have | Should Have | Nice to Have
**Description**: [Detailed description]
**Acceptance Criteria**:
- [ ] [Criterion 1]
- [ ] [Criterion 2]

### FR-2: [Requirement Name]

**Priority**: Must Have | Should Have | Nice to Have
**Description**: [Detailed description]
**Acceptance Criteria**:
- [ ] [Criterion 1]
- [ ] [Criterion 2]

## Non-Functional Requirements

### NFR-1: Performance

- [Performance requirement with measurable target]

### NFR-2: Security

- [Security requirement]

### NFR-3: Scalability

- [Scalability requirement with scale targets]

## API Changes

### New Endpoints

| Method | Path | Description |
|--------|------|-------------|
| POST | /api/v1/... | [Description] |
| GET | /api/v1/... | [Description] |

### Modified Endpoints

| Method | Path | Change |
|--------|------|--------|
| ... | ... | ... |

### New Resource Types

```yaml
apiVersion: [group]/v1alpha1
kind: [ResourceName]
metadata:
  name: [example]
spec:
  # [Field descriptions]
status:
  # [Status field descriptions]
```

## Data Model Changes

### New Fields

| Resource | Field | Type | Description |
|----------|-------|------|-------------|
| ... | ... | ... | ... |

### Schema Changes

[Description of schema migrations or changes]

## UI/UX Requirements

### Wireframes

[Link to wireframes or inline descriptions]

### User Flows

1. [Step 1]
2. [Step 2]
3. [Step 3]

## Out of Scope

- [Explicitly excluded item 1]
- [Explicitly excluded item 2]

## Dependencies

### Internal Dependencies

- [Dependency on other team/service]

### External Dependencies

- [Dependency on third-party service]

## Risks and Mitigations

| Risk | Likelihood | Impact | Mitigation |
|------|------------|--------|------------|
| [Risk] | High/Medium/Low | High/Medium/Low | [Mitigation] |

## Success Metrics

| Metric | Target | Measurement Method |
|--------|--------|-------------------|
| [Metric] | [Target] | [How to measure] |

## Next Steps

- [ ] Architecture review (architect)
- [ ] Pricing review (commercial-strategist)
- [ ] Human approval gate
