# Flux Kustomization Patterns

## Overview

Flux Kustomization resources apply Kubernetes manifests from a source (OCIRepository or GitRepository) with optional transformations, patches, and health checks.

## Basic Flux Kustomization

```yaml
apiVersion: kustomize.toolkit.fluxcd.io/v1
kind: Kustomization
metadata:
  name: activity-apiserver
  namespace: activity-system
spec:
  interval: 1h
  retryInterval: 1m
  timeout: 5m
  sourceRef:
    kind: OCIRepository
    name: activity-kustomize
  path: "./base"
  targetNamespace: activity-system
  prune: true
  wait: true
```

## Key Configuration Options

### Source Reference

```yaml
spec:
  sourceRef:
    kind: OCIRepository    # or GitRepository
    name: activity-kustomize
    namespace: activity-system  # optional, defaults to Kustomization namespace
```

### Path Within Source

```yaml
spec:
  path: "./base"                    # Main deployment
  path: "./components/observability" # Specific component
  path: "./examples"                 # Example resources
```

### Pruning and Garbage Collection

```yaml
spec:
  prune: true  # Delete resources removed from source
```

### Wait for Readiness

```yaml
spec:
  wait: true     # Wait for all resources to be ready
  timeout: 5m    # Timeout for readiness
```

## Dependency Management

### dependsOn

Ensures Kustomizations are applied in order:

```yaml
apiVersion: kustomize.toolkit.fluxcd.io/v1
kind: Kustomization
metadata:
  name: activity-apiserver
spec:
  dependsOn:
    - name: clickhouse-migrations
    - name: nats-stream
```

### Common Dependency Chains

```yaml
# Database infrastructure
clickhouse-keeper:
  dependsOn: []

clickhouse-database:
  dependsOn:
    - name: clickhouse-keeper

clickhouse-migrations:
  dependsOn:
    - name: clickhouse-database

# Application layer
activity-apiserver:
  dependsOn:
    - name: clickhouse-migrations

activity-processor:
  dependsOn:
    - name: activity-apiserver

activity-ui:
  dependsOn:
    - name: activity-apiserver
```

## Health Checks

Define resources that must be healthy:

```yaml
spec:
  healthChecks:
    - apiVersion: apps/v1
      kind: Deployment
      name: activity-apiserver
      namespace: activity-system
    - apiVersion: v1
      kind: Service
      name: activity-apiserver
      namespace: activity-system
```

### Health Check Expressions

For custom health conditions:

```yaml
spec:
  healthChecks:
    - apiVersion: clickhouse.altinity.com/v1
      kind: ClickHouseInstallation
      name: activity-clickhouse
      namespace: activity-system
  healthCheckExprs:
    - apiVersion: clickhouse.altinity.com/v1
      kind: ClickHouseInstallation
      expr: "status.status == 'Completed'"
```

## Inline Patches

Apply patches directly in the Kustomization:

### Strategic Merge Patch

```yaml
spec:
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
              containers:
                - name: apiserver
                  env:
                    - name: CLICKHOUSE_HOST
                      value: "clickhouse.activity-system.svc"
```

### JSON Patch

```yaml
spec:
  patches:
    - patch: |
        - op: replace
          path: /spec/replicas
          value: 3
      target:
        kind: Deployment
        name: activity-apiserver
```

### Target Selectors

```yaml
spec:
  patches:
    - patch: |
        apiVersion: apps/v1
        kind: Deployment
        metadata:
          name: placeholder  # Ignored when target is specified
        spec:
          replicas: 3
      target:
        kind: Deployment
        labelSelector: "app.kubernetes.io/component=apiserver"
```

## Complex Patch Examples

### Adding Environment Variables

```yaml
patches:
  - patch: |
      apiVersion: apps/v1
      kind: Deployment
      metadata:
        name: activity-apiserver
      spec:
        template:
          spec:
            containers:
              - name: apiserver
                env:
                  - name: CLICKHOUSE_HOST
                    value: "clickhouse-activity-clickhouse.activity-system.svc.cluster.local"
                  - name: CLICKHOUSE_PORT
                    value: "9440"
                  - name: CLICKHOUSE_TLS_ENABLED
                    value: "true"
```

### Adding Volumes and Mounts

```yaml
patches:
  - patch: |
      apiVersion: apps/v1
      kind: Deployment
      metadata:
        name: activity-apiserver
      spec:
        template:
          spec:
            volumes:
              - name: clickhouse-client-tls
                csi:
                  driver: csi.cert-manager.io
                  readOnly: true
                  volumeAttributes:
                    csi.cert-manager.io/issuer-name: clickhouse-ca
                    csi.cert-manager.io/issuer-kind: Issuer
                    csi.cert-manager.io/common-name: activity-apiserver-clickhouse-client
            containers:
              - name: apiserver
                volumeMounts:
                  - name: clickhouse-client-tls
                    mountPath: /var/run/secrets/clickhouse-client-tls
                    readOnly: true
```

### Topology Spread Constraints

```yaml
patches:
  - patch: |
      apiVersion: apps/v1
      kind: Deployment
      metadata:
        name: activity-apiserver
      spec:
        template:
          spec:
            topologySpreadConstraints:
              - maxSkew: 1
                topologyKey: topology.kubernetes.io/zone
                whenUnsatisfiable: ScheduleAnyway
                labelSelector:
                  matchLabels:
                    app.kubernetes.io/name: activity-apiserver
              - maxSkew: 1
                topologyKey: kubernetes.io/hostname
                whenUnsatisfiable: ScheduleAnyway
                labelSelector:
                  matchLabels:
                    app.kubernetes.io/name: activity-apiserver
```

## Kubeconfig for Remote Clusters

Apply to a different cluster (e.g., for aggregated API servers):

```yaml
spec:
  kubeConfig:
    secretRef:
      name: activity-examples-installer-kubeconfig
  force: true  # Use client-side apply (required for aggregated APIs)
```

## Post-Build Variable Substitution

```yaml
spec:
  postBuild:
    substitute:
      ENVIRONMENT: staging
      DOMAIN: staging.env.datum.net
    substituteFrom:
      - kind: ConfigMap
        name: cluster-vars
      - kind: Secret
        name: cluster-secrets
```

## Suspend Reconciliation

Temporarily stop reconciliation:

```yaml
spec:
  suspend: true
```

Or via CLI:
```bash
flux suspend kustomization activity-apiserver -n activity-system
flux resume kustomization activity-apiserver -n activity-system
```

## Debugging

```bash
# View Kustomization status
kubectl get kustomization -n activity-system

# Describe for events and conditions
kubectl describe kustomization activity-apiserver -n activity-system

# View applied resources
flux tree kustomization activity-apiserver -n activity-system

# Force reconciliation
flux reconcile kustomization activity-apiserver -n activity-system

# View dry-run of what would be applied
flux diff kustomization activity-apiserver -n activity-system
```
