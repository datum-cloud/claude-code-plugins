# Emitting Kubernetes Events for Activity Integration

This guide explains how controllers should emit Kubernetes events so they can be consumed by the Activity system and surfaced to users through ActivityPolicy eventRules.

## Overview

The Activity system automatically collects Kubernetes events and translates them into human-readable activity entries using ActivityPolicy eventRules. For this to work effectively, controllers must emit events with:

1. **Consistent reason codes** — Machine-readable identifiers that eventRules can match
2. **Clear event types** — `Normal` for success, `Warning` for problems
3. **Informative messages** — Human-readable context included in activity summaries
4. **Proper resource references** — Link back to the affected resource

## Event Recorder Setup

### Standard Controller Pattern

Set up the event recorder in your controller:

```go
import (
    "context"

    corev1 "k8s.io/api/core/v1"
    "k8s.io/apimachinery/pkg/runtime"
    "k8s.io/client-go/tools/record"
    ctrl "sigs.k8s.io/controller-runtime"
    "sigs.k8s.io/controller-runtime/pkg/client"
)

type MyResourceReconciler struct {
    client.Client
    Scheme   *runtime.Scheme
    Recorder record.EventRecorder
}

func (r *MyResourceReconciler) SetupWithManager(mgr ctrl.Manager) error {
    // Create event recorder for this controller
    r.Recorder = mgr.GetEventRecorderFor("myresource-controller")

    return ctrl.NewControllerManagedBy(mgr).
        For(&v1alpha1.MyResource{}).
        Complete(r)
}
```

### Aggregated API Server Pattern

For aggregated API servers using REST storage:

```go
import (
    "k8s.io/client-go/kubernetes"
    "k8s.io/client-go/tools/record"
    "k8s.io/apimachinery/pkg/runtime"
)

type REST struct {
    client    client.Client
    scheme    *runtime.Scheme
    recorder  record.EventRecorder
}

func NewREST(client client.Client, scheme *runtime.Scheme, clientset kubernetes.Interface) *REST {
    // Create event broadcaster
    eventBroadcaster := record.NewBroadcaster()
    eventBroadcaster.StartRecordingToSink(&typedcorev1.EventSinkImpl{
        Interface: clientset.CoreV1().Events(""),
    })

    return &REST{
        client:   client,
        scheme:   scheme,
        recorder: eventBroadcaster.NewRecorder(scheme, corev1.EventSource{
            Component: "myresource-controller",
        }),
    }
}
```

---

## Event Structure

### Core Fields

Every Kubernetes event has these key fields that ActivityPolicy can match:

| Field | Description | ActivityPolicy Access |
|-------|-------------|----------------------|
| `reason` | Machine-readable code (PascalCase) | `event.reason` |
| `type` | `Normal` or `Warning` | `event.type` |
| `message` | Human-readable description | `event.message` |
| `regarding` | Reference to affected resource | `event.regarding` |
| `source.component` | Controller name | `event.source.component` |

### Emitting Events

Use the recorder methods:

```go
// Normal event - success or progress
r.Recorder.Event(resource, corev1.EventTypeNormal, "Ready", "Resource is ready")

// Warning event - problem or failure
r.Recorder.Event(resource, corev1.EventTypeWarning, "Failed", "Failed to provision: connection timeout")

// Event with formatted message
r.Recorder.Eventf(resource, corev1.EventTypeNormal, "Scaled", "Scaled from %d to %d replicas", oldCount, newCount)

// Annotated event (adds annotations to the event object)
r.Recorder.AnnotatedEventf(resource, annotations, corev1.EventTypeNormal, "Configured", "Applied configuration %s", configName)
```

---

## Reason Code Standards

### Naming Convention

Reason codes should be:
- **PascalCase** — `Ready`, `Failed`, `Progressing`
- **Verb or adjective** — Describes the state or action
- **Consistent across resources** — Use the same codes for similar situations

### Standard Reason Codes

Use these standard codes when applicable. ActivityPolicy templates can rely on them:

#### Lifecycle Events

