# Validation Patterns

## Strategy Pattern

```go
type myResourceStrategy struct {
    runtime.ObjectTyper
    names.NameGenerator
}

func (s *myResourceStrategy) NamespaceScoped() bool {
    return true
}

func (s *myResourceStrategy) PrepareForCreate(ctx context.Context, obj runtime.Object) {
    resource := obj.(*v1alpha1.MyResource)
    // Set defaults
    if resource.Spec.Replicas == 0 {
        resource.Spec.Replicas = 1
    }
    // Clear status on create
    resource.Status = v1alpha1.MyResourceStatus{}
}

func (s *myResourceStrategy) Validate(ctx context.Context, obj runtime.Object) field.ErrorList {
    resource := obj.(*v1alpha1.MyResource)
    return validateMyResource(resource)
}

func (s *myResourceStrategy) PrepareForUpdate(ctx context.Context, obj, old runtime.Object) {
    newResource := obj.(*v1alpha1.MyResource)
    oldResource := old.(*v1alpha1.MyResource)
    // Preserve status during spec updates
    newResource.Status = oldResource.Status
}

func (s *myResourceStrategy) ValidateUpdate(ctx context.Context, obj, old runtime.Object) field.ErrorList {
    newResource := obj.(*v1alpha1.MyResource)
    oldResource := old.(*v1alpha1.MyResource)
    return validateMyResourceUpdate(newResource, oldResource)
}
```

## Validation Functions

```go
func validateMyResource(r *v1alpha1.MyResource) field.ErrorList {
    allErrs := field.ErrorList{}
    specPath := field.NewPath("spec")

    // Required field
    if r.Spec.Name == "" {
        allErrs = append(allErrs, field.Required(
            specPath.Child("name"),
            "name is required",
        ))
    }

    // Range validation
    if r.Spec.Replicas < 0 || r.Spec.Replicas > 100 {
        allErrs = append(allErrs, field.Invalid(
            specPath.Child("replicas"),
            r.Spec.Replicas,
            "must be between 0 and 100",
        ))
    }

    // Format validation
    if !isValidName(r.Spec.Name) {
        allErrs = append(allErrs, field.Invalid(
            specPath.Child("name"),
            r.Spec.Name,
            "must be a valid DNS subdomain",
        ))
    }

    return allErrs
}

func validateMyResourceUpdate(new, old *v1alpha1.MyResource) field.ErrorList {
    allErrs := validateMyResource(new)
    specPath := field.NewPath("spec")

    // Immutable field
    if new.Spec.Name != old.Spec.Name {
        allErrs = append(allErrs, field.Forbidden(
            specPath.Child("name"),
            "name is immutable",
        ))
    }

    return allErrs
}
```

## Kubebuilder Markers

Use markers for declarative validation:

```go
type MyResourceSpec struct {
    // +kubebuilder:validation:Required
    // +kubebuilder:validation:MinLength=1
    // +kubebuilder:validation:MaxLength=63
    // +kubebuilder:validation:Pattern=`^[a-z0-9]([-a-z0-9]*[a-z0-9])?$`
    Name string `json:"name"`

    // +kubebuilder:validation:Minimum=0
    // +kubebuilder:validation:Maximum=100
    // +kubebuilder:default=1
    Replicas int32 `json:"replicas,omitempty"`

    // +kubebuilder:validation:Enum=small;medium;large
    Size string `json:"size,omitempty"`

    // +kubebuilder:validation:Format=uri
    Endpoint string `json:"endpoint,omitempty"`
}
```

## Admission Webhooks

For complex validation, use admission webhooks:

```go
func (v *MyResourceValidator) ValidateCreate(ctx context.Context, obj runtime.Object) error {
    resource := obj.(*v1alpha1.MyResource)

    // Cross-resource validation
    if err := v.validateExternalDependencies(ctx, resource); err != nil {
        return err
    }

    return nil
}

func (v *MyResourceValidator) ValidateUpdate(ctx context.Context, oldObj, newObj runtime.Object) error {
    old := oldObj.(*v1alpha1.MyResource)
    new := newObj.(*v1alpha1.MyResource)

    // Transition validation
    if !isValidTransition(old.Status.Phase, new.Status.Phase) {
        return field.Forbidden(
            field.NewPath("status", "phase"),
            "invalid phase transition",
        )
    }

    return nil
}
```
