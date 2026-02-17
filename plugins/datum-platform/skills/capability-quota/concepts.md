# Quota Concepts

This document explains the core domain model of the Milo quota system.

## Resource Type Overview

The quota system consists of six Kubernetes custom resources that work together:

```
ResourceRegistration (defines what to track)
         │
         ▼
GrantCreationPolicy ──► ResourceGrant (allocates capacity)
         │                     │
         │                     ▼
         │              AllowanceBucket (aggregates, tracks availability)
         │                     ▲
         │                     │
ClaimCreationPolicy ──► ResourceClaim (requests quota)
```

## ResourceRegistration

A **cluster-scoped** resource that defines a quota-able resource type. You must create a registration before any grants or claims can reference that resource type.

```yaml
apiVersion: quota.miloapis.com/v1alpha1
kind: ResourceRegistration
metadata:
  name: projects
spec:
  # Unique identifier for this resource type
  resourceType: "resourcemanager.miloapis.com/projects"

  # Which resource type receives grants and creates claims
  consumerType:
    apiGroup: resourcemanager.miloapis.com
    kind: Organization

  # Entity = discrete instances (count), Allocation = capacity amounts
  type: Entity

  # Units for display vs internal tracking
  baseUnit: "count"
  displayUnit: "projects"
  unitConversionFactor: 1  # displayValue = baseValue / factor

  # Optional: which resources can create claims against this type
  claimingResources:
    - apiGroup: resourcemanager.miloapis.com
      kind: Project
```

### Registration Types

| Type | Use Case | Example |
|------|----------|---------|
| `Entity` | Discrete countable instances | Projects, VMs, Users |
| `Allocation` | Capacity amounts | CPU cores, Memory GB, Storage |

### Status Conditions

| Condition | Reason | Meaning |
|-----------|--------|---------|
| `Active=True` | `RegistrationActive` | Validated and operational |
| `Active=False` | `ValidationFailed` | Configuration error |
| `Active=False` | `RegistrationPending` | Being processed |

## ResourceGrant

A **namespaced** resource that allocates quota capacity to a consumer. Multiple grants can contribute to a single consumer's quota.

```yaml
apiVersion: quota.miloapis.com/v1alpha1
kind: ResourceGrant
metadata:
  name: acme-project-quota
  namespace: quota-system
spec:
  # Who receives this quota
  consumerRef:
    apiGroup: resourcemanager.miloapis.com
    kind: Organization
    name: acme-corp
    namespace: org-acme  # Optional for namespaced consumers

  # What quota is allocated
  allowances:
    - resourceType: "resourcemanager.miloapis.com/projects"
      buckets:
        - amount: 100  # In baseUnit
```

### Allocation Model

```
Organization "acme-corp" has 3 ResourceGrants:
├── Grant A: 50 projects (base allocation)
├── Grant B: 25 projects (expansion pack)
└── Grant C: 25 projects (promotional)
                ▼
AllowanceBucket aggregates: limit = 100 projects
```

### Status Conditions

| Condition | Reason | Meaning |
|-----------|--------|---------|
| `Active=True` | `GrantActive` | Validated and contributing to bucket |
| `Active=False` | `ValidationFailed` | Configuration error |
| `Active=False` | `GrantPending` | Being processed |

## AllowanceBucket

A **namespaced** resource that is **automatically created and managed** by the quota system. Do not create these manually. They aggregate all active grants for a consumer+resourceType pair and track consumption.

```yaml
apiVersion: quota.miloapis.com/v1alpha1
kind: AllowanceBucket
metadata:
  name: acme-corp-projects  # Auto-generated
  namespace: quota-system
spec:
  consumerRef:
    apiGroup: resourcemanager.miloapis.com
    kind: Organization
    name: acme-corp
  resourceType: "resourcemanager.miloapis.com/projects"
status:
  limit: 100        # Sum of all active grant amounts
  allocated: 45     # Sum of all granted claim amounts
  available: 55     # limit - allocated (never negative)
  claimCount: 45    # Number of granted claims
  grantCount: 3     # Number of active grants
  contributingGrantRefs:
    - name: grant-a
      amount: 50
    - name: grant-b
      amount: 25
    - name: grant-c
      amount: 25
```

