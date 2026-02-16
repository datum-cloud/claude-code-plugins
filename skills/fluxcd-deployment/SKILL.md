# FluxCD Deployment Patterns

This skill covers how services are deployed to Datum Cloud infrastructure using FluxCD GitOps.

## Overview

Services are deployed via **FluxCD** using **OCIRepository** resources that pull complete Kustomize bundles as OCI artifacts. This is different from image updater patterns—the entire configuration is versioned atomically.

## Key Concepts

| Concept | Description |
|---------|-------------|
| **OCIRepository** | Pulls Kustomize bundles from OCI registry (not container images) |
| **Flux Kustomization** | Applies resources from OCIRepository with patches |
| **Semver filtering** | Controls which versions deploy to each environment |
| **Dependency ordering** | `dependsOn` chains ensure correct initialization order |

## Deployment Flow

```
Service repo CI → Publishes Kustomize bundle as OCI artifact
                        ↓
FluxCD OCIRepository → Polls for new semver versions (every 5m)
                        ↓
Flux Kustomization → Applies resources with inline patches
                        ↓
Kubernetes resources deployed
```

**No Git commits to infra repo** — Deployment happens automatically when new OCI artifacts match the semver filter.

## Key Files

| File | Purpose |
|------|---------|
| `oci-repository.md` | OCIRepository patterns |
| `flux-kustomization.md` | Flux Kustomization patterns |
| `infra-structure.md` | Infra repository structure |

## Infra Repository Structure

Services are deployed from `datum-cloud/infra`:

```
infra/
├── clusters/
│   ├── staging/
│   │   └── apps/           # Kustomization references per service
│   └── production/
│       └── apps/
├── apps/
│   └── {service}/
│       ├── base/           # Flux Kustomizations + OCIRepository
│       ├── overlays/
│       │   ├── staging/
│       │   └── production/
│       └── components/     # Optional features
└── infrastructure/         # Shared platform components
```

## OCIRepository Pattern

Services publish Kustomize bundles to `ghcr.io/datum-cloud/{service}-kustomize`:

```yaml
apiVersion: source.toolkit.fluxcd.io/v1
kind: OCIRepository
metadata:
  name: activity-kustomize
spec:
  interval: 5m
  url: oci://ghcr.io/datum-cloud/activity-kustomize
  ref:
    semver: ">=0.0.0"  # Stable releases only
```

### Environment-Specific Filtering

**Staging** — allows pre-release versions with branch filter:
```yaml
spec:
  ref:
    semver: ">=0.0.0-0"
    semverFilter: '.*-staging-test-deploy-.*'
```

**Production** — stable releases only:
```yaml
spec:
  ref:
    semver: ">=0.0.0"
```

## Flux Kustomization Pattern

Each component is a Flux Kustomization that references the OCIRepository:

```yaml
apiVersion: kustomize.toolkit.fluxcd.io/v1
kind: Kustomization
metadata:
  name: activity-apiserver
spec:
  interval: 1h
  timeout: 1m
  sourceRef:
    kind: OCIRepository
    name: activity-kustomize
  path: "./base"
  targetNamespace: activity-system
  prune: true
  wait: true
  dependsOn:
    - name: clickhouse-migrations
  patches:
    - patch: |
        apiVersion: apps/v1
        kind: Deployment
        metadata:
          name: activity-apiserver
        spec:
          replicas: 3
  healthChecks:
    - apiVersion: apps/v1
      kind: Deployment
      name: activity-apiserver
      namespace: activity-system
```

### Key Fields

| Field | Purpose |
|-------|---------|
| `sourceRef` | References OCIRepository containing Kustomize bundle |
| `path` | Path within the OCI artifact to apply |
| `dependsOn` | Other Kustomizations that must complete first |
| `patches` | Inline patches applied after Kustomize build |
| `healthChecks` | Resources that must be healthy before marking ready |
| `prune` | Remove resources deleted from source |
| `wait` | Wait for resources to be ready |

## Dependency Ordering

Use `dependsOn` for stateful services that need ordered initialization:

```yaml
# Example: Activity service dependency chain
clickhouse-keeper
    ↓
clickhouse-database
    ↓
clickhouse-migrations
    ↓
activity-apiserver
    ↓
activity-processor
    ↓
activity-ui
```

```yaml
# clickhouse-database.yaml
spec:
  dependsOn:
    - name: clickhouse-keeper

# clickhouse-migrations.yaml
spec:
  dependsOn:
    - name: clickhouse-database

# activity-apiserver.yaml
spec:
  dependsOn:
    - name: clickhouse-migrations
```

## Inline Patching

Heavy use of inline patches in Flux Kustomizations rather than overlay files:

```yaml
patches:
  - patch: |
      apiVersion: apps/v1
      kind: Deployment
      metadata:
        name: activity-apiserver
      spec:
        replicas: 3
        template:
          spec:
            topologySpreadConstraints:
              - maxSkew: 1
                topologyKey: topology.kubernetes.io/zone
                whenUnsatisfiable: ScheduleAnyway
            containers:
              - name: apiserver
                env:
                  - name: CLICKHOUSE_HOST
                    value: "clickhouse-activity-clickhouse.activity-system.svc"
```

## Comparison: OCIRepository vs Image Updater

| Aspect | Image Updater | OCIRepository (Activity) |
|--------|--------------|-------------------------|
| **What's versioned** | Individual container images | Entire Kustomize bundle |
| **Git commits** | Automation commits new tags | No Git commits needed |
| **Version source** | Image registry tags | OCI artifact semver |
| **Deployment trigger** | ImagePolicy + ImageUpdateAutomation | OCIRepository polling |
| **Config changes** | Only image tag changes | Full config + image together |

## Publishing Kustomize Bundles

Services publish their `config/` directory as an OCI artifact:

```yaml
# .github/workflows/publish.yaml
- name: Push Kustomize bundle
  run: |
    flux push artifact oci://ghcr.io/datum-cloud/${{ github.event.repository.name }}-kustomize:${{ env.VERSION }} \
      --path=./config \
      --source="${{ github.repositoryUrl }}" \
      --revision="${{ github.sha }}"
```

## Related Skills

- `kustomize-patterns` — Base + components + overlays structure
- `datum-ci` — GitHub Actions workflows for publishing
