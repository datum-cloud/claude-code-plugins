---
name: go-conventions
description: Covers Go coding conventions including import grouping, error handling, naming, and comments. Use when writing or reviewing Go code to ensure consistency across services.
---

# Go Conventions

This skill covers Go coding conventions for Datum Cloud services.

## Overview

All Go code follows these conventions for consistency across services.

## Key Files

| File | Purpose |
|------|---------|
| `testing.md` | Test patterns |

## Import Grouping

Three groups, separated by blank lines:

```go
import (
    // Standard library
    "context"
    "fmt"
    "time"

    // External packages
    "k8s.io/apimachinery/pkg/runtime"
    "sigs.k8s.io/controller-runtime/pkg/client"

    // Internal packages
    "github.com/datumapis/myservice/pkg/apis/v1alpha1"
    "github.com/datumapis/myservice/internal/storage"
)
```

## Error Handling

### Error Messages

- Lowercase, no punctuation
- Include context
- Actionable when possible

```go
// Good
return fmt.Errorf("creating resource %s: %w", name, err)

// Bad
return fmt.Errorf("Failed to create resource.")
```

### Error Wrapping

Always wrap with context:

```go
if err != nil {
    return fmt.Errorf("validating spec: %w", err)
}
```

### Sentinel Errors

Use for expected conditions:

```go
var ErrNotFound = errors.New("resource not found")

if errors.Is(err, ErrNotFound) {
    // handle not found
}
```

## Naming

| Type | Convention | Example |
|------|------------|---------|
| Package | short, lowercase | `storage`, `quota` |
| Interface | -er suffix when single method | `Reader`, `Storage` |
| Struct | noun | `ResourceStore` |
| Function | verb | `CreateResource` |
| Constant | PascalCase | `MaxRetries` |
| Variable | camelCase | `resourceCount` |

## Comments

### Package Comments

```go
// Package storage implements the storage backend for resources.
package storage
```

### Function Comments

```go
// CreateResource creates a new resource in the store.
// It returns ErrAlreadyExists if the resource exists.
func CreateResource(ctx context.Context, r *Resource) error {
```

### Why, Not What

```go
// Good: explains why
// Use sync.Once to ensure thread-safe lazy initialization
r.storeOnce.Do(...)

// Bad: explains what (obvious from code)
// Initialize the store
r.storeOnce.Do(...)
```

## Context

- First parameter always
- Never store in structs
- Pass through call chains

```go
func (s *Store) Get(ctx context.Context, name string) (*Resource, error) {
    return s.backend.Get(ctx, name)
}
```

## Validation Scripts

| Script | Purpose |
|--------|---------|
| `scripts/check-imports.sh` | Verify import grouping |
| `scripts/check-test-naming.sh` | Verify test file names |
| `scripts/check-boilerplate.sh` | Verify license headers |

## Related Files

- `testing.md` — Test conventions
