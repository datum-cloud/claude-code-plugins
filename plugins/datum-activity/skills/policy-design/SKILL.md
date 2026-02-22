---
name: policy-design
description: Design ActivityPolicy resources that translate audit logs and events into human-readable activity timelines for service consumers.
---

# Skill: Activity Policy Design

This skill helps service providers create ActivityPolicy resources that transform raw audit logs and Kubernetes events into meaningful activity summaries for their consumers.

## When to Use

- Creating activity timelines for a new resource type
- Improving existing activity summaries
- Testing policy changes before deployment
- Understanding how the Activity system works

## Prerequisites

The Activity MCP server must be running:
```bash
activity mcp --kubeconfig ~/.kube/config
```

## Available Tools

| Tool | Purpose |
|------|---------|
| `list_activity_policies` | See existing policies for reference |
| `preview_activity_policy` | Test a policy against sample inputs |
| `query_audit_logs` | Examine real audit log data |
| `get_audit_log_facets` | Find distinct verbs, resources, users |

## ActivityPolicy Structure

```yaml
apiVersion: activity.miloapis.com/v1alpha1
kind: ActivityPolicy
metadata:
  name: {service}-{resource}
spec:
  resource:
    apiGroup: {api-group}
    kind: {Kind}
  auditRules:
    - match: "{CEL expression}"
      summary: "{template}"
  eventRules:
    - match: "{CEL expression}"
      summary: "{template}"
```

## Standard Rule Templates

### Basic CRUD Operations

```yaml
auditRules:
  # Create
  - match: "audit.verb == 'create'"
    summary: "{{ actor }} created {{ link(kind + ' ' + audit.objectRef.name, audit.responseObject) }}"

  # Delete
  - match: "audit.verb == 'delete'"
    summary: "{{ actor }} deleted {{ kind }} {{ audit.objectRef.name }}"

  # Update (spec only, not status)
  - match: "audit.verb in ['update', 'patch'] && audit.objectRef.subresource == ''"
    summary: "{{ actor }} updated {{ link(kind + ' ' + audit.objectRef.name, audit.objectRef) }}"

  # Status update (system)
  - match: "audit.objectRef.subresource == 'status'"
    summary: "System updated status of {{ kind }} {{ audit.objectRef.name }}"
```

### Scale Operations

```yaml
  - match: "audit.objectRef.subresource == 'scale'"
    summary: "{{ actor }} scaled {{ link(kind + ' ' + audit.objectRef.name, audit.objectRef) }}"
```

### Event Rules

```yaml
eventRules:
  - match: "event.reason == 'Ready'"
    summary: "{{ link(kind + ' ' + event.regarding.name, event.regarding) }} is now ready"

  - match: "event.reason == 'Failed'"
    summary: "{{ kind }} {{ event.regarding.name }} failed: {{ event.note }}"

  - match: "event.type == 'Warning'"
    summary: "Warning on {{ kind }} {{ event.regarding.name }}: {{ event.note }}"
```

## Match Expression Reference

### Audit Context Variables

```cel
audit.verb                      # create, update, delete, patch, get, list, watch
audit.objectRef.resource        # plural: deployments, configmaps
audit.objectRef.name            # resource name
audit.objectRef.namespace       # namespace
audit.objectRef.apiGroup        # apps, networking.k8s.io
audit.objectRef.subresource     # status, scale, or ""
audit.user.username             # alice@example.com
audit.responseStatus.code       # 200, 201, 404, 500
audit.responseObject            # created/updated object (for links)
```

### Event Context Variables

```cel
event.reason                    # Ready, Failed, Scheduled
event.type                      # Normal, Warning
event.note                      # event message
event.regarding.name            # resource name
event.regarding.kind            # resource kind
event.regarding.namespace       # namespace
event.annotations               # event annotations map
```

## Summary Template Variables

```
{{ actor }}                     # Human-readable actor name
{{ kind }}                      # Resource kind from spec.resource
{{ audit.objectRef.name }}      # Resource name
{{ audit.objectRef.namespace }} # Namespace
{{ event.note }}                # Event message
```

### link() Helper

