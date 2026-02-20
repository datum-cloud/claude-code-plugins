---
name: k8s-apiserver-patterns
description: Covers patterns for building Kubernetes aggregated API servers including REST handlers, storage interfaces, scheme registration, and type definitions. Use when implementing API types, storage backends, or server configuration.
---

# Kubernetes API Server Patterns

This skill covers patterns for building Kubernetes aggregated API servers and understanding when to choose this approach over CRD-based controllers.

## Overview

Datum Cloud services are Kubernetes aggregated API servers, not CRD-based controllers. This means:
- Custom storage backends (not etcd)
- Direct REST handler implementation
- Scheme registration and API installation
- APIService registration

**Important**: Before implementing a new service, read `architecture-decision.md` to understand why aggregated API servers were chosen and when CRD-based controllers might be appropriate.

## Key Files

| File | Purpose |
|------|---------|
| `architecture-decision.md` | **Start here** — When to use aggregated servers vs CRDs |
| `types.md` | API type definitions and conventions |
| `storage.md` | Storage backend implementation |
| `validation.md` | Validation patterns |
| `server-config.md` | Server configuration |
| `feature-gates.md` | Feature lifecycle management |

## Core Patterns

### REST Handler Structure

```go
type REST struct {
    store       storage.Interface
    TableConvertor
    *genericregistry.Store
}

func NewREST(store storage.Interface) (*REST, *StatusREST) {
    r := &REST{store: store}
    statusStore := &StatusREST{store: store}
    return r, statusStore
}
```

### Storage Interface

Use `rest.Storage`, NOT `rest.StandardStorage`:

```go
var _ rest.Storage = &REST{}
var _ rest.Creater = &REST{}
var _ rest.Updater = &REST{}
var _ rest.GracefulDeleter = &REST{}
var _ rest.Lister = &REST{}
var _ rest.Getter = &REST{}
var _ rest.Watcher = &REST{}
```

### Scheme Registration

Explicit `Install()` not `init()`:

```go
func Install(scheme *runtime.Scheme) {
    utilruntime.Must(v1alpha1.AddToScheme(scheme))
    utilruntime.Must(scheme.SetVersionPriority(v1alpha1.SchemeGroupVersion))
}
```

## Scaffolding Scripts

| Script | Purpose |
|--------|---------|
| `scripts/scaffold-resource.sh` | Generate type + list + deepcopy |
| `scripts/scaffold-storage.sh` | Generate storage skeleton |
| `scripts/validate-types.sh` | Validate type conventions |

## Validation

Run `scripts/validate-types.sh` to check:
- TypeMeta and ObjectMeta present
- Spec and Status separation
- List type has Items
- Deepcopy markers present

## Related Files

- `types.md` — Type definitions
- `storage.md` — Storage patterns
- `validation.md` — Validation patterns
- `server-config.md` — Server setup
- `feature-gates.md` — Feature lifecycle patterns
