---
handoff:
  id: feat-XXX
  from: product-discovery
  to: [product-planner, commercial-strategist]
  created: YYYY-MM-DDTHH:MM:SSZ

  context_summary: |
    [1-3 sentence summary of the feature and its purpose]

  decisions_made:
    - decision: "[Key decision made during discovery]"
      rationale: "[Why this decision was made]"
      alternatives_considered:
        - "[Alternative 1]"
        - "[Alternative 2]"

  open_questions:
    - question: "[Question that needs resolution]"
      context: "[Why this matters]"
      blocking: true
      suggested_owner: product-planner

  assumptions:
    - assumption: "[What was assumed]"
      confidence: medium
      validation_needed: true

  dependencies:
    upstream:
      - artifact: "requests/feat-XXX-{name}.md"
        relationship: "derived_from"
    downstream:
      - artifact: "specs/feat-XXX-{name}.md"
        relationship: "enables"
      - artifact: "pricing/feat-XXX-{name}.md"
        relationship: "informs"

  platform_capabilities:
    quota:
      applies: false
      rationale: "[Why or why not]"
    insights:
      applies: false
      rationale: "[Why or why not]"
    telemetry:
      applies: false
      rationale: "[Why or why not]"
    activity:
      applies: false
      rationale: "[Why or why not]"
---

# Discovery Brief: [Feature Name]

**ID**: feat-XXX
**Date**: YYYY-MM-DD
**Author**: [Discovery lead]

## Problem Statement

[What is the actual problem being solved? Not the solution, but the underlying need.]

## Target Users

[Who specifically will use this? Be specific about roles and context.]

| User Type | Context | Frequency |
|-----------|---------|-----------|
| [Role] | [When/why they encounter this] | [How often] |

## Current State

[What happens today without this feature? What are the workarounds?]

## Scope Boundaries

### In Scope

- [Specific thing included]
- [Specific thing included]

### Out of Scope

- [Specific thing excluded]
- [Specific thing excluded]

### Future Considerations

- [Things that might come later]

## Success Criteria

[How will we know this worked? Ideally measurable.]

- [ ] [Criterion 1]
- [ ] [Criterion 2]

## Platform Capability Assessment

### Quota

- **Applies**: [Yes/No]
- **Rationale**: [Why or why not]
- **If yes**: [Dimensions to limit]

### Insights

- **Applies**: [Yes/No]
- **Rationale**: [Why or why not]
- **If yes**: [InsightPolicy rules to create, CEL conditions]

### Telemetry

- **Applies**: [Yes/No]
- **Rationale**: [Why or why not]
- **If yes**: [Metrics needed]

### Activity

- **Applies**: [Yes/No]
- **Rationale**: [Why or why not]
- **If yes**: [Events to emit]

## Open Questions

1. [Question that needs resolution before spec]
2. [Question that needs resolution before spec]

## Next Steps

- [ ] Resolve open questions
- [ ] Hand off to product-planner for spec