| Reason | Type | When to Use |
|--------|------|-------------|
| `Created` | Normal | Resource successfully created |
| `Updated` | Normal | Resource successfully updated |
| `Deleted` | Normal | Resource successfully deleted |

#### State Transitions

| Reason | Type | When to Use |
|--------|------|-------------|
| `Ready` | Normal | Resource is fully operational |
| `NotReady` | Warning | Resource is not yet ready |
| `Progressing` | Normal | Resource is being reconciled |
| `Degraded` | Warning | Resource is operational but impaired |

#### Provisioning Events

| Reason | Type | When to Use |
|--------|------|-------------|
| `Provisioning` | Normal | Backend provisioning started |
| `Provisioned` | Normal | Backend provisioning complete |
| `ProvisioningFailed` | Warning | Backend provisioning failed |

#### Scaling Events

| Reason | Type | When to Use |
|--------|------|-------------|
| `ScaledUp` | Normal | Replicas increased |
| `ScaledDown` | Normal | Replicas decreased |
| `ScalingFailed` | Warning | Scaling operation failed |

#### Networking Events

| Reason | Type | When to Use |
|--------|------|-------------|
| `Programmed` | Normal | Network configuration applied |
| `EndpointsReady` | Normal | Endpoints are healthy |
| `EndpointsFailed` | Warning | Endpoint health check failed |

#### Certificate Events

| Reason | Type | When to Use |
|--------|------|-------------|
| `CertificateIssued` | Normal | TLS certificate obtained |
| `CertificateRenewed` | Normal | TLS certificate renewed |
| `CertificateFailed` | Warning | Certificate issuance failed |
| `CertificateExpiring` | Warning | Certificate nearing expiration |

#### Validation Events

| Reason | Type | When to Use |
|--------|------|-------------|
| `ValidationSucceeded` | Normal | Configuration is valid |
| `ValidationFailed` | Warning | Configuration validation failed |
| `ConfigurationApplied` | Normal | Configuration successfully applied |

#### Error Events

| Reason | Type | When to Use |
|--------|------|-------------|
| `Failed` | Warning | Generic failure (include details in message) |
| `InternalError` | Warning | Unexpected internal error |
| `DependencyFailed` | Warning | Dependency not available |
| `QuotaExceeded` | Warning | Resource quota limit hit |
| `PermissionDenied` | Warning | IAM permission check failed |

---

## Message Guidelines

### Message Structure

Messages should be:
- **Self-contained** — Understandable without additional context
- **Actionable** — Help users understand what happened and what to do
- **Consistent** — Similar events use similar message patterns

### Good Message Patterns

```go
// Include the resource identifier
r.Recorder.Event(proxy, corev1.EventTypeNormal, "Programmed",
    fmt.Sprintf("HTTPProxy %s is now programmed on gateway %s", proxy.Name, gateway))

// Include the error details
r.Recorder.Event(instance, corev1.EventTypeWarning, "ProvisioningFailed",
    fmt.Sprintf("Failed to provision instance: %v", err))

// Include before/after for changes
r.Recorder.Eventf(deployment, corev1.EventTypeNormal, "ScaledUp",
    "Scaled deployment from %d to %d replicas", oldReplicas, newReplicas)

// Include relevant configuration
r.Recorder.Event(service, corev1.EventTypeNormal, "EndpointsReady",
    fmt.Sprintf("All %d endpoints are healthy", endpointCount))
```

### Avoid

```go
// Too vague
r.Recorder.Event(resource, corev1.EventTypeWarning, "Failed", "Operation failed")

// Internal implementation details
r.Recorder.Event(resource, corev1.EventTypeWarning, "Failed",
    "etcd transaction conflict on key /registry/myresources/default/foo")

// Stack traces in messages
r.Recorder.Event(resource, corev1.EventTypeWarning, "Failed", err.Error())  // if err contains stack trace
```

---

## Event Emission Patterns

### Reconciliation Loop Pattern

Emit events at key points in the reconciliation loop:

