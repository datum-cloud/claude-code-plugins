# /investigate Command

Investigate platform activity to understand who did what, when, and why.

## Usage

```
/investigate <query>
```

## Examples

```bash
# Find who deleted something
/investigate who deleted the api-gateway deployment

# Find what changed recently
/investigate what changed in production in the last hour

# Find user activity
/investigate what has alice@example.com been doing

# Find failed operations
/investigate failed operations in the last 24 hours

# Find secret access
/investigate who accessed secrets in production
```

## Behavior

When invoked, this command:

1. **Parses the query** to understand:
   - Time range (default: last 24 hours)
   - Target resource/user/namespace
   - Type of investigation (deletion, changes, access, failures)

2. **Uses appropriate tools**:
   - `query_audit_logs` for specific searches
   - `find_failed_operations` for failure investigation
   - `get_resource_history` for resource-specific queries
   - `get_user_activity_summary` for user investigations

3. **Presents results** with:
   - Direct answer to the question
   - Timeline of relevant events
   - Actor information
   - Suggested follow-up queries

## Query Patterns

### Deletion Investigation
"who deleted X" → Search for delete verb on resource

### Change Investigation
"what changed in X" → Search activities by namespace/resource

### User Investigation
"what has X been doing" → Get user activity summary

### Failure Investigation
"failed operations" → Use find_failed_operations tool

### Access Investigation
"who accessed X" → Search audit logs for resource access

## Output Format

```markdown
## Investigation: {query}

### Summary
{direct answer to the question}

### Timeline
| Time | Actor | Action | Resource |
|------|-------|--------|----------|
| ... | ... | ... | ... |

### Key Findings
- {finding 1}
- {finding 2}

### Suggested Next Steps
- {suggestion 1}
- {suggestion 2}
```

## Prerequisites

The Activity MCP server must be configured and accessible.
