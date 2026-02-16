# Telemetry Implementation Guide

## Setting Up Telemetry

### Initialize Providers

```go
func setupTelemetry(ctx context.Context) (func(), error) {
    // Metrics
    meterProvider, err := setupMeterProvider(ctx)
    if err != nil {
        return nil, err
    }
    otel.SetMeterProvider(meterProvider)

    // Traces
    tracerProvider, err := setupTracerProvider(ctx)
    if err != nil {
        return nil, err
    }
    otel.SetTracerProvider(tracerProvider)

    // Cleanup function
    return func() {
        meterProvider.Shutdown(ctx)
        tracerProvider.Shutdown(ctx)
    }, nil
}
```

### Get Meters and Tracers

```go
var (
    meter  = otel.Meter("myservice")
    tracer = otel.Tracer("myservice")
)
```

## Instrumenting API Handlers

### Request Metrics

```go
var (
    requestsTotal = meter.Int64Counter(
        "myservice.requests.total",
        metric.WithDescription("Total API requests"),
    )
    requestDuration = meter.Float64Histogram(
        "myservice.request.duration.seconds",
        metric.WithDescription("Request duration in seconds"),
    )
)

func (h *Handler) ServeHTTP(w http.ResponseWriter, r *http.Request) {
    start := time.Now()

    // Handle request
    status := h.handle(w, r)

    // Record metrics
    duration := time.Since(start).Seconds()
    attrs := []attribute.KeyValue{
        attribute.String("method", r.Method),
        attribute.String("path", r.URL.Path),
        attribute.Int("status", status),
    }

    requestsTotal.Add(r.Context(), 1, metric.WithAttributes(attrs...))
    requestDuration.Record(r.Context(), duration, metric.WithAttributes(attrs...))
}
```

### Request Tracing

```go
func (h *Handler) handle(ctx context.Context, req *Request) (*Response, error) {
    ctx, span := tracer.Start(ctx, "HandleRequest",
        trace.WithAttributes(
            attribute.String("request.id", req.ID),
        ),
    )
    defer span.End()

    // Process request
    result, err := h.process(ctx, req)
    if err != nil {
        span.RecordError(err)
        span.SetStatus(codes.Error, err.Error())
        return nil, err
    }

    span.SetAttributes(attribute.String("response.id", result.ID))
    return result, nil
}
```

## Resource-Specific Metrics

### Gauge for Active Resources

```go
var activeResources = meter.Int64UpDownCounter(
    "myservice.myresource.active",
    metric.WithDescription("Number of active MyResource instances"),
)

func (r *REST) Create(ctx context.Context, obj runtime.Object, ...) (runtime.Object, error) {
    result, err := r.store.Create(ctx, obj, ...)
    if err == nil {
        activeResources.Add(ctx, 1)
    }
    return result, err
}

func (r *REST) Delete(ctx context.Context, name string, ...) (runtime.Object, bool, error) {
    result, sync, err := r.store.Delete(ctx, name, ...)
    if err == nil {
        activeResources.Add(ctx, -1)
    }
    return result, sync, err
}
```

### Status Metrics

```go
var resourceStatus = meter.Int64ObservableGauge(
    "myservice.myresource.status",
    metric.WithDescription("MyResource status by condition"),
)

func setupStatusMetrics(store storage.Interface) {
    meter.RegisterCallback(func(ctx context.Context, observer metric.Observer) error {
        resources, _ := store.List(ctx, &storage.ListOptions{})

        statusCounts := make(map[string]int64)
        for _, r := range resources.Items {
            status := getStatus(r)
            statusCounts[status]++
        }

        for status, count := range statusCounts {
            observer.ObserveInt64(resourceStatus, count,
                metric.WithAttributes(attribute.String("status", status)),
            )
        }
        return nil
    }, resourceStatus)
}
```

## Trace Context Propagation

### Across Service Calls

```go
func (c *Client) Call(ctx context.Context, req *Request) (*Response, error) {
    ctx, span := tracer.Start(ctx, "ClientCall")
    defer span.End()

    // Inject trace context into headers
    headers := make(http.Header)
    otel.GetTextMapPropagator().Inject(ctx, propagation.HeaderCarrier(headers))

    // Make request with headers
    httpReq, _ := http.NewRequestWithContext(ctx, "POST", url, body)
    for k, v := range headers {
        httpReq.Header[k] = v
    }

    return c.do(httpReq)
}
```

### From Incoming Requests

```go
func (h *Handler) ServeHTTP(w http.ResponseWriter, r *http.Request) {
    // Extract trace context from headers
    ctx := otel.GetTextMapPropagator().Extract(
        r.Context(),
        propagation.HeaderCarrier(r.Header),
    )

    ctx, span := tracer.Start(ctx, "HandleRequest")
    defer span.End()

    // Handle with traced context
    h.handle(ctx, w, r)
}
```

## Testing Telemetry

```go
func TestMetricsEmission(t *testing.T) {
    reader := metric.NewManualReader()
    provider := metric.NewMeterProvider(metric.WithReader(reader))
    otel.SetMeterProvider(provider)

    // Perform operation
    handler.Create(ctx, newResource(), nil, nil)

    // Collect metrics
    var rm metricdata.ResourceMetrics
    reader.Collect(ctx, &rm)

    // Verify metrics
    require.NotEmpty(t, rm.ScopeMetrics)
    // Assert specific metrics...
}
```
