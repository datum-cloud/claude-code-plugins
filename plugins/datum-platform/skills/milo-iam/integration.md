# Service Integration with IAM

Guide for integrating services with the Milo IAM system.

## Integration Overview

Services integrate with IAM by:

1. Defining ProtectedResources (declarative YAML)
2. Defining Roles (declarative YAML)
3. Deploying the resources to the cluster
4. The IAM system handles authorization enforcement automatically

**You do NOT need to write authorization code.** The platform handles permission checks at the API gateway layer.

## Step-by-Step Integration

### Step 1: Identify Protected Resources

List all resource types your service manages:

| Resource | Scope | Parent |
|----------|-------|--------|
| `Workload` | Project | Project |
| `WorkloadDeployment` | Project | Workload |
| `GatewayPolicy` | Project | Project |

### Step 2: Define Permissions

For each resource, identify required permissions:

```yaml
# Standard CRUD permissions
permissions:
  - list
  - get
  - create
  - update
  - delete
  - patch
  - watch

# Optional: cross-reference permission
  - use
```

### Step 3: Create ProtectedResource Files

Create one file per resource in `config/protected-resources/{service}/`:

```yaml
# config/protected-resources/compute/workload.yaml
apiVersion: iam.miloapis.com/v1alpha1
kind: ProtectedResource
metadata:
  name: workloads.myservice.miloapis.com
spec:
  serviceRef:
    name: myservice.miloapis.com
  kind: Workload
  singular: workload
  plural: workloads
  permissions:
    - list
    - get
    - create
    - update
    - delete
    - patch
    - watch
  parentResources:
    - apiGroup: resourcemanager.miloapis.com
      kind: Project
```

### Step 4: Define Service Roles

Create role hierarchy in `config/roles/`:

```yaml
# config/roles/compute-workload-viewer.yaml
apiVersion: iam.miloapis.com/v1alpha1
kind: Role
metadata:
  name: myservice.miloapis.com-workload-viewer
  namespace: datum-system
spec:
  launchStage: Stable
  includedPermissions:
    - myservice.miloapis.com/workloads.get
    - myservice.miloapis.com/workloads.list
    - myservice.miloapis.com/workloads.watch

---
# config/roles/compute-workload-editor.yaml
apiVersion: iam.miloapis.com/v1alpha1
kind: Role
metadata:
  name: myservice.miloapis.com-workload-editor
  namespace: datum-system
spec:
  launchStage: Stable
  inheritedRoles:
    - name: myservice.miloapis.com-workload-viewer
      namespace: datum-system
  includedPermissions:
    - myservice.miloapis.com/workloads.create
    - myservice.miloapis.com/workloads.update
    - myservice.miloapis.com/workloads.patch

---
# config/roles/compute-workload-admin.yaml
apiVersion: iam.miloapis.com/v1alpha1
kind: Role
metadata:
  name: myservice.miloapis.com-workload-admin
  namespace: datum-system
spec:
  launchStage: Stable
  inheritedRoles:
    - name: myservice.miloapis.com-workload-editor
      namespace: datum-system
  includedPermissions:
    - myservice.miloapis.com/workloads.delete
```

### Step 5: Create Aggregate Roles

For convenience, create service-wide aggregate roles:

```yaml
# config/roles/compute-admin.yaml
apiVersion: iam.miloapis.com/v1alpha1
kind: Role
metadata:
  name: myservice.miloapis.com-admin
  namespace: datum-system
spec:
  launchStage: Stable
  inheritedRoles:
    - name: myservice.miloapis.com-workload-admin
      namespace: datum-system
    - name: myservice.miloapis.com-network-admin
      namespace: datum-system
    - name: myservice.miloapis.com-storage-admin
      namespace: datum-system
```

### Step 6: Wire Up Kustomization

```yaml
# config/protected-resources/kustomization.yaml
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization
resources:
  - compute/workload.yaml
  - compute/network.yaml
  - compute/storage.yaml

---
# config/roles/kustomization.yaml
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization
resources:
  - compute-workload-viewer.yaml
  - compute-workload-editor.yaml
  - compute-workload-admin.yaml
  - compute-network-viewer.yaml
  - compute-network-editor.yaml
  - compute-network-admin.yaml
  - compute-admin.yaml
```

### Step 7: Include in Base Kustomization

```yaml
# config/base/kustomization.yaml
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization
resources:
  - deployment.yaml
  - service.yaml
  - ../protected-resources
  - ../roles
```

## Naming Conventions

### ProtectedResource Names

