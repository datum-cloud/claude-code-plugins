# Quota Implementation Guide

This guide explains how to integrate your service with the Milo quota system.

## Integration Overview

There are **two integration patterns**:

### Pattern 1: Policy-Driven (Recommended for most cases)

Use ClaimCreationPolicy for automatic enforcement at admission time:
- Resource creation is **blocked** if quota is exceeded
- No code changes needed — policies handle everything
- Best for: Simple resources where creation = consumption

### Pattern 2: Service-Managed Claims

Create ResourceClaims directly from your controller:
- Resource is **created but not provisioned** until quota is granted
- Service controls claim lifecycle and handles pending state
- Best for: Auto-scaling, async provisioning, deferred resource activation

Choose Pattern 1 unless you need deferred provisioning behavior.

---

## Pattern 1: Policy-Driven Integration

The quota system handles enforcement transparently via admission webhooks.

## Step 1: Register Your Resource Type

Create a `ResourceRegistration` to tell the quota system about your resource:

```yaml
apiVersion: quota.miloapis.com/v1alpha1
kind: ResourceRegistration
metadata:
  name: myservice-widgets
spec:
  # Unique identifier - use your API group + resource name
  resourceType: "myservice.miloapis.com/widgets"

  # Who can receive quota for this resource type
  consumerType:
    apiGroup: resourcemanager.miloapis.com
    kind: Organization

  # Entity for countable things, Allocation for capacity
  type: Entity

  # Units
  baseUnit: "count"
  displayUnit: "widgets"
  unitConversionFactor: 1

  # Which resources can create claims (your resource type)
  claimingResources:
    - apiGroup: myservice.miloapis.com
      kind: Widget
```

### Choosing Registration Type

| Type | When to Use | Example |
|------|-------------|---------|
| `Entity` | Discrete instances you can count | VMs, Projects, API Keys |
| `Allocation` | Capacity/amounts | Storage GB, CPU cores, Memory |

### Unit Conversion

For capacity-based quotas, use conversion factors for display:

```yaml
spec:
  baseUnit: "bytes"
  displayUnit: "GB"
  unitConversionFactor: 1073741824  # 1 GB = 1024^3 bytes
```

## Step 2: Create a ClaimCreationPolicy for Enforcement

This policy automatically enforces quota when your resources are created:

```yaml
apiVersion: quota.miloapis.com/v1alpha1
kind: ClaimCreationPolicy
metadata:
  name: widget-quota-enforcement
spec:
  trigger:
    resource:
      apiVersion: myservice.miloapis.com/v1alpha1
      kind: Widget
    # Optional: only enforce for certain conditions
    constraints:
      - expression: "!trigger.metadata.labels.exists(k, k == 'quota-exempt')"
        message: "Skip quota-exempt widgets"

  target:
    resourceClaimTemplate:
      metadata:
        generateName: "widget-claim-"
        namespace: "quota-system"
      spec:
        # consumerRef auto-resolved from trigger's organization context
        requests:
          - resourceType: "myservice.miloapis.com/widgets"
            amount: 1
```

### Dynamic Claim Amounts

For capacity-based quotas, use CEL to calculate the amount:

```yaml
spec:
  target:
    resourceClaimTemplate:
      spec:
        requests:
          - resourceType: "myservice.miloapis.com/bytes"
            amount: "{{trigger.spec.sizeGB * 1073741824}}"
```

### Multi-Resource Claims

Request multiple quotas atomically:

```yaml
spec:
  target:
    resourceClaimTemplate:
      spec:
        requests:
          - resourceType: "myservice.miloapis.com/instances"
            amount: 1
          - resourceType: "myservice.miloapis.com/vcpus"
            amount: "{{trigger.spec.vcpus}}"
          - resourceType: "myservice.miloapis.com/memoryGB"
            amount: "{{trigger.spec.memoryGB}}"
```

All requests must succeed or the entire resource creation is rejected.