### Key Status Fields

| Field | Description |
|-------|-------------|
| `limit` | Total allocated capacity from all grants |
| `allocated` | Currently consumed by granted claims |
| `available` | Remaining capacity (`limit - allocated`) |
| `claimCount` | Number of active claims |
| `grantCount` | Number of contributing grants |

## ResourceClaim

A **namespaced** resource that requests quota during resource creation. Claims can be created in two ways:

1. **Automatically by ClaimCreationPolicy** — Admission webhook creates claim and blocks resource creation if denied
2. **Directly by services** — Service creates claim and manages deferred provisioning (resource exists but waits for quota)

Use direct creation when you need resources to exist in a "pending quota" state (e.g., auto-scaling scenarios).

```yaml
apiVersion: quota.miloapis.com/v1alpha1
kind: ResourceClaim
metadata:
  name: project-xyz-claim
  namespace: quota-system
spec:
  # Who is consuming the quota
  consumerRef:
    apiGroup: resourcemanager.miloapis.com
    kind: Organization
    name: acme-corp

  # What resource triggered this claim (auto-filled by policy)
  resourceRef:
    apiGroup: resourcemanager.miloapis.com
    kind: Project
    name: xyz
    namespace: org-acme

  # What quota is requested (atomic: all or nothing)
  requests:
    - resourceType: "resourcemanager.miloapis.com/projects"
      amount: 1
status:
  allocations:
    - resourceType: "resourcemanager.miloapis.com/projects"
      status: Granted        # or Denied, Pending
      reason: QuotaAvailable # or QuotaExceeded, ValidationFailed
      allocatedAmount: 1
      allocatingBucket: acme-corp-projects
  conditions:
    - type: Granted
      status: "True"
      reason: QuotaAvailable
```

### Atomic Semantics

A claim with multiple requests is **atomic**: all requests must be satisfiable or the entire claim is denied. This prevents partial allocations.

### Status Conditions

| Condition | Reason | Meaning |
|-----------|--------|---------|
| `Granted=True` | `QuotaAvailable` | All requests granted |
| `Granted=False` | `QuotaExceeded` | Insufficient quota |
| `Granted=False` | `ValidationFailed` | Configuration error |
| `Granted=Unknown` | `PendingEvaluation` | Still being processed |

## GrantCreationPolicy

A **cluster-scoped** resource that automatically creates `ResourceGrant` resources when specified events occur (e.g., when an Organization is created).

```yaml
apiVersion: quota.miloapis.com/v1alpha1
kind: GrantCreationPolicy
metadata:
  name: default-project-quota
spec:
  disabled: false  # Can disable without deleting

  trigger:
    resource:
      apiVersion: resourcemanager.miloapis.com/v1alpha1
      kind: Organization
    # Optional CEL constraints (pure CEL, no delimiters)
    constraints:
      - expression: "trigger.spec.tier == 'enterprise'"
        message: "Only applies to enterprise orgs"

  target:
    # Optional: for cross-cluster quota
    parentContext:
      apiGroup: resourcemanager.miloapis.com
      kind: Organization
      nameExpression: "trigger.spec.parentOrg"

    resourceGrantTemplate:
      metadata:
        # Supports {{ }} CEL expressions
        name: "{{trigger.metadata.name}}-project-quota"
        namespace: "quota-system"
      spec:
        consumerRef:
          apiGroup: resourcemanager.miloapis.com
          kind: Organization
          name: "{{trigger.metadata.name}}"
        allowances:
          - resourceType: "resourcemanager.miloapis.com/projects"
            buckets:
              - amount: 100
```

### CEL Expression Context

Constraint expressions have access to:
- `trigger` — The resource that triggered the policy
- `user` — Authentication info (username, groups, UID)
- `requestInfo` — Request metadata (verb, resource, etc.)