```go
func (r *MyResourceReconciler) Reconcile(ctx context.Context, req ctrl.Request) (ctrl.Result, error) {
    var resource v1alpha1.MyResource
    if err := r.Get(ctx, req.NamespacedName, &resource); err != nil {
        return ctrl.Result{}, client.IgnoreNotFound(err)
    }

    // Check if being deleted
    if !resource.DeletionTimestamp.IsZero() {
        if err := r.cleanup(ctx, &resource); err != nil {
            r.Recorder.Event(&resource, corev1.EventTypeWarning, "CleanupFailed",
                fmt.Sprintf("Failed to cleanup: %v", err))
            return ctrl.Result{}, err
        }
        r.Recorder.Event(&resource, corev1.EventTypeNormal, "Deleted", "Resource cleanup complete")
        return ctrl.Result{}, nil
    }

    // Provisioning
    if !r.isProvisioned(&resource) {
        r.Recorder.Event(&resource, corev1.EventTypeNormal, "Provisioning", "Starting provisioning")

        if err := r.provision(ctx, &resource); err != nil {
            r.Recorder.Event(&resource, corev1.EventTypeWarning, "ProvisioningFailed",
                fmt.Sprintf("Provisioning failed: %v", err))
            return ctrl.Result{}, err
        }

        r.Recorder.Event(&resource, corev1.EventTypeNormal, "Provisioned", "Provisioning complete")
    }

    // Check readiness
    if r.isReady(&resource) {
        // Only emit Ready event on transition
        if !r.wasReady(&resource) {
            r.Recorder.Event(&resource, corev1.EventTypeNormal, "Ready", "Resource is ready")
        }
    }

    return ctrl.Result{}, nil
}
```

### State Transition Pattern

Only emit events when state actually changes:

```go
func (r *MyResourceReconciler) updateStatus(ctx context.Context, resource *v1alpha1.MyResource, newPhase string) error {
    oldPhase := resource.Status.Phase

    // Only emit event if phase changed
    if oldPhase != newPhase {
        resource.Status.Phase = newPhase

        switch newPhase {
        case "Ready":
            r.Recorder.Event(resource, corev1.EventTypeNormal, "Ready",
                fmt.Sprintf("Resource transitioned from %s to Ready", oldPhase))
        case "Failed":
            r.Recorder.Event(resource, corev1.EventTypeWarning, "Failed",
                fmt.Sprintf("Resource transitioned from %s to Failed", oldPhase))
        case "Degraded":
            r.Recorder.Event(resource, corev1.EventTypeWarning, "Degraded",
                fmt.Sprintf("Resource degraded from %s state", oldPhase))
        }
    }

    return r.Status().Update(ctx, resource)
}
```

### Error Classification Pattern

Emit different event types based on error category:

```go
func (r *MyResourceReconciler) handleError(resource *v1alpha1.MyResource, err error) {
    switch {
    case errors.Is(err, ErrQuotaExceeded):
        r.Recorder.Event(resource, corev1.EventTypeWarning, "QuotaExceeded",
            "Resource quota exceeded. Request additional quota or reduce usage.")

    case errors.Is(err, ErrPermissionDenied):
        r.Recorder.Event(resource, corev1.EventTypeWarning, "PermissionDenied",
            fmt.Sprintf("Permission denied: %v", err))

    case errors.Is(err, ErrDependencyNotReady):
        r.Recorder.Event(resource, corev1.EventTypeWarning, "DependencyFailed",
            fmt.Sprintf("Dependency not ready: %v", err))

    case IsTransient(err):
        // Don't emit event for transient errors that will auto-retry
        return

    default:
        r.Recorder.Event(resource, corev1.EventTypeWarning, "Failed",
            fmt.Sprintf("Reconciliation failed: %v", err))
    }
}
```

---

## User-Friendly Messaging with Annotations

### The Problem with Hardcoded Messages

Embedding user-facing text directly in controller code has drawbacks:
- Changing messaging requires code changes and redeployment
- Messages can't be customized per-tenant or localized
- Technical details leak into user-facing summaries
- No separation between what happened (data) and how to describe it (presentation)

