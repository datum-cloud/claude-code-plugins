#!/bin/bash
# Validate Kustomize configurations
# Run from service repository root

set -e

echo "=== Kustomize Validation ==="

ERRORS=0

# Check for config directory
if [ ! -d "config" ]; then
    echo "ERROR: No config/ directory found"
    exit 1
fi

# Check base builds
echo "Checking base configuration..."
if [ -d "config/base" ]; then
    if kubectl kustomize config/base > /dev/null 2>&1; then
        echo "✓ Base configuration builds successfully"
    else
        echo "ERROR: Base configuration fails to build"
        kubectl kustomize config/base 2>&1 | head -20
        ERRORS=$((ERRORS + 1))
    fi
else
    echo "WARNING: No config/base directory"
fi

# Check each overlay
echo "Checking overlays..."
for OVERLAY_DIR in config/overlays/*/; do
    if [ -d "$OVERLAY_DIR" ]; then
        OVERLAY_NAME=$(basename "$OVERLAY_DIR")
        if kubectl kustomize "$OVERLAY_DIR" > /dev/null 2>&1; then
            echo "✓ Overlay '$OVERLAY_NAME' builds successfully"
        else
            echo "ERROR: Overlay '$OVERLAY_NAME' fails to build"
            kubectl kustomize "$OVERLAY_DIR" 2>&1 | head -20
            ERRORS=$((ERRORS + 1))
        fi
    fi
done

# Check each component
echo "Checking components..."
for COMPONENT_DIR in config/components/*/; do
    if [ -d "$COMPONENT_DIR" ]; then
        COMPONENT_NAME=$(basename "$COMPONENT_DIR")
        if [ -f "$COMPONENT_DIR/kustomization.yaml" ]; then
            # Components can't be built standalone, check syntax
            if grep -q "kind: Component" "$COMPONENT_DIR/kustomization.yaml"; then
                echo "✓ Component '$COMPONENT_NAME' has valid structure"
            else
                echo "ERROR: Component '$COMPONENT_NAME' missing 'kind: Component'"
                ERRORS=$((ERRORS + 1))
            fi
        fi
    fi
done

# Check for common issues
echo "Checking for common issues..."

# Check for hardcoded namespaces in base
if grep -r "namespace:" config/base/*.yaml 2>/dev/null | grep -v "kustomization"; then
    echo "WARNING: Hardcoded namespace found in base (should use overlay)"
fi

# Check for missing resources
if [ -f "config/base/kustomization.yaml" ]; then
    RESOURCES=$(grep -A100 "^resources:" config/base/kustomization.yaml | grep "^  -" | sed 's/.*- //')
    for RESOURCE in $RESOURCES; do
        if [ ! -f "config/base/$RESOURCE" ]; then
            echo "ERROR: Referenced resource '$RESOURCE' not found"
            ERRORS=$((ERRORS + 1))
        fi
    done
fi

echo ""
if [ "$ERRORS" -gt 0 ]; then
    echo "FAILED: $ERRORS error(s) found"
    exit 1
else
    echo "PASSED: Kustomize validation complete"
fi