## Step 3: Create a GrantCreationPolicy for Allocation

This policy automatically allocates quota when organizations are created:

```yaml
apiVersion: quota.miloapis.com/v1alpha1
kind: GrantCreationPolicy
metadata:
  name: widget-default-quota
spec:
  trigger:
    resource:
      apiVersion: resourcemanager.miloapis.com/v1alpha1
      kind: Organization

  target:
    resourceGrantTemplate:
      metadata:
        name: "{{trigger.metadata.name}}-widget-quota"
        namespace: "quota-system"
      spec:
        consumerRef:
          apiGroup: resourcemanager.miloapis.com
          kind: Organization
          name: "{{trigger.metadata.name}}"
        allowances:
          - resourceType: "myservice.miloapis.com/widgets"
            buckets:
              - amount: 10  # Free tier default
```

### Tier-Based Grants

Create separate policies for different tiers:

```yaml
# Free tier policy
apiVersion: quota.miloapis.com/v1alpha1
kind: GrantCreationPolicy
metadata:
  name: widget-quota-free
spec:
  trigger:
    resource:
      apiVersion: resourcemanager.miloapis.com/v1alpha1
      kind: Organization
    constraints:
      - expression: "trigger.spec.tier == 'free' || !has(trigger.spec.tier)"
        message: "Free tier or no tier specified"
  target:
    resourceGrantTemplate:
      spec:
        allowances:
          - resourceType: "myservice.miloapis.com/widgets"
            buckets:
              - amount: 5
---
# Pro tier policy
apiVersion: quota.miloapis.com/v1alpha1
kind: GrantCreationPolicy
metadata:
  name: widget-quota-pro
spec:
  trigger:
    resource:
      apiVersion: resourcemanager.miloapis.com/v1alpha1
      kind: Organization
    constraints:
      - expression: "trigger.spec.tier == 'pro'"
        message: "Pro tier organizations"
  target:
    resourceGrantTemplate:
      spec:
        allowances:
          - resourceType: "myservice.miloapis.com/widgets"
            buckets:
              - amount: 100
---
# Enterprise tier policy
apiVersion: quota.miloapis.com/v1alpha1
kind: GrantCreationPolicy
metadata:
  name: widget-quota-enterprise
spec:
  trigger:
    resource:
      apiVersion: resourcemanager.miloapis.com/v1alpha1
      kind: Organization
    constraints:
      - expression: "trigger.spec.tier == 'enterprise'"
        message: "Enterprise tier organizations"
  target:
    resourceGrantTemplate:
      spec:
        allowances:
          - resourceType: "myservice.miloapis.com/widgets"
            buckets:
              - amount: 1000
```

### Dynamic Grant Amounts

Use CEL to calculate grant amounts from organization attributes:

```yaml
spec:
  target:
    resourceGrantTemplate:
      spec:
        allowances:
          - resourceType: "myservice.miloapis.com/widgets"
            buckets:
              - amount: "{{trigger.spec.quotaOverride.widgets}}"
```

## Step 4: Configure Tier Defaults

Document your tier defaults for commercial consistency:

| Resource Type | Free | Pro | Enterprise |
|---------------|------|-----|------------|
| `myservice.miloapis.com/widgets` | 5 | 100 | 1000 |
| `myservice.miloapis.com/premium-widgets` | 0 | 10 | 100 |

### Tier Design Principles

- **Free**: Enough for meaningful evaluation (3-10 resources)
- **Pro**: Enough for typical production workloads (50-500 resources)
- **Enterprise**: Generous limits for large scale (500+ resources)

Quotas should feel generous. Users hitting limits should feel "I'm growing" not "I'm being restricted."

## CEL Expression Reference

### Constraint Expressions

Pure CEL expressions (no delimiters) that return boolean:

