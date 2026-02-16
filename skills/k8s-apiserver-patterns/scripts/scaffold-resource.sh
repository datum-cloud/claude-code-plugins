#!/bin/bash
# Scaffold a new API resource type
# Usage: scaffold-resource.sh <resource-name>

set -e

RESOURCE_NAME=$1
RESOURCE_LOWER=$(echo "$RESOURCE_NAME" | tr '[:upper:]' '[:lower:]')
RESOURCE_PLURAL="${RESOURCE_LOWER}s"

if [ -z "$RESOURCE_NAME" ]; then
    echo "Usage: scaffold-resource.sh <resource-name>"
    echo "Example: scaffold-resource.sh VirtualMachine"
    exit 1
fi

echo "Scaffolding resource type $RESOURCE_NAME..."

# Get API group from CLAUDE.md or default
API_GROUP=${API_GROUP:-"myservice.miloapis.com"}

# Create types file
mkdir -p pkg/apis/${RESOURCE_LOWER}/v1alpha1

cat > "pkg/apis/${RESOURCE_LOWER}/v1alpha1/types.go" << EOF
package v1alpha1

import (
    metav1 "k8s.io/apimachinery/pkg/apis/meta/v1"
)

// +kubebuilder:object:root=true
// +kubebuilder:subresource:status
// +kubebuilder:resource:shortName=${RESOURCE_LOWER:0:2}
// +kubebuilder:printcolumn:name="Status",type=string,JSONPath=\`.status.phase\`
// +kubebuilder:printcolumn:name="Age",type=date,JSONPath=\`.metadata.creationTimestamp\`

// ${RESOURCE_NAME} is the Schema for the ${RESOURCE_PLURAL} API
type ${RESOURCE_NAME} struct {
    metav1.TypeMeta   \`json:",inline"\`
    metav1.ObjectMeta \`json:"metadata,omitempty"\`

    Spec   ${RESOURCE_NAME}Spec   \`json:"spec,omitempty"\`
    Status ${RESOURCE_NAME}Status \`json:"status,omitempty"\`
}

// ${RESOURCE_NAME}Spec defines the desired state of ${RESOURCE_NAME}
type ${RESOURCE_NAME}Spec struct {
    // INSERT FIELDS HERE

    // +kubebuilder:validation:Optional
    // Description is a human-readable description
    Description string \`json:"description,omitempty"\`
}

// ${RESOURCE_NAME}Status defines the observed state of ${RESOURCE_NAME}
type ${RESOURCE_NAME}Status struct {
    // Phase represents the current phase of the resource
    // +kubebuilder:validation:Enum=Pending;Running;Failed;Succeeded
    Phase string \`json:"phase,omitempty"\`

    // Conditions represent the latest available observations
    Conditions []metav1.Condition \`json:"conditions,omitempty"\`
}

// +kubebuilder:object:root=true

// ${RESOURCE_NAME}List contains a list of ${RESOURCE_NAME}
type ${RESOURCE_NAME}List struct {
    metav1.TypeMeta \`json:",inline"\`
    metav1.ListMeta \`json:"metadata,omitempty"\`
    Items           []${RESOURCE_NAME} \`json:"items"\`
}
EOF

echo "Created pkg/apis/${RESOURCE_LOWER}/v1alpha1/types.go"

# Create register file
cat > "pkg/apis/${RESOURCE_LOWER}/v1alpha1/register.go" << EOF
package v1alpha1

import (
    metav1 "k8s.io/apimachinery/pkg/apis/meta/v1"
    "k8s.io/apimachinery/pkg/runtime"
    "k8s.io/apimachinery/pkg/runtime/schema"
)

var (
    SchemeGroupVersion = schema.GroupVersion{
        Group:   "${API_GROUP}",
        Version: "v1alpha1",
    }

    SchemeBuilder = runtime.NewSchemeBuilder(addKnownTypes)
    AddToScheme   = SchemeBuilder.AddToScheme
)

func Resource(resource string) schema.GroupResource {
    return SchemeGroupVersion.WithResource(resource).GroupResource()
}

func addKnownTypes(scheme *runtime.Scheme) error {
    scheme.AddKnownTypes(SchemeGroupVersion,
        &${RESOURCE_NAME}{},
        &${RESOURCE_NAME}List{},
    )
    metav1.AddToGroupVersion(scheme, SchemeGroupVersion)
    return nil
}
EOF

echo "Created pkg/apis/${RESOURCE_LOWER}/v1alpha1/register.go"

# Create doc file
cat > "pkg/apis/${RESOURCE_LOWER}/v1alpha1/doc.go" << EOF
// +kubebuilder:object:generate=true
// +groupName=${API_GROUP}

// Package v1alpha1 contains API Schema definitions for the ${RESOURCE_LOWER} v1alpha1 API group
package v1alpha1
EOF

echo "Created pkg/apis/${RESOURCE_LOWER}/v1alpha1/doc.go"

echo ""
echo "Next steps:"
echo "1. Add fields to ${RESOURCE_NAME}Spec in types.go"
echo "2. Run 'task generate' to generate deepcopy"
echo "3. Create storage with scaffold-storage.sh $RESOURCE_NAME"
echo "4. Run validate-types.sh to verify conventions"
