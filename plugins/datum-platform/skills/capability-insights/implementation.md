# Insights Implementation Guide

This guide covers how to create effective InsightPolicy resources for your service.

## Designing Effective Insight Rules

### What Makes a Good Rule

| Characteristic | Good | Bad |
|----------------|------|-----|
| **Actionable** | "Set fieldB to 'compatible' to resolve" | "Something is wrong" |
| **Specific** | "MyResource my-app has invalid config" | "Some resources have issues" |
| **Low false-positive** | Threshold chosen carefully | Alerts on normal behavior |
| **Clear severity** | Critical for failures, info for optimization | Everything is critical |

### Rule Categories

**Configuration Issues**
- Invalid field combinations
- Deprecated settings
- Missing required fields
- Security misconfigurations

**Health Issues**
- Failing status conditions
- Prolonged not-ready state
- High error rates

**Optimization Opportunities**
- Underutilization
- Cost savings
- Performance improvements

**Compliance Concerns**
- Policy violations
- Expiring certificates
- Outdated versions

---

## Creating an InsightPolicy

### Step 1: Identify Detection Opportunities

For each resource type your service manages, ask:

1. What misconfigurations are common? (Check support tickets)
2. What status conditions indicate problems?
3. What security issues can be detected?
4. What optimization opportunities exist?

### Step 2: Write the Policy

Create a file in `config/insights/`:

```yaml
# config/insights/myresource-policies.yaml
apiVersion: insights.miloapis.com/v1alpha1
kind: InsightPolicy
metadata:
  name: myservice-myresource
  namespace: myservice-system
spec:
  targetSelector:
    apiVersion: myservice.miloapis.com/v1alpha1
    kind: MyResource
  rules:
    # Configuration validation
    - name: invalid-config
      condition: "object.spec.fieldA == '' || object.spec.fieldB < 0"
      severity: critical
      category: configuration
      message: "{{ object.kind }} {{ object.metadata.name }} has invalid configuration"
      description: |
        The resource has invalid configuration:
        {{ object.spec.fieldA == '' ? '- fieldA is empty' : '' }}
        {{ object.spec.fieldB < 0 ? '- fieldB must be non-negative' : '' }}

    # Health check
    - name: not-ready-prolonged
      condition: |
        has(object.status.conditions) &&
        object.status.conditions.exists(c,
          c.type == 'Ready' &&
          c.status == 'False' &&
          timestamp(c.lastTransitionTime) < now() - duration('15m')
        )
      severity: warning
      category: health
      message: "{{ object.kind }} {{ object.metadata.name }} has been not ready for over 15 minutes"
      description: "Check the resource status conditions and logs for more details."

    # Optimization
    - name: oversized
      condition: |
        has(object.status.metrics) &&
        object.status.metrics.cpuUtilization < 10 &&
        object.status.metrics.memoryUtilization < 10
      severity: info
      category: optimization
      message: "{{ object.kind }} {{ object.metadata.name }} appears oversized"
      description: "CPU and memory utilization are both under 10%. Consider reducing resource allocation."
      ttlSeconds: 604800  # 7 days - re-evaluate weekly
```

### Step 3: Add to Kustomization

```yaml
# config/insights/kustomization.yaml
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization
resources:
  - myresource-policies.yaml
```

Include in your base:

```yaml
# config/base/kustomization.yaml
resources:
  - deployment.yaml
  - service.yaml

components:
  - ../insights
```

---

## CEL Expression Patterns

### Basic Field Checks

```yaml
# Field is empty
condition: "object.spec.field == ''"

# Field is missing
condition: "!has(object.spec.field)"

# Field has specific value
condition: "object.spec.field == 'badValue'"

# Numeric comparison
condition: "object.spec.replicas < 1"
```

### Optional Fields

```yaml
# Check if field exists before comparing
condition: "has(object.spec.optional) && object.spec.optional == 'bad'"

# Default value pattern
condition: "(has(object.spec.optional) ? object.spec.optional : 'default') == 'bad'"
```

### List Operations

```yaml
# Any item matches
condition: "object.spec.items.exists(item, item.enabled == false)"

# All items match
condition: "object.spec.items.all(item, item.valid == true)"

# Count matching items
condition: "object.spec.items.filter(item, item.status == 'failed').size() > 3"

# No items exist
condition: "!has(object.spec.items) || object.spec.items.size() == 0"
```

### Status Conditions

```yaml
# Check specific condition
condition: |
  object.status.conditions.exists(c,
    c.type == 'Ready' && c.status == 'False'
  )

# Condition with time check
condition: |
  object.status.conditions.exists(c,
    c.type == 'Ready' &&
    c.status == 'False' &&
    timestamp(c.lastTransitionTime) < now() - duration('10m')
  )

# Multiple condition check
condition: |
  object.status.conditions.exists(c, c.type == 'Ready' && c.status == 'False') &&
  object.status.conditions.exists(c, c.type == 'Progressing' && c.status == 'False')
```

### Labels and Annotations

```yaml
# Check label exists
condition: "has(object.metadata.labels) && 'environment' in object.metadata.labels"

# Check label value
condition: |
  has(object.metadata.labels) &&
  'environment' in object.metadata.labels &&
  object.metadata.labels['environment'] == 'production'

# Missing required label
condition: "!has(object.metadata.labels) || !('team' in object.metadata.labels)"
```

