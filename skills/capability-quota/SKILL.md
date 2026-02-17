---
name: capability-quota
description: Covers resource quota integration using the Milo quota system. Use when implementing ResourceRegistration, ClaimCreationPolicy, or GrantCreationPolicy resources for quota enforcement and allocation.
---

# Capability: Quota

This skill covers quota integration for Datum Cloud services using the Milo quota system.

## Overview

The Milo quota system is a **declarative, policy-driven, Kubernetes-native** resource quota management system. It provides:

- **Real-time enforcement** via admission webhooks during resource creation
- **Automated quota provisioning** via policies that react to resource lifecycle events
- **Multi-tenant tracking** across organization and project hierarchies
- **Complete visibility** via AllowanceBucket status and metrics

## API Group

All quota resources use the `quota.miloapis.com` API group with version `v1alpha1`.

## Core Resource Types

The quota system has **six resource types** that work together:

| Resource | Scope | Purpose |
|----------|-------|---------|
| **ResourceRegistration** | Cluster | Defines what resource types can be quota'd |
| **ResourceGrant** | Namespaced | Allocates quota capacity to a consumer |
| **AllowanceBucket** | Namespaced | Aggregates grants and tracks consumption (auto-created) |
| **ResourceClaim** | Namespaced | Requests quota during resource creation |
| **GrantCreationPolicy** | Cluster | Automates grant creation on resource lifecycle events |
| **ClaimCreationPolicy** | Cluster | Automates claim creation during admission (enforcement) |

Read `concepts.md` for detailed explanations of each resource type and their relationships.

## How Services Integrate

Services have **two integration patterns** depending on their needs:

### Pattern 1: Policy-Driven Enforcement (Admission Blocking)

Use this when resources should be **rejected at creation** if quota is exceeded. The admission webhook blocks the API request.

- Best for: Simple resources where creation = consumption
- Behavior: 403 Forbidden if quota exceeded
- Lifecycle: Fully automatic via policies

### Pattern 2: Service-Managed Claims (Deferred Provisioning)

Use this when resources should be **created but not provisioned** until quota is available. The service manages claim lifecycle directly.

- Best for: Auto-scaling, async provisioning, resources with startup delay
- Behavior: Resource created in "pending quota" state, provisioned when claim is granted
- Lifecycle: Service creates/manages ResourceClaims directly

Example use case: Compute instances where auto-scaling creates the instance object, but the system waits for the quota claim to be granted before actually provisioning the VM.

---

## Pattern 1: Policy-Driven Integration

### 1. Register Your Resource Type

Create a `ResourceRegistration` to define what resource type can be quota'd:

```yaml
apiVersion: quota.miloapis.com/v1alpha1
kind: ResourceRegistration
metadata:
  name: myservice-resources
spec:
  resourceType: "myservice.miloapis.com/resources"
  consumerType:
    apiGroup: resourcemanager.miloapis.com
    kind: Organization
  type: Entity  # or Allocation for capacity-based
  baseUnit: "count"
  displayUnit: "resources"
```

### 2. Create a ClaimCreationPolicy for Enforcement

Create a `ClaimCreationPolicy` that automatically enforces quota when your resources are created:

```yaml
apiVersion: quota.miloapis.com/v1alpha1
kind: ClaimCreationPolicy
metadata:
  name: myservice-resource-quota
spec:
  trigger:
    resource:
      apiVersion: myservice.miloapis.com/v1alpha1
      kind: MyResource
  target:
    resourceClaimTemplate:
      metadata:
        generateName: "myresource-claim-"
        namespace: "{{trigger.metadata.namespace}}"
      spec:
        requests:
          - resourceType: "myservice.miloapis.com/resources"
            amount: 1
```

### 3. Create a GrantCreationPolicy for Allocation

Create a `GrantCreationPolicy` that automatically allocates quota when organizations are created:

```yaml
apiVersion: quota.miloapis.com/v1alpha1
kind: GrantCreationPolicy
metadata:
  name: myservice-default-grant
spec:
  trigger:
    resource:
      apiVersion: resourcemanager.miloapis.com/v1alpha1
      kind: Organization
  target:
    resourceGrantTemplate:
      metadata:
        name: "{{trigger.metadata.name}}-myservice-quota"
        namespace: "{{trigger.metadata.namespace}}"
      spec:
        consumerRef:
          apiGroup: resourcemanager.miloapis.com
          kind: Organization
          name: "{{trigger.metadata.name}}"
        allowances:
          - resourceType: "myservice.miloapis.com/resources"
            buckets:
              - amount: 100  # Default quota
```

---

