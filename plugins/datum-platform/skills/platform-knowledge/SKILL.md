---
name: platform-knowledge
description: Provides high-level understanding of the Datum Cloud platform architecture. Use when onboarding to the codebase, understanding the system structure, or learning about multi-tenancy, resource hierarchy, and service architecture.
user-invocable: false
---

# Platform Knowledge

This skill provides high-level understanding of the Datum Cloud platform architecture.

## Platform Overview

Datum Cloud is a multi-tenant cloud platform built on Kubernetes primitives. The control plane is **Milo** — an extensible multi-tenant control plane built with the Kubernetes API library.

### Architecture Principles

- **Kubernetes-native**: All services are Kubernetes aggregated API servers (NOT CRD-based)
- **Multi-tenant by design**: Every resource belongs to an organization and project
- **Custom storage backends**: Services implement their own storage, not etcd
- **Platform capabilities**: Services integrate with quota, insights, telemetry, and activity

## Resource Hierarchy

```
Organization
└── Project
    └── Resources (service-specific)
```

### Organizations

Top-level tenant boundary. Contains:
- Account settings and payment methods
- IAM policies at organization scope
- Quota allocations (AllowanceBuckets)

### Projects

Workload isolation within an organization. Contains:
- Service resources
- Project-scoped IAM policies
- Resource grants from organization quotas

## Multi-Tenancy Model

### Tenant Isolation

- **Data isolation**: Each tenant's data is logically separated
- **Control plane isolation**: API requests are scoped to tenant context
- **Network isolation**: Optional dedicated networking per tenant (Enterprise tier)

### Tenant Context

Every API request carries tenant context:
- Organization ID
- Project ID (when applicable)
- User identity and roles

### Cross-Tenant Operations

Some platform operations span tenants:
- Platform operators can view across organizations
- Usage aggregation for reporting
- Usage analytics for capacity planning

## Service Architecture

Services in Datum Cloud follow a consistent pattern:

### Aggregated API Server

Each service is a Kubernetes aggregated API server that:
- Registers with kube-apiserver via APIService
- Implements its own REST handlers
- Uses custom storage backends (not etcd)
- Handles its own authentication delegation

### Choosing an Integration Pattern

Datum Cloud services can use either approach to integrate with the control plane:

1. **Controller-Runtime + CRDs** — Using Milo's multi-cluster runtime provider
2. **Aggregated API Server** — For custom storage backends or API control

The choice depends on two primary factors:

| Factor | Use Aggregated API Server | Use Controller-Runtime |
|--------|---------------------------|------------------------|
| **Storage** | Need custom backend (database, external system) | etcd is sufficient |
| **API Control** | Need custom subresources, streaming, or fine-grained request handling | Standard CRUD semantics |

**For detailed guidance**: Read `k8s-apiserver-patterns/architecture-decision.md` which covers:
- When to use each approach
- Milo's multi-cluster runtime provider for controller-runtime services
- Decision flowchart for new services
- Examples of both patterns in Datum Cloud

### API Group Convention

Services use the pattern: `{service}.miloapis.com`

Examples:
- `resourcemanager.miloapis.com` — Organizations and projects
- `iam.miloapis.com` — Identity and access management
- `activity.miloapis.com` — Activity timelines
- `insights.miloapis.com` — Proactive issue detection
- `quota.miloapis.com` — Resource quota enforcement

### Resource Naming

Resources follow Kubernetes conventions:
- Kind: PascalCase singular (`VirtualMachine`)
- Resource: lowercase plural (`virtualmachines`)
- Short names: lowercase abbreviation (`vm`)

## Identity and Access Management

The platform uses a Kubernetes-native IAM system. Key concepts:

### IAM Resources

| Resource | Purpose |
|----------|---------|
| `ProtectedResource` | Declares a resource type and its permissions |
| `Role` | Collection of permissions that can be granted |
| `PolicyBinding` | Binds a role to users/groups on a resource |
| `User` | Platform user identity |
| `Group` | Collection of users |

### Authorization Flow

1. Services declare ProtectedResources (what resources exist and their permissions)
2. Platform defines Roles (collections of permissions)
3. Administrators create PolicyBindings (who can do what on which resources)
4. IAM system enforces authorization automatically

### Permission Inheritance

Permissions flow down the resource hierarchy:
- Organization admin → automatically admin on all Projects
- Project admin → automatically admin on all resources in that Project

Read `milo-iam/SKILL.md` for comprehensive IAM documentation.

## Platform Capabilities

Every service can integrate with these platform capabilities:

| Capability | Purpose | Integration Point |
|------------|---------|-------------------|
| IAM | Authorization | ProtectedResource + Role definitions |
| Quota | Limit resource consumption | Admission control |
| Insights | Proactive issue detection | InsightPolicy resources |
| Telemetry | Observability data | Metrics, traces, logs |
| Activity | Audit trail | ActivityPolicy resources |

Read the individual capability skills for integration details.

## Related Files

- `services-catalog.md` — Catalog of platform services
