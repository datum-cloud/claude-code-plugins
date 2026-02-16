# Consuming Activity Timelines

This guide explains how services can expose activity timelines to users, helping them understand what's happening in the system.

## Overview

The Activity system provides multiple interfaces for consuming activity data:

| Interface | Use Case | Best For |
|-----------|----------|----------|
| `kubectl activity query` | CLI-based investigation | DevOps, debugging, scripting |
| Watch API | Real-time streaming | Live dashboards, notifications |
| ActivityQuery API | Programmatic historical search | Backend services, reporting |
| ActivityFacetQuery API | Filter autocomplete | Building filter UIs |

---

## kubectl activity CLI

The `kubectl activity` command provides a user-friendly interface for querying activities.

### Basic Usage

```bash
# Query recent activity (default: last 24 hours)
kubectl activity query

# Search last 7 days
kubectl activity query --start-time "now-7d"

# Filter by CEL expression
kubectl activity query --filter "spec.changeSource == 'human'"

# Multiple filters
kubectl activity query --start-time "now-7d" \
  --filter "spec.resource.kind == 'HTTPProxy' && spec.changeSource == 'human'"
```

### Output Formats

```bash
# Human-readable table (default)
kubectl activity query

# JSON for programmatic processing
kubectl activity query -o json

# YAML
kubectl activity query -o yaml

# JSONPath for extracting specific fields
kubectl activity query -o jsonpath='{range .items[*]}{.spec.summary}{"\n"}{end}'
```

### Pagination

```bash
# Limit results
kubectl activity query --limit 50

# Get next page using continuation token
kubectl activity query --limit 50 --continue-after "eyJhbGciOiJ..."

# Fetch all pages (use with caution)
kubectl activity query --all-pages
```

### Common Queries

```bash
# What changed in production today?
kubectl activity query --filter "spec.resource.namespace == 'production'"

# Who deleted resources this week?
kubectl activity query --start-time "now-7d" \
  --filter "spec.summary.contains('deleted')"

# All human-initiated changes
kubectl activity query --filter "spec.changeSource == 'human'"

# Changes by specific user
kubectl activity query --filter "spec.actor.name == 'alice@example.com'"

# HTTPProxy changes only
kubectl activity query --filter "spec.resource.kind == 'HTTPProxy'"

# Failed operations
kubectl activity query --filter "spec.summary.contains('failed')"
```

---

## Real-time Watch API

Stream activities as they happen using the Kubernetes watch API.

### kubectl Watch

```bash
# Watch all activities
kubectl get activities --watch

# Watch with namespace filter
kubectl get activities --watch --namespace production

# Watch human changes only
kubectl get activities --watch --field-selector spec.changeSource=human
```

### Programmatic Watch (Go)

```go
import (
    "context"
    metav1 "k8s.io/apimachinery/pkg/apis/meta/v1"
    "k8s.io/apimachinery/pkg/watch"
    activityv1alpha1 "go.miloapis.com/activity/pkg/apis/activity/v1alpha1"
)

func WatchActivities(ctx context.Context, client activityv1alpha1.ActivityInterface) error {
    watcher, err := client.Watch(ctx, metav1.ListOptions{})
    if err != nil {
        return err
    }
    defer watcher.Stop()

    for event := range watcher.ResultChan() {
        switch event.Type {
        case watch.Added:
            activity := event.Object.(*activityv1alpha1.Activity)
            fmt.Printf("New activity: %s\n", activity.Spec.Summary)
        }
    }
    return nil
}
```

### Watch with Reconnection

For production use, handle disconnections gracefully:

```go
func WatchWithReconnect(ctx context.Context, client activityv1alpha1.ActivityInterface) {
    var resourceVersion string

    for {
        select {
        case <-ctx.Done():
            return
        default:
        }

        opts := metav1.ListOptions{
            ResourceVersion: resourceVersion,
        }

        watcher, err := client.Watch(ctx, opts)
        if err != nil {
            time.Sleep(5 * time.Second)
            continue
        }

        for event := range watcher.ResultChan() {
            if event.Type == watch.Error {
                break
            }

            activity := event.Object.(*activityv1alpha1.Activity)
            resourceVersion = activity.ResourceVersion

            // Process activity...
            handleActivity(activity)
        }

        watcher.Stop()
    }
}
```

---

## Building Activity Timeline UIs

### Fetching Activities for Display

Use ActivityQuery to fetch activities for a timeline view:

```typescript
interface ActivityQuerySpec {
  startTime: string;      // "now-7d" or RFC3339
  endTime?: string;       // defaults to "now"
  filter?: string;        // CEL expression
  namespace?: string;     // filter by namespace
  resourceKind?: string;  // filter by kind
  actorName?: string;     // filter by actor
  changeSource?: string;  // "human" or "system"
  limit?: number;         // results per page (max 1000)
  continue?: string;      // pagination cursor
}

async function fetchActivities(spec: ActivityQuerySpec): Promise<Activity[]> {
  const query = {
    apiVersion: 'activity.miloapis.com/v1alpha1',
    kind: 'ActivityQuery',
    spec: spec,
  };

  const result = await k8sClient.create(query);
  return result.status.results;
}

// Example: Fetch last 7 days of human changes
const activities = await fetchActivities({
  startTime: 'now-7d',
  changeSource: 'human',
  limit: 100,
});
```

### Building Filter Dropdowns

Use ActivityFacetQuery to populate filter options:

```typescript
interface FacetSpec {
  field: string;
  limit?: number;  // top N values
}

interface ActivityFacetQuerySpec {
  timeRange: {
    start: string;
    end?: string;
  };
  filter?: string;  // pre-filter activities
  facets: FacetSpec[];
}

async function fetchFacets(spec: ActivityFacetQuerySpec): Promise<FacetResults> {
  const query = {
    apiVersion: 'activity.miloapis.com/v1alpha1',
    kind: 'ActivityFacetQuery',
    spec: spec,
  };

  const result = await k8sClient.create(query);
  return result.status.facets;
}

// Example: Get filter options for activity timeline
const facets = await fetchFacets({
  timeRange: { start: 'now-30d' },
  facets: [
    { field: 'spec.actor.name', limit: 20 },
    { field: 'spec.resource.kind' },
    { field: 'spec.resource.namespace' },
    { field: 'spec.changeSource' },
  ],
});

// Result:
// {
//   facets: [
//     { field: 'spec.actor.name', values: [
//       { value: 'alice@example.com', count: 142 },
//       { value: 'bob@example.com', count: 89 },
//     ]},
//     { field: 'spec.resource.kind', values: [
//       { value: 'HTTPProxy', count: 231 },
//       { value: 'Instance', count: 156 },
//     ]},
//     ...
//   ]
// }
```

### Supported Facet Fields

| Field | Description |
|-------|-------------|
| `spec.actor.name` | Actor display names |
| `spec.actor.type` | user, serviceaccount, controller |
| `spec.resource.apiGroup` | API groups |
| `spec.resource.kind` | Resource kinds |
| `spec.resource.namespace` | Namespaces |
| `spec.changeSource` | human, system |

### Rendering Activity Summaries

Activity summaries contain clickable link markers:

```typescript
interface Activity {
  spec: {
    summary: string;  // "alice@example.com created HTTPProxy my-proxy"
    links: Array<{
      marker: string;  // Text to highlight: "HTTPProxy my-proxy"
      resource: {
        apiGroup: string;
        kind: string;
        name: string;
        namespace?: string;
      };
    }>;
    changeSource: 'human' | 'system';
    actor: {
      type: 'user' | 'serviceaccount' | 'controller';
      name: string;
      email?: string;
    };
    resource: {
      apiGroup: string;
      kind: string;
      name: string;
      namespace?: string;
    };
    changes?: Array<{
      field: string;
      old: string;
      new: string;
    }>;
  };
  metadata: {
    creationTimestamp: string;
  };
}

function renderActivitySummary(activity: Activity): JSX.Element {
  let summary = activity.spec.summary;
  const links = activity.spec.links || [];

  // Replace link markers with clickable elements
  const parts: (string | JSX.Element)[] = [];
  let lastIndex = 0;

  for (const link of links) {
    const markerIndex = summary.indexOf(link.marker, lastIndex);
    if (markerIndex === -1) continue;

    // Add text before marker
    if (markerIndex > lastIndex) {
      parts.push(summary.substring(lastIndex, markerIndex));
    }

    // Add clickable link
    parts.push(
      <ResourceLink
        key={link.marker}
        resource={link.resource}
        label={link.marker}
      />
    );

    lastIndex = markerIndex + link.marker.length;
  }

  // Add remaining text
  if (lastIndex < summary.length) {
    parts.push(summary.substring(lastIndex));
  }

  return <span>{parts}</span>;
}
```

### Timeline Component Pattern

