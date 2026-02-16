# Capability: Insights

This skill covers insights integration for Datum Cloud services using the Insights system.

## Overview

The Insights system is a **declarative, policy-driven, Kubernetes-native** platform for proactively detecting issues in resources. It provides:

- **Policy-driven detection** — CEL-based rules evaluate resource state to identify issues
- **Lifecycle management** — Insights can be acknowledged, snoozed, assigned, and resolved
- **Muting capabilities** — Suppress known/expected insights with mute rules
- **Multi-tenant scoping** — Insights scoped to organization, project, or namespace

**Key insight**: Services don't detect issues programmatically. Instead, services define `InsightPolicy` resources with CEL expressions that describe what conditions warrant an insight.

## API Group

All insights resources use the `insights.miloapis.com` API group with version `v1alpha1`.

## Core Resource Types

The insights system has **three resource types**:

| Resource | Scope | Purpose |
|----------|-------|---------|
| **Insight** | Namespaced | A detected issue or finding about a resource |
| **InsightPolicy** | Namespaced | CEL-based rules that generate insights automatically |
| **InsightMuteRule** | Namespaced | Suppress insights matching certain criteria |

## How Services Integrate

Services integrate by creating **InsightPolicy** resources that define rules for detecting issues. The insights system automatically:

1. Watches resources matching the policy's target selector
2. Evaluates CEL conditions against each resource
3. Creates `Insight` resources when conditions match
4. Resolves insights when conditions no longer match

### What Services DO

- **Create InsightPolicy** resources for their resource types
- **Define CEL-based conditions** that identify issues
- **Write human-readable message templates** using CEL expressions

### What Services DON'T DO

- Emit insights programmatically (the Insights controller creates them)
- Manage insight lifecycle (users/automation handles acknowledgement, resolution)
- Handle insight storage or retention

---

## Quick Start: Creating an InsightPolicy

### Step 1: Define Policy for Your Resource

```yaml
apiVersion: insights.miloapis.com/v1alpha1
kind: InsightPolicy
metadata:
  name: myresource-config-issues
  namespace: myservice-system
spec:
  targetSelector:
    apiVersion: myservice.miloapis.com/v1alpha1
    kind: MyResource
  rules:
    - name: config-conflict
      condition: "object.spec.fieldA == 'value1' && object.spec.fieldB == 'incompatible'"
      severity: warning
      category: configuration
      message: "MyResource {{ object.metadata.name }} has conflicting configuration"
      description: "fieldA is set to 'value1' which is incompatible with fieldB 'incompatible'. Set fieldB to 'compatible' to resolve."

    - name: missing-required-field
      condition: "!has(object.spec.requiredField) || object.spec.requiredField == ''"
      severity: critical
      category: configuration
      message: "MyResource {{ object.metadata.name }} is missing required field"
      description: "The requiredField must be set for the resource to function correctly."
```

### Step 2: Add to Kustomization

```yaml
# config/insights/kustomization.yaml
resources:
  - myresource-config-issues.yaml
```

### Step 3: Verify Policy is Active

```bash
kubectl get insightpolicies -n myservice-system
kubectl get insights -A  # See generated insights
```

---

## InsightPolicy Reference

### Spec Fields

| Field | Type | Description |
|-------|------|-------------|
| `targetSelector` | TargetSelector | Which resources this policy applies to |
| `rules` | []InsightRule | Rules that generate insights |
| `suspended` | bool | Stops generating new insights when true |

### TargetSelector

```yaml
targetSelector:
  apiVersion: myservice.miloapis.com/v1alpha1
  kind: MyResource
  labelSelector:           # Optional: filter by labels
    matchLabels:
      environment: production
  namespaces:              # Optional: limit to specific namespaces
    - production
    - staging
```

### InsightRule

