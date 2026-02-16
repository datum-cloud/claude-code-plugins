# Activity Implementation Guide

This guide explains how to integrate your service with the Activity system to provide human-readable activity timelines for your resources.

## Integration Overview

The Activity system transforms raw Kubernetes audit logs and events into human-readable activity summaries. Your integration consists of:

1. **Create ActivityPolicy resources** — Define how your resource operations appear in timelines
2. **Deploy policies** — Include in your service's Kustomize deployment
3. **Test with PolicyPreview** — Validate rules before deployment

**No code changes required** — The Kubernetes API server already generates audit logs for all API operations. Your policies just define how those logs are translated.

---

## Step 1: Identify Your Resources

List the resources in your service that users care about tracking:

| Resource | API Group | Important Operations |
|----------|-----------|---------------------|
| MyResource | myservice.miloapis.com | create, update, delete |
| MyConfig | myservice.miloapis.com | create, update, delete |

### Deciding What to Track

**Always track**:
- Resource creation and deletion
- Significant configuration changes
- Permission/access changes
- State transitions users care about

**Consider tracking**:
- Status subresource updates (for controller-driven changes)
- Scale operations
- Finalizer additions/removals

**Skip tracking**:
- High-frequency status updates (use events instead)
- Internal reconciliation chatter
- System-only fields

---

## Step 2: Create ActivityPolicy

Create one ActivityPolicy per resource kind. Place in `config/apiserver/policies/`.

### Basic Policy Structure

```yaml
apiVersion: activity.miloapis.com/v1alpha1
kind: ActivityPolicy
metadata:
  name: myservice-myresource
spec:
  # Target resource
  resource:
    apiGroup: myservice.miloapis.com
    kind: MyResource

  # Rules for audit log entries
  auditRules:
    - match: "<CEL expression>"
      summary: "<template with {{ expressions }}>"

  # Rules for Kubernetes events (optional)
  eventRules:
    - match: "<CEL expression>"
      summary: "<template>"
```

### Complete Example: Basic Resource

```yaml
apiVersion: activity.miloapis.com/v1alpha1
kind: ActivityPolicy
metadata:
  name: myservice-myresource
spec:
  resource:
    apiGroup: myservice.miloapis.com
    kind: MyResource

  auditRules:
    # Creation
    - match: "audit.verb == 'create'"
      summary: "{{ actor }} created {{ link(kind + ' ' + audit.objectRef.name, audit.responseObject) }}"

    # Deletion
    - match: "audit.verb == 'delete'"
      summary: "{{ actor }} deleted {{ kind }} {{ audit.objectRef.name }}"

    # Update (excludes status-only updates)
    - match: "audit.verb in ['update', 'patch'] && audit.objectRef.subresource == ''"
      summary: "{{ actor }} updated {{ link(kind + ' ' + audit.objectRef.name, audit.objectRef) }}"

    # Status updates (if you want to track them)
    - match: "audit.objectRef.subresource == 'status'"
      summary: "{{ link(kind + ' ' + audit.objectRef.name, audit.objectRef) }} status changed"

  eventRules:
    # Controller events
    - match: "event.reason == 'Ready'"
      summary: "{{ link(kind + ' ' + event.regarding.name, event.regarding) }} is now ready"

    - match: "event.reason == 'Failed'"
      summary: "{{ link(kind + ' ' + event.regarding.name, event.regarding) }} failed: {{ event.message }}"
```

---

## Step 3: Define Audit Rules

### Match Expression Patterns

Match expressions are pure CEL that return boolean:

```yaml
# Match specific verbs
- match: "audit.verb == 'create'"
- match: "audit.verb == 'delete'"
- match: "audit.verb in ['update', 'patch']"

# Match subresources
- match: "audit.objectRef.subresource == 'status'"
- match: "audit.objectRef.subresource == 'scale'"
- match: "audit.objectRef.subresource == ''"  # Main resource only

# Combine conditions
- match: "audit.verb == 'update' && audit.objectRef.subresource == ''"

# Match error responses
- match: "audit.responseStatus.code >= 400"

# Match by user type
- match: "audit.user.username.startsWith('system:')"
- match: "!audit.user.username.startsWith('system:')"
```

### Summary Template Patterns

Templates use `{{ }}` delimiters with CEL expressions inside:

