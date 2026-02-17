#!/bin/bash
# Auto-validation hook for PostToolUse events
# Runs appropriate validators based on the file that was edited
#
# This script receives JSON input via stdin with the following structure:
# {
#   "tool_name": "Write|Edit",
#   "tool_input": { "file_path": "/path/to/file" },
#   "tool_output": "..."
# }

set -e

# Read JSON input from stdin
INPUT=$(cat)

# Extract the file path from tool_input
FILE_PATH=$(echo "$INPUT" | jq -r '.tool_input.file_path // .tool_input.filePath // empty')

if [ -z "$FILE_PATH" ]; then
  # No file path found, nothing to validate
  exit 0
fi

# Get the filename for pattern matching
FILENAME=$(basename "$FILE_PATH")
DIRNAME=$(dirname "$FILE_PATH")

# Track validation results
VALIDATION_FAILED=0
VALIDATION_OUTPUT=""

# Helper function to run a validator if it exists
run_validator() {
  local validator="$1"
  local target="$2"

  if [ -x "$validator" ]; then
    echo "Running: $(basename "$validator")" >&2
    if ! output=$("$validator" "$target" 2>&1); then
      VALIDATION_FAILED=1
      VALIDATION_OUTPUT="${VALIDATION_OUTPUT}\n$(basename "$validator"): $output"
    fi
  fi
}

# Determine which validators to run based on file type and location

# Go files: run Go convention checks
if [[ "$FILENAME" == *.go ]]; then
  PLUGIN_ROOT="${CLAUDE_PLUGIN_ROOT:-$(dirname "$(dirname "$0")")}"

  # Check imports
  if [ -x "$PLUGIN_ROOT/skills/go-conventions/scripts/check-imports.sh" ]; then
    run_validator "$PLUGIN_ROOT/skills/go-conventions/scripts/check-imports.sh" "$FILE_PATH"
  fi

  # Check boilerplate
  if [ -x "$PLUGIN_ROOT/skills/go-conventions/scripts/check-boilerplate.sh" ]; then
    run_validator "$PLUGIN_ROOT/skills/go-conventions/scripts/check-boilerplate.sh" "$FILE_PATH"
  fi

  # Check test naming for test files
  if [[ "$FILENAME" == *_test.go ]]; then
    if [ -x "$PLUGIN_ROOT/skills/go-conventions/scripts/check-test-naming.sh" ]; then
      run_validator "$PLUGIN_ROOT/skills/go-conventions/scripts/check-test-naming.sh" "$FILE_PATH"
    fi
  fi

  # Check types.go files for API type conventions
  if [[ "$FILENAME" == "types.go" ]] || [[ "$DIRNAME" == *"/apis/"* ]]; then
    if [ -x "$PLUGIN_ROOT/skills/k8s-apiserver-patterns/scripts/validate-types.sh" ]; then
      run_validator "$PLUGIN_ROOT/skills/k8s-apiserver-patterns/scripts/validate-types.sh" "$FILE_PATH"
    fi
  fi

  # Check for quota-related files
  if [[ "$FILE_PATH" == *"quota"* ]]; then
    if [ -x "$PLUGIN_ROOT/skills/capability-quota/scripts/validate-quota.sh" ]; then
      run_validator "$PLUGIN_ROOT/skills/capability-quota/scripts/validate-quota.sh" "$FILE_PATH"
    fi
  fi

  # Check for telemetry/metrics-related files
  if [[ "$FILE_PATH" == *"metric"* ]] || [[ "$FILE_PATH" == *"telemetry"* ]]; then
    if [ -x "$PLUGIN_ROOT/skills/capability-telemetry/scripts/validate-metrics.sh" ]; then
      run_validator "$PLUGIN_ROOT/skills/capability-telemetry/scripts/validate-metrics.sh" "$FILE_PATH"
    fi
  fi

  # Check for activity-related files
  if [[ "$FILE_PATH" == *"activity"* ]] || [[ "$FILE_PATH" == *"event"* ]]; then
    if [ -x "$PLUGIN_ROOT/skills/capability-activity/scripts/validate-activity.sh" ]; then
      run_validator "$PLUGIN_ROOT/skills/capability-activity/scripts/validate-activity.sh" "$FILE_PATH"
    fi
  fi

  # Check for insights-related files
  if [[ "$FILE_PATH" == *"insight"* ]] || [[ "$FILE_PATH" == *"alert"* ]]; then
    if [ -x "$PLUGIN_ROOT/skills/capability-insights/scripts/validate-insights.sh" ]; then
      run_validator "$PLUGIN_ROOT/skills/capability-insights/scripts/validate-insights.sh" "$FILE_PATH"
    fi
  fi
fi

# Kustomize files: run kustomize validation
if [[ "$FILENAME" == "kustomization.yaml" ]] || [[ "$FILENAME" == "kustomization.yml" ]]; then
  PLUGIN_ROOT="${CLAUDE_PLUGIN_ROOT:-$(dirname "$(dirname "$0")")}"

  if [ -x "$PLUGIN_ROOT/skills/kustomize-patterns/scripts/validate-kustomize.sh" ]; then
    run_validator "$PLUGIN_ROOT/skills/kustomize-patterns/scripts/validate-kustomize.sh" "$DIRNAME"
  fi

  if [ -x "$PLUGIN_ROOT/skills/kustomize-patterns/scripts/check-security.sh" ]; then
    run_validator "$PLUGIN_ROOT/skills/kustomize-patterns/scripts/check-security.sh" "$DIRNAME"
  fi
fi

# YAML files in config directories
if [[ "$FILENAME" == *.yaml ]] || [[ "$FILENAME" == *.yml ]]; then
  if [[ "$DIRNAME" == *"/config/"* ]] || [[ "$DIRNAME" == *"/deploy/"* ]]; then
    PLUGIN_ROOT="${CLAUDE_PLUGIN_ROOT:-$(dirname "$(dirname "$0")")}"

    if [ -x "$PLUGIN_ROOT/skills/kustomize-patterns/scripts/check-security.sh" ]; then
      run_validator "$PLUGIN_ROOT/skills/kustomize-patterns/scripts/check-security.sh" "$FILE_PATH"
    fi
  fi
fi

# Output results
if [ $VALIDATION_FAILED -eq 1 ]; then
  echo -e "Validation warnings:$VALIDATION_OUTPUT" >&2
  # Exit 0 to not block the edit, but warnings are shown
  # Change to exit 2 if you want to block edits that fail validation
  exit 0
fi

exit 0
