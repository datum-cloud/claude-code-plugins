---
name: milo-iam
description: Covers the Identity and Access Management system including ProtectedResource, Role, and PolicyBinding definitions. Use when implementing authorization for new resource types or defining service roles.
---

# Milo IAM

This skill covers the Identity and Access Management (IAM) system in Milo, the Datum Cloud control plane.

## Overview

Milo uses a Kubernetes-native IAM system built on Custom Resource Definitions (CRDs). Services integrate declaratively by:

1. **Defining ProtectedResources** — YAML files declaring which resources require authorization and their permissions
2. **Creating Roles** — Collections of permissions that can be assigned to users/groups
3. **Binding Roles via PolicyBinding** — Connecting roles to subjects (users/groups) for specific resources

The IAM system handles authorization enforcement. Services don't need to understand the internal authorization backend — they only need to define protected resources and roles.

## Core Concepts

### API Group

All IAM resources are in the `iam.miloapis.com/v1alpha1` API group.

### Resource Types

| Resource | Scope | Purpose |
|----------|-------|---------|
| `ProtectedResource` | Cluster | Declares a resource type and its permissions |
| `Role` | Namespaced | Defines a collection of permissions |
| `PolicyBinding` | Namespaced | Binds a role to subjects on a resource |
| `User` | Cluster | Represents a platform user |
| `Group` | Namespaced | A collection of users |
| `GroupMembership` | Namespaced | Links users to groups |

## ProtectedResource

Declares which resources require authorization and what permissions apply.

### Structure

```yaml
apiVersion: iam.miloapis.com/v1alpha1
kind: ProtectedResource
metadata:
  name: workloads.myservice.miloapis.com
spec:
  # Which service owns this resource
  serviceRef:
    name: myservice.miloapis.com

  # Resource kind (matches Kubernetes Kind)
  kind: Workload
  singular: workload
  plural: workloads

  # Available permissions for this resource
  permissions:
    - list
    - get
    - create
    - update
    - delete
    - patch
    - watch
    - use

  # Parent resources for permission inheritance
  parentResources:
    - apiGroup: resourcemanager.miloapis.com
      kind: Project
```

### Permission Inheritance

Permissions flow down the resource hierarchy:

```
Organization (admin)
  └─→ Project (admin, inherited)
       └─→ Workload (admin, inherited)
```

A user with `admin` on an Organization automatically has `admin` on all Projects and Workloads within that Organization.

### Permission Naming Convention

Permissions follow the format: `{service}/{resource}.{action}`

Examples:
- `iam.miloapis.com/users.create`
- `myservice.miloapis.com/workloads.get`
- `resourcemanager.miloapis.com/projects.delete`

## Role

Defines a collection of permissions that can be granted to users.

### Structure

```yaml
apiVersion: iam.miloapis.com/v1alpha1
kind: Role
metadata:
  name: workload-editor
  namespace: datum-system
spec:
  # Launch stage for the role
  launchStage: Stable

  # Direct permissions
  includedPermissions:
    - myservice.miloapis.com/workloads.get
    - myservice.miloapis.com/workloads.list
    - myservice.miloapis.com/workloads.create
    - myservice.miloapis.com/workloads.update

  # Inherit permissions from other roles
  inheritedRoles:
    - name: workload-viewer
      namespace: datum-system
```

### Role Inheritance

Roles support composition through `inheritedRoles`. The system computes effective permissions by flattening the inheritance tree:

```yaml
# workload-admin inherits workload-editor
# workload-editor inherits workload-viewer
# Result: workload-admin has all permissions from all three roles
status:
  effectivePermissions:
    - myservice.miloapis.com/workloads.get
    - myservice.miloapis.com/workloads.list
    - myservice.miloapis.com/workloads.create
    - myservice.miloapis.com/workloads.update
    - myservice.miloapis.com/workloads.delete
```

### Standard Role Pattern

Follow the viewer → editor → admin hierarchy:

| Role | Permissions |
|------|-------------|
| `viewer` | get, list, watch |
| `editor` | viewer + create, update, patch |
| `admin` | editor + delete, manage roles |

## PolicyBinding

Connects roles to subjects (users or groups) for specific resources.

### Structure

```yaml
apiVersion: iam.miloapis.com/v1alpha1
kind: PolicyBinding
metadata:
  name: alice-workload-editor
  namespace: my-project
spec:
  # Which role to grant
  roleRef:
    name: workload-editor
    namespace: datum-system

  # Who receives the role
  subjects:
    - kind: User
      name: alice@example.com
      uid: "user-uuid-here"

    - kind: Group
      name: developers
      namespace: my-org

  # What resource(s) the role applies to
  resourceSelector:
    # Option 1: Specific resource instance
    resourceRef:
      apiGroup: myservice.miloapis.com
      kind: Workload
      name: my-workload
      uid: "workload-uuid-here"

    # Option 2: All resources of a kind (pick one, not both)
    # resourceKind:
    #   apiGroup: myservice.miloapis.com
    #   kind: Workload
```

### Resource Selector Options

| Selector | Use Case |
|----------|----------|
| `resourceRef` | Grant role on a specific resource instance |
| `resourceKind` | Grant role on all resources of a type (within namespace) |

## Service Integration

Services integrate with IAM declaratively, not programmatically.

