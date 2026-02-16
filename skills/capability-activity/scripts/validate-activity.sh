#!/bin/bash
# Validate activity integration completeness
# Run from service repository root

set -e

echo "=== Activity Integration Validation ==="

ERRORS=0
WARNINGS=0

# Check for policies directory
POLICIES_DIR="config/apiserver/policies"
if [ ! -d "$POLICIES_DIR" ]; then
    echo "ERROR: Policies directory not found at $POLICIES_DIR"
    echo "  Run scaffold-activity.sh to create ActivityPolicy resources"
    ERRORS=$((ERRORS + 1))
else
    echo "✓ Policies directory exists"
fi

# Check for ActivityPolicy files
echo ""
echo "Checking ActivityPolicy files..."
POLICY_FILES=$(find "$POLICIES_DIR" -name "*-activity.yaml" 2>/dev/null | wc -l | tr -d ' ')
if [ "$POLICY_FILES" -eq 0 ]; then
    echo "ERROR: No ActivityPolicy files found in $POLICIES_DIR"
    echo "  Expected files matching *-activity.yaml"
    ERRORS=$((ERRORS + 1))
else
    echo "✓ Found $POLICY_FILES ActivityPolicy file(s)"

    # List the policies
    for policy in $(find "$POLICIES_DIR" -name "*-activity.yaml" 2>/dev/null); do
        echo "  - $(basename "$policy")"
    done
fi

# Check for kustomization.yaml
echo ""
echo "Checking Kustomization..."
KUSTOMIZATION="$POLICIES_DIR/kustomization.yaml"
if [ ! -f "$KUSTOMIZATION" ]; then
    echo "WARNING: No kustomization.yaml found in $POLICIES_DIR"
    echo "  Policies may not be deployed"
    WARNINGS=$((WARNINGS + 1))
else
    echo "✓ Kustomization file exists"

    # Check if activity policies are included
    for policy in $(find "$POLICIES_DIR" -name "*-activity.yaml" 2>/dev/null); do
        policy_name=$(basename "$policy")
        if ! grep -q "$policy_name" "$KUSTOMIZATION"; then
            echo "WARNING: $policy_name not included in kustomization.yaml"
            WARNINGS=$((WARNINGS + 1))
        fi
    done
fi

# Validate policy structure
echo ""
echo "Validating policy structure..."
for policy in $(find "$POLICIES_DIR" -name "*-activity.yaml" 2>/dev/null); do
    policy_name=$(basename "$policy")

    # Check for required fields
    if ! grep -q "apiVersion: activity.miloapis.com" "$policy"; then
        echo "ERROR: $policy_name missing correct apiVersion"
        ERRORS=$((ERRORS + 1))
    fi

    if ! grep -q "kind: ActivityPolicy" "$policy"; then
        echo "ERROR: $policy_name missing kind: ActivityPolicy"
        ERRORS=$((ERRORS + 1))
    fi

    if ! grep -q "auditRules:" "$policy"; then
        echo "ERROR: $policy_name missing auditRules section"
        ERRORS=$((ERRORS + 1))
    fi

    # Check for create rule
    if ! grep -q "audit.verb == 'create'" "$policy"; then
        echo "WARNING: $policy_name missing create audit rule"
        WARNINGS=$((WARNINGS + 1))
    fi

    # Check for delete rule
    if ! grep -q "audit.verb == 'delete'" "$policy"; then
        echo "WARNING: $policy_name missing delete audit rule"
        WARNINGS=$((WARNINGS + 1))
    fi

    # Check for update rule
    if ! grep -qE "audit.verb (==|in).*'(update|patch)'" "$policy"; then
        echo "WARNING: $policy_name missing update/patch audit rule"
        WARNINGS=$((WARNINGS + 1))
    fi

    echo "✓ $policy_name structure valid"
done

# Check for API types to ensure all resources have policies
echo ""
echo "Checking for uncovered API types..."
TYPES_DIR="pkg/apis"
if [ -d "$TYPES_DIR" ]; then
    # Find all types.go files and extract Kind definitions
    for types_file in $(find "$TYPES_DIR" -name "types.go" 2>/dev/null); do
        # Extract struct names that look like API types (have metav1.TypeMeta)
        kinds=$(grep -B 1 "metav1.TypeMeta" "$types_file" 2>/dev/null | grep "^type " | awk '{print $2}' || true)

        for kind in $kinds; do
            # Skip List types and internal types
            if [[ "$kind" == *"List" ]] || [[ "$kind" == *"Status" ]] || [[ "$kind" == *"Spec" ]]; then
                continue
            fi

            kind_lower=$(echo "$kind" | tr '[:upper:]' '[:lower:]')

            # Check if there's a policy for this kind
            if ! find "$POLICIES_DIR" -name "*-activity.yaml" -exec grep -l "kind: $kind" {} \; 2>/dev/null | grep -q .; then
                echo "WARNING: No ActivityPolicy found for $kind"
                echo "  Consider running: scaffold-activity.sh <api-group> $kind"
                WARNINGS=$((WARNINGS + 1))
            fi
        done
    done
else
    echo "INFO: No pkg/apis directory found, skipping API type check"
fi

# Summary
echo ""
echo "=== Validation Summary ==="
if [ "$ERRORS" -gt 0 ]; then
    echo "FAILED: $ERRORS error(s), $WARNINGS warning(s)"
    exit 1
elif [ "$WARNINGS" -gt 0 ]; then
    echo "PASSED with warnings: $WARNINGS warning(s)"
    echo "Review warnings and address if needed"
    exit 0
else
    echo "PASSED: Activity integration validation complete"
    exit 0
fi
