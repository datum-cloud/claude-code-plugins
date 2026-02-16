#!/bin/bash
# Validate insights policy configuration
# Run from service repository root

set -e

echo "=== Insights Policy Validation ==="

ERRORS=0
WARNINGS=0

# Check for insights directory
echo "Checking for insights directory..."
if [ ! -d "config/insights" ]; then
    echo "WARNING: No config/insights/ directory found"
    echo "  Consider adding InsightPolicy resources to detect issues proactively"
    WARNINGS=$((WARNINGS + 1))
else
    echo "✓ Found config/insights/ directory"
fi

# Check for InsightPolicy files
echo "Checking for InsightPolicy files..."
POLICY_FILES=$(find config/insights -name "*.yaml" -exec grep -l "kind: InsightPolicy" {} \; 2>/dev/null | wc -l | tr -d ' ' || echo "0")
if [ "$POLICY_FILES" -eq 0 ]; then
    echo "WARNING: No InsightPolicy files found in config/insights/"
    echo "  Consider adding policies to detect issues proactively"
    WARNINGS=$((WARNINGS + 1))
else
    echo "✓ Found $POLICY_FILES InsightPolicy file(s)"
fi

# Validate YAML syntax
echo "Checking YAML syntax..."
for file in config/insights/*.yaml 2>/dev/null; do
    if [ -f "$file" ]; then
        if ! python3 -c "import yaml; yaml.safe_load(open('$file'))" 2>/dev/null; then
            echo "ERROR: Invalid YAML syntax in $file"
            ERRORS=$((ERRORS + 1))
        fi
    fi
done
if [ "$ERRORS" -eq 0 ]; then
    echo "✓ All YAML files have valid syntax"
fi

# Check for required fields in policies
echo "Checking policy structure..."
for file in config/insights/*.yaml 2>/dev/null; do
    if [ -f "$file" ] && grep -q "kind: InsightPolicy" "$file"; then
        # Check for targetSelector
        if ! grep -q "targetSelector:" "$file"; then
            echo "ERROR: $file is missing targetSelector"
            ERRORS=$((ERRORS + 1))
        fi
        # Check for rules
        if ! grep -q "rules:" "$file"; then
            echo "ERROR: $file is missing rules"
            ERRORS=$((ERRORS + 1))
        fi
        # Check for required rule fields
        if grep -q "rules:" "$file"; then
            # Each rule should have name, condition, severity, category, message
            RULE_COUNT=$(grep -c "^\s*- name:" "$file" 2>/dev/null || echo "0")
            if [ "$RULE_COUNT" -eq 0 ]; then
                echo "WARNING: $file has no rules defined"
                WARNINGS=$((WARNINGS + 1))
            fi
        fi
    fi
done

# Check kustomization includes insights
echo "Checking kustomization integration..."
if [ -f "config/base/kustomization.yaml" ]; then
    if ! grep -qE "(insights|../insights)" config/base/kustomization.yaml 2>/dev/null; then
        echo "WARNING: config/base/kustomization.yaml may not include insights"
        echo "  Add '../insights' to components or resources"
        WARNINGS=$((WARNINGS + 1))
    else
        echo "✓ Base kustomization references insights"
    fi
fi

# Check for insights kustomization
if [ -d "config/insights" ] && [ ! -f "config/insights/kustomization.yaml" ]; then
    echo "WARNING: config/insights/ exists but has no kustomization.yaml"
    WARNINGS=$((WARNINGS + 1))
fi

# Summary
echo ""
echo "=== Summary ==="
if [ "$ERRORS" -gt 0 ]; then
    echo "FAILED: $ERRORS error(s), $WARNINGS warning(s)"
    exit 1
elif [ "$WARNINGS" -gt 0 ]; then
    echo "PASSED with warnings: $WARNINGS warning(s)"
    echo "  Insights integration may be incomplete"
    exit 0
else
    echo "PASSED: Insights policy validation complete"
    exit 0
fi
