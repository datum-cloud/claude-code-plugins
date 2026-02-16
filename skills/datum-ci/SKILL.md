# Datum CI

This skill covers CI/CD patterns for Datum Cloud services.

## Overview

Services use GitHub Actions with reusable workflows from `datum-cloud/actions`.

## Key Files

| File | Purpose |
|------|---------|
| `github-actions.md` | Workflow patterns |

## Pipeline Structure

```
validate → build → publish → deploy
```

## Reusable Workflows

### Validate

```yaml
# .github/workflows/ci.yaml
name: CI

on:
  push:
    branches: [main]
  pull_request:
    branches: [main]

jobs:
  validate:
    uses: datum-cloud/actions/.github/workflows/go-validate.yaml@main
    with:
      go-version: "1.21"
```

### Build

```yaml
  build:
    needs: validate
    uses: datum-cloud/actions/.github/workflows/container-build.yaml@main
    with:
      dockerfile: Dockerfile
      context: .
    secrets:
      registry-username: ${{ secrets.REGISTRY_USERNAME }}
      registry-password: ${{ secrets.REGISTRY_PASSWORD }}
```

### Publish

```yaml
  publish:
    needs: build
    if: github.ref == 'refs/heads/main'
    uses: datum-cloud/actions/.github/workflows/container-publish.yaml@main
    with:
      image-name: myservice
      sign-image: true
    secrets:
      registry-username: ${{ secrets.REGISTRY_USERNAME }}
      registry-password: ${{ secrets.REGISTRY_PASSWORD }}
      signing-key: ${{ secrets.COSIGN_PRIVATE_KEY }}
```

## Taskfile

Use Taskfile for local development:

```yaml
# Taskfile.yaml
version: "3"

tasks:
  generate:
    desc: Run code generation
    cmds:
      - go generate ./...
      - controller-gen object paths="./pkg/apis/..."

  lint:
    desc: Run linters
    cmds:
      - golangci-lint run ./...

  test:
    desc: Run tests
    cmds:
      - go test -race -coverprofile=coverage.out ./...

  build:
    desc: Build binary
    cmds:
      - go build -o bin/myservice ./cmd/myservice

  docker-build:
    desc: Build container image
    cmds:
      - docker build -t myservice:local .
```

## Dockerfile

```dockerfile
# Build stage
FROM golang:1.21 AS builder

WORKDIR /workspace
COPY go.mod go.sum ./
RUN go mod download

COPY . .
RUN CGO_ENABLED=0 GOOS=linux go build -o /myservice ./cmd/myservice

# Runtime stage
FROM gcr.io/distroless/static-debian12:nonroot

COPY --from=builder /myservice /myservice

USER nonroot:nonroot
ENTRYPOINT ["/myservice"]
```

## Related Files

- `github-actions.md` — Detailed workflow patterns