### Status Conditions

| Condition | Reason | Meaning |
|-----------|--------|---------|
| `Ready=True` | `PolicyReady` | Validated and active |
| `Ready=False` | `ValidationFailed` | Configuration error |
| `Ready=False` | `PolicyDisabled` | Explicitly disabled |

## ClaimCreationPolicy

A **cluster-scoped** resource that automatically creates `ResourceClaim` resources during admission webhook processing, enforcing quota before resources are created.

**When to use**: Resources that should be rejected immediately if quota is exceeded.

**When NOT to use**: Resources that should be created but not provisioned until quota is available (use service-managed claims instead). See `implementation.md` for the service-managed pattern.

```yaml
apiVersion: quota.miloapis.com/v1alpha1
kind: ClaimCreationPolicy
metadata:
  name: project-creation-quota
spec:
  disabled: false

  trigger:
    resource:
      apiVersion: resourcemanager.miloapis.com/v1alpha1
      kind: Project
    # Optional CEL constraints
    constraints:
      - expression: "trigger.spec.type == 'production'"
        message: "Only applies to production projects"

  target:
    resourceClaimTemplate:
      metadata:
        # Use generateName for unique claim names
        generateName: "project-claim-"
        namespace: "quota-system"
      spec:
        # consumerRef is auto-resolved if omitted
        requests:
          - resourceType: "resourcemanager.miloapis.com/projects"
            amount: 1
```

### Admission Enforcement Flow

1. User creates a Project
2. Admission webhook intercepts the request
3. ClaimCreationPolicy matches the Project
4. ResourceClaim is created automatically
5. Quota system evaluates claim against AllowanceBucket
6. If granted: Project creation proceeds
7. If denied: 403 Forbidden returned to user

### Status Conditions

| Condition | Reason | Meaning |
|-----------|--------|---------|
| `Ready=True` | `PolicyReady` | Validated and active |
| `Ready=False` | `ValidationFailed` | Configuration error |
| `Ready=False` | `PolicyDisabled` | Explicitly disabled |

## Quota Dimensions

A **dimension** is a single countable aspect of a resource type. Common patterns:

| Pattern | Example | Use Case |
|---------|---------|----------|
| `{service}/count` | `myservice.miloapis.com/instances` | Number of instances |
| `{service}/{attribute}` | `myservice.miloapis.com/vcpus` | Aggregate attribute |
| `{service}/{size}` | `myservice.miloapis.com/bytes` | Total capacity |

## Tier Defaults

Quota allocations typically vary by subscription tier:

| Tier | Philosophy | Example (Projects) |
|------|------------|-------------------|
| Free | Enough for meaningful evaluation | 3 |
| Pro | Enough for typical production | 50 |
| Enterprise | Enough for large scale | 500 |

**Design principle**: Quotas should feel generous. Hitting limits should mean "you're growing" not "we're restricting you."

## Enforcement Response

When quota is exceeded, the API returns a 403 Forbidden:

```json
{
  "kind": "Status",
  "apiVersion": "v1",
  "status": "Failure",
  "message": "Insufficient quota resources available",
  "reason": "Forbidden",
  "details": {
    "kind": "ResourceClaim",
    "causes": [
      {
        "reason": "QuotaExceeded",
        "message": "quota exceeded for resourcemanager.miloapis.com/projects",
        "field": "requests[0]"
      }
    ]
  },
  "code": 403
}
```

## Quota Increase Workflow

1. Consumer requests increase via support or self-service
2. Commercial review (for paid tiers, if needed)
3. New ResourceGrant created (or existing grant updated)
4. AllowanceBucket automatically recalculates limits
5. Consumer can now create more resources

## Automatic Cleanup

ResourceClaims created by policies include owner references to the triggering resource. When the resource is deleted:
1. Kubernetes garbage collection deletes the ResourceClaim
2. AllowanceBucket automatically updates (allocated decreases)
3. Quota is released without any manual intervention