```yaml
constraints:
  # Check labels
  - expression: "trigger.metadata.labels.exists(k, k == 'billable')"

  # Check spec fields
  - expression: "trigger.spec.tier == 'enterprise'"

  # Check user groups
  - expression: "user.groups.exists(g, g == 'quota-admin')"

  # Combine conditions
  - expression: "trigger.spec.environment == 'production' && trigger.spec.replicas > 1"
```

### Template Expressions

CEL expressions in `{{ }}` delimiters embedded in strings:

```yaml
metadata:
  name: "{{trigger.metadata.name}}-quota"
  namespace: "{{trigger.metadata.namespace}}"
  annotations:
    created-for: "{{trigger.spec.owner}}"
spec:
  allowances:
    - amount: "{{trigger.spec.requestedQuota}}"
```

### Available Context Variables

| Variable | Description |
|----------|-------------|
| `trigger` | The resource that triggered the policy |
| `trigger.metadata` | Standard Kubernetes metadata (name, namespace, labels, annotations) |
| `trigger.spec` | The resource's spec |
| `user` | Authenticated user info (username, groups, uid) |
| `requestInfo` | Request metadata (verb, resource, subresource) |

## Testing Quota Integration

### Manual Testing Flow

1. **Create the registration**:
   ```bash
   kubectl apply -f resourceregistration.yaml
   kubectl get resourceregistration myservice-widgets -o yaml
   # Verify: status.conditions[Active].status = True
   ```

2. **Create the policies**:
   ```bash
   kubectl apply -f grantcreationpolicy.yaml
   kubectl apply -f claimcreationpolicy.yaml
   kubectl get grantcreationpolicy -o yaml
   kubectl get claimcreationpolicy -o yaml
   # Verify: status.conditions[Ready].status = True
   ```

3. **Create an organization (triggers grant)**:
   ```bash
   kubectl apply -f test-org.yaml
   kubectl get resourcegrant -n quota-system
   # Verify: Grant created for the organization
   kubectl get allowancebucket -n quota-system
   # Verify: Bucket shows limit from grant
   ```

4. **Create resources until quota exceeded**:
   ```bash
   # Create widgets up to quota limit
   for i in $(seq 1 6); do
     kubectl apply -f widget-$i.yaml
   done
   # Last one should fail with 403 if limit is 5
   ```

5. **Verify quota release on delete**:
   ```bash
   kubectl delete widget widget-1
   kubectl get allowancebucket -n quota-system
   # Verify: available increased by 1
   kubectl apply -f widget-6.yaml
   # Should succeed now
   ```

### Integration Test Pattern

```go
func TestQuotaEnforcement(t *testing.T) {
    ctx := context.Background()

    // Create organization (triggers grant via policy)
    org := &resourcemanagerv1alpha1.Organization{
        ObjectMeta: metav1.ObjectMeta{
            Name: "test-org",
        },
        Spec: resourcemanagerv1alpha1.OrganizationSpec{
            Tier: "free", // Gets 5 widgets
        },
    }
    _, err := client.Create(ctx, org)
    require.NoError(t, err)

    // Wait for grant and bucket
    require.Eventually(t, func() bool {
        bucket, err := quotaClient.Get(ctx, "test-org-widgets")
        return err == nil && bucket.Status.Limit == 5
    }, 10*time.Second, 100*time.Millisecond)

    // Create widgets up to limit
    for i := 0; i < 5; i++ {
        widget := &myservicev1alpha1.Widget{
            ObjectMeta: metav1.ObjectMeta{
                Name:      fmt.Sprintf("widget-%d", i),
                Namespace: "test-org",
            },
        }
        _, err := client.Create(ctx, widget)
        require.NoError(t, err)
    }

    // Verify quota is consumed
    bucket, _ := quotaClient.Get(ctx, "test-org-widgets")
    assert.Equal(t, int64(5), bucket.Status.Allocated)
    assert.Equal(t, int64(0), bucket.Status.Available)

    // Next widget should be rejected
    widget := &myservicev1alpha1.Widget{
        ObjectMeta: metav1.ObjectMeta{
            Name:      "widget-6",
            Namespace: "test-org",
        },
    }
    _, err = client.Create(ctx, widget)
    require.Error(t, err)
    assert.Contains(t, err.Error(), "quota exceeded")

    // Delete a widget
    err = client.Delete(ctx, "widget-0")
    require.NoError(t, err)

    // Wait for quota release
    require.Eventually(t, func() bool {
        bucket, _ := quotaClient.Get(ctx, "test-org-widgets")
        return bucket.Status.Available == 1
    }, 5*time.Second, 100*time.Millisecond)

    // Can create another widget now
    _, err = client.Create(ctx, widget)
    require.NoError(t, err)
}
```

