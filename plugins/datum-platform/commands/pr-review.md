---
name: pr-review
description: >
  Run two read-only reviewers on a pull request, compare their verdicts,
  and either carry the PR to auto-merge through the fixer or put the choice
  to you. Drives the pr-review-loop skill.
tools: Read, Grep, Glob, Bash, Agent
model: sonnet
disable-model-invocation: true
argument-hint: "[pr-number]"
---

# PR Review Command

Run the two-reviewer loop on one pull request.

## Usage

```
/pr-review                  Review the PR for the current branch
/pr-review <number>         Review a specific PR in this repository
```

## Arguments

PR number: $ARGUMENTS

## Workflow

1. **Resolve the PR.** With a number, use it. Without one, `gh pr view --json number` on the current branch. If neither resolves, stop with the error below.
2. **Read the `pr-review-loop` skill** and its `protocol.md`.
3. **Apply the cost caps** from the skill. Say which reviewers will run and why.
4. **Fetch the head once** in the PR's worktree, as the skill describes, so the reviewers never fetch.
5. **Launch the reviewers** in one message, with the PR number, base SHA, and head SHA. They run in the background on their own, on the model their definitions pin. Never name a model at the spawn; the `model-tiers` skill says why.
6. **Keep working** until both reports land, then compare them under the five agreement conditions and the always-escalate list.
7. **Act.** When the conditions hold, classify the findings against `model-tiers` and spawn `pr-review-fixer` for its fix phase, naming `model: haiku` at the spawn when every finding is simple, and say in one line what it is doing. Otherwise put the choice to the user with a recommendation.
8. **Re-review.** If the fixer changed a `blocker` or `warning`, run the second pass on the pushed head: `pr-rereviewer` in place of a fresh `pr-adversary`, alongside `pr-conventions-reviewer`, giving the re-reviewer both heads and the findings the fixer applied. Two `merge` verdicts, or two `hold` with nothing above `nit`, unlock the fixer's ready phase. A second `hold` goes to the user.
9. **Rebase when it falls behind.** A branch behind its base, or colliding with another open pull request, goes to `pr-rebaser` before the ready phase. A conflict that is a design choice comes back to the user.

## Output

```
Reviewing #1234 against a1b2c3d (base) with pr-adversary and pr-conventions-reviewer.
Both run in the background. I will pick them up when they land.

[reports arrive]

pr-adversary: VERDICT: hold. <reason>
pr-conventions-reviewer: VERDICT: hold. <reason>
Agreement: all five conditions hold. Spawning pr-review-fixer to apply 3 findings and push. Both reviewers run again on the new head before ready and auto-merge.
```

or

```
pr-adversary: VERDICT: merge. <reason>
pr-conventions-reviewer: VERDICT: hold. <reason>
Split verdict. The conventions reviewer says the patch target does not anchor; the adversary rendered it and it does. Recommendation: <one line>. Which way?
```

## Error handling

**No PR resolves:**
```
No pull request for this branch. Pass a number: /pr-review <number>
```

**A reviewer did not finish:**
```
pr-adversary returned no verdict line. Treating this as not finished. The conventions report is below for reference; nothing will be applied without your say.
```
