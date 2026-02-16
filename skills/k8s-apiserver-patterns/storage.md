# Storage Implementation

## REST Storage Structure

```go
type REST struct {
    store     storage.Interface
    createStrategy rest.RESTCreateStrategy
    updateStrategy rest.RESTUpdateStrategy
}

type StatusREST struct {
    store storage.Interface
}

func NewREST(store storage.Interface) (*REST, *StatusREST) {
    r := &REST{
        store:          store,
        createStrategy: &myResourceStrategy{},
        updateStrategy: &myResourceStrategy{},
    }
    statusStore := &StatusREST{store: store}
    return r, statusStore
}
```

## Interface Implementation

### Required Interfaces

```go
var _ rest.Storage = &REST{}
var _ rest.Creater = &REST{}
var _ rest.Updater = &REST{}
var _ rest.GracefulDeleter = &REST{}
var _ rest.Lister = &REST{}
var _ rest.Getter = &REST{}

// Optional but recommended
var _ rest.Watcher = &REST{}
var _ rest.TableConvertor = &REST{}
```

### Create

```go
func (r *REST) Create(ctx context.Context, obj runtime.Object, createValidation rest.ValidateObjectFunc, options *metav1.CreateOptions) (runtime.Object, error) {
    // Run validation
    if createValidation != nil {
        if err := createValidation(ctx, obj); err != nil {
            return nil, err
        }
    }

    // Apply defaults
    r.createStrategy.PrepareForCreate(ctx, obj)

    // Validate
    if errs := r.createStrategy.Validate(ctx, obj); len(errs) > 0 {
        return nil, errors.NewInvalid(/* ... */)
    }

    // Store
    return r.store.Create(ctx, obj, options)
}
```

### Get

```go
func (r *REST) Get(ctx context.Context, name string, options *metav1.GetOptions) (runtime.Object, error) {
    return r.store.Get(ctx, name, options)
}
```

### List

```go
func (r *REST) List(ctx context.Context, options *metainternalversion.ListOptions) (runtime.Object, error) {
    return r.store.List(ctx, options)
}
```

### Update

```go
func (r *REST) Update(ctx context.Context, name string, objInfo rest.UpdatedObjectInfo, createValidation rest.ValidateObjectFunc, updateValidation rest.ValidateObjectUpdateFunc, forceAllowCreate bool, options *metav1.UpdateOptions) (runtime.Object, bool, error) {
    // Get existing object
    existing, err := r.store.Get(ctx, name, &metav1.GetOptions{})
    if err != nil {
        if !errors.IsNotFound(err) || !forceAllowCreate {
            return nil, false, err
        }
        // Handle create-on-update if allowed
    }

    // Get updated object
    obj, err := objInfo.UpdatedObject(ctx, existing)
    if err != nil {
        return nil, false, err
    }

    // Prepare for update
    r.updateStrategy.PrepareForUpdate(ctx, obj, existing)

    // Validate
    if errs := r.updateStrategy.ValidateUpdate(ctx, obj, existing); len(errs) > 0 {
        return nil, false, errors.NewInvalid(/* ... */)
    }

    // Store
    return r.store.Update(ctx, name, obj, options)
}
```

### Delete

```go
func (r *REST) Delete(ctx context.Context, name string, deleteValidation rest.ValidateObjectFunc, options *metav1.DeleteOptions) (runtime.Object, bool, error) {
    // Get object for return
    obj, err := r.store.Get(ctx, name, &metav1.GetOptions{})
    if err != nil {
        return nil, false, err
    }

    // Validate deletion
    if deleteValidation != nil {
        if err := deleteValidation(ctx, obj); err != nil {
            return nil, false, err
        }
    }

    // Delete
    if err := r.store.Delete(ctx, name, options); err != nil {
        return nil, false, err
    }

    return obj, true, nil
}
```

## Status Subresource

```go
func (r *StatusREST) Get(ctx context.Context, name string, options *metav1.GetOptions) (runtime.Object, error) {
    return r.store.Get(ctx, name, options)
}

func (r *StatusREST) Update(ctx context.Context, name string, objInfo rest.UpdatedObjectInfo, createValidation rest.ValidateObjectFunc, updateValidation rest.ValidateObjectUpdateFunc, forceAllowCreate bool, options *metav1.UpdateOptions) (runtime.Object, bool, error) {
    // Get existing
    existing, err := r.store.Get(ctx, name, &metav1.GetOptions{})
    if err != nil {
        return nil, false, err
    }

    // Get updated status
    obj, err := objInfo.UpdatedObject(ctx, existing)
    if err != nil {
        return nil, false, err
    }

    // Copy status to existing (preserve spec)
    existingResource := existing.(*v1alpha1.MyResource)
    newResource := obj.(*v1alpha1.MyResource)
    existingResource.Status = newResource.Status

    // Store
    return r.store.Update(ctx, name, existingResource, options)
}
```

## Storage Initialization

Use `sync.Once` for lazy initialization:

```go
type REST struct {
    store     storage.Interface
    storeOnce sync.Once
}

func (r *REST) getStore() storage.Interface {
    r.storeOnce.Do(func() {
        r.store = newStorageBackend()
    })
    return r.store
}
```
