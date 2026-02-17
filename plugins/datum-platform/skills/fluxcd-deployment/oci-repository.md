# OCIRepository Patterns

## Overview

OCIRepository resources pull complete Kustomize bundles from OCI registries. The bundle contains the entire `config/` directory from a service repository, published as an OCI artifact.

## Basic OCIRepository

```yaml
apiVersion: source.toolkit.fluxcd.io/v1
kind: OCIRepository
metadata:
  name: activity-kustomize
  namespace: activity-system
spec:
  interval: 5m
  url: oci://ghcr.io/datum-cloud/activity-kustomize
  ref:
    semver: ">=0.0.0"
```

## Semver Reference Options

### Stable Releases Only (Production)

```yaml
spec:
  ref:
    semver: ">=0.0.0"
```

Matches: `v1.0.0`, `v1.2.3`, `v2.0.0`
Does NOT match: `v1.0.0-rc1`, `v1.0.0-staging-test-deploy-abc123`

### Pre-releases with Filter (Staging)

```yaml
spec:
  ref:
    semver: ">=0.0.0-0"
    semverFilter: '.*-staging-test-deploy-.*'
```

Matches: `v0.0.0-staging-test-deploy-abc123`, `v1.0.0-staging-test-deploy-feature-branch`
The `-0` suffix enables pre-release matching.

### Specific Tag

```yaml
spec:
  ref:
    tag: "v1.2.3"
```

### Latest from Branch

```yaml
spec:
  ref:
    tag: "main"
```

## Multiple OCIRepositories

Services may have multiple OCI bundles (e.g., main service + UI):

```yaml
# Main service Kustomize bundle
apiVersion: source.toolkit.fluxcd.io/v1
kind: OCIRepository
metadata:
  name: activity-kustomize
spec:
  url: oci://ghcr.io/datum-cloud/activity-kustomize
  ref:
    semver: ">=0.0.0-0"
    semverFilter: '.*-staging-test-deploy-.*'

---
# UI Kustomize bundle
apiVersion: source.toolkit.fluxcd.io/v1
kind: OCIRepository
metadata:
  name: activity-ui-kustomize
spec:
  url: oci://ghcr.io/datum-cloud/activity-ui-kustomize
  ref:
    semver: ">=0.0.0-0"
    semverFilter: '.*-staging-test-deploy-.*'
```

## Environment Patches

Use Kustomize patches to override OCIRepository refs per environment:

```yaml
# overlays/staging/patches/oci-repository-patch.yaml
apiVersion: source.toolkit.fluxcd.io/v1
kind: OCIRepository
metadata:
  name: activity-kustomize
spec:
  ref:
    semver: ">=0.0.0-0"
    semverFilter: '.*-staging-test-deploy-.*'

---
# overlays/production/patches/oci-repository-patch.yaml
apiVersion: source.toolkit.fluxcd.io/v1
kind: OCIRepository
metadata:
  name: activity-kustomize
spec:
  ref:
    semver: ">=0.0.0"
```

## Publishing OCI Artifacts

Services publish their Kustomize bundles using Flux CLI:

```bash
# Publish with semver tag
flux push artifact oci://ghcr.io/datum-cloud/activity-kustomize:v1.2.3 \
  --path=./config \
  --source="https://github.com/datum-cloud/activity" \
  --revision="abc123"

# Publish pre-release for staging
flux push artifact oci://ghcr.io/datum-cloud/activity-kustomize:v0.0.0-staging-test-deploy-feature-branch \
  --path=./config \
  --source="https://github.com/datum-cloud/activity" \
  --revision="def456"
```

## GitHub Actions Workflow

```yaml
name: Publish Kustomize Bundle

on:
  push:
    branches: [main]
    tags: ['v*']

jobs:
  publish:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4

      - name: Setup Flux CLI
        uses: fluxcd/flux2/action@main

      - name: Login to GHCR
        run: |
          echo "${{ secrets.GITHUB_TOKEN }}" | \
            flux push artifact --creds=flux:${{ secrets.GITHUB_TOKEN }} \
            oci://ghcr.io/datum-cloud/${{ github.event.repository.name }}-kustomize:${{ github.ref_name }} \
            --path=./config \
            --source="${{ github.repositoryUrl }}" \
            --revision="${{ github.sha }}"
```

## Verification

Check OCIRepository status:

```bash
# View OCIRepository status
kubectl get ocirepository -n activity-system

# Describe for details
kubectl describe ocirepository activity-kustomize -n activity-system

# Check which artifact is currently pulled
kubectl get ocirepository activity-kustomize -n activity-system -o jsonpath='{.status.artifact.revision}'
```
