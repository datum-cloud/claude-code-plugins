---
name: kustomize-patterns
description: Covers Kustomize deployment patterns using base, components, and overlays structure. Use when organizing Kubernetes manifests for different environments.
---

# Kustomize Patterns

This skill covers Kustomize deployment patterns for Datum Cloud services.

## Overview

Services use a base + components + overlays model:

```
config/
├── base/                    # Core resources
├── components/              # Toggleable features
└── overlays/               # Environment-specific
```

## Key Files

| File | Purpose |
|------|---------|
| `components.md` | Component patterns |
| `overlays.md` | Environment overlays |

## Base Structure

```yaml
# config/base/kustomization.yaml
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization

resources:
  - deployment.yaml
  - service.yaml
  - serviceaccount.yaml

commonLabels:
  app.kubernetes.io/name: myservice
  app.kubernetes.io/component: apiserver
```

## Components

Independently toggleable features:

| Component | Purpose |
|-----------|---------|
| `api-registration` | APIService registration |
| `cert-manager-ca` | TLS certificates |
| `observability` | Metrics and health |
| `tracing` | Distributed tracing |

## Overlays

One per environment:

| Overlay | Purpose |
|---------|---------|
| `development` | Local development |
| `staging` | Pre-production |
| `production` | Production deployment |

## Validation

Run `scripts/validate-kustomize.sh` to verify:
- All overlays build successfully
- No invalid references

Run `scripts/check-security.sh` to verify:
- Security contexts set
- No root containers
- Resource limits defined

## Related Files

- `components.md` — Component details
- `overlays.md` — Overlay patterns
- `scripts/validate-kustomize.sh` — Build validation
- `scripts/check-security.sh` — Security validation