### The Solution: Annotation-Driven Templates

Controllers should emit **structured data** in event annotations, while **ActivityPolicy templates** control the user-facing message. This separates concerns:

| Layer | Responsibility |
|-------|----------------|
| Controller | Emit events with structured data in annotations |
| ActivityPolicy | Transform data into user-friendly summaries |

### Annotation Conventions

Use a consistent annotation prefix for activity-relevant data:

```go
const (
    // Annotation prefix for activity template data
    ActivityAnnotationPrefix = "activity.miloapis.com/"
)

// Common annotation keys
const (
    // Human-readable display name (preferred over .metadata.name)
    AnnotationDisplayName = ActivityAnnotationPrefix + "display-name"

    // Action performed (for custom action descriptions)
    AnnotationAction = ActivityAnnotationPrefix + "action"

    // Target of the action (when different from the event's regarding object)
    AnnotationTarget = ActivityAnnotationPrefix + "target"

    // Actor override (when system acts on behalf of a user)
    AnnotationActorName = ActivityAnnotationPrefix + "actor-name"

    // Numeric values for summaries
    AnnotationOldValue = ActivityAnnotationPrefix + "old-value"
    AnnotationNewValue = ActivityAnnotationPrefix + "new-value"

    // Resource counts
    AnnotationCount = ActivityAnnotationPrefix + "count"

    // Duration or timing
    AnnotationDuration = ActivityAnnotationPrefix + "duration"

    // Error category (user-friendly, not technical)
    AnnotationErrorCategory = ActivityAnnotationPrefix + "error-category"
)
```

### Emitting Annotated Events

Use `AnnotatedEventf` to include structured data:

```go
func (r *MyResourceReconciler) emitScaledEvent(resource *v1alpha1.MyResource, oldReplicas, newReplicas int) {
    annotations := map[string]string{
        "activity.miloapis.com/old-value":    strconv.Itoa(oldReplicas),
        "activity.miloapis.com/new-value":    strconv.Itoa(newReplicas),
        "activity.miloapis.com/display-name": resource.Spec.DisplayName,
    }

    var reason string
    if newReplicas > oldReplicas {
        reason = "ScaledUp"
    } else {
        reason = "ScaledDown"
    }

    // Message is for kubectl/logs; annotations are for ActivityPolicy
    r.Recorder.AnnotatedEventf(resource, annotations, corev1.EventTypeNormal, reason,
        "Scaled from %d to %d replicas", oldReplicas, newReplicas)
}
```

```go
func (r *MyResourceReconciler) emitReadyEvent(resource *v1alpha1.MyResource) {
    annotations := map[string]string{
        "activity.miloapis.com/display-name": resource.Spec.DisplayName,
        "activity.miloapis.com/endpoint":     resource.Status.Endpoint,
    }

    r.Recorder.AnnotatedEventf(resource, annotations, corev1.EventTypeNormal, "Ready",
        "Resource is ready at %s", resource.Status.Endpoint)
}
```

```go
func (r *MyResourceReconciler) emitFailedEvent(resource *v1alpha1.MyResource, err error) {
    // Classify the error for user-friendly messaging
    errorCategory := classifyError(err)

    annotations := map[string]string{
        "activity.miloapis.com/display-name":   resource.Spec.DisplayName,
        "activity.miloapis.com/error-category": errorCategory,
    }

    r.Recorder.AnnotatedEventf(resource, annotations, corev1.EventTypeWarning, "Failed",
        "Operation failed: %v", err)
}

func classifyError(err error) string {
    switch {
    case errors.Is(err, ErrQuotaExceeded):
        return "quota_exceeded"
    case errors.Is(err, ErrPermissionDenied):
        return "permission_denied"
    case errors.Is(err, ErrInvalidConfiguration):
        return "invalid_configuration"
    case errors.Is(err, ErrDependencyUnavailable):
        return "dependency_unavailable"
    default:
        return "internal_error"
    }
}
```

### Accessing Annotations in ActivityPolicy

