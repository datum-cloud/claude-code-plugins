# Testing Conventions

## File Naming

- `foo.go` → `foo_test.go`
- Same package (not `_test` suffix)
- Test helpers in `testing_helpers_test.go`

## Test Naming

```go
// Function tests
func TestFunctionName(t *testing.T)

// Method tests
func TestTypeName_MethodName(t *testing.T)

// Subtests with descriptive names
func TestCreate(t *testing.T) {
    t.Run("valid resource", func(t *testing.T) { ... })
    t.Run("missing required field", func(t *testing.T) { ... })
}
```

## Table-Driven Tests

```go
func TestValidation(t *testing.T) {
    tests := []struct {
        name    string
        input   *Resource
        wantErr bool
        errMsg  string
    }{
        {
            name:    "valid resource",
            input:   validResource(),
            wantErr: false,
        },
        {
            name:    "missing name",
            input:   resourceWithoutName(),
            wantErr: true,
            errMsg:  "name is required",
        },
    }

    for _, tt := range tests {
        t.Run(tt.name, func(t *testing.T) {
            err := Validate(tt.input)
            if tt.wantErr {
                require.Error(t, err)
                assert.Contains(t, err.Error(), tt.errMsg)
            } else {
                require.NoError(t, err)
            }
        })
    }
}
```

## Assertions

Use testify:

```go
import (
    "github.com/stretchr/testify/assert"
    "github.com/stretchr/testify/require"
)

// require: fatal on failure (preconditions)
require.NoError(t, err)
require.NotNil(t, result)

// assert: continue on failure (actual tests)
assert.Equal(t, expected, actual)
assert.Contains(t, str, substring)
assert.Len(t, slice, 3)
```

## Test Structure

```go
func TestOperation(t *testing.T) {
    // Setup
    ctx := context.Background()
    store := newTestStore()
    resource := newTestResource()

    // Execute
    result, err := store.Create(ctx, resource)

    // Verify
    require.NoError(t, err)
    assert.Equal(t, resource.Name, result.Name)
}
```

## Builder Pattern

```go
func newTestResource(opts ...ResourceOption) *Resource {
    r := &Resource{
        ObjectMeta: metav1.ObjectMeta{
            Name:      "test-resource",
            Namespace: "default",
        },
        Spec: ResourceSpec{
            Replicas: 1,
        },
    }
    for _, opt := range opts {
        opt(r)
    }
    return r
}

type ResourceOption func(*Resource)

func withName(name string) ResourceOption {
    return func(r *Resource) { r.Name = name }
}

func withReplicas(n int32) ResourceOption {
    return func(r *Resource) { r.Spec.Replicas = n }
}

// Usage
resource := newTestResource(
    withName("my-resource"),
    withReplicas(3),
)
```

## Parallel Tests

```go
func TestParallel(t *testing.T) {
    t.Parallel() // Mark test as parallel

    tests := []struct{...}{}
    for _, tt := range tests {
        tt := tt // Capture range variable
        t.Run(tt.name, func(t *testing.T) {
            t.Parallel() // Each subtest parallel too
            // test code
        })
    }
}
```

## Test Fixtures

Store in `testdata/`:

```
pkg/storage/
├── store.go
├── store_test.go
└── testdata/
    ├── valid-resource.yaml
    └── invalid-resource.yaml
```

```go
func loadTestData(t *testing.T, name string) []byte {
    t.Helper()
    data, err := os.ReadFile(filepath.Join("testdata", name))
    require.NoError(t, err)
    return data
}
```

## Mocks

Use interfaces for mockability:

```go
type Store interface {
    Get(ctx context.Context, name string) (*Resource, error)
    Create(ctx context.Context, r *Resource) (*Resource, error)
}

type MockStore struct {
    GetFunc    func(ctx context.Context, name string) (*Resource, error)
    CreateFunc func(ctx context.Context, r *Resource) (*Resource, error)
}

func (m *MockStore) Get(ctx context.Context, name string) (*Resource, error) {
    return m.GetFunc(ctx, name)
}
```
