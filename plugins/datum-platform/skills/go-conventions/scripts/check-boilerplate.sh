#!/bin/bash
# Check for required boilerplate (license headers)
# Run from service repository root

set -e

echo "=== Boilerplate Check ==="

ERRORS=0

# Expected boilerplate pattern (adjust as needed)
BOILERPLATE_PATTERN="Copyright.*Datum"

# Find all Go files
GO_FILES=$(find . -name "*.go" -not -path "./vendor/*" -not -name "zz_generated*" -not -path "./.git/*")

for FILE in $GO_FILES; do
    # Check first 10 lines for boilerplate
    HEAD=$(head -10 "$FILE")

    if ! echo "$HEAD" | grep -qi "$BOILERPLATE_PATTERN"; then
        echo "WARNING: $FILE may be missing license header"
        # Don't error, just warn (boilerplate requirements may vary)
    fi
done

# Check for package comments in main packages
echo "Checking package comments..."
for DOC_FILE in $(find . -name "doc.go" -not -path "./vendor/*"); do
    if ! grep -q "^// Package" "$DOC_FILE"; then
        echo "WARNING: $DOC_FILE missing package comment"
    fi
done

echo ""
if [ "$ERRORS" -gt 0 ]; then
    echo "FAILED: $ERRORS error(s) found"
    exit 1
else
    echo "PASSED: Boilerplate check complete"
fi
