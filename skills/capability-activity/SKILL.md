# Capability: Activity

This skill covers activity timeline integration for Datum Cloud services using the Activity system.

## Overview

The Activity system is a **declarative, policy-driven, Kubernetes-native** platform for transforming raw audit logs and Kubernetes events into human-readable activity timelines. It provides:

- **Automatic capture** — Kubernetes API server audit logs capture all API operations automatically
- **Policy-driven translation** — CEL-based rules transform raw logs into readable summaries
- **Live streaming** — Real-time activity feeds via watch API
- **Historical queries** — Search and filter past activities with time ranges
- **Faceted filtering** — Get distinct values for building filter UIs
- **Multi-tenant isolation** — Activity scoped to organization, project, or user

**Key insight**: Services don't emit activity events directly. Instead, services define `ActivityPolicy` resources that describe how their resource operations should appear in activity timelines.

## API Group

All activity resources use the `activity.miloapis.com` API group with version `v1alpha1`.

## Core Resource Types

The activity system has **six resource types**:

| Resource | Scope | Purpose |
|----------|-------|---------|
| **Activity** | Read-only | Human-readable activity record (query result) |
| **ActivityPolicy** | Cluster | Defines translation rules for resource types |
| **ActivityQuery** | Ephemeral | Search historical activities with filters |
| **ActivityFacetQuery** | Ephemeral | Get distinct values for filter dropdowns |
| **AuditLogQuery** | Ephemeral | Query raw audit log entries directly |
| **AuditLogFacetsQuery** | Ephemeral | Get facets from raw audit logs |
| **PolicyPreview** | Ephemeral | Test policies against sample inputs |

Read `concepts.md` for detailed explanations of each resource type.
Read `emitting-events.md` for how controllers should emit Kubernetes events.
Read `consuming-timelines.md` for how to expose activity timelines to users.

## How Services Integrate

Services integrate by creating **ActivityPolicy** resources that define how their API operations appear in activity feeds. The activity system automatically:

1. Receives audit logs from the Kubernetes API server
2. Receives events from Kubernetes controllers
3. Matches them against ActivityPolicy rules
4. Translates to human-readable Activity summaries
5. Stores for query and streaming

### What Services DO

- **Emit Kubernetes events** from controllers for state transitions (see `emitting-events.md`)
- **Include structured data in event annotations** for user-friendly messaging (e.g., display names, values)
- **Create ActivityPolicy** resources for their resource types
- **Define CEL-based matching rules** for audit logs and events
- **Define summary templates** using event annotations for user-friendly, maintainable messaging

### What Services DON'T DO

- Emit activity records directly (the Activity system creates them)
- Manage activity storage or retention
- Handle activity queries (the activity API does this)

---

## Quick Start: Creating an ActivityPolicy

### Step 1: Define Policy for Your Resource

```yaml
apiVersion: activity.miloapis.com/v1alpha1
kind: ActivityPolicy
metadata:
  name: myservice-myresource
spec:
  resource:
    apiGroup: myservice.miloapis.com
    kind: MyResource
  auditRules:
    - match: "audit.verb == 'create'"
      summary: "{{ actor }} created {{ link(kind + ' ' + audit.objectRef.name, audit.responseObject) }}"
    - match: "audit.verb == 'delete'"
      summary: "{{ actor }} deleted {{ kind }} {{ audit.objectRef.name }}"
    - match: "audit.verb in ['update', 'patch']"
      summary: "{{ actor }} updated {{ link(kind + ' ' + audit.objectRef.name, audit.objectRef) }}"
  eventRules:
    - match: "event.reason == 'Ready'"
      summary: "{{ link(kind + ' ' + event.regarding.name, event.regarding) }} is now ready"
```

### Step 2: Add to Kustomization

```yaml
# config/apiserver/policies/kustomization.yaml
resources:
  - myresource-policy.yaml
```

### Step 3: Test with PolicyPreview

```yaml
apiVersion: activity.miloapis.com/v1alpha1
kind: PolicyPreview
spec:
  policy:
    resource:
      apiGroup: myservice.miloapis.com
      kind: MyResource
    auditRules:
      - match: "audit.verb == 'create'"
        summary: "{{ actor }} created MyResource"
  inputs:
    - type: audit
      audit:
        verb: create
        objectRef:
          apiGroup: myservice.miloapis.com
          resource: myresources
          name: my-resource
        user:
          username: alice@example.com
```

---

## Activity Data Model

### Activity Object

The translated activity record that users see:

```yaml
apiVersion: activity.miloapis.com/v1alpha1
kind: Activity
metadata:
  name: activity-abc123
spec:
  summary: "alice@example.com created MyResource my-resource"
  changeSource: human       # "human" or "system"
  actor:
    type: user              # user, serviceaccount, controller
    name: alice@example.com
    email: alice@example.com
  resource:
    apiGroup: myservice.miloapis.com
    kind: MyResource
    name: my-resource
    namespace: my-project
  links:
    - marker: "MyResource my-resource"
      resource:
        apiGroup: myservice.miloapis.com
        kind: MyResource
        name: my-resource
  tenant:
    type: project
    name: my-project
  origin:
    type: audit
    id: abc123-audit-id
  changes:                  # Optional field-level diffs
    - field: "spec.replicas"
      old: "1"
      new: "3"
```