## Handling Quota Exceeded Errors

When quota is exceeded, the API returns a 403 Forbidden. Your service should:

1. **Not retry** — quota errors are deterministic
2. **Surface the error clearly** — tell users why creation failed
3. **Suggest next steps** — link to quota management UI

### Error Response Format

```json
{
  "kind": "Status",
  "apiVersion": "v1",
  "status": "Failure",
  "message": "Insufficient quota resources available",
  "reason": "Forbidden",
  "details": {
    "causes": [
      {
        "reason": "QuotaExceeded",
        "message": "quota exceeded for myservice.miloapis.com/widgets: requested 1, available 0, limit 5",
        "field": "requests[0]"
      }
    ]
  },
  "code": 403
}
```

### Client Error Handling

```go
_, err := client.Create(ctx, widget)
if apierrors.IsForbidden(err) {
    // Check if it's a quota error
    if strings.Contains(err.Error(), "quota exceeded") {
        return fmt.Errorf("widget quota exceeded: upgrade your plan or delete unused widgets")
    }
}
```

## Monitoring Quota

### AllowanceBucket Status

Query bucket status to show users their quota:

```go
bucket, err := quotaClient.AllowanceBuckets("quota-system").Get(ctx, bucketName, metav1.GetOptions{})
if err != nil {
    return err
}

fmt.Printf("Widgets: %d/%d used (%d available)\n",
    bucket.Status.Allocated,
    bucket.Status.Limit,
    bucket.Status.Available)
```

### Metrics

The quota system exports Prometheus metrics:

- `quota_bucket_limit` — Total allocated capacity
- `quota_bucket_allocated` — Currently consumed
- `quota_bucket_available` — Remaining capacity
- `quota_claim_granted_total` — Claims granted
- `quota_claim_denied_total` — Claims denied (quota exceeded)

## Checklist (Pattern 1: Policy-Driven)

Before shipping policy-driven quota integration:

- [ ] ResourceRegistration created for each quota dimension
- [ ] ClaimCreationPolicy created for enforcement
- [ ] GrantCreationPolicy created for each tier
- [ ] Tier defaults documented and reviewed with commercial team
- [ ] Integration tests cover: grant creation, claim success, quota exceeded, quota release
- [ ] Error messages clearly indicate quota exceeded
- [ ] UI shows current quota usage (if applicable)
- [ ] Runbook documents quota increase procedure

---

## Pattern 2: Service-Managed Claims

Use this pattern when resources need to exist before quota is granted (deferred provisioning).

### When to Use

- **Auto-scaling**: Create instance objects ahead of demand, provision when quota available
- **Async workflows**: Resources that already have async provisioning
- **Optimistic creation**: Allow resource to exist for tracking while waiting for quota
- **Graceful handling**: Service decides how to handle quota pending/exceeded states

### Step 1: Register Resource Type (Same as Pattern 1)

Create ResourceRegistration as described above.

### Step 2: Create GrantCreationPolicies (Same as Pattern 1)

Create tier-based GrantCreationPolicies as described above.

### Step 3: Skip ClaimCreationPolicy

Do NOT create a ClaimCreationPolicy. Your service manages claims directly.

### Step 4: Create Claims from Your Controller

When your resource is created, create a ResourceClaim:

