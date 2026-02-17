#!/bin/bash
# Scaffold telemetry integration for a resource
# Usage: scaffold-telemetry.sh <resource-name>

set -e

RESOURCE_NAME=$1
RESOURCE_LOWER=$(echo "$RESOURCE_NAME" | tr '[:upper:]' '[:lower:]')

if [ -z "$RESOURCE_NAME" ]; then
    echo "Usage: scaffold-telemetry.sh <resource-name>"
    echo "Example: scaffold-telemetry.sh VirtualMachine"
    exit 1
fi

echo "Scaffolding telemetry integration for $RESOURCE_NAME..."

# Create telemetry directory
mkdir -p internal/telemetry

# Create metrics definitions
cat > "internal/telemetry/${RESOURCE_LOWER}_metrics.go" << EOF
package telemetry

import (
    "go.opentelemetry.io/otel"
    "go.opentelemetry.io/otel/metric"
)

var meter = otel.Meter("myservice")

// ${RESOURCE_NAME}Metrics holds metrics for $RESOURCE_NAME
type ${RESOURCE_NAME}Metrics struct {
    RequestsTotal   metric.Int64Counter
    RequestDuration metric.Float64Histogram
    ActiveCount     metric.Int64UpDownCounter
}

// New${RESOURCE_NAME}Metrics creates metrics for $RESOURCE_NAME
func New${RESOURCE_NAME}Metrics() (*${RESOURCE_NAME}Metrics, error) {
    requestsTotal, err := meter.Int64Counter(
        "myservice.${RESOURCE_LOWER}.requests.total",
        metric.WithDescription("Total ${RESOURCE_NAME} API requests"),
    )
    if err != nil {
        return nil, err
    }

    requestDuration, err := meter.Float64Histogram(
        "myservice.${RESOURCE_LOWER}.request.duration.seconds",
        metric.WithDescription("${RESOURCE_NAME} request duration in seconds"),
    )
    if err != nil {
        return nil, err
    }

    activeCount, err := meter.Int64UpDownCounter(
        "myservice.${RESOURCE_LOWER}.active",
        metric.WithDescription("Number of active ${RESOURCE_NAME} instances"),
    )
    if err != nil {
        return nil, err
    }

    return &${RESOURCE_NAME}Metrics{
        RequestsTotal:   requestsTotal,
        RequestDuration: requestDuration,
        ActiveCount:     activeCount,
    }, nil
}
EOF

echo "Created internal/telemetry/${RESOURCE_LOWER}_metrics.go"

# Create tracing helpers
cat > "internal/telemetry/${RESOURCE_LOWER}_tracing.go" << EOF
package telemetry

import (
    "context"

    "go.opentelemetry.io/otel"
    "go.opentelemetry.io/otel/attribute"
    "go.opentelemetry.io/otel/trace"
)

var tracer = otel.Tracer("myservice")

// Start${RESOURCE_NAME}Span starts a traced span for ${RESOURCE_NAME} operations
func Start${RESOURCE_NAME}Span(ctx context.Context, operation string, name, namespace string) (context.Context, trace.Span) {
    return tracer.Start(ctx, operation+"${RESOURCE_NAME}",
        trace.WithAttributes(
            attribute.String("resource.name", name),
            attribute.String("resource.namespace", namespace),
            attribute.String("resource.kind", "${RESOURCE_NAME}"),
        ),
    )
}
EOF

echo "Created internal/telemetry/${RESOURCE_LOWER}_tracing.go"

echo ""
echo "Next steps:"
echo "1. Import metrics in your REST handler"
echo "2. Record request metrics in API operations"
echo "3. Use Start${RESOURCE_NAME}Span for tracing"
echo "4. Add structured logging with resource context"
echo "5. Run validate-metrics.sh to verify integration"
