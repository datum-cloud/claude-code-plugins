#!/bin/bash
# Scaffold quota integration for a resource
# Usage: scaffold-quota.sh <resource-name> <api-group>

set -e

RESOURCE_NAME=$1
API_GROUP=$2

if [ -z "$RESOURCE_NAME" ] || [ -z "$API_GROUP" ]; then
    echo "Usage: scaffold-quota.sh <resource-name> <api-group>"
    echo "Example: scaffold-quota.sh Widget myservice.miloapis.com"
    exit 1
fi

RESOURCE_LOWER=$(echo "$RESOURCE_NAME" | tr '[:upper:]' '[:lower:]')
RESOURCE_PLURAL="${RESOURCE_LOWER}s"

echo "Scaffolding quota integration for $RESOURCE_NAME ($API_GROUP)..."

# Create quota manifests directory
mkdir -p config/quota

# Create ResourceRegistration
cat > "config/quota/${RESOURCE_LOWER}-registration.yaml" << EOF
# ResourceRegistration for $RESOURCE_NAME quota
apiVersion: quota.miloapis.com/v1alpha1
kind: ResourceRegistration
metadata:
  name: ${RESOURCE_LOWER}-quota
spec:
  # Unique identifier for this resource type
  resourceType: "${API_GROUP}/${RESOURCE_PLURAL}"

  # Which resource type receives grants (typically Organization)
  consumerType:
    apiGroup: resourcemanager.miloapis.com
    kind: Organization

  # Entity for countable instances, Allocation for capacity amounts
  type: Entity

  # Units for tracking and display
  baseUnit: "count"
  displayUnit: "${RESOURCE_PLURAL}"
  unitConversionFactor: 1

  # Which resource types can create claims
  claimingResources:
    - apiGroup: ${API_GROUP}
      kind: ${RESOURCE_NAME}
EOF

echo "Created config/quota/${RESOURCE_LOWER}-registration.yaml"

# Create ClaimCreationPolicy
cat > "config/quota/${RESOURCE_LOWER}-claim-policy.yaml" << EOF
# ClaimCreationPolicy enforces quota when ${RESOURCE_NAME} resources are created
apiVersion: quota.miloapis.com/v1alpha1
kind: ClaimCreationPolicy
metadata:
  name: ${RESOURCE_LOWER}-quota-enforcement
spec:
  trigger:
    resource:
      apiVersion: ${API_GROUP}/v1alpha1
      kind: ${RESOURCE_NAME}
    # Optional: add constraints to skip quota for certain resources
    # constraints:
    #   - expression: "!trigger.metadata.labels.exists(k, k == 'quota-exempt')"
    #     message: "Skip quota-exempt resources"

  target:
    resourceClaimTemplate:
      metadata:
        generateName: "${RESOURCE_LOWER}-claim-"
        namespace: "quota-system"
      spec:
        # consumerRef is auto-resolved from the trigger resource's organization context
        requests:
          - resourceType: "${API_GROUP}/${RESOURCE_PLURAL}"
            amount: 1
EOF

echo "Created config/quota/${RESOURCE_LOWER}-claim-policy.yaml"

# Create GrantCreationPolicy for each tier
cat > "config/quota/${RESOURCE_LOWER}-grant-policies.yaml" << EOF
# GrantCreationPolicies allocate ${RESOURCE_NAME} quota when Organizations are created

---
# Free tier: Enough for meaningful evaluation
apiVersion: quota.miloapis.com/v1alpha1
kind: GrantCreationPolicy
metadata:
  name: ${RESOURCE_LOWER}-quota-free
spec:
  trigger:
    resource:
      apiVersion: resourcemanager.miloapis.com/v1alpha1
      kind: Organization
    constraints:
      - expression: "trigger.spec.tier == 'free' || !has(trigger.spec.tier)"
        message: "Free tier or no tier specified"

  target:
    resourceGrantTemplate:
      metadata:
        name: "{{trigger.metadata.name}}-${RESOURCE_LOWER}-quota"
        namespace: "quota-system"
      spec:
        consumerRef:
          apiGroup: resourcemanager.miloapis.com
          kind: Organization
          name: "{{trigger.metadata.name}}"
        allowances:
          - resourceType: "${API_GROUP}/${RESOURCE_PLURAL}"
            buckets:
              - amount: 5  # TODO: Adjust based on service requirements

