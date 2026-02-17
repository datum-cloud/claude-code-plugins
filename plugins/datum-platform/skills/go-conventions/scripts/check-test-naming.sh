#!/bin/bash
# Check test file naming conventions
# Run from service repository root

set -e

echo "=== Test Naming Check ==="

ERRORS=0

# Find all Go files (excluding vendor and generated)
GO_FILES=$(find . -name "*.go" -not -path "./vendor/*" -not -name "zz_generated*" -not -path "./.git/*" -not -name "*_test.go")

for FILE in $GO_FILES; do
    BASE=$(basename "$FILE" .go)
    DIR=$(dirname "$FILE")
    TEST_FILE="$DIR/${BASE}_test.go"

    # Check if test file should exist (has exported functions)
    if grep -q "^func [A-Z]" "$FILE" 2>/dev/null; then
        if [ ! -f "$TEST_FILE" ]; then
            # Only warn for main code files, not helpers
            if [[ "$FILE" != *"doc.go"* ]] && [[ "$FILE" != *"register.go"* ]]; then
                echo "INFO: $FILE has no test file ($TEST_FILE)"
            fi
        fi
    fi
done

# Check test file naming
TEST_FILES=$(find . -name "*_test.go" -not -path "./vendor/*" -not -path "./.git/*")

for TEST_FILE in $TEST_FILES; do
    # Check for proper test function naming
    if grep -q "^func Test" "$TEST_FILE"; then
        # Good - has test functions
        :
    else
        echo "WARNING: $TEST_FILE has no Test functions"
    fi

    # Check for t.Run usage in table tests
    if grep -q "for.*range" "$TEST_FILE" && grep -q "tests\|testCases\|cases" "$TEST_FILE"; then
        if ! grep -q "t.Run" "$TEST_FILE"; then
            echo "WARNING: $TEST_FILE may have table tests without t.Run"
        fi
    fi
done

echo ""
if [ "$ERRORS" -gt 0 ]; then
    echo "FAILED: $ERRORS error(s) found"
    exit 1
else
    echo "PASSED: Test naming check complete"
fi