```yaml
# Basic with actor and kind
summary: "{{ actor }} created {{ kind }}"

# With resource link (clickable in UI)
summary: "{{ actor }} created {{ link(kind + ' ' + audit.objectRef.name, audit.responseObject) }}"

# With conditional human/system detection
summary: "{{ audit.user.username.startsWith('system:') ? 'System' : actor }} updated {{ kind }}"

# Include specific field from response
summary: "{{ actor }} updated {{ kind }} {{ audit.objectRef.name }} replicas to {{ audit.responseObject.spec.replicas }}"

# Subresource operation
summary: "{{ actor }} scaled {{ link(kind + ' ' + audit.objectRef.name, audit.objectRef) }}"
```

### Built-in Variables

| Variable | Type | Description |
|----------|------|-------------|
| `actor` | string | Resolved display name for the user/SA |
| `kind` | string | Resource kind from policy spec |
| `audit` | object | Full audit.Event from API server |
| `audit.verb` | string | create, update, patch, delete, etc. |
| `audit.objectRef` | object | Target resource reference |
| `audit.objectRef.name` | string | Resource name |
| `audit.objectRef.namespace` | string | Resource namespace |
| `audit.objectRef.subresource` | string | Subresource name or empty |
| `audit.user` | object | Authenticated user info |
| `audit.user.username` | string | User identifier |
| `audit.responseObject` | object | The created/updated resource |
| `audit.responseStatus` | object | HTTP response status |

### The link() Function

Creates clickable references in the UI:

```yaml
# link(displayText, resourceReference)
summary: "{{ link(kind + ' ' + audit.objectRef.name, audit.responseObject) }}"
```

The second argument must be a resource reference object with apiGroup, kind, name, namespace.

---

## Step 4: Define Event Rules (Optional)

Event rules translate Kubernetes events emitted by your controllers into activity entries.

**Important**: For your events to be consumed by the Activity system, controllers must emit them correctly. Read `emitting-events.md` for the complete guide on:
- Setting up event recorders
- Standard reason codes and message patterns
- Event emission best practices

### When to Use Event Rules

- Controller state transitions (Ready, Failed, Progressing)
- Async operation completion
- Warning/error conditions
- Events that represent user-visible state changes

### Event Match Patterns

```yaml
# Match by reason
- match: "event.reason == 'Ready'"
- match: "event.reason == 'Failed'"
- match: "event.reason == 'Progressing'"

# Match by type
- match: "event.type == 'Warning'"
- match: "event.type == 'Normal'"

# Combine conditions
- match: "event.reason == 'Failed' && event.type == 'Warning'"
```

### Event Variables

| Variable | Type | Description |
|----------|------|-------------|
| `event` | object | Full core/v1 Event object |
| `event.reason` | string | Event reason code |
| `event.type` | string | Normal or Warning |
| `event.message` | string | Event message text |
| `event.regarding` | object | Resource the event is about |
| `event.regarding.name` | string | Resource name |
| `event.regarding.namespace` | string | Resource namespace |
| `actor` | string | Always "System" for events |
| `kind` | string | Resource kind from policy spec |

### Event Summary Examples

Basic examples using event.regarding:

```yaml
eventRules:
  - match: "event.reason == 'Ready'"
    summary: "{{ link(kind + ' ' + event.regarding.name, event.regarding) }} is now ready"

  - match: "event.reason == 'Failed'"
    summary: "{{ link(kind + ' ' + event.regarding.name, event.regarding) }} failed: {{ event.message }}"

  - match: "event.reason == 'Progressing'"
    summary: "{{ link(kind + ' ' + event.regarding.name, event.regarding) }} is progressing"

  - match: "event.reason == 'ScaledUp'"
    summary: "{{ link(kind + ' ' + event.regarding.name, event.regarding) }} scaled up"

  - match: "event.type == 'Warning'"
    summary: "Warning for {{ link(kind + ' ' + event.regarding.name, event.regarding) }}: {{ event.message }}"
```

### Using Event Annotations for User-Friendly Messages

For better user experience, controllers should emit events with annotations containing structured data. ActivityPolicy templates then use these annotations to create user-friendly summaries. See `emitting-events.md` for the complete pattern.

```yaml
eventRules:
  # Use display-name annotation for human-readable names
  - match: "event.reason == 'Ready' && has(event.annotations['activity.miloapis.com/display-name'])"
    summary: "{{ link(event.annotations['activity.miloapis.com/display-name'], event.regarding) }} is ready"

  # Include structured values from annotations
  - match: "event.reason == 'ScaledUp'"
    summary: "{{ link(event.annotations['activity.miloapis.com/display-name'], event.regarding) }} scaled from {{ event.annotations['activity.miloapis.com/old-value'] }} to {{ event.annotations['activity.miloapis.com/new-value'] }} replicas"

  # Use error category for user-friendly error messages
  - match: "event.reason == 'Failed' && event.annotations['activity.miloapis.com/error-category'] == 'quota_exceeded'"
    summary: "{{ link(event.annotations['activity.miloapis.com/display-name'], event.regarding) }} could not complete: resource quota exceeded"

  # Fallback for events without annotations
  - match: "event.reason == 'Ready'"
    summary: "{{ link(kind + ' ' + event.regarding.name, event.regarding) }} is ready"
```

