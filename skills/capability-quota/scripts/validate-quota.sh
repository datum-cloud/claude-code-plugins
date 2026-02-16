#!/bin/bash
# Validate quota integration completeness
# Run from service repository root

set -e

echo "=== Quota Integration Validation ==="

ERRORS=0
WARNINGS=0

# Check for quota manifests directory
echo "Checking quota manifests..."
QUOTA_DIR=""
for dir in config/quota manifests/quota deploy/quota; do
    if [ -d "$dir" ]; then
        QUOTA_DIR="$dir"
        break
    fi
done

if [ -z "$QUOTA_DIR" ]; then
    echo "WARNING: No quota manifests directory found (checked config/quota, manifests/quota, deploy/quota)"
    echo "  If this service has limitable resources, create quota policy manifests"
    WARNINGS=$((WARNINGS + 1))
fi

# Check for ResourceRegistration
echo "Checking ResourceRegistration manifests..."
REGISTRATIONS=$(find . -name "*.yaml" -o -name "*.yml" 2>/dev/null | xargs grep -l "kind: ResourceRegistration" 2>/dev/null | wc -l || echo "0")
if [ "$REGISTRATIONS" -eq 0 ]; then
    echo "WARNING: No ResourceRegistration manifests found"
    echo "  Create a ResourceRegistration for each quota dimension"
    WARNINGS=$((WARNINGS + 1))
else
    echo "✓ Found $REGISTRATIONS ResourceRegistration manifest(s)"
fi

# Check for ClaimCreationPolicy
echo "Checking ClaimCreationPolicy manifests..."
CLAIM_POLICIES=$(find . -name "*.yaml" -o -name "*.yml" 2>/dev/null | xargs grep -l "kind: ClaimCreationPolicy" 2>/dev/null | wc -l || echo "0")
if [ "$CLAIM_POLICIES" -eq 0 ]; then
    echo "WARNING: No ClaimCreationPolicy manifests found"
    echo "  Create a ClaimCreationPolicy for quota enforcement at admission"
    WARNINGS=$((WARNINGS + 1))
else
    echo "✓ Found $CLAIM_POLICIES ClaimCreationPolicy manifest(s)"
fi

# Check for GrantCreationPolicy
echo "Checking GrantCreationPolicy manifests..."
GRANT_POLICIES=$(find . -name "*.yaml" -o -name "*.yml" 2>/dev/null | xargs grep -l "kind: GrantCreationPolicy" 2>/dev/null | wc -l || echo "0")
if [ "$GRANT_POLICIES" -eq 0 ]; then
    echo "WARNING: No GrantCreationPolicy manifests found"
    echo "  Create GrantCreationPolicies for automatic quota allocation per tier"
    WARNINGS=$((WARNINGS + 1))
else
    echo "✓ Found $GRANT_POLICIES GrantCreationPolicy manifest(s)"
fi

# Check for tier coverage in GrantCreationPolicies
echo "Checking tier coverage..."
if [ "$GRANT_POLICIES" -gt 0 ]; then
    for TIER in free pro enterprise; do
        TIER_COVERAGE=$(find . -name "*.yaml" -o -name "*.yml" 2>/dev/null | xargs grep -l "kind: GrantCreationPolicy" 2>/dev/null | xargs grep -l "$TIER" 2>/dev/null | wc -l || echo "0")
        if [ "$TIER_COVERAGE" -eq 0 ]; then
            echo "WARNING: No GrantCreationPolicy appears to cover '$TIER' tier"
        fi
    done
fi

# Check for quota API group reference
echo "Checking API group references..."
CORRECT_API_GROUP=$(find . -name "*.yaml" -o -name "*.yml" 2>/dev/null | xargs grep -l "quota.miloapis.com" 2>/dev/null | wc -l || echo "0")
WRONG_API_GROUP=$(find . -name "*.yaml" -o -name "*.yml" 2>/dev/null | xargs grep -l "quota.miloapis.com" 2>/dev/null | wc -l || echo "0")
if [ "$WRONG_API_GROUP" -gt 0 ]; then
    echo "ERROR: Found references to old API group 'quota.miloapis.com'"
    echo "  Use 'quota.miloapis.com' instead"
    ERRORS=$((ERRORS + 1))
fi
if [ "$CORRECT_API_GROUP" -gt 0 ]; then
    echo "✓ Found $CORRECT_API_GROUP file(s) with correct API group"
fi

# Check for quota-related tests
echo "Checking quota tests..."
QUOTA_TESTS=$(grep -r "TestQuota\|quota.*Exceed\|ClaimCreationPolicy\|ResourceGrant" *_test.go 2>/dev/null | wc -l || echo "0")
if [ "$QUOTA_TESTS" -eq 0 ]; then
    echo "WARNING: No quota-specific tests found"
    echo "  Add tests for quota enforcement and release"
    WARNINGS=$((WARNINGS + 1))
else
    echo "✓ Found $QUOTA_TESTS quota test reference(s)"
fi

# Check for documented tier defaults
echo "Checking tier defaults documentation..."
TIER_DOCS=$(find . -name "*.md" 2>/dev/null | xargs grep -l "tier.*default\|quota.*limit" 2>/dev/null | wc -l || echo "0")
if [ "$TIER_DOCS" -eq 0 ]; then
    echo "WARNING: No documented tier defaults found in markdown files"
    echo "  Document quota defaults for each tier"
    WARNINGS=$((WARNINGS + 1))
else
    echo "✓ Found tier documentation"
fi

echo ""
echo "=== Summary ==="
if [ "$ERRORS" -gt 0 ]; then
    echo "FAILED: $ERRORS error(s), $WARNINGS warning(s)"
    exit 1
elif [ "$WARNINGS" -gt 0 ]; then
    echo "PASSED with warnings: $WARNINGS warning(s)"
    echo "Review warnings above and address if applicable to this service"
    exit 0
else
    echo "PASSED: Quota integration validation complete"
    exit 0
fi
