#!/bin/bash
# Check security configurations in Kustomize manifests
# Run from service repository root

set -e

echo "=== Security Configuration Check ==="

ERRORS=0
WARNINGS=0

# Build production overlay for checking
if [ ! -d "config/overlays/production" ]; then
    echo "WARNING: No production overlay found, checking base"
    MANIFEST=$(kubectl kustomize config/base 2>/dev/null)
else
    MANIFEST=$(kubectl kustomize config/overlays/production 2>/dev/null)
fi

if [ -z "$MANIFEST" ]; then
    echo "ERROR: Could not build manifests"
    exit 1
fi

# Check for securityContext
echo "Checking security contexts..."

# Check runAsNonRoot
if echo "$MANIFEST" | grep -q "runAsNonRoot: true"; then
    echo "✓ runAsNonRoot is set"
else
    echo "ERROR: runAsNonRoot not set to true"
    ERRORS=$((ERRORS + 1))
fi

# Check readOnlyRootFilesystem
if echo "$MANIFEST" | grep -q "readOnlyRootFilesystem: true"; then
    echo "✓ readOnlyRootFilesystem is set"
else
    echo "ERROR: readOnlyRootFilesystem not set to true"
    ERRORS=$((ERRORS + 1))
fi

# Check allowPrivilegeEscalation
if echo "$MANIFEST" | grep -q "allowPrivilegeEscalation: false"; then
    echo "✓ allowPrivilegeEscalation is disabled"
else
    echo "ERROR: allowPrivilegeEscalation not set to false"
    ERRORS=$((ERRORS + 1))
fi

# Check capabilities drop
if echo "$MANIFEST" | grep -A5 "capabilities:" | grep -q 'drop:'; then
    if echo "$MANIFEST" | grep -A10 "capabilities:" | grep -q '"ALL"\|ALL'; then
        echo "✓ Capabilities dropped"
    else
        echo "WARNING: Capabilities drop may not include ALL"
        WARNINGS=$((WARNINGS + 1))
    fi
else
    echo "ERROR: No capabilities drop found"
    ERRORS=$((ERRORS + 1))
fi

# Check resource limits
echo "Checking resource limits..."
if echo "$MANIFEST" | grep -q "limits:"; then
    echo "✓ Resource limits defined"
else
    echo "ERROR: No resource limits defined"
    ERRORS=$((ERRORS + 1))
fi

if echo "$MANIFEST" | grep -q "requests:"; then
    echo "✓ Resource requests defined"
else
    echo "ERROR: No resource requests defined"
    ERRORS=$((ERRORS + 1))
fi

# Check for privileged containers
echo "Checking for privileged containers..."
if echo "$MANIFEST" | grep -q "privileged: true"; then
    echo "ERROR: Privileged container found"
    ERRORS=$((ERRORS + 1))
else
    echo "✓ No privileged containers"
fi

# Check for hostNetwork
if echo "$MANIFEST" | grep -q "hostNetwork: true"; then
    echo "ERROR: hostNetwork enabled"
    ERRORS=$((ERRORS + 1))
else
    echo "✓ hostNetwork not used"
fi

# Check for hostPID
if echo "$MANIFEST" | grep -q "hostPID: true"; then
    echo "ERROR: hostPID enabled"
    ERRORS=$((ERRORS + 1))
else
    echo "✓ hostPID not used"
fi

# Check image
echo "Checking container images..."
if echo "$MANIFEST" | grep -E "image:.*:latest"; then
    echo "WARNING: Using :latest tag"
    WARNINGS=$((WARNINGS + 1))
fi

if echo "$MANIFEST" | grep -E "image:.*distroless"; then
    echo "✓ Using distroless base image"
else
    echo "WARNING: Not using distroless base image"
    WARNINGS=$((WARNINGS + 1))
fi

echo ""
echo "Summary: $ERRORS error(s), $WARNINGS warning(s)"

if [ "$ERRORS" -gt 0 ]; then
    echo "FAILED: Security check failed"
    exit 1
else
    echo "PASSED: Security check complete"
fi
