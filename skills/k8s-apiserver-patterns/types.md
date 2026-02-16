# API Type Definitions

## Type Structure

Every resource type follows this pattern:

```go
// +kubebuilder:object:root=true
// +kubebuilder:subresource:status
// +kubebuilder:printcolumn:name="Status",type=string,JSONPath=`.status.phase`

// MyResource is the Schema for the myresources API
type MyResource struct {
    metav1.TypeMeta   `json:",inline"`
    metav1.ObjectMeta `json:"metadata,omitempty"`

    Spec   MyResourceSpec   `json:"spec,omitempty"`
    Status MyResourceStatus `json:"status,omitempty"`
}

// MyResourceSpec defines the desired state
type MyResourceSpec struct {
    // +kubebuilder:validation:Required
    // +kubebuilder:validation:MinLength=1
    Name string `json:"name"`

    // +kubebuilder:validation:Optional
    // +kubebuilder:default=1
    Replicas int32 `json:"replicas,omitempty"`
}

// MyResourceStatus defines the observed state
type MyResourceStatus struct {
    // +kubebuilder:validation:Enum=Pending;Running;Failed
    Phase string `json:"phase,omitempty"`

    Conditions []metav1.Condition `json:"conditions,omitempty"`
}

// +kubebuilder:object:root=true

// MyResourceList contains a list of MyResource
type MyResourceList struct {
    metav1.TypeMeta `json:",inline"`
    metav1.ListMeta `json:"metadata,omitempty"`
    Items           []MyResource `json:"items"`
}
```

## Conventions

### Naming

| Convention | Example |
|------------|---------|
| Kind | `MyResource` (PascalCase singular) |
| Resource | `myresources` (lowercase plural) |
| List Kind | `MyResourceList` |
| Short name | `mr` (lowercase abbreviation) |

### Fields

| Field | Required | Purpose |
|-------|----------|---------|
| `TypeMeta` | Yes | API version and kind |
| `ObjectMeta` | Yes | Name, namespace, labels, etc. |
| `Spec` | Yes | Desired state (user-specified) |
| `Status` | Yes | Observed state (system-managed) |

### Markers

| Marker | Purpose |
|--------|---------|
| `+kubebuilder:object:root=true` | Root object for code generation |
| `+kubebuilder:subresource:status` | Enable /status subresource |
| `+kubebuilder:validation:Required` | Field is required |
| `+kubebuilder:validation:Optional` | Field is optional |
| `+kubebuilder:default=value` | Default value |
| `+kubebuilder:validation:Enum=a;b;c` | Allowed values |

## Status Conditions

Use standard Kubernetes conditions:

```go
type MyResourceStatus struct {
    Conditions []metav1.Condition `json:"conditions,omitempty"`
}

// Condition types
const (
    ConditionReady       = "Ready"
    ConditionProgressing = "Progressing"
    ConditionDegraded    = "Degraded"
)
```

### Setting Conditions

```go
meta.SetStatusCondition(&resource.Status.Conditions, metav1.Condition{
    Type:               ConditionReady,
    Status:             metav1.ConditionTrue,
    Reason:             "ResourceReady",
    Message:            "Resource is ready",
    ObservedGeneration: resource.Generation,
})
```

## SchemeBuilder

```go
var (
    SchemeGroupVersion = schema.GroupVersion{
        Group:   "myservice.miloapis.com",
        Version: "v1alpha1",
    }

    SchemeBuilder = runtime.NewSchemeBuilder(addKnownTypes)
    AddToScheme   = SchemeBuilder.AddToScheme
)

func addKnownTypes(scheme *runtime.Scheme) error {
    scheme.AddKnownTypes(SchemeGroupVersion,
        &MyResource{},
        &MyResourceList{},
    )
    metav1.AddToGroupVersion(scheme, SchemeGroupVersion)
    return nil
}
```
