# Feature Gates

## Overview

Feature gates provide runtime toggles for experimental or optional features in Kubernetes aggregated API servers. They follow the Kubernetes component-base pattern for managing feature lifecycle from experimental (Alpha) to production-ready (GA) to removal.

**When to use feature gates:**
- Feature changes storage backend behavior
- Feature integrates with external systems
- Feature is experimental and may be removed
- Operators need runtime control over feature enablement

**Skip feature gates for:**
- Simple API additions with no behavioral changes
- Bug fixes
- Internal refactoring
- Features gated by other mechanisms (RBAC, admission)

**Upstream documentation:** [k8s.io/component-base/featuregate](https://pkg.go.dev/k8s.io/component-base/featuregate)

## Feature Definition

Define features in `pkg/features/features.go`:

```go
package features

import (
    "k8s.io/apimachinery/pkg/util/runtime"
    utilfeature "k8s.io/apiserver/pkg/util/feature"
    "k8s.io/component-base/featuregate"
)

const (
    // EventsProxy enables forwarding Kubernetes Events (core/v1.Event) to the
    // Activity service instead of storing them in etcd. This provides multi-tenant
    // event storage with automatic scope injection.
    //
    // owner: @datum-cloud/platform
    // alpha: v0.1.0
    EventsProxy featuregate.Feature = "EventsProxy"

    // Sessions enables the identity.miloapis.com/v1alpha1 Session virtual API
    // that proxies to an external identity provider for session management.
    //
    // owner: @datum-cloud/platform
    // alpha: v0.1.0
    // ga: v0.2.0
    Sessions featuregate.Feature = "Sessions"
)
```

**Documentation comment structure:**
- First line: Brief description of what the feature enables
- Optionally: Additional details about implementation or dependencies
- owner: Team responsible for the feature
- alpha: Version when feature was introduced
- beta: Version when feature became Beta (if applicable)
- ga: Version when feature became GA (if applicable)
- deprecated: Version and reason (if applicable)

## Feature Gate Registration

Register feature gates using the `init()` pattern:

```go
func init() {
    runtime.Must(utilfeature.DefaultMutableFeatureGate.Add(defaultFeatureGates))
}

// defaultFeatureGates defines the default state of feature gates.
// Features are listed in alphabetical order.
var defaultFeatureGates = map[featuregate.Feature]featuregate.FeatureSpec{
    EventsProxy: {
        Default:    false,
        PreRelease: featuregate.Alpha,
    },
    Sessions: {
        Default:    true,
        PreRelease: featuregate.GA,
    },
}
```

**FeatureSpec fields:**
- `Default`: Whether feature is enabled by default
- `PreRelease`: Feature stage (Alpha, Beta, GA, Deprecated)
- `LockToDefault`: If true, feature cannot be toggled via flag (used for truly immutable features)

**Import in server main:**

```go
import (
    _ "go.miloapis.com/myservice/pkg/features"
)
```

The blank import ensures the `init()` function runs and registers all feature gates.

## Checking Feature Enablement

### In Config Methods

```go
import (
    utilfeature "k8s.io/apiserver/pkg/util/feature"
    "go.miloapis.com/myservice/pkg/features"
)

func (c *Config) Complete() CompletedConfig {
    c.GenericConfig.Complete()

    if utilfeature.DefaultFeatureGate.Enabled(features.EventsProxy) {
        // Initialize Events proxy client
        c.EventsClient = newEventsProxyClient(c.EventsProxyURL)
    }

    return CompletedConfig{&completedConfig{c}}
}
```

### In REST Handlers

```go
func (r *REST) Create(ctx context.Context, obj runtime.Object, createValidation rest.ValidateObjectFunc, options *metav1.CreateOptions) (runtime.Object, error) {
    if utilfeature.DefaultFeatureGate.Enabled(features.EventsProxy) {
        // Proxy to external system
        return r.eventsClient.Create(ctx, obj)
    }

    // Default behavior: store in etcd
    return r.store.Create(ctx, obj, createValidation, options)
}
```

### In Controllers

```go
func (c *Controller) syncHandler(ctx context.Context, key string) error {
    if utilfeature.DefaultFeatureGate.Enabled(features.MyFeature) {
        // Feature-specific reconciliation logic
        return c.reconcileWithFeature(ctx, key)
    }

    // Default reconciliation logic
    return c.reconcileDefault(ctx, key)
}
```

## CLI Configuration

### Command-Line Flag

```bash
# Enable single feature
./myservice --feature-gates=EventsProxy=true

# Enable multiple features
./myservice --feature-gates=EventsProxy=true,AnotherFeature=false

# Disable a Beta/GA feature (if allowed)
./myservice --feature-gates=Sessions=false
```

### Environment Variable

```bash
# Set via environment variable
export FEATURE_GATES="EventsProxy=true,AnotherFeature=false"
./myservice
```

### Kubernetes Deployment

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: myservice
spec:
  template:
    spec:
      containers:
      - name: myservice
        image: myservice:latest
        args:
        - --feature-gates=EventsProxy=true
```

## Feature Lifecycle Stages

| Stage | Default | Can Disable | Characteristics |
|-------|---------|-------------|-----------------|
| Alpha | `false` | N/A (off by default) | Experimental, may be removed without notice |
| Beta | `true` | Yes | Stable API, enabled by default, may still change |
| GA | `true` | No | Production-ready, API is locked, cannot be disabled |
| Deprecated | `false` | N/A (off by default) | Scheduled for removal, use alternative |

## Feature Graduation

### Alpha to Beta Graduation

**Criteria:**
- Feature has been tested in production environments
- API is stable (no breaking changes expected)
- Documentation is complete
- No critical bugs outstanding

**Code Changes:**

```go
// BEFORE (Alpha)
const (
    // MyFeature enables experimental widget support.
    // owner: @datum-cloud/platform
    // alpha: v0.1.0
    MyFeature featuregate.Feature = "MyFeature"
)

var defaultFeatureGates = map[featuregate.Feature]featuregate.FeatureSpec{
    MyFeature: {
        Default:    false,           // Disabled by default
        PreRelease: featuregate.Alpha,
    },
}

// AFTER (Beta)
const (
    // MyFeature enables widget support.
    // owner: @datum-cloud/platform
    // alpha: v0.1.0
    // beta: v0.3.0
    MyFeature featuregate.Feature = "MyFeature"
)

var defaultFeatureGates = map[featuregate.Feature]featuregate.FeatureSpec{
    MyFeature: {
        Default:    true,            // Now enabled by default
        PreRelease: featuregate.Beta,
    },
}
```

**Migration Notes:**
- Announce in release notes that feature is now Beta
- Operators who explicitly disabled it will continue to have it disabled
- New deployments get the feature enabled by default

### Beta to GA Graduation

**Criteria:**
- Feature has been Beta for at least one release cycle
- No API changes required
- Proven stable in production
- Performance characteristics understood

**Code Changes:**

```go
// BEFORE (Beta)
const (
    // MyFeature enables widget support.
    // owner: @datum-cloud/platform
    // alpha: v0.1.0
    // beta: v0.3.0
    MyFeature featuregate.Feature = "MyFeature"
)

var defaultFeatureGates = map[featuregate.Feature]featuregate.FeatureSpec{
    MyFeature: {
        Default:    true,
        PreRelease: featuregate.Beta,
    },
}

// AFTER (GA)
const (
    // MyFeature enables widget support.
    // owner: @datum-cloud/platform
    // alpha: v0.1.0
    // beta: v0.3.0
    // ga: v0.5.0
    MyFeature featuregate.Feature = "MyFeature"
)

var defaultFeatureGates = map[featuregate.Feature]featuregate.FeatureSpec{
    MyFeature: {
        Default:    true,
        PreRelease: featuregate.GA,  // Empty string internally
    },
}
```

**Migration Notes:**
- Announce GA in release notes
- Feature can no longer be disabled via flag (attempting to disable will log a warning)
- Begin planning gate removal timeline

### GA to Gate Removal

**Criteria:**
- Feature has been GA for at least two release cycles
- No operators depend on disabling the feature
- Removal announced in advance (N-1 release)

**Code Changes:**

```go
// BEFORE (GA with gate)
const (
    MyFeature featuregate.Feature = "MyFeature"
)

var defaultFeatureGates = map[featuregate.Feature]featuregate.FeatureSpec{
    MyFeature: {Default: true, PreRelease: featuregate.GA},
}

// Check in code
if utilfeature.DefaultFeatureGate.Enabled(features.MyFeature) {
    // feature code
}

// AFTER (Gate removed)
// 1. Remove the constant from pkg/features/features.go
// 2. Remove from defaultFeatureGates map
// 3. Remove all Enabled() checks throughout codebase
// 4. Keep the feature code, just remove the conditional
```

**Removal Process:**
1. Announce gate removal in release notes (N-1 release)
2. Remove gate constant and FeatureSpec in target release (N)
3. Clean up all `Enabled()` checks throughout codebase
4. Feature code runs unconditionally

### Deprecation Path

For features that will be removed rather than graduated to GA:

```go
const (
    // LegacyFeature enables the legacy behavior.
    // owner: @datum-cloud/platform
    // alpha: v0.1.0
    // deprecated: v0.4.0 (use NewFeature instead)
    LegacyFeature featuregate.Feature = "LegacyFeature"
)

var defaultFeatureGates = map[featuregate.Feature]featuregate.FeatureSpec{
    LegacyFeature: {
        Default:    false,
        PreRelease: featuregate.Deprecated,
    },
}
```

**Deprecation process:**
1. Change `PreRelease` to `featuregate.Deprecated`
2. Set `Default` to `false`
3. Update documentation comment with deprecation notice and alternative
4. Announce deprecation in release notes
5. Remove in subsequent release (typically N+2)

### Complete Lifecycle Example

The same feature evolving through all stages:

```go
// Version 0.1.0 - Alpha
// MyFeature enables experimental widget support.
// owner: @datum-cloud/platform
// alpha: v0.1.0
MyFeature featuregate.Feature = "MyFeature"
// Spec: {Default: false, PreRelease: featuregate.Alpha}

// Version 0.3.0 - Beta (after production validation)
// MyFeature enables widget support.
// owner: @datum-cloud/platform
// alpha: v0.1.0
// beta: v0.3.0
// Spec: {Default: true, PreRelease: featuregate.Beta}

// Version 0.5.0 - GA (after stability period)
// MyFeature enables widget support.
// owner: @datum-cloud/platform
// alpha: v0.1.0
// beta: v0.3.0
// ga: v0.5.0
// Spec: {Default: true, PreRelease: featuregate.GA}

// Version 0.7.0 - Gate Removed
// No constant, no spec, no Enabled() checks
// Widget support code runs unconditionally
```

## Naming Conventions

| Convention | Example | Anti-Pattern |
|------------|---------|--------------|
| PascalCase | `EventsProxy` | `eventsProxy`, `events_proxy` |
| No suffix | `Sessions` | `SessionsFeature`, `SessionsGate` |
| Descriptive | `UserIdentities` | `UI`, `UsrIdent` |
| Noun or noun phrase | `EventsProxy` | `EnableEventsProxy`, `ProxyEvents` |

**Rationale:**
- PascalCase matches Go constant conventions
- No suffix reduces verbosity (the type `featuregate.Feature` provides context)
- Descriptive names improve readability in configuration
- Noun form describes the capability being enabled

## When to Use Feature Gates

### Use Feature Gates When

**Feature changes storage backend behavior:**

```go
if utilfeature.DefaultFeatureGate.Enabled(features.EventsProxy) {
    // Store events in external system instead of etcd
    return r.eventsClient.Create(ctx, obj)
}
```

**Feature integrates with external systems:**

```go
if utilfeature.DefaultFeatureGate.Enabled(features.Sessions) {
    // Proxy to external identity provider
    return r.identityProxy.GetSession(ctx, name)
}
```

**Feature is experimental and may be removed:**

```go
// alpha: v0.1.0
// This feature may be removed if telemetry shows low usage
ExperimentalFeature featuregate.Feature = "ExperimentalFeature"
```

**Operators need runtime control:**

```go
// Allow operators to disable feature if it causes issues
if utilfeature.DefaultFeatureGate.Enabled(features.NewBehavior) {
    return r.newImplementation(ctx, obj)
}
return r.legacyImplementation(ctx, obj)
```

### Skip Feature Gates When

**Simple API additions with no behavioral changes:**

```go
// New field in existing type - no gate needed
type MyResourceSpec struct {
    Name        string `json:"name"`
    NewField    string `json:"newField,omitempty"`  // Just add the field
}
```

**Bug fixes:**

```go
// Fix incorrect validation logic - no gate needed
func ValidateMyResource(obj *MyResource) field.ErrorList {
    // Just fix the bug
    if obj.Spec.Replicas < 0 {
        return field.ErrorList{field.Invalid(...)}
    }
}
```

**Internal refactoring:**

```go
// Refactor storage implementation - no gate needed
// Old: func (r *REST) Get(ctx context.Context, name string) (runtime.Object, error)
// New: func (r *REST) Get(ctx context.Context, name string, options *metav1.GetOptions) (runtime.Object, error)
// As long as behavior is unchanged
```

**Features gated by other mechanisms:**

```go
// RBAC already controls access - no feature gate needed
// +kubebuilder:rbac:groups=myservice.miloapis.com,resources=secrets,verbs=get;list

// Admission webhook already validates - no feature gate needed
func (v *MyResourceValidator) ValidateCreate(ctx context.Context, obj runtime.Object) error {
    // Validation logic
}
```

## Integration with Server Configuration

Feature gates integrate with the server configuration patterns documented in `server-config.md`.

### Import in Main

```go
package main

import (
    _ "go.miloapis.com/myservice/pkg/features"  // Register feature gates
    "go.miloapis.com/myservice/pkg/server"
)

func main() {
    o := server.NewOptions()
    o.AddFlags(pflag.CommandLine)
    pflag.Parse()

    config, err := o.Config()
    if err != nil {
        klog.Fatal(err)
    }

    server, err := config.Complete().New()
    if err != nil {
        klog.Fatal(err)
    }

    stopCh := genericapiserver.SetupSignalHandler()
    if err := server.Run(stopCh); err != nil {
        klog.Fatal(err)
    }
}
```

### Check in Config.Complete()

```go
func (c *Config) Complete() CompletedConfig {
    c.GenericConfig.Complete()

    // Conditionally initialize storage based on feature gate
    if utilfeature.DefaultFeatureGate.Enabled(features.EventsProxy) {
        c.EventsStorage = newProxyStorage(c.EventsProxyURL)
    } else {
        c.EventsStorage = newEtcdStorage(c.GenericConfig.RESTOptionsGetter)
    }

    return CompletedConfig{&completedConfig{c}}
}
```

### Conditional API Installation

```go
func (c CompletedConfig) New() (*MyServer, error) {
    genericServer, err := c.GenericConfig.New("myservice", genericapiserver.NewEmptyDelegate())
    if err != nil {
        return nil, err
    }

    s := &MyServer{
        GenericAPIServer: genericServer,
    }

    // Conditionally install API group based on feature gate
    if utilfeature.DefaultFeatureGate.Enabled(features.Sessions) {
        apiGroupInfo := genericapiserver.NewDefaultAPIGroupInfo(
            "identity.miloapis.com",
            Scheme,
            metav1.ParameterCodec,
            Codecs,
        )

        rest := storage.NewSessionREST(c.IdentityClient)
        v1alpha1Storage := map[string]rest.Storage{
            "sessions": rest,
        }
        apiGroupInfo.VersionedResourcesStorageMap["v1alpha1"] = v1alpha1Storage

        if err := s.GenericAPIServer.InstallAPIGroup(&apiGroupInfo); err != nil {
            return nil, err
        }
    }

    return s, nil
}
```

For more details on server configuration patterns, see `server-config.md`.