### String Operations

```yaml
# Contains
condition: "object.spec.name.contains('deprecated')"

# Starts/ends with
condition: "object.spec.image.startsWith('internal-registry.example.com/')"

# Regex match (if supported)
condition: "object.spec.version.matches('^v[0-9]+\\.[0-9]+\\.[0-9]+$')"
```

---

## Message Templates

### Basic Templates

```yaml
message: "{{ object.kind }} {{ object.metadata.name }} has an issue"
```

### Conditional Text

```yaml
message: |
  {{ object.kind }} {{ object.metadata.name }} {{
    object.spec.replicas < 1 ? 'has no replicas' : 'has too few replicas'
  }}
```

### Including Field Values

```yaml
description: |
  Current configuration:
  - fieldA: {{ object.spec.fieldA }}
  - fieldB: {{ object.spec.fieldB }}

  Expected: fieldA and fieldB should be compatible.
```

---

## Testing Policies

### Apply to Test Cluster

```bash
# Apply the policy
kubectl apply -f config/insights/myresource-policies.yaml

# Create a resource that should trigger an insight
kubectl apply -f test/fixtures/bad-config.yaml

# Check if insight was created
kubectl get insights -n test-namespace

# Describe the insight
kubectl describe insight <insight-name> -n test-namespace
```

### Verify Policy Status

```bash
# Check policy is active
kubectl get insightpolicies -n myservice-system

# Check for evaluation errors
kubectl describe insightpolicy myservice-myresource -n myservice-system
```

### Test Mute Rules

```bash
# Create a mute rule
kubectl apply -f - <<EOF
apiVersion: insights.miloapis.com/v1alpha1
kind: InsightMuteRule
metadata:
  name: test-mute
  namespace: test-namespace
spec:
  match:
    category: configuration
  reason: "Testing mute functionality"
EOF

# Verify insight is muted
kubectl get insights -n test-namespace
```

---

## Deployment Checklist

Before deploying InsightPolicy resources:

- [ ] Policies are in `config/insights/` directory
- [ ] Kustomization includes the insights directory
- [ ] CEL expressions are syntactically valid
- [ ] Messages are clear and actionable
- [ ] Severity levels are appropriate
- [ ] Categories are consistent with platform conventions
- [ ] TTL is set appropriately for time-sensitive checks
- [ ] Policies are tested against sample resources

---

## Validation Script

Run `scripts/validate-insights.sh` to check:

```bash
#!/bin/bash
# Validate insights policy configuration
set -e

echo "=== Insights Policy Validation ==="

ERRORS=0

# Check for policy files
echo "Checking for InsightPolicy files..."
POLICY_FILES=$(find config/insights -name "*.yaml" -exec grep -l "kind: InsightPolicy" {} \; 2>/dev/null | wc -l || echo "0")
if [ "$POLICY_FILES" -eq 0 ]; then
    echo "WARNING: No InsightPolicy files found in config/insights/"
    echo "  Consider adding policies to detect issues proactively"
else
    echo "✓ Found $POLICY_FILES InsightPolicy file(s)"
fi

# Validate YAML syntax
echo "Validating YAML syntax..."
for file in config/insights/*.yaml; do
    if [ -f "$file" ]; then
        if ! kubectl apply --dry-run=client -f "$file" > /dev/null 2>&1; then
            echo "ERROR: Invalid YAML in $file"
            ERRORS=$((ERRORS + 1))
        fi
    fi
done

# Check kustomization includes insights
echo "Checking kustomization..."
if ! grep -q "insights" config/base/kustomization.yaml 2>/dev/null; then
    echo "WARNING: config/base/kustomization.yaml may not include insights"
fi

echo ""
if [ "$ERRORS" -gt 0 ]; then
    echo "FAILED: $ERRORS error(s) found"
    exit 1
else
    echo "PASSED: Insights validation complete"
fi
```

---

## Common Mistakes

### Overly Broad Conditions

**Bad**: Matches too many resources
```yaml
condition: "has(object.status)"  # Almost everything has status
```

**Good**: Specific condition
```yaml
condition: |
  has(object.status.conditions) &&
  object.status.conditions.exists(c, c.type == 'Ready' && c.status == 'False')
```

### Missing Field Guards

**Bad**: Assumes field exists
```yaml
condition: "object.spec.optional.nested == 'bad'"  # Errors if optional is missing
```

**Good**: Check existence first
```yaml
condition: |
  has(object.spec.optional) &&
  has(object.spec.optional.nested) &&
  object.spec.optional.nested == 'bad'
```

### Unclear Messages

**Bad**: Vague message
```yaml
message: "Resource has a problem"
```

**Good**: Specific and actionable
```yaml
message: "{{ object.kind }} {{ object.metadata.name }} has fieldA='{{ object.spec.fieldA }}' which conflicts with fieldB"
description: "Set fieldA to 'compatible' or change fieldB to resolve this conflict."
```

### Wrong Severity

**Bad**: Everything is critical
```yaml
severity: critical  # For an optimization suggestion
```

**Good**: Appropriate severity
```yaml
severity: info  # For optimization suggestions
severity: warning  # For things that should be fixed
severity: critical  # Only for actual failures or security issues
```