```tsx
function ActivityTimeline({
  namespace,
  resourceKind,
  initialLimit = 50,
}: TimelineProps) {
  const [activities, setActivities] = useState<Activity[]>([]);
  const [filters, setFilters] = useState<Filters>({});
  const [facets, setFacets] = useState<FacetResults | null>(null);
  const [continueCursor, setContinueCursor] = useState<string | null>(null);

  // Load facets for filter dropdowns
  useEffect(() => {
    fetchFacets({
      timeRange: { start: 'now-30d' },
      facets: [
        { field: 'spec.actor.name', limit: 20 },
        { field: 'spec.resource.kind' },
        { field: 'spec.changeSource' },
      ],
    }).then(setFacets);
  }, []);

  // Load activities based on filters
  useEffect(() => {
    const filterExpr = buildFilterExpression(filters);

    fetchActivities({
      startTime: filters.startTime || 'now-7d',
      namespace,
      resourceKind,
      filter: filterExpr,
      limit: initialLimit,
    }).then((result) => {
      setActivities(result.items);
      setContinueCursor(result.continue || null);
    });
  }, [filters, namespace, resourceKind]);

  // Load more activities
  const loadMore = async () => {
    if (!continueCursor) return;

    const result = await fetchActivities({
      startTime: filters.startTime || 'now-7d',
      filter: buildFilterExpression(filters),
      limit: initialLimit,
      continue: continueCursor,
    });

    setActivities([...activities, ...result.items]);
    setContinueCursor(result.continue || null);
  };

  return (
    <div className="activity-timeline">
      <FilterBar facets={facets} filters={filters} onChange={setFilters} />

      <div className="activity-list">
        {activities.map((activity) => (
          <ActivityItem key={activity.metadata.uid} activity={activity} />
        ))}
      </div>

      {continueCursor && (
        <button onClick={loadMore}>Load More</button>
      )}
    </div>
  );
}
```

---

## Raw Audit Log Access

For compliance, debugging, or advanced use cases, query raw audit logs directly.

### AuditLogQuery

```yaml
apiVersion: activity.miloapis.com/v1alpha1
kind: AuditLogQuery
spec:
  startTime: "now-1h"
  endTime: "now"
  filter: "verb == 'delete' && objectRef.namespace == 'production'"
  limit: 100
```

### AuditLogFacetQuery

Get distinct values from raw audit logs:

```yaml
apiVersion: activity.miloapis.com/v1alpha1
kind: AuditLogFacetQuery
spec:
  timeRange:
    start: "now-7d"
  facets:
    - field: verb
    - field: user.username
      limit: 20
    - field: objectRef.resource
    - field: objectRef.namespace
    - field: responseStatus.code
```

### Supported Audit Facet Fields

| Field | Description |
|-------|-------------|
| `verb` | API verbs (create, update, delete, etc.) |
| `user.username` | User identifiers |
| `user.uid` | User UIDs |
| `objectRef.resource` | Resource types (plural) |
| `objectRef.namespace` | Target namespaces |
| `objectRef.apiGroup` | API groups |
| `responseStatus.code` | HTTP status codes |

---

## Event Facet Queries

For Kubernetes events, use EventFacetQuery:

```yaml
apiVersion: activity.miloapis.com/v1alpha1
kind: EventFacetQuery
spec:
  timeRange:
    start: "now-7d"
  facets:
    - field: involvedObject.kind
    - field: involvedObject.namespace
    - field: reason
    - field: type
    - field: source.component
```

### Supported Event Facet Fields

| Field | Description |
|-------|-------------|
| `involvedObject.kind` | Resource kinds |
| `involvedObject.namespace` | Namespaces |
| `reason` | Event reason codes (Ready, Failed, etc.) |
| `type` | Normal or Warning |
| `source.component` | Source controller |
| `namespace` | Event namespace |

---

## CEL Filter Expression Reference

### Activity Filter Fields

```cel
# By change source
spec.changeSource == 'human'
spec.changeSource == 'system'

# By actor
spec.actor.name == 'alice@example.com'
spec.actor.type == 'user'
spec.actor.type == 'serviceaccount'
!spec.actor.name.startsWith('system:')

# By resource
spec.resource.kind == 'HTTPProxy'
spec.resource.kind in ['Deployment', 'StatefulSet']
spec.resource.namespace == 'production'
spec.resource.apiGroup == 'otherservice.miloapis.com'

# By summary content
spec.summary.contains('created')
spec.summary.contains('deleted')
spec.summary.contains('failed')

# By origin
spec.origin.type == 'audit'
spec.origin.type == 'event'

# Combined filters
spec.actor.type == 'user' && spec.resource.namespace == 'production'
spec.changeSource == 'human' && spec.summary.contains('deleted')
```

### Audit Log Filter Fields

```cel
# By verb
verb == 'create'
verb == 'delete'
verb in ['update', 'patch']

# By user
user.username == 'alice@example.com'
user.username.startsWith('system:serviceaccount:')
!user.username.startsWith('system:')

# By resource
objectRef.resource == 'httpproxies'
objectRef.namespace == 'production'
objectRef.apiGroup == 'otherservice.miloapis.com'
objectRef.subresource == 'status'
objectRef.subresource == ''  # main resource only

# By response
responseStatus.code >= 400  # errors only
responseStatus.code == 201  # created
responseStatus.code == 200  # success
```

### Common Operators

