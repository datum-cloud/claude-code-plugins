# Infra Repository Structure

## Overview

The `datum-cloud/infra` repository contains all deployment configurations for Datum Cloud services. Services are deployed via FluxCD GitOps reconciliation.

## Repository Layout

```
infra/
├── .github/
│   └── workflows/           # Cluster provisioning, preview environments
├── clusters/
│   ├── staging/
│   │   ├── flux-system/     # FluxCD bootstrap configuration
│   │   ├── infrastructure/  # Platform components for staging
│   │   └── apps/            # Service Kustomization references
│   ├── production/
│   │   ├── flux-system/
│   │   ├── infrastructure/
│   │   └── apps/
│   ├── edge/                # Edge cluster configuration
│   └── preview/             # Ephemeral preview environments
├── apps/
│   └── {service}/           # Per-service deployment configs
│       ├── base/
│       ├── overlays/
│       └── components/
├── infrastructure/          # Shared platform components
│   ├── base/
│   └── overlays/
├── gcp/                     # Pulumi programs for GCP provisioning
└── provisioning/            # Node and cluster setup scripts
```

## Cluster Directory

Each cluster has a dedicated directory that FluxCD watches:

### `clusters/{env}/apps/`

Contains Kustomization references that point to `apps/{service}/overlays/{env}`:

```yaml
# clusters/staging/apps/activity-system.yaml
apiVersion: kustomize.toolkit.fluxcd.io/v1
kind: Kustomization
metadata:
  name: activity-system
  namespace: flux-system
spec:
  interval: 1h
  retryInterval: 1m
  timeout: 5m
  prune: true
  wait: true
  sourceRef:
    kind: GitRepository
    name: flux-system
  path: "./apps/activity-system/overlays/staging"
  dependsOn:
    - name: nats-system
    - name: clickhouse-operator
    - name: victoria-metrics-operator
    - name: cert-manager
    - name: external-secrets
```

### `clusters/{env}/infrastructure/`

Platform components required before services:

```yaml
# clusters/staging/infrastructure/cert-manager.yaml
apiVersion: kustomize.toolkit.fluxcd.io/v1
kind: Kustomization
metadata:
  name: cert-manager
  namespace: flux-system
spec:
  sourceRef:
    kind: GitRepository
    name: flux-system
  path: "./infrastructure/cert-manager/overlays/staging"
```

## Apps Directory

### Standard Service Structure

```
apps/{service}/
├── base/
│   ├── kustomization.yaml      # References all base resources
│   ├── namespace.yaml          # Service namespace
│   ├── oci-repository.yaml     # OCIRepository for Kustomize bundle
│   ├── apiserver.yaml          # Main Flux Kustomization
│   └── {component}.yaml        # Additional Flux Kustomizations
├── overlays/
│   ├── staging/
│   │   ├── kustomization.yaml  # Includes base + staging patches
│   │   ├── patches/            # Environment-specific patches
│   │   └── *.yaml              # Staging-only resources
│   └── production/
│       ├── kustomization.yaml
│       └── patches/
└── components/
    ├── observability/          # Optional monitoring
    └── performance-testing/    # Optional load testing
```

### Base Kustomization

```yaml
# apps/activity-system/base/kustomization.yaml
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization

namespace: activity-system

resources:
  - namespace.yaml
  - oci-repository.yaml
  - apiserver.yaml
  - clickhouse-keeper.yaml
  - clickhouse-database.yaml
  - clickhouse-migrations.yaml
  - nats-jetstream.yaml
  - vector-aggregator.yaml
  - vector-sidecar.yaml

commonLabels:
  app.kubernetes.io/instance: activity
  app.kubernetes.io/part-of: activity.miloapis.com
```

### Overlay Kustomization

```yaml
# apps/activity-system/overlays/staging/kustomization.yaml
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization

resources:
  - ../../base
  - etcd.yaml                    # Staging-only resource
  - activity-gateway.yaml
  - ui.yaml

components:
  - ../../components/observability
  - ../../components/performance-testing

patches:
  - path: patches/oci-repository-patch.yaml
  - path: patches/vector-sidecar-deployment-patch.yaml
  - path: patches/apiserver-nats-tls-patch.yaml
```

## Activity System Example

### Complete Structure

