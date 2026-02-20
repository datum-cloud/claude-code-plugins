---
name: c4-diagrams
description: Covers creating C4 architecture diagrams using PlantUML. Use when documenting system architecture, component relationships, or container layouts for technical documentation.
---

# C4 Diagrams with PlantUML

This skill covers creating C4 model architecture diagrams using the PlantUML C4 plugin.

## Overview

The C4 model provides four levels of abstraction for documenting software architecture:

| Level | Name | Purpose |
|-------|------|---------|
| 1 | Context | System in its environment with users and external systems |
| 2 | Container | High-level technology choices and responsibilities |
| 3 | Component | Components within a container |
| 4 | Code | Class/entity level (rarely needed) |

## PlantUML C4 Setup

Include the C4 library at the start of your diagram:

```plantuml
@startuml
!include https://raw.githubusercontent.com/plantuml-stdlib/C4-PlantUML/master/C4_Container.puml

' Your diagram here

@enduml
```

Available includes based on diagram level:

| Include | Use For |
|---------|---------|
| `C4_Context.puml` | Level 1 - System Context diagrams |
| `C4_Container.puml` | Level 2 - Container diagrams |
| `C4_Component.puml` | Level 3 - Component diagrams |
| `C4_Dynamic.puml` | Sequence-style interaction diagrams |
| `C4_Deployment.puml` | Infrastructure and deployment diagrams |

## Key Files

| File | Purpose |
|------|---------|
| `context-diagrams.md` | System context diagram patterns |
| `container-diagrams.md` | Container diagram patterns |
| `component-diagrams.md` | Component diagram patterns |

## Core Elements

### People and Systems

```plantuml
@startuml
!include https://raw.githubusercontent.com/plantuml-stdlib/C4-PlantUML/master/C4_Context.puml

Person(user, "Platform User", "A user of the Datum Cloud platform")
Person_Ext(external, "External User", "External system user")

System(platform, "Datum Cloud Platform", "Multi-tenant Kubernetes platform")
System_Ext(github, "GitHub", "Source code repository")

Rel(user, platform, "Uses", "HTTPS")
Rel(platform, github, "Pulls code from", "HTTPS")

@enduml
```

### Containers

```plantuml
@startuml
!include https://raw.githubusercontent.com/plantuml-stdlib/C4-PlantUML/master/C4_Container.puml

Person(user, "Platform User")

System_Boundary(platform, "Datum Cloud Platform") {
    Container(api, "API Server", "Go", "Handles API requests")
    Container(controller, "Controller", "Go", "Reconciles resources")
    ContainerDb(db, "Database", "PostgreSQL", "Stores platform data")
}

Rel(user, api, "Uses", "HTTPS")
Rel(api, db, "Reads/Writes", "SQL")
Rel(controller, api, "Watches", "Kubernetes API")

@enduml
```

### Components

```plantuml
@startuml
!include https://raw.githubusercontent.com/plantuml-stdlib/C4-PlantUML/master/C4_Component.puml

Container_Boundary(api, "API Server") {
    Component(handler, "Request Handler", "Go", "Processes HTTP requests")
    Component(storage, "Storage Backend", "Go", "Manages persistence")
    Component(auth, "Auth Middleware", "Go", "Validates tokens")
}

Rel(handler, auth, "Uses")
Rel(handler, storage, "Uses")

@enduml
```

## Element Reference

### People

| Macro | Description |
|-------|-------------|
| `Person(alias, label, description)` | Internal user |
| `Person_Ext(alias, label, description)` | External user |

### Systems

| Macro | Description |
|-------|-------------|
| `System(alias, label, description)` | Internal system |
| `System_Ext(alias, label, description)` | External system |
| `System_Boundary(alias, label)` | Grouping boundary |

### Containers

| Macro | Description |
|-------|-------------|
| `Container(alias, label, technology, description)` | Generic container |
| `ContainerDb(alias, label, technology, description)` | Database container |
| `ContainerQueue(alias, label, technology, description)` | Message queue |
| `Container_Boundary(alias, label)` | Container grouping |

### Components

| Macro | Description |
|-------|-------------|
| `Component(alias, label, technology, description)` | Generic component |
| `ComponentDb(alias, label, technology, description)` | Database component |
| `ComponentQueue(alias, label, technology, description)` | Queue component |

