# Control Plane Integration: Architecture Decision

This document explains the two primary approaches for integrating services with the Datum Cloud control plane and when to choose each.

## Two Approaches

Datum Cloud services can integrate with the control plane using either approach:

1. **Controller-Runtime + CRDs** — Using the multi-cluster runtime provider in Milo
2. **Aggregated API Server** — For custom storage backends or API control

### 1. Controller-Runtime Pattern (CRDs + Controllers)

The controller-runtime pattern uses Custom Resource Definitions (CRDs) stored in etcd with controllers that watch for changes and reconcile state.

**How it works:**
- Define CRDs that extend the Kubernetes API
- Controllers watch for resource changes
- Reconciliation loop brings actual state to desired state
- Uses etcd as the storage backend (via kube-apiserver)

**Key components:**
```
┌─────────────────────────────────────────────┐
│              kube-apiserver                 │
│  ┌─────────┐   ┌──────────┐   ┌─────────┐  │
│  │   CRD   │ → │   etcd   │ ← │ Watch   │  │
│  └─────────┘   └──────────┘   └─────────┘  │
└─────────────────────────────────────────────┘
                       │
                       ▼
              ┌─────────────────┐
              │   Controller    │
              │  ┌───────────┐  │
              │  │ Reconcile │  │
              │  │   Loop    │  │
              │  └───────────┘  │
              └─────────────────┘
```

**Typical implementation:**
```go
// CRD type definition
type MyResource struct {
    metav1.TypeMeta   `json:",inline"`
    metav1.ObjectMeta `json:"metadata,omitempty"`
    Spec   MyResourceSpec   `json:"spec,omitempty"`
    Status MyResourceStatus `json:"status,omitempty"`
}

// Controller reconciliation
func (r *MyResourceReconciler) Reconcile(ctx context.Context, req ctrl.Request) (ctrl.Result, error) {
    var resource MyResource
    if err := r.Get(ctx, req.NamespacedName, &resource); err != nil {
        return ctrl.Result{}, client.IgnoreNotFound(err)
    }

    // Reconcile actual state to match desired state
    // ...

    return ctrl.Result{}, nil
}
```

### 2. Aggregated API Server Pattern

Aggregated API servers register with kube-apiserver as extension API servers, implementing their own REST handlers and storage backends.

**How it works:**
- Implement a standalone API server using `k8s.io/apiserver`
- Register with kube-apiserver via APIService resources
- Handle requests directly with custom REST handlers
- Use any storage backend (database, external API, etc.)

**Key components:**
```
┌─────────────────────────────────────────────┐
│              kube-apiserver                 │
│  ┌─────────────┐                            │
│  │ APIService  │ ─── proxies to ───┐        │
│  └─────────────┘                   │        │
└────────────────────────────────────│────────┘
                                     ▼
                        ┌─────────────────────┐
                        │  Aggregated Server  │
                        │  ┌───────────────┐  │
                        │  │ REST Handlers │  │
                        │  └───────────────┘  │
                        │         │           │
                        │         ▼           │
                        │  ┌───────────────┐  │
                        │  │Custom Storage │  │
                        │  │  (DB, API)    │  │
                        │  └───────────────┘  │
                        └─────────────────────┘
```

**Typical implementation:**
```go
// REST handler
type REST struct {
    store storage.Interface
}

func (r *REST) Create(ctx context.Context, obj runtime.Object, ...) (runtime.Object, error) {
    resource := obj.(*MyResource)

    // Direct storage operation
    created, err := r.store.Create(ctx, resource)
    if err != nil {
        return nil, err
    }

    return created, nil
}
```

## Decision Criteria

The choice between approaches comes down to two primary factors:

### 1. Do you need a custom storage backend?

If your service needs to store data in something other than etcd (a database, external system, etc.), use an **aggregated API server**.

Examples:
- Activity service stores events in a time-series database for efficient queries
- Search service queries external search indexes
- Analytics service aggregates data from multiple sources

### 2. Do you need more control over API endpoints?

If you need custom subresources, non-standard HTTP semantics, or fine-grained control over request handling, use an **aggregated API server**.

Examples:
- Custom `/status` or `/scale` subresource behavior
- Streaming or long-polling endpoints
- Complex request validation beyond webhooks
- Custom content negotiation

### Decision Flowchart

```
                    ┌─────────────────────────┐
                    │ Need custom storage     │
                    │ backend (not etcd)?     │
                    └───────────┬─────────────┘
                                │
               ┌────────────────┼────────────────┐
               │ Yes                             │ No
               ▼                                 ▼
     ┌─────────────────┐               ┌─────────────────────┐
     │   Aggregated    │               │ Need fine-grained   │
     │   API Server    │               │ API endpoint        │
     └─────────────────┘               │ control?            │
                                       └──────────┬──────────┘
                                                  │
                                 ┌────────────────┼────────────────┐
                                 │ Yes                             │ No
                                 ▼                                 ▼
                       ┌─────────────────┐              ┌─────────────────┐
                       │   Aggregated    │              │ Controller-     │
                       │   API Server    │              │ Runtime + CRDs  │
                       └─────────────────┘              └─────────────────┘
```

