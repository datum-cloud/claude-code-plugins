#!/bin/bash
# Validate API type conventions
# Run from service repository root

set -e

echo "=== API Type Validation ==="

ERRORS=0

# Find all types.go files
TYPE_FILES=$(find pkg/apis -name "types.go" 2>/dev/null || echo "")

if [ -z "$TYPE_FILES" ]; then
    echo "WARNING: No types.go files found in pkg/apis/"
    exit 0
fi

for TYPE_FILE in $TYPE_FILES; do
    echo "Checking $TYPE_FILE..."

    # Check for TypeMeta
    if ! grep -q "metav1.TypeMeta" "$TYPE_FILE"; then
        echo "ERROR: Missing TypeMeta in $TYPE_FILE"
        ERRORS=$((ERRORS + 1))
    fi

    # Check for ObjectMeta
    if ! grep -q "metav1.ObjectMeta" "$TYPE_FILE"; then
        echo "ERROR: Missing ObjectMeta in $TYPE_FILE"
        ERRORS=$((ERRORS + 1))
    fi

    # Check for Spec/Status pattern
    if grep -q "type.*struct" "$TYPE_FILE"; then
        # Get resource names (types ending in Spec or Status indicate main type exists)
        RESOURCES=$(grep -oE "type [A-Z][a-zA-Z]+Spec struct" "$TYPE_FILE" | sed 's/type //;s/Spec struct//')

        for RESOURCE in $RESOURCES; do
            # Check for corresponding type
            if ! grep -q "type ${RESOURCE} struct" "$TYPE_FILE"; then
                echo "ERROR: Found ${RESOURCE}Spec but no ${RESOURCE} type"
                ERRORS=$((ERRORS + 1))
            fi

            # Check for List type
            if ! grep -q "type ${RESOURCE}List struct" "$TYPE_FILE"; then
                echo "ERROR: Missing ${RESOURCE}List type"
                ERRORS=$((ERRORS + 1))
            fi

            # Check for Items in List
            if ! grep -A5 "type ${RESOURCE}List struct" "$TYPE_FILE" | grep -q "Items"; then
                echo "ERROR: ${RESOURCE}List missing Items field"
                ERRORS=$((ERRORS + 1))
            fi
        done
    fi

    # Check for kubebuilder markers
    if ! grep -q "+kubebuilder:object:root=true" "$TYPE_FILE"; then
        echo "WARNING: Missing +kubebuilder:object:root=true marker"
    fi

    # Check for deepcopy generation marker in doc.go
    DOC_FILE=$(dirname "$TYPE_FILE")/doc.go
    if [ -f "$DOC_FILE" ]; then
        if ! grep -q "+kubebuilder:object:generate=true" "$DOC_FILE"; then
            echo "WARNING: Missing +kubebuilder:object:generate=true in doc.go"
        fi
    else
        echo "WARNING: Missing doc.go file"
    fi
done

# Check for generated deepcopy
DEEPCOPY_FILES=$(find pkg/apis -name "zz_generated.deepcopy.go" 2>/dev/null | wc -l)
if [ "$DEEPCOPY_FILES" -eq 0 ]; then
    echo "WARNING: No generated deepcopy files found"
    echo "  Run 'task generate' to generate deepcopy functions"
fi

echo ""
if [ "$ERRORS" -gt 0 ]; then
    echo "FAILED: $ERRORS error(s) found"
    exit 1
else
    echo "PASSED: API type validation complete"
fi
