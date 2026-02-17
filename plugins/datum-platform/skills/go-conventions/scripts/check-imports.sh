#!/bin/bash
# Check import grouping conventions
# Run from service repository root

set -e

echo "=== Import Grouping Check ==="

ERRORS=0

# Find all Go files (excluding generated and vendor)
GO_FILES=$(find . -name "*.go" -not -path "./vendor/*" -not -name "zz_generated*" -not -path "./.git/*")

for FILE in $GO_FILES; do
    # Extract import block
    IMPORTS=$(sed -n '/^import (/,/^)/p' "$FILE" 2>/dev/null)

    if [ -z "$IMPORTS" ]; then
        continue
    fi

    # Check for proper grouping (should have blank lines between groups)
    # Count blank lines in import block
    BLANK_LINES=$(echo "$IMPORTS" | grep -c "^$" || echo "0")

    # If there are multiple imports but no blank lines, likely missing grouping
    IMPORT_COUNT=$(echo "$IMPORTS" | grep -c '"' || echo "0")

    if [ "$IMPORT_COUNT" -gt 3 ] && [ "$BLANK_LINES" -eq 0 ]; then
        echo "WARNING: $FILE may be missing import grouping"
        # Don't error, just warn
    fi
done

# Use goimports to check
if command -v goimports &> /dev/null; then
    echo "Running goimports check..."
    DIFF=$(goimports -l . 2>/dev/null | grep -v vendor | grep -v zz_generated || echo "")
    if [ -n "$DIFF" ]; then
        echo "WARNING: The following files need goimports formatting:"
        echo "$DIFF"
    else
        echo "✓ All files pass goimports check"
    fi
else
    echo "Note: Install goimports for full import checking"
fi

echo ""
if [ "$ERRORS" -gt 0 ]; then
    echo "FAILED: $ERRORS error(s) found"
    exit 1
else
    echo "PASSED: Import check complete"
fi
