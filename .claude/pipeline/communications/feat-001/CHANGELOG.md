# Changelog

All notable changes to the `datum-platform` Claude Code plugin are documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/).

## [Unreleased]

### Added

- **k8s-apiserver-patterns: Feature Gates documentation** - New `feature-gates.md` file documenting the Kubernetes feature lifecycle pattern (Alpha -> Beta -> GA -> Removal) for aggregated API servers. Includes:
  - Feature definition patterns using `k8s.io/component-base/featuregate`
  - Registration via `init()` pattern
  - Runtime enablement checking in Config, REST handlers, and controllers
  - CLI configuration (`--feature-gates=FeatureName=true`)
  - Complete graduation lifecycle with code examples at each stage
  - Naming conventions (PascalCase, no suffix)
  - Decision criteria for when to use feature gates
  - Integration with existing server configuration patterns

  Reference: Milo Events proxy implementation (`pkg/features/features.go`)
