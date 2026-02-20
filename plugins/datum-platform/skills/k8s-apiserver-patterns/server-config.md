# Server Configuration

## CompletedConfig Pattern

```go
type Config struct {
    GenericConfig *genericapiserver.RecommendedConfig
    Storage       storage.Interface
}

type completedConfig struct {
    *Config
}

type CompletedConfig struct {
    *completedConfig
}

func (c *Config) Complete() CompletedConfig {
    // Apply defaults
    c.GenericConfig.Complete()

    return CompletedConfig{&completedConfig{c}}
}

func (c CompletedConfig) New() (*MyServer, error) {
    genericServer, err := c.GenericConfig.New("myservice", genericapiserver.NewEmptyDelegate())
    if err != nil {
        return nil, err
    }

    s := &MyServer{
        GenericAPIServer: genericServer,
        storage:          c.Storage,
    }

    // Install API
    apiGroupInfo := genericapiserver.NewDefaultAPIGroupInfo(
        "myservice.miloapis.com",
        Scheme,
        metav1.ParameterCodec,
        Codecs,
    )

    rest, statusRest := storage.NewREST(c.Storage)
    v1alpha1Storage := map[string]rest.Storage{
        "myresources":        rest,
        "myresources/status": statusRest,
    }
    apiGroupInfo.VersionedResourcesStorageMap["v1alpha1"] = v1alpha1Storage

    if err := s.GenericAPIServer.InstallAPIGroup(&apiGroupInfo); err != nil {
        return nil, err
    }

    return s, nil
}
```

## Server Struct

```go
type MyServer struct {
    GenericAPIServer *genericapiserver.GenericAPIServer
    storage          storage.Interface
}

func (s *MyServer) Run(stopCh <-chan struct{}) error {
    return s.GenericAPIServer.PrepareRun().Run(stopCh)
}
```

## Main Setup

```go
func main() {
    // Parse flags
    o := NewOptions()
    o.AddFlags(pflag.CommandLine)
    pflag.Parse()

    // Build config
    config, err := o.Config()
    if err != nil {
        klog.Fatal(err)
    }

    // Create server
    server, err := config.Complete().New()
    if err != nil {
        klog.Fatal(err)
    }

    // Run
    stopCh := genericapiserver.SetupSignalHandler()
    if err := server.Run(stopCh); err != nil {
        klog.Fatal(err)
    }
}
```

## Options

```go
type Options struct {
    RecommendedOptions *genericoptions.RecommendedOptions
    StorageOptions     *StorageOptions
}

func NewOptions() *Options {
    return &Options{
        RecommendedOptions: genericoptions.NewRecommendedOptions(
            "",
            Codecs.LegacyCodec(v1alpha1.SchemeGroupVersion),
        ),
        StorageOptions: NewStorageOptions(),
    }
}

func (o *Options) Config() (*Config, error) {
    // Create generic config
    serverConfig := genericapiserver.NewRecommendedConfig(Codecs)

    if err := o.RecommendedOptions.ApplyTo(serverConfig); err != nil {
        return nil, err
    }

    // Create storage
    store, err := o.StorageOptions.NewStorage()
    if err != nil {
        return nil, err
    }

    return &Config{
        GenericConfig: serverConfig,
        Storage:       store,
    }, nil
}
```

## Feature Gates Integration

For managing experimental features with runtime toggles, see `feature-gates.md`.

Import features package to register gates via init():

```go
import (
    _ "go.miloapis.com/myservice/pkg/features"
)
```

Check feature enablement in Config methods:

```go
func (c *Config) Complete() CompletedConfig {
    c.GenericConfig.Complete()

    if utilfeature.DefaultFeatureGate.Enabled(features.MyFeature) {
        // Initialize feature-specific configuration
        c.FeatureClient = newFeatureClient(c.FeatureURL)
    }

    return CompletedConfig{&completedConfig{c}}
}
```

## APIService Registration

```yaml
apiVersion: apiregistration.k8s.io/v1
kind: APIService
metadata:
  name: v1alpha1.myservice.miloapis.com
spec:
  group: myservice.miloapis.com
  version: v1alpha1
  service:
    name: myservice
    namespace: myservice-system
    port: 443
  groupPriorityMinimum: 1000
  versionPriority: 15
  caBundle: ${CA_BUNDLE}
```
