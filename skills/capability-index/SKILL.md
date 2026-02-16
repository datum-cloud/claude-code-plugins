# Capability Index

This skill provides a decision framework for determining which platform capabilities a feature needs.

## The Four Capabilities

| Capability | Question to Ask | When to Use |
|------------|-----------------|-------------|
| **Quota** | What needs limits to prevent abuse? | Resource consumption |
| **Insights** | What can the platform detect that users can't? | Proactive issue detection |
| **Telemetry** | What do operators need to observe? | Debugging and SLOs |
| **Activity** | What actions need to be auditable? | Compliance and security |

## Decision Framework

### Step 1: Identify the Feature Type

| Feature Type | Likely Capabilities |
|--------------|---------------------|
| New resource type | All four |
| New API operation | Activity, Telemetry |
| UI feature only | Telemetry (maybe) |
| Configuration change | Activity |
| Performance improvement | Telemetry |

### Step 2: Ask the Capability Questions

#### Quota Questions

- Can this resource be exhausted or abused?
- What is the natural unit to limit? (count, size, rate)
- What are sensible defaults for Free, Pro, Enterprise?
- How do consumers request more quota?

**Skip quota if**: The resource is inherently limited by other means or has no abuse potential.

#### Insights Questions

- What can go wrong that the platform can detect before users notice?
- What patterns indicate misconfiguration?
- What thresholds signal problems?
- What CEL conditions can identify issues?

**Skip insights if**: Issues are immediately obvious to users or no early warning is possible.

**Note**: Insights uses a policy-driven model—services define `InsightPolicy` resources with CEL expressions that detect issues. No code changes are required to emit insights.

#### Telemetry Questions

- What metrics indicate health?
- What traces help debug issues?
- What logs are needed for troubleshooting?
- What SLOs could be defined?

**Skip telemetry if**: The feature has no runtime behavior to observe.

#### Activity Questions

- What resource operations need to appear in activity timelines?
- How should create/update/delete operations be summarized for users?
- What controller events represent user-visible state changes?
- What compliance requirements apply?
- How will users access activity timelines? (CLI, UI, API)

**Skip activity if**: The action has no security or compliance implications.

**Note**: Activity uses a policy-driven model—services define `ActivityPolicy` resources that translate audit logs and Kubernetes events into human-readable summaries. No code changes are required to emit activities.

Read `capability-activity/consuming-timelines.md` for how to expose activity timelines to users via CLI, UI, or API.

### Step 3: Document the Assessment

Use this template:

```markdown
## Platform Capability Assessment

### Quota
- **Applies**: Yes/No
- **Rationale**: Why or why not
- **If yes**: Dimensions to limit, tier defaults

### Insights
- **Applies**: Yes/No
- **Rationale**: Why or why not
- **If yes**: InsightPolicy rules to create, CEL conditions to evaluate

### Telemetry
- **Applies**: Yes/No
- **Rationale**: Why or why not
- **If yes**: Metrics, traces, logs needed

### Activity
- **Applies**: Yes/No
- **Rationale**: Why or why not
- **If yes**:
  - Resource kinds needing policies
  - Events to emit from controller (reason codes)
  - Key operations to surface in timelines
```

## Common Patterns

### New Resource Type

Almost always needs all four:
- **Quota**: Limit on count or aggregate size
- **Insights**: Configuration validation, health checks
- **Telemetry**: CRUD metrics, reconciliation traces
- **Activity**: Event emission from controller + ActivityPolicy for create/update/delete/events

### New Sub-Resource or Status

Usually needs:
- **Telemetry**: Status transition metrics
- **Activity**: Maybe (if security-relevant)

Usually skips:
- **Quota**: Covered by parent resource
- **Insights**: Covered by parent resource (usually)

### New API Operation

Usually needs:
- **Telemetry**: Operation latency, success/failure
- **Activity**: If it mutates state

Usually skips:
- **Quota**: Unless operation consumes resources
- **Insights**: Unless operation can fail in detectable ways

## Related Skills

- `capability-quota` — Detailed quota integration
- `capability-insights` — Detailed insights integration
- `capability-telemetry` — Detailed telemetry integration
- `capability-activity` — Detailed activity integration