```go
func (r *Reconciler) createQuotaClaim(ctx context.Context, resource *v1alpha1.MyResource) error {
    claim := &quotav1alpha1.ResourceClaim{
        ObjectMeta: metav1.ObjectMeta{
            Name:      fmt.Sprintf("%s-quota", resource.Name),
            Namespace: "quota-system",
            // Owner reference ensures claim is deleted when resource is deleted
            OwnerReferences: []metav1.OwnerReference{
                *metav1.NewControllerRef(resource, v1alpha1.SchemeGroupVersion.WithKind("MyResource")),
            },
        },
        Spec: quotav1alpha1.ResourceClaimSpec{
            ConsumerRef: quotav1alpha1.ConsumerRef{
                APIGroup: "resourcemanager.miloapis.com",
                Kind:     "Organization",
                Name:     resource.Spec.Organization,
            },
            Requests: []quotav1alpha1.ResourceRequest{
                {
                    ResourceType: "myservice.miloapis.com/resources",
                    Amount:       1,
                },
            },
            ResourceRef: &quotav1alpha1.UnversionedObjectReference{
                APIGroup:  "myservice.miloapis.com",
                Kind:      "MyResource",
                Name:      resource.Name,
                Namespace: resource.Namespace,
            },
        },
    }
    return r.Client.Create(ctx, claim)
}
```

### Step 5: Watch Claim Status

Check claim status in your reconcile loop:

```go
func (r *Reconciler) Reconcile(ctx context.Context, req ctrl.Request) (ctrl.Result, error) {
    resource := &v1alpha1.MyResource{}
    if err := r.Get(ctx, req.NamespacedName, resource); err != nil {
        return ctrl.Result{}, client.IgnoreNotFound(err)
    }

    // Get the quota claim
    claim := &quotav1alpha1.ResourceClaim{}
    claimKey := types.NamespacedName{
        Name:      fmt.Sprintf("%s-quota", resource.Name),
        Namespace: "quota-system",
    }

    if err := r.Get(ctx, claimKey, claim); err != nil {
        if apierrors.IsNotFound(err) {
            // Create the claim
            if err := r.createQuotaClaim(ctx, resource); err != nil {
                return ctrl.Result{}, err
            }
            resource.Status.Phase = "PendingQuota"
            return ctrl.Result{RequeueAfter: 5 * time.Second}, r.Status().Update(ctx, resource)
        }
        return ctrl.Result{}, err
    }

    // Check claim conditions
    grantedCondition := findCondition(claim.Status.Conditions, "Granted")
    if grantedCondition == nil {
        // Still being evaluated
        resource.Status.Phase = "PendingQuota"
        return ctrl.Result{RequeueAfter: 5 * time.Second}, r.Status().Update(ctx, resource)
    }

    switch grantedCondition.Status {
    case metav1.ConditionTrue:
        // Quota granted - proceed with provisioning
        if resource.Status.Phase == "PendingQuota" {
            resource.Status.Phase = "Provisioning"
            if err := r.Status().Update(ctx, resource); err != nil {
                return ctrl.Result{}, err
            }
        }
        return r.provision(ctx, resource)

    case metav1.ConditionFalse:
        // Quota denied
        resource.Status.Phase = "QuotaExceeded"
        resource.Status.Message = grantedCondition.Message
        return ctrl.Result{}, r.Status().Update(ctx, resource)

    default:
        // Unknown/pending
        return ctrl.Result{RequeueAfter: 5 * time.Second}, nil
    }
}

func findCondition(conditions []metav1.Condition, condType string) *metav1.Condition {
    for i := range conditions {
        if conditions[i].Type == condType {
            return &conditions[i]
        }
    }
    return nil
}
```

### Step 6: Expose Status to Users

Add quota-related status to your resource:

```go
type MyResourceStatus struct {
    Phase   string            `json:"phase,omitempty"`
    Message string            `json:"message,omitempty"`
    Conditions []metav1.Condition `json:"conditions,omitempty"`
}
```