### 1. Define ProtectedResources

Create YAML files in `config/protected-resources/{service}/`:

```yaml
# config/protected-resources/myservice/myresource.yaml
apiVersion: iam.miloapis.com/v1alpha1
kind: ProtectedResource
metadata:
  name: myresources.myservice.miloapis.com
spec:
  serviceRef:
    name: myservice.miloapis.com
  kind: MyResource
  singular: myresource
  plural: myresources
  permissions:
    - list
    - get
    - create
    - update
    - delete
    - watch
  parentResources:
    - apiGroup: resourcemanager.miloapis.com
      kind: Project
```

### 2. Define Service Roles

Create role definitions in `config/roles/`:

```yaml
# config/roles/myservice-viewer.yaml
apiVersion: iam.miloapis.com/v1alpha1
kind: Role
metadata:
  name: myservice.miloapis.com-viewer
  namespace: datum-system
spec:
  launchStage: Stable
  includedPermissions:
    - myservice.miloapis.com/myresources.get
    - myservice.miloapis.com/myresources.list
    - myservice.miloapis.com/myresources.watch

---
# config/roles/myservice-editor.yaml
apiVersion: iam.miloapis.com/v1alpha1
kind: Role
metadata:
  name: myservice.miloapis.com-editor
  namespace: datum-system
spec:
  launchStage: Stable
  inheritedRoles:
    - name: myservice.miloapis.com-viewer
      namespace: datum-system
  includedPermissions:
    - myservice.miloapis.com/myresources.create
    - myservice.miloapis.com/myresources.update

---
# config/roles/myservice-admin.yaml
apiVersion: iam.miloapis.com/v1alpha1
kind: Role
metadata:
  name: myservice.miloapis.com-admin
  namespace: datum-system
spec:
  launchStage: Stable
  inheritedRoles:
    - name: myservice.miloapis.com-editor
      namespace: datum-system
  includedPermissions:
    - myservice.miloapis.com/myresources.delete
```

### 3. Include in Kustomization

```yaml
# config/protected-resources/kustomization.yaml
resources:
  - myservice/myresource.yaml

# config/roles/kustomization.yaml
resources:
  - myservice-viewer.yaml
  - myservice-editor.yaml
  - myservice-admin.yaml
```

## Resource Hierarchy

The platform uses a standard resource hierarchy:

```
Organization (tenant root)
  └─→ Project (resource container)
       └─→ Service Resources (workloads, networks, etc.)
```

### Defining Parent Resources

When defining a ProtectedResource, specify parent resources for permission inheritance:

```yaml
spec:
  parentResources:
    # Most service resources are children of Project
    - apiGroup: resourcemanager.miloapis.com
      kind: Project
```

For resources directly under Organization:

```yaml
spec:
  parentResources:
    - apiGroup: resourcemanager.miloapis.com
      kind: Organization
```

## Common Patterns

### Organization-Level Roles

For resources that span the entire organization:

```yaml
apiVersion: iam.miloapis.com/v1alpha1
kind: PolicyBinding
metadata:
  name: org-admin-binding
  namespace: my-org
spec:
  roleRef:
    name: organization-admin
    namespace: datum-system
  subjects:
    - kind: User
      name: admin@company.com
      uid: "user-uuid"
  resourceSelector:
    resourceRef:
      apiGroup: resourcemanager.miloapis.com
      kind: Organization
      name: my-org
      uid: "org-uuid"
```

### Group-Based Access

Grant roles to groups rather than individual users:

```yaml
apiVersion: iam.miloapis.com/v1alpha1
kind: PolicyBinding
metadata:
  name: dev-team-editor
  namespace: my-project
spec:
  roleRef:
    name: workload-editor
    namespace: datum-system
  subjects:
    - kind: Group
      name: developers
      namespace: my-org
  resourceSelector:
    resourceRef:
      apiGroup: resourcemanager.miloapis.com
      kind: Project
      name: my-project
      uid: "project-uuid"
```

### Cross-Namespace Role References

Roles in `datum-system` namespace are available platform-wide. Service-specific roles can reference them:

```yaml
spec:
  roleRef:
    name: resourcemanager.miloapis.com-organizationowner
    namespace: datum-system
```

## Validation

ProtectedResources and Roles are validated by admission webhooks:

| Validation | Description |
|------------|-------------|
| Permission format | Must match `{service}/{resource}.{action}` |
| Role references | Referenced roles must exist |
| Subject UIDs | Required for Users (except system groups) |
| Resource references | Referenced resources must exist |

## Testing IAM Configuration

Apply IAM resources to a test cluster and verify:

```bash
# Apply protected resources
kubectl apply -k config/protected-resources/

# Apply roles
kubectl apply -k config/roles/

# Verify role effective permissions
kubectl get role -n datum-system myservice.miloapis.com-admin -o yaml

# Create test policy binding
kubectl apply -f test-binding.yaml

# Verify access (implementation-specific)
```

## Files in This Skill

- `SKILL.md` — This overview
- `concepts.md` — Deep dive into IAM concepts (Users, Groups, Permissions, Role composition)
- `integration.md` — Step-by-step service integration guide

## Related Skills

- `k8s-apiserver-patterns` — For implementing API types that IAM protects
- `kustomize-patterns` — For organizing IAM resource YAML files