**Benefits of annotation-driven messaging:**
- Change user-facing text without code changes (update ActivityPolicy only)
- Display human-readable names instead of Kubernetes resource names
- Provide structured values (counts, before/after) for rich summaries
- Classify errors into user-friendly categories

---

## Step 5: Handle Subresources

Many resources have subresources (status, scale, etc.) that generate separate audit entries.

### Common Pattern: Skip Status Updates

```yaml
auditRules:
  # Only match main resource updates
  - match: "audit.verb in ['update', 'patch'] && audit.objectRef.subresource == ''"
    summary: "{{ actor }} updated {{ link(kind + ' ' + audit.objectRef.name, audit.objectRef) }}"
```

### Pattern: Track Status Separately

```yaml
auditRules:
  # Main resource updates
  - match: "audit.verb in ['update', 'patch'] && audit.objectRef.subresource == ''"
    summary: "{{ actor }} updated {{ link(kind + ' ' + audit.objectRef.name, audit.objectRef) }}"

  # Status updates (system-driven)
  - match: "audit.objectRef.subresource == 'status'"
    summary: "{{ link(kind + ' ' + audit.objectRef.name, audit.objectRef) }} status changed"
```

### Pattern: Scale Operations

```yaml
auditRules:
  - match: "audit.objectRef.subresource == 'scale'"
    summary: "{{ actor }} scaled {{ link(kind + ' ' + audit.objectRef.name, audit.objectRef) }}"
```

---

## Step 6: Distinguish Human vs System Actions

### Using the Actor Variable

The `actor` variable is pre-resolved to a display name. For human users, it's typically their email. For system accounts, it includes the service account path.

```yaml
# Simple approach - just use actor
summary: "{{ actor }} created {{ kind }}"
# Output: "alice@example.com created MyResource"
# Output: "system:serviceaccount:kube-system:deployment-controller created MyResource"
```

### Conditional Human/System Detection

```yaml
# More readable summaries
summary: "{{ audit.user.username.startsWith('system:') ? 'System' : actor }} created {{ kind }}"
# Output: "alice@example.com created MyResource"
# Output: "System created MyResource"
```

### Filter by Change Source

The activity system automatically sets `changeSource` to `human` or `system` based on the actor. Users can filter:

```bash
kubectl get activities --field-selector spec.changeSource=human
```

---

## Step 7: Test with PolicyPreview

Before deploying, test your policies using PolicyPreview.

### Create a PolicyPreview Resource

```yaml
apiVersion: activity.miloapis.com/v1alpha1
kind: PolicyPreview
metadata:
  name: test-myresource-policy
spec:
  policy:
    resource:
      apiGroup: myservice.miloapis.com
      kind: MyResource
    auditRules:
      - match: "audit.verb == 'create'"
        summary: "{{ actor }} created {{ link(kind + ' ' + audit.objectRef.name, audit.responseObject) }}"
      - match: "audit.verb == 'delete'"
        summary: "{{ actor }} deleted {{ kind }} {{ audit.objectRef.name }}"

  inputs:
    # Test create operation
    - type: audit
      audit:
        verb: create
        objectRef:
          apiGroup: myservice.miloapis.com
          resource: myresources
          name: test-resource
          namespace: test-project
        user:
          username: alice@example.com
        responseObject:
          apiVersion: myservice.miloapis.com/v1alpha1
          kind: MyResource
          metadata:
            name: test-resource
            namespace: test-project

    # Test delete operation
    - type: audit
      audit:
        verb: delete
        objectRef:
          apiGroup: myservice.miloapis.com
          resource: myresources
          name: test-resource
          namespace: test-project
        user:
          username: bob@example.com
```

### Check Preview Results

```bash
kubectl apply -f policy-preview.yaml
kubectl get policypreview test-myresource-policy -o yaml
```

The status shows:
- Which inputs matched which rules
- Rendered summary text
- Any errors in expressions

```yaml
status:
  results:
    - inputIndex: 0
      matched: true
      ruleIndex: 0
      activity:
        spec:
          summary: "alice@example.com created MyResource test-resource"
          actor:
            name: alice@example.com
            type: user
    - inputIndex: 1
      matched: true
      ruleIndex: 1
      activity:
        spec:
          summary: "bob@example.com deleted MyResource test-resource"
```