Users see:
```yaml
status:
  phase: PendingQuota
  conditions:
    - type: QuotaGranted
      status: "False"
      reason: PendingEvaluation
      message: "Waiting for quota claim to be evaluated"
```

### Step 7: Handle Quota Release

With owner references, quota is released automatically when the resource is deleted (Kubernetes garbage collection deletes the claim).

If you need manual release (e.g., resource transitions to a state that no longer consumes quota):

```go
func (r *Reconciler) releaseQuota(ctx context.Context, resource *v1alpha1.MyResource) error {
    claim := &quotav1alpha1.ResourceClaim{}
    claimKey := types.NamespacedName{
        Name:      fmt.Sprintf("%s-quota", resource.Name),
        Namespace: "quota-system",
    }
    if err := r.Get(ctx, claimKey, claim); err != nil {
        return client.IgnoreNotFound(err)
    }
    return r.Delete(ctx, claim)
}
```

### Testing Service-Managed Claims

```go
func TestDeferredProvisioning(t *testing.T) {
    ctx := context.Background()

    // Create resource - should succeed even without quota
    resource := &v1alpha1.MyResource{
        ObjectMeta: metav1.ObjectMeta{
            Name:      "test-resource",
            Namespace: "test-ns",
        },
        Spec: v1alpha1.MyResourceSpec{
            Organization: "test-org",
        },
    }
    _, err := client.Create(ctx, resource)
    require.NoError(t, err)

    // Resource should be in PendingQuota state
    require.Eventually(t, func() bool {
        r := &v1alpha1.MyResource{}
        client.Get(ctx, types.NamespacedName{Name: "test-resource", Namespace: "test-ns"}, r)
        return r.Status.Phase == "PendingQuota"
    }, 10*time.Second, 100*time.Millisecond)

    // Claim should exist
    claim := &quotav1alpha1.ResourceClaim{}
    err = quotaClient.Get(ctx, types.NamespacedName{
        Name:      "test-resource-quota",
        Namespace: "quota-system",
    }, claim)
    require.NoError(t, err)

    // Create a grant to provide quota
    grant := &quotav1alpha1.ResourceGrant{
        // ... grant spec
    }
    quotaClient.Create(ctx, grant)

    // Resource should transition to Provisioning
    require.Eventually(t, func() bool {
        r := &v1alpha1.MyResource{}
        client.Get(ctx, types.NamespacedName{Name: "test-resource", Namespace: "test-ns"}, r)
        return r.Status.Phase == "Provisioning"
    }, 30*time.Second, 100*time.Millisecond)
}

func TestQuotaExceededDeferred(t *testing.T) {
    ctx := context.Background()

    // Set up org with zero quota
    // ... create grant with amount: 0

    // Create resource
    resource := &v1alpha1.MyResource{...}
    _, err := client.Create(ctx, resource)
    require.NoError(t, err)  // Creation succeeds

    // Resource should eventually show QuotaExceeded
    require.Eventually(t, func() bool {
        r := &v1alpha1.MyResource{}
        client.Get(ctx, types.NamespacedName{Name: "test-resource", Namespace: "test-ns"}, r)
        return r.Status.Phase == "QuotaExceeded"
    }, 30*time.Second, 100*time.Millisecond)
}
```

## Checklist (Pattern 2: Service-Managed)

Before shipping service-managed quota integration:

- [ ] ResourceRegistration created for each quota dimension
- [ ] GrantCreationPolicy created for each tier
- [ ] Controller creates ResourceClaim with owner reference
- [ ] Controller watches claim status and updates resource phase
- [ ] Resource status exposes quota state to users (PendingQuota, QuotaExceeded)
- [ ] Owner references ensure claims are garbage collected
- [ ] Tier defaults documented and reviewed with commercial team
- [ ] Integration tests cover: claim creation, granted flow, denied flow, cleanup
- [ ] UI shows quota status appropriately
