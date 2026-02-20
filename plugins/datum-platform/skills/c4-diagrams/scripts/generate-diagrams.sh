#!/usr/bin/env bash
#
# Generate PNG images from PlantUML diagram sources.
# Requires Docker to be installed and running.
#
# Usage:
#   ./generate-diagrams.sh [directory]
#
# Arguments:
#   directory  Path containing .puml files (default: docs/architecture)
#
# Examples:
#   ./generate-diagrams.sh                      # Process docs/architecture
#   ./generate-diagrams.sh docs/diagrams        # Process custom directory
#   ./generate-diagrams.sh .                    # Process current directory
#

set -euo pipefail

DIAGRAM_DIR="${1:-docs/architecture}"

# Resolve to absolute path
DIAGRAM_DIR="$(cd "${DIAGRAM_DIR}" 2>/dev/null && pwd)" || {
    echo "Error: Directory '${1:-docs/architecture}' does not exist" >&2
    exit 1
}

# Check for Docker
if ! command -v docker &>/dev/null; then
    echo "Error: Docker is required but not installed" >&2
    exit 1
fi

# Check Docker is running
if ! docker info &>/dev/null; then
    echo "Error: Docker is not running" >&2
    exit 1
fi

# Find all .puml files
PUML_FILES=$(find "${DIAGRAM_DIR}" -name "*.puml" -type f)

if [[ -z "${PUML_FILES}" ]]; then
    echo "No .puml files found in ${DIAGRAM_DIR}" >&2
    exit 0
fi

echo "Generating PNGs from PlantUML diagrams in ${DIAGRAM_DIR}..."

# Generate PNGs using PlantUML Docker image
docker run --rm \
    -v "${DIAGRAM_DIR}:/data" \
    plantuml/plantuml \
    -tpng "/data/*.puml" "/data/**/*.puml" 2>/dev/null || true

# Count generated files
GENERATED=0
while IFS= read -r puml; do
    png="${puml%.puml}.png"
    if [[ -f "${png}" ]]; then
        echo "  Generated: ${png#${DIAGRAM_DIR}/}"
        ((GENERATED++))
    else
        echo "  Warning: Failed to generate ${png#${DIAGRAM_DIR}/}" >&2
    fi
done <<< "${PUML_FILES}"

echo "Done. Generated ${GENERATED} PNG file(s)."