---

## Step 8: Deploy Policies

### Directory Structure

```
config/
  apiserver/
    policies/
      kustomization.yaml
      myresource-policy.yaml
      myconfig-policy.yaml
```

### Kustomization

```yaml
# config/apiserver/policies/kustomization.yaml
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization

resources:
  - myresource-policy.yaml
  - myconfig-policy.yaml
```

### Include in Main Deployment

```yaml
# config/apiserver/kustomization.yaml
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization

resources:
  - deployment.yaml
  - service.yaml
  - policies/
```

---

## Complete Policy Examples

### Example 1: Compute Instance

```yaml
apiVersion: activity.miloapis.com/v1alpha1
kind: ActivityPolicy
metadata:
  name: compute-instance
spec:
  resource:
    apiGroup: myservice.miloapis.com
    kind: Instance

  auditRules:
    - match: "audit.verb == 'create'"
      summary: "{{ actor }} created {{ link('instance ' + audit.objectRef.name, audit.responseObject) }}"

    - match: "audit.verb == 'delete'"
      summary: "{{ actor }} deleted instance {{ audit.objectRef.name }}"

    - match: "audit.verb in ['update', 'patch'] && audit.objectRef.subresource == ''"
      summary: "{{ actor }} updated {{ link('instance ' + audit.objectRef.name, audit.objectRef) }}"

    - match: "audit.objectRef.subresource == 'start'"
      summary: "{{ actor }} started {{ link('instance ' + audit.objectRef.name, audit.objectRef) }}"

    - match: "audit.objectRef.subresource == 'stop'"
      summary: "{{ actor }} stopped {{ link('instance ' + audit.objectRef.name, audit.objectRef) }}"

  eventRules:
    - match: "event.reason == 'Running'"
      summary: "{{ link('Instance ' + event.regarding.name, event.regarding) }} is now running"

    - match: "event.reason == 'Stopped'"
      summary: "{{ link('Instance ' + event.regarding.name, event.regarding) }} has stopped"

    - match: "event.reason == 'ProvisioningFailed'"
      summary: "{{ link('Instance ' + event.regarding.name, event.regarding) }} failed to provision: {{ event.message }}"
```

### Example 2: Networking HTTPProxy

```yaml
apiVersion: activity.miloapis.com/v1alpha1
kind: ActivityPolicy
metadata:
  name: networking-httpproxy
spec:
  resource:
    apiGroup: otherservice.miloapis.com
    kind: HTTPProxy

  auditRules:
    - match: "audit.verb == 'create'"
      summary: "{{ actor }} created {{ link('HTTPProxy ' + audit.objectRef.name, audit.responseObject) }}"

    - match: "audit.verb == 'delete'"
      summary: "{{ actor }} deleted HTTPProxy {{ audit.objectRef.name }}"

    - match: "audit.verb in ['update', 'patch'] && audit.objectRef.subresource == ''"
      summary: "{{ actor }} updated {{ link('HTTPProxy ' + audit.objectRef.name, audit.objectRef) }}"

  eventRules:
    - match: "event.reason == 'Programmed'"
      summary: "{{ link('HTTPProxy ' + event.regarding.name, event.regarding) }} is now programmed"

    - match: "event.reason == 'CertificateIssued'"
      summary: "Certificate issued for {{ link('HTTPProxy ' + event.regarding.name, event.regarding) }}"

    - match: "event.reason == 'CertificateFailed'"
      summary: "Certificate failed for {{ link('HTTPProxy ' + event.regarding.name, event.regarding) }}: {{ event.message }}"
```

### Example 3: RBAC Resources

```yaml
apiVersion: activity.miloapis.com/v1alpha1
kind: ActivityPolicy
metadata:
  name: iam-role
spec:
  resource:
    apiGroup: iam.miloapis.com
    kind: Role

  auditRules:
    - match: "audit.verb == 'create'"
      summary: "{{ actor }} created role {{ link(audit.objectRef.name, audit.responseObject) }}"

    - match: "audit.verb == 'delete'"
      summary: "{{ actor }} deleted role {{ audit.objectRef.name }}"

    - match: "audit.verb in ['update', 'patch'] && audit.objectRef.subresource == ''"
      summary: "{{ actor }} updated role {{ link(audit.objectRef.name, audit.objectRef) }}"
---
apiVersion: activity.miloapis.com/v1alpha1
kind: ActivityPolicy
metadata:
  name: iam-policybinding
spec:
  resource:
    apiGroup: iam.miloapis.com
    kind: PolicyBinding

  auditRules:
    - match: "audit.verb == 'create'"
      summary: "{{ actor }} granted {{ link(audit.responseObject.spec.roleRef.name, audit.responseObject.spec.roleRef) }} to {{ audit.responseObject.spec.subject.name }}"

    - match: "audit.verb == 'delete'"
      summary: "{{ actor }} revoked policy binding {{ audit.objectRef.name }}"
```

