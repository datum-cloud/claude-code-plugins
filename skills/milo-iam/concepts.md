# IAM Concepts

Deep dive into the Identity and Access Management concepts in Milo.

## Identity Model

### Users

Users represent human identities in the platform. They are cluster-scoped resources.

```yaml
apiVersion: iam.miloapis.com/v1alpha1
kind: User
metadata:
  name: alice-uuid
spec:
  email: alice@example.com
  displayName: Alice Smith
status:
  # User state management
  state: Active  # Active, Suspended, Deactivated
```

Users are typically created through identity provider integration (SSO) rather than directly.

### Groups

Groups are collections of users within an organization. They are namespaced (namespace = organization).

```yaml
apiVersion: iam.miloapis.com/v1alpha1
kind: Group
metadata:
  name: platform-engineers
  namespace: acme-org
spec:
  displayName: Platform Engineers
```

### GroupMembership

Links users to groups:

```yaml
apiVersion: iam.miloapis.com/v1alpha1
kind: GroupMembership
metadata:
  name: alice-in-engineers
  namespace: acme-org
spec:
  userRef:
    name: alice-uuid
  groupRef:
    name: platform-engineers
```

### Machine Accounts

> **Status**: Available for service-to-service authentication scenarios.

For service-to-service authentication:

```yaml
apiVersion: iam.miloapis.com/v1alpha1
kind: MachineAccount
metadata:
  name: ci-pipeline
  namespace: my-project
spec:
  displayName: CI Pipeline Service Account
```

Machine accounts can have keys generated for authentication:

```yaml
apiVersion: iam.miloapis.com/v1alpha1
kind: MachineAccountKey
metadata:
  name: ci-pipeline-key-1
  namespace: my-project
spec:
  machineAccountRef:
    name: ci-pipeline
```

## Permission Model

### Permission Structure

Permissions identify specific actions on resource types:

```
{service}/{resource}.{action}
```

Components:
- **service**: The API group (e.g., `myservice.miloapis.com`)
- **resource**: The resource type in plural form (e.g., `workloads`)
- **action**: The operation (e.g., `create`, `get`, `delete`)

### Standard Actions

| Action | HTTP Verb | Description |
|--------|-----------|-------------|
| `get` | GET | Read a single resource |
| `list` | GET (collection) | List resources |
| `watch` | GET (streaming) | Watch for changes |
| `create` | POST | Create new resource |
| `update` | PUT | Replace entire resource |
| `patch` | PATCH | Partial update |
| `delete` | DELETE | Remove resource |
| `use` | N/A | Special permission for cross-resource references |

### The `use` Permission

The `use` permission allows referencing a resource from another resource, without granting read/write access:

```yaml
# User can reference this network in their workloads
# but cannot read or modify the network itself
permissions:
  - otherservice.miloapis.com/networks.use
```

## Resource Hierarchy

### Hierarchical Authorization

The platform uses hierarchical resource organization:

```
Organization
  └── Project
       ├── Workload
       ├── Network
       └── Storage
```

Permissions granted at a parent level inherit down:

| Grant Location | Effective Permissions |
|----------------|----------------------|
| Organization | All Projects + all their resources |
| Project | That Project + its resources |
| Resource | That specific resource only |

### Parent Resource Declaration

When defining a ProtectedResource, specify its parent:

```yaml
spec:
  parentResources:
    - apiGroup: resourcemanager.miloapis.com
      kind: Project
```

Multiple parents are supported for resources that can exist in different contexts:

```yaml
spec:
  parentResources:
    - apiGroup: resourcemanager.miloapis.com
      kind: Project
    - apiGroup: resourcemanager.miloapis.com
      kind: Organization
```

## Role Composition

### Role Inheritance

Roles can inherit permissions from other roles:

```yaml
spec:
  inheritedRoles:
    - name: base-role
      namespace: datum-system
```

