---
name: investigate
description: Investigate platform activity to understand who did what, when, and why. Use for incident investigation, debugging, compliance audits, and understanding system behavior.
---

# Skill: Investigate Platform Activity

This skill helps you investigate Kubernetes platform activity using the Activity MCP server.

## When to Use

- **Incident investigation**: "Who deleted my pod?"
- **Debugging**: "Why is my deployment failing?"
- **Compliance**: "Show all secret access in production"
- **Understanding**: "What changed in the last hour?"

## Prerequisites

The Activity MCP server must be running and configured:
```bash
activity mcp --kubeconfig ~/.kube/config
```

## Available Tools

### Query Tools

| Tool | Purpose |
|------|---------|
| `query_audit_logs` | Search raw audit log entries |
| `query_activities` | Search human-readable summaries |
| `query_events` | Search Kubernetes events |

### Discovery Tools

| Tool | Purpose |
|------|---------|
| `get_audit_log_facets` | Find distinct users, resources, verbs |
| `get_activity_facets` | Find distinct actors, kinds |
| `get_event_facets` | Find distinct reasons, components |

### Investigation Tools

| Tool | Purpose |
|------|---------|
| `find_failed_operations` | Find 4xx/5xx responses |
| `get_resource_history` | Track changes to a resource |
| `get_user_activity_summary` | See what a user has done |

### Analytics Tools

| Tool | Purpose |
|------|---------|
| `get_activity_timeline` | Activity over time |
| `summarize_recent_activity` | High-level summary |
| `compare_activity_periods` | Compare two time periods |

## Common Patterns

### Find Who Deleted Something

```
Tool: query_audit_logs
Args:
  startTime: "now-24h"
  filter: "verb == 'delete' && objectRef.name == 'my-resource'"
```

### Find Failed Operations

```
Tool: find_failed_operations
Args:
  startTime: "now-1h"
  namespace: "production"
```

### Get Resource History

```
Tool: get_resource_history
Args:
  apiGroup: "apps"
  resource: "deployments"
  name: "my-deployment"
  namespace: "default"
```

### Find User Activity

```
Tool: get_user_activity_summary
Args:
  username: "alice@example.com"
  startTime: "now-7d"
```

### Find Secret Access

```
Tool: query_audit_logs
Args:
  startTime: "now-7d"
  filter: "objectRef.resource == 'secrets'"
```

## CEL Filter Reference

### Audit Log Fields

```cel
verb == 'create'                              # Specific verb
verb in ['create', 'update', 'delete']        # Multiple verbs
objectRef.resource == 'secrets'               # Resource type
objectRef.namespace == 'production'           # Namespace
objectRef.name == 'my-secret'                 # Resource name
user.username == 'alice@example.com'          # Specific user
user.username.startsWith('system:')           # System accounts
responseStatus.code >= 400                    # Failed requests
```

### Activity Fields

```cel
spec.changeSource == 'human'                  # Human changes
spec.actor.name == 'alice@example.com'        # Specific actor
spec.resource.kind == 'Deployment'            # Resource kind
spec.resource.namespace == 'production'       # Namespace
```

## Time Range Syntax

- Relative: `now-7d`, `now-24h`, `now-30m`
- Absolute: `2024-01-15T10:00:00Z`

## Example Investigation

**Scenario**: A secret was deleted and we need to find who did it.

1. **Find the deletion**:
   ```
   query_audit_logs
     startTime: "now-24h"
     filter: "verb == 'delete' && objectRef.resource == 'secrets'"
   ```

2. **Check the user's other activity**:
   ```
   get_user_activity_summary
     username: "bob@example.com"
     startTime: "now-24h"
   ```

3. **Get full timeline**:
   ```
   get_resource_history
     resource: "secrets"
     name: "my-secret"
     namespace: "production"
   ```

## Output Formatting

Present results with:
- **Summary first**: Answer the question directly
- **Timeline**: Show events in order
- **Actors**: Who did what
- **Next steps**: Suggest further investigation