```
apps/activity-system/
├── base/
│   ├── kustomization.yaml
│   ├── namespace.yaml
│   ├── oci-repository.yaml         # → ghcr.io/datum-cloud/activity-kustomize
│   ├── apiserver.yaml              # Flux Kustomization for API server
│   ├── clickhouse-keeper.yaml      # ClickHouse coordination
│   ├── clickhouse-database.yaml    # ClickHouse storage
│   ├── clickhouse-migrations.yaml  # Schema migrations
│   ├── clickhouse-ca.yaml          # Certificate authority
│   ├── clickhouse-cold-storage.yaml
│   ├── clickhouse-config.yaml
│   ├── clickhouse-datasource.yaml
│   ├── nats-jetstream.yaml         # Event streaming
│   ├── vector-aggregator.yaml      # Log aggregation
│   ├── vector-sidecar.yaml         # Log collection
│   ├── authorization-webhook.yaml
│   └── milo-*.yaml                 # Milo integration
├── overlays/
│   ├── staging/
│   │   ├── kustomization.yaml
│   │   ├── etcd.yaml               # ActivityPolicy storage
│   │   ├── activity-gateway.yaml   # TLS gateway
│   │   ├── activity-ui-oci-repository.yaml
│   │   ├── ui.yaml
│   │   ├── activity-examples.yaml
│   │   ├── activity-staging-rbac.yaml
│   │   └── patches/
│   │       ├── oci-repository-patch.yaml
│   │       ├── vector-sidecar-deployment-patch.yaml
│   │       ├── vector-aggregator-patch.yaml
│   │       ├── apiserver-nats-tls-patch.yaml
│   │       ├── apiserver-new-components-patch.yaml
│   │       └── nats-jetstream-namespace-patch.yaml
│   └── production/
│       ├── kustomization.yaml
│       └── patches/
│           ├── oci-repository-patch.yaml
│           ├── vector-sidecar-daemonset-patch.yaml
│           ├── clickhouse-database-patch.yaml
│           └── clickhouse-cold-storage-bucket-patch.yaml
└── components/
    ├── observability/
    │   └── kustomization.yaml
    └── performance-testing/
        └── kustomization.yaml
```

### Key Differences: Staging vs Production

| Aspect | Staging | Production |
|--------|---------|------------|
| **OCI semver** | `>=0.0.0-0` with filter | `>=0.0.0` stable only |
| **etcd** | Deployed for ActivityPolicy | Not deployed |
| **UI** | Deployed | Not deployed |
| **Gateway** | activity.staging.env.datum.net | Not deployed |
| **Vector sidecar** | Deployment (2-5 replicas) | DaemonSet |
| **Performance tests** | Enabled | Disabled |
| **Examples** | Installed to Milo | Not installed |

## Adding a New Service

1. Create directory structure:
   ```bash
   mkdir -p apps/{service}/base
   mkdir -p apps/{service}/overlays/{staging,production}
   mkdir -p apps/{service}/components
   ```

2. Create base resources:
   - `namespace.yaml`
   - `oci-repository.yaml` (pointing to service's Kustomize bundle)
   - Flux Kustomization(s) for each component

3. Create overlay kustomizations:
   - Reference base
   - Add environment-specific patches
   - Include appropriate components

4. Add cluster reference:
   ```yaml
   # clusters/staging/apps/{service}.yaml
   apiVersion: kustomize.toolkit.fluxcd.io/v1
   kind: Kustomization
   metadata:
     name: {service}
     namespace: flux-system
   spec:
     sourceRef:
       kind: GitRepository
       name: flux-system
     path: "./apps/{service}/overlays/staging"
     dependsOn:
       - name: cert-manager
       - name: external-secrets
       # ... other dependencies
   ```

5. Commit and push — FluxCD will reconcile automatically.

## Dependency Management

### Service Dependencies

Services declare dependencies on platform components:

```yaml
# clusters/staging/apps/activity-system.yaml
spec:
  dependsOn:
    - name: nats-system          # Messaging
    - name: clickhouse-operator  # Database operator
    - name: victoria-metrics-operator  # Metrics
    - name: cert-manager         # TLS certificates
    - name: external-secrets     # Secret management
```

### Infrastructure Dependencies

Platform components have their own dependency chains:

```yaml
# cert-manager must exist before any service needing TLS
# external-secrets must exist before any service using GCP secrets
# clickhouse-operator must exist before any ClickHouse databases
```

## Validation

Before committing changes:

```bash
# Validate all Kustomize builds
for overlay in staging production; do
  kubectl kustomize apps/activity-system/overlays/$overlay
done

# Dry-run against cluster
flux diff kustomization activity-system -n flux-system
```
