# Services Catalog

This catalog lists services in the Datum Cloud platform with their API groups, primary resources, and capability integrations.

## Catalog Format

Each service entry includes:
- **API Group**: The Kubernetes API group
- **Primary Resources**: Main resource types exposed
- **Capabilities**: Which platform capabilities are integrated
- **Status**: Implementation status

---

## Core Platform Services

### Resource Manager

```yaml
name: Resource Manager
apiGroup: resourcemanager.miloapis.com
version: v1alpha1
primaryResources:
  - kind: Organization
    resource: organizations
    description: Top-level tenant boundary
  - kind: Project
    resource: projects
    description: Workload isolation within an organization
capabilities:
  quota: true
  insights: true
  telemetry: true
  activity: true
status: Stable
```

The Resource Manager provides the multi-tenant hierarchy that all other services build upon. Organizations and Projects are the foundation of the platform's resource model.

---

### IAM (Identity and Access Management)

```yaml
name: IAM
apiGroup: iam.miloapis.com
version: v1alpha1
primaryResources:
  - kind: ProtectedResource
    resource: protectedresources
    description: Declares resource types and their permissions
  - kind: Role
    resource: roles
    description: Collection of permissions
  - kind: PolicyBinding
    resource: policybindings
    description: Binds roles to subjects on resources
  - kind: User
    resource: users
    description: Platform user identity
  - kind: Group
    resource: groups
    description: Collection of users
  - kind: GroupMembership
    resource: groupmemberships
    description: Links users to groups
capabilities:
  quota: false
  insights: true
  telemetry: true
  activity: true
status: Stable
```

IAM provides authorization for all platform resources. Services integrate by defining ProtectedResources and Roles.

---

### Activity

```yaml
name: Activity
apiGroup: activity.miloapis.com
version: v1alpha1
primaryResources:
  - kind: Activity
    resource: activities
    description: Human-readable record of platform events (read-only)
  - kind: ActivityPolicy
    resource: activitypolicies
    description: Translates audit logs and events into activities
  - kind: ActivityQuery
    resource: activityqueries
    description: Query historical activities
  - kind: ActivityFacetQuery
    resource: activityfacetqueries
    description: Get distinct values for filter UIs
  - kind: AuditLogQuery
    resource: auditlogqueries
    description: Query raw audit logs
  - kind: PolicyPreview
    resource: policypreviews
    description: Test ActivityPolicy rules
capabilities:
  quota: false
  insights: false
  telemetry: true
  activity: false  # Self-referential
status: Stable
```

Activity provides audit trails and event timelines for all platform resources.

---

### Insights

```yaml
name: Insights
apiGroup: insights.miloapis.com
version: v1alpha1
primaryResources:
  - kind: Insight
    resource: insights
    description: Proactive issue notification (system-generated)
  - kind: InsightPolicy
    resource: insightpolicies
    description: CEL-based rules for detecting issues
  - kind: InsightMuteRule
    resource: insightmuterules
    description: Suppress insights matching criteria
capabilities:
  quota: false
  insights: false  # Self-referential
  telemetry: true
  activity: true
status: Stable
```

Insights proactively detects configuration issues, security concerns, and optimization opportunities.

---

### Quota

```yaml
name: Quota
apiGroup: quota.miloapis.com
version: v1alpha1
primaryResources:
  - kind: ResourceRegistration
    resource: resourceregistrations
    description: Registers a limitable resource dimension
  - kind: ResourceGrant
    resource: resourcegrants
    description: Grants quota to a tenant
  - kind: AllowanceBucket
    resource: allowancebuckets
    description: Aggregated view of available quota (system-generated)
  - kind: ResourceClaim
    resource: resourceclaims
    description: Claims quota for resource usage
  - kind: GrantCreationPolicy
    resource: grantcreationpolicies
    description: Auto-creates grants based on conditions
  - kind: ClaimCreationPolicy
    resource: claimcreationpolicies
    description: Auto-creates claims at admission
capabilities:
  quota: false  # Self-referential
  insights: true
  telemetry: true
  activity: true
status: Stable
```

Quota manages resource limits and usage tracking across the platform.

---

## Adding a New Service

When a new service is created:

1. Add an entry to this catalog following the format above
2. Document the API group, version, and resources
3. List which capabilities are integrated
4. Set the appropriate status (Alpha, Beta, Stable)

## Cross-Service References

Services commonly reference resources from other services:

| Service | References | Purpose |
|---------|------------|---------|
| All services | `resourcemanager.miloapis.com/Project` | Parent resource for IAM inheritance |
| All services | `iam.miloapis.com/ProtectedResource` | Authorization declarations |
| All services | `quota.miloapis.com/ResourceRegistration` | Quota dimension registration |
