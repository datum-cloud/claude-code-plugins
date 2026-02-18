# Troubleshooting

Common issues and their resolutions when using the Datum Cloud Claude Code plugins.

## Table of Contents

- [Pipeline Issues](#pipeline-issues)
  - [Pipeline cannot advance: "artifact not found"](#pipeline-cannot-advance-artifact-not-found)
  - [Pipeline cannot advance: "blocking open question"](#pipeline-cannot-advance-blocking-open-question)
- [Review Issues](#review-issues)
  - [/review finds no changes](#review-finds-no-changes)
- [Deployment Issues](#deployment-issues)
  - [Deployment fails: "review gate not approved"](#deployment-fails-review-gate-not-approved)
  - [Deployment fails: "blocking findings exist"](#deployment-fails-blocking-findings-exist)
- [Learning System Issues](#learning-system-issues)
  - [/evolve produces no new patterns](#evolve-produces-no-new-patterns)
  - [Agent produces output that ignores existing patterns](#agent-produces-output-that-ignores-existing-patterns)
- [Plugin Issues](#plugin-issues)
  - [Code-reviewer runs validation scripts that fail with "script not found"](#code-reviewer-runs-validation-scripts-that-fail-with-script-not-found)
- [Agent-Specific Issues](#agent-specific-issues)
  - [Commercial-strategist recommendations conflict with existing services](#commercial-strategist-recommendations-conflict-with-existing-services)
  - [GTM content contains inaccurate capability claims](#gtm-content-contains-inaccurate-capability-claims)

---

## Pipeline Issues

### Pipeline cannot advance: "artifact not found"

**Symptom:** The pipeline refuses to advance with an "artifact not found" error.

**Cause:** The artifact expected for the current stage does not exist. Either the agent did not complete successfully, or the artifact was written to an unexpected location.

**Resolution:**

1. Check the expected artifact path:
   ```bash
   /pipeline status feat-042
   ```

2. Verify the artifact directory:
   ```bash
   ls .claude/pipeline/briefs/
   ```

3. If the artifact is missing, re-invoke the agent for that stage.

---

### Pipeline cannot advance: "blocking open question"

**Symptom:** The pipeline refuses to advance due to a blocking open question.

**Cause:** The current stage artifact has an open question marked `blocking: true` in its handoff header.

**Resolution:**

1. Read the artifact and find the blocking question
2. Resolve it by updating the artifact or consulting the suggested owner
3. Try advancing again

To override without resolving (when the question genuinely cannot be answered):
```bash
/pipeline next feat-042 --force
```

> **Warning:** Use `--force` sparingly. Unresolved blocking questions often reappear as review findings.

---

## Review Issues

### /review finds no changes

**Symptom:** The `/review` command reports no changes to review.

**Cause:** You are on main or the current branch has no changes compared to its base.

**Resolution:**

```bash
/review --diff feat-042-vm-snapshots    # Review specific branch
/review --diff main                     # Review all changes since main
```

---

## Deployment Issues

### Deployment fails: "review gate not approved"

**Symptom:** Deployment is blocked because the review gate has not been approved.

**Resolution:**

1. Run code review first:
   ```bash
   /review feat-042
   ```

2. Fix any blocking findings

3. Approve the review gate:
   ```bash
   /pipeline approve feat-042 review
   ```

4. Deploy:
   ```bash
   /deploy feat-042
   ```

---

### Deployment fails: "blocking findings exist"

**Symptom:** Deployment is blocked because there are unresolved blocking findings.

**Resolution:**

1. Check which findings are blocking:
   ```bash
   /pipeline status feat-042
   ```

2. The status output lists unresolved blocking findings

3. Fix them in the code, re-run `/review feat-042`, and approve if clean

---

## Learning System Issues

### /evolve produces no new patterns

**Symptom:** Running `/evolve` produces no new pattern promotions.

**Cause:** Either there are no review findings yet, or all patterns are already promoted.

**Resolution:**

1. Check the findings file exists:
   ```bash
   ls .claude/review-findings.jsonl
   ```

2. If the file exists but is empty, run code reviews with `/review` to populate it

3. Patterns require at least 3 occurrences to promote, so a single review rarely generates promotable patterns

---

### Agent produces output that ignores existing patterns

**Symptom:** An agent produces output that does not follow established patterns for the service.

**Cause:** Agents load their runbook and the pattern registry during context discovery. If the runbook or pattern registry is empty (because `/evolve` has not been run), agents work from general knowledge rather than service-specific patterns.

**Resolution:**

1. Run `/evolve` to populate runbooks
2. Re-invoke the agent

---

## Plugin Issues

### Code-reviewer runs validation scripts that fail with "script not found"

**Symptom:** The code-reviewer reports that validation scripts like `check-imports.sh` or `validate-types.sh` cannot be found.

**Cause:** Validation scripts are distributed with the plugin skills. If the code-reviewer cannot find them, the plugin may not be fully installed or the plugin root path is not set.

**Resolution:**

Reinstall the plugin:
```bash
/plugin install datum-platform@datum-claude-code-plugins
```

---

## Agent-Specific Issues

### Commercial-strategist recommendations conflict with existing services

**Symptom:** The commercial-strategist produces pricing recommendations that conflict with existing service pricing.

**Cause:** The commercial-strategist reads `platform-knowledge/services-catalog.md` to ensure pricing consistency across services. If this catalog is outdated, recommendations may conflict with existing pricing.

**Resolution:**

Update the services catalog with current pricing information before invoking the commercial-strategist on a new service.

---

### GTM content contains inaccurate capability claims

**Symptom:** The gtm-comms agent produces content with capability claims that don't match reality.

**Cause:** The gtm-comms agent verifies claims against pipeline artifacts and code, but only if those artifacts exist. If the feature's spec or design documents are missing or incomplete, the agent has less to verify against.

**Resolution:**

1. Ensure spec and design artifacts are complete before invoking gtm-comms
2. The `announce` gate exists specifically to catch inaccurate claims before publication
3. Always review GTM content manually before approving the announce gate

---

## Getting Help

If you encounter an issue not covered here:

1. Check the agent's skill documentation in `plugins/datum-platform/skills/` or `plugins/datum-gtm/skills/`
2. Review the command definition in `plugins/*/commands/`
3. File an issue at [github.com/datum-cloud/claude-code-plugins/issues](https://github.com/datum-cloud/claude-code-plugins/issues)