## Milo Multi-Cluster Runtime Provider

For services using the controller-runtime pattern, Milo provides a **multi-cluster runtime provider** that enables controllers to operate across the dynamic fleet of project control planes.

**Location:** `milo/pkg/multicluster-runtime/`

### How It Works

The provider extends `sigs.k8s.io/multicluster-runtime` to discover and manage clusters dynamically:

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

**Internal Service Discovery** (`InternalServiceDiscovery: true`)
- Uses internal Kubernetes service addresses
- Connects to: `milo-apiserver.project-{name}.svc.cluster.local:6443`
- Best for operators running within the infrastructure control plane

**External Discovery** (`InternalServiceDiscovery: false`)
- Uses external Milo API endpoints
- Path: `/apis/resourcemanager.miloapis.com/v1alpha1/projects/{name}/control-plane`
- Best for operators outside the infrastructure cluster

### Using the Provider

```go
import (
    mcruntime "sigs.k8s.io/multicluster-runtime/pkg/manager"
    miloprovider "go.datum.net/milo/pkg/multicluster-runtime/milo"
)

func main() {
    // Create the multi-cluster manager
    mgr, err := mcruntime.New(cfg, mcruntime.Options{
        // Standard manager options
    })

    // Create the Milo provider
    provider, err := miloprovider.New(mgr.GetClient(), miloprovider.Options{
        InternalServiceDiscovery: true,
    })

    // Start provider - it watches Projects and engages clusters
    go provider.Run(ctx, mgr)

    // Register controllers - they'll run across all discovered clusters
    if err := (&MyReconciler{}).SetupWithManager(mgr); err != nil {
        // ...
    }
}
```

## When to Use Each Approach

### Use Controller-Runtime + CRDs When:

| Scenario | Why It Fits |
|----------|-------------|
| Managing external resources | Reconciliation handles drift and retries naturally |
| etcd storage is sufficient | No need for custom backend complexity |
| Multi-cluster coordination | Milo's multi-cluster runtime handles discovery |
| Operator pattern | Watching and reacting to resource changes |
| GitOps workflows | CRDs integrate with Flux, ArgoCD |
| Standard CRUD semantics | No custom API behavior needed |

**Good use cases:**
- Infrastructure operators (provisioning cloud resources)
- Cross-cluster resource synchronization
- Workflow controllers
- Policy enforcement controllers

### Use Aggregated API Server When:

| Scenario | Why It Fits |
|----------|-------------|
| Custom storage backend | Database, external API, time-series store |
| Query-heavy workloads | Complex queries beyond etcd's capabilities |
| Large data volumes | etcd size limits don't apply |
| Custom API semantics | Non-standard subresources, streaming |
| Synchronous responses | Immediate feedback without reconciliation |
| External system facade | Present external data as Kubernetes API |

**Good use cases:**
- Activity/audit logging (time-series storage)
- Search services (external search index)
- Analytics services (aggregated queries)
- Services fronting external systems

## Examples in Datum Cloud

### Controller-Runtime Services

Services using controller-runtime with the multi-cluster provider:
- Project controllers managing cross-cluster resources
- Policy enforcement controllers
- Resource synchronization controllers

### Aggregated API Servers

Services using aggregated API servers:
- **Activity service** — Stores events in a time-series database for efficient queries
- **Search service** — Queries external search indexes

### Hybrid: Milo Itself

Milo uses both patterns:
- **API Server** (`milo/cmd/milo/apiserver/`) — Serves Organizations, Projects, IAM as aggregated APIs
- **Controller Manager** (`milo/cmd/milo/controller-manager/`) — Runs reconciliation for resource lifecycle

## Implementation References

### For Controller-Runtime + CRDs
- [Kubebuilder Book](https://book.kubebuilder.io/)
- [controller-runtime](https://github.com/kubernetes-sigs/controller-runtime)
- [multicluster-runtime](https://github.com/kubernetes-sigs/multicluster-runtime)
- Milo provider: `milo/pkg/multicluster-runtime/`

### For Aggregated API Servers
- `k8s-apiserver-patterns/` skill in this repository
- `types.md` — Type definitions
- `storage.md` — Storage implementation
- `validation.md` — Validation patterns
- `server-config.md` — Server configuration

## Summary

| Aspect | Controller-Runtime + CRDs | Aggregated API Server |
|--------|---------------------------|----------------------|
| **Storage** | etcd (via kube-apiserver) | Custom (you choose) |
| **Consistency** | Eventual (reconciliation) | Synchronous |
| **Complexity** | Lower | Higher |
| **Multi-cluster** | Via Milo provider | Manual coordination |
| **Best for** | Operators, reconciliation | Custom storage, API control |
| **Primary decision** | etcd is sufficient | Need custom storage or API control |