Format: `{plural}.{apiGroup}`

Examples:
- `workloads.myservice.miloapis.com`
- `projects.resourcemanager.miloapis.com`
- `users.iam.miloapis.com`

### Role Names

Format: `{apiGroup}-{resource}-{level}`

Examples:
- `myservice.miloapis.com-workload-viewer`
- `myservice.miloapis.com-workload-editor`
- `myservice.miloapis.com-workload-admin`

Aggregate roles:
- `myservice.miloapis.com-admin` (all compute resources)
- `myservice.miloapis.com-viewer` (read-only all compute)

## Common Patterns

### Cross-Resource References

When one resource references another (e.g., Workload references Network):

```yaml
# Define 'use' permission on the referenced resource
# config/protected-resources/networking/network.yaml
spec:
  permissions:
    - list
    - get
    - create
    - update
    - delete
    - use  # Allows Workloads to reference Networks
```

Then in your workload editor role:

```yaml
# config/roles/compute-workload-editor.yaml
spec:
  includedPermissions:
    - myservice.miloapis.com/workloads.create
    - otherservice.miloapis.com/networks.use  # Can reference networks
```

### Sub-Resources

For resources that are children of other resources:

```yaml
# WorkloadDeployment is child of Workload
apiVersion: iam.miloapis.com/v1alpha1
kind: ProtectedResource
metadata:
  name: workloaddeployments.myservice.miloapis.com
spec:
  serviceRef:
    name: myservice.miloapis.com
  kind: WorkloadDeployment
  singular: workloaddeployment
  plural: workloaddeployments
  permissions:
    - list
    - get
    - watch
    # No create/delete - managed by parent Workload
  parentResources:
    - apiGroup: myservice.miloapis.com
      kind: Workload
```

### Read-Only Resources

For resources that are system-managed and users can only view:

```yaml
spec:
  permissions:
    - list
    - get
    - watch
    # No create, update, delete
```

### Admin-Only Resources

For sensitive resources only admins should access:

```yaml
# Only create admin role, no viewer/editor
apiVersion: iam.miloapis.com/v1alpha1
kind: Role
metadata:
  name: audit.miloapis.com-auditlog-admin
  namespace: datum-system
spec:
  launchStage: Stable
  includedPermissions:
    - audit.miloapis.com/auditlogs.get
    - audit.miloapis.com/auditlogs.list
    - audit.miloapis.com/auditlogs.watch
```

## Testing Your Integration

### Verify ProtectedResources

```bash
# Build and check for errors
kubectl kustomize config/protected-resources/

# Apply to test cluster
kubectl apply -k config/protected-resources/

# Verify creation
kubectl get protectedresources
```

### Verify Roles

```bash
# Build and check for errors
kubectl kustomize config/roles/

# Apply to test cluster
kubectl apply -k config/roles/

# Verify effective permissions are computed
kubectl get role -n datum-system myservice.miloapis.com-workload-admin -o yaml
```

### Test PolicyBinding

```yaml
# test/iam/test-binding.yaml
apiVersion: iam.miloapis.com/v1alpha1
kind: PolicyBinding
metadata:
  name: test-binding
  namespace: test-project
spec:
  roleRef:
    name: myservice.miloapis.com-workload-editor
    namespace: datum-system
  subjects:
    - kind: User
      name: test-user@example.com
      uid: "test-user-uuid"
  resourceSelector:
    resourceRef:
      apiGroup: resourcemanager.miloapis.com
      kind: Project
      name: test-project
      uid: "test-project-uuid"
```

## Troubleshooting

### Role Not Taking Effect

1. Check role exists: `kubectl get role -n datum-system {role-name}`
2. Check effectivePermissions in status
3. Verify PolicyBinding references correct role namespace

### Permission Denied Errors

1. Check PolicyBinding exists in correct namespace
2. Verify subject UID matches user's UID
3. Check resource selector matches the resource being accessed
4. Verify parent resource chain is properly configured

### Role Inheritance Not Working

1. Check referenced role exists
2. Verify namespace reference is correct
3. Check for circular dependencies (will fail validation)

## Checklist

Before shipping your IAM integration:

- [ ] ProtectedResource defined for each resource type
- [ ] Permissions include standard CRUD operations
- [ ] Parent resources correctly specified
- [ ] Viewer → Editor → Admin role hierarchy created
- [ ] Aggregate service role created (optional)
- [ ] All resources included in kustomization
- [ ] Resources apply without errors
- [ ] Roles show correct effectivePermissions
- [ ] Test PolicyBinding grants expected access