Creates clickable references:
```
{{ link(displayText, resourceRef) }}

# Examples:
{{ link(kind + ' ' + audit.objectRef.name, audit.responseObject) }}
{{ link(kind + ' ' + event.regarding.name, event.regarding) }}
```

## Design Workflow

### 1. Gather Requirements

Ask:
- What API group and kind?
- What operations matter to users?
- Are there subresources (status, scale)?
- What events does the controller emit?

### 2. Examine Real Data

```
Tool: query_audit_logs
Args:
  filter: "objectRef.resource == 'myresources'"
  startTime: "now-7d"
  limit: 20
```

### 3. See Existing Policies

```
Tool: list_activity_policies
```

### 4. Draft Policy

Create rules for each meaningful operation.

### 5. Test with Preview

```
Tool: preview_activity_policy
Args:
  policy: |
    apiVersion: activity.miloapis.com/v1alpha1
    kind: ActivityPolicy
    spec:
      resource:
        apiGroup: myservice.miloapis.com
        kind: MyResource
      auditRules:
        - match: "audit.verb == 'create'"
          summary: "{{ actor }} created {{ kind }} {{ audit.objectRef.name }}"
  inputs:
    - type: audit
      audit:
        verb: create
        user:
          username: alice@example.com
        objectRef:
          apiGroup: myservice.miloapis.com
          resource: myresources
          name: my-resource
```

## Best Practices

### 1. Handle Subresources

Always distinguish spec updates from status updates:
```yaml
# User-initiated spec changes
- match: "audit.verb in ['update', 'patch'] && audit.objectRef.subresource == ''"

# System-initiated status changes
- match: "audit.objectRef.subresource == 'status'"
```

### 2. Use Meaningful Actions

Good: "created", "updated", "deleted", "scaled", "configured"
Bad: "changed", "modified", "touched"

### 3. Include Context

Good: "alice created Domain example.com in production"
Bad: "resource created"

### 4. Make Links Clickable

Use `link()` for navigable references:
```yaml
summary: "{{ actor }} created {{ link(kind + ' ' + audit.objectRef.name, audit.responseObject) }}"
```

### 5. Order Rules Carefully

Specific rules first, general fallbacks last:
```yaml
# Specific first
- match: "audit.verb == 'delete' && audit.responseStatus.code == 404"
  summary: "{{ actor }} attempted to delete non-existent {{ kind }}"

# General second
- match: "audit.verb == 'delete'"
  summary: "{{ actor }} deleted {{ kind }} {{ audit.objectRef.name }}"
```

## Complete Example

```yaml
apiVersion: activity.miloapis.com/v1alpha1
kind: ActivityPolicy
metadata:
  name: compute-workload
spec:
  resource:
    apiGroup: compute.datumapis.com
    kind: Workload
  auditRules:
    - match: "audit.objectRef.subresource == 'scale'"
      summary: "{{ actor }} scaled {{ link(kind + ' ' + audit.objectRef.name, audit.objectRef) }}"
    - match: "audit.verb == 'create'"
      summary: "{{ actor }} created {{ link(kind + ' ' + audit.objectRef.name, audit.responseObject) }}"
    - match: "audit.verb == 'delete'"
      summary: "{{ actor }} deleted {{ kind }} {{ audit.objectRef.name }}"
    - match: "audit.verb in ['update', 'patch'] && audit.objectRef.subresource == ''"
      summary: "{{ actor }} updated {{ link(kind + ' ' + audit.objectRef.name, audit.objectRef) }}"
    - match: "audit.objectRef.subresource == 'status'"
      summary: "System updated status of {{ kind }} {{ audit.objectRef.name }}"
  eventRules:
    - match: "event.reason == 'Ready'"
      summary: "{{ link(kind + ' ' + event.regarding.name, event.regarding) }} is now ready"
    - match: "event.reason == 'Scaled'"
      summary: "{{ kind }} {{ event.regarding.name }} scaled to {{ event.annotations['replicas'] }} replicas"
    - match: "event.type == 'Warning'"
      summary: "Warning on {{ kind }} {{ event.regarding.name }}: {{ event.note }}"
```