---
# Pro tier: Enough for typical production workloads
apiVersion: quota.miloapis.com/v1alpha1
kind: GrantCreationPolicy
metadata:
  name: ${RESOURCE_LOWER}-quota-pro
spec:
  trigger:
    resource:
      apiVersion: resourcemanager.miloapis.com/v1alpha1
      kind: Organization
    constraints:
      - expression: "trigger.spec.tier == 'pro'"
        message: "Pro tier organizations"

  target:
    resourceGrantTemplate:
      metadata:
        name: "{{trigger.metadata.name}}-${RESOURCE_LOWER}-quota"
        namespace: "quota-system"
      spec:
        consumerRef:
          apiGroup: resourcemanager.miloapis.com
          kind: Organization
          name: "{{trigger.metadata.name}}"
        allowances:
          - resourceType: "${API_GROUP}/${RESOURCE_PLURAL}"
            buckets:
              - amount: 100  # TODO: Adjust based on service requirements

---
# Enterprise tier: Enough for large scale
apiVersion: quota.miloapis.com/v1alpha1
kind: GrantCreationPolicy
metadata:
  name: ${RESOURCE_LOWER}-quota-enterprise
spec:
  trigger:
    resource:
      apiVersion: resourcemanager.miloapis.com/v1alpha1
      kind: Organization
    constraints:
      - expression: "trigger.spec.tier == 'enterprise'"
        message: "Enterprise tier organizations"

  target:
    resourceGrantTemplate:
      metadata:
        name: "{{trigger.metadata.name}}-${RESOURCE_LOWER}-quota"
        namespace: "quota-system"
      spec:
        consumerRef:
          apiGroup: resourcemanager.miloapis.com
          kind: Organization
          name: "{{trigger.metadata.name}}"
        allowances:
          - resourceType: "${API_GROUP}/${RESOURCE_PLURAL}"
            buckets:
              - amount: 1000  # TODO: Adjust based on service requirements
EOF

echo "Created config/quota/${RESOURCE_LOWER}-grant-policies.yaml"

# Create tier defaults documentation
cat > "config/quota/${RESOURCE_LOWER}-defaults.md" << EOF
# ${RESOURCE_NAME} Quota Defaults

## Tier Allocations

| Resource Type | Free | Pro | Enterprise |
|---------------|------|-----|------------|
| \`${API_GROUP}/${RESOURCE_PLURAL}\` | 5 | 100 | 1000 |

## Design Rationale

- **Free**: Enough for meaningful evaluation (TODO: verify this is sufficient for demos)
- **Pro**: Covers typical production workloads (TODO: analyze actual usage patterns)
- **Enterprise**: Generous limits for large scale (TODO: confirm with commercial team)

## Tier Design Principles

Quotas should feel generous. Users hitting limits should feel "I'm growing" not "I'm being restricted."

## Quota Increase Process

1. Consumer requests increase via support or self-service
2. Commercial review (for paid tiers, if needed)
3. New ResourceGrant created or existing grant updated
4. Consumer notified of increased quota
EOF

echo "Created config/quota/${RESOURCE_LOWER}-defaults.md"

echo ""
echo "=== Scaffolding Complete ==="
echo ""
echo "Generated files:"
echo "  - config/quota/${RESOURCE_LOWER}-registration.yaml  (ResourceRegistration)"
echo "  - config/quota/${RESOURCE_LOWER}-claim-policy.yaml  (ClaimCreationPolicy)"
echo "  - config/quota/${RESOURCE_LOWER}-grant-policies.yaml (GrantCreationPolicies per tier)"
echo "  - config/quota/${RESOURCE_LOWER}-defaults.md        (Tier defaults documentation)"
echo ""
echo "Next steps:"
echo "1. Review and adjust tier default amounts in grant policies"
echo "2. Review the claim policy - add constraints if some resources should skip quota"
echo "3. If tracking capacity (not count), update registration type to Allocation"
echo "4. Add quota tests to verify enforcement"
echo "5. Run validate-quota.sh to check completeness"
echo "6. Get commercial team approval on tier defaults"