| Field | Type | Description |
|-------|------|-------------|
| `name` | string | Unique identifier for the rule (lowercase, hyphenated) |
| `condition` | string | CEL expression that returns true when insight should exist |
| `severity` | enum | `info`, `warning`, or `critical` |
| `category` | string | Classification (e.g., `configuration`, `security`, `performance`) |
| `message` | string | Short summary with CEL template support `{{ expr }}` |
| `description` | string | Detailed explanation with CEL template support |
| `ttlSeconds` | int64 | Optional time-to-live for generated insights |

### CEL Expression Context

In `condition`, `message`, and `description` expressions:

| Variable | Description |
|----------|-------------|
| `object` | The resource being evaluated |
| `object.metadata` | Resource metadata (name, namespace, labels, etc.) |
| `object.spec` | Resource spec |
| `object.status` | Resource status |

---

## Insight Resource

Insights are created automatically by InsightPolicy rules or manually.

### Insight Spec

```yaml
apiVersion: insights.miloapis.com/v1alpha1
kind: Insight
metadata:
  name: insight-abc123
  namespace: my-project
spec:
  targetRef:
    apiVersion: myservice.miloapis.com/v1alpha1
    kind: MyResource
    name: my-resource
    namespace: my-project
  severity: warning
  category: configuration
  message: "MyResource my-resource has conflicting configuration"
  description: "fieldA is set to 'value1' which is incompatible..."
  source:
    type: Policy
    policyRef:
      name: myresource-config-issues
      namespace: myservice-system
      ruleName: config-conflict
  ttlSeconds: 0  # 0 = never expires
```

### Insight Status

```yaml
status:
  state: Active              # Active, Acknowledged, Snoozed, Resolved
  owner:                     # Who is responsible
    type: user
    name: alice@example.com
  acknowledgement:           # If acknowledged
    by: { type: user, name: alice@example.com }
    at: "2024-01-15T10:00:00Z"
    note: "Looking into this"
  snooze:                    # If snoozed
    by: { type: user, name: bob@example.com }
    at: "2024-01-15T10:00:00Z"
    until: "2024-01-16T10:00:00Z"
  assignment:                # If assigned
    by: { type: user, name: alice@example.com }
    to: { type: user, name: bob@example.com }
    at: "2024-01-15T10:00:00Z"
  resolution:                # If resolved
    by: { type: user, name: bob@example.com }
    at: "2024-01-16T10:00:00Z"
    note: "Fixed the configuration"
  muted: false               # Whether muted by a mute rule
  targetExists: true         # Whether target resource still exists
```

### Insight States

| State | Meaning |
|-------|---------|
| `Active` | Issue detected and needs attention |
| `Acknowledged` | Someone has seen it and is aware |
| `Snoozed` | Temporarily suppressed until a specified time |
| `Resolved` | Issue has been addressed |

### Severity Levels

| Severity | Meaning | Typical Use |
|----------|---------|-------------|
| `info` | Informational, optimization opportunity | Underutilization, cost savings |
| `warning` | Should address soon | Misconfigurations, deprecations |
| `critical` | Immediate action required | Security issues, failures |

---

## Insight Actions (Subresources)

Users interact with insights via subresources:

### Acknowledge

```bash
kubectl patch insight insight-abc123 --subresource=acknowledge \
  --type=merge -p '{"note": "I am looking into this"}'
```

### Snooze

```bash
kubectl patch insight insight-abc123 --subresource=snooze \
  --type=merge -p '{"duration": "4h"}'  # or {"until": "2024-01-16T10:00:00Z"}
```

### Resolve

```bash
kubectl patch insight insight-abc123 --subresource=resolve \
  --type=merge -p '{"note": "Fixed the configuration"}'
```

### Assign

```bash
kubectl patch insight insight-abc123 --subresource=assign \
  --type=merge -p '{"assignee": {"type": "user", "name": "bob@example.com"}}'
```

---

## InsightMuteRule

Suppress insights that are known or expected.

### Example: Mute All Info-Level Insights in Dev

```yaml
apiVersion: insights.miloapis.com/v1alpha1
kind: InsightMuteRule
metadata:
  name: mute-dev-info
  namespace: development
spec:
  match:
    severity: info
  reason: "Development namespace - info-level insights expected"
```

