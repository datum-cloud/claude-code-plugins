#!/bin/bash
# Scaffold storage backend for a resource
# Usage: scaffold-storage.sh <resource-name>

set -e

RESOURCE_NAME=$1
RESOURCE_LOWER=$(echo "$RESOURCE_NAME" | tr '[:upper:]' '[:lower:]')
RESOURCE_PLURAL="${RESOURCE_LOWER}s"

if [ -z "$RESOURCE_NAME" ]; then
    echo "Usage: scaffold-storage.sh <resource-name>"
    echo "Example: scaffold-storage.sh VirtualMachine"
    exit 1
fi

echo "Scaffolding storage for $RESOURCE_NAME..."

# Create storage directory
mkdir -p "pkg/registry/${RESOURCE_LOWER}"

# Create REST storage
cat > "pkg/registry/${RESOURCE_LOWER}/rest.go" << EOF
package ${RESOURCE_LOWER}

import (
    "context"
    "sync"

    metav1 "k8s.io/apimachinery/pkg/apis/meta/v1"
    "k8s.io/apimachinery/pkg/runtime"
    "k8s.io/apiserver/pkg/registry/rest"
)

// REST implements rest.Storage for ${RESOURCE_NAME}
type REST struct {
    store     Store
    storeOnce sync.Once
    newStore  func() Store
}

// StatusREST implements the status subresource
type StatusREST struct {
    store Store
}

// NewREST creates REST storage for ${RESOURCE_NAME}
func NewREST(newStore func() Store) (*REST, *StatusREST) {
    r := &REST{newStore: newStore}
    return r, &StatusREST{store: r.getStore()}
}

func (r *REST) getStore() Store {
    r.storeOnce.Do(func() {
        r.store = r.newStore()
    })
    return r.store
}

// Implement rest.Storage
var _ rest.Storage = &REST{}
var _ rest.Creater = &REST{}
var _ rest.Updater = &REST{}
var _ rest.GracefulDeleter = &REST{}
var _ rest.Lister = &REST{}
var _ rest.Getter = &REST{}

func (r *REST) New() runtime.Object {
    return &v1alpha1.${RESOURCE_NAME}{}
}

func (r *REST) NewList() runtime.Object {
    return &v1alpha1.${RESOURCE_NAME}List{}
}

func (r *REST) NamespaceScoped() bool {
    return true
}

func (r *REST) Create(ctx context.Context, obj runtime.Object, createValidation rest.ValidateObjectFunc, options *metav1.CreateOptions) (runtime.Object, error) {
    if createValidation != nil {
        if err := createValidation(ctx, obj); err != nil {
            return nil, err
        }
    }
    return r.getStore().Create(ctx, obj.(*v1alpha1.${RESOURCE_NAME}))
}

func (r *REST) Get(ctx context.Context, name string, options *metav1.GetOptions) (runtime.Object, error) {
    return r.getStore().Get(ctx, name)
}

func (r *REST) List(ctx context.Context, options *metainternalversion.ListOptions) (runtime.Object, error) {
    return r.getStore().List(ctx)
}

func (r *REST) Update(ctx context.Context, name string, objInfo rest.UpdatedObjectInfo, createValidation rest.ValidateObjectFunc, updateValidation rest.ValidateObjectUpdateFunc, forceAllowCreate bool, options *metav1.UpdateOptions) (runtime.Object, bool, error) {
    existing, err := r.getStore().Get(ctx, name)
    if err != nil {
        return nil, false, err
    }

    obj, err := objInfo.UpdatedObject(ctx, existing)
    if err != nil {
        return nil, false, err
    }

    if updateValidation != nil {
        if err := updateValidation(ctx, obj, existing); err != nil {
            return nil, false, err
        }
    }

    result, err := r.getStore().Update(ctx, obj.(*v1alpha1.${RESOURCE_NAME}))
    return result, false, err
}

func (r *REST) Delete(ctx context.Context, name string, deleteValidation rest.ValidateObjectFunc, options *metav1.DeleteOptions) (runtime.Object, bool, error) {
    obj, err := r.getStore().Get(ctx, name)
    if err != nil {
        return nil, false, err
    }

    if deleteValidation != nil {
        if err := deleteValidation(ctx, obj); err != nil {
            return nil, false, err
        }
    }

    if err := r.getStore().Delete(ctx, name); err != nil {
        return nil, false, err
    }

    return obj, true, nil
}
EOF

echo "Created pkg/registry/${RESOURCE_LOWER}/rest.go"

# Create store interface
cat > "pkg/registry/${RESOURCE_LOWER}/store.go" << EOF
package ${RESOURCE_LOWER}

import (
    "context"
)

// Store defines the storage interface for ${RESOURCE_NAME}
type Store interface {
    Create(ctx context.Context, resource *v1alpha1.${RESOURCE_NAME}) (*v1alpha1.${RESOURCE_NAME}, error)
    Get(ctx context.Context, name string) (*v1alpha1.${RESOURCE_NAME}, error)
    List(ctx context.Context) (*v1alpha1.${RESOURCE_NAME}List, error)
    Update(ctx context.Context, resource *v1alpha1.${RESOURCE_NAME}) (*v1alpha1.${RESOURCE_NAME}, error)
    Delete(ctx context.Context, name string) error
}
EOF

echo "Created pkg/registry/${RESOURCE_LOWER}/store.go"

echo ""
echo "Next steps:"
echo "1. Implement the Store interface for your backend"
echo "2. Wire up REST storage in server configuration"
echo "3. Add platform capability integrations"
echo "4. Write tests"