---

## Testing Activity Integration

### Manual Testing

1. **Deploy the policy**:
   ```bash
   kubectl apply -f config/apiserver/policies/
   ```

2. **Perform operations**:
   ```bash
   kubectl apply -f test-resource.yaml
   kubectl patch myresource test -p '{"spec":{"replicas":3}}'
   kubectl delete myresource test
   ```

3. **Watch activities**:
   ```bash
   kubectl get activities --watch
   ```

4. **Query historical**:
   ```bash
   kubectl create -f - <<EOF
   apiVersion: activity.miloapis.com/v1alpha1
   kind: ActivityQuery
   metadata:
     name: test-query
   spec:
     startTime: "now-1h"
     resourceKind: MyResource
   EOF
   kubectl get activityquery test-query -o yaml
   ```

### Integration Test Pattern

```go
func TestActivityPolicy(t *testing.T) {
    ctx := context.Background()

    // Apply the policy
    policy := loadPolicy(t, "testdata/myresource-policy.yaml")
    _, err := activityClient.ActivityPolicies().Create(ctx, policy, metav1.CreateOptions{})
    require.NoError(t, err)

    // Create a resource
    resource := &v1alpha1.MyResource{
        ObjectMeta: metav1.ObjectMeta{
            Name:      "test-resource",
            Namespace: "test-ns",
        },
    }
    _, err = client.MyResources("test-ns").Create(ctx, resource, metav1.CreateOptions{})
    require.NoError(t, err)

    // Wait for activity to appear
    var activities *activityv1alpha1.ActivityList
    require.Eventually(t, func() bool {
        query := &activityv1alpha1.ActivityQuery{
            Spec: activityv1alpha1.ActivityQuerySpec{
                StartTime:    "now-5m",
                ResourceKind: "MyResource",
                Namespace:    "test-ns",
            },
        }
        result, err := activityClient.ActivityQueries().Create(ctx, query, metav1.CreateOptions{})
        if err != nil {
            return false
        }
        activities = &activityv1alpha1.ActivityList{Items: result.Status.Results}
        return len(activities.Items) > 0
    }, 30*time.Second, 1*time.Second)

    // Verify activity content
    require.Len(t, activities.Items, 1)
    activity := activities.Items[0]
    assert.Contains(t, activity.Spec.Summary, "created")
    assert.Contains(t, activity.Spec.Summary, "test-resource")
    assert.Equal(t, "MyResource", activity.Spec.Resource.Kind)
}
```

---

## Checklist

Before shipping activity integration:

- [ ] ActivityPolicy created for each user-facing resource kind
- [ ] Policies cover create, update, and delete operations
- [ ] Status/subresource updates handled appropriately (included or excluded)
- [ ] Event rules added for controller state transitions
- [ ] Summaries are human-readable and actionable
- [ ] Links use correct resource references
- [ ] PolicyPreview tested with sample inputs
- [ ] Policies deployed via Kustomize
- [ ] Integration tests verify activity generation
- [ ] Documented which operations generate activities

---

## Troubleshooting

### Activities Not Appearing

1. **Check policy exists**:
   ```bash
   kubectl get activitypolicy
   ```

2. **Verify policy matches your resource**:
   ```bash
   kubectl get activitypolicy myservice-myresource -o yaml
   ```

3. **Check audit logs are flowing**:
   ```bash
   kubectl create -f - <<EOF
   apiVersion: activity.miloapis.com/v1alpha1
   kind: AuditLogQuery
   spec:
     startTime: "now-1h"
     resource:
       apiGroup: myservice.miloapis.com
       kind: MyResource
   EOF
   ```

4. **Test with PolicyPreview** to validate rules match

### Wrong Actor Shown

Check the audit log to see what user information is available:
```bash
# Query raw audit logs
kubectl get auditlogquery -o yaml
```

### Links Not Working

Ensure the resource reference in `link()` has correct:
- apiGroup
- kind
- name
- namespace (for namespaced resources)

Use `audit.responseObject` for creates (has full object), `audit.objectRef` for updates/deletes.
