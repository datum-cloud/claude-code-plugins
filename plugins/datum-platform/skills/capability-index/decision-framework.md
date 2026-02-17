# Capability Decision Framework

Quick reference for determining which platform capabilities apply to a feature.

## Decision Tree

```
Is this a new resource type?
├── Yes → Evaluate ALL four capabilities
└── No
    ├── Can it be exhausted/abused? → Quota
    ├── Can platform detect issues early? → Insights
    ├── Does it have runtime behavior? → Telemetry
    └── Does it mutate state? → Activity
```

## Quick Assessment Matrix

| Feature Type | Quota | Insights | Telemetry | Activity |
|--------------|-------|----------|-----------|----------|
| New resource | ✓ | ✓ | ✓ | ✓ |
| New operation | Maybe | Maybe | ✓ | ✓ |
| UI feature | - | - | Maybe | - |
| Config change | - | - | ✓ | ✓ |
| Performance fix | - | - | ✓ | - |
| Bug fix | - | - | Maybe | - |

## Red Flags

Watch for these situations that often indicate missing capability integration:

| Situation | Missing Capability |
|-----------|-------------------|
| "We can't tell if this is being used" | Telemetry |
| "Someone used all the capacity" | Quota |
| "We didn't know there was a problem" | Insights |
| "We can't tell who did this" | Activity |

## Capability Integration Checklist

Before marking a feature complete, verify:

- [ ] Quota: Limits enforced if consumable
- [ ] Insights: InsightPolicy created if issues can be detected
- [ ] Telemetry: Metrics emitting if observable
- [ ] Activity: ActivityPolicy created if operations should be auditable
