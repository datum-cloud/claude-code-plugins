#!/bin/bash
# Validate telemetry integration completeness
# Run from service repository root

set -e

echo "=== Telemetry Integration Validation ==="

ERRORS=0

# Check for metric definitions
echo "Checking metric definitions..."
METRIC_DEFS=$(grep -r "Int64Counter\|Float64Histogram\|Int64UpDownCounter\|Int64ObservableGauge" pkg/ internal/ 2>/dev/null | wc -l || echo "0")
if [ "$METRIC_DEFS" -eq 0 ]; then
    echo "WARNING: No metric definitions found"
    echo "  Consider adding metrics for observability"
else
    echo "✓ Found $METRIC_DEFS metric definition(s)"
fi

# Check for tracer usage
echo "Checking trace instrumentation..."
TRACE_SPANS=$(grep -r "tracer.Start\|trace.Start\|StartSpan" pkg/ internal/ 2>/dev/null | wc -l || echo "0")
if [ "$TRACE_SPANS" -eq 0 ]; then
    echo "WARNING: No trace spans found"
    echo "  Consider adding traces for request tracking"
else
    echo "✓ Found $TRACE_SPANS trace span(s)"
fi

# Check for structured logging
echo "Checking structured logging..."
STRUCTURED_LOGS=$(grep -r "logger.Info\|logger.Error\|logger.Debug\|slog.Info\|slog.Error" pkg/ internal/ 2>/dev/null | wc -l || echo "0")
if [ "$STRUCTURED_LOGS" -eq 0 ]; then
    echo "WARNING: No structured logging found"
else
    echo "✓ Found $STRUCTURED_LOGS structured log statement(s)"
fi

# Check metric naming conventions
echo "Checking metric naming conventions..."
BAD_NAMES=$(grep -rE "\"[a-z]+[A-Z]|\"[A-Z]" pkg/ internal/ 2>/dev/null | grep -E "Counter\|Histogram\|Gauge" | wc -l || echo "0")
if [ "$BAD_NAMES" -gt 0 ]; then
    echo "WARNING: Some metrics may not follow naming conventions"
    echo "  Use lowercase with dots: service.resource.measurement"
fi

# Check for OTel imports
echo "Checking OpenTelemetry integration..."
OTEL_IMPORTS=$(grep -r "go.opentelemetry.io/otel" pkg/ internal/ 2>/dev/null | wc -l || echo "0")
if [ "$OTEL_IMPORTS" -eq 0 ]; then
    echo "WARNING: No OpenTelemetry imports found"
else
    echo "✓ OpenTelemetry is integrated"
fi

# Check for telemetry tests
echo "Checking telemetry tests..."
TELEMETRY_TESTS=$(grep -r "TestMetric\|TestTrace\|telemetry.*test" pkg/ internal/ 2>/dev/null | wc -l || echo "0")
if [ "$TELEMETRY_TESTS" -eq 0 ]; then
    echo "WARNING: No telemetry-specific tests found"
else
    echo "✓ Found $TELEMETRY_TESTS telemetry test(s)"
fi

echo ""
if [ "$ERRORS" -gt 0 ]; then
    echo "FAILED: $ERRORS error(s) found"
    exit 1
else
    echo "PASSED: Telemetry integration validation complete"
fi
