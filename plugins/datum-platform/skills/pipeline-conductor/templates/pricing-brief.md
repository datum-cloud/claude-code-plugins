---
handoff:
  id: feat-XXX
  from: commercial-strategist
  to: [architect]
  created: YYYY-MM-DDTHH:MM:SSZ

  context_summary: |
    [1-3 sentence summary of pricing strategy and key commercial decisions]

  decisions_made:
    - decision: "[Tier boundary decision]"
      rationale: "[Why this tier structure makes sense]"
      alternatives_considered:
        - "[Alternative pricing model]"

    - decision: "[Quota default decision]"
      rationale: "[Why these limits are appropriate]"
      alternatives_considered:
        - "[Higher/lower limits considered]"

  open_questions:
    - question: "[Question for architect about implementation cost]"
      context: "[How this affects pricing model]"
      blocking: false
      suggested_owner: architect

  assumptions:
    - assumption: "[Usage pattern assumption]"
      confidence: medium
      validation_needed: true

  dependencies:
    upstream:
      - artifact: "briefs/feat-XXX-{name}.md"
        relationship: "derived_from"
      - artifact: "specs/feat-XXX-{name}.md"
        relationship: "references"
    downstream:
      - artifact: "designs/feat-XXX-{name}.md"
        relationship: "informs"

  platform_capabilities:
    quota:
      applies: true
      rationale: "[Quota strategy defined in this document]"
    insights:
      applies: false
      rationale: "[From discovery]"
    telemetry:
      applies: false
      rationale: "[From discovery]"
    activity:
      applies: false
      rationale: "[From discovery]"
---

# Pricing Brief: [Feature Name]

**ID**: feat-XXX
**Date**: YYYY-MM-DD
**Author**: [Commercial strategist]
**Status**: Draft | In Review | Approved

## Executive Summary

[2-3 sentence summary of the pricing recommendation]

## Feature Context

### Feature Description

[Brief description of the feature being priced]

### Target Users

| User Segment | Use Case | Volume Expectation |
|--------------|----------|-------------------|
| [Segment] | [Use case] | [Expected usage] |

## Tier Strategy

### Tier Placement

| Tier | Access | Rationale |
|------|--------|-----------|
| Free | [Full/Limited/None] | [Why] |
| Pro | [Full/Limited/None] | [Why] |
| Enterprise | [Full/Limited/None] | [Why] |

### Feature Matrix

| Capability | Free | Pro | Enterprise |
|------------|------|-----|------------|
| [Capability 1] | [Limit/Yes/No] | [Limit/Yes/No] | [Limit/Yes/No] |
| [Capability 2] | [Limit/Yes/No] | [Limit/Yes/No] | [Limit/Yes/No] |

## Quota Recommendations

### Quota Dimensions

| Dimension | Unit | Free | Pro | Enterprise | Rationale |
|-----------|------|------|-----|------------|-----------|
| [Dimension 1] | [unit] | [limit] | [limit] | [limit] | [Why these limits] |
| [Dimension 2] | [unit] | [limit] | [limit] | [limit] | [Why these limits] |

### Quota Behavior

| Scenario | Behavior |
|----------|----------|
| Approaching limit (80%) | [Notification/Warning] |
| At limit | [Block/Degrade/Notify] |
| Burst allowance | [Yes/No, if yes: amount] |

### AllowanceBucket Configuration

```yaml
apiVersion: quota.datumapis.com/v1alpha1
kind: AllowanceBucket
metadata:
  name: [feature]-limits
spec:
  dimensions:
    - name: [dimension]
      unit: [unit]
      defaults:
        free: [value]
        pro: [value]
        enterprise: [value]
```

## Commercial Impact

### Revenue Impact

| Scenario | Impact | Confidence |
|----------|--------|------------|
| New revenue from feature | [Estimate] | [High/Medium/Low] |
| Upgrade pressure created | [Estimate] | [High/Medium/Low] |
| Churn risk if not implemented | [Estimate] | [High/Medium/Low] |

### Cost Considerations

| Cost Factor | Estimate | Notes |
|-------------|----------|-------|
| Infrastructure cost per unit | [Estimate] | [Notes] |
| Support burden | [Estimate] | [Notes] |
| Margin at each tier | [Estimate] | [Notes] |

## Migration Path

### Existing Customers

| Scenario | Treatment |
|----------|-----------|
| Free tier customers | [Grandfathered/Migrated/Limited] |
| Pro tier customers | [Grandfathered/Migrated/Limited] |
| Enterprise customers | [Grandfathered/Migrated/Limited] |

### Communication Plan

- [How existing customers will be notified]
- [Timeline for migration]
- [Opt-out or appeal process]

## Competitive Analysis

| Competitor | Approach | Our Differentiation |
|------------|----------|---------------------|
| [Competitor 1] | [Their approach] | [How we differ] |
| [Competitor 2] | [Their approach] | [How we differ] |

## Risks and Mitigations

| Risk | Likelihood | Impact | Mitigation |
|------|------------|--------|------------|
| Limits feel too restrictive | Medium | High | [Mitigation] |
| Pricing inconsistent with similar features | Low | Medium | [Mitigation] |
| Migration causes customer complaints | Medium | Medium | [Mitigation] |

## Recommendations

### Primary Recommendation

[Clear statement of recommended pricing approach]

### Alternative Options

1. **Option A**: [Description]
   - Pros: ...
   - Cons: ...

2. **Option B**: [Description]
   - Pros: ...
   - Cons: ...

## Service Profile Updates

Update `.claude/service-profile.md` with:

```yaml
quota:
  enabled: true
  dimensions:
    - name: [dimension]
      unit: [unit]
      tiers:
        free: [value]
        pro: [value]
        enterprise: [value]
```

## Next Steps

- [ ] Review with architect for implementation feasibility
- [ ] Human approval gate
- [ ] Update service profile after approval