ActivityPolicy templates access event annotations via `event.annotations`:

```yaml
apiVersion: activity.miloapis.com/v1alpha1
kind: ActivityPolicy
metadata:
  name: myservice-myresource
spec:
  resource:
    apiGroup: myservice.miloapis.com
    kind: MyResource

  eventRules:
    # Use display name from annotation instead of metadata.name
    - match: "event.reason == 'Ready'"
      summary: "{{ link(event.annotations['activity.miloapis.com/display-name'], event.regarding) }} is ready"

    # Include structured values in summary
    - match: "event.reason == 'ScaledUp'"
      summary: "{{ link(event.annotations['activity.miloapis.com/display-name'], event.regarding) }} scaled from {{ event.annotations['activity.miloapis.com/old-value'] }} to {{ event.annotations['activity.miloapis.com/new-value'] }} replicas"

    - match: "event.reason == 'ScaledDown'"
      summary: "{{ link(event.annotations['activity.miloapis.com/display-name'], event.regarding) }} scaled down from {{ event.annotations['activity.miloapis.com/old-value'] }} to {{ event.annotations['activity.miloapis.com/new-value'] }} replicas"

    # User-friendly error messages based on category
    - match: "event.reason == 'Failed' && event.annotations['activity.miloapis.com/error-category'] == 'quota_exceeded'"
      summary: "{{ link(event.annotations['activity.miloapis.com/display-name'], event.regarding) }} could not complete: resource quota exceeded"

    - match: "event.reason == 'Failed' && event.annotations['activity.miloapis.com/error-category'] == 'permission_denied'"
      summary: "{{ link(event.annotations['activity.miloapis.com/display-name'], event.regarding) }} could not complete: insufficient permissions"

    - match: "event.reason == 'Failed' && event.annotations['activity.miloapis.com/error-category'] == 'invalid_configuration'"
      summary: "{{ link(event.annotations['activity.miloapis.com/display-name'], event.regarding) }} has invalid configuration"

    # Fallback for unclassified errors
    - match: "event.reason == 'Failed'"
      summary: "{{ link(event.annotations['activity.miloapis.com/display-name'], event.regarding) }} encountered an error"
```

### Benefits of Annotation-Driven Messaging

| Benefit | Example |
|---------|---------|
| **Change messaging without code** | Update ActivityPolicy to say "instances" instead of "replicas" |
| **User-friendly names** | Show "Production API Gateway" instead of "prod-api-gw-7f8d9" |
| **Localization-ready** | Different ActivityPolicies per locale (future) |
| **Error classification** | Map internal errors to user-friendly categories |
| **Consistent formatting** | Policy controls number formatting, units, etc. |
| **A/B testing messages** | Test different phrasings without code changes |

### Common Annotation Patterns

#### Display Names

Always include a human-readable display name:

```go
annotations := map[string]string{
    "activity.miloapis.com/display-name": resource.Spec.DisplayName,
}
```

Template:
```yaml
summary: "{{ event.annotations['activity.miloapis.com/display-name'] }} is ready"
# Output: "Production API Gateway is ready"
# Instead of: "prod-api-gw-7f8d9 is ready"
```

#### Before/After Values

For changes, include old and new values:

```go
annotations := map[string]string{
    "activity.miloapis.com/old-value": oldValue,
    "activity.miloapis.com/new-value": newValue,
    "activity.miloapis.com/field":     "replicas",
}
```

Template:
```yaml
summary: "{{ event.annotations['activity.miloapis.com/display-name'] }} {{ event.annotations['activity.miloapis.com/field'] }} changed from {{ event.annotations['activity.miloapis.com/old-value'] }} to {{ event.annotations['activity.miloapis.com/new-value'] }}"
```

#### Counts and Quantities

Include counts for batch operations:

```go
annotations := map[string]string{
    "activity.miloapis.com/count": strconv.Itoa(len(items)),
}
```

Template:
```yaml
summary: "Processed {{ event.annotations['activity.miloapis.com/count'] }} items for {{ link(event.annotations['activity.miloapis.com/display-name'], event.regarding) }}"
```