| Operator | Description | Example |
|----------|-------------|---------|
| `==` | Equals | `spec.actor.name == 'alice'` |
| `!=` | Not equals | `spec.changeSource != 'system'` |
| `in` | In list | `verb in ['create', 'delete']` |
| `&&` | And | `a == 'x' && b == 'y'` |
| `\|\|` | Or | `a == 'x' \|\| a == 'y'` |
| `!` | Not | `!spec.actor.name.startsWith('system:')` |
| `.startsWith()` | String prefix | `user.username.startsWith('alice')` |
| `.endsWith()` | String suffix | `user.username.endsWith('@example.com')` |
| `.contains()` | String contains | `spec.summary.contains('deleted')` |

---

## Integration Patterns

### Pattern 1: Resource-Specific Activity Panel

Show activity for a specific resource in its detail view:

```typescript
function ResourceActivityPanel({ resource }: { resource: K8sResource }) {
  const { namespace, name, kind, apiGroup } = resource.metadata;

  return (
    <ActivityTimeline
      filter={`
        spec.resource.namespace == '${namespace}' &&
        spec.resource.name == '${name}' &&
        spec.resource.kind == '${kind}'
      `}
      startTime="now-30d"
      limit={20}
    />
  );
}
```

### Pattern 2: Project-Wide Activity Feed

Show all activity within a project:

```typescript
function ProjectActivityFeed({ projectNamespace }: Props) {
  return (
    <ActivityTimeline
      namespace={projectNamespace}
      startTime="now-7d"
      filters={{
        changeSource: 'human',  // Focus on human actions
      }}
    />
  );
}
```

### Pattern 3: Security Audit Dashboard

Monitor sensitive operations:

```typescript
const SECURITY_FILTER = `
  spec.resource.kind in ['Secret', 'Role', 'RoleBinding', 'PolicyBinding'] ||
  spec.summary.contains('deleted') ||
  spec.summary.contains('permission')
`;

function SecurityAuditDashboard() {
  return (
    <ActivityTimeline
      filter={SECURITY_FILTER}
      startTime="now-30d"
      changeSource="human"
    />
  );
}
```

### Pattern 4: Real-time Notifications

Send alerts for specific activity patterns:

```go
func WatchForDeletions(ctx context.Context, client activityv1alpha1.ActivityInterface, notify func(Activity)) {
    watcher, _ := client.Watch(ctx, metav1.ListOptions{
        FieldSelector: "spec.changeSource=human",
    })

    for event := range watcher.ResultChan() {
        if event.Type != watch.Added {
            continue
        }

        activity := event.Object.(*activityv1alpha1.Activity)

        // Alert on deletions in production
        if strings.Contains(activity.Spec.Summary, "deleted") &&
           activity.Spec.Resource.Namespace == "production" {
            notify(activity)
        }
    }
}
```

---

## Multi-Tenancy Considerations

Activities are automatically scoped to the user's tenant context:

| Tenant Type | What User Sees |
|-------------|----------------|
| Platform | All activities across all tenants |
| Organization | Activities within their organization |
| Project | Activities within their project |
| User | Activities they performed |

No additional filtering is needed—the API server enforces tenant isolation automatically based on the authenticated user's context.

---

## Best Practices

### For CLI Tools

1. **Default to human changes** — Most users want to see what humans did, not controller reconciliation
2. **Use relative time** — `now-7d` is more intuitive than absolute timestamps
3. **Provide output formats** — Support JSON for scripting, table for humans
4. **Page by default** — Don't overwhelm with thousands of results

### For UIs

1. **Load facets upfront** — Populate filter dropdowns before user interaction
2. **Stream real-time updates** — Use watch API for live dashboards
3. **Render links** — Make resource references clickable
4. **Show actor context** — Display whether change was human or system
5. **Support infinite scroll** — Use continuation tokens for pagination

### For Backend Services

1. **Use specific filters** — Narrow queries with namespace, kind, and time range
2. **Handle pagination** — Don't assume all results fit in one response
3. **Reconnect watchers** — Handle watch disconnections gracefully
4. **Cache facets** — Facet queries can be expensive; cache results

---

## Troubleshooting

### No Activities Showing

1. **Check time range** — Default is 24 hours; expand if needed
2. **Verify tenant context** — User must have access to the resources
3. **Check ActivityPolicy exists** — Resources need policies to generate activities
4. **Query raw audit logs** — Use AuditLogQuery to see if logs are flowing

### Stale Watch Results

1. **Check resourceVersion** — Resume from last known version
2. **Reconnect with backoff** — Handle connection drops gracefully
3. **Use informers** — For Go, use the generated informers for reliable caching

### Slow Queries

1. **Add time bounds** — Always specify startTime
2. **Use specific filters** — Filter by namespace, kind, or actor
3. **Limit results** — Use pagination with reasonable limits
4. **Pre-filter with facets** — Use facet queries to build efficient filters
