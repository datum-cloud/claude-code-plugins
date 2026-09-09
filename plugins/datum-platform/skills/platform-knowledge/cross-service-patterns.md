# Cross-Service Design Patterns

This document captures the architectural principles that govern how services in the Datum Cloud platform relate to and depend on each other.

## Directed Dependency Principle

Dependencies between services must flow in one direction: **producers push into downstream APIs; downstream services do not watch upstream ones.**

When Service A's resources need to drive behavior in Service B:
- Service A's controller creates or updates resources in Service B's API
- Service B's controller only ever reconciles its own resources
- Service B has no knowledge of Service A's API

**Why**: Cross-watch coupling ties two operators' reconciliation loops together, making them harder to deploy, scale, and reason about independently. A projected resource in the downstream API is an explicit, auditable artifact — it's visible in the cluster and has its own status.

**Counter-pattern to avoid**: Service B watching Service A's CRDs directly. This creates a hidden runtime dependency that isn't expressed in either service's API.

```
✓ Correct
  Service A controller ──creates──▶ ServiceB/ResourceX

✗ Avoid
  Service B controller ──watches──▶ ServiceA/ResourceY
```

## Resource Projection Pattern

When one service's configuration should drive another service, the producing service projects that configuration as a concrete resource in the consuming service's API.

```
ServiceConfiguration (services.miloapis.com)
  └─ services controller reconciles
       └─ creates ServiceLevelObjective (telemetry.miloapis.com)
            └─ telemetry controller reconciles
                 └─ backend-specific configuration
```

The projected resource is:
- **Explicit** — visible in the cluster with its own metadata and status
- **Auditable** — creation, updates, and deletion are tracked
- **Decoupled at runtime** — the consuming operator can be unavailable; projected resources queue up and are reconciled when it recovers

The producing service imports the consuming service's Go types as a module dependency. This is an acceptable compile-time coupling; runtime coupling is what to avoid.

## Declaration vs. Evaluation Separation

Configuration resources declare **intent**. Runtime evaluation — whether the system is actually meeting that intent — is a separate concern owned by a different system.

| Concern | Owner | Example |
|---------|-------|---------|
| Declaring an SLO target | `ServiceConfiguration` | `spec.serviceLevelObjectives[].target: "99.9"` |
| Evaluating SLO compliance | Telemetry backend | Recording rules, burn-rate alerts |
| Surfacing violations | Alerting infrastructure | Alert firing, notification routing |

Mixing declaration and evaluation in the same resource creates a resource that reconciles against an external system it has no business querying, and produces confusing status churn on what should be a stable config object.

## Status Conditions Reflect Configuration Health Only

A configuration resource's status conditions should reflect whether **the configuration itself is valid and consistent** — not whether the runtime system is meeting the declared targets.

```
✓ Appropriate status condition
  type: SLOReferencesValid
  status: "True"
  reason: AllIndicatorsResolved
  message: "All SLO indicator references resolve to defined SLIs"

✗ Not appropriate
  type: SLOCompliant
  status: "False"
  reason: BurnRateTooHigh
  message: "Error budget burn rate exceeds threshold"
```

The second example belongs in a separate resource or alert, not on the config object. Config objects should be stable; runtime compliance state changes continuously.

## Inline Definitions vs. Separate CRDs

When a concept is **inherently per-resource** — it doesn't make sense outside the context of its owner — define it inline as a field, not as a separate CRD.

Promote to a separate CRD only when:
- The concept needs to be shared across multiple resource types
- The concept has its own independent lifecycle (create, update, delete independent of the owner)
- The concept needs its own RBAC surface

**Example**: SLIs on `ServiceConfiguration` are defined inline because they are always per-service and have no value outside of a specific service's configuration.

## Technology-Neutral APIs

API schemas should be **backend-agnostic**. Translation to specific backends (Prometheus, Datadog, OpenTelemetry, etc.) is a deployment and configuration concern owned by the consuming operator — not expressed in the API type.

```yaml
# ✓ Technology-neutral
spec:
  serviceLevelIndicators:
    - name: request-success-rate
      type: Ratio
      ratio:
        good: { metric: http_requests_total, filters: ['{code!~"5.."}'] }
        total: { metric: http_requests_total }

# ✗ Backend-coupled
spec:
  prometheus:
    recordingRules:
      - expr: sum(rate(http_requests_total{code!~"5.."}[5m]))
```

Backend-neutral APIs allow the platform to support multiple telemetry backends without API changes, and keep infrastructure-specific knowledge out of the service contract.