### Relationships

| Macro | Description |
|-------|-------------|
| `Rel(from, to, label)` | Basic relationship |
| `Rel(from, to, label, technology)` | Relationship with tech |
| `Rel_D(from, to, label)` | Downward relationship |
| `Rel_U(from, to, label)` | Upward relationship |
| `Rel_L(from, to, label)` | Leftward relationship |
| `Rel_R(from, to, label)` | Rightward relationship |

## Layout Control

Control diagram layout with directional relationships and layout hints:

```plantuml
@startuml
!include https://raw.githubusercontent.com/plantuml-stdlib/C4-PlantUML/master/C4_Container.puml

LAYOUT_WITH_LEGEND()
LAYOUT_LEFT_RIGHT()

' Elements will flow left to right
Container(a, "Service A", "Go", "First service")
Container(b, "Service B", "Go", "Second service")
Container(c, "Service C", "Go", "Third service")

Rel_R(a, b, "Calls")
Rel_R(b, c, "Calls")

@enduml
```

Layout macros:

| Macro | Effect |
|-------|--------|
| `LAYOUT_TOP_DOWN()` | Vertical layout (default) |
| `LAYOUT_LEFT_RIGHT()` | Horizontal layout |
| `LAYOUT_WITH_LEGEND()` | Add legend to diagram |
| `LAYOUT_AS_SKETCH()` | Hand-drawn style |

## Styling

Customize colors and appearance:

```plantuml
@startuml
!include https://raw.githubusercontent.com/plantuml-stdlib/C4-PlantUML/master/C4_Container.puml

' Custom colors
AddElementTag("critical", $bgColor="#ff0000", $fontColor="#ffffff")
AddElementTag("deprecated", $bgColor="#888888")

Container(api, "API Server", "Go", "Critical service", $tags="critical")
Container(legacy, "Legacy Service", "Java", "Being replaced", $tags="deprecated")

@enduml
```

## Best Practices

### Diagram Guidelines

1. **One purpose per diagram** — Don't mix abstraction levels
2. **Limit elements** — 5-10 elements per diagram for readability
3. **Consistent naming** — Use the same names across all diagrams
4. **Clear descriptions** — Each element should have a meaningful description
5. **Show key relationships** — Don't show every possible connection

### Documentation Integration

Place diagrams in `docs/architecture/`:

```
docs/
└── architecture/
    ├── context.puml          # Level 1
    ├── containers.puml       # Level 2
    └── components/
        ├── api-server.puml   # Level 3 for API
        └── controller.puml   # Level 3 for controller
```

### Rendering

Render diagrams using:

```bash
# Using PlantUML CLI
plantuml -tpng docs/architecture/*.puml

# Using PlantUML server
# Add to markdown: ![Diagram](http://www.plantuml.com/plantuml/proxy?src=...)
```

## Example: Datum Platform Context

```plantuml
@startuml C4_Context
!include https://raw.githubusercontent.com/plantuml-stdlib/C4-PlantUML/master/C4_Context.puml

LAYOUT_WITH_LEGEND()

title Datum Cloud Platform - System Context

Person(admin, "Platform Admin", "Manages platform configuration")
Person(developer, "Developer", "Deploys and manages workloads")

System(platform, "Datum Cloud Platform", "Multi-tenant Kubernetes platform for edge workloads")

System_Ext(github, "GitHub", "Source code and CI/CD")
System_Ext(cloud, "Cloud Providers", "GCP, AWS infrastructure")
System_Ext(monitoring, "Monitoring", "Observability stack")

Rel(admin, platform, "Configures", "CLI/API")
Rel(developer, platform, "Deploys to", "kubectl/API")
Rel(platform, github, "Pulls from", "HTTPS")
Rel(platform, cloud, "Provisions on", "Cloud APIs")
Rel(platform, monitoring, "Exports to", "OTLP")

@enduml
```

## Anti-patterns to Avoid

- **Too much detail** — Context diagrams shouldn't show internal components
- **Missing descriptions** — Every element needs context
- **Inconsistent abstraction** — Don't mix containers and components
- **Overcrowded diagrams** — Split into multiple focused diagrams
- **No legend** — Always include `LAYOUT_WITH_LEGEND()` for clarity
