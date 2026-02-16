# Controller-Runtime Patterns

This skill covers patterns for building Kubernetes controllers using controller-runtime with Milo's multi-cluster runtime provider.

## Overview

Datum Cloud services can use controller-runtime when:
- etcd storage is sufficient (no custom storage backend needed)
- Standard CRUD and reconciliation semantics fit the use case
- The service needs to operate across multiple project control planes

**Decision guidance**: Read `k8s-apiserver-patterns/architecture-decision.md` to understand when to use this approach vs aggregated API servers.

## Key Files

| File | Purpose |
|------|---------|
| `multicluster-provider.md` | Using Milo's multi-cluster runtime provider |
| `reconciler-patterns.md` | Standard reconciliation patterns |
| `status-conditions.md` | Status condition conventions |

## Milo Multi-Cluster Runtime

Milo provides a multi-cluster runtime provider that enables controllers to operate across the dynamic fleet of project control planes.

**Location**: `milo/pkg/multicluster-runtime/`

### Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                    Milo Control Plane                       │
│  ┌───────────────────────────────────────────────────────┐  │
│  │              Multi-Cluster Manager                    │  │
│  │  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐   │  │
│  │  │ Controller  │  │ Controller  │  │ Controller  │   │  │
│  │  └──────┬──────┘  └──────┬──────┘  └──────┬──────┘   │  │
│  └─────────│────────────────│────────────────│──────────┘  │
│            │                │                │              │
│            ▼                ▼                ▼              │
│  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐         │
│  │  Project A  │  │  Project B  │  │  Project C  │         │
│  │  Control    │  │  Control    │  │  Control    │         │
│  │  Plane      │  │  Plane      │  │  Plane      │         │
│  └─────────────┘  └─────────────┘  └─────────────┘         │
└─────────────────────────────────────────────────────────────┘
```

### Discovery Modes

| Mode | Setting | Connection | Best For |
|------|---------|------------|----------|
| Internal | `InternalServiceDiscovery: true` | `milo-apiserver.project-{name}.svc.cluster.local:6443` | Operators in infrastructure cluster |
| External | `InternalServiceDiscovery: false` | Via Milo API endpoint | Remote operators |

## Basic Setup

```go
import (
    "sigs.k8s.io/controller-runtime/pkg/manager"
    mcruntime "sigs.k8s.io/multicluster-runtime/pkg/manager"
    miloprovider "go.datum.net/milo/pkg/multicluster-runtime/milo"
)

func main() {
    // Create the multi-cluster manager
    mgr, err := mcruntime.New(cfg, mcruntime.Options{
        Scheme: scheme,
    })
    if err != nil {
        // handle error
    }

    // Create the Milo provider
    provider, err := miloprovider.New(mgr.GetClient(), miloprovider.Options{
        InternalServiceDiscovery: true,
    })
    if err != nil {
        // handle error
    }

    // Start provider - watches Projects and engages clusters
    go provider.Run(ctx, mgr)

    // Register controllers
    if err := (&MyReconciler{}).SetupWithManager(mgr); err != nil {
        // handle error
    }

    // Start manager
    if err := mgr.Start(ctx); err != nil {
        // handle error
    }
}
```

## Reconciler Pattern

```go
type MyResourceReconciler struct {
    client.Client
    Scheme *runtime.Scheme
}

func (r *MyResourceReconciler) Reconcile(ctx context.Context, req ctrl.Request) (ctrl.Result, error) {
    log := log.FromContext(ctx)

    // Fetch the resource
    var resource myv1.MyResource
    if err := r.Get(ctx, req.NamespacedName, &resource); err != nil {
        return ctrl.Result{}, client.IgnoreNotFound(err)
    }

    // Add finalizer if needed
    if !controllerutil.ContainsFinalizer(&resource, finalizerName) {
        controllerutil.AddFinalizer(&resource, finalizerName)
        if err := r.Update(ctx, &resource); err != nil {
            return ctrl.Result{}, err
        }
    }

    // Handle deletion
    if !resource.DeletionTimestamp.IsZero() {
        return r.reconcileDelete(ctx, &resource)
    }

    // Reconcile desired state
    return r.reconcileNormal(ctx, &resource)
}

func (r *MyResourceReconciler) SetupWithManager(mgr ctrl.Manager) error {
    return ctrl.NewControllerManagedBy(mgr).
        For(&myv1.MyResource{}).
        Owns(&corev1.ConfigMap{}).
        Complete(r)
}
```

## Status Conditions

Use standard Kubernetes condition types:

```go
import "k8s.io/apimachinery/pkg/api/meta"

// Set condition
meta.SetStatusCondition(&resource.Status.Conditions, metav1.Condition{
    Type:               "Ready",
    Status:             metav1.ConditionTrue,
    ObservedGeneration: resource.Generation,
    Reason:             "ReconcileSucceeded",
    Message:            "Resource is ready",
})

// Update status
if err := r.Status().Update(ctx, &resource); err != nil {
    return ctrl.Result{}, err
}
```

## Multi-Cluster Awareness

Controllers receive a cluster-aware context. Access cluster information:

```go
func (r *MyResourceReconciler) Reconcile(ctx context.Context, req ctrl.Request) (ctrl.Result, error) {
    // Get cluster from context (if using multicluster-runtime)
    cluster, ok := mcruntime.ClusterFromContext(ctx)
    if ok {
        log.Info("reconciling in cluster", "cluster", cluster.Name())
    }

    // Use cluster-specific client if needed
    clusterClient := cluster.GetClient()

    // ...
}
```

## When to Use This Pattern

| Use Case | Why Controller-Runtime Fits |
|----------|----------------------------|
| Infrastructure operators | Reconciliation handles drift naturally |
| Cross-cluster sync | Multi-cluster runtime discovers clusters |
| Policy enforcement | React to resource changes |
| Workflow automation | Watch and act on state transitions |
| Standard CRUD | No custom API behavior needed |

## When NOT to Use This Pattern

Use aggregated API servers instead when:
- You need a custom storage backend (database, external system)
- You need fine-grained control over API endpoints
- Synchronous request-response semantics are required

See `k8s-apiserver-patterns/architecture-decision.md` for the full decision framework.

## Related Skills

- `k8s-apiserver-patterns` — For aggregated API server approach
- `go-conventions` — Code style and testing
- `capability-activity` — Emitting events for activity tracking
