---
name: commercial-models
description: Covers pricing frameworks and commercial patterns including usage-based, subscription, and hybrid models. Use when designing pricing tiers, migration strategies, or assessing commercial viability of features.
---

# Commercial Models

This skill covers pricing frameworks and commercial patterns for Datum Cloud services.

## Pricing Models

### Usage-Based

Charge based on consumption:

| Model | Unit | Example |
|-------|------|---------|
| Per-request | API call | $0.001 per request |
| Per-resource-hour | Time × count | $0.05 per VM-hour |
| Per-unit | GB, CPU, etc. | $0.10 per GB |

**Best for**: Variable consumption, pay-as-you-go

### Subscription

Fixed recurring charge:

| Tier | Price | Includes |
|------|-------|----------|
| Free | $0 | Limited features, quota |
| Pro | $99/mo | Full features, higher quota |
| Enterprise | Custom | Everything + support |

**Best for**: Predictable revenue, committed customers

### Hybrid

Subscription + usage overage:

```
Base: $99/month (includes 1000 requests)
Overage: $0.01 per request over 1000
```

**Best for**: Baseline predictability with growth flexibility

## Tier Design

### Free Tier

Purpose: Evaluation and adoption

Design principles:
- Enough to build a meaningful demo
- Time-limited or feature-limited (not both)
- Clear upgrade path
- No credit card required

### Pro Tier

Purpose: Production workloads

Design principles:
- Price anchored to value delivered
- Generous quota (upgrade trigger = growth)
- Standard support included
- Monthly or annual plans

### Enterprise Tier

Purpose: Large organizations

Design principles:
- Custom pricing via sales
- Committed spend discounts
- Dedicated support
- Custom SLAs
- Volume discounts

## Pricing Psychology

### Anchoring

Show the most expensive option first to anchor perception.

### Value Framing

Frame price in terms of value, not cost:
- "Saves 10 hours/week" not "$50/month"

### Round Numbers

Use round numbers for simplicity:
- $99 not $97.43
- $0.10 not $0.0973

### Predictability

Consumers value bill predictability:
- Offer spend caps
- Provide usage dashboards
- Send alerts before overages

## Migration Strategies

### Grandfathering

Keep existing customers on old pricing:
- Simple to implement
- Creates legacy complexity
- Use for major changes

### Gradual Transition

Move customers over time:
- 30-60-90 day notice
- Discount during transition
- Clear communication

### Hard Cutover

Switch everyone at once:
- Clean, simple
- Risk of churn
- Use for minor changes

## Related Skills

- `capability-quota` — Quota implementation
