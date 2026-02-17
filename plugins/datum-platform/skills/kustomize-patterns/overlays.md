# Kustomize Overlays

## Overlay Structure

```yaml
# config/overlays/{env}/kustomization.yaml
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization

namespace: myservice-system

resources:
  - ../../base

components:
  - ../../components/api-registration
  - ../../components/cert-manager-ca

patches:
  - path: deployment-patch.yaml

configMapGenerator:
  - name: myservice-config
    literals:
      - LOG_LEVEL=info
```

## Environment Overlays

### Development

Minimal resources, debugging enabled:

```yaml
# config/overlays/development/kustomization.yaml
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization

namespace: myservice-dev

resources:
  - ../../base

# No production components

patches:
  - path: development-patch.yaml

# config/overlays/development/development-patch.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: myservice
spec:
  replicas: 1
  template:
    spec:
      containers:
        - name: myservice
          env:
            - name: LOG_LEVEL
              value: debug
          resources:
            limits:
              cpu: 500m
              memory: 256Mi
            requests:
              cpu: 100m
              memory: 128Mi
```

### Staging

Production-like but smaller scale:

```yaml
# config/overlays/staging/kustomization.yaml
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization

namespace: myservice-staging

resources:
  - ../../base

components:
  - ../../components/api-registration
  - ../../components/cert-manager-ca
  - ../../components/observability

patches:
  - path: staging-patch.yaml

# config/overlays/staging/staging-patch.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: myservice
spec:
  replicas: 2
  template:
    spec:
      containers:
        - name: myservice
          resources:
            limits:
              cpu: 1000m
              memory: 512Mi
            requests:
              cpu: 250m
              memory: 256Mi
```

### Production

Full scale, all components:

```yaml
# config/overlays/production/kustomization.yaml
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization

namespace: myservice-system

resources:
  - ../../base

components:
  - ../../components/api-registration
  - ../../components/cert-manager-ca
  - ../../components/observability
  - ../../components/tracing

patches:
  - path: production-patch.yaml
  - path: hpa.yaml

# config/overlays/production/production-patch.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: myservice
spec:
  replicas: 3
  template:
    spec:
      containers:
        - name: myservice
          resources:
            limits:
              cpu: 2000m
              memory: 1Gi
            requests:
              cpu: 500m
              memory: 512Mi
      topologySpreadConstraints:
        - maxSkew: 1
          topologyKey: topology.kubernetes.io/zone
          whenUnsatisfiable: DoNotSchedule
          labelSelector:
            matchLabels:
              app.kubernetes.io/name: myservice
```

## Namespace Strategy

| Overlay | Namespace |
|---------|-----------|
| development | `{service}-dev` |
| staging | `{service}-staging` |
| production | `{service}-system` |

## Testing Overlays

```bash
# Build and verify each overlay
kubectl kustomize config/overlays/development
kubectl kustomize config/overlays/staging
kubectl kustomize config/overlays/production

# Diff against cluster
kubectl diff -k config/overlays/staging
```
