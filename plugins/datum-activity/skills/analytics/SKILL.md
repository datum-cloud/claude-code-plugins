---
name: analytics
description: Analyze platform activity patterns over time. Use for trend analysis, anomaly detection, compliance reporting, and capacity planning.
---

# Skill: Activity Analytics

This skill helps you analyze platform activity patterns, detect anomalies, and generate reports using the Activity MCP server.

## When to Use

- **Trend analysis**: "How has deployment frequency changed?"
- **Anomaly detection**: "Is activity higher than normal?"
- **Compliance reporting**: "Generate monthly access report"
- **Capacity planning**: "What's our API usage pattern?"

## Available Tools

### Analytics Tools

| Tool | Purpose |
|------|---------|
| `get_activity_timeline` | Activity counts by time bucket |
| `summarize_recent_activity` | High-level activity summary |
| `compare_activity_periods` | Compare two time periods |

### Query Tools (for drill-down)

| Tool | Purpose |
|------|---------|
| `query_audit_logs` | Detailed audit log search |
| `query_activities` | Human-readable activity search |
| `get_audit_log_facets` | Aggregate by user/resource/verb |
| `get_activity_facets` | Aggregate by actor/kind/namespace |

## Common Patterns

### Activity Over Time

```
Tool: get_activity_timeline
Args:
  startTime: "now-7d"
  endTime: "now"
  bucketSize: "1h"           # Options: 5m, 15m, 1h, 6h, 1d
  filter: "spec.changeSource == 'human'"
```

Returns:
```json
{
  "buckets": [
    {"time": "2024-01-15T10:00:00Z", "count": 42},
    {"time": "2024-01-15T11:00:00Z", "count": 67},
    ...
  ]
}
```

### Compare Periods

```
Tool: compare_activity_periods
Args:
  period1Start: "now-14d"
  period1End: "now-7d"
  period2Start: "now-7d"
  period2End: "now"
```

Returns:
```json
{
  "period1": {"totalCount": 1234, "uniqueActors": 15},
  "period2": {"totalCount": 1567, "uniqueActors": 18},
  "change": {
    "countPercent": 27.0,
    "actorsPercent": 20.0
  }
}
```

### Activity Summary

```
Tool: summarize_recent_activity
Args:
  startTime: "now-24h"
  namespace: "production"
```

Returns:
```json
{
  "totalActivities": 234,
  "humanActivities": 45,
  "systemActivities": 189,
  "topActors": [
    {"name": "alice@example.com", "count": 23},
    {"name": "bob@example.com", "count": 15}
  ],
  "topResources": [
    {"kind": "Deployment", "count": 67},
    {"kind": "ConfigMap", "count": 45}
  ],
  "failedOperations": 3
}
```

### Top Users

```
Tool: get_audit_log_facets
Args:
  startTime: "now-30d"
  fields: ["user.username"]
  filter: "verb in ['create', 'update', 'delete']"
  limit: 10
```

### Top Resources Changed

```
Tool: get_activity_facets
Args:
  startTime: "now-7d"
  fields: ["spec.resource.kind", "spec.resource.namespace"]
  filter: "spec.changeSource == 'human'"
```

## Report Templates

### Weekly Activity Report

```markdown
# Weekly Activity Report
Period: {{period1Start}} to {{period2End}}

## Summary
- Total activities: {{totalCount}}
- Human changes: {{humanCount}} ({{humanPercent}}%)
- System changes: {{systemCount}}
- Failed operations: {{failedCount}}

## Compared to Previous Week
- Activity: {{changePercent > 0 ? '+' : ''}}{{changePercent}}%
- Unique users: {{usersChange}}

## Top Contributors
| User | Changes |
|------|---------|
{{#topActors}}
| {{name}} | {{count}} |
{{/topActors}}

## Most Changed Resources
| Resource | Kind | Changes |
|----------|------|---------|
{{#topResources}}
| {{name}} | {{kind}} | {{count}} |
{{/topResources}}
```

### Compliance Access Report

```markdown
# Sensitive Resource Access Report
Period: {{startTime}} to {{endTime}}

## Secret Access
{{#secretAccess}}
| Time | User | Namespace | Secret | Action |
|------|------|-----------|--------|--------|
{{#events}}
| {{time}} | {{user}} | {{namespace}} | {{name}} | {{verb}} |
{{/events}}
{{/secretAccess}}

## Privileged Operations
{{#privilegedOps}}
| Time | User | Resource | Action |
|------|------|----------|--------|
{{#events}}
| {{time}} | {{user}} | {{resource}} | {{verb}} |
{{/events}}
{{/privilegedOps}}
```

## Analysis Workflows

### Detect Unusual Activity

1. **Get baseline**:
   ```
   get_activity_timeline
     startTime: "now-30d"
     endTime: "now-7d"
     bucketSize: "1d"
   ```

2. **Compare to recent**:
   ```
   compare_activity_periods
     period1Start: "now-14d"
     period1End: "now-7d"
     period2Start: "now-7d"
     period2End: "now"
   ```

3. **Investigate spikes**:
   ```
   query_audit_logs
     startTime: "<spike_time>"
     endTime: "<spike_time + 1h>"
   ```

### Audit User Activity

1. **Get summary**:
   ```
   get_user_activity_summary
     username: "alice@example.com"
     startTime: "now-30d"
   ```

2. **Get details**:
   ```
   query_audit_logs
     filter: "user.username == 'alice@example.com'"
     startTime: "now-30d"
   ```

3. **Check sensitive access**:
   ```
   query_audit_logs
     filter: "user.username == 'alice@example.com' && objectRef.resource == 'secrets'"
   ```

### Capacity Analysis

1. **API usage over time**:
   ```
   get_activity_timeline
     startTime: "now-30d"
     bucketSize: "1d"
   ```

2. **Breakdown by resource**:
   ```
   get_audit_log_facets
     fields: ["objectRef.resource", "verb"]
     startTime: "now-30d"
   ```

3. **Peak hours**:
   ```
   get_activity_timeline
     startTime: "now-7d"
     bucketSize: "1h"
   ```

## Output Formatting

### Time Series (for charts)
```json
{
  "labels": ["Mon", "Tue", "Wed", "Thu", "Fri"],
  "datasets": [
    {"label": "Human", "data": [45, 67, 52, 71, 48]},
    {"label": "System", "data": [120, 145, 132, 156, 128]}
  ]
}
```

### Aggregates (for dashboards)
```json
{
  "totalActivities": 1234,
  "uniqueActors": 23,
  "topResource": "Deployment",
  "peakHour": "14:00",
  "failureRate": "2.3%"
}
```

### Tables (for reports)
```markdown
| Metric | This Week | Last Week | Change |
|--------|-----------|-----------|--------|
| Total Changes | 1,234 | 1,067 | +16% |
| Human Changes | 234 | 198 | +18% |
| Failed Ops | 12 | 8 | +50% |
```
