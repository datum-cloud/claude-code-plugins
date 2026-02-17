# Kustomize Components

## Component Structure

```yaml
# config/components/mycomponent/kustomization.yaml
apiVersion: kustomize.config.k8s.io/v1alpha1
kind: Component

resources:
  - resource.yaml

patches:
  - path: patch.yaml
    target:
      kind: Deployment
      name: myservice
```

## Standard Components

### api-registration

Registers the APIService with kube-apiserver:

```yaml
# config/components/api-registration/kustomization.yaml
apiVersion: kustomize.config.k8s.io/v1alpha1
kind: Component

resources:
  - apiservice.yaml

# config/components/api-registration/apiservice.yaml
apiVersion: apiregistration.k8s.io/v1
kind: APIService
metadata:
  name: v1alpha1.myservice.miloapis.com
spec:
  group: myservice.miloapis.com
  version: v1alpha1
  service:
    name: myservice
    namespace: myservice-system
    port: 443
  groupPriorityMinimum: 1000
  versionPriority: 15
```

### cert-manager-ca

TLS certificates via cert-manager CSI:

```yaml
# config/components/cert-manager-ca/kustomization.yaml
apiVersion: kustomize.config.k8s.io/v1alpha1
kind: Component

patches:
  - path: tls-volume-patch.yaml
    target:
      kind: Deployment
      name: myservice

# config/components/cert-manager-ca/tls-volume-patch.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: myservice
spec:
  template:
    spec:
      volumes:
        - name: tls
          csi:
            driver: csi.cert-manager.io
            readOnly: true
            volumeAttributes:
              csi.cert-manager.io/issuer-name: service-ca
              csi.cert-manager.io/issuer-kind: ClusterIssuer
              csi.cert-manager.io/dns-names: "${SERVICE}.${NAMESPACE}.svc"
      containers:
        - name: myservice
          volumeMounts:
            - name: tls
              mountPath: /var/run/secrets/tls
              readOnly: true
```

### observability

Metrics and health endpoints:

```yaml
# config/components/observability/kustomization.yaml
apiVersion: kustomize.config.k8s.io/v1alpha1
kind: Component

resources:
  - servicemonitor.yaml
  - podmonitor.yaml

patches:
  - path: metrics-port-patch.yaml
    target:
      kind: Deployment
      name: myservice
```

### tracing

OpenTelemetry tracing:

```yaml
# config/components/tracing/kustomization.yaml
apiVersion: kustomize.config.k8s.io/v1alpha1
kind: Component

patches:
  - path: otel-env-patch.yaml
    target:
      kind: Deployment
      name: myservice

# config/components/tracing/otel-env-patch.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: myservice
spec:
  template:
    spec:
      containers:
        - name: myservice
          env:
            - name: OTEL_EXPORTER_OTLP_ENDPOINT
              value: "http://otel-collector:4317"
            - name: OTEL_SERVICE_NAME
              value: "myservice"
```

## Using Components

In overlays:

```yaml
# config/overlays/production/kustomization.yaml
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization

resources:
  - ../../base

components:
  - ../../components/api-registration
  - ../../components/cert-manager-ca
  - ../../components/observability
  - ../../components/tracing
```

## Creating New Components

1. Create directory: `config/components/{name}/`
2. Create `kustomization.yaml` with `kind: Component`
3. Add resources or patches
4. Reference in relevant overlays
5. Test with `kubectl kustomize`