## Pattern 2: Service-Managed Claims

For resources that need deferred provisioning, the service manages ResourceClaim lifecycle directly instead of using ClaimCreationPolicy.

### When to Use This Pattern

- **Auto-scaling**: Instances created ahead of demand, provisioned when quota available
- **Async provisioning**: Resources that take time to provision anyway
- **Optimistic creation**: Allow resource to exist for visibility while waiting for quota
- **Graceful degradation**: Service can decide how to handle quota pending state

### Integration Approach

1. **Register your resource type** (same as Pattern 1)
2. **Create GrantCreationPolicies** (same as Pattern 1)
3. **Skip ClaimCreationPolicy** — your service manages claims directly
4. **In your controller/storage**:
   - Create ResourceClaim when resource is created
   - Watch claim status for `Granted` condition
   - Only provision the resource when claim is granted
   - Set resource status to indicate "pending quota" while waiting

### Example: Compute Instance Controller

```go
func (r *InstanceReconciler) Reconcile(ctx context.Context, req ctrl.Request) (ctrl.Result, error) {
    instance := &computev1alpha1.Instance{}
    if err := r.Get(ctx, req.NamespacedName, instance); err != nil {
        return ctrl.Result{}, client.IgnoreNotFound(err)
    }

    // Check if claim exists
    claim := &quotav1alpha1.ResourceClaim{}
    claimName := fmt.Sprintf("%s-quota", instance.Name)
    err := r.Get(ctx, types.NamespacedName{
        Name:      claimName,
        Namespace: "quota-system",
    }, claim)

    if apierrors.IsNotFound(err) {
        // Create the claim
        claim = &quotav1alpha1.ResourceClaim{
            ObjectMeta: metav1.ObjectMeta{
                Name:      claimName,
                Namespace: "quota-system",
                OwnerReferences: []metav1.OwnerReference{
                    *metav1.NewControllerRef(instance, computev1alpha1.SchemeGroupVersion.WithKind("Instance")),
                },
            },
            Spec: quotav1alpha1.ResourceClaimSpec{
                ConsumerRef: quotav1alpha1.ConsumerRef{
                    APIGroup: "resourcemanager.miloapis.com",
                    Kind:     "Organization",
                    Name:     instance.Spec.Organization,
                },
                Requests: []quotav1alpha1.ResourceRequest{
                    {ResourceType: "myservice.miloapis.com/instances", Amount: 1},
                    {ResourceType: "myservice.miloapis.com/vcpus", Amount: int64(instance.Spec.VCPUs)},
                },
                ResourceRef: &quotav1alpha1.UnversionedObjectReference{
                    APIGroup:  "myservice.miloapis.com",
                    Kind:      "Instance",
                    Name:      instance.Name,
                    Namespace: instance.Namespace,
                },
            },
        }
        if err := r.Create(ctx, claim); err != nil {
            return ctrl.Result{}, err
        }
        // Update instance status
        instance.Status.Phase = "PendingQuota"
        return ctrl.Result{RequeueAfter: 5 * time.Second}, r.Status().Update(ctx, instance)
    }

    // Check claim status
    if !isClaimGranted(claim) {
        if isClaimDenied(claim) {
            instance.Status.Phase = "QuotaExceeded"
            instance.Status.Message = "Insufficient quota available"
            return ctrl.Result{}, r.Status().Update(ctx, instance)
        }
        // Still pending, requeue
        return ctrl.Result{RequeueAfter: 5 * time.Second}, nil
    }

    // Claim granted - proceed with provisioning
    instance.Status.Phase = "Provisioning"
    // ... actual provisioning logic ...
}
```

### Status Visibility

With service-managed claims, expose quota status to users:

```yaml
status:
  phase: PendingQuota  # or Provisioning, Running, QuotaExceeded
  conditions:
    - type: QuotaGranted
      status: "False"
      reason: PendingEvaluation
      message: "Waiting for quota claim to be granted"
```

## Implementation

Read `implementation.md` for:
- Detailed step-by-step integration guide for both patterns
- CEL expression patterns for policies
- Tier-specific quota defaults
- Testing quota enforcement
- Handling quota exceeded responses

## Validation

Run `scripts/validate-quota.sh` to verify:
- ResourceRegistration exists for your resource types
- ClaimCreationPolicy configured for enforcement
- GrantCreationPolicy configured for allocation
- Tier defaults configured appropriately

## Related Files

- `concepts.md` — Quota domain model and resource type details
- `implementation.md` — Integration guide with examples
- `scripts/validate-quota.sh` — Validation script
- `scripts/scaffold-quota.sh` — Scaffolding script