The system computes `effectivePermissions` by flattening the inheritance tree.

### Inheritance Rules

1. **No cycles**: Role A cannot inherit from Role B if B inherits from A
2. **Cross-namespace**: Roles can inherit from roles in other namespaces
3. **Computed status**: `status.effectivePermissions` shows the flattened result
4. **Transitive**: If A inherits B and B inherits C, A gets C's permissions

### Best Practices

Build role hierarchies following the least-privilege principle:

```
viewer (get, list, watch)
  └── editor (+ create, update, patch)
       └── admin (+ delete, manage)
```

## PolicyBinding Details

### Subject Types

PolicyBindings support two subject types:

**User subjects** require a UID:
```yaml
subjects:
  - kind: User
    name: alice@example.com
    uid: "user-uuid-here"  # Required
```

**Group subjects** require namespace:
```yaml
subjects:
  - kind: Group
    name: developers
    namespace: acme-org
```

### Resource Selectors

Two selection modes:

**Specific resource** (most common):
```yaml
resourceSelector:
  resourceRef:
    apiGroup: myservice.miloapis.com
    kind: Workload
    name: my-workload
    uid: "workload-uuid"
```

**All resources of a kind** (use carefully):
```yaml
resourceSelector:
  resourceKind:
    apiGroup: myservice.miloapis.com
    kind: Workload
```

### Namespace Semantics

The PolicyBinding namespace has meaning:

- For **project-scoped resources**: The namespace is the project
- For **organization-scoped resources**: The namespace is the organization
- For **cluster-scoped resources**: The namespace is typically `datum-system`

## Launch Stages

Roles have launch stages indicating maturity:

| Stage | Description |
|-------|-------------|
| `EarlyAccess` | Preview, may change significantly |
| `Alpha` | Feature complete but not stable |
| `Beta` | Stable API, may have bugs |
| `Stable` | Production ready |
| `Deprecated` | Being phased out |

```yaml
spec:
  launchStage: Stable
```

## Condition-Based Access

Roles can include conditions (when supported):

```yaml
spec:
  includedPermissions:
    - myservice.miloapis.com/workloads.get
  # Future: conditions for time-based, IP-based, etc.
```

## Audit and Compliance

### User Invitation Flow

> **Status**: Available for inviting new users to organizations.

New users are invited via UserInvitation:

```yaml
apiVersion: iam.miloapis.com/v1alpha1
kind: UserInvitation
metadata:
  name: invite-bob
  namespace: acme-org
spec:
  email: bob@example.com
  roles:
    - name: project-viewer
      namespace: datum-system
```

### Platform Access Approval

> **Status**: Used for controlled platform access workflows.

For controlled platform access:

```yaml
apiVersion: iam.miloapis.com/v1alpha1
kind: PlatformAccessApproval
metadata:
  name: approve-bob
spec:
  userRef:
    name: bob-uuid
  approvedBy: admin@example.com
```

### User Deactivation

> **Status**: Available for user offboarding workflows.

For offboarding:

```yaml
apiVersion: iam.miloapis.com/v1alpha1
kind: UserDeactivation
metadata:
  name: deactivate-alice
spec:
  userRef:
    name: alice-uuid
  reason: "Employee departure"
```

## Cross-Cutting Concerns

### Tenant Isolation

The IAM system enforces tenant isolation:

1. **Namespace boundaries**: Resources in one organization namespace cannot reference resources in another
2. **Permission scoping**: Roles granted in one organization don't apply to another
3. **Group isolation**: Groups exist within organization namespaces

### Service Account Impersonation

> **Note**: This is handled internally by the authentication layer, not exposed as a CRD.

Services may impersonate users for delegation. The service presents a token, and IAM resolves it to the user identity.

### Emergency Access

> **Note**: Reserved for platform operators in break-glass scenarios.

For break-glass scenarios, platform operators can use special system groups that bypass normal authorization checks. These actions are logged and audited.