### Example: Mute Specific Policy Rule

```yaml
apiVersion: insights.miloapis.com/v1alpha1
kind: InsightMuteRule
metadata:
  name: mute-known-issue
  namespace: my-project
spec:
  match:
    policyRef:
      name: myresource-config-issues
      namespace: myservice-system
      ruleName: config-conflict
  reason: "Known issue, fix scheduled for next sprint"
  expiresAt: "2024-02-01T00:00:00Z"  # Auto-expires
```

### Match Criteria

| Field | Description |
|-------|-------------|
| `policyRef` | Mute insights from specific policy/rule |
| `category` | Mute insights of a specific category |
| `targetRef` | Mute insights about a specific resource |
| `severity` | Mute insights at or below this severity |
| `labelSelector` | Mute insights matching labels |

---

## Common Policy Patterns

### Configuration Validation

```yaml
rules:
  - name: invalid-replica-count
    condition: "object.spec.replicas < 1"
    severity: critical
    category: configuration
    message: "{{ object.kind }} {{ object.metadata.name }} has invalid replica count"
    description: "Replica count must be at least 1. Current value: {{ object.spec.replicas }}"
```

### Status Condition Checks

```yaml
rules:
  - name: not-ready
    condition: |
      object.status.conditions.exists(c,
        c.type == 'Ready' && c.status == 'False' &&
        timestamp(c.lastTransitionTime) < now() - duration('10m')
      )
    severity: warning
    category: health
    message: "{{ object.kind }} {{ object.metadata.name }} has been not ready for over 10 minutes"
```

### Security Issues

```yaml
rules:
  - name: privileged-container
    condition: "object.spec.template.spec.containers.exists(c, c.securityContext.privileged == true)"
    severity: critical
    category: security
    message: "{{ object.kind }} {{ object.metadata.name }} uses privileged containers"
    description: "Privileged containers are a security risk. Consider using specific capabilities instead."
```

### Resource Optimization

```yaml
rules:
  - name: no-resource-limits
    condition: |
      object.spec.template.spec.containers.exists(c,
        !has(c.resources.limits) || !has(c.resources.limits.memory)
      )
    severity: info
    category: optimization
    message: "{{ object.kind }} {{ object.metadata.name }} has containers without memory limits"
```

---

## Service Integration Guide

### 1. Identify Detection Opportunities

Ask:
- What misconfigurations are common?
- What health issues can be detected early?
- What security concerns should be flagged?
- What optimization opportunities exist?

### 2. Create InsightPolicy Resources

Create policy files in `config/insights/`:

```
config/
└── insights/
    ├── kustomization.yaml
    ├── myresource-config.yaml      # Configuration issues
    ├── myresource-health.yaml      # Health checks
    └── myresource-security.yaml    # Security concerns
```

### 3. Define Categories

Use consistent categories across your service:

| Category | Use For |
|----------|---------|
| `configuration` | Invalid settings, conflicts |
| `security` | Security misconfigurations |
| `health` | Failures, degraded state |
| `performance` | Performance concerns |
| `optimization` | Cost savings, efficiency |
| `compliance` | Policy violations |

### 4. Include in Kustomization

```yaml
# config/base/kustomization.yaml
resources:
  - deployment.yaml
  - service.yaml

# Include insights policies
components:
  - ../insights
```

---

## Querying Insights

### List All Insights

```bash
kubectl get insights -A
kubectl get insights -n my-project
```

### Filter by Severity

```bash
kubectl get insights -A --field-selector spec.severity=critical
```

### Filter by State

```bash
kubectl get insights -A --field-selector status.state=Active
```

### Watch for New Insights

```bash
kubectl get insights -A --watch
```

---

## Related Files

- `implementation.md` — Detailed policy creation guide
- `scripts/validate-insights.sh` — Validation script
- `scripts/scaffold-insights.sh` — Policy scaffolding script

## Related Skills

- `capability-activity` — Similar policy-driven model for activity timelines
- `k8s-apiserver-patterns` — For implementing the resources that insights monitor