### Actor Types

| Type | Description | Example |
|------|-------------|---------|
| `user` | Human user via UI/CLI | alice@example.com |
| `serviceaccount` | Kubernetes service account | system:serviceaccount:default:mysa |
| `controller` | Kubernetes controller | deployment-controller |

### Change Source

| Value | Meaning |
|-------|---------|
| `human` | User-initiated via UI, CLI, or API |
| `system` | Controller or automation initiated |

---

## Exposing Activity to Users

Services can help users understand activity through multiple interfaces. Read `consuming-timelines.md` for complete patterns.

### kubectl activity CLI

The most user-friendly way to query activities:

```bash
# Query recent activity (default: last 24 hours)
kubectl activity query

# Search last 7 days for human changes
kubectl activity query --start-time "now-7d" --filter "spec.changeSource == 'human'"

# Filter by resource kind
kubectl activity query --filter "spec.resource.kind == 'HTTPProxy'"

# JSON output for scripting
kubectl activity query -o json

# Pagination
kubectl activity query --limit 50 --continue-after "eyJhbGciOiJ..."
```

### Live Feed (Watch)

```bash
# Stream new activities in real-time
kubectl get activities --watch

# Filter by change source
kubectl get activities --watch --field-selector spec.changeSource=human
```

### Historical Search (ActivityQuery)

```yaml
apiVersion: activity.miloapis.com/v1alpha1
kind: ActivityQuery
metadata:
  name: recent-changes
spec:
  startTime: "now-7d"           # Relative: now-{n}{s|m|h|d|w}
  endTime: "now"                # Or absolute: 2024-01-01T00:00:00Z
  changeSource: "human"         # Optional: human or system
  namespace: "my-project"       # Optional: filter by namespace
  resourceKind: "MyResource"    # Optional: filter by kind
  actorName: "alice@example.com" # Optional: filter by actor
  search: "created"             # Optional: full-text search
  filter: "spec.actor.type == 'user'"  # Optional: CEL expression
  limit: 100                    # Pagination (max 1000)
```

### Facet Queries (For Filter UIs)

```yaml
apiVersion: activity.miloapis.com/v1alpha1
kind: ActivityFacetQuery
spec:
  timeRange:
    start: "now-30d"
  filter: "spec.changeSource == 'human'"
  facets:
    - field: spec.actor.name
      limit: 20
    - field: spec.resource.kind
    - field: spec.resource.namespace
```

Returns:
```yaml
status:
  facets:
    - field: spec.actor.name
      values:
        - value: alice@example.com
          count: 142
        - value: bob@example.com
          count: 89
    - field: spec.resource.kind
      values:
        - value: MyResource
          count: 231
```

---

## CEL Expression Reference

### Match Expressions (auditRules/eventRules)

Pure CEL returning boolean:

```yaml
# Audit log variables
audit.verb == 'create'
audit.verb in ['update', 'patch']
audit.objectRef.subresource == 'status'
audit.objectRef.subresource == 'scale'
audit.user.username.startsWith('system:')
audit.responseStatus.code >= 400

# Event variables
event.reason == 'Ready'
event.type == 'Warning'
event.regarding.name == 'my-resource'
```

### Summary Templates

CEL expressions in `{{ }}` delimiters:

```yaml
# Built-in helpers
summary: "{{ actor }} created {{ kind }}"

# link(displayText, resourceRef) - creates clickable reference
summary: "{{ link(kind + ' ' + audit.objectRef.name, audit.responseObject) }}"

# Conditional text
summary: "{{ audit.user.username.startsWith('system:') ? 'System' : actor }} updated {{ kind }}"
```

### Available Variables

| Context | Variable | Description |
|---------|----------|-------------|
| Audit | `audit` | Full audit.Event object |
| Audit | `audit.verb` | API verb (create, update, delete, etc.) |
| Audit | `audit.objectRef` | Target resource reference |
| Audit | `audit.user` | Authenticated user info |
| Audit | `audit.responseObject` | Created/updated object |
| Audit | `audit.responseStatus` | Response status |
| Event | `event` | Full core/v1 Event object |
| Event | `event.reason` | Event reason code |
| Event | `event.type` | Normal or Warning |
| Event | `event.regarding` | Resource the event is about |
| Both | `actor` | Resolved actor display name |
| Both | `kind` | Resource kind from spec |

---

## Implementation

Read `implementation.md` for:
- Complete ActivityPolicy creation guide
- Subresource handling patterns
- Human vs system actor detection
- Event rule patterns
- Testing policies with PolicyPreview
- Deployment via Kustomize

## Validation

Run `scripts/validate-activity.sh` to verify:
- ActivityPolicy exists for each resource kind
- Policies cover create/update/delete operations
- Policies are syntactically valid

## Related Files

- `concepts.md` — Activity domain model details
- `emitting-events.md` — How controllers emit Kubernetes events for activity
- `implementation.md` — Integration guide with examples (creating ActivityPolicies)
- `consuming-timelines.md` — How to expose activity timelines to users
- `scripts/validate-activity.sh` — Validation script
- `scripts/scaffold-activity.sh` — Policy scaffolding script
