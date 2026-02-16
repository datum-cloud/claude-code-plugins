#!/bin/bash
# Scaffold ActivityPolicy for a resource type
# Usage: scaffold-activity.sh <api-group> <kind>
# Example: scaffold-activity.sh myservice.miloapis.com MyResource

set -e

API_GROUP=$1
KIND=$2
KIND_LOWER=$(echo "$KIND" | tr '[:upper:]' '[:lower:]')
SERVICE_NAME=$(echo "$API_GROUP" | cut -d. -f1)

if [ -z "$API_GROUP" ] || [ -z "$KIND" ]; then
    echo "Usage: scaffold-activity.sh <api-group> <kind>"
    echo "Example: scaffold-activity.sh myservice.miloapis.com MyResource"
    exit 1
fi

echo "Scaffolding ActivityPolicy for $KIND ($API_GROUP)..."

# Create policies directory if needed
mkdir -p config/apiserver/policies

# Create the ActivityPolicy
cat > "config/apiserver/policies/${KIND_LOWER}-activity.yaml" << EOF
apiVersion: activity.miloapis.com/v1alpha1
kind: ActivityPolicy
metadata:
  name: ${SERVICE_NAME}-${KIND_LOWER}
spec:
  resource:
    apiGroup: ${API_GROUP}
    kind: ${KIND}

  auditRules:
    # Resource creation
    - match: "audit.verb == 'create'"
      summary: "{{ actor }} created {{ link(kind + ' ' + audit.objectRef.name, audit.responseObject) }}"

    # Resource deletion
    - match: "audit.verb == 'delete'"
      summary: "{{ actor }} deleted {{ kind }} {{ audit.objectRef.name }}"

    # Resource update (excluding status-only updates)
    - match: "audit.verb in ['update', 'patch'] && audit.objectRef.subresource == ''"
      summary: "{{ actor }} updated {{ link(kind + ' ' + audit.objectRef.name, audit.objectRef) }}"

    # Uncomment to track status changes
    # - match: "audit.objectRef.subresource == 'status'"
    #   summary: "{{ link(kind + ' ' + audit.objectRef.name, audit.objectRef) }} status changed"

  eventRules:
    # Ready state transition
    - match: "event.reason == 'Ready'"
      summary: "{{ link(kind + ' ' + event.regarding.name, event.regarding) }} is now ready"

    # Failed state
    - match: "event.reason == 'Failed'"
      summary: "{{ link(kind + ' ' + event.regarding.name, event.regarding) }} failed: {{ event.message }}"

    # Uncomment for warning events
    # - match: "event.type == 'Warning'"
    #   summary: "Warning for {{ link(kind + ' ' + event.regarding.name, event.regarding) }}: {{ event.message }}"
EOF

echo "Created config/apiserver/policies/${KIND_LOWER}-activity.yaml"

# Create test preview file
cat > "config/apiserver/policies/${KIND_LOWER}-activity-preview.yaml" << EOF
# Test file for validating the ActivityPolicy
# Apply with: kubectl apply -f ${KIND_LOWER}-activity-preview.yaml
# Check results: kubectl get policypreview test-${KIND_LOWER}-policy -o yaml
apiVersion: activity.miloapis.com/v1alpha1
kind: PolicyPreview
metadata:
  name: test-${KIND_LOWER}-policy
spec:
  policy:
    resource:
      apiGroup: ${API_GROUP}
      kind: ${KIND}
    auditRules:
      - match: "audit.verb == 'create'"
        summary: "{{ actor }} created {{ link(kind + ' ' + audit.objectRef.name, audit.responseObject) }}"
      - match: "audit.verb == 'delete'"
        summary: "{{ actor }} deleted {{ kind }} {{ audit.objectRef.name }}"
      - match: "audit.verb in ['update', 'patch'] && audit.objectRef.subresource == ''"
        summary: "{{ actor }} updated {{ link(kind + ' ' + audit.objectRef.name, audit.objectRef) }}"

  inputs:
    # Test create
    - type: audit
      audit:
        verb: create
        objectRef:
          apiGroup: ${API_GROUP}
          resource: ${KIND_LOWER}s
          name: test-resource
          namespace: test-project
        user:
          username: alice@example.com
        responseObject:
          apiVersion: ${API_GROUP}/v1alpha1
          kind: ${KIND}
          metadata:
            name: test-resource
            namespace: test-project

    # Test update
    - type: audit
      audit:
        verb: update
        objectRef:
          apiGroup: ${API_GROUP}
          resource: ${KIND_LOWER}s
          name: test-resource
          namespace: test-project
          subresource: ""
        user:
          username: bob@example.com

    # Test delete
    - type: audit
      audit:
        verb: delete
        objectRef:
          apiGroup: ${API_GROUP}
          resource: ${KIND_LOWER}s
          name: test-resource
          namespace: test-project
        user:
          username: carol@example.com
EOF

echo "Created config/apiserver/policies/${KIND_LOWER}-activity-preview.yaml"

# Check if kustomization.yaml exists, add resource if not present
KUSTOMIZATION="config/apiserver/policies/kustomization.yaml"
if [ ! -f "$KUSTOMIZATION" ]; then
    cat > "$KUSTOMIZATION" << EOF
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization

resources:
  - ${KIND_LOWER}-activity.yaml
EOF
    echo "Created $KUSTOMIZATION"
else
    if ! grep -q "${KIND_LOWER}-activity.yaml" "$KUSTOMIZATION"; then
        # Add to resources list
        sed -i '' "/^resources:/a\\
  - ${KIND_LOWER}-activity.yaml
" "$KUSTOMIZATION" 2>/dev/null || \
        sed -i "/^resources:/a\\  - ${KIND_LOWER}-activity.yaml" "$KUSTOMIZATION"
        echo "Added ${KIND_LOWER}-activity.yaml to $KUSTOMIZATION"
    fi
fi

echo ""
echo "Next steps:"
echo "1. Review and customize config/apiserver/policies/${KIND_LOWER}-activity.yaml"
echo "2. Add event rules for your controller's event reasons"
echo "3. Test with: kubectl apply -f config/apiserver/policies/${KIND_LOWER}-activity-preview.yaml"
echo "4. Verify results: kubectl get policypreview test-${KIND_LOWER}-policy -o yaml"
echo "5. Deploy: kubectl apply -f config/apiserver/policies/"
echo "6. Run validate-activity.sh to verify integration"
