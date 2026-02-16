# Capability: Telemetry

This skill covers telemetry integration for Datum Cloud services.

## Overview

Telemetry enables services to emit observability data. The telemetry system handles:
- Metrics (numeric measurements over time)
- Traces (distributed request tracking)
- Logs (structured event records)

All telemetry follows OpenTelemetry conventions.

## Core Concepts

### Metrics

Numeric measurements with dimensions:

```go
// Counter - monotonically increasing
requests := meter.Int64Counter("myresource.requests.total")
requests.Add(ctx, 1, attribute.String("method", "create"))

// Gauge - point-in-time value
activeResources := meter.Int64UpDownCounter("myresource.active")
activeResources.Add(ctx, 1)

// Histogram - distribution of values
latency := meter.Float64Histogram("myresource.request.duration_seconds")
latency.Record(ctx, duration.Seconds())
```

### Traces

Request flow across services:

```go
ctx, span := tracer.Start(ctx, "CreateMyResource")
defer span.End()

span.SetAttributes(
    attribute.String("resource.name", name),
    attribute.String("resource.namespace", namespace),
)

if err != nil {
    span.RecordError(err)
    span.SetStatus(codes.Error, err.Error())
}
```

### Logs

Structured event records:

```go
logger.Info("resource created",
    "name", resource.Name,
    "namespace", resource.Namespace,
    "spec", resource.Spec,
)

logger.Error(err, "failed to create resource",
    "name", name,
)
```

## Naming Conventions

### Metric Names

Pattern: `{service}.{resource}.{measurement}[.{unit}]`

| Example | Description |
|---------|-------------|
| `compute.vm.requests.total` | Total VM API requests |
| `compute.vm.active` | Currently active VMs |
| `compute.vm.cpu.utilization.percent` | VM CPU utilization |
| `compute.vm.request.duration.seconds` | Request latency |

### Span Names

Pattern: `{Operation}{Resource}`

| Example | Description |
|---------|-------------|
| `CreateVirtualMachine` | Creating a VM |
| `ReconcileVirtualMachine` | Reconciling a VM |
| `ValidateVirtualMachine` | Validating a VM |

### Log Fields

Standard fields:
- `resource.name` — Resource name
- `resource.namespace` — Resource namespace
- `resource.apiVersion` — API version
- `resource.kind` — Resource kind
- `operation` — What was attempted
- `error` — Error if failed

## Implementation

Read `implementation.md` for:
- Setting up telemetry providers
- Instrumenting API handlers
- Adding custom metrics
- Trace context propagation

## Validation

Run `scripts/validate-metrics.sh` to verify:
- Metrics are registered
- Traces are emitted
- Naming conventions followed

## Related Files

- `implementation.md` — Integration guide
- `scripts/validate-metrics.sh` — Validation script
- `scripts/scaffold-telemetry.sh` — Scaffolding script