#### Duration and Timing

Include timing for operations:

```go
annotations := map[string]string{
    "activity.miloapis.com/duration": duration.String(),
}
```

Template:
```yaml
summary: "{{ link(event.annotations['activity.miloapis.com/display-name'], event.regarding) }} provisioning completed in {{ event.annotations['activity.miloapis.com/duration'] }}"
```

#### Related Resources

Reference related resources:

```go
annotations := map[string]string{
    "activity.miloapis.com/related-kind": "Gateway",
    "activity.miloapis.com/related-name": gateway.Name,
}
```

Template:
```yaml
summary: "{{ link(event.annotations['activity.miloapis.com/display-name'], event.regarding) }} attached to {{ event.annotations['activity.miloapis.com/related-kind'] }} {{ event.annotations['activity.miloapis.com/related-name'] }}"
```

### Fallback Handling

Always handle cases where annotations might be missing:

```yaml
eventRules:
  # Prefer display-name, fall back to regarding.name
  - match: "event.reason == 'Ready' && has(event.annotations['activity.miloapis.com/display-name'])"
    summary: "{{ link(event.annotations['activity.miloapis.com/display-name'], event.regarding) }} is ready"

  - match: "event.reason == 'Ready'"
    summary: "{{ link(kind + ' ' + event.regarding.name, event.regarding) }} is ready"
```

Or use CEL's ternary operator:

```yaml
summary: "{{ has(event.annotations['activity.miloapis.com/display-name']) ? event.annotations['activity.miloapis.com/display-name'] : event.regarding.name }} is ready"
```

---

## Connecting Events to ActivityPolicy

### Writing Matching Event Rules

For every event reason code your controller emits, create a matching eventRule in your ActivityPolicy:

```yaml
apiVersion: activity.miloapis.com/v1alpha1
kind: ActivityPolicy
metadata:
  name: myservice-myresource
spec:
  resource:
    apiGroup: myservice.miloapis.com
    kind: MyResource

  eventRules:
    # Lifecycle events
    - match: "event.reason == 'Ready'"
      summary: "{{ link(kind + ' ' + event.regarding.name, event.regarding) }} is now ready"

    - match: "event.reason == 'Progressing'"
      summary: "{{ link(kind + ' ' + event.regarding.name, event.regarding) }} is being updated"

    # Provisioning events
    - match: "event.reason == 'Provisioning'"
      summary: "{{ link(kind + ' ' + event.regarding.name, event.regarding) }} provisioning started"

    - match: "event.reason == 'Provisioned'"
      summary: "{{ link(kind + ' ' + event.regarding.name, event.regarding) }} provisioning complete"

    - match: "event.reason == 'ProvisioningFailed'"
      summary: "{{ link(kind + ' ' + event.regarding.name, event.regarding) }} failed to provision: {{ event.message }}"

    # Scaling events
    - match: "event.reason == 'ScaledUp'"
      summary: "{{ link(kind + ' ' + event.regarding.name, event.regarding) }} scaled up"

    - match: "event.reason == 'ScaledDown'"
      summary: "{{ link(kind + ' ' + event.regarding.name, event.regarding) }} scaled down"

    # Warning events (catch-all for unmatched warnings)
    - match: "event.type == 'Warning' && !event.reason.startsWith('Scaling')"
      summary: "Warning for {{ link(kind + ' ' + event.regarding.name, event.regarding) }}: {{ event.message }}"
```

### Including Message Content

Use `event.message` to include the message in the activity summary:

```yaml
# Full message for errors
- match: "event.reason == 'Failed'"
  summary: "{{ link(kind + ' ' + event.regarding.name, event.regarding) }} failed: {{ event.message }}"

# Message only for context
- match: "event.reason == 'ConfigurationApplied'"
  summary: "{{ link(kind + ' ' + event.regarding.name, event.regarding) }} configuration updated"
```

### Filtering Events

Not all events should become activities. Use match expressions to filter:

```yaml
eventRules:
  # Only show Ready, not Progressing (too noisy)
  - match: "event.reason == 'Ready'"
    summary: "{{ link(kind + ' ' + event.regarding.name, event.regarding) }} is ready"

  # Only show warnings, not routine normal events
  - match: "event.type == 'Warning'"
    summary: "{{ link(kind + ' ' + event.regarding.name, event.regarding) }}: {{ event.message }}"

  # Skip internal events
  - match: "event.reason == 'Scheduled'"
    # No summary = event is filtered out
```

---

## Testing Event Integration

### Unit Test Pattern

Test that your controller emits expected events:

```go
func TestReconciler_EmitsReadyEvent(t *testing.T) {
    // Setup
    scheme := runtime.NewScheme()
    _ = v1alpha1.AddToScheme(scheme)

    resource := &v1alpha1.MyResource{
        ObjectMeta: metav1.ObjectMeta{
            Name:      "test-resource",
            Namespace: "default",
        },
    }

    fakeClient := fake.NewClientBuilder().
        WithScheme(scheme).
        WithObjects(resource).
        Build()

    recorder := record.NewFakeRecorder(10)

    reconciler := &MyResourceReconciler{
        Client:   fakeClient,
        Scheme:   scheme,
        Recorder: recorder,
    }

    // Act
    _, err := reconciler.Reconcile(context.Background(), ctrl.Request{
        NamespacedName: types.NamespacedName{
            Name:      "test-resource",
            Namespace: "default",
        },
    })
    require.NoError(t, err)

    // Assert
    select {
    case event := <-recorder.Events:
        assert.Contains(t, event, "Normal")
        assert.Contains(t, event, "Ready")
    default:
        t.Fatal("Expected Ready event was not emitted")
    }
}
```

### Integration Test with Activity

Test that events flow through to activities:

```go
func TestActivityIntegration_EventsAppearInTimeline(t *testing.T) {
    ctx := context.Background()

    // Create resource (triggers controller)
    resource := &v1alpha1.MyResource{
        ObjectMeta: metav1.ObjectMeta{
            Name:      "test-resource",
            Namespace: "test-ns",
        },
    }
    _, err := client.MyResources("test-ns").Create(ctx, resource, metav1.CreateOptions{})
    require.NoError(t, err)

    // Wait for Ready event to become activity
    require.Eventually(t, func() bool {
        query := &activityv1alpha1.ActivityQuery{
            Spec: activityv1alpha1.ActivityQuerySpec{
                StartTime:    "now-5m",
                ResourceKind: "MyResource",
                Namespace:    "test-ns",
                Filter:       "spec.summary.contains('ready')",
            },
        }
        result, err := activityClient.ActivityQueries().Create(ctx, query, metav1.CreateOptions{})
        if err != nil {
            return false
        }
        return len(result.Status.Results) > 0
    }, 30*time.Second, 1*time.Second, "Ready event did not appear in activity timeline")
}
```

---

## Checklist

Before shipping event integration:

### Event Emission
- [ ] Event recorder set up in controller/REST handler
- [ ] Consistent reason codes used (PascalCase, standard vocabulary)
- [ ] Normal events for success, Warning events for problems
- [ ] Events emitted only on state transitions (not every reconcile)

### User-Friendly Messaging
- [ ] Display names included via `activity.miloapis.com/display-name` annotation
- [ ] Structured data in annotations (not embedded in message strings)
- [ ] Error categories classified for user-friendly messages
- [ ] Before/after values included for change events

### ActivityPolicy Integration
- [ ] ActivityPolicy eventRules match all reason codes
- [ ] Templates use annotations for user-friendly summaries
- [ ] Fallbacks handle missing annotations gracefully
- [ ] Noisy events filtered out in ActivityPolicy

### Testing
- [ ] Unit tests verify event emission and annotations
- [ ] Integration test verifies events appear in activity timeline

---

## Related Files

- `SKILL.md` — Activity system overview
- `implementation.md` — ActivityPolicy creation guide
- `concepts.md` — Activity data model
- `consuming-timelines.md` — How users view activity timelines
