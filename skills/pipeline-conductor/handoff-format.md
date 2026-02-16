# Handoff Header Format

All pipeline artifacts MUST include a structured handoff header in YAML frontmatter. This ensures downstream agents understand context, decisions, and open questions without re-discovery.

## Header Schema

```yaml
---
handoff:
  id: feat-{NNN}                    # Feature ID
  from: {agent-name}                # Agent that produced this artifact
  to: [{agent-name}, ...]           # Agents that will consume this artifact
  created: {ISO-8601 timestamp}     # When artifact was created
  updated: {ISO-8601 timestamp}     # Last modification (optional)

  context_summary: |                # 1-3 sentence summary of the work
    Brief description of what this artifact represents
    and its purpose in the pipeline.

  decisions_made:                   # Key decisions with rationale
    - decision: "Description of decision"
      rationale: "Why this decision was made"
      alternatives_considered:
        - "Alternative 1"
        - "Alternative 2"

  open_questions:                   # Unresolved items for downstream
    - question: "Question text"
      context: "Why this matters"
      blocking: true|false          # Does this block progression?
      suggested_owner: "{agent}"    # Who should resolve this?

  assumptions:                      # Assumptions made during work
    - assumption: "What was assumed"
      confidence: high|medium|low
      validation_needed: true|false

  dependencies:                     # What this artifact depends on
    upstream:
      - artifact: "path/to/artifact.md"
        relationship: "derived_from|references|supersedes"
    downstream:
      - artifact: "path/to/next-artifact.md"
        relationship: "enables|informs|blocks"

  platform_capabilities:            # Capability decisions
    quota:
      applies: true|false
      rationale: "Why or why not"
    insights:
      applies: true|false
      rationale: "Why or why not"
    telemetry:
      applies: true|false
      rationale: "Why or why not"
    activity:
      applies: true|false
      rationale: "Why or why not"
---
```

## Required Fields by Stage

### Request Stage

```yaml
handoff:
  id: feat-{NNN}
  from: user
  to: [product-discovery]
  context_summary: "..."
  open_questions: [...]
```

### Discovery Stage (Brief)

```yaml
handoff:
  id: feat-{NNN}
  from: product-discovery
  to: [product-planner, commercial-strategist]
  context_summary: "..."
  decisions_made: [...]
  open_questions: [...]
  assumptions: [...]
  platform_capabilities: {...}
```

### Spec Stage

```yaml
handoff:
  id: feat-{NNN}
  from: product-planner
  to: [architect, commercial-strategist]
  context_summary: "..."
  decisions_made: [...]
  open_questions: [...]
  dependencies:
    upstream:
      - artifact: "briefs/{id}.md"
        relationship: "derived_from"
```

### Pricing Stage

```yaml
handoff:
  id: feat-{NNN}
  from: commercial-strategist
  to: [architect]
  context_summary: "..."
  decisions_made: [...]   # Tier decisions, quota defaults
  assumptions: [...]      # Usage assumptions
```

### Design Stage

```yaml
handoff:
  id: feat-{NNN}
  from: architect
  to: [api-dev, frontend-dev, sre, test-engineer]
  context_summary: "..."
  decisions_made: [...]   # Architecture decisions
  open_questions: [...]   # Implementation details TBD
  platform_capabilities: {...}  # Confirmed integrations
```

### Implementation Stage

Implementation produces code, not artifacts. However, PR descriptions should include:

```markdown
## Handoff Context

**Feature**: feat-{NNN} - {name}
**Design**: .claude/pipeline/designs/{id}.md
**Implements**: {list of design sections implemented}

### Decisions Made During Implementation

- Decision: ...
  Rationale: ...

### Deviations from Design

- Deviation: ...
  Reason: ...
  Impact: ...

### Open Questions for Review

- Question: ...
  Context: ...
```

### Review Stage

```yaml
handoff:
  id: feat-{NNN}
  from: code-reviewer
  to: [sre]
  context_summary: "..."
  decisions_made:
    - decision: "Review approved/blocked"
      rationale: "Summary of findings"
  open_questions: [...]   # Issues requiring attention
```

## Validation Rules

Before advancing pipeline stages, validate:

1. **Required fields present**: All required fields for the stage exist
2. **No blocking open questions**: `blocking: true` questions are resolved
3. **Assumptions validated**: High-confidence assumptions are acceptable
4. **Dependencies satisfied**: Upstream artifacts exist and are complete
5. **Platform capabilities assessed**: All four capabilities have decisions

## Example: Complete Discovery Brief Header

```yaml
---
handoff:
  id: feat-042
  from: product-discovery
  to: [product-planner, commercial-strategist]
  created: 2025-01-15T10:30:00Z

  context_summary: |
    VM snapshot management for compliance requirements. Enables point-in-time
    recovery and audit trail for regulated workloads. Primary users are
    compliance officers and platform operators.

  decisions_made:
    - decision: "Snapshots will be project-scoped resources"
      rationale: "Aligns with existing resource hierarchy and IAM model"
      alternatives_considered:
        - "Organization-scoped snapshots"
        - "VM-attached snapshots (no separate resource)"

    - decision: "Automated snapshot policies will be a separate feature"
      rationale: "Reduces scope for initial release; manual snapshots first"
      alternatives_considered:
        - "Include automated policies in v1"

  open_questions:
    - question: "Should snapshots count against storage quota?"
      context: "Snapshots consume storage but are typically smaller than full VMs"
      blocking: false
      suggested_owner: commercial-strategist

    - question: "What's the maximum retention period?"
      context: "Compliance requirements vary; need to balance cost and compliance"
      blocking: true
      suggested_owner: product-planner

  assumptions:
    - assumption: "GCP persistent disk snapshots as backend"
      confidence: high
      validation_needed: false

    - assumption: "Snapshots can be restored to different projects"
      confidence: medium
      validation_needed: true

  dependencies:
    upstream:
      - artifact: "requests/feat-042-vm-snapshot-management.md"
        relationship: "derived_from"
    downstream:
      - artifact: "specs/feat-042-vm-snapshot-management.md"
        relationship: "enables"
      - artifact: "pricing/feat-042-vm-snapshot-management.md"
        relationship: "informs"

  platform_capabilities:
    quota:
      applies: true
      rationale: "Snapshots consume storage; need per-project limits"
    insights:
      applies: true
      rationale: "Can detect orphaned snapshots, retention violations"
    telemetry:
      applies: true
      rationale: "Snapshot size, count, creation/deletion rates"
    activity:
      applies: true
      rationale: "Snapshot operations need audit trail for compliance"
---
```

## Agent Responsibilities

### When Producing Artifacts

1. Always include complete handoff header
2. Document all decisions with rationale
3. Flag blocking vs non-blocking open questions
4. State assumptions explicitly with confidence levels
5. Assess all platform capabilities (even if "does not apply")

### When Consuming Artifacts

1. Read handoff header first before artifact content
2. Check for blocking open questions - resolve or escalate
3. Validate assumptions relevant to your work
4. Reference upstream decisions when making new ones
5. Update your artifact's `dependencies.upstream` section
